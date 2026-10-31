`timescale 1ns/1ps
 



module student_frame_axi_core #(parameter SUPPORT_COLOR=1) (
    input wire clk_i,rst_n_i,start_i,
    input wire [15:0] width_i,height_i,
    input wire joint_i,camera_layout_i,input wire [1:0] output_mode_i,
    input wire [31:0] input_base_i,output_base_i,
    output reg busy_o,done_o,error_o,
    output wire color_model_o,
    output reg [23:0] pixels_done_o,
    output wire tile_input_valid_o,input wire tile_input_ready_i,
    output wire [7:0] tile_input_pixel_o,
    output wire tile_start_valid_o,input wire tile_start_ready_i,
    input wire tile_result_valid_i,output wire tile_result_ready_o,
    input wire [7:0] tile_result_pixel_i,input wire [9:0] tile_result_address_i,
    output wire arvalid_o,input wire arready_i,output wire [31:0] araddr_o,
    input wire rvalid_i,rlast_i,input wire [1:0] rresp_i,
    input wire [127:0] rdata_i,output wire rready_o,
    output wire awvalid_o,input wire awready_i,output wire [31:0] awaddr_o,
    output wire wvalid_o,input wire wready_i,output wire [127:0] wdata_o,
    output wire [15:0] wstrb_o,output wire wlast_o,
    input wire bvalid_i,input wire [1:0] bresp_i,output wire bready_o
);
    localparam [2:0] IDLE=0,READ_ADDR=1,READ_DATA=2,WRITE_ADDR=3,WRITE_DATA=4,WRITE_RESP=5,PREPROCESS=6;
    reg [2:0] state;
    reg joint,camera_layout;
    reg [1:0] output_mode;
     
    assign color_model_o = SUPPORT_COLOR && output_mode==2'd0;
    reg [15:0] source_pixel;
    wire [15:0] tone_pixel,color_pixel;
    upload_gray_scan_rgb565 frame_gray_tone(.pixel_i(source_pixel),.pixel_o(tone_pixel));
    upload_color_enhance_rgb565 frame_color_contrast(.pixel_i(source_pixel),.pixel_o(color_pixel));
    wire [15:0] prepared_pixel=!joint ? source_pixel : SUPPORT_COLOR && output_mode==0 ? color_pixel : tone_pixel;
    wire [7:0] prepared_red={prepared_pixel[15:11],prepared_pixel[15:13]};
    wire [7:0] prepared_green={prepared_pixel[10:5],prepared_pixel[10:9]};
    wire [7:0] prepared_blue={prepared_pixel[4:0],prepared_pixel[4:2]};
    wire mem_req,mem_valid,result_valid,result_ready,scheduler_busy,scheduler_done;
    wire [31:0] mem_addr,result_addr;
    wire [7:0] result_data;
    wire [9:0] unused_input_index;
    reg [31:0] input_base,output_base,read_address,write_address;
    reg [3:0] read_lane;
    reg [1:0] read_channel;
    reg [7:0] input_byte;
    reg read_valid,finish_pending;
    reg [7:0] result_red,result_green;
    reg [127:0] write_data;
    reg [15:0] write_strobe;
    wire [1:0] mem_channel,result_channel;
    wire [31:0] physical_read_address=mem_addr;
    wire [31:0] physical_write_address=result_addr;
    reg cache_valid;
    reg [31:0] cache_address;
    reg [127:0] cache_data;
    wire [3:0] source_lane=physical_read_address[3:0] ^ (camera_layout ? 4'he : 4'h0);
    wire [15:0] cached_pixel=cache_data[source_lane*8 +: 16];
    wire [7:0] cached_red={cached_pixel[15:11],cached_pixel[15:13]};
    wire [7:0] cached_green={cached_pixel[10:5],cached_pixel[10:9]};
    wire [7:0] cached_blue={cached_pixel[4:0],cached_pixel[4:2]};
    wire [15:0] read_pixel = rdata_i[read_lane*8 +: 16];
    wire [7:0] read_red = {read_pixel[15:11],read_pixel[15:13]};
    wire [7:0] read_green = {read_pixel[10:5],read_pixel[10:9]};
    wire [7:0] read_blue = {read_pixel[4:0],read_pixel[4:2]};
     
    wire [7:0] unsigned_result = result_data ^ 8'h80;
    wire [31:0] scaled_result = unsigned_result * 32'd95429 + 32'd32768;
    wire [7:0] output_byte = scaled_result[31:16] > 255 ? 8'd255 : scaled_result[23:16];
    wire [15:0] output_luma_sum=result_red*8'd77+result_green*8'd150+output_byte*8'd29+16'd128;
    wire [7:0] output_gray=output_luma_sum[15:8];
    wire [15:0] output_pixel = output_mode==1 ? {output_gray[7:3],output_gray[7:2],output_gray[7:3]} :
        !SUPPORT_COLOR || output_mode==2 ? (output_gray>=128 ? 16'hffff : 16'h0000) : {result_red[7:3],result_green[7:2],output_byte[7:3]};
    assign mem_valid=read_valid;
    assign arvalid_o=state==READ_ADDR;
    assign araddr_o=read_address;
    assign rready_o=state==READ_DATA;
    assign result_ready=state==IDLE && !read_valid;
    assign awvalid_o=state==WRITE_ADDR;
    assign awaddr_o=write_address;
    assign wvalid_o=state==WRITE_DATA;
    assign wdata_o=write_data;
    assign wstrb_o=write_strobe;
    assign wlast_o=1'b1;
    assign bready_o=state==WRITE_RESP;
    student_frame_tile_scheduler scheduler (
        .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(start_i && !busy_o),
        .width_i(width_i),.height_i(height_i),.input_base_i(input_base_i),.output_base_i(output_base_i),
        .input_mem_req_o(mem_req),.input_mem_addr_o(mem_addr),.input_mem_channel_o(mem_channel),.input_mem_valid_i(mem_valid),.input_mem_data_i(input_byte),
        .tile_input_valid_o(tile_input_valid_o),.tile_input_index_o(unused_input_index),.tile_input_data_o(tile_input_pixel_o),
        .tile_input_ready_i(tile_input_ready_i),.tile_start_valid_o(tile_start_valid_o),.tile_start_ready_i(tile_start_ready_i),
        .tile_result_valid_i(tile_result_valid_i),.tile_result_index_i(tile_result_address_i),.tile_result_data_i(tile_result_pixel_i),
        .tile_result_ready_o(tile_result_ready_o),.result_valid_o(result_valid),.result_addr_o(result_addr),.result_channel_o(result_channel),
        .result_data_o(result_data),.result_ready_i(result_ready),.busy_o(scheduler_busy),.done_o(scheduler_done)
    );
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            cache_valid<=0;cache_address<=0;cache_data<=0;
            joint<=0;camera_layout<=0;output_mode<=0;source_pixel<=0;pixels_done_o<=0;state<=IDLE;busy_o<=0;done_o<=0;error_o<=0;read_valid<=0;finish_pending<=0;
            input_base<=0;output_base<=0;read_address<=0;write_address<=0;read_lane<=0;read_channel<=0;
            input_byte<=0;write_data<=0;write_strobe<=0;result_red<=0;result_green<=0;
        end else begin
            read_valid<=0;
            if(start_i && !busy_o) begin
                done_o<=0;error_o<=0;finish_pending<=0;cache_valid<=0;pixels_done_o<=0;
                if(width_i==0 || height_i==0 || width_i>1920 || height_i>1080) begin done_o<=1;error_o<=1;end
                else begin camera_layout<=camera_layout_i;joint<=joint_i;output_mode<=output_mode_i;busy_o<=1;input_base<=input_base_i;output_base<=output_base_i;end
            end
            if(scheduler_done)finish_pending<=1;
            if(finish_pending && state==IDLE)begin busy_o<=0;done_o<=1;finish_pending<=0;end
            case(state)
                IDLE: begin
                    if(mem_req && !read_valid)begin
                        if(cache_valid && cache_address==(physical_read_address & 32'hfffffff0))begin
                            source_pixel<=cached_pixel;read_channel<=mem_channel;state<=PREPROCESS;
                        end else begin
                            read_address<=physical_read_address & 32'hfffffff0;
                            read_lane<=source_lane;read_channel<=mem_channel;state<=READ_ADDR;
                        end
                    end else if(result_valid && result_ready)begin
                        case(result_channel)
                            0:result_red<=output_byte;
                            1:result_green<=output_byte;
                            2:begin
                                write_address<=physical_write_address & 32'hfffffff0;
                                write_data<={112'd0,output_pixel} << (physical_write_address[3:0]*8);
                                write_strobe<=16'h0003 << physical_write_address[3:0];state<=WRITE_ADDR;
                            end
                        endcase
                    end
                end
                READ_ADDR:if(arready_i)state<=READ_DATA;
                READ_DATA:if(rvalid_i)begin
                    source_pixel<=read_pixel;
                    cache_data<=rdata_i;cache_address<=read_address;cache_valid<=rresp_i==0 && rlast_i;
                    if(rresp_i!=0 || !rlast_i)error_o<=1;state<=PREPROCESS;
                end
                PREPROCESS:begin
                    input_byte<=read_channel==0 ? prepared_red : read_channel==1 ? prepared_green : prepared_blue;
                    read_valid<=1;state<=IDLE;
                end
                WRITE_ADDR:if(awready_i)state<=WRITE_DATA;
                WRITE_DATA:if(wready_i)state<=WRITE_RESP;
                WRITE_RESP:if(bvalid_i)begin if(bresp_i!=0)error_o<=1;else pixels_done_o<=pixels_done_o+1'b1;state<=IDLE;end
                default:begin state<=IDLE;error_o<=1;end
            endcase
        end
    end
endmodule
