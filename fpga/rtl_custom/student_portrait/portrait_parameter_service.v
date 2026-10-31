`timescale 1ns / 1ps
 
module portrait_parameter_service (
    input i_clk, input i_rstn, input i_flush,
    input i_request_valid, output o_request_ready,
    input [3:0] i_layer, input [6:0] i_group,
    output o_response_valid, input i_response_ready,
    output [255:0] o_bias, output [255:0] o_multiplier,
    output [47:0] o_shift, output o_error
);
 
(* syn_romstyle = "block_rom" *) reg [287:0] reg_parameters_low [0:31];
(* syn_romstyle = "block_rom" *) reg [287:0] reg_parameters_high [0:31];
reg [287:0] reg_parameters_low_read,reg_parameters_high_read;
wire [575:0] reg_packet;
reg reg_valid, reg_error_o;
wire wire_advance;
wire wire_invalid;
assign wire_advance = !reg_valid || i_response_ready;
assign wire_invalid = (i_layer >= 12) || (i_group > 1) || (i_layer == 11 && i_group != 0);
assign o_request_ready = wire_advance && !i_flush;
assign o_response_valid = reg_valid && !i_flush;
assign o_error = reg_error_o;
assign reg_packet = reg_error_o ? 576'd0 : {reg_parameters_high_read,reg_parameters_low_read};
initial begin
    $readmemh("rtl_custom/student_portrait/portrait_quantization_half0.mem", reg_parameters_low);
    $readmemh("rtl_custom/student_portrait/portrait_quantization_half1.mem", reg_parameters_high);
end
genvar lane;
generate for (lane=0; lane<8; lane=lane+1) begin: quantization_fields
    assign o_bias[lane*32+:32] = reg_packet[lane*72+40+:32];
    assign o_multiplier[lane*32+:32] = reg_packet[lane*72+8+:32];
    assign o_shift[lane*6+:6] = reg_packet[lane*72+:6];
end endgenerate
always @(posedge i_clk) begin
    if (i_rstn && !i_flush && i_request_valid && o_request_ready) begin
         

        reg_parameters_low_read <= reg_parameters_low[{i_layer,i_group[0]}];
        reg_parameters_high_read <= reg_parameters_high[{i_layer,i_group[0]}];
    end
end
always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin reg_valid <= 1'b0; reg_error_o <= 1'b0; end
    else if (i_flush) begin reg_valid <= 1'b0; reg_error_o <= 1'b0; end
    else if (wire_advance) begin
        reg_valid <= i_request_valid;
        if (i_request_valid && o_request_ready) reg_error_o <= wire_invalid;
    end
end
endmodule
