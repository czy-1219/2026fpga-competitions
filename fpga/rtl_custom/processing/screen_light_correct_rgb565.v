`timescale 1ns/1ps

 






module screen_light_correct_rgb565 #(
    parameter integer GAIN_R_Q8 = 256,
    parameter integer GAIN_G_Q8 = 256,
    parameter integer GAIN_B_Q8 = 256,
    parameter integer HIGHLIGHT_LIMIT = 248,
    parameter integer DETAIL_SHIFT = 5
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pixel_valid_i,
    input  wire [15:0] pixel_i,
    output reg         pixel_valid_o,
    output reg  [15:0] pixel_o
);
    reg [7:0] r8, g8, b8;
    reg [15:0] r_gain, g_gain, b_gain;
    reg [8:0] y_est;
    reg [7:0] r_out, g_out, b_out;
    reg [7:0] max_rgb;

    function [7:0] sat8;
        input integer value;
        begin
            if (value < 0) sat8 = 8'd0;
            else if (value > 255) sat8 = 8'd255;
            else sat8 = value[7:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid_o <= 1'b0;
            pixel_o <= 16'd0;
        end else begin
            pixel_valid_o <= pixel_valid_i;
            if (pixel_valid_i) begin
                r8 = {pixel_i[15:11], 3'b0};
                g8 = {pixel_i[10:5], 2'b0};
                b8 = {pixel_i[4:0], 3'b0};
                r_gain = r8 * GAIN_R_Q8;
                g_gain = g8 * GAIN_G_Q8;
                b_gain = b8 * GAIN_B_Q8;
                r_out = sat8(r_gain >> 8);
                g_out = sat8(g_gain >> 8);
                b_out = sat8(b_gain >> 8);

                 

                max_rgb = (r_out > g_out) ? ((r_out > b_out) ? r_out : b_out)
                                           : ((g_out > b_out) ? g_out : b_out);
                if (max_rgb > HIGHLIGHT_LIMIT) begin
                    r_out = sat8((r_out + HIGHLIGHT_LIMIT) >> 1);
                    g_out = sat8((g_out + HIGHLIGHT_LIMIT) >> 1);
                    b_out = sat8((b_out + HIGHLIGHT_LIMIT) >> 1);
                end

                 


                y_est = (r_out * 77 + g_out * 150 + b_out * 29) >> 8;
                if (y_est > 8'd128) begin
                    r_out = sat8(r_out + DETAIL_SHIFT);
                    g_out = sat8(g_out + DETAIL_SHIFT);
                    b_out = sat8(b_out + DETAIL_SHIFT);
                end
                pixel_o <= {r_out[7:3], g_out[7:2], b_out[7:3]};
            end
        end
    end
endmodule
