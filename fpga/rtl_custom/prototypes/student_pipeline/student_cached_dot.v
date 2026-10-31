`timescale 1ns / 1ps

 

module student_cached_dot (
    input wire clk_i,
    input wire rst_n_i,
    input wire load_valid_i,
    output wire load_ready_o,
    input wire [9:0] load_address_i,
    input wire load_activation_i,
    input wire load_weight_i,
    input wire signed [7:0] activation_i,
    input wire signed [7:0] weight_i,
    input wire job_valid_i,
    output wire job_ready_o,
    input wire [9:0] term_count_i,
    input wire signed [31:0] bias_i,
    input wire signed [7:0] input_zero_i,
    input wire signed [31:0] multiplier_i,
    input wire [5:0] right_shift_i,
    input wire signed [31:0] output_zero_i,
    input wire signed [7:0] minimum_i,
    input wire signed [7:0] maximum_i,
    output wire result_valid_o,
    input wire result_ready_i,
    output wire signed [7:0] pixel_o
);
    localparam [1:0] IDLE = 2'd0, FETCH = 2'd1, SEND = 2'd2, DRAIN = 2'd3;
    reg [1:0] state, next_state;
    reg signed [7:0] activation_memory [0:575];
    reg signed [7:0] weight_memory [0:575];
    reg signed [7:0] activation_read, weight_read;
    reg [9:0] term_index, term_count;
    reg signed [7:0] input_zero;
    reg signed [31:0] multiplier, output_zero;
    reg [5:0] right_shift;
    reg signed [7:0] minimum, maximum;
    wire count_legal, shift_legal, job_accept, load_accept, last_term;
    wire mac_start_ready, mac_term_ready, mac_valid, quant_ready;
    wire signed [31:0] accumulator;
    wire quant_valid;
    wire signed [7:0] quant_pixel;
    wire term_accept, result_accept;

    assign count_legal = (term_count_i != 0) && (term_count_i <= 10'd576);
    assign shift_legal = right_shift_i <= 6'd31;
    assign job_ready_o = rst_n_i && (state == IDLE) && mac_start_ready && count_legal && shift_legal;
    assign job_accept = job_valid_i && job_ready_o;
    assign load_ready_o = rst_n_i && (state == IDLE) && !job_valid_i && (load_address_i < 10'd576);
    assign load_accept = load_valid_i && load_ready_o;
    assign last_term = term_index == term_count - 1'b1;
    assign term_accept = (state == SEND) && mac_term_ready;
    assign result_valid_o = quant_valid;
    assign pixel_o = quant_pixel;
    assign result_accept = quant_valid && result_ready_i;

    student_serial_mac u_mac (
        .clk_i(clk_i), .rst_n_i(rst_n_i), .start_valid_i(job_accept), .start_ready_o(mac_start_ready),
        .bias_i(bias_i), .term_valid_i(state == SEND), .term_ready_o(mac_term_ready),
        .activation_i(activation_read), .input_zero_i(input_zero), .weight_i(weight_read),
        .term_last_i(last_term), .result_valid_o(mac_valid), .result_ready_i(quant_ready), .accumulator_o(accumulator)
    );
    student_requantize u_quant (
        .clk_i(clk_i), .rst_n_i(rst_n_i), .valid_i(mac_valid), .ready_o(quant_ready),
        .accumulator_i(accumulator), .multiplier_i(multiplier), .right_shift_i(right_shift),
        .output_zero_i(output_zero), .minimum_i(minimum), .maximum_i(maximum),
        .valid_o(quant_valid), .ready_i(result_ready_i), .pixel_o(quant_pixel)
    );

    wire cache_prefetch = (state == SEND) && term_accept && !last_term;
    wire cache_read_enable = (state == FETCH) || cache_prefetch;
    wire [9:0] cache_read_address = cache_prefetch ? term_index + 1'b1 : term_index;

     
    always @(posedge clk_i) begin
        if (load_accept && load_activation_i)
            activation_memory[load_address_i] <= activation_i;
        if (load_accept && load_weight_i)
            weight_memory[load_address_i] <= weight_i;
        if (cache_read_enable) begin
            activation_read <= activation_memory[cache_read_address];
            weight_read <= weight_memory[cache_read_address];
        end
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) state <= IDLE;
        else state <= next_state;
    end
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (job_accept) next_state = FETCH;
            FETCH: next_state = SEND;
            SEND: if (term_accept) next_state = last_term ? DRAIN : SEND;
            DRAIN: if (result_accept) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            term_index <= 10'd0;
            term_count <= 10'd0;
            input_zero <= 8'sd0;
            multiplier <= 32'sd0;
            right_shift <= 6'd0;
            output_zero <= 32'sd0;
            minimum <= -8'sd128;
            maximum <= 8'sd127;
        end else begin
            if (job_accept) begin
                term_index <= 10'd0;
                term_count <= term_count_i;
                input_zero <= input_zero_i;
                multiplier <= multiplier_i;
                right_shift <= right_shift_i;
                output_zero <= output_zero_i;
                minimum <= minimum_i;
                maximum <= maximum_i;
            end else if (term_accept && !last_term) begin
                term_index <= term_index + 1'b1;
            end
        end
    end
endmodule
