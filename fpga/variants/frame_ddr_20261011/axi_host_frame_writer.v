`timescale 1ns/1ps

 

module axi_host_frame_writer (
    input wire clk, input wire rst, input wire start_i,
    input wire [1:0] slot_i, input wire metadata_valid_i,
    input wire [11:0] frame_width_i, input wire [11:0] frame_height_i,
    input wire [21:0] payload_bytes_i,
    input wire packet_done_i, input wire packet_good_i,
    input wire receiver_error_i,
    input wire [127:0] fifo_data_i, input wire [9:0] fifo_word_count_i,
    output reg fifo_read_o,
    output reg [31:0] axi_awaddr_o, output wire [7:0] axi_awlen_o,
    output reg axi_awvalid_o, input wire axi_awready_i,
    output reg [127:0] axi_wdata_o, output wire [15:0] axi_wstrb_o,
    output wire axi_wlast_o, output reg axi_wvalid_o,
    input wire axi_wready_i, input wire axi_bvalid_i,
    input wire [1:0] axi_bresp_i,
    output reg active_o, output reg complete_pulse_o,
    output reg success_o, output reg axi_error_o,
    output wire auto_document_o
);
    reg decoder_reset;
    reg [1:0] slot;
    reg [11:0] expected_width, expected_height;
    reg [21:0] input_bytes, target_bytes;
    reg metadata_latched;

    reg [127:0] input_pack;
    reg input_pack_valid;
    reg [1:0] input_word_index;
    wire [31:0] decoder_word =
        (input_word_index == 0) ? {input_pack[103:96], input_pack[111:104], input_pack[119:112], input_pack[127:120]} :
        (input_word_index == 1) ? {input_pack[71:64], input_pack[79:72], input_pack[87:80], input_pack[95:88]} :
        (input_word_index == 2) ? {input_pack[39:32], input_pack[47:40], input_pack[55:48], input_pack[63:56]} :
                                  {input_pack[7:0], input_pack[15:8], input_pack[23:16], input_pack[31:24]};
    wire packet_rejected = packet_done_i && !packet_good_i;
    wire decoder_input_valid = active_o && input_pack_valid && !packet_rejected;
     



    wire decoder_input_last = 1'b0;
    wire decoder_input_accept;
    wire decoder_output_valid, decoder_idle, decoder_image_end;
    wire [15:0] decoder_width, decoder_height, decoder_x, decoder_y;
    wire [7:0] decoder_r, decoder_g, decoder_b;
    wire output_accept;

     
    jpeg_core #(.SUPPORT_WRITABLE_DHT(1)) u_jpeg_decoder (
        .clk_i(clk), .rst_i(rst || decoder_reset),
        .inport_valid_i(decoder_input_valid), .inport_data_i(decoder_word),
        .inport_strb_i(4'hF), .inport_last_i(decoder_input_last),
        .outport_accept_i(output_accept), .inport_accept_o(decoder_input_accept),
        .outport_valid_o(decoder_output_valid),
        .outport_width_o(decoder_width), .outport_height_o(decoder_height),
        .outport_pixel_x_o(decoder_x), .outport_pixel_y_o(decoder_y),
        .outport_pixel_r_o(decoder_r), .outport_pixel_g_o(decoder_g),
        .outport_pixel_b_o(decoder_b), .idle_o(decoder_idle),
        .image_end_o(decoder_image_end)
    );

    wire [15:0] decoded_rgb565 = {decoder_r[7:3], decoder_g[7:2], decoder_b[7:3]};
    reg [127:0] pixel_pack;
    reg pack_pending, response_pending, saw_pixel, dimension_error;
    reg [21:0] sample_count, white_count, dark_count;
    reg [19:0] stalled_cycles;
    wire dimensions_match = decoder_width == {4'd0, expected_width} &&
                            decoder_height == {4'd0, expected_height};
    wire pixel_in_frame = decoder_x < {4'd0, expected_width} &&
                          decoder_y < {4'd0, expected_height};
    wire [23:0] expected_pixels = expected_width * expected_height;
    wire sample_white = decoder_r >= 8'd200 && decoder_g >= 8'd200 && decoder_b >= 8'd200;
    wire sample_dark = decoder_r <= 8'd80 && decoder_g <= 8'd80 && decoder_b <= 8'd80;
    assign auto_document_o = sample_count != 0 &&
                             white_count > (sample_count >> 1) &&
                             dark_count > (sample_count >> 6);
    assign output_accept = active_o && !packet_rejected && !pack_pending && !response_pending &&
                           !axi_awvalid_o && !axi_wvalid_o;
    assign axi_awlen_o = 8'd0;
    assign axi_wstrb_o = 16'hFFFF;
    assign axi_wlast_o = 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            decoder_reset <= 1'b1; slot <= 0;
            expected_width <= 0; expected_height <= 0;
            input_bytes <= 0; target_bytes <= 0; metadata_latched <= 0;
            input_pack <= 0; input_pack_valid <= 0; input_word_index <= 0;
            pixel_pack <= 0; pack_pending <= 0; response_pending <= 0;
            saw_pixel <= 0; dimension_error <= 0;
            sample_count <= 0; white_count <= 0; dark_count <= 0;
            stalled_cycles <= 0;
            fifo_read_o <= 0; axi_awaddr_o <= 0; axi_awvalid_o <= 0;
            axi_wdata_o <= 0; axi_wvalid_o <= 0;
            active_o <= 0; complete_pulse_o <= 0; success_o <= 0;
            axi_error_o <= 0;
        end else begin
            fifo_read_o <= 1'b0;
            complete_pulse_o <= 1'b0;
            if (start_i && !active_o) begin
                decoder_reset <= 1'b0; slot <= slot_i;
                expected_width <= frame_width_i;
                expected_height <= frame_height_i;
                target_bytes <= payload_bytes_i;
                metadata_latched <= metadata_valid_i;
                input_bytes <= 0; input_pack_valid <= 0; input_word_index <= 0;
                pixel_pack <= 0; pack_pending <= 0; response_pending <= 0;
                saw_pixel <= 0; dimension_error <= 0;
                sample_count <= 0; white_count <= 0; dark_count <= 0;
                stalled_cycles <= 0;
                axi_awvalid_o <= 0; axi_wvalid_o <= 0;
                active_o <= 1'b1; success_o <= 0; axi_error_o <= 0;
            end else if (active_o) begin
                 


                if (!packet_done_i || (decoder_input_valid && decoder_input_accept) ||
                    (decoder_output_valid && output_accept) || axi_bvalid_i)
                    stalled_cycles <= 0;
                else if (!(&stalled_cycles)) stalled_cycles <= stalled_cycles + 1'b1;
                if (!metadata_latched && metadata_valid_i) begin
                    expected_width <= frame_width_i;
                    expected_height <= frame_height_i;
                    target_bytes <= payload_bytes_i;
                    metadata_latched <= 1'b1;
                end
                if (!input_pack_valid && fifo_word_count_i != 0 && input_bytes < target_bytes) begin
                    input_pack <= fifo_data_i;
                    input_pack_valid <= 1'b1;
                    input_word_index <= 0;
                    fifo_read_o <= 1'b1;
                end else if (decoder_input_valid && decoder_input_accept) begin
                    input_bytes <= input_bytes + 22'd4;
                    if (input_word_index == 3) begin
                        input_pack_valid <= 1'b0;
                        input_word_index <= 0;
                    end else input_word_index <= input_word_index + 1'b1;
                end

                if (decoder_output_valid && output_accept) begin
                    if (!dimensions_match) dimension_error <= 1'b1;
                     

                    if (dimensions_match && pixel_in_frame) begin
                        saw_pixel <= 1'b1;
                        sample_count <= sample_count + 1'b1;
                        if (sample_white) white_count <= white_count + 1'b1;
                        if (sample_dark) dark_count <= dark_count + 1'b1;
                        pixel_pack[decoder_x[2:0] * 16 +: 16] <= decoded_rgb565;
                        if (decoder_x[2:0] == 3'd7) begin
                            axi_wdata_o <= pixel_pack |
                                ({{112{1'b0}}, decoded_rgb565} << (decoder_x[2:0] * 16));
                            axi_awaddr_o <= {8'd0, slot, 22'd0} +
                                ((decoder_y * decoder_width + {decoder_x[15:3], 3'b000}) << 1);
                            axi_awvalid_o <= 1'b1;
                            axi_wvalid_o <= 1'b1;
                            pack_pending <= 1'b1;
                            pixel_pack <= 0;
                        end
                    end
                end

                if (axi_awvalid_o && axi_awready_i) axi_awvalid_o <= 1'b0;
                if (axi_wvalid_o && axi_wready_i) axi_wvalid_o <= 1'b0;
                if (pack_pending && (!axi_awvalid_o || axi_awready_i) &&
                    (!axi_wvalid_o || axi_wready_i)) begin
                    pack_pending <= 1'b0;
                    response_pending <= 1'b1;
                end
                if (response_pending && axi_bvalid_i) begin
                    response_pending <= 1'b0;
                    if (axi_bresp_i != 2'b00) axi_error_o <= 1'b1;
                end

                if (packet_done_i && (packet_rejected || (&stalled_cycles)) &&
                    !pack_pending && !response_pending && !axi_awvalid_o && !axi_wvalid_o) begin
                    decoder_reset <= 1'b1; active_o <= 1'b0;
                    complete_pulse_o <= 1'b1; success_o <= 1'b0;
                end else if (packet_done_i && packet_good_i && decoder_idle &&
                             input_bytes >= target_bytes &&
                             !input_pack_valid && !pack_pending && !response_pending &&
                             !axi_awvalid_o && !axi_wvalid_o) begin
                    decoder_reset <= 1'b1; active_o <= 1'b0;
                    complete_pulse_o <= 1'b1;
                    success_o <= metadata_latched && saw_pixel && !receiver_error_i &&
                                 !axi_error_o && !dimension_error && decoder_image_end &&
                                 {2'd0, sample_count} == expected_pixels;
                end
            end else decoder_reset <= 1'b1;
        end
    end
endmodule
