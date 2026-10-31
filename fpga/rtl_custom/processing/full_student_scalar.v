`timescale 1ns/1ps
 









module full_student_scalar #(
 parameter EXP_ROM="variants/full_student_20261018/exp_neg_q20.mem"
)(
 input wire clk_i,rst_n_i,valid_i,output wire ready_o,
 input wire [4:0] op_i,input wire signed [31:0] a_i,b_i,c_i,
 output reg valid_o,input wire ready_i,output reg signed [31:0] value_o,
 output reg error_o,saturated_o
);
 localparam IDLE=0,DISPATCH=1,MSTART=2,MWAIT=3,EXP_READ=4,EXP_GOT=5,
  EXP_MUL=6,EXP_WAIT=7,EXP_FINISH=8,DSTART=9,DIVIDE=10,DEND=11,SILU_MUL=12,FINISH=13;
 reg [3:0] state;reg [4:0] op;reg signed [31:0] a,b,c;
 reg signed [63:0] result;
 reg [31:0] exp_x;reg [20:0] exp_value,exp_start;
 reg [11:0] exp_fraction;reg [15:0] exp_delta;
 (* syn_ramstyle="block_ram" *) reg [36:0] exp_rom[0:255];reg [36:0] exp_q;
 initial $readmemh(EXP_ROM,exp_rom);
 always @(posedge clk_i)if(state==EXP_READ)exp_q<=exp_rom[exp_x[19:12]];
 reg signed [31:0] ma,mb;
 wire mr,mv;wire signed [63:0] mp;
 wire mstart=state==MSTART || state==EXP_MUL || state==SILU_MUL;
 full_student_mul32 mult(.clk_i(clk_i),.rst_n_i(rst_n_i),.valid_i(mstart),.ready_o(mr),.a_i(ma),.b_i(mb),.valid_o(mv),.ready_i(state==MWAIT || state==EXP_WAIT),.product_o(mp));
 reg [63:0] dividend,quotient;reg [64:0] remainder;
 reg [31:0] divisor;reg [5:0] div_count;reg div_negative;
 wire [64:0] trial={remainder[63:0],dividend[63]};
 wire qbit=trial>={33'd0,divisor};
 wire [64:0] rem_next=qbit ? trial-{33'd0,divisor} : trial;
 wire [64:0] twice_rem=remainder<<1;
 wire round_div=twice_rem>{33'd0,divisor} || (twice_rem=={33'd0,divisor} && quotient[0]);
 wire [63:0] rounded_div=quotient+{63'd0,round_div};
 wire signed [63:0] signed_div=div_negative ? -$signed(rounded_div) : $signed(rounded_div);
 wire [31:0] abs_a=a[31] ? -a : a;
 function signed [63:0] round16;
  input signed [63:0] v;reg [63:0] mag,q;reg inc;
  begin
   mag=v[63] ? -v : v;q=mag>>16;
   inc=mag[15:0]>16'h8000 || (mag[15:0]==16'h8000 && q[0]);q=q+{63'd0,inc};
   round16=v[63] ? -$signed(q) : $signed(q);
  end
 endfunction
 assign ready_o=state==IDLE && !valid_o;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;op<=0;a<=0;b<=0;c<=0;result<=0;valid_o<=0;value_o<=0;error_o<=0;saturated_o<=0;
   exp_x<=0;exp_value<=0;exp_start<=0;exp_fraction<=0;exp_delta<=0;ma<=0;mb<=0;
   dividend<=0;quotient<=0;remainder<=0;divisor<=0;div_count<=0;div_negative<=0;
  end else begin
   if(valid_o && ready_i)valid_o<=0;
   case(state)
    IDLE:if(valid_i && ready_o)begin op<=op_i;a<=a_i;b<=b_i;c<=c_i;error_o<=0;saturated_o<=0;state<=DISPATCH;end
    DISPATCH:case(op)
     0:begin result<=$signed({{32{a[31]}},a})+$signed({{32{b[31]}},b});state<=FINISH;end
     1:begin result<=$signed({{32{a[31]}},a})-$signed({{32{b[31]}},b});state<=FINISH;end
     2:begin ma<=a;mb<=b;state<=MSTART;end
     3:begin
      dividend<={16'd0,abs_a,16'd0};divisor<=b[31] ? -b : b;div_negative<=a[31]^b[31];state<=DSTART;
     end
     4:begin result<=a<b ? a : b;state<=FINISH;end
     5:begin result<=a>b ? a : b;state<=FINISH;end
     6:begin result<={32'd0,abs_a};state<=FINISH;end
     7:begin result<=-$signed({{32{a[31]}},a});state<=FINISH;end
     8:begin result<=a<b ? b : a>c ? c : a;error_o<=b>c;state<=FINISH;end
     9,10,11,12:begin
      if(op==12)exp_x<=a>=0 ? 32'd0 : abs_a;
      else if(op==10)exp_x<=abs_a>=32'd524288 ? 32'd1048576 : abs_a<<1;
      else exp_x<=abs_a;
      state<=EXP_READ;
     end
     13:begin result<=a>b ? 64'd65536 : 64'd0;state<=FINISH;end
     14:begin result<=a>=b ? 64'd65536 : 64'd0;state<=FINISH;end
     15:begin result<=a>=0 ? b : c;state<=FINISH;end
     16:begin result<=$signed({a[31:16],16'd0});state<=FINISH;end
     17:begin result<=round16($signed({{32{a[31]}},a}))<<<16;state<=FINISH;end
     18:begin result<=a!=0 ? b : c;state<=FINISH;end
     19:begin
      if(a<=0)begin result<=0;state<=FINISH;end
      else if(b<=0 || a>=b)begin result<=65536;state<=FINISH;end
      else begin dividend<={16'd0,abs_a,16'd0};divisor<=b;div_negative<=0;state<=DSTART;end
     end
     20,21:begin
      if(b<0 || b>32'sd2031616 || b[15:0]!=0)begin result<=0;error_o<=1;end
      else if(op==20)result<=($signed({{48{a[31]}},a[31:16]})>>>b[20:16])<<<16;
      else result<=$signed({{48{a[31]}},a[31:16]})<<<(b[20:16]+7'd16);
      state<=FINISH;
     end
     22:begin result<=$signed({{48{a[31]|b[31]}},(a[31:16]|b[31:16])})<<<16;state<=FINISH;end
     default:begin error_o<=1;result<=0;state<=FINISH;end
    endcase
    MSTART:if(mr)state<=MWAIT;
    MWAIT:if(mv)begin result<=round16(mp);state<=FINISH;end
    EXP_READ:begin
     if(exp_x>=32'd1048576)begin exp_value<=0;state<=EXP_FINISH;end else state<=EXP_GOT;
    end
    EXP_GOT:begin
     exp_start<=exp_q[36:16];exp_delta<=exp_q[15:0];exp_fraction<=exp_x[11:0];
     ma<={16'd0,exp_q[15:0]};mb<={20'd0,exp_x[11:0]};state<=EXP_MUL;
    end
    EXP_MUL:if(mr)state<=EXP_WAIT;
    EXP_WAIT:if(mv)begin exp_value<=exp_start-((mp+64'd2048)>>12);state<=EXP_FINISH;end
    EXP_FINISH:begin
     if(op==12)begin result<=round16($signed({27'd0,exp_value,16'd0})>>>4);state<=FINISH;end
     else begin
      divisor<=32'd1048576+{11'd0,exp_value};div_negative<=op==10 && a[31];
      if(op==10)dividend<=({43'd0,21'd1048576-exp_value}<<16);
      else if(a[31])dividend<=({43'd0,exp_value}<<16);
      else dividend<=64'd68719476736;
      state<=DSTART;
     end
    end
    DSTART:begin
     quotient<=0;remainder<=0;div_count<=0;
     if(divisor==0)begin result<=0;error_o<=1;state<=FINISH;end else state<=DIVIDE;
    end
    DIVIDE:begin
     remainder<=rem_next;dividend<=dividend<<1;quotient<={quotient[62:0],qbit};div_count<=div_count+1;
     if(div_count==63)state<=DEND;
    end
    DEND:begin
     if(op==11)begin ma<=a;mb<=signed_div[31:0];state<=SILU_MUL;end
     else begin result<=signed_div;state<=FINISH;end
    end
    SILU_MUL:if(mr)state<=MWAIT;
    FINISH:begin
     if(result>64'sd2147483647)begin value_o<=32'sh7fffffff;saturated_o<=1;end
     else if(result< -64'sd2147483648)begin value_o<=32'sh80000000;saturated_o<=1;end
     else value_o<=result[31:0];
     valid_o<=1;state<=IDLE;
    end
    default:begin error_o<=1;result<=0;state<=FINISH;end
   endcase
  end
 end
endmodule
