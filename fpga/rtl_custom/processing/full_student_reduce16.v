`timescale 1ns/1ps
 






module full_student_reduce16(
 input wire clk_i,rst_n_i,start_i,input wire [1023:0] command_i,
 output reg busy_o,done_o,error_o,output reg [31:0] outputs_o,clipped_o,
 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,
 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,
 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i
);
 localparam IDLE=0,SETUP=1,BEGIN_WIN=2,TAP=3,READ_GOT=4,ACC=5,NEXT_TAP=6,
  SCALE=7,DSTART=8,DWAIT=9,WRITE=10,NEXT=11,WAIT_MEM=12,FINISH=13;
 reg [3:0] state,ret;reg [1:0] op;reg replicate,include_pad;
 reg [15:0] iw,ih,ow,oh,oc,kw,kh,kc,stepx,stepy,padx,pady,x,y,ch,kx,ky,cc;
 reg [7:0] fi,fo;reg [31:0] base,origin,ix,iy,ic,group_step,lastrow,lastcol,setup;reg signed [31:0] padcol;
 reg signed [31:0] firstrow,firstcol,rowoffset,coloffset,rowadvance,coladvance;
 reg signed [17:0] startx,starty,px,py;
 reg [31:0] group_addr,outaddr,outpixel,outrow,oxs,oys,ocs;
 reg signed [63:0] sum,reduce_value,numerator;reg signed [15:0] extreme,sample;
 reg [63:0] denominator;reg [31:0] count;reg sample_valid;
 reg req_valid,req_write;reg [31:0] req_addr;reg [127:0] req_data,rsp_data;reg [15:0] req_strb;
 reg cache_valid;reg [31:0] cache_tag;reg [127:0] cache_data;reg [2:0] lane;
 reg [15:0] pixel;wire dr,dv,de;wire signed [63:0] dq;
 full_student_div64 divider(.clk_i(clk_i),.rst_n_i(rst_n_i && !(state==FINISH && error_o)),.valid_i(state==DSTART),.ready_o(dr),.numerator_i(numerator),.denominator_i(denominator),.valid_o(dv),.ready_i(state==DWAIT),.quotient_o(dq),.error_o(de));
 assign mem_valid_o=req_valid;assign mem_write_o=req_write;assign mem_addr_o=req_addr;assign mem_wdata_o=req_data;assign mem_wstrb_o=req_strb;
 wire inside_image=px>=0 && px<$signed({2'b0,iw}) && py>=0 && py<$signed({2'b0,ih});
 wire [31:0] realrow=py<0 ? 32'd0 : py>=$signed({2'b0,ih}) ? lastrow : rowoffset;
 wire [31:0] realcol=px<0 ? 32'd0 : px>=$signed({2'b0,iw}) ? lastcol : coloffset;
 wire [31:0] readaddr=group_addr+realrow+realcol;
 wire signed [63:0] extended_sample={{48{sample[15]}},sample};
 wire signed [63:0] sum_next=sum+extended_sample;
 wire [7:0] left_shift=fo>=fi ? fo-fi : 0;
 wire [7:0] right_shift=fi>fo ? fi-fo : 0;
 wire signed [63:0] shifted=reduce_value<<<left_shift;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;ret<=0;busy_o<=0;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;op<=0;replicate<=0;include_pad<=0;
   iw<=0;ih<=0;ow<=0;oh<=0;oc<=0;kw<=0;kh<=0;kc<=0;stepx<=0;stepy<=0;padx<=0;pady<=0;x<=0;y<=0;ch<=0;kx<=0;ky<=0;cc<=0;fi<=0;fo<=0;
   base<=0;origin<=0;padcol<=0;ix<=0;iy<=0;ic<=0;group_step<=0;lastrow<=0;lastcol<=0;setup<=0;firstrow<=0;firstcol<=0;rowoffset<=0;coloffset<=0;rowadvance<=0;coladvance<=0;
   startx<=0;starty<=0;px<=0;py<=0;group_addr<=0;outaddr<=0;outpixel<=0;outrow<=0;oxs<=0;oys<=0;ocs<=0;
   sum<=0;reduce_value<=0;numerator<=0;denominator<=0;extreme<=0;sample<=0;count<=0;sample_valid<=0;
   req_valid<=0;req_write<=0;req_addr<=0;req_data<=0;rsp_data<=0;req_strb<=0;cache_valid<=0;cache_tag<=0;cache_data<=0;lane<=0;pixel<=0;
  end else case(state)
   IDLE:if(start_i)begin
    busy_o<=1;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;cache_valid<=0;x<=0;y<=0;ch<=0;
    op<=command_i[1:0];replicate<=command_i[8];include_pad<=command_i[9];
    iw<=command_i[32+:16];ih<=command_i[48+:16];ow<=command_i[64+:16];oh<=command_i[80+:16];oc<=command_i[96+:16];
    kw<=command_i[128+:16];kh<=command_i[144+:16];kc<=command_i[160+:16];
    stepx<=command_i[192+:16];stepy<=command_i[208+:16];padx<=command_i[224+:16];pady<=command_i[240+:16];
    base<=command_i[256+:32];origin<=command_i[256+:32];ix<=command_i[288+:32];iy<=command_i[320+:32];ic<=command_i[352+:32];group_step<=command_i[384+:32];
    outaddr<=command_i[416+:32];outpixel<=command_i[416+:32];outrow<=command_i[416+:32];oxs<=command_i[448+:32];oys<=command_i[480+:32];ocs<=command_i[512+:32];
    fi<=command_i[544+:8];fo<=command_i[552+:8];setup<=0;firstrow<=0;firstcol<=0;lastrow<=0;lastcol<=0;rowadvance<=0;coladvance<=0;
    startx<=-$signed({2'b0,command_i[224+:16]});starty<=-$signed({2'b0,command_i[240+:16]});
    if(command_i[32+:16]==0 || command_i[48+:16]==0 || command_i[64+:16]==0 || command_i[80+:16]==0 || command_i[96+:16]==0 ||
       command_i[128+:16]==0 || command_i[144+:16]==0 || command_i[160+:16]==0 || command_i[544+:8]>24 || command_i[552+:8]>24 ||
       command_i[256] || command_i[288] || command_i[320] || command_i[352] || command_i[384] || command_i[416] || command_i[448] || command_i[480] || command_i[512])begin error_o<=1;state<=FINISH;end
    else state<=SETUP;
   end
   SETUP:begin
     
    if(setup<iw-1)lastcol<=lastcol+ix;if(setup<ih-1)lastrow<=lastrow+iy;
    if(setup<padx)firstcol<=firstcol-$signed(ix);if(setup<pady)firstrow<=firstrow-$signed(iy);
    if(setup<stepx)coladvance<=coladvance+$signed(ix);if(setup<stepy)rowadvance<=rowadvance+$signed(iy);
    setup<=setup+1;
    if(setup>=iw && setup>=ih && setup>=padx && setup>=pady && setup>=stepx && setup>=stepy)begin padcol<=firstcol;state<=BEGIN_WIN;end
   end
   BEGIN_WIN:begin
    kx<=0;ky<=0;cc<=0;count<=0;sum<=0;extreme<=op==3 ? 16'sh7fff : 16'sh8000;
    group_addr<=base;px<=startx;py<=starty;rowoffset<=firstrow;coloffset<=firstcol;state<=TAP;
   end
   TAP:begin
    if(!inside_image && !replicate)begin sample<=0;sample_valid<=0;state<=ACC;end
    else if(cache_valid && cache_tag=={readaddr[31:4],4'b0})begin sample<=cache_data[readaddr[3:1]*16+:16];sample_valid<=1;state<=ACC;end
    else begin req_valid<=1;req_write<=0;req_addr<={readaddr[31:4],4'b0};lane<=readaddr[3:1];ret<=READ_GOT;state<=WAIT_MEM;end
   end
   READ_GOT:begin cache_valid<=1;cache_tag<=req_addr;cache_data<=rsp_data;sample<=rsp_data[lane*16+:16];sample_valid<=1;state<=ACC;end
   ACC:begin
    if(sample_valid || include_pad)begin
     count<=count+1;if(count==32'hffffffff)begin error_o<=1;state<=FINISH;end else state<=NEXT_TAP;
    end else state<=NEXT_TAP;
    if(sample_valid)begin
     sum<=sum_next;
     if(op==2 && sample>extreme || op==3 && sample<extreme)extreme<=sample;
     if(sum[63]==extended_sample[63] && sum_next[63]!=sum[63])begin error_o<=1;state<=FINISH;end
    end
   end
   NEXT_TAP:begin
    if(cc+1<kc)begin cc<=cc+1;group_addr<=group_addr+ic;state<=TAP;end
    else if(kx+1<kw)begin cc<=0;kx<=kx+1;group_addr<=base;px<=px+1;coloffset<=coloffset+$signed(ix);state<=TAP;end
    else if(ky+1<kh)begin cc<=0;kx<=0;ky<=ky+1;group_addr<=base;px<=startx;py<=py+1;coloffset<=firstcol;rowoffset<=rowoffset+$signed(iy);state<=TAP;end
    else begin reduce_value<=op[1] ? {{48{extreme[15]}},extreme} : sum;state<=SCALE;end
   end
   SCALE:begin
    numerator<=shifted;denominator<=(op==1 ? {32'd0,count} : 64'd1)<<right_shift;
    if((op==1 && count==0) || ((shifted>>>left_shift)!=reduce_value))begin error_o<=1;state<=FINISH;end else state<=DSTART;
   end
   DSTART:if(dr)state<=DWAIT;
   DWAIT:if(dv)begin
    if(de)begin error_o<=1;state<=FINISH;end else begin
     if(dq>32767)begin pixel<=16'h7fff;clipped_o<=clipped_o+1;end
     else if(dq< -32768)begin pixel<=16'h8000;clipped_o<=clipped_o+1;end else pixel<=dq[15:0];
     state<=WRITE;
    end
   end
   WRITE:begin req_valid<=1;req_write<=1;req_addr<={outaddr[31:4],4'b0};req_data<=({112'd0,pixel}<<(outaddr[3:1]*16));req_strb<=16'd3<<(outaddr[3:1]*2);ret<=NEXT;state<=WAIT_MEM;end
   NEXT:begin
    outputs_o<=outputs_o+1;
    if(ch+1<oc)begin ch<=ch+1;base<=base+group_step;outaddr<=outaddr+ocs;state<=BEGIN_WIN;end
    else begin
     ch<=0;base<=origin;
     if(x+1<ow)begin x<=x+1;outpixel<=outpixel+oxs;outaddr<=outpixel+oxs;firstcol<=firstcol+coladvance;startx<=startx+$signed({2'b0,stepx});state<=BEGIN_WIN;end
     else if(y+1<oh)begin x<=0;y<=y+1;outrow<=outrow+oys;outpixel<=outrow+oys;outaddr<=outrow+oys;firstrow<=firstrow+rowadvance;starty<=starty+$signed({2'b0,stepy});firstcol<=padcol;startx<=-$signed({2'b0,padx});state<=BEGIN_WIN;end
     else state<=FINISH;
    end
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
