`timescale 1ns/1ps
 




module full_student_model_loader #(parameter STREAM_TIMEOUT_CYCLES=480000000)(
 input wire clk_i,rst_n_i,start_i,program_i,
 input wire [31:0] bytes_i,crc_i,
 input wire data_valid_i,output wire data_ready_o,input wire [127:0] data_i,
 output reg busy_o,done_o,error_o,output reg [3:0] error_code_o,
 output reg [31:0] bytes_done_o,output reg [31:0] crc_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,ACCEPT=1,CRC=2,WRITE=3,WAIT_WRITE=4,
  NEXT_WRITE=5,READ=6,WAIT_READ=7,NEXT_READ=8,FINISH=9;
 reg [3:0] state;reg [31:0] base,address,total,expected,crc;
 reg [127:0] data;reg [3:0] byte_index;reg readback,req_valid;reg [28:0] idle_ticks;
 function [31:0] crc_byte;
  input [31:0] prev;input [7:0] value;reg [31:0] next;integer j;
  begin next=prev^{24'd0,value};for(j=0;j<8;j=j+1)next=(next>>1)^(next[0] ? 32'hedb88320 : 32'd0);crc_byte=next;end
 endfunction
 assign data_ready_o=state==ACCEPT;
 assign mem_valid_o=req_valid;assign mem_write_o=state==WAIT_WRITE;
 assign mem_addr_o=address;assign mem_wdata_o=data;assign mem_wstrb_o=16'hffff;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;base<=0;address<=0;total<=0;expected<=0;crc<=32'hffffffff;idle_ticks<=0;
   data<=0;byte_index<=0;readback<=0;req_valid<=0;busy_o<=0;done_o<=0;error_o<=0;error_code_o<=0;bytes_done_o<=0;crc_o<=0;
  end else case(state)
   IDLE:if(start_i)begin
    busy_o<=1;done_o<=0;error_o<=0;error_code_o<=0;bytes_done_o<=0;crc_o<=0;
    base<=program_i ? 32'h03a00000 : 32'h03000000;address<=program_i ? 32'h03a00000 : 32'h03000000;
    total<=bytes_i;expected<=crc_i;crc<=32'hffffffff;readback<=0;byte_index<=0;idle_ticks<=0;
    if(bytes_i==0 || bytes_i[3:0]!=0 || bytes_i>(program_i ? 32'h00600000 : 32'h00a00000) || (program_i && bytes_i[6:0]!=0))
     begin error_o<=1;error_code_o<=1;state<=FINISH;end
    else state<=ACCEPT;
   end
   ACCEPT:if(data_valid_i)begin data<=data_i;byte_index<=0;idle_ticks<=0;state<=CRC;end
    else if(idle_ticks+1>=STREAM_TIMEOUT_CYCLES)begin error_o<=1;error_code_o<=6;state<=FINISH;end
    else idle_ticks<=idle_ticks+1;
   CRC:begin
    crc<=crc_byte(crc,data[byte_index*8+:8]);
    if(byte_index==15)state<=readback ? NEXT_READ : WRITE;else byte_index<=byte_index+1;
   end
   WRITE:begin req_valid<=1;state<=WAIT_WRITE;end
   WAIT_WRITE:begin
    if(req_valid && mem_ready_i)req_valid<=0;
    if(mem_rsp_valid_i && !req_valid)begin
     if(mem_error_i)begin error_o<=1;error_code_o<=2;state<=FINISH;end else state<=NEXT_WRITE;
    end
   end
   NEXT_WRITE:begin
    bytes_done_o<=bytes_done_o+16;address<=address+16;
    if(bytes_done_o+16==total)begin
     crc_o<=~crc;
     if((~crc)!=expected)begin error_o<=1;error_code_o<=3;state<=FINISH;end
     else begin readback<=1;crc<=32'hffffffff;address<=base;bytes_done_o<=0;state<=READ;end
    end else state<=ACCEPT;
   end
   READ:begin req_valid<=1;state<=WAIT_READ;end
   WAIT_READ:begin
    if(req_valid && mem_ready_i)req_valid<=0;
    if(mem_rsp_valid_i && !req_valid)begin
     if(mem_error_i)begin error_o<=1;error_code_o<=4;state<=FINISH;end
     else begin data<=mem_rdata_i;byte_index<=0;state<=CRC;end
    end
   end
   NEXT_READ:begin
    bytes_done_o<=bytes_done_o+16;address<=address+16;
    if(bytes_done_o+16==total)begin crc_o<=~crc;error_o<=(~crc)!=expected;error_code_o<=(~crc)!=expected ? 4'd5 : 4'd0;state<=FINISH;end
    else state<=READ;
   end
   FINISH:begin busy_o<=0;done_o<=1;req_valid<=0;state<=IDLE;end
   default:begin error_o<=1;error_code_o<=15;req_valid<=0;state<=FINISH;end
  endcase
 end
endmodule
