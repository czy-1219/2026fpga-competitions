`timescale 1ns/1ps
 

module student_compact_shared_conv(
 input wire clk_i,rst_n_i,input wire [2:0] layer_i,
 input wire start_valid_i,output wire start_ready_o,
 input wire signed [31:0] output_zero_i,
 output wire parameter_valid_o,input wire parameter_ready_i,output wire [6:0] parameter_channel_o,
 input wire parameter_response_valid_i,output wire parameter_response_ready_o,
 input wire [255:0] bias_i,multiplier_i,input wire [47:0] right_shift_i,
 output wire memory_valid_o,input wire memory_ready_i,
 output wire [31:0] activation_address_o,weight_address_o,output wire padding_o,
 input wire memory_response_valid_i,output wire memory_response_ready_o,
 input wire signed [7:0] activation_i,input wire [63:0] weight_i,
 output wire result_valid_o,input wire result_ready_i,output wire [31:0] result_address_o,
 output wire signed [7:0] pixel_o,output wire done_o
);
 localparam IDLE=0,PARAM=1,PARAM_WAIT=2,START=3,REQUEST=4,RESPONSE=5,QUANT=6,RESULT=7;
 reg [2:0] state;reg first,last;reg [3:0] x,y,oc,ic;reg [1:0] kx,ky;
 reg [31:0] output_address;reg signed [31:0] bias,multiplier,output_zero;reg [5:0] shift;
 wire [4:0] channels=first?5'd3:5'd16;
 wire signed [5:0] px=$signed({2'd0,x})+$signed({4'd0,kx})-(last?6'sd0:6'sd1);
 wire signed [5:0] py=$signed({2'd0,y})+$signed({4'd0,ky})-(last?6'sd0:6'sd1);
 wire [7:0] spatial={py[3:0],px[3:0]};
 wire [8:0] term_index={5'd0,ky}*9'd3+{7'd0,kx};
 wire [8:0] tap_index=(last?9'd0:term_index)+(oc[3]?9'd9:9'd0);
 assign activation_address_o=first?({24'd0,spatial}<<1)+{24'd0,spatial}+{28'd0,ic}:{20'd0,spatial,ic};
 assign weight_address_o=first?({23'd0,tap_index}<<1)+{23'd0,tap_index}+{28'd0,ic}:({23'd0,tap_index}<<4)+{28'd0,ic};
 assign padding_o=px<0||px>15||py<0||py>15;
 wire term_last=(ic==channels-1)&&(last || (kx==2&&ky==2));
 wire sr,tr,mv,qr,qv;wire signed [31:0] accumulator;
 assign start_ready_o=rst_n_i&&state==IDLE;
 assign parameter_valid_o=state==PARAM;assign parameter_response_ready_o=state==PARAM_WAIT;
 assign parameter_channel_o={6'd0,oc[3]};
 assign memory_valid_o=state==REQUEST;assign memory_response_ready_o=state==RESPONSE&&tr;
 assign result_valid_o=state==RESULT&&qv;assign result_address_o=output_address;
 assign done_o=result_valid_o&&result_ready_i&&x==15&&y==15&&oc==(last?2:15);
 student_serial_mac mac(.clk_i(clk_i),.rst_n_i(rst_n_i),.start_valid_i(state==START),.start_ready_o(sr),.bias_i(bias),
  .term_valid_i(state==RESPONSE&&memory_response_valid_i),.term_ready_o(tr),.activation_i(padding_o?-8'sd128:activation_i),.input_zero_i(-8'sd128),
  .weight_i(weight_i[oc[2:0]*8+:8]),.term_last_i(term_last),.result_valid_o(mv),.result_ready_i(state==QUANT&&qr),.accumulator_o(accumulator));
 student_requantize quant(.clk_i(clk_i),.rst_n_i(rst_n_i),.valid_i(state==QUANT&&mv),.ready_o(qr),.accumulator_i(accumulator),.multiplier_i(multiplier),.right_shift_i(shift),
  .output_zero_i(output_zero),.minimum_i(-8'sd128),.maximum_i(8'sd127),.valid_o(qv),.ready_i(state==RESULT&&result_ready_i),.pixel_o(pixel_o));
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin state<=IDLE;first<=0;last<=0;x<=0;y<=0;oc<=0;ic<=0;kx<=0;ky<=0;output_address<=0;bias<=0;multiplier<=0;shift<=0;output_zero<=0;end
  else case(state)
   IDLE:if(start_valid_i)begin first<=layer_i==0;last<=layer_i==4;x<=0;y<=0;oc<=0;output_address<=0;output_zero<=output_zero_i;state<=PARAM;end
   PARAM:if(parameter_ready_i)state<=PARAM_WAIT;
   PARAM_WAIT:if(parameter_response_valid_i)begin bias<=bias_i[oc[2:0]*32+:32];multiplier<=multiplier_i[oc[2:0]*32+:32];shift<=right_shift_i[oc[2:0]*6+:6];state<=START;end
   START:if(sr)begin ic<=0;kx<=0;ky<=0;state<=REQUEST;end
   REQUEST:if(memory_ready_i)state<=RESPONSE;
   RESPONSE:if(memory_response_valid_i&&tr)begin
    if(term_last)state<=QUANT;
    else begin
     if(ic==channels-1)begin ic<=0;if(kx==2)begin kx<=0;ky<=ky+1;end else kx<=kx+1;end else ic<=ic+1;
     state<=REQUEST;
    end
   end
   QUANT:if(mv&&qr)state<=RESULT;
   RESULT:if(qv&&result_ready_i)begin
    if(done_o)state<=IDLE;
    else begin output_address<=output_address+1;state<=PARAM;
     if(oc==(last?2:15))begin oc<=0;if(x==15)begin x<=0;y<=y+1;end else x<=x+1;end else oc<=oc+1;
    end
   end
  endcase
 end
endmodule
