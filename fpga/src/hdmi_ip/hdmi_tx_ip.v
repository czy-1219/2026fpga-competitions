 










`timescale 1 ps / 1ps
module hdmi_tx_ip
(
	input           pixelclk,        
	input           pixelclk5x,      
	input           rstin,           
	input[7:0]      blue_din,        
	input[7:0]      green_din,       
	input[7:0]      red_din,         
	input           hsync,           
	input           vsync,           
	input           de,              




	output [2:0]    data_p_h,
	output [2:0]    data_p_l,
	output 		    clk_p_h ,
	output 		    clk_p_l ,
	output [2:0]    data_n_h,
	output [2:0]    data_n_l,
	output 		    clk_n_h ,
	output 		    clk_n_l ,
	
	output 	[9:0] 	txc_o, 
	output 	[9:0] 	txd0_o, 
	output 	[9:0] 	txd1_o, 
	output 	[9:0] 	txd2_o
);

wire    [9:0]   red ;
wire    [9:0]   green ;
wire    [9:0]   blue ;

	
	wire 	[3:0] 	w_ctl = 4'b0000; 
	
	tmds_channel enc_0 (
		.clk_pixel			(pixelclk),
		.video_data			(blue_din),
		.data_island_data		(0),
		.control_data		({vsync, hsync}),
		.mode				({3'b0, de}),   
		.tmds				(blue)
	);
	tmds_channel enc_1 (
		.clk_pixel			(pixelclk),
		.video_data			(green_din),
		.data_island_data		(0),
		.control_data		(w_ctl[1:0]),
		.mode				({3'b0, de}),   
		.tmds				(green)
	);
	tmds_channel enc_2 (
		.clk_pixel			(pixelclk),
		.video_data			(red_din),
		.data_island_data		(0),
		.control_data		(w_ctl[3:2]),
		.mode				({3'b0, de}),   
		.tmds				(red)
	);

	 


























serdes_4b_10to1 serdes_4b_10to1_m0(
	.clk         (pixelclk        ), 
	.clkx5       (pixelclk5x      ), 
	.data_b      (blue            ), 
	.data_g      (green           ), 
	.data_r      (red             ), 
	.data_c      (10'b1111100000  ), 
	.dataout_h 	 (), 
	.dataout_l 	 (), 
	.clk_h 		 (), 
	.clk_l  	 (), 

	.data_p_h	(data_p_h),
	.data_p_l	(data_p_l),
	.clk_p_h 	(clk_p_h ),
	.clk_p_l 	(clk_p_l ),
	.data_n_h	(data_n_h),
	.data_n_l	(data_n_l),
	.clk_n_h 	(clk_n_h ),
	.clk_n_l 	(clk_n_l )
  ) ; 

	assign txc_o = 10'b1111100000;
	assign txd0_o = blue;
	assign txd1_o = green;
	assign txd2_o = red; 

endmodule
