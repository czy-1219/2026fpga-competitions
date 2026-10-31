 


module moire_policy_temporal #(
    parameter integer ALPHA_SHIFT = 2
) (
    input        clk_i,
    input        rst_n_i,
    input        update_i,
    input  [7:0] weight_c0_i,
    input  [7:0] weight_c1_i,
    input  [7:0] weight_c2_i,
    input  [7:0] weight_c3_i,
    input  [7:0] weight_c4_i,
    input  [7:0] text_protect_i,
    output reg [7:0] weight_c0_o,
    output reg [7:0] weight_c1_o,
    output reg [7:0] weight_c2_o,
    output reg [7:0] weight_c3_o,
    output reg [7:0] weight_c4_o,
    output reg [7:0] text_protect_o
);
    wire [15:0] a = (16'd1 << ALPHA_SHIFT);
    wire [15:0] inv_a = a - 1'b1;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            weight_c0_o <= 8'd255;
            weight_c1_o <= 8'd0;
            weight_c2_o <= 8'd0;
            weight_c3_o <= 8'd0;
            weight_c4_o <= 8'd0;
            text_protect_o <= 8'd0;
        end else if (update_i) begin
            weight_c0_o <= (weight_c0_o * inv_a + weight_c0_i) >> ALPHA_SHIFT;
            weight_c1_o <= (weight_c1_o * inv_a + weight_c1_i) >> ALPHA_SHIFT;
            weight_c2_o <= (weight_c2_o * inv_a + weight_c2_i) >> ALPHA_SHIFT;
            weight_c3_o <= (weight_c3_o * inv_a + weight_c3_i) >> ALPHA_SHIFT;
            weight_c4_o <= (weight_c4_o * inv_a + weight_c4_i) >> ALPHA_SHIFT;
            text_protect_o <= (text_protect_o * inv_a + text_protect_i) >> ALPHA_SHIFT;
        end
    end
endmodule
