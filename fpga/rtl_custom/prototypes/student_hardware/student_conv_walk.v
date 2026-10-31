`timescale 1ns / 1ps

 

module student_conv_walk #(
    parameter WIDTH = 8,
    parameter HEIGHT = 6,
    parameter CHANNELS = 3,
    parameter OUTPUT_CHANNELS = 4,
    parameter KERNEL = 3
) (
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
     
    assign activation_address_o = padding_o ? 32'd0 : (source_row * WIDTH + source_column) * CHANNELS + input_channel;
    assign weight_address_o = ((output_channel * KERNEL + kernel_row) * KERNEL + kernel_column) * CHANNELS + input_channel;
    assign output_address_o = (row * WIDTH + column) * OUTPUT_CHANNELS + output_channel;
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
