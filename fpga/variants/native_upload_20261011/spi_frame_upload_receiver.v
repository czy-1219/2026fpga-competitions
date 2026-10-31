`timescale 1ns/1ps

 

module spi_frame_upload_receiver (
    input  wire        rst_n,
    input  wire        session_reset_i,
    input  wire        spi_sclk_i,
    input  wire        spi_cs_n_i,
    input  wire        select_i,
    input  wire        spi_mosi_i,
    input  wire        fifo_full_i,
    output reg  [7:0]  fifo_data_o,
    output reg         fifo_write_o,
    output wire        packet_done_o,
    output wire        packet_good_o,
    output reg         header_error_o,
    output reg         overflow_o,
    output reg  [21:0] payload_count_o,
    output reg         frame_metadata_valid_o,
    output reg  [11:0] frame_width_o,
    output reg  [11:0] frame_height_o,
    output reg  [21:0] frame_payload_bytes_o
);
    localparam integer HEADER_BYTES = 16;
    localparam [21:0] MAX_JPEG_PAYLOAD = 22'd4194288;

    reg [7:0] rx_shift;
    reg [2:0] bit_count;
     
    reg [22:0] byte_count;
    reg [31:0] crc_state;
    reg [31:0] received_crc;
    reg [31:0] header_payload;
    reg packet_done_state;
    reg packet_good_state;
    assign packet_done_o = packet_done_state;
    assign packet_good_o = packet_good_state;
    wire [7:0] completed_byte = {rx_shift[6:0], spi_mosi_i};
    wire [22:0] total_bytes = 23'd20 + {1'b0, frame_payload_bytes_o};

    function supported_geometry;
        input [11:0] width;
        input [11:0] height;
        input [31:0] payload;
        begin
            supported_geometry = (payload != 0) &&
                (payload <= MAX_JPEG_PAYLOAD) && (payload[3:0] == 0) &&
                (
                (width == 12'd1024 && height == 12'd600) ||
                (width == 12'd1920 && height == 12'd1080) || (width == 12'd256 && height == 12'd224)
                );
        end
    endfunction

    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0] data_in;
        integer bit_index;
        reg [31:0] value;
        begin
            value = crc_in ^ data_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                value = value[0] ? ((value >> 1) ^ 32'hEDB88320)
                                 : (value >> 1);
            crc32_byte = value;
        end
    endfunction

    task check_header_byte;
        input [4:0] index;
        input [7:0] value;
        reg [31:0] completed_payload;
        begin
            case (index)
                5'd0:  if (value != 8'h55) header_error_o <= 1'b1;
                5'd1:  if (value != 8'h4A) header_error_o <= 1'b1;
                5'd2:  if (value != 8'h49) header_error_o <= 1'b1;
                5'd3:  if (value != 8'h47) header_error_o <= 1'b1;
                5'd4:  if (value != 8'h01) header_error_o <= 1'b1;
                5'd5:  if (value != 8'h02) header_error_o <= 1'b1;
                5'd6:  frame_width_o[7:0] <= value;
                5'd7: begin
                    frame_width_o[11:8] <= value[3:0];
                    if (value[7:4] != 0) header_error_o <= 1'b1;
                end
                5'd8:  frame_height_o[7:0] <= value;
                5'd9: begin
                    frame_height_o[11:8] <= value[3:0];
                    if (value[7:4] != 0) header_error_o <= 1'b1;
                end
                5'd10: header_payload[7:0] <= value;
                5'd11: header_payload[15:8] <= value;
                5'd12: header_payload[23:16] <= value;
                5'd13: begin
                    completed_payload = {value, header_payload[23:0]};
                    frame_payload_bytes_o <= completed_payload[21:0];
                    frame_metadata_valid_o <= supported_geometry(
                        frame_width_o, frame_height_o, completed_payload);
                    if (!supported_geometry(frame_width_o, frame_height_o,
                                            completed_payload))
                        header_error_o <= 1'b1;
                end
                default: begin end
            endcase
        end
    endtask

     


    always @(posedge spi_sclk_i or posedge session_reset_i or negedge rst_n) begin
        if (!rst_n || session_reset_i) begin
            rx_shift <= 8'd0;
            bit_count <= 3'd0;
            byte_count <= 23'd0;
            crc_state <= 32'hFFFFFFFF;
            received_crc <= 32'd0;
            header_payload <= 32'd0;
            fifo_data_o <= 8'd0;
            fifo_write_o <= 1'b0;
            packet_done_state <= 1'b0;
            packet_good_state <= 1'b0;
            header_error_o <= 1'b0;
            overflow_o <= 1'b0;
            payload_count_o <= 22'd0;
            frame_metadata_valid_o <= 1'b0;
            frame_width_o <= 12'd0;
            frame_height_o <= 12'd0;
            frame_payload_bytes_o <= 22'd0;
        end else if (spi_cs_n_i) begin
            bit_count <= 3'd0;
            fifo_write_o <= 1'b0;
            if (select_i && !packet_done_state && byte_count != 0) begin
                packet_done_state <= 1'b1;
                packet_good_state <= 1'b0;
            end
        end else if (select_i && !packet_done_state) begin
            fifo_write_o <= 1'b0;
            rx_shift <= completed_byte;
            if (bit_count == 3'd7) begin
                bit_count <= 3'd0;
                if (byte_count < HEADER_BYTES) begin
                    check_header_byte(byte_count[4:0], completed_byte);
                end else if (frame_metadata_valid_o &&
                             byte_count < HEADER_BYTES + frame_payload_bytes_o) begin
                    if (fifo_full_i) begin
                        overflow_o <= 1'b1;
                    end else begin
                        fifo_data_o <= completed_byte;
                        fifo_write_o <= 1'b1;
                    end
                    crc_state <= crc32_byte(crc_state, completed_byte);
                    payload_count_o <= payload_count_o + 1'b1;
                end else if (frame_metadata_valid_o && byte_count < total_bytes) begin
                    case (byte_count - HEADER_BYTES - frame_payload_bytes_o)
                        0: received_crc[7:0] <= completed_byte;
                        1: received_crc[15:8] <= completed_byte;
                        2: received_crc[23:16] <= completed_byte;
                        3: begin
                            received_crc[31:24] <= completed_byte;
                            packet_done_state <= 1'b1;
                            packet_good_state <= !header_error_o && !overflow_o &&
                                (payload_count_o == frame_payload_bytes_o) &&
                                ({completed_byte, received_crc[23:0]} == ~crc_state);
                        end
                    endcase
                end else if (byte_count >= HEADER_BYTES) begin
                    packet_done_state <= 1'b1;
                    packet_good_state <= 1'b0;
                end
                byte_count <= byte_count + 1'b1;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end else begin
            fifo_write_o <= 1'b0;
        end
    end
endmodule
