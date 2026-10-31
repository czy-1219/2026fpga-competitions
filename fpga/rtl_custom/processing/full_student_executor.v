`timescale 1ns/1ps

 













module full_student_executor #(parameter WEIGHT_CACHE_LOG2=9,parameter SHARED_NONCONV=0,parameter HEAD_FILTER=0)(

 input wire clk_i,rst_n_i,start_i,input wire [31:0] program_base_i,command_count_i,memory_limit_i,
 input wire [2:0] head_mask_i,input wire [1:0] program_1080_i,

 output reg busy_o,done_o,error_o,output reg [7:0] error_code_o,

 output reg [31:0] command_index_o,output reg [63:0] cycles_o,outputs_o,clipped_o,

 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,

 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,

 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i

);

 localparam IDLE=0,FETCH=1,FETCH_WAIT=2,DECODE=3,LAUNCH=4,ARM=5,RUN=6,FINISH=7,ADVANCE=8;

  

 `include "variants/full_student_20261018/runtime/head_dispatch_metadata.vh"
 wire skip_command;
 generate if(HEAD_FILTER)begin: head_dispatch
  (* syn_ramstyle="block_ram" *) reg [2:0] command_heads[0:HEAD_TABLE_WORDS-1];
  reg [2:0] selected_heads;
  wire [31:0] table_address=command_index_o+(program_1080_i==2 ? HEAD_LOCAL_OFFSET : program_1080_i==1 ? HEAD_LCD_COMMANDS : 0);
  initial $readmemh("variants/full_student_20261018/runtime/head_dispatch.mem",command_heads);
   

  always @(posedge clk_i)begin
   if(state==FETCH)selected_heads<=command_heads[table_address];
  end
  assign skip_command=(selected_heads & head_mask_i)==0;
 end else begin: all_heads
  assign skip_command=1'b0;
 end endgenerate

 reg [3:0] state;reg [1023:0] command;reg [31:0] pc,count,limit;reg [2:0] beat;reg fetch_valid;

 reg [1:0] selected;wire [3:0] eb,ed,ee,ev,ew;wire [31:0] en[0:3],ec[0:3],ea[0:3];wire [127:0] ewdata[0:3];wire [15:0] estrb[0:3];

 wire in_engine=state==LAUNCH || state==ARM || state==RUN;

 wire legal_address={1'b0,ea[selected]}+33'd16<={1'b0,limit} && ea[selected][3:0]==0;

 wire eready=in_engine && (legal_address ? mem_ready_i : 1'b1);

 reg rejected;wire eresp=in_engine && (mem_rsp_valid_i || rejected);wire eerror=mem_error_i || rejected;

 wire [3:0] starts=(state==LAUNCH) ? (4'b0001<<selected) : 4'd0;

 wire [3:0] ready_vec=(in_engine && eready) ? (4'b0001<<selected) : 4'd0;

 wire [3:0] rsp_vec=eresp ? (4'b0001<<selected) : 4'd0;

  

 wire first_scalar=command[416+:32]==1;
 wire second_scalar=command[640+:32]==1;
 wire first_scalar_exact=command[384+:4]==0 && $signed(command[384+:32])>=-32'sd524288 && $signed(command[384+:32])<=32'sd524272;
 wire second_scalar_exact=command[608+:4]==0 && $signed(command[608+:32])>=-32'sd524288 && $signed(command[608+:32])<=32'sd524272;
 wire first_tensor_exact=command[416+:32]==0 && command[352+:32]==12 && command[272+:16]==0 && command[304+:16]==0 && command[336+:16]==0 && !command[224] && !command[256] && !command[288] && !command[320];
 wire second_tensor_exact=command[640+:32]==0 && command[576+:32]==12 && command[496+:16]==0 && command[528+:16]==0 && command[560+:16]==0 && !command[448] && !command[480] && !command[512] && !command[544];
 wire first_alias_safe=first_scalar || command[224+:32]!=command[96+:32] || command[256+:96]==command[128+:96];
 wire second_alias_safe=second_scalar || command[448+:32]!=command[96+:32] || command[480+:96]==command[128+:96];
 wire [31:0] vector_op=command[0+:32];
 wire compare_op=vector_op==13 || vector_op==14;
 wire raw_sub_op=vector_op==1 && ((first_scalar && !first_scalar_exact) || (second_scalar && !second_scalar_exact));
 wire third_scalar=command[864+:32]==1;
 wire third_exact=third_scalar ? (command[832+:4]==0 && $signed(command[832+:32])>=-32'sd524288 && $signed(command[832+:32])<=32'sd524272) :
  (command[864+:32]==0 && command[800+:32]==12 && command[720+:16]==0 && command[752+:16]==0 && command[784+:16]==0 && !command[672] && !command[704] && !command[736] && !command[768]);
 wire wide_first=command[384+:4]==0 && $signed(command[384+:32])>=-32'sd2097152 && $signed(command[384+:32])<=32'sd2097136;
 wire wide_second=command[608+:4]==0 && $signed(command[608+:32])>=-32'sd2097152 && $signed(command[608+:32])<=32'sd2097136;
 wire raw_first=$signed(command[384+:32])>=-32'sd2097152 && $signed(command[384+:32])<=32'sd2097152;
 wire raw_second=$signed(command[608+:32])>=-32'sd2097152 && $signed(command[608+:32])<=32'sd2097152;
 wire first_constant_ok=compare_op || (raw_sub_op ? raw_first : vector_op==2 ? wide_first : first_scalar_exact);
 wire second_constant_ok=compare_op || (raw_sub_op ? raw_second : vector_op==2 ? wide_second : second_scalar_exact);
 wire vector_hardware=SHARED_NONCONV && command[992+:8]==2 && (vector_op==0 || vector_op==1 || vector_op==2 || vector_op==4 || compare_op || vector_op==18) && command[80+:8]==12 &&
  (first_scalar ? first_constant_ok : first_tensor_exact) && (second_scalar ? second_constant_ok : second_tensor_exact) &&
  (vector_op!=18 || (third_exact && (third_scalar || command[672+:32]!=command[96+:32] || command[704+:96]==command[128+:96]))) &&
  first_alias_safe && second_alias_safe && command[144+:16]==0 && command[176+:16]==0 && command[208+:16]==0 && !command[96] && !command[128] && !command[160] && !command[192];
 reg [1023:0] vector_transform;
 always @(*)begin
  vector_transform=0;
  vector_transform[0+:32]=vector_op==0 ? 32'd9 : vector_op==1 ? (raw_sub_op ? 32'd15 : 32'd7) : vector_op==2 ? 32'd14 : vector_op==4 ? 32'd10 : vector_op==13 ? 32'd11 : vector_op==14 ? 32'd12 : 32'd13;
  vector_transform[32+:32]=command[32+:32];vector_transform[64+:32]=command[32+:32];
  vector_transform[96+:32]={16'd0,command[64+:16]};
  vector_transform[128+:32]=command[224+:32];vector_transform[160+:96]=command[256+:96];
  vector_transform[256+:32]=command[96+:32];vector_transform[288+:96]=command[128+:96];
  vector_transform[384+:32]=32'h00000c0c;
  vector_transform[480+:32]=command[448+:32];vector_transform[512+:96]=command[480+:96];
  vector_transform[608]=first_scalar;vector_transform[609]=second_scalar;vector_transform[610]=third_scalar;
  if(compare_op || raw_sub_op)begin vector_transform[416+:32]=command[384+:32];vector_transform[448+:32]=command[608+:32];end
  vector_transform[640+:16]=command[388+:16];vector_transform[656+:16]=command[612+:16];
  if(vector_op==2)begin vector_transform[640+:18]=command[388+:18];vector_transform[672+:18]=command[612+:18];end
  vector_transform[704+:16]=command[836+:16];vector_transform[736+:32]=command[672+:32];vector_transform[768+:96]=command[704+:96];
 end
 function stride_fits;input [31:0] a;begin stride_fits=(a[31:16]==0)||(a[31:15]==17'h1ffff);end endfunction
 wire [1023:0] transform_command=vector_hardware ? vector_transform : command;

 full_student_conv16 #(.WEIGHT_CACHE_LOG2(WEIGHT_CACHE_LOG2)) conv(

  .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(starts[0]),.iw_i(command[0+:16]),.ih_i(command[16+:16]),.ic_i(command[32+:16]),.oc_i(command[48+:16]),.ow_i(command[64+:16]),.oh_i(command[80+:16]),

  .kernel_i(command[96+:4]),.stride_i(command[100+:4]),.dilation_i(command[104+:4]),.pad_i(command[108+:4]),.relu_i(command[112]),.input_base_i(command[128+:32]),.weight_base_i(command[160+:32]),.param_base_i(command[192+:32]),.output_base_i(command[224+:32]),

  .busy_o(eb[0]),.done_o(ed[0]),.error_o(ee[0]),.outputs_o(en[0]),.mem_valid_o(ev[0]),.mem_ready_i(ready_vec[0]),.mem_write_o(ew[0]),.mem_addr_o(ea[0]),.mem_wdata_o(ewdata[0]),.mem_wstrb_o(estrb[0]),.mem_rsp_valid_i(rsp_vec[0]),.mem_error_i(eerror),.mem_rdata_i(mem_rdata_i));

 assign ec[0]=0;

 generate if(SHARED_NONCONV)begin: shared_ops

  full_student_nonconv_cpu engine(.clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(|starts[2:1]),.command_i(command),.busy_o(eb[1]),.done_o(ed[1]),.error_o(ee[1]),.outputs_o(en[1]),.clipped_o(ec[1]),.mem_valid_o(ev[1]),.mem_ready_i(|ready_vec[2:1]),.mem_write_o(ew[1]),.mem_addr_o(ea[1]),.mem_wdata_o(ewdata[1]),.mem_wstrb_o(estrb[1]),.mem_rsp_valid_i(|rsp_vec[2:1]),.mem_error_i(eerror),.mem_rdata_i(mem_rdata_i));

  genvar j;for(j=2;j<3;j=j+1)begin: aliases

   assign eb[j]=eb[1];assign ed[j]=ed[1];assign ee[j]=ee[1];assign en[j]=en[1];assign ec[j]=ec[1];assign ev[j]=ev[1];assign ew[j]=ew[1];assign ea[j]=ea[1];assign ewdata[j]=ewdata[1];assign estrb[j]=estrb[1];

  end

 full_student_transform16 transform(.clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(starts[3]),.command_i(transform_command),.busy_o(eb[3]),.done_o(ed[3]),.error_o(ee[3]),.outputs_o(en[3]),.clipped_o(ec[3]),.mem_valid_o(ev[3]),.mem_ready_i(ready_vec[3]),.mem_write_o(ew[3]),.mem_addr_o(ea[3]),.mem_wdata_o(ewdata[3]),.mem_wstrb_o(estrb[3]),.mem_rsp_valid_i(rsp_vec[3]),.mem_error_i(eerror),.mem_rdata_i(mem_rdata_i));

 end else begin: dedicated_ops

 full_student_vector16 vector(.clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(starts[1]),.command_i(command),.busy_o(eb[1]),.done_o(ed[1]),.error_o(ee[1]),.outputs_o(en[1]),.clipped_o(ec[1]),.mem_valid_o(ev[1]),.mem_ready_i(ready_vec[1]),.mem_write_o(ew[1]),.mem_addr_o(ea[1]),.mem_wdata_o(ewdata[1]),.mem_wstrb_o(estrb[1]),.mem_rsp_valid_i(rsp_vec[1]),.mem_error_i(eerror),.mem_rdata_i(mem_rdata_i));

 full_student_reduce16 reduce(.clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(starts[2]),.command_i(command),.busy_o(eb[2]),.done_o(ed[2]),.error_o(ee[2]),.outputs_o(en[2]),.clipped_o(ec[2]),.mem_valid_o(ev[2]),.mem_ready_i(ready_vec[2]),.mem_write_o(ew[2]),.mem_addr_o(ea[2]),.mem_wdata_o(ewdata[2]),.mem_wstrb_o(estrb[2]),.mem_rsp_valid_i(rsp_vec[2]),.mem_error_i(eerror),.mem_rdata_i(mem_rdata_i));

 full_student_transform16 transform(.clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(starts[3]),.command_i(command),.busy_o(eb[3]),.done_o(ed[3]),.error_o(ee[3]),.outputs_o(en[3]),.clipped_o(ec[3]),.mem_valid_o(ev[3]),.mem_ready_i(ready_vec[3]),.mem_write_o(ew[3]),.mem_addr_o(ea[3]),.mem_wdata_o(ewdata[3]),.mem_wstrb_o(estrb[3]),.mem_rsp_valid_i(rsp_vec[3]),.mem_error_i(eerror),.mem_rdata_i(mem_rdata_i));

 end endgenerate

 assign mem_valid_o=in_engine ? ev[selected] && legal_address : fetch_valid;

 assign mem_write_o=in_engine ? ew[selected] : 1'b0;

 assign mem_addr_o=in_engine ? ea[selected] : pc+{25'd0,beat,4'd0};

 assign mem_wdata_o=in_engine ? ewdata[selected] : 128'd0;

 assign mem_wstrb_o=in_engine ? estrb[selected] : 16'd0;

 always @(posedge clk_i or negedge rst_n_i)begin

  if(!rst_n_i)begin

   state<=IDLE;command<=0;pc<=0;count<=0;limit<=0;beat<=0;fetch_valid<=0;selected<=0;rejected<=0;

   busy_o<=0;done_o<=0;error_o<=0;error_code_o<=0;command_index_o<=0;cycles_o<=0;outputs_o<=0;clipped_o<=0;

  end else begin

   rejected<=in_engine && ev[selected] && eready && !legal_address;

   if(busy_o)cycles_o<=cycles_o+1;

   case(state)

    IDLE:if(start_i)begin

     busy_o<=1;done_o<=0;error_o<=0;error_code_o<=0;command_index_o<=0;cycles_o<=0;outputs_o<=0;clipped_o<=0;

     pc<=program_base_i;count<=command_count_i;limit<=memory_limit_i;beat<=0;

     if(program_base_i[6:0]!=0 || command_count_i==0 || command_count_i>32'h01ffffff ||
        (HEAD_FILTER && (head_mask_i==0 || command_count_i>(program_1080_i ? HEAD_TABLE_WORDS-HEAD_LCD_COMMANDS : HEAD_LCD_COMMANDS))) ||

        {1'b0,program_base_i}+({1'b0,command_count_i}<<7)>{1'b0,memory_limit_i})begin error_o<=1;error_code_o<=1;state<=FINISH;end else state<=FETCH;

    end

    FETCH:begin fetch_valid<=1;state<=FETCH_WAIT;end

    FETCH_WAIT:begin

     if(fetch_valid && mem_ready_i)fetch_valid<=0;

     if(mem_rsp_valid_i && !fetch_valid)begin

      if(mem_error_i)begin error_o<=1;error_code_o<=2;state<=FINISH;end

      else begin command[beat*128+:128]<=mem_rdata_i;if(beat==7)state<=DECODE;else begin beat<=beat+1;state<=FETCH;end end

     end

    end

    DECODE:begin

     if(command[1008+:16]!=16'hf516 || command[1000+:8]!=0 || command[992+:8]<1 || command[992+:8]>4)begin error_o<=1;error_code_o<=3;state<=FINISH;end

     else if(skip_command)state<=ADVANCE;
     else begin selected<=vector_hardware ? 2'd3 : (SHARED_NONCONV && command[992+:8]==4 && (command[384+:8]!=command[392+:8] || !stride_fits(command[160+:32]) || !stride_fits(command[192+:32]) || !stride_fits(command[224+:32]))) ? 2'd1 : command[992+:2]-2'd1;state<=LAUNCH;end

    end

    LAUNCH:state<=ARM;

    ARM:if(eb[selected])state<=RUN;else if(ed[selected])begin error_o<=1;error_code_o<=4;state<=FINISH;end

    RUN:if(ed[selected])begin

     outputs_o<=outputs_o+{32'd0,en[selected]};clipped_o<=clipped_o+{32'd0,ec[selected]};

     if(ee[selected])begin error_o<=1;error_code_o<=8'd16+{6'd0,selected};state<=FINISH;end

     else state<=ADVANCE;

    end

    ADVANCE:begin
     if(command_index_o+1==count)state<=FINISH;
     else begin command_index_o<=command_index_o+1;pc<=pc+128;beat<=0;state<=FETCH;end
    end

    FINISH:begin busy_o<=0;done_o<=1;fetch_valid<=0;state<=IDLE;end

    default:begin error_o<=1;error_code_o<=255;fetch_valid<=0;state<=FINISH;end

   endcase

  end

 end

endmodule

