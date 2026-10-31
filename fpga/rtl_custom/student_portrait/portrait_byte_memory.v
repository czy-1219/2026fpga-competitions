`timescale 1ns / 1ps
 

module portrait_byte_memory #(
    parameter [31:0] BASE_ADDRESS = 32'h01000000
)(
    input wire clk_i,
    input wire rst_n_i,
    input wire clear_i,
    input wire fence_i,
    input wire read_valid_i,
    output wire read_ready_o,
    input wire [31:0] read_address_i,
    output wire response_valid_o,
    input wire response_ready_i,
    output wire [7:0] response_data_o,
    input wire write_valid_i,
    output wire write_ready_o,
    input wire [31:0] write_address_i,
    input wire [7:0] write_data_i,
    output wire fence_done_o,
    output wire fault_o,
    output wire bus_idle_o,
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
    localparam [3:0] IDLE=0, READ_ADDRESS=1, READ_DATA=2,
        READ_DRAIN=3, RESPONSE=4, WRITE_ADDRESS=5, WRITE_DATA=6, WRITE_RESPONSE=7;
    reg [3:0] state, next_state;
    reg [27:0] read_tag, write_tag, pending_tag;
    reg [3:0] pending_lane;
    reg [127:0] read_line, write_line;
    reg [15:0] write_mask;
    reg read_cached, fault;
    reg [7:0] response_data;
    wire dirty = |write_mask;
    wire write_same = write_address_i[31:4]==write_tag;
    wire read_from_write = dirty && read_address_i[31:4]==write_tag && write_mask[read_address_i[3:0]];
    wire read_from_cache = read_cached && read_address_i[31:4]==read_tag;
    wire write_accept = write_valid_i && write_ready_o;
    wire read_accept = read_valid_i && read_ready_o;
    wire read_fault = rresp_i!=0 || !rlast_i;
    assign write_ready_o = rst_n_i && state==IDLE && !fault && !fence_i && !clear_i && (!dirty || write_same);
     
    assign read_ready_o = rst_n_i && state==IDLE && !fault && !fence_i && !clear_i && !write_valid_i;
    assign response_valid_o = state==RESPONSE && !fault;
    assign response_data_o = response_data;
    assign arvalid_o = state==READ_ADDRESS;
    assign araddr_o = BASE_ADDRESS + {pending_tag,4'b0000};
    assign rready_o = state==READ_DATA || state==READ_DRAIN;
    assign awvalid_o = state==WRITE_ADDRESS;
    assign awaddr_o = BASE_ADDRESS + {write_tag,4'b0000};
    assign wvalid_o = state==WRITE_DATA;
    assign wdata_o = write_line;
    assign wstrb_o = write_mask;
    assign wlast_o = 1'b1;
    assign bready_o = state==WRITE_RESPONSE;
    assign fence_done_o = fence_i && state==IDLE && !dirty && !fault;
    assign fault_o = fault;
    assign bus_idle_o = state==IDLE;

    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) state<=IDLE;
        else state<=next_state;
    end
    always @(*) begin
        next_state=state;
        case(state)
            IDLE: begin
                if(!clear_i && !fault) begin
                    if(dirty && (fence_i || (write_valid_i && !write_same))) next_state=WRITE_ADDRESS;
                    else if(read_accept) begin
                        if(read_from_write || read_from_cache) next_state=RESPONSE;
                        else next_state=READ_ADDRESS;
                    end
                end
            end
            READ_ADDRESS: if(arready_i) next_state=READ_DATA;
            READ_DATA: if(rvalid_i) begin
                if(read_fault) begin
                    if(rlast_i) next_state=IDLE;
                    else next_state=READ_DRAIN;
                end else next_state=RESPONSE;
            end
            READ_DRAIN: if(rvalid_i && rlast_i) next_state=IDLE;
            RESPONSE: if(response_ready_i) next_state=IDLE;
            WRITE_ADDRESS: if(awready_i) next_state=WRITE_DATA;
            WRITE_DATA: if(wready_i) next_state=WRITE_RESPONSE;
            WRITE_RESPONSE: if(bvalid_i) next_state=IDLE;
            default: next_state=IDLE;
        endcase
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            read_tag<=0;write_tag<=0;pending_tag<=0;pending_lane<=0;
            read_line<=0;write_line<=0;write_mask<=0;read_cached<=0;fault<=0;response_data<=0;
        end else begin
             
            if(clear_i && state==IDLE) begin
                read_cached<=0;write_mask<=0;fault<=0;
            end
            if(write_accept) begin
                write_tag<=write_address_i[31:4];
                write_line[write_address_i[3:0]*8 +: 8]<=write_data_i;
                write_mask[write_address_i[3:0]]<=1'b1;
                if(read_cached && read_tag==write_address_i[31:4]) read_cached<=0;
            end
            if(read_accept) begin
                pending_tag<=read_address_i[31:4];pending_lane<=read_address_i[3:0];
                if(read_from_write) response_data<=write_line[read_address_i[3:0]*8 +: 8];
                else if(read_from_cache) response_data<=read_line[read_address_i[3:0]*8 +: 8];
            end
            if(state==READ_DATA && rvalid_i) begin
                if(read_fault) begin fault<=1;read_cached<=0;end
                else begin
                    read_tag<=pending_tag;read_line<=rdata_i;read_cached<=1;
                    response_data<=rdata_i[pending_lane*8 +: 8];
                end
            end
            if(state==WRITE_RESPONSE && bvalid_i) begin
                write_mask<=0;
                if(bresp_i!=0) fault<=1;
            end
        end
    end
endmodule
