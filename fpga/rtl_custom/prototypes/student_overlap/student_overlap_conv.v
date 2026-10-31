`timescale 1ns / 1ps

 


module student_overlap_conv #(
    parameter WIDTH=16, HEIGHT=16, CHANNELS=16,
    parameter OUTPUT_CHANNELS=16, KERNEL=3,
    parameter LANES=8
) (
    input wire clk_i, rst_n_i,
    input wire start_valid_i, output wire start_ready_o,
    input wire signed [7:0] input_zero_i,
    input wire signed [31:0] output_zero_i,
    input wire signed [7:0] minimum_i, maximum_i,
    output wire parameter_valid_o, input wire parameter_ready_i,
    output wire [6:0] parameter_channel_o,
    input wire parameter_response_valid_i,
    output wire parameter_response_ready_o,
    input wire [255:0] bias_i, multiplier_i,
    input wire [47:0] right_shift_i,
    output wire memory_valid_o, input wire memory_ready_i,
    output wire [31:0] activation_address_o, weight_address_o,
    output wire padding_o,
    input wire memory_response_valid_i,
    output wire memory_response_ready_o,
    input wire signed [7:0] activation_i,
    input wire [63:0] weight_i,
    output wire result_valid_o, input wire result_ready_i,
    output wire [31:0] result_address_o,
    output wire signed [7:0] pixel_o,
    output wire done_o
);
     
    localparam GROUPS=OUTPUT_CHANNELS/LANES;
    localparam [3:0] IDLE=0, PARAMETER_REQUEST=1, PARAMETER_WAIT=2,
        DOT_START=3, MEMORY_REQUEST=4, QUANTIZE=6;
    reg [3:0] state, next_state;
    reg signed [7:0] input_zero, minimum, maximum;
    reg signed [31:0] output_zero;
    reg [255:0] biases, multipliers;
    reg [47:0] shifts;
    reg [6:0] group_channel;
    reg [2:0] result_lane, feed_lane;
    reg all_sent;
    wire quant_accept;
    reg [31:0] output_base, retire_address;
    reg final_group;
    reg response_pending, response_padding, response_last, group_issued;
    wire request_accept;
    wire walk_ready, walk_valid, walk_last, walk_done;
    wire [31:0] walk_output;
    wire [9:0] walk_term;
    wire [LANES-1:0] mac_start_ready, mac_term_ready, mac_valid;
    wire [LANES*32-1:0] accumulators;
    wire quant_ready, quant_valid, start_accept, memory_accept, result_accept;
    wire signed [7:0] term_activation;
    wire signed [31:0] selected_accumulator, selected_multiplier;
    wire [5:0] selected_shift;

    assign start_ready_o=rst_n_i && state==IDLE && walk_ready;
    assign start_accept=start_valid_i && start_ready_o;
    assign parameter_valid_o=rst_n_i && state==PARAMETER_REQUEST;
    assign parameter_channel_o=group_channel;
    assign parameter_response_ready_o=rst_n_i && state==PARAMETER_WAIT;
    assign memory_valid_o=rst_n_i && state==MEMORY_REQUEST && walk_valid
        && !group_issued && (!response_pending || memory_accept);
    assign request_accept=memory_valid_o && memory_ready_i;
    assign memory_response_ready_o=rst_n_i && state==MEMORY_REQUEST && response_pending && (&mac_term_ready);
    assign memory_accept=memory_response_valid_i && memory_response_ready_o;
    assign term_activation=response_padding ? input_zero : activation_i;
    assign result_valid_o=rst_n_i && state!=IDLE && quant_valid;
    assign result_accept=result_valid_o && result_ready_i;
    assign result_address_o=retire_address;
    assign done_o=result_accept && retire_address==WIDTH*HEIGHT*OUTPUT_CHANNELS-1;
    assign selected_accumulator=accumulators[feed_lane*32+:32];
    assign selected_multiplier=multipliers[feed_lane*32+:32];
    assign selected_shift=shifts[feed_lane*6+:6];
    assign quant_accept=rst_n_i && state==QUANTIZE && !all_sent && mac_valid[feed_lane] && quant_ready;

    student_conv_walk #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.CHANNELS(CHANNELS),
        .OUTPUT_CHANNELS(GROUPS),.KERNEL(KERNEL)) student_conv_walk_Inst_groups (
        .clk_i(clk_i),.rst_n_i(rst_n_i),.start_valid_i(start_accept),.start_ready_o(walk_ready),
        .term_valid_o(walk_valid),.term_ready_i(request_accept),.padding_o(padding_o),
        .activation_address_o(activation_address_o),.weight_address_o(weight_address_o),
        .output_address_o(walk_output),.cache_address_o(walk_term),
        .term_last_o(walk_last),.layer_last_o(walk_done)
    );
    genvar lane;
    generate for(lane=0;lane<LANES;lane=lane+1) begin: channel_mac
        student_serial_mac student_serial_mac_Inst_channel (
            .clk_i(clk_i),.rst_n_i(rst_n_i),
            .start_valid_i(rst_n_i && state==DOT_START && (&mac_start_ready)),
            .start_ready_o(mac_start_ready[lane]),.bias_i(biases[lane*32+:32]),
            .term_valid_i(memory_accept),.term_ready_o(mac_term_ready[lane]),
            .activation_i(term_activation),.input_zero_i(input_zero),
            .weight_i(weight_i[lane*8+:8]),.term_last_i(response_last),
            .result_valid_o(mac_valid[lane]),
            .result_ready_i(state==QUANTIZE && !all_sent && feed_lane==lane && quant_ready),
            .accumulator_o(accumulators[lane*32+:32])
        );
    end endgenerate
     
    student_requantize student_requantize_Inst_shared (
        .clk_i(clk_i),.rst_n_i(rst_n_i),
        .valid_i(rst_n_i && state==QUANTIZE && !all_sent && mac_valid[feed_lane]),.ready_o(quant_ready),
        .accumulator_i(selected_accumulator),.multiplier_i(selected_multiplier),
        .right_shift_i(selected_shift),.output_zero_i(output_zero),
        .minimum_i(minimum),.maximum_i(maximum),
        .valid_o(quant_valid),.ready_i(state!=IDLE && result_ready_i),.pixel_o(pixel_o)
    );
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) state<=IDLE;
        else state<=next_state;
    end
    always @(*) begin
        next_state=state;
        case(state)
            IDLE:if(start_accept)next_state=PARAMETER_REQUEST;
            PARAMETER_REQUEST:if(parameter_ready_i)next_state=PARAMETER_WAIT;
            PARAMETER_WAIT:if(parameter_response_valid_i)next_state=DOT_START;
            DOT_START:if(&mac_start_ready)next_state=MEMORY_REQUEST;
            MEMORY_REQUEST:if(memory_accept && response_last)next_state=QUANTIZE;
            QUANTIZE:begin
                if(done_o)next_state=IDLE;
                else if(quant_accept && feed_lane==LANES-1 && !final_group)next_state=PARAMETER_REQUEST;
            end
            default:next_state=IDLE;
        endcase
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)begin
            input_zero<=0;output_zero<=0;minimum<=-8'sd128;maximum<=8'sd127;
            biases<=0;multipliers<=0;shifts<=0;group_channel<=0;
            result_lane<=0;feed_lane<=0;all_sent<=0;output_base<=0;retire_address<=0;final_group<=0;
            response_pending<=0;response_padding<=0;response_last<=0;group_issued<=0;
        end else begin
            if(start_accept)begin
                input_zero<=input_zero_i;output_zero<=output_zero_i;
                minimum<=minimum_i;maximum<=maximum_i;group_channel<=0;retire_address<=0;
            end
            if(parameter_response_valid_i && parameter_response_ready_o)begin
                biases<=bias_i;multipliers<=multiplier_i;shifts<=right_shift_i;
            end
            if(state==DOT_START && (&mac_start_ready))group_issued<=0;
            if(memory_accept)response_pending<=0;
            if(request_accept)begin
                response_pending<=1;response_padding<=padding_o;response_last<=walk_last;
                if(walk_last)begin
                    group_issued<=1;output_base<=walk_output*LANES;
                    final_group<=walk_done;feed_lane<=0;all_sent<=0;
                end
            end
            if(quant_accept)begin
                if(feed_lane==LANES-1)begin
                    all_sent<=1;
                    group_channel<=group_channel==GROUPS-1 ? 7'd0 : group_channel+1'b1;
                end
                else feed_lane<=feed_lane+1'b1;
            end
            if(result_accept)retire_address<=retire_address+1'b1;
        end
    end
endmodule
