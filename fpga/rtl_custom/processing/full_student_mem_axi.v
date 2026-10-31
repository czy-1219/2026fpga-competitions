`timescale 1ns/1ps
 


module full_student_mem_axi(
 input wire clk_i,rst_n_i,
 input wire req_valid_i,output wire req_ready_o,input wire req_write_i,
 input wire [31:0] req_addr_i,input wire [127:0] req_data_i,input wire [15:0] req_strb_i,
 output reg rsp_valid_o,rsp_error_o,output reg [127:0] rsp_data_o,
 output wire arvalid_o,input wire arready_i,output wire [31:0] araddr_o,
 input wire rvalid_i,rlast_i,input wire [1:0] rresp_i,input wire [127:0] rdata_i,output wire rready_o,
 output wire awvalid_o,input wire awready_i,output wire [31:0] awaddr_o,
 output wire wvalid_o,input wire wready_i,output wire [127:0] wdata_o,output wire [15:0] wstrb_o,output wire wlast_o,
 input wire bvalid_i,input wire [1:0] bresp_i,output wire bready_o
);
 localparam IDLE=0,RA=1,RD=2,WS=3,WB=4,RESP=5;
 reg [2:0] state;reg [31:0] address;reg [127:0] data;reg [15:0] strb;
 reg aw_sent,w_sent,bad_read;
 wire launch=rst_n_i && state==IDLE && req_valid_i && req_addr_i[3:0]==0;
 wire read_launch=launch && !req_write_i;
 wire write_launch=launch && req_write_i;
 assign req_ready_o=state==IDLE;
 assign arvalid_o=state==RA || read_launch;assign araddr_o=state==IDLE ? req_addr_i : address;assign rready_o=state==RD;
 assign awvalid_o=(state==WS && !aw_sent) || write_launch;assign awaddr_o=state==IDLE ? req_addr_i : address;
 assign wvalid_o=(state==WS && !w_sent) || write_launch;assign wdata_o=state==IDLE ? req_data_i : data;assign wstrb_o=state==IDLE ? req_strb_i : strb;assign wlast_o=1;
 assign bready_o=state==WB;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   state<=IDLE;address<=0;data<=0;strb<=0;aw_sent<=0;w_sent<=0;bad_read<=0;
   rsp_valid_o<=0;rsp_error_o<=0;rsp_data_o<=0;
  end else begin
   rsp_valid_o<=0;
   case(state)
    IDLE:if(req_valid_i)begin
     address<=req_addr_i;data<=req_data_i;strb<=req_strb_i;aw_sent<=0;w_sent<=0;bad_read<=0;
     rsp_error_o<=0;
     if(req_addr_i[3:0]!=0)begin rsp_error_o<=1;state<=RESP;end
     else if(req_write_i)begin
      aw_sent<=awready_i;w_sent<=wready_i;
      state<=awready_i && wready_i ? WB : WS;
     end else state<=arready_i ? RD : RA;
    end
    RA:if(arready_i)state<=RD;
    RD:if(rvalid_i)begin
     rsp_data_o<=rdata_i;
     if(rresp_i!=0 || !rlast_i)bad_read<=1;
     if(rlast_i)begin rsp_error_o<=bad_read || rresp_i!=0;rsp_valid_o<=1;state<=IDLE;end
    end
    WS:begin
     if(awvalid_o && awready_i)aw_sent<=1;
     if(wvalid_o && wready_i)w_sent<=1;
     if((aw_sent || awready_i) && (w_sent || wready_i))state<=WB;
    end
    WB:if(bvalid_i)begin rsp_error_o<=bresp_i!=0;rsp_valid_o<=1;state<=IDLE;end
    RESP:begin rsp_valid_o<=1;state<=IDLE;end
    default:begin rsp_error_o<=1;state<=RESP;end
   endcase
  end
 end
endmodule
