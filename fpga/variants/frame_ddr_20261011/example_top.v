`timescale 1ns/1ps
`include "rtl_custom/processing/model_flash_reader.v"

 
`include "rtl_custom/uart/uart_rx_byte.v"
	`include "rtl_custom/uart/uart_tx_byte.v"
	`include "rtl_custom/processing/scan_rgb565_pixel.v"
	`include "rtl_custom/capture/frame_capture_ctrl.v"
	`include "rtl_custom/capture/frame_uart_sender.v"
	`include "rtl_custom/processing/frame_pixel_processor.v"
`include "rtl_custom/processing/scan_bw_ddr_engine.v"
`include "variants/frame_ddr_20261011/axi4_ctrl_capture.v"
`include "variants/frame_ddr_20261011/axi_host_frame_writer.v"
`include "rtl_custom/prototypes/student_pipeline/student_serial_mac.v"
`include "rtl_custom/prototypes/student_hardware/student_requantize.v"
`include "rtl_custom/prototypes/student_pipeline/student_cached_dot.v"
`include "rtl_custom/prototypes/student_hardware/student_conv_walk.v"
`include "rtl_custom/prototypes/student_overlap/student_overlap_conv.v"
`include "rtl_custom/prototypes/student_hardware/student_residual_add.v"
`include "variants/student_overlap_20261007/compact_student_tile.v"
`include "variants/frame_ddr_20261011/compact_student_registers.v"
`include "variants/frame_ddr_20261011/student_frame_tile_scheduler.v"
`include "variants/frame_ddr_20261011/student_frame_full_engine.v"
`include "variants/frame_ddr_20261011/fpga_spi_control.v"
`include "variants/native_upload_20261011/spi_frame_upload_receiver.v"
`include "rtl_custom/spi/upload_fifo_ready.v"
`include "rtl_custom/jpeg/jpeg_q50_header_rom.v"
`include "rtl_custom/jpeg/jpeg_stream_transport.sv"
`include "rtl_custom/jpeg/jpeg_mcu_reader.sv"
`include "rtl_custom/jpeg/axi_single_request.v"
`include "rtl_custom/jpeg/jpeg_frame_pipeline.sv"


`include "variants/frame_ddr_20261011/portrait_memory_arbiter.v"
`include "rtl_custom/student_portrait/portrait_byte_memory.v"
`include "rtl_custom/student_portrait/portrait_axi_network.v"
`include "rtl_custom/student_portrait/portrait_network_engine.v"
`include "rtl_custom/student_portrait/portrait_serviced_conv.v"
`include "rtl_custom/student_portrait/portrait_runtime_conv.v"
`include "rtl_custom/student_portrait/portrait_runtime_walk.v"
`include "rtl_custom/student_portrait/portrait_requantize_single.v"
`include "rtl_custom/student_portrait/portrait_parameter_service.v"
`include "rtl_custom/student_portrait/portrait_weight_service.v"
`include "variants/frame_ddr_20261011/portrait_register_endpoint.v"

module example_top 
(
	 


	input 			clk_24m,			 
	input 			clk_25m,			 




	output 			sys_pll_rstn_o, 		
	
	input 			clk_sys,			 
	input 			clk_pixel,			 
	input 			clk_pixel_2x,		 
	input 			clk_pixel_10x,		 
	
	input 			sys_pll_lock,		 



	output 			dsi_pll_rstn_o,
	
	input 			dsi_refclk_i,		 
	input 			dsi_byteclk_i,		 
	input 			dsi_serclk_i,		 
	input 			dsi_txcclk_i,		 
	
	input 			dsi_pll_lock,
	
	 

	output 			ddr_pll_rstn_o, 
	
	input 			tdqss_clk,			
	input 			core_clk,			 
	input 			tac_clk,			
	input 			twd_clk,			
	
	input 			ddr_pll_lock,		 



	output 	[2:0] 	shift,
	output 	[4:0] 	shift_sel,
	output 			shift_ena,
	
	
	
	 

	output 			lvds_pll_rstn_o, 
	
	input 			clk_lvds_1x, 
	input 			clk_lvds_7x, 
	input 			clk_27m, 			 
	input 			clk_54m, 			 
	
	input 			lvds_pll_lock, 
	
	
	
	 

	output 	[15:0] 	addr,
	output 	[2:0] 	ba,
	output 			we,
	output 			reset,
	output 			ras,
	output 			cas,
	output 			odt,
	output 			cke,
	output 			cs,
	
	 
	input 	[15:0] 	i_dq_hi,
	input 	[15:0] 	i_dq_lo,
	
	output 	[15:0] 	o_dq_hi,
	output 	[15:0] 	o_dq_lo,
	output 	[15:0] 	o_dq_oe,
	
	 
	output 	[1:0] 	o_dm_hi,
	output 	[1:0] 	o_dm_lo,
	
	 
	input 	[1:0] 	i_dqs_hi,
	input 	[1:0] 	i_dqs_lo,
	
	input 	[1:0] 	i_dqs_n_hi,
	input 	[1:0] 	i_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_hi,
	output 	[1:0] 	o_dqs_lo,
	
	output 	[1:0] 	o_dqs_n_hi,
	output 	[1:0] 	o_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_oe,
	output 	[1:0] 	o_dqs_n_oe,
	
	 
	output 			clk_p_hi, 
	output 			clk_p_lo, 
	output 			clk_n_hi, 
	output 			clk_n_lo, 
	
	
	
	 

	output 			csi_ctl0_o,
	output 			csi_ctl0_oe,
	input 			csi_ctl0_i,
	
	output 			csi_ctl1_o,
	output 			csi_ctl1_oe,
	input 			csi_ctl1_i,
	
	output 			csi_scl_o,
	output 			csi_scl_oe,
	input 			csi_scl_i,
	
	output 			csi_sda_o,
	output 			csi_sda_oe,
	input 			csi_sda_i,
	
	 
	input 			csi_rxc_lp_p_i,
	input 			csi_rxc_lp_n_i,
	output 			csi_rxc_hs_en_o,
	output 			csi_rxc_hs_term_en_o,
	input 			csi_rxc_i,
	
	 
	output 			csi_rxd0_rst_o,
	output 			csi_rxd0_hs_en_o,
	output 			csi_rxd0_hs_term_en_o,
	
	input 			csi_rxd0_lp_p_i,
	input 			csi_rxd0_lp_n_i,
	input 	[7:0] 	csi_rxd0_hs_i,
	
	 
	output 			csi_rxd1_rst_o,
	output 			csi_rxd1_hs_en_o,
	output 			csi_rxd1_hs_term_en_o,
	
	input 			csi_rxd1_lp_n_i,
	input 			csi_rxd1_lp_p_i,
	input 	[7:0] 	csi_rxd1_hs_i,
	
	 
	output 			csi_rxd2_rst_o,
	output 			csi_rxd2_hs_en_o,
	output 			csi_rxd2_hs_term_en_o,
	
	input 			csi_rxd2_lp_p_i,
	input 			csi_rxd2_lp_n_i,
	input 	[7:0] 	csi_rxd2_hs_i,
	
	 
	output 			csi_rxd3_rst_o,
	output 			csi_rxd3_hs_en_o,
	output 			csi_rxd3_hs_term_en_o,
	
	input 			csi_rxd3_lp_p_i,
	input 			csi_rxd3_lp_n_i,
	input 	[7:0] 	csi_rxd3_hs_i,
	
	 












	output 			dsi_pwm_o,			 
	output 			dsi_resetn_o,		 


	output 			dsi_txc_rst_o,
	output 			dsi_txc_lp_p_oe,
	output 			dsi_txc_lp_p_o,
	output 			dsi_txc_lp_n_oe,
	output 			dsi_txc_lp_n_o,
	output 			dsi_txc_hs_oe,
	output 	[7:0] 	dsi_txc_hs_o,
	
	output 			dsi_txd0_rst_o,
	output 			dsi_txd0_hs_oe,
	output 	[7:0] 	dsi_txd0_hs_o,
	output 			dsi_txd0_lp_p_oe,
	output 			dsi_txd0_lp_p_o,
	output 			dsi_txd0_lp_n_oe,
	output 			dsi_txd0_lp_n_o,
	
	output 			dsi_txd1_rst_o,
	output 			dsi_txd1_lp_p_oe,
	output 			dsi_txd1_lp_p_o,
	output 			dsi_txd1_lp_n_oe,
	output 			dsi_txd1_lp_n_o,
	output 			dsi_txd1_hs_oe,
	output 	[7:0] 	dsi_txd1_hs_o,
	
	output 			dsi_txd2_rst_o,
	output 			dsi_txd2_lp_p_oe,
	output 			dsi_txd2_lp_p_o,
	output 			dsi_txd2_lp_n_oe,
	output 			dsi_txd2_lp_n_o,
	output 			dsi_txd2_hs_oe,
	output 	[7:0] 	dsi_txd2_hs_o,
	
	output 			dsi_txd3_rst_o,
	output 			dsi_txd3_lp_p_oe,
	output 			dsi_txd3_lp_p_o,
	output 			dsi_txd3_lp_n_oe,
	output 			dsi_txd3_lp_n_o,
	output 			dsi_txd3_hs_oe,
	output 	[7:0] 	dsi_txd3_hs_o,
	
	input 			dsi_txd0_lp_p_i,
	input 			dsi_txd0_lp_n_i,
	input 			dsi_txd1_lp_p_i,
	input 			dsi_txd1_lp_n_i,
	input 			dsi_txd2_lp_p_i,
	input 			dsi_txd2_lp_n_i,
	input 			dsi_txd3_lp_p_i,
	input 			dsi_txd3_lp_n_i,
	
	
	 

	input 		 	uart_rx_i,			 
	output 		 	uart_tx_o, 
	
	
	output 	[5:0] 	led_o,			 




	output 			cmos_sclk,
	input 			cmos_sdat_IN,
	output 			cmos_sdat_OUT,
	output 			cmos_sdat_OE,
	
	 
	input 			cmos_pclk,
	input 			cmos_vsync,
	input 			cmos_href,
	input 	[7:0] 	cmos_data,
	
	output 			cmos_ctl1_o, 
	output 			cmos_ctl1_oe, 
	input 			cmos_ctl1_i,
	output 			cmos_ctl2_o,
	output 			cmos_ctl2_oe, 
	input 			cmos_ctl2_i, 
	output 			cmos_ctl3_o,
	output 			cmos_ctl3_oe, 
	input 			cmos_ctl3_i, 
	
	
	 

	output 			hdmi_txc_oe,
	output 			hdmi_txd0_oe,
	output 			hdmi_txd1_oe,
	output 			hdmi_txd2_oe,
	
	output 			hdmi_txc_rst_o,
	output 			hdmi_txd0_rst_o,
	output 			hdmi_txd1_rst_o,
	output 			hdmi_txd2_rst_o,
	
	output 	[9:0] 	hdmi_txc_o,
	output 	[9:0] 	hdmi_txd0_o,
	output 	[9:0] 	hdmi_txd1_o,
	output 	[9:0] 	hdmi_txd2_o,
	
	
	 

	output 			lvds_txc_oe,
	output 	[6:0] 	lvds_txc_o,
	output 			lvds_txc_rst_o,
	
	output 			lvds_txd0_oe,
	output 	[6:0] 	lvds_txd0_o,
	output 			lvds_txd0_rst_o,
	
	output 			lvds_txd1_oe,
	output 	[6:0] 	lvds_txd1_o,
	output 			lvds_txd1_rst_o,
	
	output 			lvds_txd2_oe,
	output 	[6:0] 	lvds_txd2_o,
	output 			lvds_txd2_rst_o,
	
	output 			lvds_txd3_oe,
	output 	[6:0] 	lvds_txd3_o,
	output 			lvds_txd3_rst_o,
	
	
	 

	output 			lcd_tp_sda_o,		 
	output 			lcd_tp_sda_oe,
	input 			lcd_tp_sda_i,
	
	output 			lcd_tp_scl_o,		 
	output 			lcd_tp_scl_oe,
	input 			lcd_tp_scl_i,
	
	output 			lcd_tp_int_o,		 
	output 			lcd_tp_int_oe,
	input 			lcd_tp_int_i,
	
	output 			lcd_tp_rst_o,		 
	
	output 			lcd_pwm_o,			 
	output 			lcd_blen_o,
	
	 
	output 			lcd_vs_o,			 
	output 			lcd_hs_o,			 
	output 			lcd_de_o,			 

	output 	[7:0] 	lcd_b7_0_o,			 
	output 	[7:0] 	lcd_g7_0_o,			 
	output 	[7:0] 	lcd_r7_0_o,			 
	
	output 	[7:0] 	lcd_b7_0_oe,		 
	output 	[7:0] 	lcd_g7_0_oe,		 
	output 	[7:0] 	lcd_r7_0_oe,		 

	input 	[7:0] 	lcd_b7_0_i,			 
	input 	[7:0] 	lcd_g7_0_i,			 
	input 	[7:0] 	lcd_r7_0_i,			 


	output 			spi_sck_o, 
	output 			spi_ssn_o 			
);

reg [1:0] r_resolution_select = 2'd0;
	
	wire 			csi_rxd0_fifo_rd_o; 
	wire 			csi_rxd0_fifo_empty_i = 0;  
	wire 			csi_rxd1_fifo_rd_o;  
	wire 			csi_rxd1_fifo_empty_i = 0;  
	wire 			csi_rxd2_fifo_rd_o;  
	wire 			csi_rxd2_fifo_empty_i = 0;  
	wire 			csi_rxd3_fifo_rd_o;  
	wire 			csi_rxd3_fifo_empty_i = 0;  
	
	
	parameter 	SIM_DATA 	= 0; 
	
	 
	assign clk_p_hi = 1'b0;	 
	assign clk_p_lo = 1'b1;
	assign clk_n_hi = 1'b1;
	assign clk_n_lo = 1'b0; 
	
	assign cmos_ctl1_o = 0; 
	assign cmos_ctl1_oe = 1; 
	assign cmos_ctl2_o = 0; 
	assign cmos_ctl2_oe = 1; 
	assign cmos_ctl3_o = 0; 
	assign cmos_ctl3_oe = 1; 
	
	 
	assign sys_pll_rstn_o = 1'b1; 	 
	
	assign dsi_pll_rstn_o = sys_pll_lock; 
	assign ddr_pll_rstn_o = sys_pll_lock; 
	assign lvds_pll_rstn_o = sys_pll_lock; 
	
	wire 			w_pll_lock = sys_pll_lock && dsi_pll_lock && ddr_pll_lock && lvds_pll_lock; 
	
	 
	reg 			rstn_sys = 0, rstn_pixel = 0; 
	wire 			rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel; 
	
	reg 			rstn_dsi_refclk = 0, rstn_dsi_byteclk = 0; 
	wire 			rst_dsi_refclk = ~rstn_dsi_refclk, rst_dsi_byteclk = ~rstn_dsi_byteclk; 
	
	reg 			rstn_lvds_1x = 0; 
	wire 			rst_lvds_1x = ~rstn_lvds_1x; 
	
	reg 			rstn_27m = 0, rstn_54m = 0; 
	wire 			rst_27m = ~rstn_27m, rst_54m = ~rstn_54m; 
	
	 
	always @(posedge clk_27m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_27m <= 0; else rstn_27m <= 1; end
	always @(posedge clk_54m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_54m <= 0; else rstn_54m <= 1; end
	always @(posedge clk_sys or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
	always @(posedge clk_pixel or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end
	always @(posedge dsi_refclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_refclk <= 0; else rstn_dsi_refclk <= 1; end
	always @(posedge dsi_byteclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_byteclk <= 0; else rstn_dsi_byteclk <= 1; end
	always @(posedge clk_lvds_1x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_lvds_1x <= 0; else rstn_lvds_1x <= 1; end
	
	
	localparam 	CLOCK_MAIN 	= 96000000; 	 







	
	wire 			w_ustick, w_mstick; 
	
	wire  [7:0] 	w_dev_index_o;  
	wire  [7:0] 	w_dev_cmd_o;  
	wire  [31:0] 	w_dev_wdata_o;  
	wire  		w_dev_wvalid_o;  
	wire  		w_dev_rvalid_o;  
	wire 	[31:0] 	w_dev_rdata_i;  
	
	wire 			w_spi_ssn_o, w_spi_sck_o; 
	wire 	[3:0] 	w_spi_data_o, w_spi_data_oe; 
	wire 	[3:0] 	w_spi_data_i; 
	
	 
	reg 			r_flash_en = 0; 		 
	
	always @(posedge clk_sys) begin
		r_flash_en <= (w_dev_wvalid_o && (w_dev_index_o == 8'h00) && (w_dev_cmd_o == 8'h00)) ? w_dev_wdata_o : r_flash_en; 
	end
	
	
	
	
	 


	
	wire 	[7:0] 	w_lcd_b_o, w_lcd_g_o, w_lcd_r_o; 
	
	wire w_model_flash_active;
	wire w_flash_pin_owner = r_flash_en || w_model_flash_active;
	assign lcd_b7_0_o = w_flash_pin_owner ? {4'b0, w_spi_data_o[3:2], 2'b0} : w_lcd_b_o;
	assign lcd_g7_0_o = w_flash_pin_owner ? {6'h0, w_spi_data_o[1:0]} : w_lcd_g_o;
	assign lcd_r7_0_o = w_flash_pin_owner ? {8'h00} : w_lcd_r_o;
	
	assign lcd_b7_0_oe = w_flash_pin_owner ? {4'b0, w_spi_data_oe[3:2], 2'b0} : 8'hFF;
	assign lcd_g7_0_oe = w_flash_pin_owner ? {6'h0, w_spi_data_oe[1:0]} : 8'hFF;
	assign lcd_r7_0_oe = w_flash_pin_owner ? {8'h00} : 8'hFF;
	
	assign spi_sck_o = w_spi_sck_o; 
	assign spi_ssn_o = w_spi_ssn_o; 
	assign w_spi_data_i = {lcd_b7_0_i[3:2], lcd_g7_0_i[1:0]}; 
	
	
	
	
	
	
	
	 


	wire			w_ddr3_ui_clk = clk_sys;
	wire			w_ddr3_ui_rst = rst_sys;
	wire			w_ddr3_ui_areset = rst_sys;
	wire			w_ddr3_ui_aresetn = rstn_sys;
	

	 
	wire	[3:0] 	w_ddr3_awid;
	wire	[31:0]	w_ddr3_awaddr;
	wire	[7:0]		w_ddr3_awlen;
	wire			w_ddr3_awvalid;
	wire			w_ddr3_awready;
	
	wire 	[3:0]  	w_ddr3_wid;
	wire 	[127:0] 	w_ddr3_wdata;
	wire 	[15:0]	w_ddr3_wstrb;
	wire			w_ddr3_wlast;
	wire			w_ddr3_wvalid;
	wire			w_ddr3_wready;
	
	wire 	[3:0] 	w_ddr3_bid;
	wire 	[1:0] 	w_ddr3_bresp;
	wire			w_ddr3_bvalid;
	wire			w_ddr3_bready;
	 

	wire [31:0] w_camera_awaddr;
	wire [7:0]  w_camera_awlen;
	wire        w_camera_awvalid;
	wire        w_camera_awready;
	wire [127:0] w_camera_wdata;
	wire [15:0] w_camera_wstrb;
	wire        w_camera_wlast;
	wire        w_camera_wvalid;
	wire        w_camera_wready;
	wire        w_camera_bvalid;
	wire [1:0]  w_camera_bresp;
	wire [31:0] w_host_awaddr;
	wire [7:0]  w_host_awlen;
	wire        w_host_awvalid;
	wire        w_host_awready;
	wire [127:0] w_host_wdata;
	wire [15:0] w_host_wstrb;
	wire        w_host_wlast;
	wire        w_host_wvalid;
	wire        w_host_wready;
	wire        w_host_bvalid;
	
	wire	[3:0] 	w_ddr3_arid;
	wire	[31:0]	w_ddr3_araddr;
	wire	[7:0]		w_ddr3_arlen;
	wire			w_ddr3_arvalid;
	wire			w_ddr3_arready;
	
	wire 	[3:0] 	w_ddr3_rid;
	wire 	[127:0] 	w_ddr3_rdata;
	wire			w_ddr3_rlast;
	wire			w_ddr3_rvalid;
	wire			w_ddr3_rready;
	wire 	[1:0] 	w_ddr3_rresp;
	
	
	 
	wire 	[3:0] 	w_ddr3_aid;
	wire 	[31:0] 	w_ddr3_aaddr;
	wire 	[7:0]  	w_ddr3_alen;
	wire 	[2:0]  	w_ddr3_asize;
	wire 	[1:0]  	w_ddr3_aburst;
	wire 	[1:0]  	w_ddr3_alock;
	wire			w_ddr3_avalid;
	wire			w_ddr3_aready;
	wire			w_ddr3_atype;
	
	wire 			w_ddr3_cal_done, w_ddr3_cal_pass; 
	
	 
	reg 			r_ddr_unlock = 0; 
	always @(posedge w_ddr3_ui_clk or negedge w_ddr3_ui_aresetn) begin
		if(~w_ddr3_ui_aresetn)
			r_ddr_unlock <= 0; 
		else
			r_ddr_unlock <= w_ddr3_cal_done; 
	end
	
	DdrCtrl ddr3_ctl_axi (	
		.core_clk		(core_clk),
		.tac_clk		(tac_clk),
		.twd_clk		(twd_clk),	
		.tdqss_clk		(tdqss_clk),
		
		.reset		(reset),
		.cs			(cs),
		.ras			(ras),
		.cas			(cas),
		.we			(we),
		.cke			(cke),    
		.addr			(addr),
		.ba			(ba),
		.odt			(odt),
		
		.o_dm_hi		(o_dm_hi),
		.o_dm_lo		(o_dm_lo),
		
		.i_dq_hi		(i_dq_hi),
		.i_dq_lo		(i_dq_lo),
		.o_dq_hi		(o_dq_hi),
		.o_dq_lo		(o_dq_lo),
		.o_dq_oe		(o_dq_oe),
		
		.i_dqs_hi		(i_dqs_hi),
		.i_dqs_lo		(i_dqs_lo),
		.i_dqs_n_hi		(i_dqs_n_hi),
		.i_dqs_n_lo		(i_dqs_n_lo),
		.o_dqs_hi		(o_dqs_hi),
		.o_dqs_lo		(o_dqs_lo),
		.o_dqs_n_hi		(o_dqs_n_hi),
		.o_dqs_n_lo		(o_dqs_n_lo),
		.o_dqs_oe		(o_dqs_oe),
		.o_dqs_n_oe		(o_dqs_n_oe),
		
		.clk			(w_ddr3_ui_clk),
		.reset_n		(w_ddr3_ui_aresetn),
		
		.axi_avalid		(w_ddr3_avalid),	 
		.axi_aready		(w_ddr3_aready),
		.axi_aaddr		(w_ddr3_aaddr),
		.axi_aid		(w_ddr3_aid),
		.axi_alen		(w_ddr3_alen),
		.axi_asize		(w_ddr3_asize),
		.axi_aburst		(w_ddr3_aburst),
		.axi_alock		(w_ddr3_alock),
		.axi_atype		(w_ddr3_atype),
		
		.axi_wid		(w_ddr3_wid),
		.axi_wvalid		(w_ddr3_wvalid),
		.axi_wready		(w_ddr3_wready),
		.axi_wdata		(w_ddr3_wdata),
		.axi_wstrb		(w_ddr3_wstrb),
		.axi_wlast		(w_ddr3_wlast),
		
		.axi_bvalid		(w_ddr3_bvalid),
		.axi_bready		(w_ddr3_bready),
		.axi_bid		(w_ddr3_bid),
		.axi_bresp		(w_ddr3_bresp),
		
		.axi_rvalid		(w_ddr3_rvalid),
		.axi_rready		(w_ddr3_rready),
		.axi_rdata		(w_ddr3_rdata),
		.axi_rid		(w_ddr3_rid),
		.axi_rresp		(w_ddr3_rresp),
		.axi_rlast		(w_ddr3_rlast),
		
		.shift		(shift),
		.shift_sel		(),
		.shift_ena		(shift_ena),
		
		.cal_ena		(1'b1),
		.cal_done		(w_ddr3_cal_done),
		.cal_pass		(w_ddr3_cal_pass)
	);
	

    wire [31:0] w_legacy_awaddr,w_legacy_araddr,w_portrait_awaddr,w_portrait_araddr;
    wire [7:0] w_legacy_awlen,w_legacy_arlen;
    wire [127:0] w_legacy_wdata,w_portrait_wdata;
    wire [15:0] w_legacy_wstrb,w_portrait_wstrb;
    wire w_legacy_awvalid,w_legacy_awready,w_legacy_wlast,w_legacy_wvalid,w_legacy_wready,w_legacy_bvalid,w_legacy_bready;
    wire w_legacy_arvalid,w_legacy_arready,w_legacy_rvalid,w_legacy_rready;
    wire w_portrait_awvalid,w_portrait_awready,w_portrait_wlast,w_portrait_wvalid,w_portrait_wready,w_portrait_bvalid,w_portrait_bready;
    wire w_portrait_arvalid,w_portrait_arready,w_portrait_rvalid,w_portrait_rready;
    wire w_frame_busy,w_frame_done,w_frame_error,w_portrait_active,w_core_busy;
    wire w_frame_arvalid,w_frame_arready,w_frame_rvalid,w_frame_rready;
    wire w_frame_awvalid,w_frame_awready,w_frame_wvalid,w_frame_wready,w_frame_bvalid,w_frame_bready,w_frame_wlast;
    wire [31:0] w_frame_araddr,w_frame_awaddr;
    wire [127:0] w_frame_wdata;
    wire [15:0] w_frame_wstrb;
    wire [31:0] w_jpeg_araddr,w_jpeg_awaddr,w_jpeg_dump_base,w_jpeg_dump_size;
    wire [127:0] w_jpeg_wdata;
    wire [15:0] w_jpeg_wstrb;
    wire w_jpeg_arvalid,w_jpeg_awvalid,w_jpeg_wvalid,w_jpeg_rready,w_jpeg_bready,w_jpeg_dump_direct;
    wire [21:0] w_jpeg_size;
    wire [7:0] w_jpeg_diag;
    wire w_model_arready,w_model_rvalid,w_model_awready,w_model_wready,w_model_bvalid;
    assign w_frame_arready=!w_stream_claim && w_frame_busy && w_model_arready;
    assign w_portrait_arready=!w_stream_claim && !w_frame_busy && w_model_arready;
    assign w_frame_rvalid=!w_stream_claim && w_frame_busy && w_model_rvalid;
    assign w_portrait_rvalid=!w_stream_claim && !w_frame_busy && w_model_rvalid;
    assign w_frame_awready=!w_stream_claim && w_frame_busy && w_model_awready;
    assign w_portrait_awready=!w_stream_claim && !w_frame_busy && w_model_awready;
    assign w_frame_wready=!w_stream_claim && w_frame_busy && w_model_wready;
    assign w_portrait_wready=!w_stream_claim && !w_frame_busy && w_model_wready;
    assign w_frame_bvalid=!w_stream_claim && w_frame_busy && w_model_bvalid;
    assign w_portrait_bvalid=!w_stream_claim && !w_frame_busy && w_model_bvalid;
    wire w_model_memory_idle;
    portrait_memory_arbiter u_portrait_memory_arbiter (
        .model_idle_o(w_model_memory_idle),
        .clk_i(clk_sys),.rst_n_i(rstn_sys),
        .legacy_arvalid_i(w_legacy_arvalid),.legacy_arready_o(w_legacy_arready),.legacy_araddr_i(w_legacy_araddr),.legacy_arlen_i(w_legacy_arlen),.legacy_rvalid_o(w_legacy_rvalid),.legacy_rready_i(w_legacy_rready),
        .legacy_awvalid_i(w_legacy_awvalid),.legacy_awready_o(w_legacy_awready),.legacy_awaddr_i(w_legacy_awaddr),.legacy_awlen_i(w_legacy_awlen),
        .legacy_wvalid_i(w_legacy_wvalid),.legacy_wready_o(w_legacy_wready),.legacy_wdata_i(w_legacy_wdata),.legacy_wstrb_i(w_legacy_wstrb),.legacy_wlast_i(w_legacy_wlast),.legacy_bvalid_o(w_legacy_bvalid),.legacy_bready_i(w_legacy_bready),
        .model_arvalid_i(w_stream_claim ? w_jpeg_arvalid : w_frame_busy ? w_frame_arvalid : w_portrait_arvalid),.model_arready_o(w_model_arready),.model_araddr_i(w_stream_claim ? w_jpeg_araddr : w_frame_busy ? w_frame_araddr : w_portrait_araddr),.model_rvalid_o(w_model_rvalid),.model_rready_i(w_stream_claim ? w_jpeg_rready : w_frame_busy ? w_frame_rready : w_portrait_rready),
        .model_awvalid_i(w_stream_claim ? w_jpeg_awvalid : w_frame_busy ? w_frame_awvalid : w_portrait_awvalid),.model_awready_o(w_model_awready),.model_awaddr_i(w_stream_claim ? w_jpeg_awaddr : w_frame_busy ? w_frame_awaddr : w_portrait_awaddr),
        .model_wvalid_i(w_stream_claim ? w_jpeg_wvalid : w_frame_busy ? w_frame_wvalid : w_portrait_wvalid),.model_wready_o(w_model_wready),.model_wdata_i(w_stream_claim ? w_jpeg_wdata : w_frame_busy ? w_frame_wdata : w_portrait_wdata),.model_wstrb_i(w_stream_claim ? w_jpeg_wstrb : w_frame_busy ? w_frame_wstrb : w_portrait_wstrb),.model_wlast_i(w_stream_claim ? 1'b1 : w_frame_busy ? w_frame_wlast : w_portrait_wlast),.model_bvalid_o(w_model_bvalid),.model_bready_i(w_stream_claim ? w_jpeg_bready : w_frame_busy ? w_frame_bready : w_portrait_bready),
        .arvalid_o(w_ddr3_arvalid),.arready_i(w_ddr3_arready && r_ddr_unlock),.araddr_o(w_ddr3_araddr),.arlen_o(w_ddr3_arlen),.rvalid_i(w_ddr3_rvalid),.rlast_i(w_ddr3_rlast),.rready_o(w_ddr3_rready),
        .awvalid_o(w_ddr3_awvalid),.awready_i(w_ddr3_awready && r_ddr_unlock),.awaddr_o(w_ddr3_awaddr),.awlen_o(w_ddr3_awlen),
        .wvalid_o(w_ddr3_wvalid),.wready_i(w_ddr3_wready),.wdata_o(w_ddr3_wdata),.wstrb_o(w_ddr3_wstrb),.wlast_o(w_ddr3_wlast),.bvalid_i(w_ddr3_bvalid),.bready_o(w_ddr3_bready));
	assign w_legacy_bready = 1'b1; 
	assign w_legacy_awaddr = w_upload_writer_active ? w_host_awaddr : w_camera_awaddr;
	assign w_legacy_awlen = w_upload_writer_active ? w_host_awlen : w_camera_awlen;
	assign w_legacy_awvalid = w_upload_writer_active ? w_host_awvalid : w_camera_awvalid;
	assign w_host_awready = w_upload_writer_active && w_legacy_awready;
	assign w_camera_awready = !w_upload_writer_active && w_legacy_awready;
	assign w_legacy_wdata = w_upload_writer_active ? w_host_wdata : w_camera_wdata;
	assign w_legacy_wstrb = w_upload_writer_active ? w_host_wstrb : w_camera_wstrb;
	assign w_legacy_wlast = w_upload_writer_active ? w_host_wlast : w_camera_wlast;
	assign w_legacy_wvalid = w_upload_writer_active ? w_host_wvalid : w_camera_wvalid;
	assign w_host_wready = w_upload_writer_active && w_legacy_wready;
	assign w_camera_wready = !w_upload_writer_active && w_legacy_wready;
	assign w_host_bvalid = w_upload_writer_active && w_legacy_bvalid;
	assign w_camera_bvalid = !w_upload_writer_active && w_legacy_bvalid;
	assign w_camera_bresp = w_ddr3_bresp;
	assign shift_sel = 5'b00100; 		 
	
	
	AXI4_AWARMux #(.AID_LEN(4), .AADDR_LEN(32)) axi4_awar_mux (
		.aclk_i			(w_ddr3_ui_clk), 
		.arst_i			(w_ddr3_ui_rst), 
		
		.awid_i			(w_ddr3_awid),
		.awaddr_i			(w_ddr3_awaddr),
		.awlen_i			(w_ddr3_awlen),
		.awvalid_i			(w_ddr3_awvalid && r_ddr_unlock),
		.awready_o			(w_ddr3_awready),
		
		.arid_i			(w_ddr3_arid),
		.araddr_i			(w_ddr3_araddr),
		.arlen_i			(w_ddr3_arlen),
		.arvalid_i			(w_ddr3_arvalid && r_ddr_unlock),
		.arready_o			(w_ddr3_arready),
		
		.aid_o			(w_ddr3_aid),
		.aaddr_o			(w_ddr3_aaddr),
		.alen_o			(w_ddr3_alen),
		.atype_o			(w_ddr3_atype),
		.avalid_o			(w_ddr3_avalid),
		.aready_i			(w_ddr3_aready)
	);
	
	assign w_ddr3_asize = 4; 		 
	assign w_ddr3_aburst = 1; 
	assign w_ddr3_alock = 0; 
	
	 











	wire            [ 7:0]          ov5640_i2c_config_index;
	wire            [23:0]          ov5640_i2c_config_data;
	wire            [ 7:0]          ov5640_i2c_config_size;
	wire                            ov5640_i2c_config_done;
	wire                            ov5640_i2c_nack_seen;
	wire            [7:0]           ov5640_i2c_first_nack_index;
	wire            [7:0]           ov5640_i2c_nack_count;
	wire            [15:0]          ov5640_i2c_rdata;                               
	reg             [19:0]          r_i2c_reconfig_count = 20'd0;
	reg                             r_i2c_reconfig_active = 1'b0;
	wire                            w_i2c_config_rst_n = rstn_sys && !r_i2c_reconfig_active;

	i2c_timing_ctrl_16bit
	#(
	    .CLK_FREQ           (CLOCK_MAIN),                               
	    .I2C_FREQ           (50_000    )                                
	) 
	u_i2c_timing_ctrl_16bit 
	(
	     
	    .clk                (clk_sys                 ),                           
	    .rst_n              (w_i2c_config_rst_n      ),                           


	    .i2c_sclk           (cmos_sclk                  ),                   
		.i2c_sdat_OUT 	(cmos_sdat_OUT), 
		.i2c_sdat_OE	(cmos_sdat_OE), 
		.i2c_sdat_IN 	(cmos_sdat_IN), 
		
	     
	    .i2c_config_index   (ov5640_i2c_config_index           ),                   
	    .i2c_config_data    ({8'h78, ov5640_i2c_config_data}   ),                   
	    .i2c_config_size    (ov5640_i2c_config_size            ),                   
	    .i2c_config_done    (ov5640_i2c_config_done            ),                   
	    .i2c_nack_seen      (ov5640_i2c_nack_seen              ),
	    .i2c_first_nack_index(ov5640_i2c_first_nack_index      ),
	    .i2c_nack_count     (ov5640_i2c_nack_count             ),
	    .i2c_rdata          (ov5640_i2c_rdata                  )                    
	);
	
	 

	I2C_OV5640_1280720_Config u_I2C_OV5640_1280720_Config
	(
	    .LUT_INDEX  (ov5640_i2c_config_index   ),
	    .CAMERA_PROFILE(w_camera_profile),.RESOLUTION_MODE (r_resolution_select),
	    .LUT_DATA   (ov5640_i2c_config_data    ),
	    .LUT_SIZE   (ov5640_i2c_config_size    )
	); 
	
	
	 




	
	wire 			w_cmos_pclk = cmos_pclk; 
	
	
	
	 
	reg 	[3:0]		r_cmos_fv_o = 0; 
	reg 	[1:0] 	r_cmos_rx_vsync0_in = 0; 
	reg 			r_camera_seen = 0;
	always @(posedge w_cmos_pclk) begin
		r_cmos_rx_vsync0_in <= {r_cmos_rx_vsync0_in, cmos_vsync}; 
		r_cmos_fv_o <= r_cmos_fv_o + ((r_cmos_rx_vsync0_in == 2'b01) ? 1 : 0); 
		if (r_cmos_rx_vsync0_in == 2'b01)
			r_camera_seen <= 1'b1;
	end
	assign led_o[5] = r_cmos_fv_o[3]; 

	 


	reg r_cam_diag_vsync_d = 1'b0;
	reg r_cam_diag_href_d = 1'b0;
	reg [15:0] r_cam_diag_line_bytes = 16'd0;
	reg [15:0] r_cam_diag_lines_work = 16'd0;
	reg [15:0] r_cam_diag_min_work = 16'hffff;
	reg [15:0] r_cam_diag_max_work = 16'd0;
	reg [15:0] r_cam_diag_frame_count = 16'd0;
	reg [15:0] r_cam_diag_line_count = 16'd0;
	reg [15:0] r_cam_diag_line_bytes_min = 16'd0;
	reg [15:0] r_cam_diag_line_bytes_max = 16'd0;
	always @(posedge w_cmos_pclk or negedge rstn_sys) begin
		if (!rstn_sys) begin
			r_cam_diag_vsync_d <= 1'b0;
			r_cam_diag_href_d <= 1'b0;
			r_cam_diag_line_bytes <= 16'd0;
			r_cam_diag_lines_work <= 16'd0;
			r_cam_diag_min_work <= 16'hffff;
			r_cam_diag_max_work <= 16'd0;
			r_cam_diag_frame_count <= 16'd0;
			r_cam_diag_line_count <= 16'd0;
			r_cam_diag_line_bytes_min <= 16'd0;
			r_cam_diag_line_bytes_max <= 16'd0;
		end else begin
			r_cam_diag_vsync_d <= cmos_vsync;
			r_cam_diag_href_d <= cmos_href;
			if (!r_cam_diag_vsync_d && cmos_vsync) begin
				r_cam_diag_line_bytes <= 16'd0;
				r_cam_diag_lines_work <= 16'd0;
				r_cam_diag_min_work <= 16'hffff;
				r_cam_diag_max_work <= 16'd0;
			end else if (cmos_vsync) begin
				if (cmos_href)
					r_cam_diag_line_bytes <= r_cam_diag_line_bytes + 1'b1;
				else
					r_cam_diag_line_bytes <= 16'd0;
				if (r_cam_diag_href_d && !cmos_href) begin
					r_cam_diag_lines_work <= r_cam_diag_lines_work + 1'b1;
					if (r_cam_diag_line_bytes < r_cam_diag_min_work)
						r_cam_diag_min_work <= r_cam_diag_line_bytes;
					if (r_cam_diag_line_bytes > r_cam_diag_max_work)
						r_cam_diag_max_work <= r_cam_diag_line_bytes;
				end
			end
			if (r_cam_diag_vsync_d && !cmos_vsync) begin
				r_cam_diag_frame_count <= r_cam_diag_frame_count + 1'b1;
				r_cam_diag_line_count <= r_cam_diag_lines_work;
				r_cam_diag_line_bytes_min <= (r_cam_diag_lines_work == 0) ? 16'd0 : r_cam_diag_min_work;
				r_cam_diag_line_bytes_max <= r_cam_diag_max_work;
			end
		end
	end

	 

	reg [63:0] r_cam_diag_sync1 = 64'd0;
	reg [63:0] r_cam_diag_sync2 = 64'd0;
	reg [63:0] r_cam_diag_published = 64'd0;
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys) begin
			r_cam_diag_sync1 <= 64'd0;
			r_cam_diag_sync2 <= 64'd0;
			r_cam_diag_published <= 64'd0;
		end else begin
			r_cam_diag_sync1 <= {r_cam_diag_frame_count, r_cam_diag_line_count,
			                     r_cam_diag_line_bytes_min, r_cam_diag_line_bytes_max};
			r_cam_diag_sync2 <= r_cam_diag_sync1;
			if (r_cam_diag_sync1 == r_cam_diag_sync2)
				r_cam_diag_published <= r_cam_diag_sync2;
		end
	end
	
	
	
	
	
	
	
	
	 

	
	localparam 	CLK_FREQ 	= 96_000_000; 	 


	localparam 	BAUD_RATE 	= 921_600; 		 



	wire 	[7:0] 	w_sfr_addr_o; 	 
	wire 	[7:0] 	w_sfr_wdata_o; 	 
	wire 			w_sfr_we_o; 		 
	reg 	[7:0] 	w_sfr_rdata_i; 	 
	wire 			w_sfr_rd_o; 		 



	reg 			r_dsi_tx_rstn = 0; 	 
	wire 	[7:0] 	w_control_pwm; 		 
	reg 			r_dsi_resetn_o = 0; 	 
	reg 			r_dsi_data_rstn = 0; 	 
	
	reg 	[3:0] 	r_dsi_lp_p_ovr = 0; 	
	reg 	[3:0] 	r_dsi_lp_n_ovr = 0; 	
	
	
	
	 
	localparam 	CSI_AXILITE_ID 	= 0; 				 
	localparam 	DSI_AXILITE_ID 	= 1; 				 
	
	reg 	[7:0] 	r_axi_addr = 8'h18; 		 
	reg 	[31:0] 	r_axi_wdata = 32'h0000000A; 	 
	wire 	[31:0] 	w_axi_rdata; 			 
	reg 	[0:0] 	r_axi_sel = 1; 			 
	reg 			r_axi_r1w0 = 0; 			 
	reg 			r_axi_req = 0; 			 
	reg 			r_axi_req_o = 0; 			 



	reg 	[31:0] 	r_axi_rdata = 0; 		 
	reg 			r_axi_idle = 0; 		 
	
	reg 	[3:0] 	rs_axilite = 0; 		 
	wire 	[3:0] 	ws_axilite_idle = 0; 		
	wire 	[3:0] 	ws_axilite_write = 1; 
	wire 	[3:0] 	ws_axilite_read = 2; 
	wire 	[3:0] 	ws_axilite_endread = 3; 
	
	reg 			r_axi_awvalid = 0, r_axi_wvalid = 0, r_axi_arvalid = 0; 
	wire 			w_axi_awready, w_axi_wready, w_axi_arready, w_axi_rvalid; 
	
	
	reg 	[3:0] 	rc_axi_init = 0; 

	always @(posedge clk_sys or posedge rst_sys) begin
		if(rst_sys) begin
			r_dsi_tx_rstn <= 0; 
			r_axi_req <= 0; 
			r_dsi_resetn_o <= 0; 
			r_dsi_data_rstn <= 0; 
			
			rs_axilite <= 0; 
			r_axi_awvalid <= 0; 
			r_axi_wvalid <= 0;
			r_axi_arvalid <= 0; 
			
			r_dsi_lp_p_ovr <= 0; 
			r_dsi_lp_n_ovr <= 0; 
			
			rc_axi_init <= 0; 
			r_axi_idle <= 0; 
			
		end else begin
			r_dsi_tx_rstn <= 1; 
			r_dsi_resetn_o <= 1; 
			r_dsi_data_rstn <= 1; 
			
		end
	end
	
	assign dsi_resetn_o = r_dsi_resetn_o; 
	
	assign csi_ctl0_oe = 0; 
	assign csi_ctl1_oe = 0; 
	
	
	PWMLite dsi_pwm (		 
		.clk_i			(clk_sys),
		.rst_i			(rst_sys),
		.pwm_i			(w_control_pwm[6:0]),
		.pol_i			(w_control_pwm[7]), 
		.pwm_o			(dsi_pwm_o)
	);

	PWMLite lcd_pwm (
		.clk_i			(clk_sys),
		.rst_i			(rst_sys),
		.pwm_i			(w_control_pwm[6:0]),
		.pol_i			(w_control_pwm[7]),
		.pwm_o			(lcd_pwm_o)
	);
	assign lcd_blen_o = 1'b1;






	 



	localparam 	CSI_RXD_INV 	= 4'b1111; 
	localparam 	CSI_DATA_WIDTH 	= 8; 			
	localparam 	CSI_STRB_WIDTH 	= CSI_DATA_WIDTH / 8; 

	
	 

	
	wire			XYCrop_frame_vsync; 
	wire			XYCrop_frame_href;
	wire			XYCrop_frame_de;
	wire	[63:0]	XYCrop_frame_Gray;
	wire			XYCrop_720_vsync, XYCrop_1080_vsync;
	wire			XYCrop_720_href, XYCrop_1080_href;
	wire			XYCrop_720_de, XYCrop_1080_de;
	wire	[63:0]	XYCrop_720_data, XYCrop_1080_data;

	Sensor_Image_XYCrop
	#(
		 
		.IMAGE_HSIZE_SOURCE (1280 * 2 / CSI_STRB_WIDTH),
		.IMAGE_VSIZE_SOURCE (720	 ),
		.IMAGE_HSIZE_TARGET (1024 * 2 / CSI_STRB_WIDTH),
		.IMAGE_YSIZE_TARGET (600 	 ),
		.PIXEL_DATA_WIDTH	(CSI_DATA_WIDTH) 		 
	)
	u_Sensor_Image_XYCrop
	(
		 
		.clk			(w_cmos_pclk),			 
		.rst_n		(rstn_sys),			 


		.image_in_vsync (cmos_vsync		),			 
		.image_in_href	(cmos_href		),			 
		.image_in_de	(cmos_href		), 			 
		.image_in_data	(cmos_data),			 
		
		.image_out_vsync(XYCrop_720_vsync ),
		.image_out_href (XYCrop_720_href),
		.image_out_de	(XYCrop_720_de),
		.image_out_data (XYCrop_720_data)
	);

	Sensor_Image_XYCrop
	#(
		.IMAGE_HSIZE_SOURCE (1920 * 2 / CSI_STRB_WIDTH),
		.IMAGE_VSIZE_SOURCE (1080),
		 

		.IMAGE_HSIZE_TARGET (1920 * 2 / CSI_STRB_WIDTH),
		.IMAGE_YSIZE_TARGET (1080),
		.PIXEL_DATA_WIDTH (CSI_DATA_WIDTH)
	)
	u_Sensor_Image_XYCrop_1080
	(
		.clk (w_cmos_pclk),
		.rst_n (rstn_sys),
		.image_in_vsync (cmos_vsync),
		.image_in_href (cmos_href),
		.image_in_de (cmos_href),
		.image_in_data (cmos_data),
		.image_out_vsync (XYCrop_1080_vsync),
		.image_out_href (XYCrop_1080_href),
		.image_out_de (XYCrop_1080_de),
		.image_out_data (XYCrop_1080_data)
	);

	assign XYCrop_frame_vsync = (r_resolution_select == 2'd1) ? XYCrop_1080_vsync : XYCrop_720_vsync;
	assign XYCrop_frame_href  = (r_resolution_select == 2'd1) ? XYCrop_1080_href  : XYCrop_720_href;
	assign XYCrop_frame_de    = (r_resolution_select == 2'd1) ? XYCrop_1080_de    : XYCrop_720_de;
	assign XYCrop_frame_Gray  = (r_resolution_select == 2'd1) ? XYCrop_1080_data  : XYCrop_720_data;

	reg			r_XYCrop_frame_vsync = 0; 
	reg			r_XYCrop_frame_href = 0;
	reg			r_XYCrop_frame_de = 0;
	reg	[63:0]	r_XYCrop_frame_Gray = 0;
	
	always @(posedge w_cmos_pclk) begin
		r_XYCrop_frame_vsync <= XYCrop_frame_vsync; 
		r_XYCrop_frame_href <= XYCrop_frame_href;
		r_XYCrop_frame_de <= XYCrop_frame_de;
		r_XYCrop_frame_Gray <= XYCrop_frame_Gray;
	end
	
	 
	wire			cmos_frame_vsync = r_XYCrop_frame_vsync;                      
	wire			cmos_frame_href = r_XYCrop_frame_href && r_XYCrop_frame_de;	  
	wire	[63:0]	cmos_frame_Gray = r_XYCrop_frame_Gray; 
	wire 			cmos_vsync_end;


	 




	wire [7:0] w_uart_rx_data;
	wire       w_uart_rx_valid;
	wire       w_spi_cmd_capture;
	wire       w_spi_cmd_resume;
	wire       w_spi_cmd_send;
	wire       w_spi_cmd_stream;
	wire       w_spi_scan_write;
	wire [1:0] w_spi_scan_value;
	wire       w_spi_resolution_write;
	wire [1:0] w_spi_resolution_value;
	wire       w_spi_upload_begin;
	wire [1:0] w_spi_upload_mode;
	wire       w_upload_select;
	wire       w_upload_packet_done;
	wire       w_upload_packet_good;
	wire       w_upload_header_error;
	wire       w_upload_overflow;
	wire [21:0] w_upload_payload_count;
	wire       w_upload_writer_active;
	wire       w_upload_writer_complete;
	wire       w_upload_writer_success;
	wire       w_upload_writer_axi_error;
	reg        r_host_frame_selected = 1'b0;
	 


	reg [1:0]  r_host_scan_select = 2'd0;
	wire [7:0] w_spi_upload_algorithm_flags;
	reg [7:0] r_host_algorithm_flags = 8'd0;
	reg [5:0]  r_upload_reset_count = 6'd0;
	reg        r_upload_start_pending = 1'b0;
	reg        r_upload_writer_start = 1'b0;
	wire       w_upload_session_reset = r_upload_reset_count != 0;

	uart_rx_byte #(
		.CLK_HZ(CLK_FREQ),
		.BAUD(BAUD_RATE)
	) u_uart_rx_byte (
		.clk(clk_sys),
		.rst_n(rstn_sys),
		.rx_i(uart_rx_i),
		.data_o(w_uart_rx_data),
		.valid_o(w_uart_rx_valid)
	);

	wire w_cmd_capture = w_spi_cmd_capture || (w_uart_rx_valid && !w_frame_busy && !r_frame_start &&
	                    ((w_uart_rx_data == 8'h43) || (w_uart_rx_data == 8'h63)));
	wire w_cmd_resume  = w_spi_cmd_resume || (w_uart_rx_valid && !w_frame_busy && !r_frame_start &&
	                    ((w_uart_rx_data == 8'h52) || (w_uart_rx_data == 8'h72)));
	wire w_cmd_send    = w_spi_cmd_send || (w_uart_rx_valid && !w_frame_busy && !r_frame_start &&
	                    ((w_uart_rx_data == 8'h53) || (w_uart_rx_data == 8'h73)));
	wire w_uart_resolution_write = w_uart_rx_valid && !w_frame_busy && !r_frame_start &&
	                    ((w_uart_rx_data == 8'h37) || (w_uart_rx_data == 8'h38) ||
	                     (w_uart_rx_data == 8'h4d) || (w_uart_rx_data == 8'h6d));
	wire [6:0] w_camera_profile;wire w_camera_profile_write;
    wire w_resolution_write = w_spi_resolution_write || w_uart_resolution_write;

	 

	reg [1:0] r_scan_select = 2'd0;
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys)
			r_scan_select <= 2'd0;
		else if (w_spi_scan_write)
			r_scan_select <= w_spi_scan_value;
		else if (w_uart_rx_valid) begin
			case (w_uart_rx_data)
				8'h42, 8'h62: r_scan_select <= 2'd1;
				8'h54, 8'h74: r_scan_select <= 2'd2;
				8'h50, 8'h70: r_scan_select <= 2'd3;
				8'h4f, 8'h6f: r_scan_select <= 2'd0;
				default: r_scan_select <= r_scan_select;
			endcase
		end
	end
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys)
			r_resolution_select <= 2'd0;
		else if (w_spi_resolution_write)
			r_resolution_select <= w_spi_resolution_value;
		else if (w_uart_rx_valid) begin
			case (w_uart_rx_data)
				8'h37: r_resolution_select <= 2'd0;  
				8'h38: r_resolution_select <= 2'd1;  
				8'h4d, 8'h6d: r_resolution_select <= 2'd2;  
				default: r_resolution_select <= r_resolution_select;
			endcase
		end
	end
	 


	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys) begin
			r_i2c_reconfig_count <= 20'd0;
			r_i2c_reconfig_active <= 1'b0;
		end else if (w_resolution_write || w_camera_profile_write) begin
			r_i2c_reconfig_count <= 20'd0;
			r_i2c_reconfig_active <= 1'b1;
		end else if (r_i2c_reconfig_active) begin
			if (r_i2c_reconfig_count == 20'd100000) begin
				r_i2c_reconfig_active <= 1'b0;
			end else begin
				r_i2c_reconfig_count <= r_i2c_reconfig_count + 1'b1;
			end
		end
	end
	wire [1:0] w_scan_mode = (r_scan_select == 2'd3) ? 2'd2 :
	                         (r_scan_select == 2'd0) ? 2'd0 : 2'd1;
	wire [7:0] w_bw_margin = (r_scan_select == 2'd2) ? 8'd12 : 8'd24;

	reg r_capture_toggle = 0;
	reg r_resume_toggle = 0;
	reg [3:0] r_stream_reset_count = 4'd0;
    reg r_stream_reset_pending = 1'b0;
    wire w_stream_reset_safe = !w_stream_claim || (w_model_memory_idle &&
        !w_jpeg_arvalid && !w_jpeg_awvalid && !w_jpeg_wvalid);
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys) begin
			r_capture_toggle <= 0;
			r_resume_toggle <= 0;
			r_stream_reset_count <= 4'd0;
            r_stream_reset_pending <= 1'b0;
		end else begin
			if (w_cmd_capture)
				r_capture_toggle <= ~r_capture_toggle;
			if (w_cmd_resume)
				r_resume_toggle <= ~r_resume_toggle;
            if (w_cmd_resume || w_spi_upload_begin || r_stream_reset_pending) begin
                if (w_stream_reset_safe) begin
                    r_stream_reset_count <= 4'd15;
                    r_stream_reset_pending <= 1'b0;
                end else r_stream_reset_pending <= 1'b1;
            end else if (r_stream_reset_count != 0) begin
                r_stream_reset_count <= r_stream_reset_count - 1'b1;
            end
		end
	end
	wire w_stream_rst_n = rstn_sys && (r_stream_reset_count == 0);

	wire w_capture_writer_vsync;
	wire w_capture_writer_data_en;
	wire w_capture_frozen_pclk;
	wire w_capture_done_toggle;

	frame_capture_ctrl u_frame_capture_ctrl (
		.pclk(w_cmos_pclk),
		.rst_n(rstn_sys),
		.sensor_vsync(cmos_frame_vsync),
		.sensor_data_en(cmos_frame_href),
		.capture_toggle_async(r_capture_toggle),
		.resume_toggle_async(r_resume_toggle),
		.writer_vsync(w_capture_writer_vsync),
		.writer_data_en(w_capture_writer_data_en),
		.frozen(w_capture_frozen_pclk),
		.capture_done_toggle(w_capture_done_toggle)
	);

	reg [2:0] r_frozen_sync = 0;
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys)
			r_frozen_sync <= 0;
		else
			r_frozen_sync <= {r_frozen_sync[1:0], w_capture_frozen_pclk};
	end
	wire w_capture_frozen_sys = r_frozen_sync[2];

	wire       w_dump_busy;
	wire [7:0] w_dump_data;
	wire       w_dump_valid;
	wire       w_dump_done;
	wire       w_uart_sender_busy;
	wire       w_frozen_frame_ready;
	wire       w_stream_dump_start;
	wire       w_stream_dump_ready;
	wire       w_stream_claim;
	wire       w_stream_ready;
	wire       w_stream_miso;
	wire       w_stream_select;
	wire       w_stream_host_select;
    wire [7:0] w_camera_algorithm_flags;
    wire w_camera_text_filter = ((r_scan_select == 2'd2) || (r_scan_select == 2'd1)) && w_camera_algorithm_flags[3];
    wire w_camera_color_filter = (r_scan_select == 2'd3) && (|w_camera_algorithm_flags[2:1]);
    wire w_camera_advanced_layout = !w_stream_host_select && (w_camera_text_filter || w_camera_color_filter);
	wire [1:0] w_host_scan_mode = (r_frame_result_select || r_frame_original_select) ? 2'd0 : (r_host_scan_select == 2'd3) ? 2'd2 :
	                              (r_host_scan_select == 2'd0) ? 2'd0 : 2'd1;
	wire [7:0] w_host_bw_margin = (r_host_scan_select == 2'd2) ? 8'd12 : 8'd24;
	wire [1:0] w_spi_upload_1080;
    reg [1:0] r_host_frame_1080=2'd0;
    wire [1:0] w_stream_use_1080=w_stream_host_select ? ((r_frame_result_select || r_frame_original_select) ? r_frame_1080 : r_host_frame_1080) : (r_resolution_select==2'd1 ? 2'd1 : 2'd0);
	reg        r_stream_pending = 1'b0;
	wire       w_stream_frame_ready = w_stream_host_select ?
	                                  ((r_frame_result_select || r_frame_original_select) ? w_frame_done && !w_frame_error : r_host_frame_selected) :
	                                  w_frozen_frame_ready;
	 

	wire       w_stream_start = r_stream_pending &&
	                           w_stream_rst_n && !r_stream_reset_pending &&
	                           w_capture_frozen_sys &&
	                           w_stream_frame_ready && !w_uart_sender_busy &&
	                           !w_stream_claim && !w_cmd_resume;
	wire       w_uart_dump_start;
	wire       w_uart_dump_ready;
	wire       w_dump_start = w_uart_dump_start || w_stream_dump_start;
	wire       w_dump_ready = w_stream_claim ? w_stream_dump_ready : w_uart_dump_ready;
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys)
			r_stream_pending <= 1'b0;
		else if (w_cmd_resume)
			r_stream_pending <= 1'b0;
		else if (w_spi_cmd_stream)
			r_stream_pending <= 1'b1;
		else if ((w_stream_host_select && w_stream_claim) ||
		         (!w_stream_host_select && w_stream_start))
			r_stream_pending <= 1'b0;
	end
	reg        r_send_pending = 1'b0;
	wire       w_uart_send_ready = r_send_pending && w_capture_frozen_sys &&
	                               w_frozen_frame_ready && !w_uart_sender_busy &&
	                               !w_stream_claim && !w_cmd_resume;
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys)
			r_send_pending <= 1'b0;
		else if (w_cmd_resume)
			r_send_pending <= 1'b0;
		else if (w_cmd_send)
			r_send_pending <= 1'b1;
		else if (w_uart_send_ready)
			r_send_pending <= 1'b0;
	end

	 


	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys) begin
			r_upload_reset_count <= 6'd0;
			r_upload_start_pending <= 1'b0;
			r_upload_writer_start <= 1'b0;
			r_host_frame_selected <= 1'b0;
			r_host_scan_select <= 2'd0;
                r_host_frame_1080 <= 1'b0;
			r_host_algorithm_flags <= 8'd0;
		end else begin
			r_upload_writer_start <= 1'b0;
			 


			if (w_spi_upload_begin) begin
				r_host_frame_selected <= 1'b0;
				 

				r_host_scan_select <= w_spi_upload_mode;
                r_host_frame_1080 <= w_spi_upload_1080;
				r_host_algorithm_flags <= w_spi_upload_algorithm_flags;
				r_upload_reset_count <= 6'd32;
				r_upload_start_pending <= 1'b1;
			end else if (r_upload_reset_count != 0) begin
				r_upload_reset_count <= r_upload_reset_count - 1'b1;
			end else if (r_upload_start_pending && w_capture_frozen_sys &&
			             w_frozen_frame_ready && !w_upload_writer_active) begin
				r_upload_writer_start <= 1'b1;
				r_upload_start_pending <= 1'b0;
			end
			if (w_upload_writer_complete && w_upload_writer_success)
				r_host_frame_selected <= 1'b1;
		end
	end

	wire [7:0] w_upload_fifo_wdata;
	wire       w_upload_fifo_write;
	wire       w_upload_fifo_full;
	wire [127:0] w_upload_fifo_rdata;
	wire [9:0] w_upload_fifo_rd_count;
	wire       w_upload_fifo_read;
	wire       w_upload_fifo_reset = !rstn_sys || w_upload_session_reset;
	 



	wire w_upload_flow_ready;
	upload_fifo_ready u_upload_fifo_ready (
		.clk(clk_sys), .rst_n(rstn_sys), .fifo_reset_i(w_upload_fifo_reset),
		.writer_active_i(w_upload_writer_active),
		.receiver_error_i(w_upload_header_error || w_upload_overflow),
		.fifo_read_count_i(w_upload_fifo_rd_count), .ready_o(w_upload_flow_ready)
	);
	wire       w_upload_metadata_valid_async;
	wire [11:0] w_upload_width_async;
	wire [11:0] w_upload_height_async;
	wire [21:0] w_upload_frame_payload_async;

	spi_frame_upload_receiver u_spi_frame_upload_receiver (
		.rst_n(rstn_sys),
		.session_reset_i(w_upload_session_reset),
		.spi_sclk_i(lcd_tp_scl_i),
		.spi_cs_n_i(lcd_tp_sda_i),
		.select_i(w_upload_select),
		.spi_mosi_i(lcd_tp_int_i),
		.fifo_full_i(w_upload_fifo_full),
		.fifo_data_o(w_upload_fifo_wdata),
		.fifo_write_o(w_upload_fifo_write),
		.packet_done_o(w_upload_packet_done_async),
		.packet_good_o(w_upload_packet_good_async),
		.header_error_o(w_upload_header_error_async),
		.overflow_o(w_upload_overflow_async),
		.payload_count_o(w_upload_payload_count_async),
		.frame_metadata_valid_o(w_upload_metadata_valid_async),
		.frame_width_o(w_upload_width_async),
		.frame_height_o(w_upload_height_async),
		.frame_payload_bytes_o(w_upload_frame_payload_async)
	);

	wire w_upload_header_error_async;
	wire w_upload_overflow_async;
	wire w_upload_packet_done_async;
	wire w_upload_packet_good_async;
	wire [21:0] w_upload_payload_count_async;
	reg [2:0] r_upload_header_sync = 3'd0;
	reg [2:0] r_upload_overflow_sync = 3'd0;
	reg [2:0] r_upload_done_sync = 3'd0;
	reg [2:0] r_upload_good_sync = 3'd0;
	reg [21:0] r_upload_count_sync1 = 22'd0;
	reg [21:0] r_upload_count_sync2 = 22'd0;
	reg [2:0] r_upload_metadata_valid_sync = 3'd0;
	reg [11:0] r_upload_width_sync1 = 12'd0;
	reg [11:0] r_upload_width_sync2 = 12'd0;
	reg [11:0] r_upload_height_sync1 = 12'd0;
	reg [11:0] r_upload_height_sync2 = 12'd0;
	reg [21:0] r_upload_payload_sync1 = 22'd0;
	reg [21:0] r_upload_payload_sync2 = 22'd0;
	wire [21:0] w_upload_decoded_frame_bytes =
		({10'd0, r_upload_width_sync2} * {10'd0, r_upload_height_sync2}) << 1;
	always @(posedge clk_sys or negedge rstn_sys) begin
		if (!rstn_sys) begin
			r_upload_header_sync <= 3'd0;
			r_upload_overflow_sync <= 3'd0;
			r_upload_done_sync <= 3'd0;
			r_upload_good_sync <= 3'd0;
			r_upload_count_sync1 <= 22'd0;
			r_upload_count_sync2 <= 22'd0;
			r_upload_metadata_valid_sync <= 3'd0;
			r_upload_width_sync1 <= 12'd0;
			r_upload_width_sync2 <= 12'd0;
			r_upload_height_sync1 <= 12'd0;
			r_upload_height_sync2 <= 12'd0;
			r_upload_payload_sync1 <= 22'd0;
			r_upload_payload_sync2 <= 22'd0;
		end else if (w_upload_session_reset) begin
			r_upload_header_sync <= 3'd0;
			r_upload_overflow_sync <= 3'd0;
			r_upload_done_sync <= 3'd0;
			r_upload_good_sync <= 3'd0;
			r_upload_count_sync1 <= 22'd0;
			r_upload_count_sync2 <= 22'd0;
			r_upload_metadata_valid_sync <= 3'd0;
			r_upload_width_sync1 <= 12'd0;
			r_upload_width_sync2 <= 12'd0;
			r_upload_height_sync1 <= 12'd0;
			r_upload_height_sync2 <= 12'd0;
			r_upload_payload_sync1 <= 22'd0;
			r_upload_payload_sync2 <= 22'd0;
		end else begin
			r_upload_header_sync <= {r_upload_header_sync[1:0], w_upload_header_error_async};
			r_upload_overflow_sync <= {r_upload_overflow_sync[1:0], w_upload_overflow_async};
			r_upload_done_sync <= {r_upload_done_sync[1:0], w_upload_packet_done_async};
			r_upload_good_sync <= {r_upload_good_sync[1:0], w_upload_packet_good_async};
			r_upload_count_sync1 <= w_upload_payload_count_async;
			r_upload_count_sync2 <= r_upload_count_sync1;
			r_upload_metadata_valid_sync <= {r_upload_metadata_valid_sync[1:0],
			                                 w_upload_metadata_valid_async};
			r_upload_width_sync1 <= w_upload_width_async;
			r_upload_width_sync2 <= r_upload_width_sync1;
			r_upload_height_sync1 <= w_upload_height_async;
			r_upload_height_sync2 <= r_upload_height_sync1;
			r_upload_payload_sync1 <= w_upload_frame_payload_async;
			r_upload_payload_sync2 <= r_upload_payload_sync1;
		end
	end
	assign w_upload_packet_done = r_upload_done_sync[2];
	assign w_upload_packet_good = r_upload_good_sync[2];
	assign w_upload_header_error = r_upload_header_sync[2];
	assign w_upload_overflow = r_upload_overflow_sync[2];
	assign w_upload_payload_count = r_upload_count_sync2;

	W0_FIFO_8 u_upload_fifo (
		.almost_full_o(), .full_o(w_upload_fifo_full), .wr_ack_o(),
		.empty_o(), .almost_empty_o(), .prog_empty_o(), .rd_valid_o(),
		.wr_clk_i(lcd_tp_scl_i), .rd_clk_i(clk_sys),
		.wr_en_i(w_upload_fifo_write), .rd_en_i(w_upload_fifo_read),
		.wdata(w_upload_fifo_wdata), .rst_busy(), .rdata(w_upload_fifo_rdata),
		.a_rst_i(w_upload_fifo_reset), .wr_datacount_o(),
		.rd_datacount_o(w_upload_fifo_rd_count), .underflow_o(), .overflow_o()
	);

	 


	assign lcd_tp_scl_o  = 1'b0;
	assign lcd_tp_scl_oe = 1'b0;
	assign lcd_tp_sda_o  = 1'b0;
	assign lcd_tp_sda_oe = 1'b0;
	assign lcd_tp_int_o  = 1'b0;
	assign lcd_tp_int_oe = 1'b0;


    localparam [31:0] FRAME_RESULT_BASE=32'h02000000;
    reg r_frame_start,r_frame_result_select,r_frame_original_select,r_frame_rejected,r_frame_source_camera;reg [1:0] r_frame_1080;
    reg [1:0] r_frame_input_slot;
    reg [2:0] r_frame_config;
    wire [1:0] w_captured_slot;
    wire [23:0] w_frame_pixels_done;
    wire [7:0] w_full_read_data;wire w_full_load_begin;
    wire w_frame_tile_input_valid,w_frame_tile_input_ready,w_frame_tile_start,w_frame_tile_start_ready;
    wire w_frame_tile_result_valid,w_frame_tile_result_ready;
    wire [7:0] w_frame_tile_input,w_frame_tile_result;
    wire [9:0] w_frame_tile_result_address;
    wire w_frame_available=!w_frame_busy && !w_portrait_active && !w_core_busy && !w_upload_writer_active &&
        !w_stream_claim && !w_stream_pending_guard && w_capture_frozen_sys && !r_frame_start;
    wire w_stream_pending_guard=r_stream_pending || r_stream_reset_pending || !w_stream_rst_n;
    always @(posedge clk_sys or negedge rstn_sys)begin
        if(!rstn_sys)begin
            r_frame_start<=0;r_frame_result_select<=0;r_frame_original_select<=0;r_frame_config<=0;r_frame_rejected<=0;r_frame_source_camera<=0;r_frame_1080<=0;r_frame_input_slot<=0;
        end else begin
            r_frame_start<=0;
            if(w_spi_upload_begin || w_cmd_resume || w_full_load_begin)begin r_frame_result_select<=0;r_frame_original_select<=0;end
            if(w_student_write_pulse && w_student_write_address==7'h61 && !w_frame_busy)r_frame_config<=w_student_write_data[2:0];
            if(w_student_write_pulse && w_student_write_address==7'h4c)begin
                if(w_student_write_data[0])begin
                    if(w_frame_available && (w_student_write_data[2] ? w_frozen_frame_ready : r_host_frame_selected))begin
                        r_frame_start<=1;r_frame_rejected<=0;r_frame_result_select<=0;r_frame_original_select<=0;
                        r_frame_input_slot<=w_student_write_data[2] ? w_captured_slot : w_upload_slot;
                        r_frame_source_camera<=w_student_write_data[2];
                        r_frame_1080<=w_student_write_data[2] ? (r_resolution_select==1 ? 2'd1 : 2'd0) : r_host_frame_1080;
                    end else r_frame_rejected<=1;
                end else if(!w_frame_busy)begin
                    r_frame_result_select<=w_student_write_data[1] && w_frame_done && !w_frame_error;
                    r_frame_original_select<=w_student_write_data[3] && w_frame_done && !w_frame_error;
                end
            end
        end
    end
    wire [7:0] w_student_read_data,w_student_write_data,w_compact_read_data,w_portrait_read_data;
    wire [7:0] w_model_flash_read_data;
    wire w_model_flash_mosi;
    wire w_model_flash_valid,w_model_flash_ready;
    wire [7:0] w_model_flash_byte;
    assign w_spi_data_o={2'b11,1'b0,w_model_flash_mosi};
    assign w_spi_data_oe=4'b1101;
    model_flash_reader u_model_flash_reader (
        .clk_i(clk_sys),.rst_n_i(rstn_sys),.write_i(w_student_write_pulse),
        .address_i(w_student_write_address),.read_address_i(w_student_read_address),
        .data_i(w_student_write_data),.flash_data_i(w_spi_data_i[1]),
        .byte_valid_o(w_model_flash_valid),.byte_o(w_model_flash_byte),.byte_ready_i(w_model_flash_ready),
        .read_data_o(w_model_flash_read_data),.active_o(w_model_flash_active),
        .flash_clock_o(w_spi_sck_o),.flash_select_n_o(w_spi_ssn_o),.flash_data_o(w_model_flash_mosi)
    );
    assign w_student_read_data = (w_student_read_address>=7'h3a && w_student_read_address<=7'h3f) ? w_model_flash_read_data :
        w_student_read_address==7'h4f ? 8'h82 : w_student_read_address>=7'h65 ? w_full_read_data : w_student_read_address==7'h60 ? 8'hd2 :
        w_student_read_address==7'h61 ? {5'd0,r_frame_config} :
        w_student_read_address==7'h62 ? w_frame_pixels_done[7:0] :
        w_student_read_address==7'h63 ? w_frame_pixels_done[15:8] :
        w_student_read_address==7'h64 ? w_frame_pixels_done[23:16] :
        w_student_read_address==7'h4c ? 8'hd2 :
        w_student_read_address==7'h4d ? {4'd0,r_frame_rejected,w_frame_error,w_frame_done,w_frame_busy} :
        w_student_read_address==7'h4e ? {3'd0,r_frame_1080[1],r_frame_source_camera,r_frame_original_select,r_frame_1080[0],r_frame_result_select} :
        (w_student_read_address[6:4]==3'b101 ? w_portrait_read_data:w_compact_read_data);
    wire [6:0] w_student_read_address,w_student_write_address;
    wire w_student_write_pulse,w_student_stream_miso;
    wire [1:0] w_student_stream_select;
    wire w_frame_color_model;
     

    assign w_frame_tile_input_ready = 1'b0;
    assign w_frame_tile_start_ready = 1'b0;
    assign w_frame_tile_result_valid = 1'b0;
    assign w_frame_tile_result = 8'd0;
    assign w_frame_tile_result_address = 10'd0;
    assign w_core_busy = 1'b0;
    assign w_student_stream_miso = 1'b0;
    assign w_compact_read_data = 8'd0;


    student_frame_full_engine u_student_frame_engine (
        .flash_valid_i(w_model_flash_valid),.flash_data_i(w_model_flash_byte),.flash_ready_o(w_model_flash_ready),
        .load_available_i(!w_portrait_active && !w_core_busy && !w_upload_writer_active && !w_stream_claim && !w_stream_pending_guard && !r_frame_start && w_ddr3_cal_done && w_ddr3_cal_pass),
        .reg_write_i(w_student_write_pulse),.reg_addr_i(w_student_write_address),.reg_data_i(w_student_write_data),.read_addr_i(w_student_read_address),.read_data_o(w_full_read_data),.load_begin_o(w_full_load_begin),
        .color_model_o(w_frame_color_model),
        .clk_i(clk_sys),.rst_n_i(rstn_sys),.start_i(r_frame_start),
        .camera_layout_i(r_frame_source_camera),.joint_i(r_frame_config[2]),.output_mode_i(r_frame_config[1:0]),
        .width_i(r_frame_1080==2 ? 16'd256 : r_frame_1080==1 ? 16'd1920 : 16'd1024),.height_i(r_frame_1080==2 ? 16'd224 : r_frame_1080==1 ? 16'd1080 : 16'd600),
        .input_base_i({8'd0,r_frame_input_slot,22'd0}),.output_base_i(FRAME_RESULT_BASE),
        .busy_o(w_frame_busy),.done_o(w_frame_done),.error_o(w_frame_error),.pixels_done_o(w_frame_pixels_done),
        .tile_input_valid_o(w_frame_tile_input_valid),.tile_input_ready_i(w_frame_tile_input_ready),.tile_input_pixel_o(w_frame_tile_input),
        .tile_start_valid_o(w_frame_tile_start),.tile_start_ready_i(w_frame_tile_start_ready),
        .tile_result_valid_i(w_frame_tile_result_valid),.tile_result_ready_o(w_frame_tile_result_ready),
        .tile_result_pixel_i(w_frame_tile_result),.tile_result_address_i(w_frame_tile_result_address),
        .arvalid_o(w_frame_arvalid),.arready_i(w_frame_arready),.araddr_o(w_frame_araddr),
        .rvalid_i(w_frame_rvalid),.rlast_i(w_ddr3_rlast),.rresp_i(w_ddr3_rresp),.rdata_i(w_ddr3_rdata),.rready_o(w_frame_rready),
        .awvalid_o(w_frame_awvalid),.awready_i(w_frame_awready),.awaddr_o(w_frame_awaddr),
        .wvalid_o(w_frame_wvalid),.wready_i(w_frame_wready),.wdata_o(w_frame_wdata),.wstrb_o(w_frame_wstrb),.wlast_o(w_frame_wlast),
        .bvalid_i(w_frame_bvalid),.bresp_i(w_ddr3_bresp),.bready_o(w_frame_bready));

    portrait_register_endpoint u_portrait_register_endpoint (
        .job_active_o(w_portrait_active),
        .clk_i(clk_sys),.rst_n_i(rstn_sys),
        .write_valid_i(w_student_write_pulse && !w_frame_busy && !r_frame_start && w_student_write_address[6:4]==3'b101),.write_address_i(w_student_write_address),.write_data_i(w_student_write_data),.read_address_i(w_student_read_address),.read_data_o(w_portrait_read_data),
        .arvalid_o(w_portrait_arvalid),.arready_i(w_portrait_arready),.araddr_o(w_portrait_araddr),.rvalid_i(w_portrait_rvalid),.rlast_i(w_ddr3_rlast),.rresp_i(w_ddr3_rresp),.rdata_i(w_ddr3_rdata),.rready_o(w_portrait_rready),
        .awvalid_o(w_portrait_awvalid),.awready_i(w_portrait_awready),.awaddr_o(w_portrait_awaddr),.wvalid_o(w_portrait_wvalid),.wready_i(w_portrait_wready),.wdata_o(w_portrait_wdata),.wstrb_o(w_portrait_wstrb),.wlast_o(w_portrait_wlast),.bvalid_i(w_portrait_bvalid),.bresp_i(w_ddr3_bresp),.bready_o(w_portrait_bready));

	wire w_stream_raw_select,w_stream_preview_select;
	fpga_spi_control u_fpga_spi_control (
        .frame_job_busy_i(w_frame_busy || r_frame_start),
		.clk(clk_sys),
		.rst_n(rstn_sys),
		.spi_sclk(lcd_tp_scl_i),
		.spi_cs_n(lcd_tp_sda_i),
		.spi_mosi(lcd_tp_int_i),
		.spi_miso(lcd_tp_rst_o),
		.capture_frozen_i(w_capture_frozen_sys),
		.frozen_frame_ready_i(w_frozen_frame_ready),
		.dump_busy_i(w_uart_sender_busy || w_stream_claim),
		.ddr_cal_done_i(w_ddr3_cal_done),
		.ddr_cal_pass_i(w_ddr3_cal_pass),
		.camera_alive_i(r_camera_seen),
		.stream_busy_i(w_stream_claim),
		.stream_ready_i(w_stream_ready),
		.stream_miso_i(w_stream_miso),
        .upload_flow_ready_i(w_upload_flow_ready),.jpeg_diag_i(w_jpeg_diag),.stream_size_i(w_jpeg_size),
		.upload_packet_done_i(w_upload_packet_done),
		.upload_packet_good_i(w_upload_packet_good),
		.upload_header_error_i(w_upload_header_error),
		.upload_overflow_i(w_upload_overflow),
		.upload_payload_count_i(w_upload_payload_count),
		.upload_writer_active_i(w_upload_writer_active),
		.upload_writer_success_i(w_upload_writer_success),
		.upload_writer_error_i(w_upload_writer_axi_error),
		.host_frame_valid_i(r_host_frame_selected),
		.scan_select_i(r_scan_select),
		.camera_frame_count_i(r_cam_diag_published[63:48]),
		.camera_line_count_i(r_cam_diag_published[47:32]),
		.camera_line_bytes_min_i(r_cam_diag_published[31:16]),
		.camera_line_bytes_max_i(r_cam_diag_published[15:0]),
		.i2c_config_index_i(ov5640_i2c_config_index),
		.i2c_config_done_i(ov5640_i2c_config_done),
		.i2c_reconfig_active_i(r_i2c_reconfig_active),
		.i2c_nack_seen_i(ov5640_i2c_nack_seen),
		.i2c_first_nack_index_i(ov5640_i2c_first_nack_index),
		.i2c_nack_count_i(ov5640_i2c_nack_count),
		.capture_pulse_o(w_spi_cmd_capture),
		.resume_pulse_o(w_spi_cmd_resume),
		.send_pulse_o(w_spi_cmd_send),
		.stream_pulse_o(w_spi_cmd_stream),
		.scan_write_pulse_o(w_spi_scan_write),
		.scan_write_value_o(w_spi_scan_value),
		.resolution_write_pulse_o(w_spi_resolution_write),
		.resolution_write_value_o(w_spi_resolution_value),
		.upload_begin_pulse_o(w_spi_upload_begin),
		.upload_begin_mode_o(w_spi_upload_mode),
        .upload_begin_1080_o(w_spi_upload_1080),
		.upload_algorithm_flags_o(w_spi_upload_algorithm_flags),
        .camera_algorithm_flags_o(w_camera_algorithm_flags),
		.camera_profile_o(w_camera_profile),.camera_profile_write_o(w_camera_profile_write),
        .pwm_o(w_control_pwm),
		.stream_select_o(w_stream_select),
		.stream_host_select_o(w_stream_host_select),
        .stream_raw_select_o(w_stream_raw_select),.stream_preview_select_o(w_stream_preview_select),
		.upload_select_o(w_upload_select),
        .student_stream_miso_i(w_student_stream_miso),.student_stream_select_o(w_student_stream_select),
        .student_read_data_i(w_student_read_data),.student_read_address_o(w_student_read_address),
        .student_write_pulse_o(w_student_write_pulse),.student_write_address_o(w_student_write_address),.student_write_data_o(w_student_write_data)
	);


    jpeg_frame_pipeline u_jpeg_frame_pipeline (
        .raw_output_i(w_stream_raw_select),.preview_i(w_stream_preview_select),
        .preview_direct_i(!w_stream_host_select),.preview_base_i({8'd0,w_captured_slot,22'd0}),
        .clk(clk_sys),.jpeg_fast_clk(core_clk),.rst_n(w_stream_rst_n),.start_i(w_stream_start),
        .width_i(w_stream_use_1080==2 ? 11'd256 : w_stream_use_1080==1 ? 11'd1920 : 11'd1024),
        .height_i(w_stream_use_1080==2 ? 11'd224 : w_stream_use_1080==1 ? 11'd1080 : 11'd600),
        .scan_mode_i(w_stream_host_select ? w_host_scan_mode : w_scan_mode),
        .frame_mode_i(w_stream_host_select ? ((r_frame_result_select || r_frame_original_select) ? 2'd0 : r_host_scan_select) : r_scan_select),
        .bw_margin_i(w_stream_host_select ? w_host_bw_margin : w_bw_margin),
        .canonical_input_i((w_stream_host_select && !(r_frame_original_select && r_frame_source_camera)) || w_camera_advanced_layout),
        .algorithm_flags_i((r_frame_result_select || r_frame_original_select) && w_stream_host_select ? 8'd0 : w_stream_host_select ? r_host_algorithm_flags : w_camera_algorithm_flags),
        .dump_start_o(w_stream_dump_start),.dump_direct_o(w_jpeg_dump_direct),
        .dump_base_o(w_jpeg_dump_base),.dump_size_o(w_jpeg_dump_size),
        .dump_busy_i(w_dump_busy),.dump_done_i(w_dump_done),.dump_valid_i(w_dump_valid),
        .dump_data_i(w_dump_data),.dump_ready_o(w_stream_dump_ready),
        .araddr_o(w_jpeg_araddr),.awaddr_o(w_jpeg_awaddr),.arvalid_o(w_jpeg_arvalid),
        .awvalid_o(w_jpeg_awvalid),.wvalid_o(w_jpeg_wvalid),
        .arready_i(w_model_arready && w_stream_claim),.awready_i(w_model_awready && w_stream_claim),
        .wready_i(w_model_wready && w_stream_claim),.wdata_o(w_jpeg_wdata),.wstrb_o(w_jpeg_wstrb),
        .rvalid_i(w_model_rvalid && w_stream_claim),.bvalid_i(w_model_bvalid && w_stream_claim),
        .rdata_i(w_ddr3_rdata),.rresp_i(w_ddr3_rresp),.bresp_i(w_ddr3_bresp),
        .rready_o(w_jpeg_rready),.bready_o(w_jpeg_bready),
        .spi_sclk_i(lcd_tp_scl_i),.spi_cs_n_i(lcd_tp_sda_i),.stream_enable_i(w_stream_select),
        .spi_miso_o(w_stream_miso),.claim_o(w_stream_claim),.ready_o(w_stream_ready),
        .jpeg_size_o(w_jpeg_size),.diag_status_o(w_jpeg_diag)
    );

	 
	frame_uart_sender #(.CLK_HZ(CLK_FREQ), .BAUD(BAUD_RATE),
	    .WIDTH(1024), .HEIGHT(600), .DUAL_RESOLUTION(1)) u_frame_uart_sender (
	    .clk(clk_sys), .rst_n(rstn_sys), .start_i(w_uart_send_ready),
	    .frame_1080_i(r_resolution_select == 2'd1),
	    .scan_mode_i(w_scan_mode), .bw_margin_i(w_bw_margin),
	    .dump_start_o(w_uart_dump_start), .dump_busy_i(w_dump_busy),
	    .dump_data_i(w_dump_data), .dump_valid_i(w_dump_valid),
	    .dump_ready_o(w_uart_dump_ready), .dump_done_i(w_dump_done),
	    .uart_tx_o(uart_tx_o), .busy_o(w_uart_sender_busy)
	);

	












	 

	

	wire                            lcd_de;
	wire                            lcd_hs;      
	wire                            lcd_vs;
	wire 					  lcd_request; 
	wire            [7:0]           lcd_red, lcd_red2;
	wire            [7:0]           lcd_green, lcd_green2;
	wire            [7:0]           lcd_blue, lcd_blue2;
	wire            [15:0]          lcd_data;


	assign w_ddr3_awid = 0; 
	assign w_ddr3_wid = 0; 
	wire [1:0] w_upload_slot;
	axi_host_frame_writer u_axi_host_frame_writer (
		.clk(clk_sys),
		.rst(rst_sys),
		.start_i(r_upload_writer_start),
        .slot_i(w_upload_slot),
        .metadata_valid_i(r_upload_metadata_valid_sync[2]),
        .frame_width_i(r_upload_width_sync2),.frame_height_i(r_upload_height_sync2),
        .payload_bytes_i(r_upload_payload_sync2),
		.packet_done_i(w_upload_packet_done),
		.packet_good_i(w_upload_packet_good),
		.receiver_error_i(w_upload_header_error || w_upload_overflow ||
            (r_upload_metadata_valid_sync[2] &&
             ((r_upload_width_sync2 != (r_host_frame_1080==2 ? 256 : r_host_frame_1080==1 ? 1920 : 1024)) ||
              (r_upload_height_sync2 != (r_host_frame_1080==2 ? 224 : r_host_frame_1080==1 ? 1080 : 600))))),
        .fifo_data_i(w_upload_fifo_rdata),
		.fifo_word_count_i(w_upload_fifo_rd_count),
		.fifo_read_o(w_upload_fifo_read),
		.axi_awaddr_o(w_host_awaddr),
		.axi_awlen_o(w_host_awlen),
		.axi_awvalid_o(w_host_awvalid),
		.axi_awready_i(w_host_awready),
		.axi_wdata_o(w_host_wdata),
		.axi_wstrb_o(w_host_wstrb),
		.axi_wlast_o(w_host_wlast),
		.axi_wvalid_o(w_host_wvalid),
		.axi_wready_i(w_host_wready),
		.axi_bvalid_i(w_host_bvalid),
		.axi_bresp_i(w_ddr3_bresp),
		.active_o(w_upload_writer_active),
		.complete_pulse_o(w_upload_writer_complete),
		.success_o(w_upload_writer_success),
		.axi_error_o(w_upload_writer_axi_error)
	);
	
	wire 			w_wframe_vsync; 
	wire 	[7:0] 	w_axi_tp; 
	
	 
	axi4_ctrl_capture #(.C_RD_END_ADDR(1920 * 2 * 1080), .C_W_WIDTH(CSI_DATA_WIDTH), .C_R_WIDTH(16), .C_ID_LEN(4)) u_axi4_ctrl (

		.axi_clk        (w_ddr3_ui_clk            ),
		.axi_reset      (w_ddr3_ui_rst            ),

		.axi_awaddr     (w_camera_awaddr       ),
		.axi_awlen      (w_camera_awlen        ),
		.axi_awvalid    (w_camera_awvalid      ),
		.axi_awready    (w_camera_awready      ),

		.axi_wdata      (w_camera_wdata        ),
		.axi_wstrb      (w_camera_wstrb        ),
		.axi_wlast      (w_camera_wlast        ),
		.axi_wvalid     (w_camera_wvalid       ),
		.axi_wready     (w_camera_wready       ),

		.axi_bid        (w_ddr3_bid   ),
		.axi_bresp      (w_camera_bresp ),
		.axi_bvalid     (w_camera_bvalid),

		.axi_arid       (w_ddr3_arid         ),
		.axi_araddr     (w_legacy_araddr       ),
		.axi_arlen      (w_legacy_arlen        ),
		.axi_arvalid    (w_legacy_arvalid      ),
		.axi_arready    (w_legacy_arready      ),

		.axi_rid        (w_ddr3_rid          ),
		.axi_rdata      (w_ddr3_rdata        ),
		.axi_rresp      (0        ),
		.axi_rlast      (w_ddr3_rlast        ),
		.axi_rvalid     (w_legacy_rvalid       ),
		.axi_rready     (w_legacy_rready       ),

		.wframe_pclk    (w_cmos_pclk          ),
		.wframe_vsync   (w_capture_writer_vsync),
		.wframe_data_en (w_capture_writer_data_en),
		.wframe_data    (cmos_frame_Gray),
		.capture_frozen_async (w_capture_frozen_pclk),
		.frozen_frame_ready   (w_frozen_frame_ready),
		.frame_size_bytes_i   (r_resolution_select == 2'd1 ? 32'd4147200 : 32'd1228800),
		 


		.display_1080_i       (r_resolution_select == 2'd1),
		
		.rframe_pclk    (clk_lvds_1x            ),
		.rframe_vsync   (~lcd_vs             ),		 
		.rframe_data_en (lcd_request             ),
		.rframe_data    (lcd_data           ),

		.dump_start     (w_dump_start),
		.dump_abort_i   (w_cmd_resume || w_spi_upload_begin),
		.dump_external_select_i(w_stream_host_select || w_jpeg_dump_direct),
        .dump_reverse_words_i(w_camera_advanced_layout && w_stream_claim && !w_jpeg_dump_direct),
		.dump_result_select_i(w_jpeg_dump_direct || ((r_frame_result_select || r_frame_original_select) && w_stream_host_select)),.dump_result_base_i(w_jpeg_dump_direct ? w_jpeg_dump_base : r_frame_result_select ? FRAME_RESULT_BASE : {8'd0,r_frame_input_slot,22'd0}),.captured_slot_o(w_captured_slot),
        .dump_external_slot_i(w_upload_slot),
		.dump_frame_size_i(w_jpeg_dump_direct ? w_jpeg_dump_size : w_stream_host_select ? (w_stream_use_1080==2 ? 32'd114688 : w_stream_use_1080==1 ? 32'd4147200 : 32'd1228800) :
		                  (r_resolution_select == 2'd1 ? 32'd4147200 : 32'd1228800)),
		.dump_busy      (w_dump_busy),
		.dump_data      (w_dump_data),
		.dump_valid     (w_dump_valid),
		.dump_ready     (w_dump_ready),
		.dump_done      (w_dump_done),
		.upload_slot_o  (w_upload_slot),
		
		.tp_o 		(w_axi_tp)
	);
	assign led_o[3:0] = w_axi_tp; 
	
	
	
	
	 

	wire 	[15:0] 	w_lcd_data_swap = {lcd_data[7:0], lcd_data[15:8]}; 
	wire 	[7:0] 	lcd_data_r = {lcd_data[15:11], 3'b0}; 
	wire 	[7:0] 	lcd_data_g = {lcd_data[10:5], 2'b0}; 
	wire 	[7:0] 	lcd_data_b = {lcd_data[4:0], 3'b0}; 
	
	lcd_driver u_lcd_driver
	(
	     
	    .clk        (clk_lvds_1x   ),
	    .rst_n      (rstn_lvds_1x), 
	    
	     
	    .lcd_dclk   (               ),
	    .lcd_blank  (               ),
	    .lcd_sync   (               ),
	    .lcd_request(lcd_request    ), 	 
	    .lcd_hs     (lcd_hs         ),
	    .lcd_vs     (lcd_vs         ),
	    .lcd_en     (lcd_de         ),
	    .lcd_rgb    ({lcd_red2,lcd_green2,lcd_blue2, lcd_red,lcd_green,lcd_blue}),
	    
	     
	    .lcd_data   ({lcd_data_r, lcd_data_g, lcd_data_b}  )
	);
	
	
	
	
	
	
	
	 


	
	assign lvds_txc_oe  	= 1'b1; 	 
	assign lvds_txd0_oe 	= 1'b1; 	 
	assign lvds_txd1_oe 	= 1'b1; 	 
	assign lvds_txd2_oe 	= 1'b1; 	 
	assign lvds_txd3_oe 	= 1'b1; 	 
	assign lvds_txc_rst_o  	= ~rstn_lvds_1x; 	 
	assign lvds_txd0_rst_o 	= ~rstn_lvds_1x; 	 
	assign lvds_txd1_rst_o 	= ~rstn_lvds_1x; 	 
	assign lvds_txd2_rst_o 	= ~rstn_lvds_1x; 	 
	assign lvds_txd3_rst_o 	= ~rstn_lvds_1x; 	 
	
	wire    [7:0]   w_lvds_c0 = 7'b1100011;
	wire    [7:0]   w_lvds_d0 = {lcd_green[0],  lcd_red[5:0]};
	wire    [7:0]   w_lvds_d1 = {lcd_blue[1:0], lcd_green[5:1]};
	wire    [7:0]   w_lvds_d2 = {lcd_de, 2'b0,  lcd_blue[5:2]};   				 
	wire    [7:0]   w_lvds_d3 = {1'b0, lcd_blue[7:6], lcd_green[7:6], lcd_red[7:6]};
	
	assign  lvds_txc_o  = {w_lvds_c0[0], w_lvds_c0[1], w_lvds_c0[2], w_lvds_c0[3], w_lvds_c0[4], w_lvds_c0[5], w_lvds_c0[6]};
	assign  lvds_txd0_o = {w_lvds_d0[0], w_lvds_d0[1], w_lvds_d0[2], w_lvds_d0[3], w_lvds_d0[4], w_lvds_d0[5], w_lvds_d0[6]};
	assign  lvds_txd1_o = {w_lvds_d1[0], w_lvds_d1[1], w_lvds_d1[2], w_lvds_d1[3], w_lvds_d1[4], w_lvds_d1[5], w_lvds_d1[6]};
	assign  lvds_txd2_o = {w_lvds_d2[0], w_lvds_d2[1], w_lvds_d2[2], w_lvds_d2[3], w_lvds_d2[4], w_lvds_d2[5], w_lvds_d2[6]};
	assign  lvds_txd3_o = {w_lvds_d3[0], w_lvds_d3[1], w_lvds_d3[2], w_lvds_d3[3], w_lvds_d3[4], w_lvds_d3[5], w_lvds_d3[6]};
	
	
endmodule
