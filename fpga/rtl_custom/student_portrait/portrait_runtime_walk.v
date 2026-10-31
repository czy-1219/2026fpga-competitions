`timescale 1ns / 1ps

 

module portrait_runtime_walk (
    input [7:0] width_i, height_i,
    input [5:0] channels_i,
    input [1:0] output_groups_i, kernel_i,
    input wire clk_i,
    input wire rst_n_i,
    input wire start_valid_i,
    output wire start_ready_o,
    output wire term_valid_o,
    input wire term_ready_i,
    output wire padding_o,
    output wire [31:0] activation_address_o,
    output wire [31:0] weight_address_o,
    output wire [31:0] output_address_o,
    output wire [9:0] cache_address_o,
    output wire term_last_o,
    output wire layer_last_o
);
    reg [7:0] WIDTH, HEIGHT;
    reg [5:0] CHANNELS;
    reg [1:0] OUTPUT_CHANNELS, KERNEL;
    reg [2:0] width_shift;
    wire signed [31:0] source_pixel;
    wire [31:0] output_pixel, kernel_pixel, term_count;
    reg [31:0] source_base, kernel_base;
    reg active;
    reg [10:0] column, row;
    reg [6:0] input_channel, output_channel;
    reg [1:0] kernel_column, kernel_row;
    reg [9:0] cache_address;
    wire accept;
    wire last_input, last_kernel_column, last_kernel_row;
    wire last_output, last_column, last_row;
    wire signed [31:0] source_column, source_row;

    assign start_ready_o = rst_n_i && !active;
    assign term_valid_o = rst_n_i && active;
    assign accept = term_valid_o && term_ready_i;
    assign last_input = input_channel == CHANNELS - 1;
    assign last_kernel_column = kernel_column == KERNEL - 1;
    assign last_kernel_row = kernel_row == KERNEL - 1;
    assign last_output = output_channel == OUTPUT_CHANNELS - 1;
    assign last_column = column == WIDTH - 1;
    assign last_row = row == HEIGHT - 1;
    assign source_column = $signed({21'd0, column}) + $signed({30'd0, kernel_column}) - (KERNEL / 2);
    assign source_row = $signed({21'd0, row}) + $signed({30'd0, kernel_row}) - (KERNEL / 2);
    assign padding_o = source_column < 0 || source_row < 0 || source_column >= WIDTH || source_row >= HEIGHT;
     
    assign source_pixel = (source_row <<< width_shift) + source_column;
    assign output_pixel = (row << width_shift) + column;
    assign kernel_pixel = (KERNEL == 3) ? (kernel_row + (kernel_row << 1) + kernel_column) : 32'd0;
    assign term_count = (KERNEL == 3) ? ((CHANNELS << 3) + CHANNELS) : CHANNELS;
    always @(*) begin
        case (CHANNELS)
            6'd3: begin source_base = source_pixel + (source_pixel << 1); kernel_base = kernel_pixel + (kernel_pixel << 1); end
            6'd16: begin source_base = source_pixel << 4; kernel_base = kernel_pixel << 4; end
            default: begin source_base = source_pixel << 5; kernel_base = kernel_pixel << 5; end
        endcase
    end
    assign activation_address_o = padding_o ? 32'd0 : source_base + input_channel;
    assign weight_address_o = (output_channel == 0 ? 32'd0 : term_count) + kernel_base + input_channel;
    assign output_address_o = ((OUTPUT_CHANNELS == 2) ? (output_pixel << 1) : output_pixel) + output_channel;
    assign cache_address_o = cache_address;
    assign term_last_o = last_input && last_kernel_column && last_kernel_row;
    assign layer_last_o = term_last_o && last_output && last_column && last_row;

     
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            active <= 1'b0;
            column <= 11'd0;
            row <= 11'd0;
            input_channel <= 7'd0;
            output_channel <= 7'd0;
            kernel_column <= 2'd0;
            kernel_row <= 2'd0;
            cache_address <= 10'd0;
        end else if (start_valid_i && start_ready_o) begin
            active <= 1'b1;
            WIDTH <= width_i; HEIGHT <= height_i; CHANNELS <= channels_i; OUTPUT_CHANNELS <= output_groups_i; KERNEL <= kernel_i;
            case(width_i)
                8'd1:width_shift<=0;8'd2:width_shift<=1;8'd4:width_shift<=2;8'd8:width_shift<=3;
                8'd16:width_shift<=4;8'd32:width_shift<=5;8'd64:width_shift<=6;default:width_shift<=7;
            endcase
            column <= 11'd0;
            row <= 11'd0;
            input_channel <= 7'd0;
            output_channel <= 7'd0;
            kernel_column <= 2'd0;
            kernel_row <= 2'd0;
            cache_address <= 10'd0;
        end else if (accept) begin
            cache_address <= term_last_o ? 10'd0 : cache_address + 1'b1;
            if (!last_input) input_channel <= input_channel + 1'b1;
            else begin
                input_channel <= 7'd0;
                if (!last_kernel_column) kernel_column <= kernel_column + 1'b1;
                else begin
                    kernel_column <= 2'd0;
                    if (!last_kernel_row) kernel_row <= kernel_row + 1'b1;
                    else begin
                        kernel_row <= 2'd0;
                        if (!last_output) output_channel <= output_channel + 1'b1;
                        else begin
                            output_channel <= 7'd0;
                            if (!last_column) column <= column + 1'b1;
                            else begin
                                column <= 11'd0;
                                if (!last_row) row <= row + 1'b1;
                                else begin row <= 11'd0; active <= 1'b0; end
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
