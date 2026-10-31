`timescale 1ns / 1ps
 

module portrait_register_endpoint (
    output wire job_active_o,
    input wire clk_i,
    input wire rst_n_i,
    input wire write_valid_i,
    input wire [6:0] write_address_i,
    input wire [7:0] write_data_i,
    input wire [6:0] read_address_i,
    output reg [7:0] read_data_o,
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
    localparam [3:0] IDLE=0, LOAD=1, FENCE=2, START=3, RUN=4,
        FETCH=5, ALPHA_CRC=6, DONE=7, ERROR=8;
    reg [3:0] state,next_state;
    assign job_active_o=state!=IDLE && state!=DONE && state!=ERROR;
    reg [15:0] input_count;
    reg [12:0] alpha_count;
    reg input_pending,alpha_valid,read_pending,input_crc_busy,complete,error;
    reg [7:0] input_byte,alpha_byte;
    reg [2:0] input_crc_bit,alpha_crc_bit;
    reg [31:0] input_crc,alpha_crc;
    wire input_ready=state==LOAD && !input_pending && !input_crc_busy && input_count<49152 && !load_fault;
    wire begin_request=write_valid_i && write_address_i==7'h50 && write_data_i==1;
    wire begin_allowed=(state==IDLE || state==DONE || state==LOAD) && load_idle && !input_pending && !input_crc_busy;
    wire begin_job=begin_request && begin_allowed;
    wire run_request=write_valid_i && write_address_i==7'h50 && write_data_i==2;
    wire run_allowed=input_count==49152 && !input_pending && !input_crc_busy;
    wire put_request=write_valid_i && write_address_i==7'h52;
    wire pop_request=write_valid_i && write_address_i==7'h57 && write_data_i==1 && state==FETCH && alpha_valid;
    wire load_read_valid=state==FETCH && !alpha_valid && !read_pending && alpha_count<4096;
    wire load_read_ready,load_response_valid,load_response_ready;
    wire [7:0] load_response_data;
    wire load_write_ready,load_fence_done,load_fault,load_idle;
    wire load_accept=input_pending && load_write_ready && state==LOAD;
    wire infer_owner=state==START || state==RUN;
    wire infer_ready,infer_done,infer_error;
    wire [4:0] infer_stage;
    wire lar,lrr,law,lwv,lwl,lbr,mar,mrr,maw,mwv,mwl,mbr;
    wire [31:0] lara,lawa,mara,mawa;
    wire [127:0] lwd,mwd;
    wire [15:0] lws,mws;
    wire [31:0] visible_crc=~((state==LOAD || state==FENCE) ? input_crc:alpha_crc);
    assign load_response_ready=state==FETCH && !alpha_valid && read_pending;
    assign arvalid_o=infer_owner ? mar:lar;
    assign araddr_o=infer_owner ? mara:lara;
    assign rready_o=infer_owner ? mrr:lrr;
    assign awvalid_o=infer_owner ? maw:law;
    assign awaddr_o=infer_owner ? mawa:lawa;
    assign wvalid_o=infer_owner ? mwv:lwv;
    assign wdata_o=infer_owner ? mwd:lwd;
    assign wstrb_o=infer_owner ? mws:lws;
    assign wlast_o=infer_owner ? mwl:lwl;
    assign bready_o=infer_owner ? mbr:lbr;
    always @(*) begin
        read_data_o=0;
        case(read_address_i)
            7'h50: read_data_o=8'h70;
            7'h51: read_data_o={1'b0,alpha_count==4096,input_count==49152 && !input_pending && !input_crc_busy,alpha_valid,error,complete,
                state==FENCE || state==START || state==RUN,input_ready};
            7'h53: read_data_o=input_count[7:0];
            7'h54: read_data_o=input_count[15:8];
            7'h55: read_data_o={3'd0,infer_stage};
            7'h56: read_data_o=alpha_byte;
            7'h58: read_data_o=alpha_count[7:0];
            7'h59: read_data_o={3'd0,alpha_count[12:8]};
            7'h5c: read_data_o=visible_crc[7:0];
            7'h5d: read_data_o=visible_crc[15:8];
            7'h5e: read_data_o=visible_crc[23:16];
            7'h5f: read_data_o=visible_crc[31:24];
            default: read_data_o=0;
        endcase
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)state<=IDLE;else state<=next_state;
    end
    always @(*) begin
        next_state=state;
        if(begin_job)next_state=LOAD;
        else case(state)
            LOAD: begin
                if(load_fault || (put_request && !input_ready))next_state=ERROR;
                else if(run_request)begin
                    if(run_allowed)next_state=FENCE;
                    else next_state=ERROR;
                end
            end
            FENCE: begin
                if(load_fault)next_state=ERROR;
                else if(load_fence_done && infer_ready)next_state=START;
            end
            START: next_state=RUN;
            RUN: if(infer_done)begin
                if(infer_error)next_state=DONE;
                else next_state=FETCH;
            end
            FETCH: begin
                if(load_fault)next_state=ERROR;
                else if(load_response_valid && load_response_ready)next_state=ALPHA_CRC;
                else if(pop_request && alpha_count==4095)next_state=DONE;
            end
            ALPHA_CRC: if(alpha_crc_bit==7)next_state=FETCH;
            ERROR: if(load_idle)next_state=DONE;
            default: next_state=state;
        endcase
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)begin
            input_count<=0;alpha_count<=0;input_pending<=0;alpha_valid<=0;read_pending<=0;
            input_crc_busy<=0;input_crc_bit<=0;alpha_crc_bit<=0;
            input_byte<=0;alpha_byte<=0;input_crc<=32'hffffffff;alpha_crc<=32'hffffffff;complete<=0;error<=0;
        end else if(begin_job)begin
            input_count<=0;alpha_count<=0;input_pending<=0;alpha_valid<=0;read_pending<=0;
            input_crc_busy<=0;input_crc_bit<=0;alpha_crc_bit<=0;
            input_crc<=32'hffffffff;alpha_crc<=32'hffffffff;complete<=0;error<=0;
        end else begin
            if(state==LOAD && put_request && input_ready)begin input_byte<=write_data_i;input_pending<=1;end
            if(load_accept)begin
                input_count<=input_count+1'b1;input_pending<=0;input_crc<=input_crc^{24'd0,input_byte};
                input_crc_busy<=1;input_crc_bit<=0;
            end
            if(input_crc_busy)begin
                input_crc<=input_crc[0] ? (input_crc>>1)^32'hedb88320:input_crc>>1;
                input_crc_bit<=input_crc_bit+1'b1;
                if(input_crc_bit==7)input_crc_busy<=0;
            end
            if(load_read_valid && load_read_ready)read_pending<=1;
            if(load_response_valid && load_response_ready)begin
                read_pending<=0;alpha_byte<=load_response_data;
                alpha_crc<=alpha_crc^{24'd0,load_response_data};alpha_crc_bit<=0;
            end
            if(state==ALPHA_CRC)begin
                alpha_crc<=alpha_crc[0] ? (alpha_crc>>1)^32'hedb88320:alpha_crc>>1;
                alpha_crc_bit<=alpha_crc_bit+1'b1;
                if(alpha_crc_bit==7)alpha_valid<=1;
            end
            if(pop_request)begin alpha_valid<=0;alpha_count<=alpha_count+1'b1;end
            if(state==RUN && infer_done)begin complete<=1;error<=infer_error;end
            if(next_state==ERROR)begin error<=1;input_pending<=0;alpha_valid<=0;end
            if(state==ERROR && load_idle)complete<=1;
        end
    end
    portrait_byte_memory load_memory(
        .clk_i(clk_i),.rst_n_i(rst_n_i),.clear_i(begin_job || state==IDLE),.fence_i(state==FENCE),
        .read_valid_i(load_read_valid),.read_ready_o(load_read_ready),.read_address_i(32'd344064+{19'd0,alpha_count}),
        .response_valid_o(load_response_valid),.response_ready_i(load_response_ready),.response_data_o(load_response_data),
        .write_valid_i(input_pending && state==LOAD),.write_ready_o(load_write_ready),.write_address_i({16'd0,input_count}),.write_data_i(input_byte^8'h80),
        .fence_done_o(load_fence_done),.fault_o(load_fault),.bus_idle_o(load_idle),
        .arvalid_o(lar),.arready_i(arready_i && !infer_owner),.araddr_o(lara),.rvalid_i(rvalid_i && !infer_owner),.rlast_i(rlast_i),.rresp_i(rresp_i),.rdata_i(rdata_i),.rready_o(lrr),
        .awvalid_o(law),.awready_i(awready_i && !infer_owner),.awaddr_o(lawa),.wvalid_o(lwv),.wready_i(wready_i && !infer_owner),.wdata_o(lwd),.wstrb_o(lws),.wlast_o(lwl),
        .bvalid_i(bvalid_i && !infer_owner),.bresp_i(bresp_i),.bready_o(lbr));
    portrait_axi_network inference(
        .clk_i(clk_i),.rst_n_i(rst_n_i),.start_i(state==START),.first_stage_i(5'd0),.last_stage_i(5'd24),
        .ready_o(infer_ready),.done_o(infer_done),.error_o(infer_error),.stage_o(infer_stage),
        .arvalid_o(mar),.arready_i(arready_i && infer_owner),.araddr_o(mara),.rvalid_i(rvalid_i && infer_owner),.rlast_i(rlast_i),.rresp_i(rresp_i),.rdata_i(rdata_i),.rready_o(mrr),
        .awvalid_o(maw),.awready_i(awready_i && infer_owner),.awaddr_o(mawa),.wvalid_o(mwv),.wready_i(wready_i && infer_owner),.wdata_o(mwd),.wstrb_o(mws),.wlast_o(mwl),
        .bvalid_i(bvalid_i && infer_owner),.bresp_i(bresp_i),.bready_o(mbr));
endmodule
