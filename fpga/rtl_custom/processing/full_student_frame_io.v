`timescale 1ns/1ps
 



module full_student_frame_io #(
 parameter INPUT_ROM="variants/full_student_20261018/rgb8_q12.mem"
)(
 input wire clk_i,rst_n_i,start_i,to_rgb565_i,camera_layout_i,
 input wire [31:0] pixels_i,input_base_i,output_base_i,
 output reg busy_o,done_o,error_o,output reg [31:0] pixels_done_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,
 output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,READ=1,READ_WAIT=2,CONVERT=3,ROM_WAIT=4,
  ROM_STORE=5,WRITE=6,WRITE_WAIT=7,NEXT=8,FINISH=9;
 reg [3:0] state;reg reverse,camera;reg [31:0] total,source,dest;
 reg [383:0] buffer_data;reg [127:0] packed_rgb;reg [1:0] beat,channel;
 reg [2:0] pixel;reg req_valid;reg [7:0] rom_index;reg [12:0] rom_q;
 (* syn_ramstyle="block_ram" *) reg [12:0] input_rom[0:255];
 initial $readmemh(INPUT_ROM,input_rom);
 always @(posedge clk_i)rom_q<=input_rom[rom_index];
 wire [15:0] rgb=camera ? packed_rgb[127:112] : packed_rgb[15:0];
 function [5:0] pack_channel;
  input signed [15:0] q;input green;reg [17:0] value,scaled;
  begin
   value=q<0 ? 0 : q>4096 ? 4096 : {2'd0,q};
   scaled=green ? (value<<6)-value+18'd2048 : (value<<5)-value+18'd2048;
   pack_channel=scaled[17:12];
  end
 endfunction
 wire [5:0] r=pack_channel($signed(buffer_data[15:0]),1'b0);
 wire [5:0] g=pack_channel($signed(buffer_data[31:16]),1'b1);
 wire [5:0] b=pack_channel($signed(buffer_data[47:32]),1'b0);
 assign mem_valid_o=req_valid;assign mem_write_o=state==WRITE_WAIT;
 assign mem_addr_o=(state==WRITE_WAIT ? dest : source)+{26'd0,beat,4'd0};
 assign mem_wdata_o=reverse ? packed_rgb : buffer_data[beat*128+:128];
 assign mem_wstrb_o=16'hffff;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;reverse<=0;camera<=0;total<=0;source<=0;dest<=0;
   buffer_data<=0;packed_rgb<=0;beat<=0;channel<=0;pixel<=0;req_valid<=0;rom_index<=0;
   busy_o<=0;done_o<=0;error_o<=0;pixels_done_o<=0;
  end else case(state)
   IDLE:if(start_i)begin
    busy_o<=1;done_o<=0;error_o<=0;pixels_done_o<=0;reverse<=to_rgb565_i;camera<=camera_layout_i;
    total<=pixels_i;source<=input_base_i;dest<=output_base_i;beat<=0;pixel<=0;channel<=0;
    if(pixels_i==0 || pixels_i>2073600 || pixels_i[2:0]!=0 || input_base_i[3:0]!=0 || output_base_i[3:0]!=0)
     begin error_o<=1;state<=FINISH;end
    else state<=READ;
   end
   READ:begin req_valid<=1;state<=READ_WAIT;end
   READ_WAIT:begin
    if(req_valid && mem_ready_i)req_valid<=0;
    if(mem_rsp_valid_i && !req_valid)begin
     if(mem_error_i)begin error_o<=1;state<=FINISH;end
     else begin
      if(reverse)buffer_data[beat*128+:128]<=mem_rdata_i;else packed_rgb<=mem_rdata_i;
      if(reverse && beat<2)begin beat<=beat+1;state<=READ;end
      else begin pixel<=0;channel<=0;beat<=0;state<=CONVERT;end
     end
    end
   end
   CONVERT:begin
    if(reverse)begin
     packed_rgb<={r[4:0],g,b[4:0],packed_rgb[127:16]};buffer_data<=buffer_data>>48;
     if(pixel==7)state<=WRITE;else pixel<=pixel+1;
    end else begin
     rom_index<=channel==0 ? {rgb[15:11],rgb[15:13]} : channel==1 ? {rgb[10:5],rgb[10:9]} : {rgb[4:0],rgb[4:2]};state<=ROM_WAIT;
    end
   end
   ROM_WAIT:state<=ROM_STORE;
   ROM_STORE:begin
    buffer_data<={3'd0,rom_q,buffer_data[383:16]};
    if(channel==2)packed_rgb<=camera ? packed_rgb<<16 : packed_rgb>>16;
    if(channel<2)begin channel<=channel+1;state<=CONVERT;end
    else if(pixel<7)begin pixel<=pixel+1;channel<=0;state<=CONVERT;end
    else state<=WRITE;
   end
   WRITE:begin req_valid<=1;state<=WRITE_WAIT;end
   WRITE_WAIT:begin
    if(req_valid && mem_ready_i)req_valid<=0;
    if(mem_rsp_valid_i && !req_valid)begin
     if(mem_error_i)begin error_o<=1;state<=FINISH;end
     else if(!reverse && beat<2)begin beat<=beat+1;state<=WRITE;end
     else state<=NEXT;
    end
   end
   NEXT:begin
    pixels_done_o<=pixels_done_o+8;source<=source+(reverse ? 48 : 16);dest<=dest+(reverse ? 16 : 48);beat<=0;
    if(pixels_done_o+8==total)state<=FINISH;else state<=READ;
   end
   FINISH:begin busy_o<=0;done_o<=1;req_valid<=0;state<=IDLE;end
   default:begin error_o<=1;req_valid<=0;state<=FINISH;end
  endcase
 end
endmodule
