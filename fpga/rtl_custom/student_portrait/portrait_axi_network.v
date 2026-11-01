`timescale 1ns / 1ps
 
module portrait_axi_network (
    input wire clk_i,
    input wire rst_n_i,
    input wire start_i,
    input wire [4:0] first_stage_i,
    input wire [4:0] last_stage_i,
    output wire ready_o,
    output wire done_o,
    output wire error_o,
    output wire [4:0] stage_o,
    output wire arvalid_o,
    input wire arready_i,
    output wire [31:0] araddr_o,
    input wire rvalid_i,
    input wire rlast_i,
    input wire [1:0] rresp_i,
    input wire [127:0] rdata_i,
    output wire rready_o,
    output wire awvalid_o,
    input wire awready_i,
    output wire [31:0] awaddr_o,
    output wire wvalid_o,
    input wire wready_i,
    output wire [127:0] wdata_o,
    output wire [15:0] wstrb_o,
    output wire wlast_o,
    input wire bvalid_i,
    input wire [1:0] bresp_i,
    output wire bready_o
);
    localparam [2:0] IDLE=0,START=1,RUN=2,FENCE=3,ABORT=4;
    reg [2:0] state,next_state;
    reg [4:0] first_stage,last_stage,stage;
    reg done,error;
    wire read_valid,read_ready,response_valid,response_ready,write_valid,write_ready;
    wire [31:0] read_address,write_address;
    wire [7:0] read_data,write_data;
    wire engine_done,engine_error,engine_ready,mem_fault,mem_idle,fence_done;
    wire [4:0] engine_stage;
    // Registered reset release stays stable when START changes to RUN.
    reg core_reset;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) core_reset <= 1'b0;
        else if (state == IDLE) core_reset <= start_i;
        else if (next_state == ABORT || next_state == IDLE) core_reset <= 1'b0;
    end
    assign ready_o=rst_n_i && state==IDLE;
    assign done_o=done;assign error_o=error;
    assign stage_o=stage;
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)state<=IDLE;else state<=next_state;
    end
    always @(*) begin
        next_state=state;
        case(state)
            IDLE: if(start_i)next_state=START;
            START: next_state=RUN;
            RUN: begin
                if(mem_fault || engine_error)next_state=ABORT;
                else if(engine_done)next_state=FENCE;
            end
            FENCE: begin
                if(mem_fault)next_state=ABORT;
                else if(fence_done)next_state=IDLE;
            end
            ABORT: if(mem_idle)next_state=IDLE;
            default: next_state=IDLE;
        endcase
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)begin first_stage<=0;last_stage<=24;stage<=0;done<=0;error<=0;end
        else begin
            done<=0;
            if(state==IDLE && start_i)begin first_stage<=first_stage_i;last_stage<=last_stage_i;error<=0;end
            if(state==START)stage<=first_stage;
            if(state==RUN)stage<=engine_stage;
            if(state==FENCE && fence_done)done<=1;
            if(state==ABORT && mem_idle)begin done<=1;error<=1;end
        end
    end
    portrait_network_engine network(
        .clk(clk_i),.rst_n(core_reset),.start(state==START),.ready(engine_ready),
        .first_stage(first_stage),.last_stage(last_stage),.stage_o(engine_stage),
        .rd_valid(read_valid),.rd_ready(read_ready),.rd_address(read_address),
        .rd_response_valid(response_valid),.rd_response_ready(response_ready),.rd_data(read_data),
        .wr_valid(write_valid),.wr_ready(write_ready),.wr_address(write_address),.wr_data(write_data),
        .done(engine_done),.error(engine_error));
    portrait_byte_memory memory(
        .clk_i(clk_i),.rst_n_i(rst_n_i),.clear_i(state==IDLE),.fence_i(state==FENCE),
        .read_valid_i(read_valid && state==RUN),.read_ready_o(read_ready),.read_address_i(read_address),
        .response_valid_o(response_valid),.response_ready_i(response_ready),.response_data_o(read_data),
        .write_valid_i(write_valid && state==RUN),.write_ready_o(write_ready),.write_address_i(write_address),.write_data_i(write_data),
        .fence_done_o(fence_done),.fault_o(mem_fault),.bus_idle_o(mem_idle),
        .arvalid_o(arvalid_o),.arready_i(arready_i),.araddr_o(araddr_o),
        .rvalid_i(rvalid_i),.rlast_i(rlast_i),.rresp_i(rresp_i),.rdata_i(rdata_i),.rready_o(rready_o),
        .awvalid_o(awvalid_o),.awready_i(awready_i),.awaddr_o(awaddr_o),
        .wvalid_o(wvalid_o),.wready_i(wready_i),.wdata_o(wdata_o),.wstrb_o(wstrb_o),.wlast_o(wlast_o),
        .bvalid_i(bvalid_i),.bresp_i(bresp_i),.bready_o(bready_o));
endmodule
