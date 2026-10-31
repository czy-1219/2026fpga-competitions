`timescale 1ns/1ps
 







module full_student_vector16(
 input wire clk_i,rst_n_i,start_i,input wire [1023:0] command_i,
 output reg busy_o,done_o,error_o,output reg [31:0] outputs_o,clipped_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,INPUT=1,READ_GOT=2,CALC_START=3,CALC_WAIT=4,WRITE=5,NEXT=6,WAIT_MEM=7,FINISH=8;
 reg [3:0] state,ret;reg [4:0] opcode;
 reg [15:0] width,height,channels,x,y,ch;reg [7:0] out_frac;
 reg [31:0] addr[0:2],row_addr[0:2],pixel_addr[0:2],sx[0:2],sy[0:2],sc[0:2];
 reg [7:0] frac[0:2];reg [2:0] constants;reg signed [31:0] constant_value[0:2],values[0:2];
 reg [31:0] out_addr,out_row,out_pixel,out_sx,out_sy,out_sc;
 reg [1:0] source;reg [2:0] lane;
 reg [2:0] cache_valid;reg [31:0] cache_addr[0:2];reg [127:0] cache_data[0:2];
 reg req_valid,req_write;reg [31:0] req_addr;reg [127:0] req_data,rsp_data;reg [15:0] req_strb;
 reg [15:0] pixel;wire alu_ready,alu_valid,alu_error,alu_sat;wire signed [31:0] alu_result;
 full_student_scalar alu(.clk_i(clk_i),.rst_n_i(rst_n_i && !(state==FINISH && error_o)),.valid_i(state==CALC_START),.ready_o(alu_ready),.op_i(opcode),.a_i(values[0]),.b_i(values[1]),.c_i(values[2]),.valid_o(alu_valid),.ready_i(state==CALC_WAIT),.value_o(alu_result),.error_o(alu_error),.saturated_o(alu_sat));
 assign mem_valid_o=req_valid;assign mem_write_o=req_write;assign mem_addr_o=req_addr;assign mem_wdata_o=req_data;assign mem_wstrb_o=req_strb;
 function signed [31:0] expand;
  input signed [15:0] v;input [7:0] f;reg signed [31:0] z;reg [31:0] mag,q,mask,rem,half;reg [7:0] shift;
  begin
   z={{16{v[15]}},v};
   if(f<=16)expand=z<<<(16-f);
   else begin
    shift=f-16;mag=z<0 ? -z : z;mask=(32'd1<<shift)-1;rem=mag&mask;half=32'd1<<(shift-1);q=mag>>shift;
    q=q+{31'd0,(rem>half || (rem==half && q[0]))};expand=z<0 ? -$signed(q) : $signed(q);
   end
  end
 endfunction
 function [16:0] quantize;
  input signed [31:0] v;input [7:0] f;reg [63:0] mag,q,mask,rem,half;integer s;
  begin
   mag=v<0 ? -$signed({{32{v[31]}},v}) : {32'd0,v};q=mag;s=16-{24'd0,f};
   if(s>0)begin mask=(64'd1<<s)-1;rem=mag&mask;half=64'd1<<(s-1);q=(mag>>s)+{63'd0,(rem>half || (rem==half && ((mag>>s)&1)!=0))};end
   else if(s<0)q=mag<<(-s);
   if(v<0)quantize=q>32768 ? {1'b1,16'h8000} : {1'b0,(~q[15:0]+16'd1)};
   else quantize=q>32767 ? {1'b1,16'h7fff} : {1'b0,q[15:0]};
  end
 endfunction
 wire [16:0] quantized=quantize(alu_result,out_frac);
 integer i;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;ret<=0;busy_o<=0;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;
   opcode<=0;width<=0;height<=0;channels<=0;x<=0;y<=0;ch<=0;out_frac<=0;constants<=0;
   out_addr<=0;out_row<=0;out_pixel<=0;out_sx<=0;out_sy<=0;out_sc<=0;source<=0;lane<=0;cache_valid<=0;
   req_valid<=0;req_write<=0;req_addr<=0;req_data<=0;req_strb<=0;rsp_data<=0;pixel<=0;
   for(i=0;i<3;i=i+1)begin addr[i]<=0;row_addr[i]<=0;pixel_addr[i]<=0;sx[i]<=0;sy[i]<=0;sc[i]<=0;frac[i]<=0;constant_value[i]<=0;values[i]<=0;cache_addr[i]<=0;cache_data[i]<=0;end
  end else case(state)
   IDLE:if(start_i)begin
    busy_o<=1;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;cache_valid<=0;source<=0;x<=0;y<=0;ch<=0;
    opcode<=command_i[4:0];width<=command_i[32+:16];height<=command_i[48+:16];channels<=command_i[64+:16];out_frac<=command_i[80+:8];
    out_addr<=command_i[96+:32];out_row<=command_i[96+:32];out_pixel<=command_i[96+:32];out_sx<=command_i[128+:32];out_sy<=command_i[160+:32];out_sc<=command_i[192+:32];
    for(i=0;i<3;i=i+1)begin
     addr[i]<=command_i[(7+7*i)*32+:32];row_addr[i]<=command_i[(7+7*i)*32+:32];pixel_addr[i]<=command_i[(7+7*i)*32+:32];
     sx[i]<=command_i[(8+7*i)*32+:32];sy[i]<=command_i[(9+7*i)*32+:32];sc[i]<=command_i[(10+7*i)*32+:32];
     frac[i]<=command_i[(11+7*i)*32+:8];constant_value[i]<=command_i[(12+7*i)*32+:32];constants[i]<=command_i[(13+7*i)*32];
    end
    if(command_i[32+:16]==0 || command_i[48+:16]==0 || command_i[64+:16]==0 || command_i[80+:8]>24 || command_i[96])begin error_o<=1;state<=FINISH;end
    else state<=INPUT;
   end
   INPUT:begin
    if(constants[source])begin
     values[source]<=constant_value[source];if(source==2)state<=CALC_START;else source<=source+1;
    end else if(frac[source]>24 || addr[source][0])begin error_o<=1;state<=FINISH;end
    else if(cache_valid[source] && cache_addr[source]=={addr[source][31:4],4'b0})begin
     values[source]<=expand($signed(cache_data[source][addr[source][3:1]*16+:16]),frac[source]);
     if(source==2)state<=CALC_START;else source<=source+1;
    end else begin req_valid<=1;req_write<=0;req_addr<={addr[source][31:4],4'b0};lane<=addr[source][3:1];ret<=READ_GOT;state<=WAIT_MEM;end
   end
   READ_GOT:begin
    cache_valid[source]<=1;cache_addr[source]<=req_addr;cache_data[source]<=rsp_data;
    values[source]<=expand($signed(rsp_data[lane*16+:16]),frac[source]);if(source==2)state<=CALC_START;else begin source<=source+1;state<=INPUT;end
   end
   CALC_START:if(alu_ready)state<=CALC_WAIT;
   CALC_WAIT:if(alu_valid)begin
    pixel<=quantized[15:0];if(quantized[16] || alu_sat)clipped_o<=clipped_o+1;
    if(alu_error)begin error_o<=1;state<=FINISH;end else state<=WRITE;
   end
   WRITE:begin
    req_valid<=1;req_write<=1;req_addr<={out_addr[31:4],4'b0};req_data<=({112'd0,pixel}<<(out_addr[3:1]*16));req_strb<=16'd3<<(out_addr[3:1]*2);ret<=NEXT;state<=WAIT_MEM;
   end
   NEXT:begin
    outputs_o<=outputs_o+1;source<=0;
    for(i=0;i<3;i=i+1)if(cache_valid[i] && cache_addr[i]==req_addr)cache_data[i][out_addr[3:1]*16+:16]<=pixel;
    if(ch+1<channels)begin ch<=ch+1;out_addr<=out_addr+out_sc;for(i=0;i<3;i=i+1)addr[i]<=addr[i]+sc[i];state<=INPUT;end
    else if(x+1<width)begin
     ch<=0;x<=x+1;out_pixel<=out_pixel+out_sx;out_addr<=out_pixel+out_sx;
     for(i=0;i<3;i=i+1)begin pixel_addr[i]<=pixel_addr[i]+sx[i];addr[i]<=pixel_addr[i]+sx[i];end
     state<=INPUT;
    end else if(y+1<height)begin
     ch<=0;x<=0;y<=y+1;out_row<=out_row+out_sy;out_pixel<=out_row+out_sy;out_addr<=out_row+out_sy;
     for(i=0;i<3;i=i+1)begin row_addr[i]<=row_addr[i]+sy[i];pixel_addr[i]<=row_addr[i]+sy[i];addr[i]<=row_addr[i]+sy[i];end
     state<=INPUT;
    end else state<=FINISH;
   end
   WAIT_MEM:begin
    if(req_valid && mem_ready_i)req_valid<=0;
    if(mem_rsp_valid_i && !req_valid)begin rsp_data<=mem_rdata_i;if(mem_error_i)begin error_o<=1;state<=FINISH;end else state<=ret;end
   end
   FINISH:begin busy_o<=0;done_o<=1;state<=IDLE;end
   default:begin req_valid<=0;error_o<=1;state<=FINISH;end
  endcase
 end
endmodule
