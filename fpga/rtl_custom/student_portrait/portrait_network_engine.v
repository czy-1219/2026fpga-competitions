`timescale 1ns/1ps
 

module portrait_network_engine(
 input clk,input rst_n,input start,output ready,input [4:0] first_stage,input [4:0] last_stage,
 output rd_valid,input rd_ready,output [31:0] rd_address,
 input rd_response_valid,output rd_response_ready,input signed [7:0] rd_data,
 output wr_valid,input wr_ready,output [31:0] wr_address,output signed [7:0] wr_data,
 output done,output error,output [4:0] stage_o);
localparam IDLE=0,SETUP=1,CONV=2,READ=3,RESPONSE=4,WRITE=5,NEXT=6;
reg [2:0] state;
reg [4:0] stage,stop_stage;
reg [31:0] index;
reg [1:0] tap;
reg signed [10:0] sum;
reg signed [7:0] value;
reg done_reg,error_reg;
reg [31:0] source,dest,count,spatial_address;
reg [1:0] kind,kernel;
reg [3:0] layer;
reg [12:0] weight_base;
reg [7:0] width,height;
reg [5:0] channels,outputs;
reg signed [7:0] input_zero;
reg signed [31:0] output_zero;
wire cs,cr,cmv,cmr,cpad,cv,cd,ce,cready;
wire [31:0] ca,co;
wire signed [7:0] pixel;
wire signed [10:0] total=sum+{{3{rd_data[7]}},rd_data};
wire signed [10:0] averaged=total<0 ? -(((-total)+11'sd2)>>>2) : ((total+11'sd2)>>>2);
assign ready=state==IDLE&&rst_n;
assign done=done_reg;assign error=error_reg;assign stage_o=stage;
assign cs=state==SETUP&&kind==0;
assign rd_valid=state==CONV ? cmv : state==READ;
assign rd_address=state==CONV ? source+ca : spatial_address;
assign rd_response_ready=state==CONV ? cmr : state==RESPONSE;
assign wr_valid=state==CONV ? cv : state==WRITE;
assign wr_address=dest+(state==CONV ? co:index);
assign wr_data=state==CONV ? pixel:value;
always @(*)begin
 source=0;dest=0;count=0;spatial_address=0;kind=0;layer=0;weight_base=0;
 width=0;height=0;channels=0;outputs=0;kernel=0;input_zero=-128;output_zero=-128;
 case(stage)
0:begin dest=32'd49152; count=32'd262144; source=32'd0;kind=0;layer=4'd0;weight_base=13'd0;width=8'd128;height=8'd128;channels=6'd3;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
1:begin dest=32'd311296; count=32'd65536; source=32'd49152;kind=1;spatial_address=32'd49152+((index/1024)*2+(tap/2))*2048+(((index/16)%64)*2+(tap%2))*16+index%16;end
2:begin dest=32'd0; count=32'd65536; source=32'd311296;kind=0;layer=4'd1;weight_base=13'd54;width=8'd64;height=8'd64;channels=6'd16;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
3:begin dest=32'd65536; count=32'd16384; source=32'd0;kind=1;spatial_address=32'd0+((index/512)*2+(tap/2))*1024+(((index/16)%32)*2+(tap%2))*16+index%16;end
4:begin dest=32'd81920; count=32'd16384; source=32'd65536;kind=0;layer=4'd2;weight_base=13'd342;width=8'd32;height=8'd32;channels=6'd16;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
5:begin dest=32'd65536; count=32'd4096; source=32'd81920;kind=1;spatial_address=32'd81920+((index/256)*2+(tap/2))*512+(((index/16)%16)*2+(tap%2))*16+index%16;end
6:begin dest=32'd69632; count=32'd4096; source=32'd65536;kind=0;layer=4'd3;weight_base=13'd630;width=8'd16;height=8'd16;channels=6'd16;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
7:begin dest=32'd65536; count=32'd1024; source=32'd69632;kind=1;spatial_address=32'd69632+((index/128)*2+(tap/2))*256+(((index/16)%8)*2+(tap%2))*16+index%16;end
8:begin dest=32'd66560; count=32'd1024; source=32'd65536;kind=0;layer=4'd4;weight_base=13'd918;width=8'd8;height=8'd8;channels=6'd16;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
9:begin dest=32'd65536; count=32'd256; source=32'd66560;kind=1;spatial_address=32'd66560+((index/64)*2+(tap/2))*128+(((index/16)%4)*2+(tap%2))*16+index%16;end
10:begin dest=32'd65792; count=32'd256; source=32'd65536;kind=0;layer=4'd5;weight_base=13'd1206;width=8'd4;height=8'd4;channels=6'd16;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
11:begin dest=32'd65536; count=32'd256; source=32'd65792;kind=0;layer=4'd6;weight_base=13'd1494;width=8'd4;height=8'd4;channels=6'd16;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
12:begin dest=32'd67584; count=32'd1024; source=32'd65536;kind=2;spatial_address=32'd65536+((index/128)/2)*64+(((index/16)%8)/2)*16+index%16;end
13:begin dest=32'd73728; count=32'd2048; source=32'd67584;kind=3;if(index%32<16)spatial_address=32'd67584+(index/32)*16+index%32;else spatial_address=32'd66560+(index/32)*16+index%32-16;end
14:begin dest=32'd65536; count=32'd1024; source=32'd73728;kind=0;layer=4'd7;weight_base=13'd1782;width=8'd8;height=8'd8;channels=6'd32;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
15:begin dest=32'd73728; count=32'd4096; source=32'd65536;kind=2;spatial_address=32'd65536+((index/256)/2)*128+(((index/16)%16)/2)*16+index%16;end
16:begin dest=32'd98304; count=32'd8192; source=32'd73728;kind=3;if(index%32<16)spatial_address=32'd73728+(index/32)*16+index%32;else spatial_address=32'd69632+(index/32)*16+index%32-16;end
17:begin dest=32'd65536; count=32'd4096; source=32'd98304;kind=0;layer=4'd8;weight_base=13'd2358;width=8'd16;height=8'd16;channels=6'd32;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
18:begin dest=32'd98304; count=32'd16384; source=32'd65536;kind=2;spatial_address=32'd65536+((index/512)/2)*256+(((index/16)%32)/2)*16+index%16;end
19:begin dest=32'd114688; count=32'd32768; source=32'd98304;kind=3;if(index%32<16)spatial_address=32'd98304+(index/32)*16+index%32;else spatial_address=32'd81920+(index/32)*16+index%32-16;end
20:begin dest=32'd65536; count=32'd16384; source=32'd114688;kind=0;layer=4'd9;weight_base=13'd2934;width=8'd32;height=8'd32;channels=6'd32;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
21:begin dest=32'd81920; count=32'd65536; source=32'd65536;kind=2;spatial_address=32'd65536+((index/1024)/2)*512+(((index/16)%64)/2)*16+index%16;end
22:begin dest=32'd147456; count=32'd131072; source=32'd81920;kind=3;if(index%32<16)spatial_address=32'd81920+(index/32)*16+index%32;else spatial_address=32'd0+(index/32)*16+index%32-16;end
23:begin dest=32'd278528; count=32'd65536; source=32'd147456;kind=0;layer=4'd10;weight_base=13'd3510;width=8'd64;height=8'd64;channels=6'd32;outputs=6'd16;kernel=2'd3;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd128;end
24:begin dest=32'd344064; count=32'd4096; source=32'd278528;kind=0;layer=4'd11;weight_base=13'd4086;width=8'd64;height=8'd64;channels=6'd16;outputs=6'd1;kernel=2'd1;input_zero=8'sd128;input_zero=-input_zero;output_zero=-32'sd116;end
 default:begin end
 endcase
end
portrait_serviced_conv core(
 .clk_i(clk),.rst_n_i(rst_n),.start_valid_i(cs),.start_ready_o(cr),
 .layer_i(layer),.weight_base_i(weight_base),.width_i(width),.height_i(height),
 .channels_i(channels),.output_channels_i(outputs),.kernel_i(kernel),
 .input_zero_i(input_zero),.output_zero_i(output_zero),.minimum_i(-8'sd128),.maximum_i(8'sd127),
 .memory_valid_o(cmv),.memory_ready_i(rd_ready&&state==CONV),.activation_address_o(ca),.padding_o(cpad),
 .memory_response_valid_i(rd_response_valid&&state==CONV),.memory_response_ready_o(cmr),.activation_i(rd_data),
 .result_valid_o(cv),.result_ready_i(wr_ready&&state==CONV),.result_address_o(co),.pixel_o(pixel),.done_o(cd),.error_o(ce));
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin state<=IDLE;stage<=0;stop_stage<=24;index<=0;tap<=0;sum<=0;value<=0;done_reg<=0;error_reg<=0;end
 else begin
  done_reg<=0;
  case(state)
   IDLE:if(start)begin error_reg<=0;if(first_stage>last_stage||last_stage>24)begin error_reg<=1;done_reg<=1;end else begin stage<=first_stage;stop_stage<=last_stage;state<=SETUP;end end
   SETUP:begin index<=0;tap<=0;sum<=0;if(kind==0)begin if(cr)state<=CONV;end else state<=READ;end
   CONV:if(cd)begin if(ce)begin error_reg<=1;state<=IDLE;done_reg<=1;end else state<=NEXT;end
   READ:if(rd_ready)state<=RESPONSE;
   RESPONSE:if(rd_response_valid)begin
    if(kind==1&&tap!=3)begin sum<=total;tap<=tap+1;state<=READ;end
    else begin value<=kind==1 ? averaged[7:0]:rd_data;state<=WRITE;end
   end
   WRITE:if(wr_ready)begin tap<=0;sum<=0;if(index==count-1)state<=NEXT;else begin index<=index+1;state<=READ;end end
   NEXT:if(stage==stop_stage)begin done_reg<=1;state<=IDLE;end else begin stage<=stage+1;state<=SETUP;end
   default:state<=IDLE;
  endcase
 end
end
endmodule
