`timescale 1ns/1ps
 
module full_student_mul32(
 input wire clk_i,rst_n_i,valid_i,output wire ready_o,
 input wire signed [31:0] a_i,b_i,
 output reg valid_o,input wire ready_i,output reg signed [63:0] product_o
);
 reg busy,negative;reg [1:0] step;
 reg [31:0] a,b;reg [63:0] sum;
 wire [15:0] aa=step[0] ? a[31:16] : a[15:0];
 wire [15:0] bb=step[1] ? b[31:16] : b[15:0];
 wire [31:0] partial=aa*bb;
 wire [63:0] aligned=step==0 ? {32'd0,partial} : step==3 ? {partial,32'd0} : {16'd0,partial,16'd0};
 wire [63:0] combined=sum+aligned;
 assign ready_o=!busy && !valid_o;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin busy<=0;negative<=0;step<=0;a<=0;b<=0;sum<=0;valid_o<=0;product_o<=0;end
  else begin
   if(valid_o && ready_i)valid_o<=0;
   if(valid_i && ready_o)begin
    a<=a_i[31] ? -a_i : a_i;b<=b_i[31] ? -b_i : b_i;negative<=a_i[31]^b_i[31];
    sum<=0;step<=0;busy<=1;
   end
   if(busy)begin
    sum<=combined;step<=step+1;
    if(step==3)begin product_o<=negative ? -combined : combined;valid_o<=1;busy<=0;end
   end
  end
 end
endmodule
