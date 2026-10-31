`timescale 1ns / 1ps

 


module student_requantize (
    input wire clk_i,
    input wire rst_n_i,
    input wire valid_i,
    output wire ready_o,
    input wire signed [31:0] accumulator_i,
    input wire signed [31:0] multiplier_i,
    input wire [5:0] right_shift_i,
    input wire signed [31:0] output_zero_i,
    input wire signed [7:0] minimum_i,
    input wire signed [7:0] maximum_i,
    output wire valid_o,
    input wire ready_i,
    output wire signed [7:0] pixel_o
);
    reg [3:0] pipeline_valid;
    reg signed [63:0] product;
    reg signed [31:0] high_product;
    reg signed [63:0] scaled_pixel;
    reg signed [7:0] pixel;
    reg [5:0] shift_product, shift_high;
    reg signed [31:0] zero_product, zero_high;
    reg signed [7:0] minimum_product, minimum_high, minimum_scaled;
    reg signed [7:0] maximum_product, maximum_high, maximum_scaled;
    reg saturated_product;
    wire advance;
    wire signed [63:0] nudge;
    wire signed [63:0] nudged_product;
    wire signed [63:0] truncated_product;
    wire [31:0] remainder_mask;
    wire [31:0] remainder;
    wire [31:0] threshold;
    wire signed [63:0] shifted_high;
    wire signed [63:0] rounded_high;
    wire signed [63:0] rescaled_pixel;

    assign advance = !pipeline_valid[3] || ready_i;
    assign ready_o = advance && (right_shift_i <= 6'd31);
    assign valid_o = pipeline_valid[3];
    assign pixel_o = pixel;
    assign nudge = product >= 0 ? 64'sd1073741824 : -64'sd1073741823;
    assign nudged_product = product + nudge;
    assign truncated_product = nudged_product / 64'sd2147483648;
    assign remainder_mask = (32'h00000001 << shift_high) - 1'b1;
    assign remainder = high_product & remainder_mask;
    assign threshold = (remainder_mask >> 1) + (high_product < 0);
    assign shifted_high = $signed(high_product) >>> shift_high;
    assign rounded_high = shifted_high + (remainder > threshold);
    assign rescaled_pixel = rounded_high + zero_high;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            pipeline_valid <= 4'b0000;
            product <= 64'sd0;
            high_product <= 32'sd0;
            scaled_pixel <= 64'sd0;
            pixel <= 8'sd0;
            saturated_product <= 1'b0;
            shift_product <= 6'd0;
            shift_high <= 6'd0;
            zero_product <= 32'sd0;
            zero_high <= 32'sd0;
            minimum_product <= -8'sd128;
            minimum_high <= -8'sd128;
            minimum_scaled <= -8'sd128;
            maximum_product <= 8'sd127;
            maximum_high <= 8'sd127;
            maximum_scaled <= 8'sd127;
        end else if (advance) begin
            pipeline_valid <= {pipeline_valid[2:0], valid_i && ready_o};
            if (valid_i && ready_o) begin
                product <= accumulator_i * multiplier_i;
                saturated_product <= (accumulator_i == -32'sd2147483648)
                                  && (multiplier_i == -32'sd2147483648);
                shift_product <= right_shift_i;
                zero_product <= output_zero_i;
                minimum_product <= minimum_i;
                maximum_product <= maximum_i;
            end
            if (pipeline_valid[0]) begin
                high_product <= saturated_product ? 32'sd2147483647 : truncated_product[31:0];
                shift_high <= shift_product;
                zero_high <= zero_product;
                minimum_high <= minimum_product;
                maximum_high <= maximum_product;
            end
            if (pipeline_valid[1]) begin
                scaled_pixel <= rescaled_pixel;
                minimum_scaled <= minimum_high;
                maximum_scaled <= maximum_high;
            end
            if (pipeline_valid[2]) begin
                if (scaled_pixel < minimum_scaled)
                    pixel <= minimum_scaled;
                else if (scaled_pixel > maximum_scaled)
                    pixel <= maximum_scaled;
                else
                    pixel <= scaled_pixel[7:0];
            end
        end
    end
endmodule
