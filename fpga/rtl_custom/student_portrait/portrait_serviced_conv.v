`timescale 1ns / 1ps
 

module portrait_serviced_conv (
    input clk_i,
    input rst_n_i,
    input start_valid_i,
    output start_ready_o,
    input [3:0] layer_i,
    input [12:0] weight_base_i,
    input [7:0] width_i,
    input [7:0] height_i,
    input [5:0] channels_i,
    input [5:0] output_channels_i,
    input [1:0] kernel_i,
    input signed [7:0] input_zero_i,
    input signed [31:0] output_zero_i,
    input signed [7:0] minimum_i,
    input signed [7:0] maximum_i,
    output memory_valid_o,
    input memory_ready_i,
    output [31:0] activation_address_o,
    output padding_o,
    input memory_response_valid_i,
    output memory_response_ready_o,
    input signed [7:0] activation_i,
    output result_valid_o,
    input result_ready_i,
    output [31:0] result_address_o,
    output signed [7:0] pixel_o,
    output done_o,
    output error_o
);
    reg [3:0] reg_layer;
    reg [12:0] reg_weight_base;
    wire wire_start_ready;
    wire wire_parameter_valid, wire_parameter_ready;
    wire wire_parameter_response_valid, wire_parameter_response_ready;
    wire [6:0] wire_parameter_group;
    wire [255:0] wire_bias, wire_multiplier;
    wire [47:0] wire_shift;
    wire wire_parameter_error;
    wire wire_memory_valid, wire_memory_response_ready;
    wire [31:0] wire_activation_address, wire_weight_address;
    wire wire_padding;
    reg reg_pending, reg_activation_issued, reg_weight_issued;
    reg reg_activation_received, reg_weight_received;
    reg [31:0] reg_activation_address;
    reg [12:0] reg_weight_address;
    reg reg_padding;
    reg signed [7:0] reg_activation;
    reg [63:0] reg_weights;
    reg reg_error;
    wire wire_weight_ready, wire_weight_valid, wire_weight_error;
    wire [63:0] wire_weights;
    wire wire_response_valid;
    wire wire_memory_request_ready;
    wire [32:0] wire_absolute_weight;
    assign start_ready_o = wire_start_ready && layer_i < 12;
    assign wire_absolute_weight = {1'b0,wire_weight_address} + {20'd0,reg_weight_base};
    assign memory_valid_o = rst_n_i && reg_pending && !reg_activation_issued;
    assign activation_address_o = reg_activation_address;
    assign padding_o = reg_padding;
    assign memory_response_ready_o = rst_n_i && reg_pending && reg_activation_issued && !reg_activation_received;
    assign wire_response_valid = reg_pending && reg_activation_received && reg_weight_received;
    assign wire_memory_request_ready = !reg_pending || (wire_response_valid && wire_memory_response_ready);
    assign error_o = reg_error;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            reg_layer <= 0;
            reg_weight_base <= 0;
            reg_pending <= 0;
            reg_activation_issued <= 0;
            reg_weight_issued <= 0;
            reg_activation_received <= 0;
            reg_weight_received <= 0;
            reg_error <= 0;
        end else begin
            if (start_valid_i && start_ready_o) begin
                reg_layer <= layer_i;
                reg_weight_base <= weight_base_i;
                reg_error <= 0;
            end
            if (wire_parameter_response_valid && wire_parameter_response_ready && wire_parameter_error)
                reg_error <= 1;
            if (wire_response_valid && wire_memory_response_ready) reg_pending <= 0;
            if (wire_memory_valid && wire_memory_request_ready) begin
                reg_pending <= 1;
                reg_activation_issued <= 0;
                reg_weight_issued <= 0;
                reg_activation_received <= 0;
                reg_weight_received <= 0;
                if (wire_absolute_weight > 4101) reg_error <= 1;
            end
            if (memory_valid_o && memory_ready_i) reg_activation_issued <= 1;
            if (reg_pending && !reg_weight_issued && wire_weight_ready) reg_weight_issued <= 1;
            if (memory_response_valid_i && memory_response_ready_o) reg_activation_received <= 1;
            if (wire_weight_valid && reg_pending && reg_weight_issued && !reg_weight_received) begin
                reg_weight_received <= 1;
                if (wire_weight_error) reg_error <= 1;
            end
        end
    end
     
    always @(posedge clk_i) begin
        if (rst_n_i) begin
            if (wire_memory_valid && wire_memory_request_ready) begin
                reg_activation_address <= wire_activation_address;
                reg_weight_address <= wire_absolute_weight > 4101 ? 13'd8191 : wire_absolute_weight[12:0];
                reg_padding <= wire_padding;
            end
            if (memory_response_valid_i && memory_response_ready_o) reg_activation <= activation_i;
            if (wire_weight_valid && reg_pending && reg_weight_issued && !reg_weight_received) reg_weights <= wire_weights;
        end
    end

    portrait_parameter_service portrait_parameter_service_Inst_parameters (
        .i_clk(clk_i), .i_rstn(rst_n_i), .i_flush(1'b0),
        .i_request_valid(wire_parameter_valid), .o_request_ready(wire_parameter_ready),
        .i_layer(reg_layer), .i_group(wire_parameter_group),
        .o_response_valid(wire_parameter_response_valid), .i_response_ready(wire_parameter_response_ready),
        .o_bias(wire_bias), .o_multiplier(wire_multiplier), .o_shift(wire_shift), .o_error(wire_parameter_error)
    );
    portrait_weight_service portrait_weight_service_Inst_weights (
        .i_clk(clk_i), .i_rstn(rst_n_i), .i_flush(1'b0),
        .i_request_valid(reg_pending && !reg_weight_issued), .o_request_ready(wire_weight_ready),
        .i_address(reg_weight_address), .o_response_valid(wire_weight_valid),
        .i_response_ready(reg_pending && reg_weight_issued && !reg_weight_received),
        .o_weights(wire_weights), .o_error(wire_weight_error)
    );
    portrait_runtime_conv portrait_runtime_conv_Inst_executor (
        .width_i(width_i), .height_i(height_i), .channels_i(channels_i),
        .output_channels_i(output_channels_i), .kernel_i(kernel_i),
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_valid_i(start_valid_i && layer_i < 12), .start_ready_o(wire_start_ready),
        .input_zero_i(input_zero_i), .output_zero_i(output_zero_i), .minimum_i(minimum_i), .maximum_i(maximum_i),
        .parameter_valid_o(wire_parameter_valid), .parameter_ready_i(wire_parameter_ready),
        .parameter_channel_o(wire_parameter_group), .parameter_response_valid_i(wire_parameter_response_valid),
        .parameter_response_ready_o(wire_parameter_response_ready), .bias_i(wire_bias),
        .multiplier_i(wire_multiplier), .right_shift_i(wire_shift),
        .memory_valid_o(wire_memory_valid), .memory_ready_i(wire_memory_request_ready),
        .activation_address_o(wire_activation_address), .weight_address_o(wire_weight_address), .padding_o(wire_padding),
        .memory_response_valid_i(wire_response_valid), .memory_response_ready_o(wire_memory_response_ready),
        .activation_i(reg_activation), .weight_i(reg_weights),
        .result_valid_o(result_valid_o), .result_ready_i(result_ready_i),
        .result_address_o(result_address_o), .pixel_o(pixel_o), .done_o(done_o)
    );
endmodule
