`timescale 1ns/1ps

 
module uart_rx_byte #(
    parameter integer CLK_HZ = 96_000_000,
    parameter integer BAUD   = 460_800,
    parameter integer CLKS_PER_BIT = CLK_HZ / BAUD
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_i,
    output reg [7:0]  data_o,
    output reg        valid_o
);
    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_DATA  = 3'd2;
    localparam [2:0] S_STOP  = 3'd3;

    reg [2:0] rx_sync;
    reg [2:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] shift_data;

    wire rx = rx_sync[2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sync <= 3'b111;
        else
            rx_sync <= {rx_sync[1:0], rx_i};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            clk_count  <= 0;
            bit_index  <= 0;
            shift_data <= 0;
            data_o     <= 0;
            valid_o    <= 1'b0;
        end else begin
            valid_o <= 1'b0;
            case (state)
                S_IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (!rx)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_count == (CLKS_PER_BIT / 2) - 1) begin
                        clk_count <= 0;
                        if (!rx)
                            state <= S_DATA;
                        else
                            state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        shift_data[bit_index] <= rx;
                        if (bit_index == 3'd7) begin
                            bit_index <= 0;
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state <= S_IDLE;
                        if (rx) begin
                            data_o <= shift_data;
                            valid_o <= 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

