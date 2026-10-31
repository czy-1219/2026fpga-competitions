/*
 * Top level for JPEG Encoder + ISP
 *
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
 module jpeg_encoder #(
    parameter DW = 8,
    parameter MCU_INPUT = 0,
    parameter SENSOR_X_SIZE    = 720,  
    parameter SENSOR_Y_SIZE    = 720
)(
    input   logic               start_capture_in,

    input   logic [9:0]         red_data_in,
    input   logic [9:0]         green_data_in,
    input   logic [9:0]         blue_data_in,    
    input   logic               frame_valid_in,
    input   logic               line_valid_in,
    input   logic               pixel_valid_in,

    output  logic [31:0]        data_out,            
    output  logic [19:0]        address_out,         
    output  logic               image_valid_out,     
    output  logic               data_valid_out,      
    output  logic               data_last_out,
    output  logic               pixel_ready_out,
    input   logic               data_ready_in,

    input   logic[2:0]          qf_select_in,        
    input   logic[$clog2(SENSOR_X_SIZE)-1:0] x_size_in,
    input   logic[$clog2(SENSOR_Y_SIZE)-1:0] y_size_in,

    input   logic               pixel_clock_in,
    input   logic               pixel_reset_n_in,
    input   logic               jpeg_fast_clock_in,
    input   logic               jpeg_fast_reset_n_in,
    input   logic               jpeg_slow_clock_in,
    input   logic               jpeg_slow_reset_n_in
);

 
logic               clk_x22;
logic               resetn_x22;

logic               slow_clock;
logic               slow_reset_n;

 
enum logic [2:0] {IDLE, RESET, WAIT_FOR_FRAME_START, COMPRESS, IMAGE_VALID} state;
logic               jpeg_reset_n;
logic               jpeg_en;

 
logic[$clog2(SENSOR_X_SIZE)-1:0] x_size_m1;
logic[$clog2(SENSOR_Y_SIZE)-1:0] y_size_m1;

 
logic signed[DW-1:0] di[7:0]; 
logic               di_valid;
logic               di_hold;
logic [2:0]         di_cnt;
logic               rgb24_hold;

 
logic [31:0]        out_data, out_data_rr;
logic               out_tlast, out_valid, out_hold;

 
always_comb clk_x22 = jpeg_fast_clock_in;
reset_sync reset_sync_x22 (.clock_in(clk_x22), .async_reset_n_in(jpeg_fast_reset_n_in & jpeg_reset_n), .sync_reset_n_out(resetn_x22));

 
always_comb slow_clock = jpeg_slow_clock_in;
reset_sync reset_sync_slow (.clock_in(slow_clock), .async_reset_n_in(jpeg_slow_reset_n_in & jpeg_reset_n), .sync_reset_n_out(slow_reset_n));

 
logic compress_2_image_valid;
psync1 psync_fsm (
    .in             (out_valid & ~out_hold & out_tlast), 
    .in_clk         (slow_clock), 
    .in_reset_n     (slow_reset_n), 
    .out            (compress_2_image_valid), 
    .out_clk        (pixel_clock_in), 
    .out_reset_n    (pixel_reset_n_in & jpeg_reset_n)
);

 
always @(posedge pixel_clock_in)
if (!pixel_reset_n_in)
    state <= IDLE;
else 
    case(state)
    RESET:                  if (~frame_valid_in) state <= WAIT_FOR_FRAME_START;      
    WAIT_FOR_FRAME_START:   if (frame_valid_in) state <= COMPRESS;                   
    COMPRESS:               if (compress_2_image_valid) state <= IMAGE_VALID;        
    default:                if (start_capture_in) state <= RESET;                    
    endcase        

always_comb jpeg_reset_n    = ~(state == RESET);
 

always_comb jpeg_en         = state == WAIT_FOR_FRAME_START | state == COMPRESS;
always_comb image_valid_out = state == IMAGE_VALID;

 
always_comb x_size_m1 = x_size_in - 1;
always_comb y_size_m1 = y_size_in - 1;

 
jisp #(
    .SENSOR_X_SIZE      (MCU_INPUT ? 32 : SENSOR_X_SIZE),
    .SENSOR_Y_SIZE      (MCU_INPUT ? 32 : SENSOR_Y_SIZE)
) jisp (
    .x_size_m1         (MCU_INPUT ? 5'd15 : x_size_m1),
    .y_size_m1         (MCU_INPUT ? 5'd15 : y_size_m1),
    .rgb24              ('{blue_data_in[9:2], green_data_in[9:2], red_data_in[9:2]}),
    .rgb24_valid        (jpeg_en & pixel_valid_in),
    .frame_valid_in     (jpeg_en & frame_valid_in),
    .line_valid_in      (jpeg_en & line_valid_in),
    .rgb24_hold         (rgb24_hold),

    .clk                (pixel_clock_in),
    .resetn             (pixel_reset_n_in & jpeg_reset_n),
    .*
);

jenc #(
    .SENSOR_X_SIZE      (SENSOR_X_SIZE),
    .SENSOR_Y_SIZE      (SENSOR_Y_SIZE)
) jenc (
    .qf_select          (qf_select_in),

    .clk                (slow_clock),
    .resetn             (slow_reset_n),
    .*
);

 
logic frame_start;
psync1 psync_frame_start (
    .in             (state==WAIT_FOR_FRAME_START & frame_valid_in), 
    .in_clk         (pixel_clock_in), 
    .in_reset_n     (pixel_reset_n_in & jpeg_reset_n), 
    .out            (frame_start), 
    .out_clk        (slow_clock), 
    .out_reset_n    (slow_reset_n)
);

 
logic [19:0]        size;
always @(posedge slow_clock)
if (frame_start)
    size <= 0;
else if (out_valid & ~out_hold)
    size <= size + 4;

 
always_comb
    for(int i=0; i<4; i++)
        data_out[8*i +: 8] = out_data[8*(3-i) +: 8];    
always_comb address_out = size;
always_comb data_valid_out = out_valid;
always_comb data_last_out = out_tlast;
 

always_comb pixel_ready_out = jpeg_en & ~rgb24_hold;
always_comb out_hold = ~data_ready_in;

endmodule
