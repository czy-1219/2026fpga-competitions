`timescale 1ns/1ps

 


module adaptive_direction_control #(
    parameter integer THRESHOLD = 16,
    parameter integer MAX_GAIN = 96
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_i,
    input  wire [15:0] horizontal_energy_i,
    input  wire [15:0] vertical_energy_i,
    output reg         valid_o,
    output reg  [7:0]  horizontal_gain_o,
    output reg  [7:0]  vertical_gain_o
);
    reg [16:0] difference;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_o <= 1'b0;
            horizontal_gain_o <= 8'd0;
            vertical_gain_o <= 8'd0;
        end else begin
            valid_o <= valid_i;
            if (valid_i) begin
                difference = (horizontal_energy_i >= vertical_energy_i)
                           ? horizontal_energy_i - vertical_energy_i
                           : vertical_energy_i - horizontal_energy_i;
                if (difference < THRESHOLD) begin
                    horizontal_gain_o <= 8'd0;
                    vertical_gain_o <= 8'd0;
                end else if (horizontal_energy_i > vertical_energy_i) begin
                    horizontal_gain_o <= MAX_GAIN;
                    vertical_gain_o <= MAX_GAIN / 4;
                end else begin
                    horizontal_gain_o <= MAX_GAIN / 4;
                    vertical_gain_o <= MAX_GAIN;
                end
            end
        end
    end
endmodule
