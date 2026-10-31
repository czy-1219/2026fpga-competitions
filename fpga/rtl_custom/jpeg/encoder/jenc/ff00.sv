/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
module ff00 ( 
    input   logic [31:0]            in_data,
    input   logic [2:0]             in_nbytes,
    input   logic                   in_tlast,
    input   logic                   in_valid,
    output  logic                   in_hold,

    output  logic [63:0]            out_data,
    output  logic [3:0]             out_nbytes,
    output  logic                   out_tlast,
    output  logic                   out_valid,
    input   logic                   out_hold,

    input   logic                   clk,
    input   logic                   resetn
);

always_comb if (in_valid) assert (in_nbytes < 5) else $error();

 
logic [3:0]             s_ff;
logic [63:0]            mask, data_0, data_1, data_2, data_3;

always_comb
    for (int i=0; i <= 3; i++)
        if (3 - i < in_nbytes)
            s_ff[i] = in_data[8*i +: 8] == 8'hff;
        else
            s_ff[i] = 0;
 





always_comb mask = '1 << 32;
always_comb data_0 = {in_data, 32'h0};
always_comb data_1 = s_ff[1] ? (data_0 & (mask <<  8)) | ((data_0 & ~(mask <<  8)) >> 8) : data_0;
always_comb data_2 = s_ff[2] ? (data_1 & (mask << 16)) | ((data_1 & ~(mask << 16)) >> 8) : data_1;
always_comb data_3 = s_ff[3] ? (data_2 & (mask << 24)) | ((data_2 & ~(mask << 24)) >> 8) : data_2;

always @(posedge clk)
if (!resetn)
    out_valid <= 0;
else if (~in_hold)
    out_valid <= in_valid;

always @(posedge clk)
if (~in_hold & in_valid) begin
        out_data <= data_3;
        out_nbytes <= in_nbytes + s_ff[0] + s_ff[1] + s_ff[2] + s_ff[3];
        out_tlast <= in_tlast;
end

always_comb in_hold = (out_hold & out_valid);

endmodule
