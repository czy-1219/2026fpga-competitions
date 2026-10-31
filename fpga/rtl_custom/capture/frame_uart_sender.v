`timescale 1ns/1ps

 

module frame_uart_sender #(
    parameter integer CLK_HZ = 96_000_000,
    parameter integer BAUD = 460_800,
    parameter integer WIDTH = 1024,
    parameter integer HEIGHT = 600,
    parameter integer PAYLOAD_BYTES = WIDTH * HEIGHT * 2,
    parameter integer DUAL_RESOLUTION = 0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start_i,
    input  wire       frame_1080_i,
    input  wire [1:0] scan_mode_i,
    input  wire [7:0] bw_margin_i,
    output reg        dump_start_o,
    input  wire       dump_busy_i,
    input  wire [7:0] dump_data_i,
    input  wire       dump_valid_i,
    output reg        dump_ready_o,
    input  wire       dump_done_i,
    output wire       uart_tx_o,
    output reg        busy_o
);
    localparam [2:0] S_IDLE    = 3'd0;
    localparam [2:0] S_HEADER  = 3'd1;
    localparam [2:0] S_PAYLOAD = 3'd2;
    localparam [2:0] S_CRC     = 3'd3;
    localparam [2:0] S_FINISH  = 3'd4;

    reg [2:0] state;
    reg [4:0] header_index;
    reg [2:0] crc_index;
    reg [31:0] crc;
    reg [31:0] crc_final;
    reg [7:0] tx_data;
    reg tx_start;
    reg [1:0] scan_mode;
    reg [7:0] bw_margin;
    reg [1:0] pixel_phase;
    reg [7:0] pixel_low;
    reg [7:0] processed_high;
    reg [7:0] background;
    reg dump_finished;
     

    reg frame_1080;
    wire [15:0] frame_width = DUAL_RESOLUTION && frame_1080 ? 16'd1920 : WIDTH;
    wire [15:0] frame_height = DUAL_RESOLUTION && frame_1080 ? 16'd1080 : HEIGHT;
    wire [31:0] frame_bytes = DUAL_RESOLUTION && frame_1080 ? 32'd4147200 : PAYLOAD_BYTES;
    wire [15:0] processed_pixel;
    wire [7:0] pixel_luminance;
    wire [15:0] input_pixel = {dump_data_i, pixel_low};
    wire bw_background_sample = pixel_luminance >= 8'd120 &&
                                ({1'b0, pixel_luminance} + 9'd100 >=
                                 {1'b0, background});
    wire tx_busy;
    wire tx_done;

    scan_rgb565_pixel u_scan_rgb565_pixel (
        .pixel_i(input_pixel),
        .background_i(background),
        .ink_margin_i(bw_margin),
        .mode_i(scan_mode),
        .pixel_o(processed_pixel),
        .luminance_o(pixel_luminance)
    );

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

     
    wire [7:0] crc_byte = scan_mode == 0 ? dump_data_i :
                         pixel_phase == 1 ? processed_pixel[7:0] : processed_high;
    wire [31:0] next_crc = crc32_next(crc, crc_byte);

    function [7:0] header_byte;
        input [4:0] index;
        begin
            case (index)
                0:  header_byte = 8'h46;  
                1:  header_byte = 8'h50;  
                2:  header_byte = 8'h49;  
                3:  header_byte = 8'h43;  
                4:  header_byte = 8'h01;  
                5:  header_byte = 8'h01;  
                6:  header_byte = frame_width[7:0];
                7:  header_byte = frame_width[15:8];
                8:  header_byte = frame_height[7:0];
                9:  header_byte = frame_height[15:8];
                10: header_byte = frame_bytes[7:0];
                11: header_byte = frame_bytes[15:8];
                12: header_byte = frame_bytes[23:16];
                13: header_byte = frame_bytes[31:24];
                14: header_byte = (scan_mode == 2'd0) ? 8'd0 :
                                  (scan_mode == 2'd2) ? 8'd3 :
                                  (bw_margin == 8'd12) ? 8'd2 : 8'd1;
                15: header_byte = 8'h00;
                default: header_byte = 8'h00;
            endcase
        end
    endfunction

    uart_tx_byte #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart_tx_byte (
        .clk(clk),
        .rst_n(rst_n),
        .data_i(tx_data),
        .start_i(tx_start),
        .tx_o(uart_tx_o),
        .busy_o(tx_busy),
        .done_o(tx_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            header_index <= 0;
            crc_index <= 0;
            crc <= 32'hFFFFFFFF;
            crc_final <= 0;
            tx_data <= 0;
            tx_start <= 0;
            dump_start_o <= 0;
            dump_ready_o <= 0;
            busy_o <= 0;
            scan_mode <= 0;
            bw_margin <= 8'd24;
            pixel_phase <= 0;
            pixel_low <= 0;
            processed_high <= 0;
            background <= 8'd224;
            dump_finished <= 1'b0;
            frame_1080 <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            dump_start_o <= 1'b0;
            dump_ready_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        busy_o <= 1'b1;
                        header_index <= 0;
                        crc <= 32'hFFFFFFFF;
                        scan_mode <= scan_mode_i;
                        bw_margin <= bw_margin_i;
                        pixel_phase <= 0;
                        background <= 8'd224;
                        dump_finished <= 1'b0;
                        frame_1080 <= DUAL_RESOLUTION && frame_1080_i;
                        dump_start_o <= 1'b1;
                        state <= S_HEADER;
                    end
                end

                S_HEADER: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data <= header_byte(header_index);
                        tx_start <= 1'b1;
                        if (header_index == 5'd15)
                            state <= S_PAYLOAD;
                        else
                            header_index <= header_index + 1'b1;
                    end
                end

                S_PAYLOAD: begin
                    if (scan_mode == 2'd0) begin
                         
                        if (dump_valid_i && !tx_busy && !tx_start) begin
                            tx_data <= dump_data_i;
                            tx_start <= 1'b1;
                            dump_ready_o <= 1'b1;
                            crc <= next_crc;
                        end
                        if (dump_done_i) begin
                            crc_final <= ~crc;
                            crc_index <= 0;
                            state <= S_CRC;
                        end
                    end else begin
                        if (dump_done_i)
                            dump_finished <= 1'b1;
                        if (!tx_busy && !tx_start) begin
                            case (pixel_phase)
                            2'd0: if (dump_valid_i) begin
                                pixel_low <= dump_data_i;
                                dump_ready_o <= 1'b1;
                                 

                                pixel_phase <= 2'd3;
                            end
                            2'd1: if (dump_valid_i) begin
                                tx_data <= processed_pixel[7:0];
                                processed_high <= processed_pixel[15:8];
                                tx_start <= 1'b1;
                                dump_ready_o <= 1'b1;
                                crc <= next_crc;
                                 




                                if (scan_mode != 2'd1 || bw_background_sample) begin
                                    if (pixel_luminance >= background)
                                        background <= background +
                                            ((pixel_luminance - background) >> 4);
                                    else
                                        background <= background -
                                            ((background - pixel_luminance) >> 4);
                                end
                                pixel_phase <= 2'd2;
                            end
                            2'd2: begin
                                tx_data <= processed_high;
                                tx_start <= 1'b1;
                                crc <= next_crc;
                                pixel_phase <= 2'd0;
                            end
                            2'd3: pixel_phase <= 2'd1;
                            endcase
                        end
                        if ((dump_done_i || dump_finished) && pixel_phase == 2'd0) begin
                            crc_final <= ~crc;
                            crc_index <= 0;
                            state <= S_CRC;
                        end
                    end
                end

                S_CRC: begin
                    if (!tx_busy && !tx_start) begin
                        case (crc_index)
                            0: tx_data <= crc_final[7:0];
                            1: tx_data <= crc_final[15:8];
                            2: tx_data <= crc_final[23:16];
                            default: tx_data <= crc_final[31:24];
                        endcase
                        tx_start <= 1'b1;
                        if (crc_index == 3)
                            state <= S_FINISH;
                        else
                            crc_index <= crc_index + 1'b1;
                    end
                end

                S_FINISH: begin
                    if (!tx_busy && !tx_start) begin
                        busy_o <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
