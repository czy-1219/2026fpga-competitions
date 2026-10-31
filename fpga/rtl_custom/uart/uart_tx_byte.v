`timescale 1ns/1ps

 
module uart_tx_byte #(
    parameter integer CLK_HZ = 96_000_000,
    parameter integer BAUD   = 460_800,
    parameter integer CLKS_PER_BIT = CLK_HZ / BAUD
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_i,
    input  wire       start_i,
    output reg        tx_o,
    output reg        busy_o,
    output reg        done_o
);
    reg [15:0] clk_count;
    reg [3:0] bit_index;
    reg [9:0] frame;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_o      <= 1'b1;
            busy_o    <= 1'b0;
            done_o    <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            frame     <= 10'h3ff;
        end else begin
            done_o <= 1'b0;
            if (!busy_o) begin
                tx_o <= 1'b1;
                if (start_i) begin
                    frame <= {1'b1, data_i, 1'b0};
                    tx_o <= 1'b0;
                    busy_o <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                end
            end else if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                if (bit_index == 4'd9) begin
                    tx_o <= 1'b1;
                    busy_o <= 1'b0;
                    done_o <= 1'b1;
                    bit_index <= 0;
                end else begin
                    bit_index <= bit_index + 1'b1;
                    tx_o <= frame[bit_index + 1'b1];
                end
            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end
    end
endmodule

