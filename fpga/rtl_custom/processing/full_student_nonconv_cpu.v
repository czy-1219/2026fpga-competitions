`timescale 1ns/1ps

 







module full_student_nonconv_cpu #(

 parameter FIRMWARE="variants/full_student_20261018/firmware/nonconv.mem"

)(

 input wire clk_i,rst_n_i,start_i,input wire [1023:0] command_i,

 output reg busy_o,done_o,error_o,output reg [31:0] outputs_o,clipped_o,

 output wire mem_valid_o,input wire mem_ready_i,output wire mem_write_o,

 output wire [31:0] mem_addr_o,output wire [127:0] mem_wdata_o,output wire [15:0] mem_wstrb_o,

 input wire mem_rsp_valid_i,mem_error_i,input wire [127:0] mem_rdata_i

);

 wire cv,trap;wire la_read,la_write;wire [31:0] la_addr;wire [31:0] ca,cwd;wire [3:0] cs;reg cr;reg [31:0] cd;

 wire pcv,pcwr,pcwait,pcready;wire [31:0] pci,pca,pcb,pcr;

 wire cpu_reset=rst_n_i && busy_o;

  



 picorv32_pcpi_fast_mul #(.EXTRA_MUL_FFS(1),.EXTRA_INSN_FFS(0)) integer_mul(

  .clk(clk_i),.resetn(cpu_reset),.pcpi_valid(pcv),.pcpi_insn(pci),.pcpi_rs1(pca),.pcpi_rs2(pcb),

  .pcpi_wr(pcwr),.pcpi_rd(pcr),.pcpi_wait(pcwait),.pcpi_ready(pcready));

 picorv32 #(.ENABLE_COUNTERS(0),.ENABLE_COUNTERS64(0),.ENABLE_PCPI(1),.ENABLE_MUL(0),.ENABLE_DIV(1),

   
  .BARREL_SHIFTER(1),.TWO_STAGE_SHIFT(0),.ENABLE_IRQ(0),.COMPRESSED_ISA(0),.PROGADDR_RESET(0),.STACKADDR(32'h4000)) cpu(

  .clk(clk_i),.resetn(cpu_reset),.trap(trap),.mem_valid(cv),.mem_instr(),.mem_ready(cr),.mem_addr(ca),.mem_wdata(cwd),.mem_wstrb(cs),.mem_rdata(cd),

  .mem_la_read(la_read),.mem_la_write(la_write),.mem_la_addr(la_addr),.mem_la_wdata(),.mem_la_wstrb(),

  .pcpi_valid(pcv),.pcpi_insn(pci),.pcpi_rs1(pca),.pcpi_rs2(pcb),.pcpi_wr(pcwr),.pcpi_rd(pcr),.pcpi_wait(pcwait),.pcpi_ready(pcready),

  .irq(32'd0),.eoi(),.trace_valid(),.trace_data());

 (* syn_ramstyle="block_ram" *) reg [31:0] ram[0:4095];reg [31:0] ram_q;

 initial $readmemh(FIRMWARE,ram);

 localparam IDLE=0,LOCAL=1,WAIT_DDR=2,ACK=3;

 reg [1:0] state;reg req;reg [31:0] addr,data;reg [3:0] strobe;

 reg cache_valid;reg [27:0] cache_tag;reg [127:0] cache_data;

 assign mem_valid_o=req;assign mem_write_o=|strobe;

 assign mem_addr_o={addr[31:4],4'b0};assign mem_wdata_o={4{data}};

 assign mem_wstrb_o={12'd0,strobe}<<(addr[3:2]*4);

 always @(posedge clk_i)begin

   



  if(cpu_reset && (la_read || la_write) && la_addr<32'h4000) ram_q<=ram[la_addr[13:2]];

  if(state==IDLE && cv && busy_o && ca<32'h4000)begin

   if(cs[0])ram[ca[13:2]][7:0]<=cwd[7:0];

   if(cs[1])ram[ca[13:2]][15:8]<=cwd[15:8];

   if(cs[2])ram[ca[13:2]][23:16]<=cwd[23:16];

   if(cs[3])ram[ca[13:2]][31:24]<=cwd[31:24];

  end

 end

 integer i,j;

 always @(posedge clk_i or negedge rst_n_i)begin

  if(!rst_n_i)begin

   busy_o<=0;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;cr<=0;cd<=0;state<=IDLE;req<=0;addr<=0;data<=0;strobe<=0;cache_valid<=0;

   cache_tag<=0;cache_data<=0;

  end else begin

   cr<=0;

   if(start_i && !busy_o)begin busy_o<=1;done_o<=0;error_o<=0;outputs_o<=0;clipped_o<=0;state<=IDLE;req<=0;cache_valid<=0;end

   else if(busy_o)begin

    if(trap)begin busy_o<=0;done_o<=1;error_o<=1;req<=0;end

    else case(state)

     IDLE:if(cv)begin

      if(ca<32'h4000)begin cd<=ram_q;cr<=1;state<=ACK;end

      else if(ca>=32'h10100 && ca<32'h10180 && cs==0)begin cd<=command_i[ca[6:2]*32+:32];cr<=1;state<=ACK;end

      else if(ca>=32'h10000 && ca<32'h1000c && cs==4'hf)begin

       if(ca[3:2]==0)begin busy_o<=0;done_o<=1;error_o<=cwd[1];end

       if(ca[3:2]==1)outputs_o<=cwd;if(ca[3:2]==2)clipped_o<=cwd;

       cd<=0;cr<=1;state<=ACK;

       



      end else if(ca>=32'h02400000 && ca<32'h08000000)begin

       if(cs==0 && cache_valid && cache_tag==ca[31:4])begin cd<=cache_data[ca[3:2]*32+:32];cr<=1;state<=ACK;end

       else begin addr<=ca;data<=cwd;strobe<=cs;req<=1;state<=WAIT_DDR;end

      end else begin busy_o<=0;done_o<=1;error_o<=1;end

     end

     LOCAL:begin cd<=ram_q;cr<=1;state<=ACK;end

     ACK:state<=IDLE;

     WAIT_DDR:begin

      if(req && mem_ready_i)req<=0;

      if(mem_rsp_valid_i && !req)begin

       if(mem_error_i)begin busy_o<=0;done_o<=1;error_o<=1;end

       else begin

        cd<=mem_rdata_i[addr[3:2]*32+:32];cr<=1;state<=ACK;

        if(strobe==0)begin cache_valid<=1;cache_tag<=addr[31:4];cache_data<=mem_rdata_i;end

        else if(cache_valid && cache_tag==addr[31:4])begin

         for(j=0;j<4;j=j+1)if(strobe[j])cache_data[addr[3:2]*32+j*8+:8]<=data[j*8+:8];

        end

       end

      end

     end

    endcase

   end

  end

 end

endmodule

