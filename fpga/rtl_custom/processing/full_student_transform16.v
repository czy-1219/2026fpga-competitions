`timescale 1ns/1ps
 










module full_student_transform16(
 input wire clk_i,rst_n_i,start_i,input wire [1023:0] command_i,
 output reg busy_o,done_o,error_o,output reg [31:0] outputs_o,clipped_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,MAP=1,CORNER=2,ADDRESS=3,READ=4,READ_GOT=5,ACC=6,QUANT=7,WRITE=8,NEXT=9,WAIT_MEM=10,FINISH=11,ROUND_SHIFT=12,PACK=13,DRAIN=14;
 // R3b: conservative disjoint positive-stride HWC copy only.
 // The existing 16x16 address multiplier is reused for range qualification.
 localparam COPY_CHECK=15,COPY_CHECK_GOT=16;
 reg regular_copy,regular_seeded;
 reg [2:0] copy_check;
 reg [15:0] copy_row_step;
 reg [32:0] copy_source_end;
 wire [15:0] check_position=copy_check==0 ? iw : copy_check==1 ? ow : copy_check==2 ? ih : oh;
 wire [15:0] check_stride=copy_check==0 ? ix[15:0] : copy_check==1 ? oxs[15:0] : copy_check==2 ? iy[15:0] : oys[15:0];
 reg add_mode,clip_mode,pool_mode;reg [31:0] base_b;
 reg subtract_mode,multiply_mode,round_phase;
 reg [31:0] second_ix,second_iy,second_ic;
 reg [31:0] third_ix,third_iy,third_ic,base_c;reg [3:0] vector_mode;reg condition;
 reg [2:0] constant_operands;
 reg signed [17:0] first_constant,second_constant;reg signed [15:0] third_constant,first_sample;
 reg [4:0] state,ret;reg [2:0] op;reg down,replicate;reg [2:0] scale;
 reg [15:0] iw,ih,ow,oh,oc,x,y,ch;reg [7:0] fi,fo;
 reg [31:0] base,ix,iy,ic,outaddr,outrow,outpixel,oxs,oys,ocs;reg signed [31:0] padx,pady;
 reg signed [31:0] srcx,srcy;reg [31:0] srcc;reg [6:0] fx,fy,den;reg [2:0] den_shift;
 reg [1:0] corner;reg [12:0] weight;reg signed [35:0] sum;reg signed [15:0] sample;
 reg [35:0] magnitude;reg [3:0] remaining;reg negative,guard_bit,sticky_bit;
 reg [15:0] mx,my,mc;reg [31:0] readaddr,address_product;reg [1:0] address_bit;
 wire [15:0] address_position=address_bit==0 ? mx : address_bit==1 ? my : mc;
 wire [15:0] address_stride_raw=third_operand ? (address_bit==0 ? third_ix[15:0] : address_bit==1 ? third_iy[15:0] : third_ic[15:0]) : second_operand ? (address_bit==0 ? second_ix[15:0] : address_bit==1 ? second_iy[15:0] : second_ic[15:0]) : (address_bit==0 ? ix[15:0] : address_bit==1 ? iy[15:0] : ic[15:0]);
 wire address_negative=third_operand ? (address_bit==0 ? third_ix[31] : address_bit==1 ? third_iy[31] : third_ic[31]) : second_operand ? (address_bit==0 ? second_ix[31] : address_bit==1 ? second_iy[31] : second_ic[31]) : (address_bit==0 ? ix[31] : address_bit==1 ? iy[31] : ic[31]);
 wire [15:0] address_stride=address_negative ? -address_stride_raw : address_stride_raw;
 wire [15:0] multiplier_position=state==COPY_CHECK ? check_position : address_position;
 wire [15:0] multiplier_stride=state==COPY_CHECK ? check_stride : address_stride;
 wire [31:0] address_multiply=multiplier_position*multiplier_stride;
 function stride_fits;input [31:0] a;begin stride_fits=(a[31:16]==0)||(a[31:15]==17'h1ffff);end endfunction
 wire signed [17:0] multiply_first=constant_operands[0] ? first_constant : {{2{first_sample[15]}},first_sample};
 wire signed [17:0] multiply_second=constant_operands[1] ? second_constant : {{2{sample[15]}},sample};
 wire signed [31:0] compare_first=constant_operands[0] ? padx : {{12{first_sample[15]}},first_sample,4'b0};
 wire signed [31:0] compare_second=constant_operands[1] ? pady : {{12{sample[15]}},sample,4'b0};
 reg cache_valid;reg [2:0] lane;
  

 reg second_valid;
  


 reg third_valid,fourth_valid;
 wire third_operand=vector_mode==13 && corner==2;
 wire second_operand=add_mode && corner==1;
 wire [1:0] read_cache=(op==1 || vector_mode==13) ? corner : {1'b0,second_operand};
 wire line_valid=read_cache==0 ? cache_valid : read_cache==1 ? second_valid : read_cache==2 ? third_valid : fourth_valid;
 wire [31:0] line_tag={tap_cache_q[155:128],4'b0};
  


 (* syn_ramstyle="block_ram" *) reg [155:0] tap_cache[0:3];
 reg [155:0] tap_cache_q;
 always @(posedge clk_i)begin
  if(state==READ_GOT)tap_cache[read_cache]<={req_addr[31:4],rsp_data};
  if(state==CORNER)tap_cache_q<=tap_cache[read_cache];
 end
 wire [15:0] line_sample=tap_cache_q[readaddr[3:1]*16+:16];
  


 reg [31:0] corner_address[0:3];
 always @(posedge clk_i)if(state==READ && op==1)corner_address[corner]<=readaddr;
  

 reg [31:0] packed_address;reg [127:0] packed_data;reg [15:0] packed_strobes;
 reg req_valid,req_write;reg [31:0] req_addr;reg [127:0] req_data,rsp_data;reg [15:0] req_strb;reg [15:0] pixel;
 assign mem_valid_o=req_valid;assign mem_write_o=req_write;assign mem_addr_o=req_addr;assign mem_wdata_o=req_data;assign mem_wstrb_o=req_strb;
 wire signed [31:0] tx=$signed({16'd0,x}<<1)+1-$signed(32'd1<<scale);
 wire signed [31:0] ty=$signed({16'd0,y}<<1)+1-$signed(32'd1<<scale);
 wire signed [31:0] cx=srcx+$signed(pool_mode ? {25'd0,fx} : {31'd0,(op==1 && corner[0])});
 wire signed [31:0] cy=srcy+$signed(pool_mode ? {25'd0,fy} : {31'd0,(op==1 && corner[1])});
 wire inside_image=cx>=0 && cy>=0 && cx<$signed({16'd0,iw}) && cy<$signed({16'd0,ih});
 wire [6:0] wx=corner[0] ? fx : den-fx,wy=corner[1] ? fy : den-fy;
 wire [13:0] weight_xy=wx*wy;
 wire signed [29:0] product=sample*$signed({1'b0,weight});
 wire signed [31:0] weighted={{2{product[29]}},product};
  

 wire [35:0] rounded=magnitude+{35'd0,(guard_bit && (sticky_bit || magnitude[0]))};
 wire quant_clip=negative ? rounded>32768 : rounded>32767;
 wire [15:0] packed_pixel=quant_clip ? (negative ? 16'h8000 : 16'h7fff) : negative ? (~rounded[15:0]+16'd1) : rounded[15:0];
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;ret<=0;regular_copy<=0;regular_seeded<=0;copy_check<=0;copy_row_step<=0;copy_source_end<=0;add_mode<=0;clip_mode<=0;pool_mode<=0;base_b<=0;op<=0;down<=0;replicate<=0;scale<=0;busy_o<=0;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;
   iw<=0;ih<=0;ow<=0;oh<=0;oc<=0;x<=0;y<=0;ch<=0;fi<=0;fo<=0;base<=0;ix<=0;iy<=0;ic<=0;outaddr<=0;outrow<=0;outpixel<=0;oxs<=0;oys<=0;ocs<=0;padx<=0;pady<=0;
   srcx<=0;srcy<=0;srcc<=0;fx<=0;fy<=0;den<=0;den_shift<=0;corner<=0;weight<=0;sum<=0;sample<=0;magnitude<=0;remaining<=0;negative<=0;guard_bit<=0;sticky_bit<=0;
   mx<=0;my<=0;mc<=0;readaddr<=0;address_product<=0;address_bit<=0;cache_valid<=0;lane<=0;
   req_valid<=0;req_write<=0;req_addr<=0;req_data<=0;rsp_data<=0;req_strb<=0;pixel<=0;
   second_valid<=0;packed_address<=0;packed_data<=0;packed_strobes<=0;
   third_valid<=0;fourth_valid<=0;
   vector_mode<=0;condition<=0;third_ix<=0;third_iy<=0;third_ic<=0;base_c<=0;third_constant<=0;
   subtract_mode<=0;multiply_mode<=0;round_phase<=0;second_ix<=0;second_iy<=0;second_ic<=0;constant_operands<=0;first_constant<=0;second_constant<=0;first_sample<=0;
  end else case(state)
   IDLE:if(start_i)begin
    regular_copy<=0;regular_seeded<=0;copy_check<=0;busy_o<=1;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;cache_valid<=0;second_valid<=0;third_valid<=0;fourth_valid<=0;packed_strobes<=0;x<=0;y<=0;ch<=0;
    pool_mode<=command_i[3:0]==6;add_mode<=command_i[3:0]==4 || command_i[3:0]>=7;vector_mode<=command_i[3:0];clip_mode<=command_i[3:0]==5;base_b<=command_i[480+:32];
    subtract_mode<=command_i[3:0]==7;multiply_mode<=command_i[3:0]==8 || command_i[3:0]==14;
    second_ix<=command_i[3:0]>=7 ? command_i[512+:32] : command_i[160+:32];
    second_iy<=command_i[3:0]>=7 ? command_i[544+:32] : command_i[192+:32];
    second_ic<=command_i[3:0]>=7 ? command_i[576+:32] : command_i[224+:32];
    constant_operands<=command_i[3:0]>=7 ? command_i[608+:3] : 3'b0;
    first_constant<=command_i[3:0]==14 ? command_i[640+:18] : {{2{command_i[655]}},command_i[640+:16]};
    second_constant<=command_i[3:0]==14 ? command_i[672+:18] : {{2{command_i[671]}},command_i[656+:16]};
    third_constant<=command_i[704+:16];base_c<=command_i[736+:32];third_ix<=command_i[768+:32];third_iy<=command_i[800+:32];third_ic<=command_i[832+:32];
    op<=command_i[3:0]>=4 ? 3'd0 : command_i[2:0];down<=command_i[8];replicate<=command_i[9];scale<=command_i[16+:3];

    iw<=command_i[32+:16];ih<=command_i[48+:16];ow<=command_i[64+:16];oh<=command_i[80+:16];oc<=command_i[96+:16];

    base<=command_i[128+:32];ix<=command_i[160+:32];iy<=command_i[192+:32];ic<=command_i[224+:32];

    outaddr<=command_i[256+:32];outpixel<=command_i[256+:32];outrow<=command_i[256+:32];oxs<=command_i[288+:32];oys<=command_i[320+:32];ocs<=command_i[352+:32];

    fi<=command_i[384+:8];fo<=command_i[392+:8];padx<=command_i[416+:32];pady<=command_i[448+:32];

    if(command_i[32+:16]==0 || command_i[48+:16]==0 || command_i[64+:16]==0 || command_i[80+:16]==0 || command_i[96+:16]==0 ||

       command_i[384+:8]!=command_i[392+:8] || !stride_fits(command_i[160+:32]) || !stride_fits(command_i[192+:32]) || !stride_fits(command_i[224+:32]) || ((command_i[3:0]==1 || command_i[3:0]==6) && (command_i[16+:3]<1 || command_i[16+:3]>5)) ||

       command_i[128] || command_i[160] || command_i[192] || command_i[224] || command_i[256] || command_i[288] || command_i[320] || command_i[352] ||
       (command_i[3:0]>=7 && (command_i[384+:16]!=16'h0c0c || (|command_i[528+:16]) || (|command_i[560+:16]) || (|command_i[592+:16]) || command_i[512] || command_i[544] || command_i[576])))begin error_o<=1;state<=FINISH;end else state<=COPY_CHECK;

   end

   COPY_CHECK:begin
    // Reject mirror/replicate, interpolation, broadcast/planar/negative strides,
    // row aliasing and non-contained crop before enabling recurrence.
    if(vector_mode!=0 || down || replicate || scale!=0 || ic!=2 || ocs!=2 ||
       ix!={15'd0,oc,1'b0} || oxs!=ix || ix[31:16]!=0 ||
       iy[31:16]!=0 || oys[31:16]!=0 ||
       padx!=0 || pady!=0 || ow!=iw || oh!=ih)state<=MAP;
    else begin address_product<=address_multiply;state<=COPY_CHECK_GOT;end
   end
   COPY_CHECK_GOT:begin
    if((copy_check==0 && address_product>iy) || (copy_check==1 && address_product>oys))state<=MAP;
    else if(copy_check==3)begin
     // Conservative whole-layout envelopes; 33 bits forbid wraparound.
     regular_copy<=!copy_source_end[32] && ({1'b0,outaddr}+{1'b0,address_product}<33'h100000000) &&
       (copy_source_end<={1'b0,outaddr} || {1'b0,outaddr}+{1'b0,address_product}<={1'b0,base});
     state<=MAP;
    end else begin
     if(copy_check==1)copy_row_step<=iy[15:0]-address_product[15:0]+16'd2;
     if(copy_check==2)copy_source_end<={1'b0,base}+{1'b0,address_product};
     copy_check<=copy_check+1'b1;state<=COPY_CHECK;
    end
   end
   MAP:begin
    sum<=0;corner<=0;srcc<={16'd0,ch};den<=1;den_shift<=0;fx<=0;fy<=0;
    case(op)
     0:begin srcx<=pool_mode ? $signed({16'd0,x}<<scale) : $signed({16'd0,x})-(vector_mode>=10 ? 32'sd0 : padx);srcy<=pool_mode ? $signed({16'd0,y}<<scale) : $signed({16'd0,y})-(vector_mode>=10 ? 32'sd0 : pady);end
     1:if(down)begin
      srcx<=$signed({16'd0,x}<<scale)+$signed(32'd1<<(scale-1))-1;srcy<=$signed({16'd0,y}<<scale)+$signed(32'd1<<(scale-1))-1;fx<=1;fy<=1;den<=2;den_shift<=1;
     end else begin srcx<=tx>>>(scale+1);srcy<=ty>>>(scale+1);fx<=tx[6:0]&((7'd1<<(scale+1))-1);fy<=ty[6:0]&((7'd1<<(scale+1))-1);den<=7'd1<<(scale+1);den_shift<=scale+1;end
     2:begin srcx<=$signed({17'd0,x[15:1]});srcy<=$signed({17'd0,y[15:1]});srcc<={14'd0,ch,y[0],x[0]};end
     3:begin srcx<=$signed({15'd0,x,ch[0]});srcy<=$signed({15'd0,y,ch[1]});srcc<={18'd0,ch[15:2]};end
    endcase
    state<=CORNER;
   end
   CORNER:begin
    weight<=op==1 ? weight_xy : 7'd1;
    if(constant_operands[third_operand ? 2 : second_operand ? 1 : 0])begin sample<=third_operand ? third_constant : second_operand ? second_constant[15:0] : first_constant[15:0];state<=ACC;end
    else if(!inside_image && op==0 && !replicate)begin sample<=0;state<=ACC;end
    else if(!inside_image && op>=2)begin error_o<=1;state<=FINISH;end
    else if(regular_copy && regular_seeded)begin state<=READ;end
    else if(op==1 && ch!=0)begin readaddr<=corner_address[corner]+ic;state<=READ;end
    else begin
     mx<=cx<0 ? 32'd0 : cx>=$signed({16'd0,iw}) ? {16'd0,iw}-1 : cx;
     my<=cy<0 ? 32'd0 : cy>=$signed({16'd0,ih}) ? {16'd0,ih}-1 : cy;
     mc<=srcc[15:0];readaddr<=third_operand ? base_c : second_operand ? base_b : base;address_bit<=0;state<=ADDRESS;
    end
   end
   ADDRESS:begin
    address_product<=address_negative ? -address_multiply : address_multiply;
    if(address_bit!=0)readaddr<=readaddr+address_product;
    if(address_bit==3)state<=READ;else address_bit<=address_bit+1'b1;
   end
   READ:begin
    if(regular_copy && !regular_seeded)begin
     regular_seeded<=1;
    end
    if(line_valid && line_tag=={readaddr[31:4],4'b0})begin sample<=line_sample;state<=ACC;end
    else begin req_valid<=1;req_write<=0;req_addr<={readaddr[31:4],4'b0};lane<=readaddr[3:1];ret<=READ_GOT;state<=WAIT_MEM;end
   end
   READ_GOT:begin
    case(read_cache)
     0:begin cache_valid<=1;end
     1:begin second_valid<=1;end
     2:begin third_valid<=1;end
     3:begin fourth_valid<=1;end
    endcase
    sample<=rsp_data[lane*16+:16];state<=ACC;
   end
   ACC:begin
    if(vector_mode>=10 && vector_mode<=13)begin
     if(corner==0)begin first_sample<=sample;condition<=sample!=0;sum<=0;end
     else if(vector_mode==10)sum<=$signed(first_sample)<$signed(sample) ? $signed(first_sample) : $signed(sample);
     else if(vector_mode==11)sum<=compare_first>compare_second ? 36'sd4096 : 36'sd0;
     else if(vector_mode==12)sum<=compare_first>=compare_second ? 36'sd4096 : 36'sd0;
     else if(corner==1)first_sample<=sample;
     else sum<=condition ? $signed(first_sample) : $signed(sample);
    end else if(vector_mode==15)begin
     if(corner==0)begin first_sample<=sample;sum<=0;end
     else sum<=$signed({{4{compare_first[31]}},compare_first})-$signed({{4{compare_second[31]}},compare_second});
    end else if(multiply_mode)begin
     if(corner==0)begin first_sample<=sample;sum<=0;end
     else sum<=multiply_first*multiply_second;
    end else sum<=sum+((subtract_mode && corner!=0) ? -weighted : weighted);
    if(pool_mode && fx<((7'd1<<scale)-1'b1))begin fx<=fx+1'b1;state<=CORNER;end
    else if(pool_mode && fy<((7'd1<<scale)-1'b1))begin fx<=0;fy<=fy+1'b1;state<=CORNER;end
    else if((op==1 && corner<3) || (add_mode && corner<(vector_mode==13 ? 2 : 1)))begin corner<=corner+1;state<=CORNER;end else state<=QUANT;
   end
   QUANT:begin magnitude<=sum<0 ? -sum : sum;negative<=sum<0;guard_bit<=0;sticky_bit<=0;round_phase<=0;remaining<=multiply_mode ? 4'd8 : vector_mode==15 ? 4'd4 : pool_mode ? {scale,1'b0} : op==1 ? {den_shift,1'b0} : 4'd0;state<=ROUND_SHIFT;end
   ROUND_SHIFT:if(remaining>=8)begin sticky_bit<=sticky_bit||guard_bit||(|magnitude[6:0]);guard_bit<=magnitude[7];magnitude<=magnitude>>8;remaining<=remaining-8;end
   else if(remaining>=4)begin sticky_bit<=sticky_bit||guard_bit||(|magnitude[2:0]);guard_bit<=magnitude[3];magnitude<=magnitude>>4;remaining<=remaining-4;end
   else if(remaining>=2)begin sticky_bit<=sticky_bit||guard_bit||magnitude[0];guard_bit<=magnitude[1];magnitude<=magnitude>>2;remaining<=remaining-2;end
   else if(remaining!=0)begin sticky_bit<=sticky_bit||guard_bit;guard_bit<=magnitude[0];magnitude<=magnitude>>1;remaining<=remaining-1'b1;end
   else if(multiply_mode && !round_phase)begin magnitude<=rounded;guard_bit<=0;sticky_bit<=0;remaining<=4'd4;round_phase<=1;end
   else state<=PACK;
   PACK:begin pixel<=clip_mode && $signed(packed_pixel)<$signed(base_b[15:0]) ? base_b[15:0] : clip_mode && $signed(packed_pixel)>$signed(base_b[31:16]) ? base_b[31:16] : packed_pixel;if(quant_clip)clipped_o<=clipped_o+1;state<=WRITE;end
   WRITE:begin
    if(packed_strobes!=0 && packed_address!={outaddr[31:4],4'b0})begin
     req_valid<=1;req_write<=1;req_addr<=packed_address;req_data<=packed_data;req_strb<=packed_strobes;
     packed_strobes<=0;ret<=WRITE;state<=WAIT_MEM;
    end else begin
     packed_address<={outaddr[31:4],4'b0};packed_data[outaddr[3:1]*16+:16]<=pixel;
     packed_strobes[outaddr[3:1]*2+:2]<=2'b11;state<=NEXT;
    end
   end
   NEXT:begin
    outputs_o<=outputs_o+1;
    if(regular_copy)begin
     // Packed channels/pixels are contiguous; only the row boundary needs a correction.
     readaddr<=readaddr+((ch+1>=oc && x+1>=ow) ? {16'd0,copy_row_step} : 32'd2);
    end
    if(ch+1<oc)begin ch<=ch+1;outaddr<=outaddr+ocs;state<=MAP;end
    else if(x+1<ow)begin ch<=0;x<=x+1;outpixel<=outpixel+oxs;outaddr<=outpixel+oxs;state<=MAP;end
    else if(y+1<oh)begin ch<=0;x<=0;y<=y+1;outrow<=outrow+oys;outpixel<=outrow+oys;outaddr<=outrow+oys;state<=MAP;end
    else state<=DRAIN;
   end
   DRAIN:begin
    if(packed_strobes!=0)begin
     req_valid<=1;req_write<=1;req_addr<=packed_address;req_data<=packed_data;req_strb<=packed_strobes;
     packed_strobes<=0;ret<=FINISH;state<=WAIT_MEM;
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
