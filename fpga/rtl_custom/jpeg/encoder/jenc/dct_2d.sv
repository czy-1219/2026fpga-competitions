/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
module dct_2d #(
    parameter DW = 8,
     





    parameter CW = DW + 4,
    parameter QW = CW + 3        
)(
    input   logic signed[DW-1:0]    di[7:0], 
    input   logic                   di_valid,
    output  logic                   di_hold,
    input   logic [2:0]             di_cnt,
    output  logic signed[QW-1:0]    q[1:0],
    output  logic                   q_valid,
    input   logic                   q_hold,
    output  logic [4:0]             q_cnt,
    input   logic                   clk,
    input   logic                   resetn,
    input   logic                   clk_x22,
    input   logic                   resetn_x22
);

always_comb assert (DW == 8) else $error();
always_comb assert (CW == 12) else $error();
always_comb assert (QW == 15) else $error();
 


logic signed[CW-1:0] dct0_q[7:0]; 
logic [2:0] dct0_q_cnt;
logic dct0_q_valid;
logic dct0_q_hold;

dct_1d_aan #(
    .DW     (DW),
    .CW     (CW)
) dct_1d_0 (
    .di             (di),
    .di_valid       (di_valid),
    .di_hold        (di_hold),
    .di_cnt         (di_cnt),
    .q              (dct0_q),
    .q_valid        (dct0_q_valid),
    .q_hold         (dct0_q_hold),
    .q_cnt          (dct0_q_cnt),
    .*
);

 


logic signed[CW-1:0] dct1_d[7:0]; 
logic [2:0] dct1_d_cnt;
logic dct1_d_valid;
logic dct1_d_hold;

transpose #(.QW(CW)) transpose (
    .d          (dct0_q),
    .d_cnt      (dct0_q_cnt),
    .d_valid    (dct0_q_valid),
    .d_hold     (dct0_q_hold),
    .q          (dct1_d),
    .q_cnt      (dct1_d_cnt),
    .q_valid    (dct1_d_valid),
    .q_hold     (dct1_d_hold),
    .*
);

 


logic signed[QW-1:0] dct1_q[7:0]; 
logic [2:0] dct1_q_cnt;
logic dct1_q_valid;
logic dct1_q_hold;

dct_1d_aan #(
    .DW     (CW),
    .CW     (QW)
) dct_1d_1 (
    .di             (dct1_d),
    .di_valid       (dct1_d_valid),
    .di_hold        (dct1_d_hold),
    .di_cnt         (dct1_d_cnt),
    .q              (dct1_q),
    .q_valid        (dct1_q_valid),
    .q_hold         (dct1_q_hold),
    .q_cnt          (dct1_q_cnt),
    .*
);

 



zigzag #(.QW(QW)) zigzag (
    .d          (dct1_q),
    .d_cnt      (dct1_q_cnt),
    .d_valid    (dct1_q_valid),
    .d_hold     (dct1_q_hold),

    .q          (q),
    .q_cnt      (q_cnt),
    .q_valid    (q_valid),
    .q_hold     (q_hold),
    .*
);
endmodule
