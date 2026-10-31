`timescale 1ns / 1ps
 

module portrait_memory_arbiter (
    input wire clk_i,
    input wire rst_n_i,
    output wire model_idle_o,
    input wire legacy_arvalid_i,
    output wire legacy_arready_o,
    input wire [31:0] legacy_araddr_i,
    input wire [7:0] legacy_arlen_i,
    output wire legacy_rvalid_o,
    input wire legacy_rready_i,
    input wire legacy_awvalid_i,
    output wire legacy_awready_o,
    input wire [31:0] legacy_awaddr_i,
    input wire [7:0] legacy_awlen_i,
    input wire legacy_wvalid_i,
    output wire legacy_wready_o,
    input wire [127:0] legacy_wdata_i,
    input wire [15:0] legacy_wstrb_i,
    input wire legacy_wlast_i,
    output wire legacy_bvalid_o,
    input wire legacy_bready_i,
    input wire model_arvalid_i,
    output wire model_arready_o,
    input wire [31:0] model_araddr_i,
    output wire model_rvalid_o,
    input wire model_rready_i,
    input wire model_awvalid_i,
    output wire model_awready_o,
    input wire [31:0] model_awaddr_i,
    input wire model_wvalid_i,
    output wire model_wready_o,
    input wire [127:0] model_wdata_i,
    input wire [15:0] model_wstrb_i,
    input wire model_wlast_i,
    output wire model_bvalid_o,
    input wire model_bready_i,
    output wire arvalid_o,
    input wire arready_i,
    output wire [31:0] araddr_o,
    output wire [7:0] arlen_o,
    input wire rvalid_i,
    input wire rlast_i,
    output wire rready_o,
    output wire awvalid_o,
    input wire awready_i,
    output wire [31:0] awaddr_o,
    output wire [7:0] awlen_o,
    output wire wvalid_o,
    input wire wready_i,
    output wire [127:0] wdata_o,
    output wire [15:0] wstrb_o,
    output wire wlast_o,
    input wire bvalid_i,
    output wire bready_o
);
     
    assign model_idle_o = !model_read_owner && !model_write_owner;
    reg model_read_owner,model_read_inflight,legacy_read_stalled;
    reg [11:0] legacy_read_pending;
    reg model_write_owner;
    reg [11:0] legacy_pending;
    wire acquire_read=!model_read_owner && model_arvalid_i &&
        legacy_read_pending==0 && !legacy_read_stalled;
    wire selected_read=model_read_owner || acquire_read;
    wire allow_legacy_read=!selected_read && (!model_arvalid_i || legacy_read_stalled);
    wire legacy_read_address_accept=legacy_arvalid_i && legacy_arready_o;
    wire legacy_read_response_accept=legacy_rvalid_o && legacy_rready_i && rlast_i;
    wire model_read_address_accept=model_arvalid_i && model_arready_o;
    wire model_read_response_accept=model_rvalid_o && model_rready_i && rlast_i;
    wire write_available = legacy_pending==0 && !legacy_awvalid_i && !legacy_wvalid_i;
    wire acquire_write = !model_write_owner && model_awvalid_i && write_available;
    wire selected_write = model_write_owner || acquire_write;
    wire legacy_address_accept = legacy_awvalid_i && legacy_awready_o;
    wire legacy_response_accept = legacy_bvalid_o && legacy_bready_i;

    assign arvalid_o=selected_read ? (!model_read_inflight && model_arvalid_i) :
        (allow_legacy_read && legacy_arvalid_i);
    assign araddr_o=selected_read ? model_araddr_i : legacy_araddr_i;
    assign arlen_o=selected_read ? 8'd0 : legacy_arlen_i;
    assign model_arready_o=selected_read && !model_read_inflight && arready_i;
    assign legacy_arready_o=allow_legacy_read && arready_i;
    assign model_rvalid_o=model_read_owner && model_read_inflight && rvalid_i;
    assign legacy_rvalid_o=!model_read_owner && !acquire_read && rvalid_i;
    assign rready_o=model_read_owner ? (model_read_inflight && model_rready_i) :
        (acquire_read ? 1'b0 : legacy_rready_i);

     
    assign awvalid_o = selected_write ? model_awvalid_i : legacy_awvalid_i;
    assign awaddr_o = selected_write ? model_awaddr_i : legacy_awaddr_i;
    assign awlen_o = selected_write ? 8'd0 : legacy_awlen_i;
    assign model_awready_o = selected_write && awready_i;
    assign legacy_awready_o = !selected_write && awready_i;
    assign wvalid_o = selected_write ? model_wvalid_i : legacy_wvalid_i;
    assign wdata_o = selected_write ? model_wdata_i : legacy_wdata_i;
    assign wstrb_o = selected_write ? model_wstrb_i : legacy_wstrb_i;
    assign wlast_o = selected_write ? model_wlast_i : legacy_wlast_i;
    assign model_wready_o = selected_write && wready_i;
    assign legacy_wready_o = !selected_write && wready_i;
    assign model_bvalid_o = model_write_owner && bvalid_i;
    assign legacy_bvalid_o = !model_write_owner && bvalid_i;
    assign bready_o = model_write_owner ? model_bready_i : legacy_bready_i;

    always @(posedge clk_i or negedge rst_n_i)begin
        if(!rst_n_i)begin
            model_read_owner<=0;model_read_inflight<=0;legacy_read_stalled<=0;
            legacy_read_pending<=0;model_write_owner<=0;legacy_pending<=0;
        end else begin
            if(acquire_read)model_read_owner<=1;
            if(model_read_address_accept)model_read_inflight<=1;
            if(model_read_response_accept)begin model_read_owner<=0;model_read_inflight<=0;end
            if(legacy_read_address_accept)legacy_read_stalled<=0;
            else if(allow_legacy_read && legacy_arvalid_i && !arready_i)legacy_read_stalled<=1;
            case({legacy_read_address_accept,legacy_read_response_accept})
                2'b10: legacy_read_pending<=legacy_read_pending+1'b1;
                2'b01: if(legacy_read_pending!=0)legacy_read_pending<=legacy_read_pending-1'b1;
                default: legacy_read_pending<=legacy_read_pending;
            endcase
            if(acquire_write)model_write_owner<=1;
            if(model_write_owner && bvalid_i && model_bready_i)model_write_owner<=0;
            case({legacy_address_accept,legacy_response_accept})
                2'b10: legacy_pending<=legacy_pending+1'b1;
                2'b01: if(legacy_pending!=0)legacy_pending<=legacy_pending-1'b1;
                default: legacy_pending<=legacy_pending;
            endcase
        end
    end
endmodule
