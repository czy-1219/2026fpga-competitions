`timescale 1ns/1ps

 

module scan_bw_shared_engine #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080,
    parameter integer WINDOW = 51
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_start_i,
    input wire [10:0] frame_width_i,
    input wire [10:0] frame_height_i,
    input  wire        pixel_valid_i,
    output wire        pixel_ready_o,
    input  wire [15:0] pixel_i,
    input  wire [7:0]  offset_i,
    input  wire        gray_override_enable_i,
    input  wire [7:0]  gray_override_i,
    output reg         pixel_valid_o,
    input  wire        pixel_ready_i,
    output reg  [15:0] pixel_o
);
    localparam integer AREA = WINDOW * WINDOW;
    localparam integer SUM_WIDTH = 20;
    localparam integer ROWS = WINDOW;

    reg [7:0] line_memory [0:(ROWS * WIDTH) - 1];
    reg [7:0] first_row_memory [0:WIDTH - 1];
    reg [13:0] column_sum_memory [0:WIDTH - 1];
    reg [13:0] horizontal_history [0:WINDOW - 1];

    reg [10:0] frame_width;
    reg [10:0] frame_height;
    reg [10:0] x_count;
    reg [10:0] y_count;
    reg [5:0] line_slot;
    reg [7:0] old_pixel_q;
    reg [7:0] first_row_pixel_q;
    reg [13:0] old_column_sum_q;
    reg [7:0] current_gray_q;
    reg [10:0] current_x_q;
    reg [10:0] current_y_q;
    reg [7:0] current_offset_q;
    reg pending;
    reg [13:0] first_column_sum;
    reg [SUM_WIDTH-1:0] horizontal_sum;

    wire [7:0] red = {pixel_i[15:11], pixel_i[15:13]};
    wire [7:0] green = {pixel_i[10:5], pixel_i[10:9]};
    wire [7:0] blue = {pixel_i[4:0], pixel_i[4:2]};
    wire [15:0] weighted_luminance = red * 8'd77 + green * 8'd150
                                      + blue * 8'd29 + 16'd128;
    wire [7:0] current_gray = gray_override_enable_i ? gray_override_i : weighted_luminance[15:8];
    wire [5:0] next_line_slot = (line_slot == ROWS - 1) ? 6'd0
                                                         : line_slot + 1'b1;
    wire [5:0] old_line_slot = line_slot;
     
    wire [16:0] current_line_address = line_slot * WIDTH + x_count;
    wire [16:0] old_line_address = old_line_slot * WIDTH + x_count;
    wire input_accept = pixel_valid_i && pixel_ready_o;

    wire [13:0] vertical_sum_next = (current_y_q == 10'd0)
        ? current_gray_q * WINDOW
        : (current_y_q < WINDOW)
            ? old_column_sum_q + current_gray_q - first_row_pixel_q
            : old_column_sum_q + current_gray_q - old_pixel_q;

    wire [SUM_WIDTH-1:0] horizontal_sum_next = (current_x_q == 10'd0)
        ? vertical_sum_next * WINDOW
        : (current_x_q < WINDOW)
            ? horizontal_sum - first_column_sum + vertical_sum_next
            : horizontal_sum - horizontal_history[0] + vertical_sum_next;

    wire [19:0] pixel_area = current_gray_q * AREA;
    wire [19:0] offset_area = (current_offset_q == 8'd4)
        ? (AREA << 2)
        : (current_offset_q == 8'd8) ? (AREA << 3) : (AREA << 3);
    wire [SUM_WIDTH-1:0] threshold_rhs = pixel_area + offset_area;
    wire is_foreground = horizontal_sum_next > threshold_rhs;

    assign pixel_ready_o = !pending && !pixel_valid_o && !frame_start_i;

    integer history_index;
    always @(posedge clk) begin
        if (input_accept) begin
            old_pixel_q <= (y_count < WINDOW) ? 8'd0
                                              : line_memory[old_line_address];
            line_memory[current_line_address] <= current_gray;
            first_row_pixel_q <= (y_count == 10'd0) ? current_gray
                                                    : first_row_memory[x_count];
            if (y_count == 10'd0)
                first_row_memory[x_count] <= current_gray;
            old_column_sum_q <= (y_count == 10'd0) ? 14'd0
                                                    : column_sum_memory[x_count];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_width <= WIDTH;
            frame_height <= HEIGHT;
            x_count <= 10'd0;
            y_count <= 10'd0;
            line_slot <= 6'd0;
            current_gray_q <= 8'd0;
            current_x_q <= 10'd0;
            current_y_q <= 10'd0;
            current_offset_q <= 8'd8;
            pending <= 1'b0;
            pixel_valid_o <= 1'b0;
            pixel_o <= 16'hFFFF;
            first_column_sum <= 14'd0;
            horizontal_sum <= {SUM_WIDTH{1'b0}};
            for (history_index = 0; history_index < WINDOW; history_index = history_index + 1)
                horizontal_history[history_index] <= 14'd0;
        end else if (frame_start_i) begin
            frame_width <= frame_width_i;
            frame_height <= frame_height_i;
            x_count <= 10'd0;
            y_count <= 10'd0;
            line_slot <= 6'd0;
            pending <= 1'b0;
            pixel_valid_o <= 1'b0;
            first_column_sum <= 14'd0;
            horizontal_sum <= {SUM_WIDTH{1'b0}};
        end else begin
            if (pixel_valid_o && pixel_ready_i)
                pixel_valid_o <= 1'b0;

            if (input_accept) begin
                pending <= 1'b1;
                current_gray_q <= current_gray;
                current_x_q <= x_count;
                current_y_q <= y_count;
                current_offset_q <= offset_i;
                if (x_count == frame_width - 1) begin
                    x_count <= 10'd0;
                    if (y_count < frame_height - 1)
                        y_count <= y_count + 1'b1;
                    line_slot <= next_line_slot;
                end else begin
                    x_count <= x_count + 1'b1;
                end
            end

            if (pending) begin
                pending <= 1'b0;
                column_sum_memory[current_x_q] <= vertical_sum_next;
                horizontal_sum <= horizontal_sum_next;
                if (current_x_q == 10'd0)
                    first_column_sum <= vertical_sum_next;
                for (history_index = 0; history_index < WINDOW - 1; history_index = history_index + 1)
                    horizontal_history[history_index] <= horizontal_history[history_index + 1];
                horizontal_history[WINDOW - 1] <= vertical_sum_next;
                pixel_o <= is_foreground ? 16'h0000 : 16'hFFFF;
                pixel_valid_o <= 1'b1;
            end
        end
    end
endmodule
