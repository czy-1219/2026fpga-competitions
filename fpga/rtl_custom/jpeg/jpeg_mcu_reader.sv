`timescale 1ns/1ps
 

module jpeg_mcu_reader #(
    parameter [31:0] BASE = 32'h0280_0000
)(
    input wire clk,rst_n,start_i,
    input wire [10:0] width_i,height_i,
    input wire half_scale_i,
    input wire source_camera_i,
    input wire [31:0] camera_base_i,
    output reg busy_o,done_o,error_o,
    output reg [31:0] araddr_o,
    output reg arvalid_o,input wire arready_i,
    input wire [127:0] rdata_i,input wire rvalid_i,
    input wire [1:0] rresp_i,output wire rready_o,
    output wire [7:0] data_o,output wire valid_o,input wire ready_i
);
    reg [10:0] width,height,tile_x,tile_y;
    reg [3:0] row,byte_index;
    reg [1:0] half;reg half_scale,waiting,word_valid;
    reg source_camera;reg [31:0] frame_base;
    wire [127:0] camera_order;
    genvar k;generate for(k=0;k<8;k=k+1)begin
        assign camera_order[k*16+:16]=rdata_i[(7-k)*16+:16];
    end endgenerate
    wire [127:0] incoming=source_camera ? camera_order : rdata_i;
    reg [127:0] next_data;
    reg next_valid,word_last,next_last,read_last,all_issued;
    wire [10:0] output_width=half_scale ? (width>>1) : width;
    wire [10:0] output_height=half_scale ? (height>>1) : height;
    reg [127:0] word_data;
    wire [11:0] output_y={1'b0,tile_y}+row;
    wire [11:0] source_y=half_scale ? output_y<<1 : output_y;
    wire [10:0] clipped_y=source_y>=height ? height-(half_scale ? 11'd2 : 11'd1) : source_y[10:0];
    wire [31:0] pixel_offset=clipped_y*width+(half_scale ? {tile_x,1'b0} : {1'b0,tile_x})+{half,3'b0};
    wire finish_word=valid_o && ready_i && byte_index==(half_scale ? 13 : 15);
    wire final_read=half==(half_scale ? 3 : 1) && row==15 && tile_x+16>=output_width && tile_y+16>=output_height;
     

    assign rready_o=waiting && !next_valid;
    assign data_o=word_data[7:0];
    assign valid_o=word_valid && busy_o;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            source_camera<=0;frame_base<=BASE;half_scale<=0;width<=0;height<=0;tile_x<=0;tile_y<=0;row<=0;half<=0;
            busy_o<=0;done_o<=0;error_o<=0;araddr_o<=0;arvalid_o<=0;
            waiting<=0;word_valid<=0;word_data<=0;byte_index<=0;
            next_data<=0;next_valid<=0;word_last<=0;next_last<=0;read_last<=0;all_issued<=0;
        end else begin
            done_o<=0;
            if(start_i && !busy_o) begin
                source_camera<=source_camera_i;frame_base<=source_camera_i ? camera_base_i : BASE;
                half_scale<=half_scale_i;width<=width_i;height<=height_i;tile_x<=0;tile_y<=0;row<=0;half<=0;
                busy_o<=1;error_o<=0;arvalid_o<=0;waiting<=0;word_valid<=0;byte_index<=0;
                next_valid<=0;word_last<=0;next_last<=0;read_last<=0;all_issued<=0;
            end else if(busy_o) begin
                if((!next_valid || finish_word) && !waiting && !arvalid_o && !all_issued) begin
                    araddr_o<=frame_base+(pixel_offset<<1);arvalid_o<=1;
                end
                if(arvalid_o && arready_i) begin
                    arvalid_o<=0;waiting<=1;read_last<=final_read;
                    if(final_read)all_issued<=1;
                    half<=half+1'b1;
                    if(half==(half_scale ? 3 : 1))begin
                        half<=0;row<=row+1'b1;
                        if(row==15)begin
                            if(tile_x+16>=output_width)begin tile_x<=0;tile_y<=tile_y+16;end
                            else tile_x<=tile_x+16;
                        end
                    end
                end
                if(valid_o && ready_i) begin
                    word_data <= half_scale && byte_index[0] ? {24'd0,word_data[127:24]} : {8'd0,word_data[127:8]};
                    byte_index<=byte_index+(half_scale && byte_index[0] ? 4'd3 : 4'd1);
                    if(finish_word) begin
                        word_valid<=next_valid;byte_index<=0;
                        if(next_valid)begin word_data<=next_data;word_last<=next_last;next_valid<=0;end
                        if(word_last)begin busy_o<=0;done_o<=1;word_valid<=0;end
                    end
                end
                if(rvalid_i && rready_o)begin
                    waiting<=0;
                    if(!word_valid || finish_word)begin word_valid<=1;word_data<=incoming;word_last<=read_last;byte_index<=0;end
                    else begin next_valid<=1;next_data<=incoming;next_last<=read_last;end
                    if(rresp_i!=0)error_o<=1;
                end
            end
        end
    end
endmodule
