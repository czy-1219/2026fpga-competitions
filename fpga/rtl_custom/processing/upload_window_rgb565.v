`ifndef UPLOAD_WINDOW_RGB565_DEFINED
`define UPLOAD_WINDOW_RGB565_DEFINED
`timescale 1ns / 1ps

 


module upload_window_rgb565 #(
    parameter integer WIDTH = 1024,
    parameter integer HEIGHT = 600
)(
    input wire clk,
    input wire rst_n,
    input wire frame_start_i,
    input wire [15:0] pixel_i,
    input wire pixel_valid_i,
    output wire pixel_ready_o,
    output wire [143:0] window_o,
    output wire window_valid_o,
    input wire window_ready_i
);
    localparam [1:0] ST_IDLE = 2'd0, ST_READ = 2'd1, ST_HOLD = 2'd2;
    reg [1:0] state, next_state;
    reg [15:0] even_rows [0:WIDTH-1];
    reg [15:0] odd_rows [0:WIDTH-1];
    reg [15:0] even_read, odd_read, current_read;
    reg [10:0] x_count, y_count, read_x, read_y;
    reg right_pending;
    reg [15:0] top_left, top_far, middle_left, middle_far, bottom_left, bottom_far;
    reg [143:0] window_reg;
    reg window_valid;
    wire [15:0] recent_row = (read_y == 0) ? current_read :
                             read_y[0] ? even_read : odd_read;
    wire [15:0] older_row = (read_y < 2) ? recent_row :
                            read_y[0] ? odd_read : even_read;
    wire [15:0] bottom_row = (read_y == HEIGHT) ? recent_row : current_read;
    wire emit_window = (read_y != 0) && (read_x != 0);
    wire advance = right_pending || (y_count == HEIGHT) || (pixel_valid_i && pixel_ready_o);
    assign pixel_ready_o = (state == ST_IDLE) && (y_count < HEIGHT) && !right_pending && !frame_start_i;
    assign window_o = window_reg;
    assign window_valid_o = window_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else if (frame_start_i) state <= ST_IDLE;
        else state <= next_state;
    end
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: if (advance && !frame_start_i) next_state = ST_READ;
            ST_READ: next_state = emit_window ? ST_HOLD : ST_IDLE;
            ST_HOLD: if (window_ready_i) next_state = ST_IDLE;
            default: next_state = ST_IDLE;
        endcase
    end

     

    always @(posedge clk) begin
        if ((state == ST_IDLE) && advance && !right_pending && !frame_start_i) begin
            even_read <= even_rows[x_count];
            odd_read <= odd_rows[x_count];
            if (y_count < HEIGHT) begin
                if (y_count[0]) odd_rows[x_count] <= pixel_i;
                else even_rows[x_count] <= pixel_i;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_count <= 0; y_count <= 0; read_x <= 0; read_y <= 0;
            right_pending <= 0; current_read <= 0;
            window_valid <= 0; window_reg <= 0;
            top_left <= 0; top_far <= 0; middle_left <= 0;
            middle_far <= 0; bottom_left <= 0; bottom_far <= 0;
        end else if (frame_start_i) begin
            x_count <= 0; y_count <= 0; right_pending <= 0; window_valid <= 0;
        end else begin
            if ((state == ST_IDLE) && advance) begin
                read_x <= right_pending ? WIDTH : x_count;
                read_y <= y_count;
                if (!right_pending) current_read <= pixel_i;
            end
            if (state == ST_READ) begin
                window_reg <= {
                    bottom_row, (read_x == 0 ? bottom_row : bottom_left), (read_x == 0 ? bottom_row : bottom_far),
                    recent_row, (read_x == 0 ? recent_row : middle_left), (read_x == 0 ? recent_row : middle_far),
                    older_row, (read_x == 0 ? older_row : top_left), (read_x == 0 ? older_row : top_far)
                };
                window_valid <= emit_window;
                top_far <= (read_x == 0) ? older_row : top_left;
                top_left <= older_row;
                middle_far <= (read_x == 0) ? recent_row : middle_left;
                middle_left <= recent_row;
                bottom_far <= (read_x == 0) ? bottom_row : bottom_left;
                bottom_left <= bottom_row;
                if (read_x == WIDTH) begin
                    x_count <= 0; y_count <= y_count + 1'b1; right_pending <= 0;
                end else if (read_x == WIDTH-1) begin
                    right_pending <= 1;
                end else begin
                    x_count <= x_count + 1'b1;
                end
            end
            if ((state == ST_HOLD) && window_ready_i) window_valid <= 0;
        end
    end
endmodule
`endif
