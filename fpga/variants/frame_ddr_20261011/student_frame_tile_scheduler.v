`timescale 1ns/1ps
 




module student_frame_tile_scheduler #(
    parameter integer MAX_WIDTH = 1920,
    parameter integer MAX_HEIGHT = 1080
) (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        start_i,
    input  wire [15:0] width_i,
    input  wire [15:0] height_i,
    input  wire [31:0] input_base_i,
    input  wire [31:0] output_base_i,
    output wire        input_mem_req_o,
    output wire [31:0] input_mem_addr_o,
    output wire [1:0] input_mem_channel_o,
    input  wire        input_mem_valid_i,
    input  wire [7:0]  input_mem_data_i,
    output wire        tile_input_valid_o,
    output wire [9:0]  tile_input_index_o,
    output wire [7:0]  tile_input_data_o,
    input  wire        tile_input_ready_i,
    output wire        tile_start_valid_o,
    input  wire        tile_start_ready_i,
    input  wire        tile_result_valid_i,
    input  wire [9:0]  tile_result_index_i,
    input  wire [7:0]  tile_result_data_i,
    output wire        tile_result_ready_o,
    output wire        result_valid_o,
    output wire [31:0] result_addr_o,
    output wire [1:0] result_channel_o,
    output wire [7:0]  result_data_o,
    input  wire        result_ready_i,
    output wire        busy_o,
    output wire        done_o
);
    localparam [3:0] S_IDLE=0,S_READ=1,S_FEED=2,S_START=3,S_RESULT=4,S_NEXT=5,S_DONE=6;
    reg [3:0] state;
    reg [15:0] width,height,tile_x,tile_y,row,col,channel;
    reg [31:0] input_base,output_base;
    reg [9:0] tile_index;
    reg [7:0] tile_byte;

     
    wire [15:0] origin_x = (width <= 16 || tile_x < 4) ? 0 :
        (tile_x - 4 > width - 16 ? width - 16 : tile_x - 4);
    wire [15:0] origin_y = (height <= 16 || tile_y < 4) ? 0 :
        (tile_y - 4 > height - 16 ? height - 16 : tile_y - 4);
    wire [15:0] read_x_raw = origin_x + col;
    wire [15:0] read_y_raw = origin_y + row;
    wire [15:0] read_x = read_x_raw < width ? read_x_raw : width - 1'b1;
    wire [15:0] read_y = read_y_raw < height ? read_y_raw : height - 1'b1;
    wire [9:0] result_pixel_index = tile_result_index_i / 3;
    wire [1:0] result_channel = tile_result_index_i % 3;
    wire [15:0] result_x = origin_x + (result_pixel_index % 16);
    wire [15:0] result_y = origin_y + (result_pixel_index / 16);
    wire result_pixel_valid = result_x >= tile_x && result_x < tile_x + 8 && result_x < width &&
                              result_y >= tile_y && result_y < tile_y + 8 && result_y < height;
    wire [31:0] read_addr = input_base + ((read_y * width + read_x) * 2);
    wire [31:0] write_addr = output_base + ((result_y * width + result_x) * 2);
    assign input_mem_req_o = state == S_READ;
    assign input_mem_addr_o = read_addr;
    assign input_mem_channel_o = channel[1:0];
    assign tile_input_valid_o = state == S_FEED;
    assign tile_input_index_o = tile_index;
    assign tile_input_data_o = tile_byte;
    assign tile_start_valid_o = state == S_START;
    assign tile_result_ready_o = state == S_RESULT && result_ready_i;
    assign result_valid_o = state == S_RESULT && tile_result_valid_i && result_pixel_valid;
    assign result_addr_o = write_addr;
    assign result_channel_o = result_channel;
    assign result_data_o = tile_result_data_i;
    assign busy_o = state != S_IDLE && state != S_DONE;
    assign done_o = state == S_DONE;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state<=S_IDLE; width<=0; height<=0; input_base<=0; output_base<=0;
            tile_x<=0; tile_y<=0; row<=0; col<=0; channel<=0; tile_index<=0; tile_byte<=0;
        end else begin
            case (state)
                S_IDLE: if (start_i && width_i!=0 && height_i!=0 && width_i<=MAX_WIDTH && height_i<=MAX_HEIGHT) begin
                    width<=width_i; height<=height_i; input_base<=input_base_i; output_base<=output_base_i;
                    tile_x<=0; tile_y<=0; row<=0; col<=0; channel<=0; tile_index<=0; state<=S_READ;
                end
                 

                S_READ: if (input_mem_valid_i) begin
                    tile_byte<=input_mem_data_i;
                    state<=S_FEED;
                end
                S_FEED: if (tile_input_ready_i) begin
                    if (tile_index==10'd767) begin tile_index<=0;state<=S_START;end
                    else begin
                        tile_index<=tile_index+1'b1;state<=S_READ;
                        if(channel==2)begin
                            channel<=0;
                            if(col==15)begin col<=0;row<=row+1'b1;end
                            else col<=col+1'b1;
                        end else channel<=channel+1'b1;
                    end
                end
                S_START: if (tile_start_ready_i) begin tile_index<=0; state<=S_RESULT; end
                S_RESULT: if (tile_result_valid_i && result_ready_i) begin
                    if (tile_result_index_i==10'd767) state<=S_NEXT;
                end
                S_NEXT: begin
                    if (tile_x+8 >= width) begin
                        tile_x<=0;
                        if (tile_y+8 >= height) state<=S_DONE;
                        else begin tile_y<=tile_y+8; row<=0; col<=0; channel<=0; tile_index<=0; state<=S_READ; end
                    end else begin tile_x<=tile_x+8; row<=0; col<=0; channel<=0; tile_index<=0; state<=S_READ; end
                end
                S_DONE: if (!start_i) state<=S_IDLE;
                default: state<=S_IDLE;
            endcase
        end
    end
endmodule
