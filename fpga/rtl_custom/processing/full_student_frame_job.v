`timescale 1ns/1ps
 


module full_student_frame_job #(parameter SHARED_NONCONV=0,parameter HEAD_FILTER=0)(
 input wire clk_i,rst_n_i,start_i,model_ready_i,camera_layout_i,
 input wire [2:0] head_mask_i,input wire [1:0] program_1080_i,
 input wire [31:0] pixels_i,input_base_i,output_base_i,command_count_i,model_output_i,
 output reg busy_o,done_o,error_o,output reg [7:0] error_code_o,
 output wire [31:0] command_index_o,output wire [63:0] cycles_o,output reg [63:0] task_cycles_o,
 output wire [31:0] pixels_done_o,output wire [2:0] stage_o,output wire [7:0] content_status_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,LOAD=1,INPUT_WAIT=2,EXECUTE=3,EXEC_WAIT=4,STORE=5,OUTPUT_WAIT=6,FINISH=7;
 reg [2:0] stage;reg camera;reg [31:0] pixels,source,dest,count,model_output;
 reg [2:0] selected_heads;reg [1:0] selected_hd;
 reg input_nonzero,tensor_nonzero,result_nonzero;
  

 assign content_status_o={1'b1,input_nonzero,tensor_nonzero,result_nonzero,done_o,stage};
 wire exec_active=stage==EXECUTE || stage==EXEC_WAIT;
 wire output_active=stage==STORE || stage==OUTPUT_WAIT;
 wire io_active=stage==LOAD || stage==INPUT_WAIT || output_active;
 wire iv,iw,ib,id,ie,ev,ew,eb,ed,ee;wire [31:0] ia,ea,ip;
 wire [127:0] iwd,ewd;wire [15:0] ist,est;wire [7:0] ec;
 wire [31:0] chosen_addr=exec_active ? ea : ia;
 wire legal=chosen_addr[3:0]==0 && {1'b0,chosen_addr}+33'd16<=33'h008000000;
 reg rejected;wire active=exec_active || io_active;
 assign stage_o=stage;assign pixels_done_o=done_o && !error_o ? pixels : output_active ? ip : 0;
 assign mem_valid_o=active && legal && (exec_active ? ev : iv);
 assign mem_write_o=exec_active ? ew : iw;assign mem_addr_o=chosen_addr;
 assign mem_wdata_o=exec_active ? ewd : iwd;assign mem_wstrb_o=exec_active ? est : ist;
 full_student_frame_io frame_io(
  .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(stage==LOAD || stage==STORE),.to_rgb565_i(output_active),.camera_layout_i(camera),
  .pixels_i(pixels),.input_base_i(output_active ? model_output : source),.output_base_i(output_active ? dest : 32'h04000000),
  .busy_o(ib),.done_o(id),.error_o(ie),.pixels_done_o(ip),
  .mem_valid_o(iv),.mem_ready_i(io_active && (legal ? mem_ready_i : 1'b1)),.mem_write_o(iw),.mem_addr_o(ia),.mem_wdata_o(iwd),.mem_wstrb_o(ist),
  .mem_rsp_valid_i(io_active && (mem_rsp_valid_i || rejected)),.mem_error_i(mem_error_i || rejected),.mem_rdata_i(mem_rdata_i));
 full_student_executor #(.SHARED_NONCONV(SHARED_NONCONV),.HEAD_FILTER(HEAD_FILTER)) executor(
  .head_mask_i(selected_heads),.program_1080_i(selected_hd),
  .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(stage==EXECUTE),.program_base_i(32'h03a00000),.command_count_i(count),.memory_limit_i(32'h08000000),
  .busy_o(eb),.done_o(ed),.error_o(ee),.error_code_o(ec),.command_index_o(command_index_o),.cycles_o(cycles_o),.outputs_o(),.clipped_o(),
  .mem_valid_o(ev),.mem_ready_i(exec_active && (legal ? mem_ready_i : 1'b1)),.mem_write_o(ew),.mem_addr_o(ea),.mem_wdata_o(ewd),.mem_wstrb_o(est),
  .mem_rsp_valid_i(exec_active && (mem_rsp_valid_i || rejected)),.mem_error_i(mem_error_i || rejected),.mem_rdata_i(mem_rdata_i));
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   task_cycles_o<=0;stage<=IDLE;camera<=0;pixels<=0;source<=0;dest<=0;count<=0;model_output<=0;rejected<=0;selected_heads<=7;selected_hd<=0;
   busy_o<=0;done_o<=0;error_o<=0;error_code_o<=0;input_nonzero<=0;tensor_nonzero<=0;result_nonzero<=0;
  end else begin
   if(busy_o)task_cycles_o<=task_cycles_o+1;
   rejected<=active && !legal && (exec_active ? ev : iv);
   if(io_active && iv && legal && mem_ready_i && iw && |iwd)begin
    if(output_active)result_nonzero<=1;else input_nonzero<=1;
   end
   if(output_active && mem_rsp_valid_i && !iw && !mem_error_i && |mem_rdata_i)tensor_nonzero<=1;
   case(stage)
    IDLE:if(start_i)begin
     task_cycles_o<=0;busy_o<=1;done_o<=0;error_o<=0;error_code_o<=0;
     input_nonzero<=0;tensor_nonzero<=0;result_nonzero<=0;
     camera<=camera_layout_i;pixels<=pixels_i;source<=input_base_i;dest<=output_base_i;count<=command_count_i;model_output<=model_output_i;
     selected_heads<=head_mask_i;selected_hd<=program_1080_i;
     if(!model_ready_i || pixels_i==0 || pixels_i>2073600 || pixels_i[2:0]!=0 || input_base_i[3:0]!=0 || output_base_i!=32'h02000000 ||
        {1'b0,input_base_i}+({1'b0,pixels_i}<<1)>33'h003000000 || model_output_i<32'h04000000 || model_output_i[3:0]!=0 ||
        {1'b0,model_output_i}+({1'b0,pixels_i}<<2)+({1'b0,pixels_i}<<1)>33'h008000000 || command_count_i==0 || command_count_i>49152)
      begin error_o<=1;error_code_o<=1;stage<=FINISH;end
     else stage<=LOAD;
    end
    LOAD:stage<=INPUT_WAIT;
    INPUT_WAIT:if(id && !ib)begin
     if(ie)begin error_o<=1;error_code_o<=2;stage<=FINISH;end else stage<=EXECUTE;
    end
    EXECUTE:stage<=EXEC_WAIT;
    EXEC_WAIT:if(ed && !eb)begin
     if(ee)begin error_o<=1;error_code_o<=ec;stage<=FINISH;end else stage<=STORE;
    end
    STORE:stage<=OUTPUT_WAIT;
    OUTPUT_WAIT:if(id && !ib)begin error_o<=ie;error_code_o<=ie ? 8'd3 : 8'd0;stage<=FINISH;end
    FINISH:begin busy_o<=0;done_o<=1;stage<=IDLE;end
    default:begin error_o<=1;error_code_o<=255;stage<=FINISH;end
   endcase
  end
 end
endmodule
