`timescale 1ns / 1ps
 
module portrait_weight_service (
    input i_clk, input i_rstn, input i_flush,
    input i_request_valid, output o_request_ready,
    input [12:0] i_address,
    output o_response_valid, input i_response_ready,
    output [63:0] o_weights, output o_error
);
(* syn_romstyle = "block_rom" *) reg [63:0] reg_main [0:4095];
(* syn_romstyle = "logic" *) reg [63:0] reg_tail [0:5];
reg [63:0] reg_weights_o;
reg [63:0] reg_main_read;
reg reg_select_tail, reg_invalid;
reg reg_valid, reg_error_o;
wire wire_advance;
assign wire_advance = !reg_valid || i_response_ready;
assign o_request_ready = wire_advance && !i_flush;
assign o_response_valid = reg_valid && !i_flush;
assign o_weights = reg_invalid ? 64'd0 : (reg_select_tail ? reg_weights_o : reg_main_read);
assign o_error = reg_error_o;
initial begin
    $readmemh("rtl_custom/student_portrait/portrait_weights_main.mem", reg_main);
    $readmemh("rtl_custom/student_portrait/portrait_weights_tail.mem", reg_tail);
end
always @(posedge i_clk) begin
    if (i_rstn && !i_flush && i_request_valid && o_request_ready) begin
        reg_main_read <= reg_main[i_address[11:0]];
        reg_select_tail <= i_address[12];
        reg_invalid <= (i_address >= 4102);
        if (i_address >= 4096 && i_address < 4102)
            reg_weights_o <= reg_tail[i_address[2:0]];
    end
end
always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin reg_valid <= 1'b0; reg_error_o <= 1'b0; end
    else if (i_flush) begin reg_valid <= 1'b0; reg_error_o <= 1'b0; end
    else if (wire_advance) begin
        reg_valid <= i_request_valid;
        if (i_request_valid && o_request_ready) reg_error_o <= (i_address >= 4102);
    end
end
endmodule
