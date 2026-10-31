`timescale 1ns/1ps

module jpeg_stream_transport #(
    parameter [31:0] JPEG_BASE = 32'h0240_0000
) (
    input  wire         clk,
    input  wire         jpeg_fast_clk,
    input  wire         rst_n,
    input  wire         start_i,
    input  wire [11:0]  frame_width_i,
    input  wire [11:0]  frame_height_i,
    input  wire [21:0]  frame_payload_bytes_i,
    input  wire [1:0]   scan_mode_i,
    input  wire [1:0]   frame_mode_i,
    input  wire         host_source_i,
    input wire raw_output_i,
    input  wire [7:0]   bw_margin_i,

    output reg          dump_start_o,
    output reg          dump_direct_o,
    output reg  [31:0]  dump_base_o,
    output reg  [31:0]  dump_size_o,
    input  wire         dump_busy_i,
    input  wire [7:0]   dump_data_i,
    input  wire         dump_valid_i,
    output wire         dump_ready_o,
    input  wire         dump_done_i,

    output reg  [31:0]  axi_awaddr_o,
    output wire [7:0]   axi_awlen_o,
    output reg          axi_awvalid_o,
    input  wire         axi_awready_i,
    output reg  [127:0] axi_wdata_o,
    output wire [15:0]  axi_wstrb_o,
    output wire         axi_wlast_o,
    output reg          axi_wvalid_o,
    input  wire         axi_wready_i,
    input  wire         axi_bvalid_i,
    input  wire [1:0]   axi_bresp_i,
    output reg          axi_active_o,
    output reg          axi_error_o,

    input  wire         spi_sclk_i,
    input  wire         spi_cs_n_i,
    input  wire         stream_enable_i,
    output wire         spi_miso_o,
    output wire         claim_o,
    output wire         ready_o,
    output reg  [21:0]  jpeg_size_o,
    output wire [7:0]   diag_status_o
);
    localparam integer HEADER_BYTES = 16;
    localparam integer JPEG_HEADER_BYTES = 623;
    localparam integer CRC_BYTES = 4;

    reg claim_reg;
    reg ready_reg;
    reg [11:0] frame_width;
    reg [11:0] frame_height;
    reg [1:0] scan_mode;
    reg [1:0] frame_mode;
    reg host_source;reg raw_output;
    reg [7:0] bw_margin;

    reg encoder_start;
    reg raw_dump_started;
    reg raw_dump_done;
    reg jpeg_dump_started;
    reg byte_phase;
    reg [7:0] pixel_low;
    reg [15:0] raw_pixel;
    reg raw_pixel_valid;
    reg frame_active;
    reg [11:0] pixel_x;
    reg [11:0] pixel_y;
    reg [7:0] background;
    reg [15:0] previous_pixel;
    reg previous_valid;
    reg [7:0] pixel_luminance_q;
    (* keep = "true" *) reg [9:0] encoder_red_q;
    (* keep = "true" *) reg [9:0] encoder_green_q;
    (* keep = "true" *) reg [9:0] encoder_blue_q;
    reg encoder_pixel_valid_q;
    reg encoder_frame_valid_q;
    reg encoder_line_valid_q;
     


    reg [8:0] line_blank_count;

    wire [15:0] processed_pixel = raw_pixel;
    wire [7:0] pixel_luminance = 8'd0;
    reg [21:0] accepted_pixels;
    reg [21:0] padded_pixels;
    wire encoder_pixel_ready;
    wire [31:0] encoder_data;
    wire [19:0] encoder_address;
    wire encoder_image_valid;
    wire encoder_data_valid;
    wire encoder_data_last;
    wire encoder_data_ready;
    wire encoder_pixel_take = encoder_pixel_valid_q && encoder_pixel_ready;

    jpeg_encoder #(
        .SENSOR_X_SIZE(1920), .SENSOR_Y_SIZE(1920), .MCU_INPUT(1)
    ) u_encoder (
        .start_capture_in(encoder_start),
        .red_data_in(encoder_red_q),
        .green_data_in(encoder_green_q),
        .blue_data_in(encoder_blue_q),
        .frame_valid_in(encoder_frame_valid_q),
        .line_valid_in(encoder_line_valid_q),
        .pixel_valid_in(encoder_pixel_valid_q),
        .pixel_ready_out(encoder_pixel_ready),
        .data_out(encoder_data), .address_out(encoder_address),
        .image_valid_out(encoder_image_valid),
        .data_valid_out(encoder_data_valid),
        .data_last_out(encoder_data_last),
        .data_ready_in(encoder_data_ready),
        .qf_select_in(3'd0),
        .x_size_in(frame_width[10:0]), .y_size_in(frame_height[10:0]),
        .pixel_clock_in(clk), .pixel_reset_n_in(rst_n),
        .jpeg_fast_clock_in(jpeg_fast_clk), .jpeg_fast_reset_n_in(rst_n),
        .jpeg_slow_clock_in(clk), .jpeg_slow_reset_n_in(rst_n)
    );

    wire raw_byte_ready = claim_reg && raw_dump_started && !raw_dump_done &&
                          line_blank_count == 0 &&
                          !raw_pixel_valid && !encoder_pixel_valid_q;
    assign dump_ready_o = jpeg_dump_started ? !fifo_full : raw_byte_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            claim_reg <= 1'b0;
            accepted_pixels <= 0; padded_pixels <= 0;
            frame_width <= 12'd0;
            frame_height <= 12'd0;
            scan_mode <= 2'd0;
            frame_mode <= 2'd0;
            host_source <= 1'b0;raw_output <= 1'b0;
            bw_margin <= 8'd24;
            encoder_start <= 1'b0;
            dump_start_o <= 1'b0;
            dump_direct_o <= 1'b0;
            dump_base_o <= 32'd0;
            dump_size_o <= 32'd0;
            raw_dump_started <= 1'b0;
            raw_dump_done <= 1'b0;
            jpeg_dump_started <= 1'b0;
            byte_phase <= 1'b0;
            pixel_low <= 8'd0;
            raw_pixel <= 16'd0;
            raw_pixel_valid <= 1'b0;
            frame_active <= 1'b0;
            pixel_x <= 12'd0;
            pixel_y <= 12'd0;
            background <= 8'd224;
            previous_pixel <= 16'd0;
            previous_valid <= 1'b0;
            pixel_luminance_q <= 8'd0;
            encoder_red_q <= 10'd0;
            encoder_green_q <= 10'd0;
            encoder_blue_q <= 10'd0;
            encoder_pixel_valid_q <= 1'b0;
            encoder_frame_valid_q <= 1'b0;
            encoder_line_valid_q <= 1'b0;
            line_blank_count <= 9'd0;
        end else begin
            encoder_start <= 1'b0;
            dump_start_o <= 1'b0;
             



            if (line_blank_count != 0 && encoder_pixel_ready)
                line_blank_count <= line_blank_count - 1'b1;
             

            encoder_frame_valid_q <= frame_active;

            if (start_i && !claim_reg) begin
                claim_reg <= 1'b1;
                accepted_pixels <= 0; padded_pixels <= frame_payload_bytes_i >> 1;
                frame_width <= frame_width_i;
                frame_height <= frame_height_i;
                scan_mode <= scan_mode_i;
                frame_mode <= frame_mode_i;
                host_source <= host_source_i;
                bw_margin <= bw_margin_i;
                raw_output <= raw_output_i;
                encoder_start <= !raw_output_i;
                raw_dump_started <= !raw_output_i;
                raw_dump_done <= raw_output_i;
                jpeg_dump_started <= raw_output_i;
                dump_direct_o <= raw_output_i;
                dump_base_o <= raw_output_i ? 32'h02800000 : 32'd0;
                dump_size_o <= {10'd0, frame_payload_bytes_i};
                dump_start_o <= 1'b1;
                byte_phase <= 1'b0;
                raw_pixel_valid <= 1'b0;
                frame_active <= 1'b0;
                pixel_x <= 12'd0;
                pixel_y <= 12'd0;
                background <= 8'd224;
                previous_pixel <= 16'd0;
                previous_valid <= 1'b0;
                encoder_line_valid_q <= 1'b0;
                line_blank_count <= 9'd0;
            end

            if (dump_valid_i && dump_ready_o && !jpeg_dump_started) begin
                if (!byte_phase) begin
                    pixel_low <= dump_data_i;
                    byte_phase <= 1'b1;
                end else begin
                    raw_pixel <= {dump_data_i, pixel_low};
                    raw_pixel_valid <= 1'b1;
                    byte_phase <= 1'b0;
                    frame_active <= 1'b1;
                end
            end

            if (raw_pixel_valid && !encoder_pixel_valid_q) begin
                    raw_pixel_valid <= 1'b0;
                    pixel_luminance_q <= pixel_luminance;
                     



                    encoder_red_q <= {processed_pixel[15:11], processed_pixel[15:11]};
                    encoder_green_q <= {processed_pixel[10:5], processed_pixel[10:7]};
                    encoder_blue_q <= {processed_pixel[4:0], processed_pixel[4:0]};
                    encoder_pixel_valid_q <= 1'b1;
                    encoder_frame_valid_q <= 1'b1;
                    encoder_line_valid_q <= 1'b1;
            end

            if (encoder_pixel_take) begin
                encoder_pixel_valid_q <= 1'b0;
                accepted_pixels <= accepted_pixels + 1'b1;
                previous_pixel <= raw_pixel;
                previous_valid <= 1'b1;
                if (scan_mode != 0) begin
                    if (pixel_luminance_q >= background)
                        background <= background + ((pixel_luminance_q - background) >> 4);
                    else
                        background <= background - ((background - pixel_luminance_q) >> 4);
                end
                if (pixel_x == 12'd15) begin
                    pixel_x <= 12'd0;
                    previous_valid <= 1'b0;
                    encoder_line_valid_q <= 1'b0;
                     


                    line_blank_count <= 9'd300;
                    if (accepted_pixels + 1'b1 == padded_pixels) begin
                        frame_active <= 1'b0;
                    end else begin
                        pixel_y <= pixel_y + 1'b1;
                    end
                end else begin
                    pixel_x <= pixel_x + 1'b1;
                end
            end

            if (dump_done_i && !jpeg_dump_started)
                raw_dump_done <= 1'b1;

            if (writer_done && !jpeg_dump_started && !dump_busy_i) begin
                jpeg_dump_started <= 1'b1;
                dump_direct_o <= 1'b1;
                dump_base_o <= JPEG_BASE;
                dump_size_o <= {10'd0, jpeg_size_o};
                dump_start_o <= 1'b1;
            end

            if (spi_done_pulse) begin
                claim_reg <= 1'b0;
                raw_dump_started <= 1'b0;
                jpeg_dump_started <= 1'b0;
                raw_pixel_valid <= 1'b0;
                frame_active <= 1'b0;
                encoder_pixel_valid_q <= 1'b0;
                encoder_frame_valid_q <= 1'b0;
                encoder_line_valid_q <= 1'b0;
                line_blank_count <= 9'd0;
            end
        end
    end

     
    localparam [2:0] W_IDLE = 3'd0, W_HEADER = 3'd1, W_SCAN = 3'd2,
                     W_EOI0 = 3'd3, W_EOI1 = 3'd4, W_PAD = 3'd5,
                     W_DONE = 3'd6;
    reg [2:0] writer_state;
    reg [9:0] header_index;reg header_ready;
    wire [7:0] header_byte;
    jpeg_q50_header_rom u_header_rom (
        .clk(clk),
        .index_i(header_index), .width_i(frame_width),
        .height_i(frame_height), .byte_o(header_byte)
    );

    reg [31:0] scan_word;
    reg scan_word_valid;
    reg scan_word_last;
    reg [1:0] scan_byte_index;
    reg [127:0] pack_data;
    reg [3:0] pack_count;
    reg [31:0] write_offset;
    reg word_pending;
    reg last_word_pending;
    reg writer_done;
    wire writer_space = !word_pending;
    wire source_valid = (writer_state == W_HEADER && header_ready) ||
                        ((writer_state == W_SCAN) && scan_word_valid) ||
                        (writer_state == W_EOI0) || (writer_state == W_EOI1) ||
                        (writer_state == W_PAD);
    wire [7:0] source_byte = (writer_state == W_HEADER) ? header_byte :
                             (writer_state == W_SCAN) ?
                                 scan_word[scan_byte_index * 8 +: 8] :
                             (writer_state == W_EOI0) ? 8'hFF :
                             (writer_state == W_EOI1) ? 8'hD9 : 8'hFF;
    wire source_take = source_valid && writer_space;
    wire [127:0] completed_pack = set_pack_byte(pack_data, pack_count, source_byte);
    assign encoder_data_ready = (writer_state == W_SCAN) && !scan_word_valid;
    assign axi_awlen_o = 8'd0;
    assign axi_wstrb_o = 16'hFFFF;
    assign axi_wlast_o = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            writer_state <= W_IDLE;
            header_index <= 10'd0;header_ready <= 1'b0;
            scan_word <= 32'd0;
            scan_word_valid <= 1'b0;
            scan_word_last <= 1'b0;
            scan_byte_index <= 2'd0;
            pack_data <= 128'd0;
            pack_count <= 4'd0;
            write_offset <= 32'd0;
            word_pending <= 1'b0;
            last_word_pending <= 1'b0;
            writer_done <= 1'b0;
            jpeg_size_o <= 22'd0;
            axi_awaddr_o <= JPEG_BASE;
            axi_awvalid_o <= 1'b0;
            axi_wdata_o <= 128'd0;
            axi_wvalid_o <= 1'b0;
            axi_active_o <= 1'b0;
            axi_error_o <= 1'b0;
        end else begin
            writer_done <= 1'b0;
            if(writer_state==W_HEADER && !header_ready)header_ready<=1'b1;
            if (axi_awvalid_o && axi_awready_i)
                axi_awvalid_o <= 1'b0;
            if (axi_wvalid_o && axi_wready_i)
                axi_wvalid_o <= 1'b0;
            if (word_pending && axi_bvalid_i) begin
                word_pending <= 1'b0;
                if (axi_bresp_i != 2'b00)
                    axi_error_o <= 1'b1;
                if (last_word_pending) begin
                    last_word_pending <= 1'b0;
                    writer_state <= W_DONE;
                    writer_done <= 1'b1;
                    jpeg_size_o <= write_offset[21:0];
                    axi_active_o <= 1'b0;
                end
            end

            if (start_i && !claim_reg) begin
                writer_state <= raw_output_i ? W_DONE : W_HEADER;
                header_index <= 10'd0;header_ready <= 1'b0;
                scan_word_valid <= 1'b0;
                scan_byte_index <= 2'd0;
                pack_data <= 128'd0;
                pack_count <= 4'd0;
                write_offset <= 32'd0;
                word_pending <= 1'b0;
                last_word_pending <= 1'b0;
                jpeg_size_o <= raw_output_i ? frame_payload_bytes_i : 22'd0;
                axi_awvalid_o <= 1'b0;
                axi_wvalid_o <= 1'b0;
                axi_active_o <= !raw_output_i;
                axi_error_o <= 1'b0;
            end

            if (encoder_data_valid && encoder_data_ready) begin
                scan_word <= encoder_data;
                scan_word_valid <= 1'b1;
                scan_word_last <= encoder_data_last;
                scan_byte_index <= 2'd0;
            end

            if (source_take) begin
                if (pack_count == 4'd15) begin
                    axi_awaddr_o <= JPEG_BASE + write_offset;
                    axi_awvalid_o <= 1'b1;
                    axi_wdata_o <= completed_pack;
                    axi_wvalid_o <= 1'b1;
                    write_offset <= write_offset + 32'd16;
                    word_pending <= 1'b1;
                    pack_data <= 128'd0;
                    pack_count <= 4'd0;
                    if (writer_state == W_PAD)
                        last_word_pending <= 1'b1;
                end else begin
                    pack_data <= completed_pack;
                    pack_count <= pack_count + 1'b1;
                end

                case (writer_state)
                    W_HEADER: begin
                        header_ready<=1'b0;
                        if (header_index == JPEG_HEADER_BYTES - 1)
                            writer_state <= W_SCAN;
                        else
                            header_index <= header_index + 1'b1;
                    end
                    W_SCAN: begin
                        if (scan_byte_index == 2'd3) begin
                            scan_word_valid <= 1'b0;
                            scan_byte_index <= 2'd0;
                            if (scan_word_last)
                                writer_state <= W_EOI0;
                        end else begin
                            scan_byte_index <= scan_byte_index + 1'b1;
                        end
                    end
                    W_EOI0: writer_state <= W_EOI1;
                    W_EOI1: writer_state <= W_PAD;
                    W_PAD: begin
                        if (pack_count == 4'd15)
                            writer_state <= W_DONE;
                    end
                    default: begin end
                endcase
            end
        end
    end

     

    function automatic [127:0] set_pack_byte;
        input [127:0] old_data;
        input [3:0] index;
        input [7:0] value;
        integer lane;
        begin
            for (lane = 0; lane < 16; lane = lane + 1)
                set_pack_byte[lane*8 +: 8] = old_data[lane*8 +: 8] |
                    (index == lane ? value : 8'd0);
        end
    endfunction
    function automatic [127:0] reverse_words_16x8;
        input [127:0] value;
        integer wi;
        begin
            for (wi = 0; wi < 8; wi = wi + 1)
                reverse_words_16x8[wi*16 +: 16] = value[(7-wi)*16 +: 16];
        end
    endfunction

     

    reg [31:0] source_crc;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)source_crc<=32'hffffffff;
        else if(start_i && !claim_reg)source_crc<=32'hffffffff;
        else if(jpeg_dump_started && dump_valid_i && dump_ready_o)source_crc<=crc32_next(source_crc,dump_data_i);
    end
    reg [127:0] fifo_pack;
    reg [3:0] fifo_pack_count;
    wire [127:0] fifo_completed = set_pack_byte(fifo_pack, fifo_pack_count,
                                                dump_data_i);
    wire fifo_write = jpeg_dump_started && dump_valid_i && dump_ready_o &&
                      fifo_pack_count == 4'd15;
    wire [127:0] fifo_wdata = reverse_words_16x8(fifo_completed);
    wire fifo_full;
    wire fifo_empty;
    wire fifo_rd_valid;
    reg fifo_rd_en;
    wire [15:0] fifo_rdata;
    wire fifo_rst_busy;
    wire fifo_arst = !rst_n || !claim_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || !claim_reg) begin
            fifo_pack <= 128'd0;
            fifo_pack_count <= 4'd0;
        end else if (jpeg_dump_started && dump_valid_i && dump_ready_o) begin
            if (fifo_pack_count == 4'd15) begin
                fifo_pack <= 128'd0;
                fifo_pack_count <= 4'd0;
            end else begin
                fifo_pack <= fifo_completed;
                fifo_pack_count <= fifo_pack_count + 1'b1;
            end
        end
    end

    R0_FIFO_16 u_stream_fifo (
        .almost_full_o(), .prog_full_o(), .full_o(fifo_full), .wr_ack_o(),
        .empty_o(fifo_empty), .almost_empty_o(), .rd_valid_o(fifo_rd_valid),
        .wr_clk_i(clk), .rd_clk_i(spi_sclk_i), .wr_en_i(fifo_write),
        .rd_en_i(fifo_rd_en), .wdata(fifo_wdata), .rst_busy(fifo_rst_busy),
        .rdata(fifo_rdata), .a_rst_i(fifo_arst), .wr_datacount_o(),
        .rd_datacount_o(), .underflow_o(), .overflow_o()
    );

    reg fifo_empty_sys1, fifo_empty_sys2;
    reg done_toggle_spi, done_toggle_sys1, done_toggle_sys2, done_toggle_seen;
    wire spi_done_pulse = done_toggle_sys2 != done_toggle_seen;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_empty_sys1 <= 1'b1;
            fifo_empty_sys2 <= 1'b1;
            done_toggle_sys1 <= 1'b0;
            done_toggle_sys2 <= 1'b0;
            done_toggle_seen <= 1'b0;
            ready_reg <= 1'b0;
        end else begin
            fifo_empty_sys1 <= fifo_empty;
            fifo_empty_sys2 <= fifo_empty_sys1;
            done_toggle_sys1 <= done_toggle_spi;
            done_toggle_sys2 <= done_toggle_sys1;
            if (claim_reg && jpeg_dump_started && !ready_reg &&
                !fifo_rst_busy && !fifo_empty_sys2)
                ready_reg <= 1'b1;
            if (spi_done_pulse) begin
                done_toggle_seen <= done_toggle_sys2;
                ready_reg <= 1'b0;
            end
            if (!claim_reg)
                ready_reg <= 1'b0;
        end
    end

    function automatic [7:0] transport_header_byte;
        input [4:0] index;
        begin
            case (index)
                0: transport_header_byte = 8'h4A;
                1: transport_header_byte = 8'h50;
                2: transport_header_byte = 8'h49;
                3: transport_header_byte = 8'h43;
                4: transport_header_byte = 8'h01;
                5: transport_header_byte = raw_output ? 8'h03 : 8'h02;
                6: transport_header_byte = frame_width[7:0];
                7: transport_header_byte = {4'd0, frame_width[11:8]};
                8: transport_header_byte = frame_height[7:0];
                9: transport_header_byte = {4'd0, frame_height[11:8]};
                10: transport_header_byte = jpeg_size_o[7:0];
                11: transport_header_byte = jpeg_size_o[15:8];
                12: transport_header_byte = {2'd0, jpeg_size_o[21:16]};
                13: transport_header_byte = 8'd0;
                14: transport_header_byte = {6'd0, frame_mode};
                default: transport_header_byte = 8'd0;
            endcase
        end
    endfunction

    function automatic [31:0] crc32_next;
        input [31:0] crc_in;
        input [7:0] data;
        integer ci;
        reg [31:0] c;
        begin
            c = crc_in ^ data;
            for (ci = 0; ci < 8; ci = ci + 1)
                c = c[0] ? ((c >> 1) ^ 32'hEDB88320) : (c >> 1);
            crc32_next = c;
        end
    endfunction

    reg [31:0] stream_index;
    reg [2:0] spi_bit_count;
    reg [7:0] current_byte;
    reg [7:0] tx_shift;
    reg [31:0] crc_state;
    reg stream_started;
     



    reg stream_underflow;
    wire next_payload_word = stream_index + 1 >= HEADER_BYTES &&
        stream_index + 1 < HEADER_BYTES + jpeg_size_o && stream_index[0];
    wire [31:0] total_bytes = HEADER_BYTES + {10'd0, jpeg_size_o} + CRC_BYTES;
    wire [31:0] payload_index = stream_index - HEADER_BYTES;
    wire [31:0] crc_after_current = crc32_next(crc_state, current_byte);

    function automatic [7:0] byte_for_index;
        input [31:0] index;
        reg [31:0] p;
        begin
            if (index < HEADER_BYTES)
                byte_for_index = transport_header_byte(index[4:0]);
            else if (index < HEADER_BYTES + jpeg_size_o) begin
                p = index - HEADER_BYTES;
                byte_for_index = p[0] ? fifo_rdata[15:8] : fifo_rdata[7:0];
            end else begin
                case (index - HEADER_BYTES - jpeg_size_o)
                    0: byte_for_index = ~source_crc[7:0];
                    1: byte_for_index = ~source_crc[15:8];
                    2: byte_for_index = ~source_crc[23:16];
                    default: byte_for_index = ~source_crc[31:24];
                endcase
            end
        end
    endfunction

    always @(negedge spi_sclk_i or negedge rst_n) begin
        if (!rst_n) begin
            stream_index <= 32'd0;
            spi_bit_count <= 3'd0;
            current_byte <= 8'd0;
            tx_shift <= 8'd0;
            crc_state <= 32'hFFFFFFFF;
            done_toggle_spi <= 1'b0;
            fifo_rd_en <= 1'b0;
            stream_started <= 1'b0;
            stream_underflow <= 1'b0;
        end else if (!stream_enable_i) begin
            stream_started <= 1'b0;
            stream_underflow <= 1'b0;
            stream_index <= 32'd0;
            spi_bit_count <= 3'd0;
            current_byte <= transport_header_byte(0);
            tx_shift <= 8'd0;
            crc_state <= 32'hFFFFFFFF;
            fifo_rd_en <= 1'b0;
        end else if (!spi_cs_n_i && ready_reg) begin
            fifo_rd_en <= 1'b0;
            if (!stream_started) begin
                stream_started <= 1'b1;
                stream_index <= 32'd0;
                spi_bit_count <= 3'd1;
                current_byte <= 8'h4A;
                tx_shift <= 8'h94;
                crc_state <= 32'hFFFFFFFF;
            end else if (spi_bit_count == 3'd7) begin
                if (next_payload_word && fifo_empty)
                    stream_underflow <= 1'b1;
                if (stream_index >= HEADER_BYTES &&
                    stream_index < HEADER_BYTES + jpeg_size_o) begin
                    crc_state <= crc_after_current;
                     



                    if (!payload_index[0])
                        fifo_rd_en <= 1'b1;
                end
                if (stream_index == total_bytes - 1'b1) begin
                    done_toggle_spi <= ~done_toggle_spi;
                    stream_started <= 1'b0;
                    spi_bit_count <= 3'd0;
                end else begin
                    stream_index <= stream_index + 1'b1;
                    spi_bit_count <= 3'd0;
                    if (stream_index == HEADER_BYTES + jpeg_size_o - 1'b1)
                        current_byte <= ~source_crc[7:0] ^ {7'd0,stream_underflow};
                    else
                        current_byte <= byte_for_index(stream_index + 1'b1);
                end
            end else if (spi_bit_count == 3'd0) begin
                tx_shift <= {current_byte[6:0], 1'b0};
                spi_bit_count <= 3'd1;
            end else begin
                tx_shift <= {tx_shift[6:0], 1'b0};
                spi_bit_count <= spi_bit_count + 1'b1;
            end
        end else begin
            fifo_rd_en <= 1'b0;
        end
    end

    assign spi_miso_o = (ready_reg && !spi_cs_n_i) ?
                        ((!stream_started || spi_bit_count == 0) ?
                         current_byte[7] : tx_shift[7]) : 1'b0;
    assign claim_o = claim_reg;
    assign ready_o = ready_reg;
    assign diag_status_o = {
        axi_error_o, ready_reg, jpeg_dump_started, axi_active_o,
        encoder_image_valid, raw_dump_done, frame_active, claim_reg
    };
endmodule
