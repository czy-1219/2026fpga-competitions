`timescale 1ns/1ps
`include "variants/frame_ddr_20261011/student_frame_axi_core.v"
`include "rtl_custom/processing/color_chroma_ddr.v"
 


module student_frame_axi_engine (
    input wire clk_i,rst_n_i,start_i,
    input wire [15:0] width_i,height_i,
    input wire joint_i,camera_layout_i,input wire [1:0] output_mode_i,
    input wire [31:0] input_base_i,output_base_i,
    output wire busy_o,done_o,error_o,
    output wire color_model_o,
    output wire [23:0] pixels_done_o,
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
    localparam [31:0] COLOR_SCRATCH=32'h03000000;
    localparam IDLE=0,START_CORE=1,CORE=2,START_POST=3,POST=4,FINISH=5;
    reg [2:0] phase;
    reg busy,done,error,use_color,joint,camera;
    reg [1:0] mode;
    reg [15:0] width,height;
    reg [31:0] input_base,output_base;
    reg [23:0] progress,total;
    wire core_busy,core_done,core_error,post_busy,post_done,post_error;
    wire [23:0] core_pixels,post_pixels;
    wire core_active=phase==START_CORE || phase==CORE;
    wire post_active=phase==START_POST || phase==POST;
    assign busy_o=busy;assign done_o=done;assign error_o=error;
    assign pixels_done_o=progress;
    wire core_arvalid,post_arvalid;
    assign arvalid_o=post_active ? post_arvalid : core_active ? core_arvalid : 1'd0;
    wire [31:0] core_araddr,post_araddr;
    assign araddr_o=post_active ? post_araddr : core_active ? core_araddr : 32'd0;
    wire core_rready,post_rready;
    assign rready_o=post_active ? post_rready : core_active ? core_rready : 1'd0;
    wire core_awvalid,post_awvalid;
    assign awvalid_o=post_active ? post_awvalid : core_active ? core_awvalid : 1'd0;
    wire [31:0] core_awaddr,post_awaddr;
    assign awaddr_o=post_active ? post_awaddr : core_active ? core_awaddr : 32'd0;
    wire core_wvalid,post_wvalid;
    assign wvalid_o=post_active ? post_wvalid : core_active ? core_wvalid : 1'd0;
    wire [127:0] core_wdata,post_wdata;
    assign wdata_o=post_active ? post_wdata : core_active ? core_wdata : 128'd0;
    wire [15:0] core_wstrb,post_wstrb;
    assign wstrb_o=post_active ? post_wstrb : core_active ? core_wstrb : 16'd0;
    wire core_wlast,post_wlast;
    assign wlast_o=post_active ? post_wlast : core_active ? core_wlast : 1'd0;
    wire core_bready,post_bready;
    assign bready_o=post_active ? post_bready : core_active ? core_bready : 1'd0;
    student_frame_axi_core u_core(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .start_i(phase==START_CORE),
        .width_i(width),
        .height_i(height),
        .joint_i(joint),
        .camera_layout_i(camera),
        .output_mode_i(mode),
        .input_base_i(input_base),
        .output_base_i(use_color ? COLOR_SCRATCH : output_base),
        .busy_o(core_busy),
        .done_o(core_done),
        .error_o(core_error),
        .color_model_o(color_model_o),
        .pixels_done_o(core_pixels),
        .tile_input_valid_o(tile_input_valid_o),
        .tile_input_ready_i(tile_input_ready_i),
        .tile_input_pixel_o(tile_input_pixel_o),
        .tile_start_valid_o(tile_start_valid_o),
        .tile_start_ready_i(tile_start_ready_i),
        .tile_result_valid_i(tile_result_valid_i),
        .tile_result_ready_o(tile_result_ready_o),
        .tile_result_pixel_i(tile_result_pixel_i),
        .tile_result_address_i(tile_result_address_i),
        .arvalid_o(core_arvalid),
        .araddr_o(core_araddr),
        .rready_o(core_rready),
        .awvalid_o(core_awvalid),
        .awaddr_o(core_awaddr),
        .wvalid_o(core_wvalid),
        .wdata_o(core_wdata),
        .wstrb_o(core_wstrb),
        .wlast_o(core_wlast),
        .bready_o(core_bready),
        .arready_i(arready_i && core_active),
        .rvalid_i(rvalid_i && core_active),
        .awready_i(awready_i && core_active),
        .wready_i(wready_i && core_active),
        .bvalid_i(bvalid_i && core_active),
        .rlast_i(rlast_i),
        .rresp_i(rresp_i),
        .rdata_i(rdata_i),
        .bresp_i(bresp_i)
    );
    color_chroma_ddr u_post(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .start_i(phase==START_POST),
        .width_i(width),
        .height_i(height),
        .input_base_i(COLOR_SCRATCH),
        .output_base_i(output_base),
        .busy_o(post_busy),
        .done_o(post_done),
        .error_o(post_error),
        .pixels_done_o(post_pixels),
        .arvalid_o(post_arvalid),
        .araddr_o(post_araddr),
        .rready_o(post_rready),
        .awvalid_o(post_awvalid),
        .awaddr_o(post_awaddr),
        .wvalid_o(post_wvalid),
        .wdata_o(post_wdata),
        .wstrb_o(post_wstrb),
        .wlast_o(post_wlast),
        .bready_o(post_bready),
        .arready_i(arready_i && post_active),
        .rvalid_i(rvalid_i && post_active),
        .awready_i(awready_i && post_active),
        .wready_i(wready_i && post_active),
        .bvalid_i(bvalid_i && post_active),
        .rlast_i(rlast_i),
        .rresp_i(rresp_i),
        .rdata_i(rdata_i),
        .bresp_i(bresp_i)
    );

    always @(posedge clk_i or negedge rst_n_i)begin
        if(!rst_n_i)begin
            phase<=IDLE;busy<=0;done<=0;error<=0;use_color<=0;joint<=0;camera<=0;mode<=0;
            width<=0;height<=0;input_base<=0;output_base<=0;progress<=0;total<=0;
        end else case(phase)
            IDLE:if(start_i)begin
                busy<=1;done<=0;error<=0;progress<=0;total<=0;
                use_color<=output_mode_i==0;mode<=output_mode_i;joint<=joint_i;camera<=camera_layout_i;
                width<=width_i;height<=height_i;input_base<=input_base_i;output_base<=output_base_i;
                phase<=START_CORE;
            end
            START_CORE:phase<=CORE;
            CORE:begin
                progress<=use_color ? core_pixels>>1 : core_pixels;
                if(core_done)begin
                    error<=core_error;total<=core_pixels;
                    phase<=use_color && !core_error ? START_POST : FINISH;
                end
            end
            START_POST:phase<=POST;
            POST:begin
                progress<=(total>>1)+(post_pixels>>1);
                if(post_done)begin error<=post_error;if(!post_error)progress<=total;phase<=FINISH;end
            end
            FINISH:begin busy<=0;done<=1;phase<=IDLE;end
            default:begin error<=1;busy<=0;done<=1;phase<=IDLE;end
        endcase
    end
endmodule
