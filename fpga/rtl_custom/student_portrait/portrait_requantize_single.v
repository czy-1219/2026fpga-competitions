`timescale 1ns / 1ps
 
module portrait_requantize_single (
    input i_clk,  
    input i_rstn,  
    input i_flush,  
    input i_in_valid,  
    output o_in_ready,  
    input signed [31:0] i_accumulator,  
    input signed [31:0] i_multiplier,  
    input [5:0] i_shift,  
    input signed [31:0] i_zero,  
    input signed [7:0] i_minimum,  
    input signed [7:0] i_maximum,  
    output o_out_valid,  
    input i_out_ready,  
    output signed [7:0] o_pixel  
);
reg [3:0] reg_valid;  
reg signed [63:0] reg_product;  
reg signed [63:0] reg_nudged;  
reg signed [63:0] reg_scaled;  
reg signed [7:0] reg_pixel_o;  
reg [5:0] reg_shift_product, reg_shift_nudged;  
reg signed [31:0] reg_zero_product, reg_zero_nudged;  
reg signed [7:0] reg_min_product, reg_min_nudged, reg_min_scaled;  
reg signed [7:0] reg_max_product, reg_max_nudged, reg_max_scaled;  
wire wire_advance;  
wire signed [63:0] wire_zero_extended;  
assign wire_zero_extended = {{32{reg_zero_nudged[31]}}, reg_zero_nudged};
assign wire_advance = !reg_valid[3] || i_out_ready;
assign o_in_ready = wire_advance && !i_flush;
assign o_out_valid = reg_valid[3] && !i_flush;
assign o_pixel = reg_pixel_o;

 
always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) reg_valid <= 4'b0000;
    else if (i_flush) reg_valid <= 4'b0000;
    else if (wire_advance) reg_valid <= {reg_valid[2:0], i_in_valid && o_in_ready};
end

 
always @(posedge i_clk) begin
    if (i_rstn && !i_flush && wire_advance) begin
        if (i_in_valid && o_in_ready) begin
            reg_product <= i_accumulator * i_multiplier;
            reg_shift_product <= i_shift;
            reg_zero_product <= i_zero;
            reg_min_product <= i_minimum;
            reg_max_product <= i_maximum;
        end
        if (reg_valid[0]) begin
            reg_nudged <= reg_product + (64'sd1 <<< (reg_shift_product - 6'd1));
            reg_shift_nudged <= reg_shift_product;
            reg_zero_nudged <= reg_zero_product;
            reg_min_nudged <= reg_min_product;
            reg_max_nudged <= reg_max_product;
        end
        if (reg_valid[1]) begin
            reg_scaled <= (reg_nudged >>> reg_shift_nudged) + wire_zero_extended;
            reg_min_scaled <= reg_min_nudged;
            reg_max_scaled <= reg_max_nudged;
        end
        if (reg_valid[2]) begin
            if (reg_scaled < reg_min_scaled) reg_pixel_o <= reg_min_scaled;
            else if (reg_scaled > reg_max_scaled) reg_pixel_o <= reg_max_scaled;
            else reg_pixel_o <= reg_scaled[7:0];
        end
    end
end
endmodule
