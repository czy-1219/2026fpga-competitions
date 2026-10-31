/*
 * MCU buffer for 4:2:0 (4:4:4, 4:2:2, 4:0:0 can be added easily)
 *
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
 module mcu_buffer #(
    parameter SENSOR_X_SIZE = 'd720,
    parameter SENSOR_Y_SIZE = 'd720,
    parameter DW            = 8,
    parameter JPEG_BIAS     = 8'd128
)(
    input   logic [DW-1:0]      yuvrgb_in[2:0],  
    input   logic [2:0]         yuvrgb_in_valid,  
    output  logic               yuvrgb_in_hold,
    input   logic               eof_in,
    input   logic[$clog2(SENSOR_X_SIZE)-1:0]    yuvrgb_in_pixel_count,
    input   logic[$clog2(SENSOR_Y_SIZE)-1:0]    yuvrgb_in_line_count,

    output  logic signed[DW-1:0] di[7:0], 
    output  logic               di_valid,
    input   logic               di_hold,
    output  logic [2:0]         di_cnt,

    input   logic[$clog2(SENSOR_X_SIZE)-1:0] x_size_m1,
    input   logic[$clog2(SENSOR_Y_SIZE)-1:0] y_size_m1,
    input   logic               slow_clock,
    input   logic               slow_reset_n,
    input   logic               clk,
    input   logic               resetn
);

 


localparam Y_LINE_BUF_SIZE = SENSOR_X_SIZE;
localparam UV_LINE_BUF_SIZE = SENSOR_X_SIZE/2;
localparam Y_LINE_BUF_HEIGHT = 16;
localparam UV_LINE_BUF_HEIGHT = 8;

 









logic[$clog2(SENSOR_X_SIZE/16)-1:0]    block_count;  
logic[$clog2(SENSOR_Y_SIZE/16)-1:0]    block_v_count;  
logic[$clog2(6)-1:0]        mcu_count, mcu_count_0;
logic[2:0]                  mcu_line_count;  
logic[(8*DW)-1:0]           rd_y, rd_uv;

 
logic[1:0] wptr, rptr;
logic full, empty;

afifo #(.ASIZE(1)) afifo(
    .i_wclk(clk),
    .i_wrst_n(resetn), 
    .i_wr(!full & yuvrgb_in_valid[0] & (yuvrgb_in_line_count[3:0]==15 | yuvrgb_in_line_count==y_size_m1) & yuvrgb_in_pixel_count==x_size_m1),
    .i_wdata('0),
    .o_wfull(full),
    .i_rclk(slow_clock),
    .i_rrst_n(slow_reset_n),
    .i_rd(!di_hold & !empty & mcu_line_count == 7 & mcu_count == 5 & block_count == (x_size_m1 >> 4)),
    .o_rdata(),
    .o_rempty(empty),
    .*
);

always_comb yuvrgb_in_hold = full;

always @(posedge slow_clock)
if (!slow_reset_n) begin
    mcu_count <= 0;
    mcu_line_count <= 0;
    block_count <= 0;
    block_v_count <= 0;

end
else if (!di_hold & !empty) begin
    mcu_line_count <= mcu_line_count + 1;            
    if (mcu_line_count == 7)
        if (mcu_count == 5) begin
            mcu_count <= 0;
            if (block_count == (x_size_m1 >> 4)) begin
                block_count <= 0;
                if (block_v_count == (y_size_m1 >> 4))
                    block_v_count <= 0;
                else 
                    block_v_count <= block_v_count + 1;  
            end
            else
                block_count <= block_count + 1;      
        end 
        else
            mcu_count <= mcu_count + 1;              
end

 

















logic [$clog2(2*Y_LINE_BUF_SIZE*Y_LINE_BUF_HEIGHT/8) - 1:0] ra_luma;  
logic [$clog2(2*2*UV_LINE_BUF_SIZE*UV_LINE_BUF_HEIGHT/8) - 1:0] ra_chroma;  


logic [$clog2(SENSOR_X_SIZE)-1:0] r_x_luma;
logic [$clog2(SENSOR_Y_SIZE)-1:0] r_y_luma;
logic [$clog2(SENSOR_X_SIZE)-1:0] r_x_chroma;
logic [$clog2(SENSOR_Y_SIZE)-1:0] r_y_chroma;

 
logic luma_gray_out_x, luma_gray_out_y;
logic luma_gray_out_z1;
logic freeze_y;

always_comb ra_luma = {{block_count, mcu_count[0]}, (r_y_luma > y_size_m1) ? y_size_m1[3:0] : {mcu_count[1], mcu_line_count}, rptr[0]};
always_comb ra_chroma = {block_count, (r_y_chroma > (y_size_m1>>1)) ? y_size_m1[3:1] : mcu_line_count, rptr[0], mcu_count[0]};

always_comb r_x_luma  =  {{block_count, mcu_count[0]}, 3'b000};
always_comb r_y_luma  =  {block_v_count, {mcu_count[1], mcu_line_count}};

always_comb r_x_chroma  =  {block_count, 3'b000};
always_comb r_y_chroma  =  {block_v_count, mcu_line_count};

always_comb luma_gray_out_x = (r_x_luma>>3) > (x_size_m1>>3);  
always_comb luma_gray_out_y = (r_y_luma>>3) > (y_size_m1>>3);  
always_comb freeze_y = (mcu_count <= 3) ? (r_y_luma > y_size_m1) : (r_y_chroma > (y_size_m1>>1));

logic re_luma;
always_comb re_luma = !di_hold & !empty & mcu_count <= 3;

 
always @(posedge slow_clock) if (re_luma) luma_gray_out_z1 <= luma_gray_out_x | luma_gray_out_y;

`ifndef USE_LATTICE_EBR
dp_ram_be  #(
    .DW     (DW*8),
    .DEPTH  (2*Y_LINE_BUF_SIZE*Y_LINE_BUF_HEIGHT/8)
) y_buf (
    .wa     ({(yuvrgb_in_pixel_count >> 3), yuvrgb_in_line_count[3:0], wptr[0]}),
    .wd     ({8{yuvrgb_in[0] - JPEG_BIAS}}),             
    .wbe    ((yuvrgb_in_pixel_count==x_size_m1 ? '1 : 1) << (yuvrgb_in_pixel_count & 7)),
    .we     (yuvrgb_in_valid[0] & !yuvrgb_in_hold),
    .ra     (ra_luma),
    .re     (re_luma),
    .rd     (rd_y),
    .rclk   (slow_clock),
    .wclk   (clk)
);
`else
ram_dp_w64_b8_d2880_EBR y_buf (
    .wr_addr_i  ({(yuvrgb_in_pixel_count >> 3), yuvrgb_in_line_count[3:0], wptr[0]}), 
    .wr_data_i  ({8{yuvrgb_in[0] - JPEG_BIAS}}),             
    .ben_i      ((yuvrgb_in_pixel_count==x_size_m1 ? '1 : 1) << (yuvrgb_in_pixel_count & 7)),
    .wr_en_i    (yuvrgb_in_valid[0] & !yuvrgb_in_hold), 

    .rd_addr_i  (ra_luma), 
    .rd_en_i    (re_luma), 
    .rd_data_o  (rd_y), 
    .wr_clk_i   (clk), 
    .rd_clk_i   (slow_clock)
);
`endif  








logic [$clog2(2*2*UV_LINE_BUF_SIZE*UV_LINE_BUF_HEIGHT/8)-1:0] uv_buf_wa;
logic [7:0]         uv_buf_wbe;
logic [DW-1:0]      uv_buf_wd;
logic               uv_buf_we;

 





always_comb uv_buf_wa = {(yuvrgb_in_pixel_count >> 4), yuvrgb_in_line_count[3:1], wptr[0], yuvrgb_in_valid[2]};  
always_comb uv_buf_wd = (yuvrgb_in_valid[2] ? yuvrgb_in[2] : yuvrgb_in[1]) - JPEG_BIAS;  
always_comb uv_buf_wbe = ((yuvrgb_in_pixel_count >> 1) == (x_size_m1 >> 1) ? '1 : 1) << ((yuvrgb_in_pixel_count >> 1) & 7);
always_comb uv_buf_we = |yuvrgb_in_valid[2:1] & ~yuvrgb_in_hold;

`ifndef USE_LATTICE_EBR
dp_ram_be  #(
    .DW     (DW*8),
    .DEPTH  (2*2*UV_LINE_BUF_SIZE*UV_LINE_BUF_HEIGHT/8)
) uv_buf (
    .wa     (uv_buf_wa),
    .wd     ({8{uv_buf_wd}}),
    .wbe    (uv_buf_wbe),
    .we     (uv_buf_we),
    .ra     (ra_chroma),
    .re     (!di_hold & !empty & mcu_count > 3 ),
    .rd     (rd_uv),
    .rclk   (slow_clock),
    .wclk   (clk)
);
`else
ram_dp_w64_b8_d1440_EBR uv_buf (
    .wr_addr_i  (uv_buf_wa),
    .wr_data_i  ({8{uv_buf_wd}}),
    .ben_i      (uv_buf_wbe),
    .wr_en_i    (uv_buf_we),

    .rd_addr_i  (ra_chroma), 
    .rd_en_i    (!di_hold & !empty & mcu_count > 3), 
    .rd_data_o  (rd_uv), 
    .wr_clk_i   (clk), 
    .rd_clk_i   (slow_clock)
);
`endif  


always @(posedge slow_clock)
if (!di_hold & !empty)
    mcu_count_0 <= mcu_count;

always_comb 
    for (int i=0; i<8; i++)
        di[i] = mcu_count_0 < 4 ? luma_gray_out_z1? 0 : rd_y[i*8 +: 8] : rd_uv[i*8 +: 8];

always @(posedge slow_clock)
if (!slow_reset_n) 
    di_valid <= 0;
else if (!di_hold)
    di_valid <= !empty;

always @(posedge slow_clock)
if (!di_hold & !empty)
    di_cnt <= mcu_line_count;

endmodule
