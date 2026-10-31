`timescale 1ns/1ps

`include "variants/cache_ring_20261007/scan_bw_local_mean.v"
`include "rtl_custom/processing/spatial_wb_rgb565.v"
`include "rtl_custom/processing/upload_color_enhance_rgb565.v"
`include "rtl_custom/processing/upload_window_rgb565.v"
`include "rtl_custom/processing/upload_neighborhood_rgb565.v"

 






module frame_stream_sender #(
    parameter integer WIDTH = 1024,
    parameter integer HEIGHT = 600,
    parameter integer PAYLOAD_BYTES = WIDTH * HEIGHT * 2,
    parameter integer EXTERNAL_BW = 0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start_i,
    input  wire [1:0] scan_mode_i,
    input  wire [1:0] frame_mode_i,
    input  wire [7:0] bw_margin_i,
    input  wire       bypass_spatial_i,
    input  wire [7:0] algorithm_flags_i,
    output reg        dump_start_o,
    input  wire       dump_busy_i,
    input  wire [7:0] dump_data_i,
    input  wire       dump_valid_i,
    output wire       dump_ready_o,
    input  wire       dump_done_i,
    input  wire       spi_sclk_i,
    input  wire       spi_cs_n_i,
    input  wire       stream_enable_i,
    output wire       spi_miso_o,
    output wire       claim_o,
    output wire       ready_o,
    output wire bw_frame_start_o,
    output wire bw_request_valid_o,
    output wire [15:0] bw_request_pixel_o,
    output wire bw_request_gray_enable_o,
    output wire [7:0] bw_request_gray_o,
    output wire [7:0] bw_request_offset_o,
    output wire bw_response_ready_o,
    input wire bw_request_ready_i,
    input wire bw_response_valid_i,
    input wire [15:0] bw_response_pixel_i
);
    localparam integer HEADER_BYTES = 16;
    localparam integer CRC_BYTES = 4;
    localparam integer TOTAL_BYTES = HEADER_BYTES + PAYLOAD_BYTES + CRC_BYTES;

    reg claim_reg;
    reg ready_reg;
    reg start_toggle;
    reg done_toggle_seen;
    reg [127:0] pack_data;
    reg [3:0] pack_count;
    reg [1:0] scan_mode;
    reg [1:0] frame_mode;
    reg [7:0] bw_margin;
    reg [2:0] pixel_phase;
    reg [7:0] pixel_low;
    reg [7:0] processed_high;
    reg [15:0] bw_processed_pixel;
     
    reg [15:0] upload_gray_pixel;
    reg [7:0] background;
    reg [10:0] pixel_x;
    reg [10:0] pixel_y;
    reg reverse_output_words;
    reg [7:0] algorithm_flags;
    reg host_input_high, host_output_high;
    reg [7:0] host_processed_high;

    wire fifo_full;
    wire fifo_empty;
    wire fifo_rst_busy;
    wire fifo_rd_valid;
    wire [15:0] fifo_rdata;
    wire [127:0] fifo_wdata;
    wire fifo_wr_en;
    reg fifo_rd_en;
    reg fifo_empty_sys1;
    reg fifo_empty_sys2;
    reg done_toggle_sys1;
    reg done_toggle_sys2;
    reg done_toggle_spi;
    reg consume_toggle_spi;
    wire fifo_arst = (!rst_n) | start_i;

    function [127:0] set_pack_byte;
        input [127:0] old_data;
        input [3:0] index;
        input [7:0] value;
        begin
            set_pack_byte = old_data;
            case (index)
                4'd0:  set_pack_byte[7:0]     = value;
                4'd1:  set_pack_byte[15:8]    = value;
                4'd2:  set_pack_byte[23:16]   = value;
                4'd3:  set_pack_byte[31:24]   = value;
                4'd4:  set_pack_byte[39:32]   = value;
                4'd5:  set_pack_byte[47:40]   = value;
                4'd6:  set_pack_byte[55:48]   = value;
                4'd7:  set_pack_byte[63:56]   = value;
                4'd8:  set_pack_byte[71:64]   = value;
                4'd9:  set_pack_byte[79:72]   = value;
                4'd10: set_pack_byte[87:80]   = value;
                4'd11: set_pack_byte[95:88]   = value;
                4'd12: set_pack_byte[103:96]  = value;
                4'd13: set_pack_byte[111:104] = value;
                4'd14: set_pack_byte[119:112] = value;
                4'd15: set_pack_byte[127:120] = value;
            endcase
        end
    endfunction

    function [127:0] reverse_words_16x8;
        input [127:0] value;
        integer word_index;
        begin
            for (word_index = 0; word_index < 8; word_index = word_index + 1)
                reverse_words_16x8[word_index * 16 +: 16] =
                    value[(7 - word_index) * 16 +: 16];
        end
    endfunction

    wire pack_space = !fifo_rst_busy && ((!fifo_full) || (pack_count != 4'd15));
    wire [15:0] input_pixel = {dump_data_i, pixel_low};
    wire [15:0] spatial_pixel;
     

    wire [15:0] processing_pixel = input_pixel;
    spatial_wb_rgb565 #(.WIDTH(WIDTH), .HEIGHT(HEIGHT), .ENABLE(1)) u_spatial_wb_rgb565 (
        .pixel_x_i(pixel_x), .pixel_y_i(pixel_y), .pixel_i(input_pixel), .pixel_o(spatial_pixel)
    );
    wire [15:0] legacy_processed_pixel;
    wire [15:0] upload_color_pixel;
    wire upload_color_mode = (scan_mode == 2'd2);
    wire [15:0] processed_pixel = upload_color_mode
                                      ? upload_color_pixel
                                      : legacy_processed_pixel;
    wire [7:0] pixel_luminance;
    wire bw_pixel_ready;
    wire bw_pixel_valid;
    wire [15:0] bw_pixel_result;
    scan_rgb565_pixel u_scan_rgb565_pixel (
        .pixel_i(processing_pixel),
        .background_i(background),
        .ink_margin_i(bw_margin),
        .mode_i(scan_mode),
        .pixel_o(legacy_processed_pixel),
        .luminance_o(pixel_luminance)
    );

    upload_color_enhance_rgb565 u_upload_color_enhance_rgb565 (
        .pixel_i(input_pixel),
        .pixel_o(upload_color_pixel)
    );

     

    wire host_filter_mode =
        (((frame_mode == 2'd2) && algorithm_flags[3]) ||
         ((frame_mode == 2'd3) && (algorithm_flags[1] || algorithm_flags[2])));
    wire host_window_ready, host_window_valid, host_neighborhood_ready;
    wire [143:0] host_window;
    wire host_filter_valid, host_filter_ready;
    wire [15:0] host_filter_pixel;
    wire [7:0] host_filter_luma;
    wire host_text_mode = host_filter_mode && (frame_mode == 2'd2);
    wire host_low_accept = claim_reg && host_filter_mode && !host_input_high && dump_valid_i && host_window_ready;
    wire host_high_accept = claim_reg && host_filter_mode && host_input_high && dump_valid_i && host_window_ready;
    wire host_result_valid = host_text_mode ? bw_pixel_valid : host_filter_valid;
    wire [15:0] host_result_pixel = host_text_mode ? bw_pixel_result : host_filter_pixel;
    wire host_output_low_accept = claim_reg && host_filter_mode && !host_output_high && host_result_valid && pack_space;
    wire host_output_high_emit = claim_reg && host_filter_mode && host_output_high && pack_space;
    assign host_filter_ready = host_text_mode ? bw_pixel_ready : host_output_low_accept;
    wire [15:0] upload_gray_tone_pixel;
    upload_gray_scan_rgb565 u_upload_gray_tone(.pixel_i(input_pixel), .pixel_o(upload_gray_tone_pixel));
    upload_window_rgb565 #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)) u_upload_window (
        .clk(clk), .rst_n(rst_n), .frame_start_i(start_i && !claim_reg),
        .pixel_i(input_pixel), .pixel_valid_i(host_high_accept), .pixel_ready_o(host_window_ready),
        .window_o(host_window), .window_valid_o(host_window_valid), .window_ready_i(host_neighborhood_ready));
    upload_neighborhood_rgb565 u_upload_neighborhood (
        .clk(clk), .rst_n(rst_n), .frame_start_i(start_i && !claim_reg),
        .window_i(host_window), .window_valid_i(host_window_valid), .window_ready_o(host_neighborhood_ready),
        .color_mode_i(frame_mode == 2'd3), .smooth_chroma_i(algorithm_flags[1]), .scan_color_i(algorithm_flags[2]),
        .pixel_o(host_filter_pixel), .luma_o(host_filter_luma),
        .pixel_valid_o(host_filter_valid), .pixel_ready_i(host_filter_ready));

    wire bw_mode = scan_mode == 2'd1;
    wire raw_accept = !host_filter_mode && claim_reg && (scan_mode == 2'd0) && dump_valid_i && pack_space;
    wire low_accept = !host_filter_mode && claim_reg && (scan_mode != 2'd0) &&
                      (pixel_phase == 3'd0) && dump_valid_i && pack_space;
    wire high_accept = !host_filter_mode && claim_reg && (scan_mode != 2'd0) &&
                       (pixel_phase == 3'd1) && dump_valid_i && pack_space &&
                       (!bw_mode || bw_pixel_ready);
    wire bw_take_output = !host_filter_mode && claim_reg && bw_mode && (pixel_phase == 3'd2) &&
                          bw_pixel_valid && pack_space;
    wire bw_emit_low = !host_filter_mode && claim_reg && bw_mode && (pixel_phase == 3'd3) && pack_space;
    wire bw_emit_high = !host_filter_mode && claim_reg && bw_mode && (pixel_phase == 3'd4) && pack_space;
    wire high_emit = !host_filter_mode && claim_reg && (scan_mode != 2'd0) && !bw_mode &&
                     (pixel_phase == 3'd2) && pack_space;
    wire [7:0] legacy_payload_byte = raw_accept ? dump_data_i :
                                     high_accept ? processed_pixel[7:0] : processed_high;
    wire [7:0] bw_payload_byte = bw_emit_low ? bw_processed_pixel[7:0]
                                              : bw_processed_pixel[15:8];
    wire payload_accept = host_output_low_accept || host_output_high_emit || raw_accept || (high_accept && !bw_mode) || high_emit ||
                          bw_emit_low || bw_emit_high;
    wire [7:0] payload_byte = host_output_low_accept ? host_result_pixel[7:0] :
                                  host_output_high_emit ? host_processed_high : (bw_emit_low || bw_emit_high)
                                  ? bw_payload_byte : legacy_payload_byte;

    assign dump_ready_o = host_filter_mode ? (claim_reg && host_window_ready) : claim_reg && pack_space &&
                          ((scan_mode == 2'd0) ||
                           (pixel_phase == 3'd0) ||
                           ((pixel_phase == 3'd1) && (!bw_mode || bw_pixel_ready)));

    assign bw_frame_start_o = start_i && !claim_reg;
    assign bw_request_valid_o = host_text_mode ? host_filter_valid : (high_accept && bw_mode);
    assign bw_request_pixel_o = host_text_mode ? host_filter_pixel : processing_pixel;
    assign bw_request_gray_enable_o = host_text_mode;
    assign bw_request_gray_o = host_filter_luma;
    assign bw_request_offset_o = (bw_margin == 8'd12) ? 8'd4 : 8'd8;
    assign bw_response_ready_o = host_text_mode ? host_output_low_accept : bw_take_output;
    generate
        if (EXTERNAL_BW != 0) begin : shared_bw
            assign bw_pixel_ready = bw_request_ready_i;
            assign bw_pixel_valid = bw_response_valid_i;
            assign bw_pixel_result = bw_response_pixel_i;
        end else begin : private_bw
    scan_bw_local_mean #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .WINDOW(51)
    ) u_scan_bw_local_mean (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start_i(start_i && !claim_reg),
        .pixel_valid_i(host_text_mode ? host_filter_valid : (high_accept && bw_mode)),
        .pixel_ready_o(bw_pixel_ready),
        .pixel_i(host_text_mode ? host_filter_pixel : processing_pixel),
        .gray_override_enable_i(host_text_mode),
        .gray_override_i(host_filter_luma),
        .offset_i((bw_margin == 8'd12) ? 8'd4 : 8'd8),
        .pixel_valid_o(bw_pixel_valid),
        .pixel_ready_i(host_text_mode ? host_output_low_accept : bw_take_output),
        .pixel_o(bw_pixel_result)
    );

        end
    endgenerate

     





    wire [127:0] completed_pack =
        set_pack_byte(pack_data, pack_count, payload_byte);
     



    assign fifo_wdata = reverse_output_words
                            ? reverse_words_16x8(completed_pack)
                            : completed_pack;
    assign fifo_wr_en = payload_accept && (pack_count == 4'd15);
    assign claim_o = claim_reg;
    assign ready_o = ready_reg;

     

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            claim_reg <= 1'b0;
            ready_reg <= 1'b0;
            start_toggle <= 1'b0;
            dump_start_o <= 1'b0;
            pack_data <= 128'b0;
            pack_count <= 4'd0;
            done_toggle_seen <= 1'b0;
            scan_mode <= 2'd0;
            frame_mode <= 2'd0;
            bw_margin <= 8'd24;
            pixel_phase <= 3'd0;
            pixel_low <= 8'd0;
            processed_high <= 8'd0;
            bw_processed_pixel <= 16'hFFFF;
            upload_gray_pixel <= 16'h0000;
            background <= 8'd224;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
            reverse_output_words <= 1'b0;
            algorithm_flags <= 8'd0;
            host_input_high <= 1'b0; host_output_high <= 1'b0; host_processed_high <= 8'd0;
        end else begin
            dump_start_o <= 1'b0;

            if (start_i && !claim_reg) begin
                claim_reg <= 1'b1;
                ready_reg <= 1'b0;
                start_toggle <= ~start_toggle;
                dump_start_o <= 1'b1;
                pack_data <= 128'b0;
                pack_count <= 4'd0;
                scan_mode <= scan_mode_i;
                frame_mode <= frame_mode_i;
                bw_margin <= bw_margin_i;
                pixel_phase <= 3'd0;
                background <= 8'd224;
                pixel_x <= 10'd0;
                pixel_y <= 10'd0;
                reverse_output_words <= bypass_spatial_i;
                algorithm_flags <= algorithm_flags_i;
                host_input_high <= 1'b0; host_output_high <= 1'b0;
            end

            if (host_low_accept) begin
                pixel_low <= dump_data_i;
                host_input_high <= 1'b1;
            end else if (host_high_accept) host_input_high <= 1'b0;
            if (host_output_low_accept) begin
                host_processed_high <= host_result_pixel[15:8];
                host_output_high <= 1'b1;
            end else if (host_output_high_emit) host_output_high <= 1'b0;

            if (low_accept) begin
                pixel_low <= dump_data_i;
                pixel_phase <= 3'd1;
            end else if (high_accept) begin
                upload_gray_pixel <= algorithm_flags[0] ? upload_gray_tone_pixel : {pixel_luminance[7:3],
                                      pixel_luminance[7:2],
                                      pixel_luminance[7:3]};
                pixel_phase <= 3'd2;
                if (pixel_x == WIDTH-1) begin
                    pixel_x <= 10'd0;
                    if (pixel_y != HEIGHT-1) pixel_y <= pixel_y + 1'b1;
                end else begin
                    pixel_x <= pixel_x + 1'b1;
                end
                if (!bw_mode) begin
                    processed_high <= processed_pixel[15:8];
                    if (pixel_luminance >= background)
                        background <= background + ((pixel_luminance - background) >> 4);
                    else
                        background <= background - ((background - pixel_luminance) >> 4);
                end
            end else if (bw_take_output) begin
                 

                bw_processed_pixel <= (frame_mode == 2'd1)
                                      ? upload_gray_pixel : bw_pixel_result;
                pixel_phase <= 3'd3;
            end else if (bw_emit_low) begin
                pixel_phase <= 3'd4;
            end else if (bw_emit_high || high_emit) begin
                pixel_phase <= 3'd0;
            end

            if (payload_accept) begin
                pack_data <= set_pack_byte(pack_data, pack_count, payload_byte);
                if (pack_count == 4'd15) begin
                    pack_count <= 4'd0;
                    pack_data <= 128'b0;
                end else begin
                    pack_count <= pack_count + 1'b1;
                end
            end

             

            if (claim_reg && !ready_reg && !fifo_rst_busy && !fifo_empty_sys2)
                ready_reg <= 1'b1;

            if (done_toggle_sys2 != done_toggle_seen) begin
                done_toggle_seen <= done_toggle_sys2;
                claim_reg <= 1'b0;
                ready_reg <= 1'b0;
            end
        end
    end

     

    R0_FIFO_16 u_stream_fifo (
        .almost_full_o(),
        .prog_full_o(),
        .full_o(fifo_full),
        .wr_ack_o(),
        .empty_o(fifo_empty),
        .almost_empty_o(),
        .rd_valid_o(fifo_rd_valid),
        .wr_clk_i(clk),
        .rd_clk_i(spi_sclk_i),
        .wr_en_i(fifo_wr_en),
        .rd_en_i(fifo_rd_en),
        .wdata(fifo_wdata),
        .rst_busy(fifo_rst_busy),
        .rdata(fifo_rdata),
        .a_rst_i(fifo_arst),
        .wr_datacount_o(),
        .rd_datacount_o(),
        .underflow_o(),
        .overflow_o()
    );

     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_empty_sys1 <= 1'b1;
            fifo_empty_sys2 <= 1'b1;
            done_toggle_sys1 <= 1'b0;
            done_toggle_sys2 <= 1'b0;
        end else begin
            fifo_empty_sys1 <= fifo_empty;
            fifo_empty_sys2 <= fifo_empty_sys1;
            done_toggle_sys1 <= done_toggle_spi;
            done_toggle_sys2 <= done_toggle_sys1;
        end
    end

     


    reg [15:0] word0, word1;
    reg word0_valid, word1_valid;
    reg start_spi1, start_spi2, start_spi_seen;
    reg consume_spi1, consume_spi2, consume_spi_seen;
    always @(posedge spi_sclk_i or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_en <= 1'b0;
            word0 <= 16'b0;
            word1 <= 16'b0;
            word0_valid <= 1'b0;
            word1_valid <= 1'b0;
            start_spi1 <= 1'b0;
            start_spi2 <= 1'b0;
            start_spi_seen <= 1'b0;
            consume_spi1 <= 1'b0;
            consume_spi2 <= 1'b0;
            consume_spi_seen <= 1'b0;
        end else begin
            fifo_rd_en <= 1'b0;
            start_spi1 <= start_toggle;
            start_spi2 <= start_spi1;
            consume_spi1 <= consume_toggle_spi;
            consume_spi2 <= consume_spi1;

            if (start_spi2 != start_spi_seen) begin
                start_spi_seen <= start_spi2;
                word0_valid <= 1'b0;
                word1_valid <= 1'b0;
            end else if (consume_spi2 != consume_spi_seen) begin
                consume_spi_seen <= consume_spi2;
                word0 <= word1;
                word0_valid <= word1_valid;
                word1_valid <= 1'b0;
            end

            if (!word0_valid && !fifo_empty) begin
                word0 <= fifo_rdata;
                word0_valid <= 1'b1;
                fifo_rd_en <= 1'b1;
            end else if (word0_valid && !word1_valid && !fifo_empty) begin
                word1 <= fifo_rdata;
                word1_valid <= 1'b1;
                fifo_rd_en <= 1'b1;
            end
        end
    end

    function [7:0] header_byte;
        input [4:0] index;
        begin
            case (index)
                5'd0:  header_byte = 8'h46;  
                5'd1:  header_byte = 8'h50;  
                5'd2:  header_byte = 8'h49;  
                5'd3:  header_byte = 8'h43;  
                5'd4:  header_byte = 8'h01;
                5'd5:  header_byte = 8'h01;  
                5'd6:  header_byte = WIDTH[7:0];
                5'd7:  header_byte = WIDTH[15:8];
                5'd8:  header_byte = HEIGHT[7:0];
                5'd9:  header_byte = HEIGHT[15:8];
                5'd10: header_byte = PAYLOAD_BYTES[7:0];
                5'd11: header_byte = PAYLOAD_BYTES[15:8];
                5'd12: header_byte = PAYLOAD_BYTES[23:16];
                5'd13: header_byte = PAYLOAD_BYTES[31:24];
                 


                5'd14: header_byte = {6'd0, frame_mode};
                default: header_byte = 8'h00;
            endcase
        end
    endfunction

    wire [7:0] header0 = header_byte(5'd0);

    function [31:0] crc32_next;
        input [31:0] crc_in;
        input [7:0] data;
        integer i;
        reg [31:0] c;
        begin
            c = crc_in ^ data;
            for (i = 0; i < 8; i = i + 1)
                c = c[0] ? ((c >> 1) ^ 32'hEDB88320) : (c >> 1);
            crc32_next = c;
        end
    endfunction

    reg [31:0] stream_index;
    reg [2:0] spi_bit_count;
    reg [7:0] current_byte;
    reg [7:0] tx_shift;
    reg [31:0] crc_state;
    reg start_neg_seen;

    wire [31:0] payload_index = stream_index - HEADER_BYTES;
    wire [31:0] crc_after_current = crc32_next(crc_state, current_byte);

    function [7:0] byte_for_index;
        input [31:0] index;
        reg [31:0] p;
        begin
            if (index < HEADER_BYTES)
                byte_for_index = header_byte(index[4:0]);
            else if (index < HEADER_BYTES + PAYLOAD_BYTES) begin
                p = index - HEADER_BYTES;
                if (p[0])
                    byte_for_index = word0[15:8];
                else if ((stream_index >= HEADER_BYTES) && payload_index[0])
                    byte_for_index = word1[7:0];
                else
                    byte_for_index = word0[7:0];
            end else begin
                case (index - HEADER_BYTES - PAYLOAD_BYTES)
                    0: byte_for_index = ~crc_state[7:0];
                    1: byte_for_index = ~crc_state[15:8];
                    2: byte_for_index = ~crc_state[23:16];
                    default: byte_for_index = ~crc_state[31:24];
                endcase
            end
        end
    endfunction

     


    always @(negedge spi_sclk_i or negedge rst_n) begin
        if (!rst_n) begin
            stream_index <= 0;
            spi_bit_count <= 0;
            current_byte <= 0;
            tx_shift <= 0;
            crc_state <= 32'hFFFFFFFF;
            done_toggle_spi <= 1'b0;
            consume_toggle_spi <= 1'b0;
            start_neg_seen <= 1'b0;
        end else begin
             







            if (start_toggle != start_neg_seen && stream_enable_i) begin
                start_neg_seen <= start_toggle;
                stream_index <= 0;
                spi_bit_count <= 1;
                current_byte <= header0;
                tx_shift <= {header0[6:0], 1'b0};
                crc_state <= 32'hFFFFFFFF;
            end else if (!spi_cs_n_i && ready_reg && stream_enable_i) begin
                if (spi_bit_count == 3'd0) begin
                    tx_shift <= {current_byte[6:0], 1'b0};
                    spi_bit_count <= 3'd1;
                end else if (spi_bit_count == 3'd7) begin
                    if ((stream_index >= HEADER_BYTES) &&
                        (stream_index < HEADER_BYTES + PAYLOAD_BYTES)) begin
                        crc_state <= crc_after_current;
                        if (payload_index[0])
                            consume_toggle_spi <= ~consume_toggle_spi;
                    end

                    if (stream_index == TOTAL_BYTES - 1) begin
                        done_toggle_spi <= ~done_toggle_spi;
                        stream_index <= 0;
                        spi_bit_count <= 0;
                        current_byte <= 0;
                        tx_shift <= 0;
                    end else begin
                        stream_index <= stream_index + 1'b1;
                        spi_bit_count <= 0;
                        if (stream_index == HEADER_BYTES + PAYLOAD_BYTES - 1)
                            current_byte <= ~crc_after_current[7:0];
                        else
                            current_byte <= byte_for_index(stream_index + 1'b1);
                        tx_shift <= 0;
                    end
                end else begin
                    tx_shift <= {tx_shift[6:0], 1'b0};
                    spi_bit_count <= spi_bit_count + 1'b1;
                end
            end
        end
    end

     


    wire first_bit_pending = (start_toggle != start_neg_seen);
    assign spi_miso_o = (ready_reg && !spi_cs_n_i) ?
                        ((spi_bit_count == 3'd0) ?
                         (first_bit_pending ? header0[7] : current_byte[7]) :
                         tx_shift[7]) :
                        1'b0;
endmodule

