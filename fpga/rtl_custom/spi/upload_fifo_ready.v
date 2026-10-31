`timescale 1ns/1ps
 

module upload_fifo_ready (
    input wire clk, input wire rst_n, input wire fifo_reset_i,
    input wire writer_active_i, input wire receiver_error_i,
    input wire [9:0] fifo_read_count_i,
    output reg ready_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_o <= 1'b0;
        else ready_o <= !fifo_reset_i && writer_active_i && !receiver_error_i &&
                        fifo_read_count_i <= 10'd256;
    end
endmodule
