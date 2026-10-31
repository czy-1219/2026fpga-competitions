`timescale 1ns/1ps

 
module compact_student_registers #(parameter COLOR_BANK=0) (
    input wire clk_i,rst_n_i,
    input wire frame_select_i,frame_reset_i,frame_input_valid_i,frame_start_valid_i,frame_result_ready_i,
    input wire [7:0] frame_input_pixel_i,
    input wire frame_color_i,
    output wire frame_input_ready_o,frame_start_ready_o,frame_result_valid_o,frame_core_busy_o,
    output wire [7:0] frame_result_pixel_o,output wire [9:0] frame_result_address_o,
    input wire write_valid_i,
    input wire [6:0] write_address_i,read_address_i,
    input wire [7:0] write_data_i,
    input wire spi_sclk_i,spi_cs_n_i,spi_mosi_i,
    input wire [1:0] stream_select_i,
    output wire stream_miso_o,
    output reg [7:0] read_data_o
);
    wire input_ready,start_ready,result_valid,busy,done;
    wire signed [7:0] result_pixel;
    wire [9:0] result_address;
    wire reset_command=write_valid_i && write_address_i==7'h40 && write_data_i[1];
    wire start_command=write_valid_i && write_address_i==7'h40 && write_data_i[0] && !write_data_i[1];
    wire input_command=write_valid_i && write_address_i==7'h41;
    wire result_command=write_valid_i && write_address_i==7'h42 && write_data_i[0];
    wire burst_begin=write_valid_i && write_address_i==7'h4b && write_data_i==1;
    reg error,complete,burst_job,feed_active,feed_valid,auto_start;
    reg [9:0] input_count,feed_index,collected;
    reg [7:0] feed_pixel;
    (* syn_ramstyle="block_ram" *) reg [7:0] input_buffer[0:767];
    (* syn_ramstyle="block_ram" *) reg [7:0] result_buffer[0:767];
    reg [31:0] result_crc;
    wire model_input_valid=burst_job ? feed_valid : input_command;
    wire [7:0] model_input_pixel=burst_job ? feed_pixel : write_data_i;
    wire model_result_ready=burst_job ? collected<768 : result_command;
    compact_student_tile #(.COLOR_BANK(COLOR_BANK)) compact_student_tile_Inst_network (
        .color_model_i(frame_select_i && frame_color_i),
        .clk_i(clk_i),.rst_n_i(rst_n_i && !frame_reset_i && (frame_select_i || (!reset_command && !burst_begin))),
        .input_valid_i(frame_select_i ? frame_input_valid_i : model_input_valid),.input_ready_o(input_ready),
        .input_pixel_i((frame_select_i ? frame_input_pixel_i : model_input_pixel) ^ 8'h80),
        .start_valid_i(frame_select_i ? frame_start_valid_i : (burst_job ? auto_start : start_command)),.start_ready_o(start_ready),
        .result_valid_o(result_valid),.result_ready_i(frame_select_i ? frame_result_ready_i : model_result_ready),
        .result_pixel_o(result_pixel),.result_address_o(result_address),.busy_o(busy),.done_o(done)
    );
    assign frame_input_ready_o=frame_select_i && input_ready;
    assign frame_start_ready_o=frame_select_i && start_ready;
    assign frame_result_valid_o=frame_select_i && result_valid;
    assign frame_result_pixel_o=result_pixel;
    assign frame_result_address_o=result_address;
    assign frame_core_busy_o=busy;
    function [31:0] crc_byte;
        input [31:0] previous;
        input [7:0] value;
        reg [31:0] work;
        integer bit;
        begin
            work=previous ^ value;
            for(bit=0;bit<8;bit=bit+1)work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc_byte=work;
        end
    endfunction

     
    reg [2:0] sclk_sync,cs_sync,mosi_sync;
    wire sclk_rise=sclk_sync[2:1]==2'b01;
    wire sclk_fall=sclk_sync[2:1]==2'b10;
    wire cs_rise=cs_sync[2:1]==2'b01;
    wire cs_fall=cs_sync[2:1]==2'b10;
    reg [1:0] transfer_mode;
    reg [2:0] bit_count;
    reg [9:0] byte_count;
    reg [7:0] rx_shift,tx_shift;
    reg [7:0] result_ram_read,result_crc_read;
    reg result_read_is_payload;
    wire [7:0] next_result_byte=result_read_is_payload ? result_ram_read : result_crc_read;
    reg [31:0] input_crc,received_crc;
    reg input_committed;
    wire [7:0] received_byte={rx_shift[6:0],mosi_sync[2]};
    assign stream_miso_o=spi_cs_n_i ? 1'b0 : tx_shift[7];

     
    always @(posedge clk_i)begin
        if(transfer_mode==2 && byte_count<768)result_ram_read<=result_buffer[byte_count];
        if(transfer_mode==2 && byte_count<772)result_read_is_payload<=byte_count<768;
        if(transfer_mode==2 && byte_count==768)result_crc_read<=~result_crc[7:0];
        if(transfer_mode==2 && byte_count==769)result_crc_read<=~result_crc[15:8];
        if(transfer_mode==2 && byte_count==770)result_crc_read<=~result_crc[23:16];
        if(transfer_mode==2 && byte_count==771)result_crc_read<=~result_crc[31:24];
        if(feed_active && !feed_valid && feed_index<768)feed_pixel<=input_buffer[feed_index];
        if(transfer_mode==1 && !cs_sync[2] && sclk_rise && bit_count==7 && byte_count<768)
            input_buffer[byte_count]<=received_byte;
        if(!frame_select_i && burst_job && result_valid && model_result_ready)result_buffer[collected]<=result_pixel;
    end

    always @(posedge clk_i or negedge rst_n_i)begin
        if(!rst_n_i)begin
            sclk_sync<=0;cs_sync<=7;mosi_sync<=0;
            transfer_mode<=0;bit_count<=0;byte_count<=0;rx_shift<=0;tx_shift<=0;
            input_crc<=32'hffffffff;received_crc<=0;input_committed<=0;
            error<=0;complete<=0;burst_job<=0;feed_active<=0;feed_valid<=0;auto_start<=0;
            input_count<=0;feed_index<=0;collected<=0;result_crc<=32'hffffffff;
        end else begin
            sclk_sync<={sclk_sync[1:0],spi_sclk_i};cs_sync<={cs_sync[1:0],spi_cs_n_i};mosi_sync<={mosi_sync[1:0],spi_mosi_i};
            auto_start<=0;
            if(frame_reset_i || reset_command || burst_begin)begin
                error<=0;complete<=0;input_count<=0;feed_index<=0;collected<=0;
                burst_job<=burst_begin;feed_active<=0;feed_valid<=0;
                input_committed<=0;result_crc<=32'hffffffff;
            end else begin
                if(!frame_select_i && !burst_job)begin
                    if(input_command && input_ready)begin input_count<=input_count+1'b1;complete<=0;end
                    if((input_command && !input_ready)||(start_command && !start_ready)||(result_command && !result_valid))error<=1;
                    if(start_command && start_ready)complete<=0;
                    if(done)begin complete<=1;input_count<=0;end
                end
                if(feed_active && !feed_valid)feed_valid<=1;
                if(feed_valid && input_ready)begin
                    feed_valid<=0;feed_index<=feed_index+1'b1;
                    if(feed_index==767)begin feed_active<=0;auto_start<=1;end
                end
                if(!frame_select_i && burst_job && result_valid && model_result_ready)begin
                    if(result_address!=collected)error<=1;
                    collected<=collected+1'b1;result_crc<=crc_byte(result_crc,result_pixel);
                    if(collected==767)complete<=1;
                end
            end
            if(cs_fall)begin
                transfer_mode<=stream_select_i;bit_count<=0;byte_count<=0;rx_shift<=0;
                input_crc<=32'hffffffff;received_crc<=0;
                if(stream_select_i==2)begin
                    if(!complete || error)begin error<=1;transfer_mode<=0;end
                     
                    tx_shift<=0;
                end
            end
             
            if(transfer_mode==2 && byte_count==0 && bit_count==0 && !sclk_sync[2])tx_shift<=next_result_byte;
            if(transfer_mode!=0 && !cs_sync[2] && sclk_rise)begin
                rx_shift<=received_byte;bit_count<=bit_count+1'b1;
                if(bit_count==7)begin
                    if(byte_count<772)byte_count<=byte_count+1'b1;
                    else error<=1;
                    if(transfer_mode==1)begin
                        if(byte_count<768)input_crc<=crc_byte(input_crc,received_byte);
                        case(byte_count)
                            768:received_crc[7:0]<=received_byte;
                            769:received_crc[15:8]<=received_byte;
                            770:received_crc[23:16]<=received_byte;
                            771:received_crc[31:24]<=received_byte;
                        endcase
                    end
                end
            end
            if(transfer_mode==2 && !cs_sync[2] && sclk_fall)begin
                if(bit_count==0)tx_shift<=next_result_byte;
                else tx_shift<={tx_shift[6:0],1'b0};
            end
            if(cs_rise && transfer_mode!=0)begin
                if(byte_count!=772 || bit_count!=0)error<=1;
                else if(transfer_mode==1)begin
                    if(received_crc!=~input_crc || !burst_job || input_committed || error)error<=1;
                    else begin input_committed<=1;feed_active<=1;feed_index<=0;end
                end
                transfer_mode<=0;
            end
        end
    end
    always @(*)begin
        case(read_address_i)
            7'h40:read_data_o=8'h61;
            7'h43:read_data_o={2'b00,error,complete,result_valid,busy,start_ready,input_ready};
            7'h44:read_data_o=input_count[7:0];
            7'h45:read_data_o={6'd0,input_count[9:8]};
            7'h46:read_data_o=result_address[7:0];
            7'h47:read_data_o={6'd0,result_address[9:8]};
            7'h48:read_data_o=result_pixel;
            7'h49:read_data_o=8'd16;
            7'h4a:read_data_o=8'd4;
            7'h4b:read_data_o=8'h62;
            default:read_data_o=0;
        endcase
    end
endmodule
