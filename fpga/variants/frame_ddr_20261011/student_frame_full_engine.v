`timescale 1ns/1ps
`include "variants/frame_ddr_20261011/student_frame_axi_core.v"
 

module student_frame_full_engine (
    input wire clk_i,rst_n_i,start_i,
    input wire flash_valid_i,input wire [7:0] flash_data_i,output wire flash_ready_o,
    input wire load_available_i,reg_write_i,input wire [6:0] reg_addr_i,read_addr_i,input wire [7:0] reg_data_i,
    output reg [7:0] read_data_o,output wire load_begin_o,
    input wire [15:0] width_i,height_i,
    input wire joint_i,camera_layout_i,input wire [1:0] output_mode_i,
    input wire [31:0] input_base_i,output_base_i,
    output wire busy_o,done_o,error_o,
    output wire color_model_o,
    output wire [23:0] pixels_done_o,
    output wire tile_input_valid_o,input wire tile_input_ready_i,
    output wire [7:0] tile_input_pixel_o,
    output wire tile_start_valid_o,input wire tile_start_ready_i,
    input wire tile_result_valid_i,output wire tile_result_ready_o,
    input wire [7:0] tile_result_pixel_i,input wire [9:0] tile_result_address_i,
    output wire arvalid_o,input wire arready_i,output wire [31:0] araddr_o,
    input wire rvalid_i,rlast_i,input wire [1:0] rresp_i,
    input wire [127:0] rdata_i,output wire rready_o,
    output wire awvalid_o,input wire awready_i,output wire [31:0] awaddr_o,
    output wire wvalid_o,input wire wready_i,output wire [127:0] wdata_o,
    output wire [15:0] wstrb_o,output wire wlast_o,
    input wire bvalid_i,input wire [1:0] bresp_i,output wire bready_o
);
 localparam IDLE=0,LEGACY=1,LATEST=2,LOADING=3;
 reg [1:0] owner;reg frame_done,frame_error,frame_is_latest;
 reg [31:0] length,crc;reg [3:0] load_config;reg [4:0] fill;
 reg [127:0] fifo;reg rejected,overflow;
 wire rb,rd,re,wr,pr,ready,cb,cd,ce;wire [1:0] hd;
 wire [7:0] error_code;wire [31:0] bytes,pixels,commands;wire [63:0] cycles,task_cycles;reg [63:0] timing_snapshot;reg timing_high,timing_valid;
 wire [23:0] legacy_pixels;
 wire load_request=reg_write_i && reg_addr_i==7'h65 && reg_data_i[0];
 wire accept_load=load_request && load_available_i && owner==IDLE && !start_i;
 wire accept_frame=start_i && owner==IDLE && !load_request;
 assign load_begin_o=accept_load;
 assign busy_o=owner!=IDLE || accept_load || accept_frame;
 assign done_o=frame_done;assign error_o=frame_error;
 assign pixels_done_o=frame_is_latest ? pixels[23:0] : legacy_pixels;
 wire use_legacy=owner==LEGACY;
 wire use_runtime=owner==LATEST || owner==LOADING;
 wire c_arvalid,r_arvalid;
 assign arvalid_o=use_legacy ? c_arvalid : use_runtime ? r_arvalid : 1'd0;
 wire [31:0] c_araddr,r_araddr;
 assign araddr_o=use_legacy ? c_araddr : use_runtime ? r_araddr : 32'd0;
 wire c_rready,r_rready;
 assign rready_o=use_legacy ? c_rready : use_runtime ? r_rready : 1'd0;
 wire c_awvalid,r_awvalid;
 assign awvalid_o=use_legacy ? c_awvalid : use_runtime ? r_awvalid : 1'd0;
 wire [31:0] c_awaddr,r_awaddr;
 assign awaddr_o=use_legacy ? c_awaddr : use_runtime ? r_awaddr : 32'd0;
 wire c_wvalid,r_wvalid;
 assign wvalid_o=use_legacy ? c_wvalid : use_runtime ? r_wvalid : 1'd0;
 wire [127:0] c_wdata,r_wdata;
 assign wdata_o=use_legacy ? c_wdata : use_runtime ? r_wdata : 128'd0;
 wire [15:0] c_wstrb,r_wstrb;
 assign wstrb_o=use_legacy ? c_wstrb : use_runtime ? r_wstrb : 16'd0;
 wire c_wlast,r_wlast;
 assign wlast_o=use_legacy ? c_wlast : use_runtime ? r_wlast : 1'd0;
 wire c_bready,r_bready;
 assign bready_o=use_legacy ? c_bready : use_runtime ? r_bready : 1'd0;
 student_frame_axi_core #(.SUPPORT_COLOR(0)) legacy(
 .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(1'b0),
 .width_i(width_i),.height_i(height_i),.joint_i(joint_i),.camera_layout_i(camera_layout_i),.output_mode_i(output_mode_i),.input_base_i(input_base_i),.output_base_i(output_base_i),
 .busy_o(cb),.done_o(cd),.error_o(ce),.color_model_o(),.pixels_done_o(legacy_pixels),
 .tile_input_valid_o(tile_input_valid_o),.tile_input_ready_i(tile_input_ready_i),.tile_input_pixel_o(tile_input_pixel_o),
 .tile_start_valid_o(tile_start_valid_o),.tile_start_ready_i(tile_start_ready_i),.tile_result_valid_i(tile_result_valid_i),.tile_result_ready_o(tile_result_ready_o),.tile_result_pixel_i(tile_result_pixel_i),.tile_result_address_i(tile_result_address_i),
 .arvalid_o(c_arvalid),
  .araddr_o(c_araddr),
  .rready_o(c_rready),
  .awvalid_o(c_awvalid),
  .awaddr_o(c_awaddr),
  .wvalid_o(c_wvalid),
  .wdata_o(c_wdata),
  .wstrb_o(c_wstrb),
  .wlast_o(c_wlast),
  .bready_o(c_bready),
  .arready_i(arready_i && use_legacy),
  .rvalid_i(rvalid_i && use_legacy),
  .awready_i(awready_i && use_legacy),
  .wready_i(wready_i && use_legacy),
  .bvalid_i(bvalid_i && use_legacy),
  .rlast_i(rlast_i),
  .rresp_i(rresp_i),
  .rdata_i(rdata_i),
  .bresp_i(bresp_i));
 full_student_runtime latest(
 .clk_i(clk_i),.rst_n_i(rst_n_i),.load_start_i(accept_load),.load_program_i(reg_data_i[1]),.load_1080_i(reg_data_i[3:2]),.load_bytes_i(length),.load_crc_i(crc),
 .load_valid_i(owner==LOADING && fill==16),.load_ready_o(ready),.load_data_i(fifo),
 .frame_start_i(accept_frame),.frame_1080_i(width_i==256 && height_i==224 ? 2'd2 : width_i==1920 ? 2'd1 : 2'd0),.frame_joint_i(joint_i),.frame_mode_i(output_mode_i),.camera_layout_i(camera_layout_i),.input_base_i(input_base_i),
 .busy_o(rb),.done_o(rd),.error_o(re),.error_code_o(error_code),.weights_ready_o(wr),.program_ready_o(pr),.program_1080_o(hd),
 .content_status_o(content_status),.bytes_done_o(bytes),.pixels_done_o(pixels),.command_index_o(commands),.model_cycles_o(cycles),.task_cycles_o(task_cycles),
 .arvalid_o(r_arvalid),
  .araddr_o(r_araddr),
  .rready_o(r_rready),
  .awvalid_o(r_awvalid),
  .awaddr_o(r_awaddr),
  .wvalid_o(r_wvalid),
  .wdata_o(r_wdata),
  .wstrb_o(r_wstrb),
  .wlast_o(r_wlast),
  .bready_o(r_bready),
  .arready_i(arready_i && use_runtime),
  .rvalid_i(rvalid_i && use_runtime),
  .awready_i(awready_i && use_runtime),
  .wready_i(wready_i && use_runtime),
  .bvalid_i(bvalid_i && use_runtime),
  .rlast_i(rlast_i),
  .rresp_i(rresp_i),
  .rdata_i(rdata_i),
  .bresp_i(bresp_i));
 wire [7:0] content_status;
 always @(*)begin
  read_data_o=0;
  case(read_addr_i)
   7'h65:read_data_o={4'd0,hd,load_config[1:0]};
   7'h66:read_data_o={rejected|overflow,(owner==LOADING && fill<16),(hd==1),pr,wr,re,rd,rb};
   7'h67:read_data_o=overflow ? 8'h81 : rejected ? 8'h80 : error_code;
   7'h68,7'h69,7'h6a,7'h6b:read_data_o=length[(read_addr_i-7'h68)*8+:8];
   7'h6c,7'h6d,7'h6e,7'h6f:read_data_o=crc[(read_addr_i-7'h6c)*8+:8];
   7'h71:read_data_o=owner==LOADING && rb ? 8'd16-{3'd0,fill} : 8'd0;
   7'h72,7'h73,7'h74,7'h75:read_data_o=bytes[(read_addr_i-7'h72)*8+:8];
   7'h76,7'h77,7'h78,7'h79:read_data_o=commands[(read_addr_i-7'h76)*8+:8];
   7'h7a,7'h7b,7'h7c,7'h7d:read_data_o=timing_valid ? timing_snapshot[((timing_high ? 32 : 0)+(read_addr_i-7'h7a)*8)+:8] : cycles[(read_addr_i-7'h7a)*8+:8];
   7'h7e:read_data_o=8'hf9;
   7'h7f:read_data_o=content_status;
  endcase
 end
 assign flash_ready_o=owner==LOADING && rb && fill<16;
 assign color_model_o=output_mode_i==0;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin timing_snapshot<=0;timing_high<=0;timing_valid<=0;owner<=IDLE;frame_is_latest<=0;frame_done<=0;frame_error<=0;length<=0;crc<=0;load_config<=0;fill<=0;fifo<=0;rejected<=0;overflow<=0;end
  else begin
   if(owner==LOADING && fill==16 && ready)fill<=0;
   if(flash_valid_i && flash_ready_o)begin fifo[fill*8+:8]<=flash_data_i;fill<=fill+1'b1;end
   if(reg_write_i)begin
    if(reg_addr_i==7'h7b)begin timing_snapshot<=reg_data_i[0] ? task_cycles : cycles;timing_valid<=1;end
    if(reg_addr_i==7'h7a)timing_high<=reg_data_i[0];
    if(reg_addr_i==7'h7c)timing_valid<=0;
    if(owner==IDLE)case(reg_addr_i)
     7'h68,7'h69,7'h6a,7'h6b:length[(reg_addr_i-7'h68)*8+:8]<=reg_data_i;
     7'h6c,7'h6d,7'h6e,7'h6f:crc[(reg_addr_i-7'h6c)*8+:8]<=reg_data_i;
    endcase
    if(reg_addr_i==7'h70)begin
     if(owner==LOADING && rb && fill<16 && !flash_valid_i)begin fifo[fill*8+:8]<=reg_data_i;fill<=fill+1;end
     else overflow<=1;
    end
   end
   if(load_request && !accept_load)rejected<=1;
   if(accept_load)begin owner<=LOADING;load_config<=reg_data_i[3:0];fill<=0;rejected<=0;overflow<=0;frame_done<=0;frame_error<=0;end
   else if(accept_frame)begin owner<=LATEST;frame_is_latest<=1;frame_done<=0;frame_error<=0;end
   else if(owner==LEGACY && cd && !cb)begin owner<=IDLE;frame_done<=1;frame_error<=ce;end
   else if(owner==LATEST && rd && !rb)begin owner<=IDLE;frame_done<=1;frame_error<=re;end
   else if(owner==LOADING && rd && !rb)begin owner<=IDLE;fill<=0;end
  end
 end
endmodule
