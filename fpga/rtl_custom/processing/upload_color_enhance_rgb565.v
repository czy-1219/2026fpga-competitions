`timescale 1ns/1ps
 

module upload_color_enhance_rgb565(input wire [15:0] pixel_i,output wire [15:0] pixel_o);
 function [7:0] tone;
  input [7:0] value;
  reg signed [9:0] delta,adjusted;
  begin
   delta=$signed({2'b00,value})-10'sd128;
   adjusted=$signed({2'b00,value})+((delta+10'sd8)>>>4);
   tone=adjusted<0?8'd0:adjusted>255?8'd255:adjusted[7:0];
  end
 endfunction
 wire [7:0] r=tone({pixel_i[15:11],pixel_i[15:13]});
 wire [7:0] g=tone({pixel_i[10:5],pixel_i[10:9]});
 wire [7:0] b=tone({pixel_i[4:0],pixel_i[4:2]});
 assign pixel_o={r[7:3],g[7:2],b[7:3]};
endmodule
