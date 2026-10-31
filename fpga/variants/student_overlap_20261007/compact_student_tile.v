`timescale 1ns/1ps
`include "rtl_custom/processing/student_compact_shared_conv.v"
 

module compact_student_tile #(parameter COLOR_BANK=0) (
 input wire clk_i,rst_n_i,
 input wire input_valid_i,output wire input_ready_o,input wire signed[7:0] input_pixel_i,
 input wire start_valid_i,output wire start_ready_o,
 output wire result_valid_o,input wire result_ready_i,
 output wire signed[7:0] result_pixel_o,output wire[9:0] result_address_o,
 output wire busy_o,output wire done_o,
 input wire color_model_i
);
localparam[3:0] IDLE=0,START=1,RUN=2,ADD_READ=3,ADD_START=4,ADD_WAIT=5,OUTPUT_READ=6,OUTPUT=7,
 EDGE_LEFT=8,EDGE_RIGHT=9,EDGE_UP=10,EDGE_DOWN=11,EDGE_FINISH=12;
 
reg color_latched;
wire use_color=(COLOR_BANK!=0) && color_latched;
reg[3:0] state;reg[2:0] layer_select;reg[9:0] input_count,add_address,output_address;
reg signed[7:0] input_memory[0:767];
reg signed[7:0] feature_first[0:4095],feature_second[0:4095];
reg signed[7:0] residual_memory[0:767],output_memory[0:767];
 

(* syn_ramstyle = "block_ram" *) reg [7:0] edge_luma[0:255];
reg [7:0] luma_read,luma_min,luma_max,input_pixel_index;
reg [1:0] input_component,add_component;
reg [3:0] add_column,add_row;
reg [9:0] luma_rg;
reg protect_pixel;
wire [7:0] unsigned_input=input_pixel_i ^ 8'h80;
wire [9:0] luma_total=luma_rg+{2'b00,unsigned_input}+10'd2;
wire [7:0] add_pixel_index={add_row,add_column};
wire [7:0] luma_address=state==EDGE_LEFT ? (add_column==0 ? add_pixel_index:add_pixel_index-8'd1) :
 state==EDGE_RIGHT ? (add_column==15 ? add_pixel_index:add_pixel_index+8'd1) :
 state==EDGE_UP ? (add_row==0 ? add_pixel_index:add_pixel_index-8'd16) :
 state==EDGE_DOWN ? (add_row==15 ? add_pixel_index:add_pixel_index+8'd16) : add_pixel_index;
(* syn_ramstyle = "block_ram" *) reg [63:0] weights_0 [0:53];

reg[63:0] weight_read_0;reg[575:0] parameter_read_0;
(* syn_ramstyle = "block_ram" *) reg [63:0] weights_1 [0:287];

reg[63:0] weight_read_1;reg[575:0] parameter_read_1;
(* syn_ramstyle = "block_ram" *) reg [63:0] weights_2 [0:287];

reg[63:0] weight_read_2;reg[575:0] parameter_read_2;
(* syn_ramstyle = "block_ram" *) reg [63:0] weights_3 [0:287];

reg[63:0] weight_read_3;reg[575:0] parameter_read_3;
(* syn_ramstyle = "block_ram" *) reg [63:0] weights_4 [0:15];

reg[63:0] weight_read_4;reg[575:0] parameter_read_4;

(* syn_ramstyle = "block_ram" *) reg [63:0] color_weights_0[0:53];
(* syn_ramstyle = "block_ram" *) reg [63:0] color_weights_1[0:287];
(* syn_ramstyle = "block_ram" *) reg [63:0] color_weights_2[0:287];
(* syn_ramstyle = "block_ram" *) reg [63:0] color_weights_3[0:287];
(* syn_ramstyle = "block_ram" *) reg [63:0] color_weights_4[0:15];
reg [63:0] color_weight_read_0,color_weight_read_1,color_weight_read_2,color_weight_read_3,color_weight_read_4;
initial begin
$readmemh("variants/color_student_20261018/weights_0.mem",color_weights_0);
$readmemh("variants/color_student_20261018/weights_1.mem",color_weights_1);
$readmemh("variants/color_student_20261018/weights_2.mem",color_weights_2);
$readmemh("variants/color_student_20261018/weights_3.mem",color_weights_3);
$readmemh("variants/color_student_20261018/weights_4.mem",color_weights_4);
$readmemh("variants/student_overlap_20261007/weights_0.mem",weights_0);

$readmemh("variants/student_overlap_20261007/weights_1.mem",weights_1);

$readmemh("variants/student_overlap_20261007/weights_2.mem",weights_2);

$readmemh("variants/student_overlap_20261007/weights_3.mem",weights_3);

$readmemh("variants/student_overlap_20261007/weights_4.mem",weights_4);

end
wire[4:0] layer_start_ready,parameter_requests,parameter_response_ready,memory_requests,memory_response_ready,padding_flags,layer_result_valid,layer_done;
wire[34:0] parameter_channels;wire[159:0] activation_addresses,weight_addresses,layer_result_addresses;
wire[39:0] layer_result_pixels;
wire[6:0] parameter_channel=parameter_channels[layer_select*7+:7];
wire[31:0] activation_address=activation_addresses[layer_select*32+:32];
wire[31:0] weight_address=weight_addresses[layer_select*32+:32];
wire[31:0] layer_result_address=layer_result_addresses[layer_select*32+:32];
wire signed[7:0] layer_result_pixel=layer_result_pixels[layer_select*8+:8];
wire[575:0] parameter_read;
reg parameter_response,memory_response;
wire signed[7:0] activation_read,add_first,add_second;
wire[63:0] weight_read;
reg signed[7:0] input_read,feature_first_read,feature_second_read,residual_read,output_read;
wire[9:0] input_read_address=state==ADD_READ ? add_address : activation_address[9:0];
assign activation_read=layer_select==0 ? input_read : layer_select==1 || layer_select==3 ? feature_first_read : feature_second_read;
assign add_first=input_read;
assign add_second=use_color && protect_pixel ? (residual_read>8'sd8 ? 8'sd8 : residual_read< -8'sd8 ? -8'sd8 : residual_read) : residual_read;
 

assign weight_read=use_color ? (layer_select==0 ? color_weight_read_0 : layer_select==1 ? color_weight_read_1 : layer_select==2 ? color_weight_read_2 : layer_select==3 ? color_weight_read_3 : color_weight_read_4) : (layer_select==0 ? weight_read_0 : layer_select==1 ? weight_read_1 : layer_select==2 ? weight_read_2 : layer_select==3 ? weight_read_3 : weight_read_4);
assign parameter_read=layer_select==0 ? parameter_read_0 : layer_select==1 ? parameter_read_1 : layer_select==2 ? parameter_read_2 : layer_select==3 ? parameter_read_3 : parameter_read_4;
wire add_ready,add_valid;wire signed[7:0] add_pixel;
assign input_ready_o=rst_n_i && state==IDLE && input_count<10'd768;
assign start_ready_o=rst_n_i && state==IDLE && input_count==10'd768;
assign result_valid_o=rst_n_i && state==OUTPUT;
assign result_pixel_o=output_read;assign result_address_o=output_address;
assign busy_o=state!=IDLE;assign done_o=result_valid_o && result_ready_i && output_address==10'd767;
student_compact_shared_conv shared_layers(
 .clk_i(clk_i),.rst_n_i(rst_n_i),.layer_i(layer_select),.start_valid_i(state==START),.start_ready_o(layer_start_ready[0]),
 .output_zero_i(layer_select==4 ? (use_color ? 32'sd0 : -32'sd124) : -32'sd128),
 .parameter_valid_o(parameter_requests[0]),.parameter_ready_i(!parameter_response),.parameter_channel_o(parameter_channels[0+:7]),
 .parameter_response_valid_i(parameter_response),.parameter_response_ready_o(parameter_response_ready[0]),
 .bias_i({parameter_read[575:544],parameter_read[503:472],parameter_read[431:400],parameter_read[359:328],parameter_read[287:256],parameter_read[215:184],parameter_read[143:112],parameter_read[71:40]}),.multiplier_i({parameter_read[543:512],parameter_read[471:440],parameter_read[399:368],parameter_read[327:296],parameter_read[255:224],parameter_read[183:152],parameter_read[111:80],parameter_read[39:8]}),.right_shift_i({parameter_read[509:504],parameter_read[437:432],parameter_read[365:360],parameter_read[293:288],parameter_read[221:216],parameter_read[149:144],parameter_read[77:72],parameter_read[5:0]}),
 .memory_valid_o(memory_requests[0]),.memory_ready_i(!memory_response||memory_response_ready[0]),.activation_address_o(activation_addresses[0+:32]),.weight_address_o(weight_addresses[0+:32]),.padding_o(padding_flags[0]),
 .memory_response_valid_i(memory_response),.memory_response_ready_o(memory_response_ready[0]),.activation_i(activation_read),.weight_i(weight_read),
 .result_valid_o(layer_result_valid[0]),.result_ready_i(state==RUN),.result_address_o(layer_result_addresses[0+:32]),.pixel_o(layer_result_pixels[0+:8]),.done_o(layer_done[0]));
genvar shared_layer;
generate for(shared_layer=1;shared_layer<5;shared_layer=shared_layer+1)begin:shared_layer_signals
 assign layer_start_ready[shared_layer]=layer_start_ready[0];
 assign parameter_requests[shared_layer]=parameter_requests[0];
 assign parameter_response_ready[shared_layer]=parameter_response_ready[0];
 assign memory_requests[shared_layer]=memory_requests[0];
 assign memory_response_ready[shared_layer]=memory_response_ready[0];
 assign padding_flags[shared_layer]=padding_flags[0];
 assign layer_result_valid[shared_layer]=layer_result_valid[0];
 assign layer_done[shared_layer]=layer_done[0];
 assign parameter_channels[shared_layer*7+:7]=parameter_channels[0+:7];
 assign activation_addresses[shared_layer*32+:32]=activation_addresses[0+:32];
 assign weight_addresses[shared_layer*32+:32]=weight_addresses[0+:32];
 assign layer_result_addresses[shared_layer*32+:32]=layer_result_addresses[0+:32];
 assign layer_result_pixels[shared_layer*8+:8]=layer_result_pixels[0+:8];
end endgenerate

student_residual_add #(.RUNTIME_SECOND_ZERO(1),.FIRST_MULTIPLIER(32'sd1073741824),.FIRST_SHIFT(0),.SECOND_MULTIPLIER(32'sd1200769939),.SECOND_SHIFT(1),.OUTPUT_MULTIPLIER(32'sd1474791907),.OUTPUT_SHIFT(19),.FIRST_ZERO(-32'sd128),.SECOND_ZERO(-32'sd124),.OUTPUT_ZERO(-32'sd128)) student_residual_add_Inst_restore (
.clk_i(clk_i),.rst_n_i(rst_n_i),.valid_i(state==ADD_START),.ready_o(add_ready),.first_i(add_first),.second_i(add_second),.second_zero_i(use_color ? 32'sd0 : -32'sd124),.valid_o(add_valid),.ready_i(state==ADD_WAIT),.pixel_o(add_pixel));
 
always @(posedge clk_i)begin
 if(input_valid_i && input_ready_o)begin
  if(input_component==0)luma_rg<={2'b00,unsigned_input};
  else if(input_component==1)luma_rg<=luma_rg+{1'b0,unsigned_input,1'b0};
  else edge_luma[input_pixel_index]<=luma_total[9:2];
 end
 if(rst_n_i && use_color && ((state==ADD_READ && add_component==0) || (state>=EDGE_LEFT && state<=EDGE_DOWN)))luma_read<=edge_luma[luma_address];
 if(rst_n_i && memory_requests[layer_select] && (!memory_response || memory_response_ready[layer_select]))begin
weight_read_0<=weights_0[weight_address[5:0]];
weight_read_1<=weights_1[weight_address[8:0]];
weight_read_2<=weights_2[weight_address[8:0]];
weight_read_3<=weights_3[weight_address[8:0]];
weight_read_4<=weights_4[weight_address[3:0]];
color_weight_read_0<=color_weights_0[weight_address[5:0]];
color_weight_read_1<=color_weights_1[weight_address[8:0]];
color_weight_read_2<=color_weights_2[weight_address[8:0]];
color_weight_read_3<=color_weights_3[weight_address[8:0]];
color_weight_read_4<=color_weights_4[weight_address[3:0]];
 end
 
if(use_color)begin
`include "variants/color_student_20261018/color_parameters.vh"
end else begin
case (parameter_channel)
7'd0:parameter_read_0<=576'hffffec686f5c0d020a0000026d77566f0f0a0000025a72e571950afffffaa17d670f2b0a00000e7e42a7eb7b0900001f2b434ff73109fffff5777157c7b40affffef35712fa7710a;
7'd1:parameter_read_0<=576'h000004395306f6ee09000013c34d48c1eb090000017f5428bfe209ffffec127cbb37550afffff578788dd5510a00000a13700459af0a0000245a53bb19600900000f804792b4f609;
default:parameter_read_0<=576'd0;
endcase

case (parameter_channel)
7'd0:parameter_read_1<=576'hfffff8f057b63fe70affffff9957acf58709fffffae249ff1c30090000051b4164ae0d09fffff0e969170ae60a0000008079ed4fa70afffffaf14eeb776209fffff30f634af3c80a;
7'd1:parameter_read_1<=576'h00000ee052744f8209fffffa6c78f4f2150a000006b35a78860c090000050b52f345590a000010ad413d60e209fffff9466b3151230a00000d6873ea73f90afffff8df7ec7cb140a;
default:parameter_read_1<=576'd0;
endcase

case (parameter_channel)
7'd0:parameter_read_2<=576'h0000045e4bd8f52f09000001994ff4d95109fffffe3b59cca8450a0000005c42c98a8a09fffffcc442baa90609fffffb2b798637750afffffa4547a2e37209fffff38358dff1f20a;
7'd1:parameter_read_2<=576'hfffff0db6e0bff530afffff9f1610ae9e10a000001bd58d12e8809fffffa2b5cd43db00a000000ea63dbbbf80afffffedf40be15b009fffff87f6a8307040afffffd7a7fa330620a;
default:parameter_read_2<=576'd0;
endcase

case (parameter_channel)
7'd0:parameter_read_3<=576'hfffffd7a47b1ac6008fffff9705983c4b508fffffde14a65c85008fffffcbd4978901608ffffffb76d5630af08fffffc2e46bcd7cb080000011547d5d5e108fffffd10503cc9e808;
7'd1:parameter_read_3<=576'hfffffc284a7c270108fffffb235a9c2c9408fffffda377fc8d8808fffffe135ca0785408fffffed6484fa3ad08fffffb3d50225d2308fffffe285fa1a35408fffffd7b603a099208;
default:parameter_read_3<=576'd0;
endcase

parameter_read_4<=576'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000029419bb21507000000397aeb464d080000008b4344879b07;

end

 if(input_valid_i && input_ready_o)input_memory[input_count]<=input_pixel_i;
 if(rst_n_i && state==RUN && layer_result_valid[layer_select])begin
  case(layer_select)
   3'd0,3'd2:feature_first[layer_result_address]<=layer_result_pixel;
   3'd1,3'd3:feature_second[layer_result_address]<=layer_result_pixel;
   3'd4:residual_memory[layer_result_address]<=layer_result_pixel;
  endcase
 end
 if(rst_n_i && (state==ADD_READ || (memory_requests[layer_select] && (!memory_response || memory_response_ready[layer_select]) && layer_select==0)))input_read<=input_memory[input_read_address];
 if(rst_n_i && memory_requests[layer_select] && (!memory_response || memory_response_ready[layer_select]))begin
  if(layer_select==1 || layer_select==3)feature_first_read<=feature_first[activation_address[11:0]];
  if(layer_select==2 || layer_select==4)feature_second_read<=feature_second[activation_address[11:0]];
 end
 if(state==ADD_READ)residual_read<=residual_memory[add_address];
 if(rst_n_i && state==ADD_WAIT && add_valid)output_memory[add_address]<=add_pixel;
 if(state==OUTPUT_READ)output_read<=output_memory[output_address];
end
always @(posedge clk_i or negedge rst_n_i)begin
 if(!rst_n_i)begin
  color_latched<=0;input_component<=0;input_pixel_index<=0;add_component<=0;add_column<=0;add_row<=0;
  luma_min<=0;luma_max<=0;protect_pixel<=0;
  state<=IDLE;layer_select<=0;input_count<=0;add_address<=0;output_address<=0;parameter_response<=0;memory_response<=0;
 end else begin
  if(input_valid_i && input_ready_o)begin
  input_count<=input_count+1'b1;
  if(input_count==0)color_latched<=color_model_i;
  if(input_component==2)begin input_component<=0;input_pixel_index<=input_pixel_index+1'b1;end
  else input_component<=input_component+1'b1;
 end
  if(parameter_response && parameter_response_ready[layer_select])parameter_response<=0;
  if(parameter_requests[layer_select] && !parameter_response)parameter_response<=1;
  if(memory_response && memory_response_ready[layer_select])memory_response<=0;
  if(memory_requests[layer_select] && (!memory_response || memory_response_ready[layer_select]))memory_response<=1;
  case(state)
   IDLE:if(start_valid_i && start_ready_o)begin layer_select<=0;state<=START;end
   START:if(layer_start_ready[layer_select])state<=RUN;
   RUN:if(layer_done[layer_select])begin
    if(layer_select==3'd4)begin add_address<=0;add_component<=0;add_column<=0;add_row<=0;protect_pixel<=0;state<=ADD_READ;end
    else begin layer_select<=layer_select+1'b1;state<=START;end
   end
   ADD_READ:state<=use_color && add_component==0 ? EDGE_LEFT : ADD_START;
   EDGE_LEFT:begin luma_min<=luma_read;luma_max<=luma_read;state<=EDGE_RIGHT;end
   EDGE_RIGHT:begin
    if(luma_read<luma_min)luma_min<=luma_read;if(luma_read>luma_max)luma_max<=luma_read;state<=EDGE_UP;
   end
   EDGE_UP:begin
    if(luma_read<luma_min)luma_min<=luma_read;if(luma_read>luma_max)luma_max<=luma_read;state<=EDGE_DOWN;
   end
   EDGE_DOWN:begin
    if(luma_read<luma_min)luma_min<=luma_read;if(luma_read>luma_max)luma_max<=luma_read;state<=EDGE_FINISH;
   end
   EDGE_FINISH:begin protect_pixel<=(luma_min<128 || luma_read<128) && (luma_max>160 || luma_read>160);state<=ADD_START;end
   ADD_START:if(add_ready)state<=ADD_WAIT;
   ADD_WAIT:if(add_valid)begin
    if(add_component==2)begin
     add_component<=0;add_column<=add_column+1'b1;if(add_column==15)add_row<=add_row+1'b1;
    end else add_component<=add_component+1'b1;
    if(add_address==10'd767)begin output_address<=0;state<=OUTPUT_READ;end
    else begin add_address<=add_address+1'b1;state<=ADD_READ;end
   end
   OUTPUT_READ:state<=OUTPUT;
   OUTPUT:if(result_ready_i)begin
    if(output_address==10'd767)begin input_count<=0;state<=IDLE;end
    else begin output_address<=output_address+1'b1;state<=OUTPUT_READ;end
   end
   default:state<=IDLE;
  endcase
 end
end
endmodule
