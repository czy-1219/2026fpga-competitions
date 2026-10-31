`timescale 1ns/1ps
 

module full_student_div64(
 input wire clk_i,rst_n_i,valid_i,output wire ready_o,
 input wire signed [63:0] numerator_i,input wire [63:0] denominator_i,
 output reg valid_o,input wire ready_i,output reg signed [63:0] quotient_o,output reg error_o
);
 reg busy,negative;reg [6:0] count;reg [63:0] dividend,divisor,quotient;reg [64:0] remainder;
 wire [64:0] trial={remainder[63:0],dividend[63]};wire bit_q=trial>={1'b0,divisor};
 wire [64:0] next_rem=bit_q ? trial-{1'b0,divisor} : trial;
 wire [63:0] next_q={quotient[62:0],bit_q};
 wire [65:0] twice={next_rem,1'b0};
 wire inc=twice>{2'b0,divisor} || (twice=={2'b0,divisor} && next_q[0]);
 wire [63:0] rounded=next_q+{63'd0,inc};
 assign ready_o=!busy && !valid_o;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin busy<=0;negative<=0;count<=0;dividend<=0;divisor<=0;quotient<=0;remainder<=0;valid_o<=0;quotient_o<=0;error_o<=0;end
  else begin
   if(valid_o && ready_i)valid_o<=0;
   if(valid_i && ready_o)begin
    negative<=numerator_i[63];dividend<=numerator_i[63] ? -numerator_i : numerator_i;
    divisor<=denominator_i;quotient<=0;remainder<=0;count<=0;error_o<=denominator_i==0;
    if(denominator_i==0)begin quotient_o<=0;valid_o<=1;end else busy<=1;
   end else if(busy)begin
    remainder<=next_rem;quotient<=next_q;dividend<=dividend<<1;count<=count+1;
    if(count==63)begin busy<=0;quotient_o<=negative ? -$signed(rounded) : $signed(rounded);valid_o<=1;end
   end
  end
 end
endmodule
