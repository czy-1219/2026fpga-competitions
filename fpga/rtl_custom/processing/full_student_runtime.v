`timescale 1ns/1ps
 



module full_student_runtime #(parameter SHARED_NONCONV=1)(
 input wire clk_i,rst_n_i,
 input wire load_start_i,load_program_i,input wire [1:0] load_1080_i,
 input wire [31:0] load_bytes_i,load_crc_i,
 input wire load_valid_i,output wire load_ready_o,input wire [127:0] load_data_i,
 input wire frame_start_i,frame_joint_i,camera_layout_i,input wire [1:0] frame_1080_i,input wire [1:0] frame_mode_i,input wire [31:0] input_base_i,
 output reg busy_o,done_o,error_o,output reg [7:0] error_code_o,
 output reg weights_ready_o,program_ready_o,output reg [1:0] program_1080_o,
 output wire [31:0] bytes_done_o,pixels_done_o,command_index_o,output wire [7:0] content_status_o,
 output wire [63:0] model_cycles_o,task_cycles_o,
 output wire arvalid_o,input wire arready_i,output wire [31:0] araddr_o,
 input wire rvalid_i,rlast_i,input wire [1:0] rresp_i,input wire [127:0] rdata_i,output wire rready_o,
 output wire awvalid_o,input wire awready_i,output wire [31:0] awaddr_o,
 output wire wvalid_o,input wire wready_i,output wire [127:0] wdata_o,output wire [15:0] wstrb_o,output wire wlast_o,
 input wire bvalid_i,input wire [1:0] bresp_i,output wire bready_o
);
 `include "variants/full_student_20261018/runtime/model_metadata.vh"
 localparam IDLE=0,LOAD_START=1,LOAD_RUN=2,FRAME_START=3,FRAME_RUN=4,FINISH=5;
 reg [2:0] phase;reg is_program,camera,joint;reg [1:0] hd;reg [1:0] mode;reg [31:0] source,length,expected;
 wire loading=phase==LOAD_START || phase==LOAD_RUN;
 wire computing=phase==FRAME_START || phase==FRAME_RUN;
 wire lv,lw,lb,ld,le,lr,fv,fw,fb,fd,fe,ready,rsp,error;
 wire [3:0] lec;wire [7:0] fec;wire [31:0] la,fa;wire [127:0] ldata,fdata,rdata;wire [15:0] lst,fst;
 assign load_ready_o=loading && lr;
 full_student_model_loader loader(
  .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(phase==LOAD_START),.program_i(is_program),.bytes_i(length),.crc_i(expected),
  .data_valid_i(loading && load_valid_i),.data_ready_o(lr),.data_i(load_data_i),.busy_o(lb),.done_o(ld),.error_o(le),.error_code_o(lec),.bytes_done_o(bytes_done_o),.crc_o(),
  .mem_valid_o(lv),.mem_ready_i(loading && ready),.mem_write_o(lw),.mem_addr_o(la),.mem_wdata_o(ldata),.mem_wstrb_o(lst),.mem_rsp_valid_i(loading && rsp),.mem_error_i(error),.mem_rdata_i(rdata));
 full_student_frame_job #(.SHARED_NONCONV(SHARED_NONCONV),.HEAD_FILTER(1)) frame(
  .head_mask_i(joint ? 3'b001 : mode==1 ? 3'b010 : mode==2 ? 3'b100 : 3'b001),.program_1080_i(hd),
  .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(phase==FRAME_START),.model_ready_i(weights_ready_o && program_ready_o && program_1080_o==hd),.camera_layout_i(camera),
  .pixels_i(hd==2 ? 32'd57344 : hd==1 ? 32'd2073600 : 32'd614400),.input_base_i(source),.output_base_i(32'h02000000),
  .command_count_i(joint ? (hd==2 ? ROI_COMMANDS : hd==1 ? HD_COMMANDS : LCD_COMMANDS) : (hd==2 ? ROI_MODEL_COMMANDS : hd==1 ? HD_MODEL_COMMANDS : LCD_MODEL_COMMANDS)),
  .model_output_i(mode==1 ? SHARED_GRAY_OUTPUT : mode==2 ? SHARED_TEXT_OUTPUT : (hd==1 ? HD_MODEL_OUTPUT : LCD_MODEL_OUTPUT)),
  .busy_o(fb),.done_o(fd),.error_o(fe),.error_code_o(fec),.command_index_o(command_index_o),.cycles_o(model_cycles_o),.task_cycles_o(task_cycles_o),.pixels_done_o(pixels_done_o),.stage_o(),.content_status_o(content_status_o),
  .mem_valid_o(fv),.mem_ready_i(computing && ready),.mem_write_o(fw),.mem_addr_o(fa),.mem_wdata_o(fdata),.mem_wstrb_o(fst),.mem_rsp_valid_i(computing && rsp),.mem_error_i(error),.mem_rdata_i(rdata));
 full_student_mem_axi bridge(
  .clk_i(clk_i),.rst_n_i(rst_n_i),.req_valid_i(loading ? lv : computing && fv),.req_ready_o(ready),.req_write_i(loading ? lw : fw),.req_addr_i(loading ? la : fa),.req_data_i(loading ? ldata : fdata),.req_strb_i(loading ? lst : fst),
  .rsp_valid_o(rsp),.rsp_error_o(error),.rsp_data_o(rdata),
  .arvalid_o(arvalid_o),.arready_i(arready_i),.araddr_o(araddr_o),.rvalid_i(rvalid_i),.rlast_i(rlast_i),.rresp_i(rresp_i),.rdata_i(rdata_i),.rready_o(rready_o),
  .awvalid_o(awvalid_o),.awready_i(awready_i),.awaddr_o(awaddr_o),.wvalid_o(wvalid_o),.wready_i(wready_i),.wdata_o(wdata_o),.wstrb_o(wstrb_o),.wlast_o(wlast_o),.bvalid_i(bvalid_i),.bresp_i(bresp_i),.bready_o(bready_o));
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   phase<=IDLE;is_program<=0;hd<=0;camera<=0;joint<=0;mode<=0;source<=0;length<=0;expected<=0;
   busy_o<=0;done_o<=0;error_o<=0;error_code_o<=0;weights_ready_o<=0;program_ready_o<=0;program_1080_o<=0;
  end else case(phase)
   IDLE:if(load_start_i || frame_start_i)begin
    busy_o<=1;done_o<=0;error_o<=0;error_code_o<=0;
    if(load_start_i)begin
     is_program<=load_program_i;hd<=load_1080_i;length<=load_bytes_i;expected<=load_crc_i;
     program_ready_o<=0;if(!load_program_i)weights_ready_o<=0;
     if(frame_start_i || load_1080_i==3 || load_bytes_i!=(load_program_i ? (load_1080_i==2 ? ROI_BYTES : load_1080_i==1 ? HD_BYTES : LCD_BYTES) : MODEL_BYTES) ||
        load_crc_i!=(load_program_i ? (load_1080_i==2 ? ROI_CRC : load_1080_i==1 ? HD_CRC : LCD_CRC) : MODEL_CRC))
      begin error_o<=1;error_code_o<=8'h40;phase<=FINISH;end
     else phase<=LOAD_START;
    end else begin
     hd<=frame_1080_i;joint<=frame_joint_i;camera<=camera_layout_i;source<=input_base_i;mode<=frame_mode_i;
     if(frame_1080_i==3 || (camera_layout_i && frame_1080_i==2) || !weights_ready_o || !program_ready_o || program_1080_o!=frame_1080_i || frame_mode_i==3)
      begin error_o<=1;error_code_o<=8'h41;phase<=FINISH;end
     else phase<=FRAME_START;
    end
   end
   LOAD_START:phase<=LOAD_RUN;
   LOAD_RUN:if(ld && !lb)begin
    error_o<=le;error_code_o<=le ? {4'h5,lec} : 8'd0;
    if(!le)begin if(is_program)begin program_ready_o<=1;program_1080_o<=hd;end else weights_ready_o<=1;end
    phase<=FINISH;
   end
   FRAME_START:phase<=FRAME_RUN;
   FRAME_RUN:if(fd && !fb)begin error_o<=fe;error_code_o<=fec;phase<=FINISH;end
   FINISH:begin busy_o<=0;done_o<=1;phase<=IDLE;end
   default:begin error_o<=1;error_code_o<=255;phase<=FINISH;end
  endcase
 end
endmodule
