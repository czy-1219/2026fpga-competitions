`timescale 1ns/1ps

 


module student_serial_mac (
    input wire clk_i,
    input wire rst_n_i,
    input wire start_valid_i,
    output wire start_ready_o,
    input wire signed [31:0] bias_i,
    input wire term_valid_i,
    output wire term_ready_o,
    input wire signed [7:0] activation_i,
    input wire signed [7:0] input_zero_i,
    input wire signed [7:0] weight_i,
    input wire term_last_i,
    output wire result_valid_o,
    input wire result_ready_i,
    output wire signed [31:0] accumulator_o
);
    reg active;
    reg product_pending;
    reg product_last;
    reg signed [16:0] product;
    reg signed [31:0] accumulator;
    reg result_valid;
    wire signed [8:0] centered_activation;
    wire signed [16:0] extended_product;
    wire signed [31:0] accumulated_product;

    assign centered_activation = {activation_i[7], activation_i}
                               - {input_zero_i[7], input_zero_i};
    assign extended_product = centered_activation * weight_i;
    assign accumulated_product = accumulator + product;
    assign start_ready_o = !active && !result_valid;
    assign term_ready_o = active && (!product_pending || !product_last);
    assign result_valid_o = result_valid;
    assign accumulator_o = accumulator;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            active <= 1'b0;
            product_pending <= 1'b0;
            product_last <= 1'b0;
            product <= 17'sd0;
            accumulator <= 32'sd0;
            result_valid <= 1'b0;
        end else begin
            if (result_valid && result_ready_i)
                result_valid <= 1'b0;
            if (start_valid_i && start_ready_o) begin
                active <= 1'b1;
                accumulator <= bias_i;
            end
            if (term_valid_i && term_ready_o) begin
                product <= extended_product;
                product_last <= term_last_i;
                product_pending <= 1'b1;
            end
            if (product_pending) begin
                accumulator <= accumulated_product;
                product_pending <= term_valid_i && term_ready_o;
                if (product_last) begin
                    active <= 1'b0;
                    result_valid <= 1'b1;
                end
            end
        end
    end
endmodule
