`timescale 1ns/1ps

 


module scan_rgb565_pixel (
    input  wire [15:0] pixel_i,
    input  wire [7:0]  background_i,
    input  wire [7:0]  ink_margin_i,
    input  wire [1:0]  mode_i,
    output wire [15:0] pixel_o,
    output wire [7:0]  luminance_o
);
    wire [7:0] red = {pixel_i[15:11], pixel_i[15:13]};
    wire [7:0] green = {pixel_i[10:5], pixel_i[10:9]};
    wire [7:0] blue = {pixel_i[4:0], pixel_i[4:2]};
     

    (* syn_use_dsp = "no" *) wire [15:0] weighted_red = red * 8'd77;
    (* syn_use_dsp = "no" *) wire [15:0] weighted_green = green * 8'd150;
    (* syn_use_dsp = "no" *) wire [15:0] weighted_blue = blue * 8'd29;
    wire [15:0] weighted = weighted_red + weighted_green + weighted_blue;
    wire [7:0] luminance = weighted[15:8];
     

    wire dark_ink = ({1'b0, luminance} + {1'b0, ink_margin_i} <
                     {1'b0, background_i})
                  && (luminance < 8'd200);
    wire lighten = ({1'b0, luminance} > {1'b0, background_i} + 9'd12)
                 && (luminance > 8'd80);
    wire darken = ({1'b0, luminance} + 9'd12 < {1'b0, background_i})
                && (luminance < 8'd180);
    wire [4:0] red_color = lighten && pixel_i[15:11] < 5'd31 ? pixel_i[15:11] + 5'd1 :
                           darken && pixel_i[15:11] > 5'd0 ? pixel_i[15:11] - 5'd1 : pixel_i[15:11];
    wire [5:0] green_color = lighten && pixel_i[10:5] < 6'd62 ? pixel_i[10:5] + 6'd2 :
                             darken && pixel_i[10:5] > 6'd1 ? pixel_i[10:5] - 6'd2 : pixel_i[10:5];
    wire [4:0] blue_color = lighten && pixel_i[4:0] < 5'd31 ? pixel_i[4:0] + 5'd1 :
                            darken && pixel_i[4:0] > 5'd0 ? pixel_i[4:0] - 5'd1 : pixel_i[4:0];

    assign luminance_o = luminance;
    assign pixel_o = mode_i == 2'd1 ? (dark_ink ? 16'h0000 : 16'hffff) :
                     mode_i == 2'd2 ? {red_color, green_color, blue_color} : pixel_i;
endmodule
