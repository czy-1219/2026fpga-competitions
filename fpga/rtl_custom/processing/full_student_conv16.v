`timescale 1ns/1ps
 







module full_student_conv16 #(parameter LANES=8,parameter WEIGHT_CACHE_LOG2=9)(
 input wire clk_i,rst_n_i,start_i,
 input wire [15:0] iw_i,ih_i,ic_i,ow_i,oh_i,oc_i,
 input wire [3:0] kernel_i,stride_i,dilation_i,pad_i,
 input wire relu_i,
 input wire [31:0] input_base_i,weight_base_i,param_base_i,output_base_i,
 output reg busy_o,done_o,error_o,output reg [31:0] outputs_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,
 output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,PARAM=1,PARAM_GOT=2,SHIFT=3,SHIFT_GOT=4,BEGIN_DOT=5,
  TAP=6,INPUT_GOT=7,WEIGHT=8,WEIGHT_GOT=9,TERM=10,RESULT=11,
  WRITE_BUILD=12,WRITE_COMMIT=13,NEXT_PIXEL=14,NEXT_GROUP=15,WAIT_MEM=16,
  FINISH=17,SETUP_ROW=18,SETUP_PAD=19,WEIGHT_CACHED=20,INPUT_PROBE=21,CLEAR_INPUT=22;
 reg [4:0] state,ret;
 reg [15:0] iw,ih,ic,ow,oh,oc,ox,oy,ci,group_channel;
  
 wire [15:0] stripe_x={ox[15:4],4'b0};
 wire [16:0] next_stripe={1'b0,stripe_x}+17'd16;
 wire signed [17:0] stripe_col=$signed({2'b0,stripe_x})-$signed({14'd0,pad});
 wire signed [17:0] next_stripe_col=stripe_col+18'sd16;
  


 wire striped=ic==32 && oc==32 && kernel==3 && stride==1 && dilation==1 && ow==iw && ow>16;
 wire stripe_last_x={1'b0,ox}+17'd1>={1'b0,ow} || (striped && &ox[3:0]);
 reg [3:0] kernel,stride,dilation,pad,kx,ky;
 reg relu;
 reg [31:0] input_base,weight_group,param_group,output_base,weight_ptr,out_ptr;
 reg [31:0] rowbytes,pixelbytes,setup_count,weight_end;
 reg signed [31:0] first_row,first_col,row_step,krow,col_offset;
 reg signed [31:0] pad_row,pad_col,col_step;
 reg signed [17:0] sy,sx,row_y,col_x;
 reg [511:0] biases;reg [63:0] shifts;reg [2:0] param_word;
 reg signed [15:0] activation;reg [127:0] weights,result;
 reg [3:0] write_lane;reg [31:0] write_addr;reg [127:0] write_data;reg [15:0] write_strb;
 reg req_valid,req_write;reg [31:0] req_addr;reg [127:0] req_data,rsp_data;reg [15:0] req_strb;
 reg [31:0] input_cache_tag;reg [127:0] input_cache_data;reg input_cache_valid;
 reg [2:0] input_lane;
 reg activation_cached;reg prefetch_valid;
  


 reg lookahead_pending,lookahead_valid,lookahead_store;
 wire lookahead_response=lookahead_pending && mem_rsp_valid_i && !req_valid;

  



 (* syn_ramstyle="block_ram" *) reg [127:0] activation_lines[0:511];
 (* syn_ramstyle="block_ram" *) reg [26:0] activation_tags[0:511];
 reg [8:0] clear_index;
 reg [127:0] activation_line_q;reg [26:0] activation_tag_q;
 wire lookahead_enabled=ic[2:0]==0;
 wire prefetch_next=state==WEIGHT && cached_term && mac_tr && activation_cached &&
  (lookahead_enabled ? (input_addr[3:1]==0 && ci+8<ic) : (input_addr[3:1]==6 && ci+2<ic));
 wire [31:0] probe_addr=prefetch_next ? {input_addr[31:4]+28'd1,4'b0} : input_addr;
 

 wire [8:0] activation_index=striped ? {sy[1:0],sx[4:0],probe_addr[5:4]} : probe_addr[12:4]^{probe_addr[16:13],probe_addr[21:17]};
 wire [8:0] activation_fill_index=striped ? {sy[1:0],sx[4:0],req_addr[5:4]} : req_addr[12:4]^{req_addr[16:13],req_addr[21:17]};
 wire [8:0] tag_write_index=state==CLEAR_INPUT ? clear_index : activation_fill_index;
 wire [31:0] next_input_addr=input_addr+32'd16;
 wire prefetched_next_hit=prefetch_valid && activation_tag_q[26] && activation_tag_q[25:0]==next_input_addr[31:6];
 always @(posedge clk_i)begin
  if(!lookahead_enabled)prefetch_valid<=prefetch_next;
  else if(state==TAP)prefetch_valid<=0;else if(prefetch_next)prefetch_valid<=1;
  if(state==TAP || prefetch_next)begin
   activation_line_q<=activation_lines[activation_index];activation_tag_q<=activation_tags[activation_index];
  end
  if(state==INPUT_GOT || lookahead_store)begin
   activation_lines[activation_fill_index]<=rsp_data;
  end
  if(state==INPUT_GOT || lookahead_store || state==CLEAR_INPUT)
   activation_tags[tag_write_index]<=state==CLEAR_INPUT ? 27'd0 : {1'b1,req_addr[31:6]};
 end
 localparam CACHE_INDEX_BITS=WEIGHT_CACHE_LOG2>0 ? WEIGHT_CACHE_LOG2 : 1;
 localparam CACHE_WORDS=1<<CACHE_INDEX_BITS;
 (* syn_ramstyle="block_ram" *) reg [127:0] weight_cache[0:CACHE_WORDS-1];
 reg [127:0] weight_cache_q;reg cache_ready;reg [31:0] term_index;
 wire cache_read_enable=state==TAP || (cached_term && mac_tr);
 wire [CACHE_INDEX_BITS-1:0] cache_read_index=state==TAP ? term_index[CACHE_INDEX_BITS-1:0] : term_index[CACHE_INDEX_BITS-1:0]+1'b1;
  
 always @(posedge clk_i)begin
  if(cache_read_enable && WEIGHT_CACHE_LOG2>0)weight_cache_q<=weight_cache[cache_read_index];
  if(state==WEIGHT_GOT && !cache_ready && term_index<CACHE_WORDS && WEIGHT_CACHE_LOG2>0)
   weight_cache[term_index[CACHE_INDEX_BITS-1:0]]<=rsp_data;
 end
 wire [LANES-1:0] enables;
 wire [LANES*16-1:0] activated_result;
 genvar g;generate for(g=0;g<LANES;g=g+1)begin:en
  assign enables[g]=group_channel+g<oc;
   
  assign activated_result[g*16+:16]=(relu && mac_result[g*16+15]) ? 16'd0 : mac_result[g*16+:16];
 end endgenerate
 wire mac_sr,mac_tr,mac_rv,mac_overflow;wire [LANES*16-1:0] mac_result;
 wire cached_term=state==WEIGHT && WEIGHT_CACHE_LOG2>0 && cache_ready && term_index<CACHE_WORDS;
 wire [2:0] cached_input_lane=state==WEIGHT ? input_addr[3:1]+3'd1 : input_addr[3:1];
 wire signed [15:0] cached_activation=input_cache_data[cached_input_lane*16+:16];
 wire padding_tap=sy<0 || sy>=$signed({2'b0,ih}) || sx<0 || sx>=$signed({2'b0,iw});
 wire consecutive_cached_channel=activation_cached && ci+1<ic && input_addr[3:1]!=3'd7 && term_index+1<CACHE_WORDS;
 full_student_mac16 #(.LANES(LANES)) mac(
  .clk_i(clk_i),.rst_n_i(rst_n_i && !(state==FINISH && error_o)),.start_valid_i(state==BEGIN_DOT),.start_ready_o(mac_sr),
  .bias_i(biases[LANES*64-1:0]),.shift_i(shifts[LANES*8-1:0]),.lane_enable_i(enables),
  .term_valid_i(state==TERM || cached_term),.term_ready_o(mac_tr),.activation_i(activation),.weights_i(cached_term ? weight_cache_q[LANES*16-1:0] : weights[LANES*16-1:0]),
  .term_last_i(ci+1==ic && kx+1==kernel && ky+1==kernel),
  .result_valid_o(mac_rv),.result_ready_i(state==RESULT),.result_o(mac_result),
  .accumulator_o(),.saturated_o(),.overflow_o(mac_overflow));
 assign mem_valid_o=req_valid;assign mem_write_o=req_write;assign mem_addr_o=req_addr;
 assign mem_wdata_o=req_data;assign mem_wstrb_o=req_strb;
 task read_beat;input [31:0] addr;input [4:0] next_state;
  begin req_addr<={addr[31:4],4'b0};req_write<=0;req_valid<=1;ret<=next_state;state<=WAIT_MEM;end
 endtask
 task write_beat;input [31:0] addr;input [127:0] data;input [15:0] strb;input [4:0] next_state;
  begin req_addr<={addr[31:4],4'b0};req_data<=data;req_strb<=strb;req_write<=1;req_valid<=1;ret<=next_state;state<=WAIT_MEM;end
 endtask
 wire [31:0] input_addr=input_base+krow+col_offset+({16'd0,ci}<<1);
 wire [31:0] lane_address=out_ptr+({28'd0,write_lane}<<1);
 wire [2:0] out_lane=lane_address[3:1];
  

 task advance_term;
  begin
   weight_ptr<=weight_ptr+16;term_index<=term_index+1;
   if(ci+1<ic)ci<=ci+1;
   else begin
    ci<=0;
    if(kx+1<kernel)begin kx<=kx+1;sx<=sx+$signed({14'd0,dilation});col_offset<=col_offset+col_step;end
    else begin kx<=0;ky<=ky+1;sx<=col_x;sy<=sy+$signed({14'd0,dilation});col_offset<=first_col;krow<=krow+row_step;end
   end
   if(ci+1==ic && kx+1==kernel && ky+1==kernel)begin weight_end<=weight_ptr+16;state<=RESULT;end
   else state<=TAP;
  end
 endtask
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;busy_o<=0;done_o<=0;error_o<=0;outputs_o<=0;req_valid<=0;
   req_write<=0;req_addr<=0;req_data<=0;rsp_data<=0;req_strb<=0;input_cache_valid<=0;
   iw<=0;ih<=0;ic<=0;ow<=0;oh<=0;oc<=0;kernel<=0;stride<=0;dilation<=0;pad<=0;relu<=0;
   input_base<=0;weight_group<=0;param_group<=0;output_base<=0;ox<=0;oy<=0;ci<=0;
   group_channel<=0;rowbytes<=0;pixelbytes<=0;setup_count<=0;first_row<=0;first_col<=0;
   row_step<=0;krow<=0;col_offset<=0;sy<=0;sx<=0;row_y<=0;col_x<=0;pad_row<=0;pad_col<=0;col_step<=0;
   biases<=0;shifts<=0;param_word<=0;activation<=0;weights<=0;result<=0;write_lane<=0;
   write_addr<=0;write_data<=0;write_strb<=0;kx<=0;ky<=0;out_ptr<=0;weight_ptr<=0;weight_end<=0;
   input_cache_tag<=0;input_cache_data<=0;input_lane<=0;ret<=0;cache_ready<=0;term_index<=0;activation_cached<=0;clear_index<=0;lookahead_pending<=0;lookahead_valid<=0;lookahead_store<=0;
  end else begin
   lookahead_store<=0;
   if(lookahead_pending && req_valid && mem_ready_i)req_valid<=0;
   case(state)
   IDLE:if(start_i)begin
    busy_o<=1;done_o<=0;error_o<=0;outputs_o<=0;input_cache_valid<=0;cache_ready<=0;clear_index<=0;lookahead_pending<=0;lookahead_valid<=0;
    iw<=iw_i;ih<=ih_i;ic<=ic_i;ow<=ow_i;oh<=oh_i;oc<=oc_i;
    kernel<=kernel_i;stride<=stride_i;dilation<=dilation_i;pad<=pad_i;relu<=relu_i;
    input_base<=input_base_i;weight_group<=weight_base_i;param_group<=param_base_i;output_base<=output_base_i;
    group_channel<=0;param_word<=0;setup_count<=0;rowbytes<=0;pixelbytes<={16'd0,ic_i}<<1;
    first_row<=0;first_col<=0;row_step<=0;col_step<=0;
    if(iw_i==0 || ih_i==0 || ic_i==0 || ow_i==0 || oh_i==0 || oc_i==0 ||
       !(kernel_i==1 || kernel_i==3 || kernel_i==5) || !(stride_i==1 || stride_i==2) ||
       dilation_i==0 || input_base_i[3:0]!=0 || weight_base_i[3:0]!=0 || param_base_i[3:0]!=0 || output_base_i[3:0]!=0)begin error_o<=1;state<=FINISH;end
    else state<=SETUP_ROW;
   end
   SETUP_ROW:begin
     

    rowbytes<=({16'd0,iw}*{16'd0,ic})<<1;setup_count<=0;state<=SETUP_PAD;
   end
   SETUP_PAD:begin
    if(setup_count<pad)begin first_row<=first_row-$signed(rowbytes);first_col<=first_col-$signed(pixelbytes);end
    if(setup_count<dilation)begin row_step<=row_step+$signed(rowbytes);col_step<=col_step+$signed(pixelbytes);end
    setup_count<=setup_count+1;
    if(setup_count>=pad && setup_count>=dilation)begin pad_row<=first_row;pad_col<=first_col;state<=CLEAR_INPUT;end
   end
   CLEAR_INPUT:if(clear_index==511)state<=PARAM;else clear_index<=clear_index+1'b1;
   PARAM:read_beat(param_group+({29'd0,param_word}<<4),PARAM_GOT);
   PARAM_GOT:begin
    biases[param_word*128+:128]<=rsp_data;
    if(param_word==3)state<=SHIFT;else begin param_word<=param_word+1;state<=PARAM;end
   end
   SHIFT:read_beat(param_group+64,SHIFT_GOT);
   SHIFT_GOT:begin
    shifts<=rsp_data[63:0];ox<=0;oy<=0;out_ptr<=output_base+({16'd0,group_channel}<<1);
    row_y<=-$signed({14'd0,pad});col_x<=-$signed({14'd0,pad});state<=BEGIN_DOT;
   end
   BEGIN_DOT:if(mac_sr)begin
    ci<=0;kx<=0;ky<=0;sy<=row_y;sx<=col_x;krow<=first_row;col_offset<=first_col;
    weight_ptr<=weight_group;term_index<=0;state<=TAP;
   end
   TAP:begin
    if(padding_tap)begin activation<=0;activation_cached<=0;state<=WEIGHT;end
    else if(input_cache_valid && input_cache_tag=={input_addr[31:4],4'b0})begin
     activation<=cached_activation;activation_cached<=1;state<=WEIGHT;
    end else begin input_lane<=input_addr[3:1];state<=INPUT_PROBE;end
   end
   INPUT_PROBE:begin
    if(lookahead_pending)begin
      

     state<=INPUT_PROBE;
    end else if(lookahead_valid)begin
     lookahead_valid<=0;input_cache_valid<=1;input_cache_tag<=req_addr;input_cache_data<=rsp_data;
     activation<=rsp_data[input_lane*16+:16];activation_cached<=1;state<=WEIGHT;
    end else if(activation_tag_q[26] && activation_tag_q[25:0]==input_addr[31:6])begin
     input_cache_valid<=1;input_cache_tag<={input_addr[31:4],4'b0};input_cache_data<=activation_line_q;
     activation<=activation_line_q[input_lane*16+:16];activation_cached<=1;state<=WEIGHT;
    end else read_beat(input_addr,INPUT_GOT);
   end
   INPUT_GOT:begin
    input_cache_valid<=1;input_cache_tag<=req_addr;input_cache_data<=rsp_data;
    activation<=rsp_data[input_lane*16+:16];activation_cached<=1;state<=WEIGHT;
   end
   WEIGHT:begin
    if(cached_term)begin
     if(mac_tr)begin
      if(lookahead_enabled && activation_cached && input_addr[3:1]==1 && ci+7<ic && term_index+7<CACHE_WORDS &&
         prefetch_valid && !prefetched_next_hit && !lookahead_pending && !lookahead_valid)begin
       req_addr<={input_addr[31:4]+28'd1,4'b0};req_write<=0;req_valid<=1;lookahead_pending<=1;
      end
      advance_term;
       

      if(padding_tap && ci+1<ic && term_index+1<CACHE_WORDS)begin
        
       activation<=0;state<=WEIGHT;
      end else if(consecutive_cached_channel)begin activation<=cached_activation;state<=WEIGHT;end
      else if(activation_cached && ci+1<ic && input_addr[3:1]==7 && term_index+1<CACHE_WORDS && (prefetched_next_hit || lookahead_valid))begin
       input_cache_tag<={input_addr[31:4]+28'd1,4'b0};input_cache_data<=lookahead_valid ? rsp_data : activation_line_q;
       activation<=lookahead_valid ? rsp_data[15:0] : activation_line_q[15:0];state<=WEIGHT;
       if(lookahead_valid)lookahead_valid<=0;
      end
     end
    end
    else read_beat(weight_ptr,WEIGHT_GOT);
   end
   WEIGHT_CACHED:begin weights<=weight_cache_q;state<=TERM;end
   WEIGHT_GOT:begin weights<=rsp_data;state<=TERM;end
   TERM:if(mac_tr)advance_term;
   RESULT:if(mac_rv)begin
    result<={{(128-LANES*16){1'b0}},activated_result};write_lane<=0;write_data<=0;write_strb<=0;cache_ready<=1;
    write_addr<={out_ptr[31:4],4'b0};
    if(mac_overflow)begin error_o<=1;state<=FINISH;end
     

    else if(LANES==8 && out_ptr[3:0]==0 && group_channel+8<=oc)
     write_beat(out_ptr,activated_result,16'hffff,NEXT_PIXEL);
    else state<=WRITE_BUILD;
   end
   WRITE_BUILD:begin
    if(write_lane==LANES || group_channel+{12'd0,write_lane}>=oc)begin
     if(write_strb!=0)write_beat(write_addr,write_data,write_strb,NEXT_PIXEL);else state<=NEXT_PIXEL;
    end else if({lane_address[31:4],4'b0}!=write_addr)write_beat(write_addr,write_data,write_strb,WRITE_COMMIT);
    else begin
     write_data[out_lane*16+:16]<=result[write_lane*16+:16];write_strb[out_lane*2+:2]<=2'b11;write_lane<=write_lane+1;
    end
   end
   WRITE_COMMIT:begin write_addr<={lane_address[31:4],4'b0};write_data<=0;write_strb<=0;state<=WRITE_BUILD;end
   NEXT_PIXEL:begin
    outputs_o<=outputs_o+({16'd0,oc}-{16'd0,group_channel}<LANES ? {16'd0,oc}-{16'd0,group_channel} : LANES);
    out_ptr<=out_ptr+({16'd0,oc}<<1);
    if(!stripe_last_x)begin
     ox<=ox+1;col_x<=col_x+$signed({14'd0,stride});first_col<=first_col+$signed(stride==2 ? pixelbytes<<1 : pixelbytes);state<=BEGIN_DOT;
    end else if(oy+1<oh)begin
     ox<=striped ? stripe_x : 0;oy<=oy+1;row_y<=row_y+$signed({14'd0,stride});
     col_x<=striped ? stripe_col : -$signed({14'd0,pad});
     first_row<=first_row+$signed(stride==2 ? rowbytes<<1 : rowbytes);
     first_col<=striped ? $signed({{14{stripe_col[17]}},stripe_col})<<<6 : pad_col;
     if(striped)out_ptr<=out_ptr+rowbytes-({28'd0,ox[3:0]}<<6);
     state<=BEGIN_DOT;
    end else if(striped && next_stripe<{1'b0,ow})begin
     ox<=next_stripe[15:0];oy<=0;row_y<=-$signed({14'd0,pad});
     col_x<=next_stripe_col;
     first_row<=pad_row;first_col<=$signed({{14{next_stripe_col[17]}},next_stripe_col})<<<6;
     out_ptr<=output_base+({16'd0,group_channel}<<1)+{9'd0,next_stripe,6'd0};state<=BEGIN_DOT;
    end else state<=NEXT_GROUP;
   end
   NEXT_GROUP:begin
    if(group_channel+LANES<oc)begin
     group_channel<=group_channel+LANES;param_group<=param_group+80;param_word<=0;weight_group<=weight_end;cache_ready<=0;
     first_row<=pad_row;first_col<=pad_col;state<=PARAM;
    end else state<=FINISH;
   end
   WAIT_MEM:begin
    if(req_valid && mem_ready_i)req_valid<=0;
    if(mem_rsp_valid_i && !req_valid)begin
     rsp_data<=mem_rdata_i;
     if(mem_error_i)begin error_o<=1;state<=FINISH;end else state<=ret;
    end
   end
   FINISH:begin busy_o<=0;done_o<=1;state<=IDLE;end
   default:begin req_valid<=0;error_o<=1;state<=FINISH;end
  endcase
   if(lookahead_response)begin
    lookahead_pending<=0;rsp_data<=mem_rdata_i;
    if(mem_error_i)begin lookahead_valid<=0;error_o<=1;state<=FINISH;end
    else begin lookahead_valid<=1;lookahead_store<=1;end
   end
  end
 end
endmodule
