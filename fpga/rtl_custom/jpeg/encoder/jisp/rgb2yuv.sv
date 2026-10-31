/*
 * RGB to Y Cb Cr conversion
 *
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
`include "rtl_custom/jpeg/encoder/jpeg_encoder.vh"
module rgb2yuv #(
    parameter DW    = 8,
    parameter MW    = 8
)(
    input   logic unsigned[DW-1:0]  rgb24[2:0],  
    input   logic               rgb24_valid,
    output  logic               rgb24_hold,
    input   logic               frame_valid_in,
    input   logic               line_valid_in,
    output  logic unsigned[DW-1:0]  yuv[2:0],  
    output  logic               yuv_valid,
    input   logic               yuv_hold,
    output  logic               frame_valid_out,
    output  logic               line_valid_out,
    input   logic               clk,
    input   logic               resetn
);

localparam YW = DW + 2;  
always_comb assert (MW == 8) else $error();

 











 


logic unsigned[YW+MW-1:0]   k_rgb1[2:0], k_rgb0[2:0];  
logic unsigned[YW-1:0]      r0, b0;  
logic s0_valid;
logic frame_valid_0;
logic line_valid_0;

always_comb begin
`ifndef RGB2YUV_USE_DSP_MULT
    k_rgb0[0] = (rgb24[0] << 6) + (rgb24[0] << 3) + (rgb24[0] << 2) + (rgb24[0] << 0);        
    k_rgb0[1] = (rgb24[1] << 7) + (rgb24[1] << 4) + (rgb24[1] << 2) + (rgb24[1] << 1);        
    k_rgb0[2] = (rgb24[2] << 4) + (rgb24[2] << 3) + (rgb24[2] << 2) + (rgb24[2] << 0);        
`else
    k_rgb0[0] =  77 * rgb24[0];
    k_rgb0[1] = 150 * rgb24[1];
    k_rgb0[2] =  29 * rgb24[2];
`endif  
end

always @(posedge clk)
if (rgb24_valid & !yuv_hold) begin
    r0 <= rgb24[0];
    b0 <= rgb24[2];
    k_rgb1[0] <= k_rgb0[0];
    k_rgb1[1] <= k_rgb0[1];
    k_rgb1[2] <= k_rgb0[2];
end

always @(posedge clk)
if (!resetn) begin
    s0_valid <= 0;
    frame_valid_0 <= 0;
    line_valid_0 <= 0;
end
else if (!yuv_hold) begin
    s0_valid <= rgb24_valid;
    frame_valid_0 <= frame_valid_in;
    line_valid_0 <= line_valid_in;
end

 



logic unsigned[YW+MW-1:0]   sum_k_rgb;
logic unsigned[YW-1:0]      y0, y1;
logic signed[YW+MW-1:0]     u0, v0, u1, v1;
logic s1_valid;
logic frame_valid_1;
logic line_valid_1;

always_comb begin
    sum_k_rgb = k_rgb1[0] + k_rgb1[1] + k_rgb1[2];
    y0 = (sum_k_rgb + (1<<(MW - 1))) >> MW;
    u0 = (b0 << MW) - sum_k_rgb;
    v0 = (r0 << MW) - sum_k_rgb;
end

always @(posedge clk)
if (s0_valid & !yuv_hold) begin
    y1 <= y0;
    u1 <= u0;
    v1 <= v0;
end

always @(posedge clk)
if (!resetn) begin
    s1_valid <= 0;
    frame_valid_1 <= 0;
    line_valid_1 <= 0;
end
else if (!yuv_hold) begin
    s1_valid <= s0_valid;
    frame_valid_1 <= frame_valid_0;
    line_valid_1 <= line_valid_0;
end

 



parameter signed[MW:0]   kcb = 144;
parameter signed[MW:0]   kcr = 182;

logic signed[YW+2*MW-1:0]   cb1, cr1;
logic signed[YW-1:0]        cb2, cr2;
logic unsigned[YW-1:0]      y2;

always_comb begin
`ifndef RGB2YUV_USE_DSP_MULT
    cb1 = (128 << (2*MW)) + (u1 << 7) + (u1 << 4);                                       
    cr1 = (128 << (2*MW)) + (v1 << 7) + (v1 << 5) + (v1 << 4) + (v1 << 2) + (v1 << 1);   
`else
    cb1 = (128 << (2*MW)) + (kcb * u1);
    cr1 = (128 << (2*MW)) + (kcr * v1);
`endif  
    
    y2 = y1;
    cb2 = (cb1 + (1<<((2*MW) - 1))) >> (2*MW);
    cr2 = (cr1 + (1<<((2*MW) - 1))) >> (2*MW);
end

always @(posedge clk)
if (s1_valid & !yuv_hold) begin
    yuv[0] <= y2 > 255 ? 255 : y2;
    yuv[1] <= cb2 < 0 ? 0 : cb2 > 255 ? 255 : cb2;
    yuv[2] <= cr2 < 0 ? 0 : cr2 > 255 ? 255 : cr2;
end

always @(posedge clk)
if (!resetn) begin
    yuv_valid <= 0;
    frame_valid_out <= 0;
    line_valid_out <= 0;
end
else if (!yuv_hold) begin
    yuv_valid <= s1_valid;
    frame_valid_out <= frame_valid_1;
    line_valid_out <= line_valid_1;
end
always_comb rgb24_hold = yuv_hold;
endmodule
