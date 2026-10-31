 
module axi4_ctrl_capture #(
	parameter 	C_ID_LEN      = 8, 
			C_DATA_LEN    = 128, 
			C_DATA_SIZE   = 4, 	 
			
			C_BURST_LEN   = 128,
			
			C_STRB_LEN    = C_DATA_LEN / 8, 
			C_ADDR_INC    = C_BURST_LEN * C_STRB_LEN,
			
			C_BASE_ADDR   = 32'h00000000, 	 
			C_BUF_SIZE    = 22, 			 
			C_RD_END_ADDR = 1280 * 720,
			
			C_W_WIDTH     = 64, 
			C_R_WIDTH     = 8
)(
    input  wire                 axi_clk         ,
    input  wire                 axi_reset       ,
    
    output       [C_ID_LEN-1:0]      axi_awid        ,
    output       [31:0]      axi_awaddr      ,
    output       [ 7:0]      axi_awlen       ,
    output       [ 2:0]      axi_awsize      ,
    output       [ 1:0]      axi_awburst     ,
    output                   axi_awlock      ,
    output       [ 3:0]      axi_awcache     ,
    output       [ 2:0]      axi_awprot      ,
    output       [ 3:0]      axi_awqos       ,
    output reg                  axi_awvalid     ,
    input  wire                 axi_awready     ,
    
    output       [C_DATA_LEN-1:0]      axi_wdata       ,
    output       [C_STRB_LEN-1:0]      axi_wstrb       ,
    output                   axi_wlast       ,
    output reg                  axi_wvalid      ,
    input  wire                 axi_wready      ,
    
    input  wire     [C_ID_LEN-1:0]      axi_bid         ,
    input  wire     [ 1:0]      axi_bresp       ,
    input  wire                 axi_bvalid      ,
    output                   axi_bready      ,
    
    output       [C_ID_LEN-1:0]      axi_arid        ,
    output       [31:0]      axi_araddr      ,
    output       [ 7:0]      axi_arlen       ,
    output       [ 2:0]      axi_arsize      ,
    output       [ 1:0]      axi_arburst     ,
    output                   axi_arlock      ,
    output       [ 3:0]      axi_arcache     ,
    output       [ 2:0]      axi_arprot      ,
    output       [ 3:0]      axi_arqos       ,
    output reg                  axi_arvalid     ,
    input  wire                 axi_arready     ,
    
    input  wire     [C_ID_LEN-1:0]      axi_rid         ,
    input  wire     [C_DATA_LEN-1:0]      axi_rdata       ,
    input  wire     [ 1:0]      axi_rresp       ,
    input  wire                 axi_rlast       ,
    input  wire                 axi_rvalid      ,
    output                   axi_rready      ,
    
    input  wire                 wframe_pclk     ,
    input  wire                 wframe_vsync    ,		 
    input  wire                 wframe_data_en  ,
    input  wire     [C_W_WIDTH-1:0]      wframe_data     ,
    input  wire                 capture_frozen_async,
    output reg                  frozen_frame_ready,
    input  wire [31:0]           frame_size_bytes_i,
    input  wire                  display_1080_i,
    
    input  wire                 rframe_pclk     ,
    input  wire                 rframe_vsync    ,		 
    input  wire                 rframe_data_en  ,
    output wire     [C_R_WIDTH-1:0]      rframe_data     ,

     

    input  wire                 dump_start       ,
    input  wire                 dump_abort_i     ,
    input  wire                 dump_external_select_i,
    input  wire                 dump_reverse_words_i,
    input wire dump_result_select_i,
    input wire [31:0] dump_result_base_i,
    output wire [1:0] captured_slot_o,
    input  wire [1:0]           dump_external_slot_i,
    input  wire [31:0]          dump_frame_size_i,
    output reg                  dump_busy        ,
    output wire     [7:0]       dump_data        ,
    output wire                 dump_valid       ,
    input  wire                 dump_ready       ,
    output reg                  dump_done        ,
    output wire [1:0]           upload_slot_o,

    output 		[31:0] 	tp_o
);
	
	initial begin
		axi_awvalid <= 0; 
		axi_wvalid <= 0; 
		axi_arvalid <= 0; 
	end

	assign axi_awid    = {C_ID_LEN{1'b0}};
	assign axi_awlen   = C_BURST_LEN - 1'b1;
	assign axi_awsize  = C_DATA_SIZE;
	assign axi_awburst = 2'b01;	 
	assign axi_awlock  = 1'b0;
	assign axi_awcache = 0;
	assign axi_awprot  = 3'b0;
	assign axi_awqos   = 4'b0;
	assign axi_wstrb   = 32'hFFFFFFFF;
	assign axi_bready  = 1; 
	    
	assign axi_arid    = {C_ID_LEN{1'b0}};
	assign axi_arsize  = C_DATA_SIZE;
	assign axi_arburst = 2'b01;	 
	assign axi_arlock  = 1'b0;
	assign axi_arcache = 0;
	assign axi_arprot  = 3'b0;
	assign axi_arqos   = 4'b0;
	assign axi_rready  = 1; 
	
	
	
	
	 

	reg	[1:0] 	rc_wframe_index;
	reg [1:0] dump_slot;
    reg [31:0] dump_base;
    assign captured_slot_o=r_wframe_index_last;
	reg frame_write_error;
	reg	[1:0] 	rc_rframe_index;
	assign upload_slot_o = rc_wframe_index;

	 
	wire [1:0] w_slot_one = rc_wframe_index + 2'd1;
	wire [1:0] w_slot_two = rc_wframe_index + 2'd2;
	wire [1:0] w_slot_three = rc_wframe_index + 2'd3;
	wire w_slot_one_free = (w_slot_one != rc_rframe_index) &&
	                       !(dump_busy && w_slot_one == dump_slot);
	wire w_slot_two_free = (w_slot_two != rc_rframe_index) &&
	                       !(dump_busy && w_slot_two == dump_slot);
	wire [1:0] w_wframe_index_next = w_slot_one_free ? w_slot_one :
	                                  w_slot_two_free ? w_slot_two : w_slot_three;

	reg 	[1:0] 	r_wframe_index_last = 0; 
	
	reg 			r_wframe_inc = 0, r_rframe_inc = 0; 

	always @(posedge axi_clk) begin
		if(axi_reset) begin
			rc_wframe_index <= 2'b0;
			rc_rframe_index <= 2'd2;
			r_wframe_index_last <= 0; 
			
		end else begin
			rc_wframe_index <= rc_wframe_index; 
			rc_rframe_index <= rc_rframe_index; 
			
			 
			case ({r_rframe_inc, r_wframe_inc})
				2'b01: begin
						 
						rc_wframe_index <= w_wframe_index_next; 	 
						if (!frame_write_error)
							r_wframe_index_last <= rc_wframe_index;
					end
				2'b10: begin
						 
						rc_rframe_index <= r_wframe_index_last; 
					end
				2'b11: begin
						 
						rc_wframe_index <= w_wframe_index_next; 	 
						rc_rframe_index <= frame_write_error ?
						                         r_wframe_index_last : rc_wframe_index;
						if (!frame_write_error)
							r_wframe_index_last <= rc_wframe_index;
					end
			endcase
			
		end
	end
	
	
	
	 


	wire 				w_wfifo_pempty, w_wfifo_empty; 
	wire 				w_wfifo_ren; 
	wire 	[C_DATA_LEN-1:0] 	w_wfifo_rdata; 

	 
	reg 	[3:0] 	rs_w = 0; 
	wire 	[3:0] 	ws_w_idle = 0; 
	wire 	[3:0] 	ws_w_wdata = 1; 
	wire 	[3:0] 	ws_w_winc = 2; 
	wire 	[3:0] 	ws_w_eof = 3; 

	 
	reg 	[C_BUF_SIZE-1:0] 	rc_w_ptr = 0; 
	reg 	[0:0] 		rc_w_eof = 0; 
	reg 				r_w_rst = 1; 
	
	 
	reg 	[7:0] 	rc_burst = 0; 	 


	reg 	[1:0] 	r_wframe_sync = 0; 	
	reg 			r_weof_pending = 0; 
	reg [11:0] pending_write_responses;
	reg [2:0] capture_frozen_sync;
	reg [31:0] awaddr_latched;
	wire write_address_accepted = axi_awvalid && axi_awready;
	wire write_response_accepted = axi_bvalid && axi_bready;

	always @(posedge axi_clk or posedge axi_reset) begin
		if (axi_reset) begin
			pending_write_responses <= 12'd0;
			frame_write_error <= 1'b0;
			capture_frozen_sync <= 3'd0;
			frozen_frame_ready <= 1'b0;
		end else begin
			capture_frozen_sync <= {capture_frozen_sync[1:0], capture_frozen_async};
			case ({write_address_accepted, write_response_accepted})
				2'b10: pending_write_responses <= pending_write_responses + 12'd1;
				2'b01: if (pending_write_responses != 12'd0)
					pending_write_responses <= pending_write_responses - 12'd1;
				default: pending_write_responses <= pending_write_responses;
			endcase
			if (write_response_accepted && axi_bresp != 2'b00)
				frame_write_error <= 1'b1;
			if (r_wframe_inc) begin
				frozen_frame_ready <= capture_frozen_sync[2] && !frame_write_error;
				frame_write_error <= 1'b0;
			end else if (!capture_frozen_sync[2]) begin
				frozen_frame_ready <= 1'b0;
			end
		end
	end

	always @(posedge axi_clk or posedge axi_reset) begin
		if(axi_reset) begin
			rs_w <= 0; 
			rc_w_ptr <= 0; 
			rc_w_eof <= 0; 
			r_w_rst <= 1; 
			axi_awvalid <= 0; 
			axi_wvalid <= 0; 
			r_wframe_sync <= 0; 
			r_weof_pending <= 0; 
			r_wframe_inc <= 0; 
			awaddr_latched <= 32'd0;
			
		end else begin
			rc_w_eof <= 0; 
			r_wframe_inc <= 0; 
			
			 
			r_wframe_sync <= {r_wframe_sync, wframe_vsync}; 
			if(r_wframe_sync == 2'b10) begin
				r_weof_pending <= 1; 
			end else begin
			end
			
			if(axi_awready) begin
				axi_awvalid <= 0; 
			end else begin
			end
			
			case (rs_w)
				ws_w_idle: begin
						rc_burst <= 0; 
						r_w_rst <= 0; 
						
						if(!axi_awvalid && ~w_wfifo_pempty) begin
							axi_awvalid <= 1; 
							axi_wvalid <= 1; 
							awaddr_latched <= C_BASE_ADDR + {rc_wframe_index, rc_w_ptr};
							rs_w <= ws_w_wdata; 

						end else if(!axi_awvalid && r_weof_pending && (~w_wfifo_empty)) begin
							 
							axi_awvalid <= 1; 
							axi_wvalid <= 1; 
							awaddr_latched <= C_BASE_ADDR + {rc_wframe_index, rc_w_ptr};
							rs_w <= ws_w_wdata; 
							
						end else if(r_weof_pending) begin
						 
							r_w_rst <= 1; 
							rs_w <= ws_w_eof; 
							
						end else begin
						end
					end
					
				ws_w_eof: begin
						 
						r_weof_pending <= 0; 
						rc_w_ptr <= 0; 
						
						rc_w_eof <= rc_w_eof + 1; 
						if (&rc_w_eof && pending_write_responses == 12'd0 &&
						    !axi_awvalid && !axi_wvalid) begin
							r_wframe_inc <= 1'b1;
							rs_w <= ws_w_idle;
						end
						else begin
						end
					end
					
				ws_w_wdata: begin
						rc_burst <= rc_burst + axi_wready; 
						
						 
						if(axi_wlast && axi_wready) begin
							axi_wvalid <= 0; 
							rs_w <= ws_w_winc; 
						end else begin
						end
					end
					
				ws_w_winc: begin
						rc_w_ptr <= rc_w_ptr + C_ADDR_INC; 
						rs_w <= ws_w_idle; 
					end
			endcase
		end
	end
	assign axi_awaddr = awaddr_latched;
	assign axi_wdata = w_wfifo_rdata; 
	assign axi_wlast = (rc_burst >= C_BURST_LEN - 1); 
	
	assign w_wfifo_ren = axi_wvalid && axi_wready; 
	
	
	assign tp_o[1:0] = {rs_w[1:0]}; 
	assign tp_o[2] = axi_wvalid; 
	assign tp_o[3] = wframe_data_en; 
	
	
	generate
		if(C_W_WIDTH == 64) begin: Gen_FIFO_W64
			W0_FIFO_64 u_W0_FIFO_64 
			(
			    .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end else if(C_W_WIDTH == 32) begin: Gen_FIFO_W32
			W0_FIFO_32 u_W0_FIFO_32
			(
			    .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end else if(C_W_WIDTH == 16) begin: Gen_FIFO_W32
			W0_FIFO_16 u_W0_FIFO_16
			(
			    .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end else if(C_W_WIDTH == 8) begin: Gen_FIFO_W8
			W0_FIFO_8 u_W0_FIFO_8 
			(
			    .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end
	endgenerate




















reg                             rframe_vsync_dly;

always @(posedge rframe_pclk)
begin
    if(axi_reset == 1'b1)
        rframe_vsync_dly <= 1'b0;
    else
        rframe_vsync_dly <= rframe_vsync;
end

wire                            rframe_vsync_neg;
assign rframe_vsync_neg =  rframe_vsync_dly & ~rframe_vsync;

reg             [4:0]           rfifo_cnt;

always @(posedge rframe_pclk)
begin
    if(axi_reset == 1'b1)
        rfifo_cnt <= 5'h1f;
    else
    begin
        if(rframe_vsync_neg == 1'b1)
            rfifo_cnt <= 5'h1f;
        else if(rfifo_cnt > 5'd0)
            rfifo_cnt <= rfifo_cnt - 1'b1;
        else
            rfifo_cnt <= 5'b0;
    end
end

reg                             rfifo_rst;

always @(posedge rframe_pclk)
begin
    if(axi_reset == 1'b1)
        rfifo_rst <= 1'b1;
    else
    begin
        if(rfifo_cnt == 5'b0)
            rfifo_rst <= 1'b0;
        else
            rfifo_rst <= 1'b1;
    end
end


 
reg [1:0] display_mode_sync;
reg display_mode_seen;
reg [6:0] display_reset_hold;
always @(posedge axi_clk or posedge axi_reset) begin
	if (axi_reset) begin
		display_mode_sync <= 2'b00;
		display_mode_seen <= 1'b0;
		display_reset_hold <= 7'd0;
	end else begin
		display_mode_sync <= {display_mode_sync[0], display_1080_i};
		if (display_mode_sync[1] != display_mode_seen) begin
			display_mode_seen <= display_mode_sync[1];
			display_reset_hold <= 7'd100;
		end else if (display_reset_hold != 0)
			display_reset_hold <= display_reset_hold - 1'b1;
	end
end

wire 			w_rfifo_rst = axi_reset || rfifo_rst || (display_reset_hold != 0); 

reg                             rfifo_wenb;
reg             [C_DATA_LEN-1:0]          rfifo_wdata;
wire            [ 9:0]          rfifo_wcnt;
wire 					  rfifo_wfull; 
wire                            rfifo_wr_rst_busy;
wire 					w_rfifo_aempty; 
wire 					w_rfifo_empty; 


generate
	if(C_R_WIDTH == 8) begin: Gen_RFIFO_8
		R0_FIFO_8 u_R0_FIFO_8
		(
			.wr_clk_i		(axi_clk),
			.wr_en_i		(rfifo_wenb),
			.wdata			(rfifo_wdata),
			.a_rst_i		(w_rfifo_rst), 
			.prog_full_o		(rfifo_wfull),
			
			.rd_clk_i		(rframe_pclk),
			.rd_en_i		(rframe_data_en),
			.rdata			(rframe_data),
			.empty_o		(w_rfifo_empty),
			.almost_empty_o	(w_rfifo_aempty)
		);
	end else if(C_R_WIDTH == 16) begin: Gen_RFIFO_16	
		R0_FIFO_16 u_R0_FIFO_16
		(
			.wr_clk_i		(axi_clk),
			.wr_en_i		(rfifo_wenb),
			.wdata			(rfifo_wdata),
			.a_rst_i		(w_rfifo_rst), 
			.prog_full_o		(rfifo_wfull),
			
			.rd_clk_i		(rframe_pclk),
			.rd_en_i		(rframe_data_en),
			.rdata			(rframe_data),
			.empty_o		(w_rfifo_empty),
			.almost_empty_o	(w_rfifo_aempty)
		);
	end
endgenerate
		
reg r_rfifo_rst = 0; 
always @(posedge axi_clk)
begin
	r_rfifo_rst <= w_rfifo_rst; 
end

 

reg             [15:0]               rfifo_wr_rst_busy_dly = 2'b0;

always @(posedge axi_clk or posedge r_rfifo_rst)
begin
    if(r_rfifo_rst == 1'b1)
        rfifo_wr_rst_busy_dly <= 0;
    else
        rfifo_wr_rst_busy_dly <= {rfifo_wr_rst_busy_dly,1'b1};
end

wire                                rfifo_wr_rst_busy_neg;
assign rfifo_wr_rst_busy_neg = (rfifo_wr_rst_busy_dly[1:0] == 2'b01) ? 1'b1 : 1'b0;

reg             [4:0]               read_ddr_delay_cnt;

always @(posedge axi_clk or posedge r_rfifo_rst)
begin
    if(r_rfifo_rst == 1'b1)
        read_ddr_delay_cnt <= 5'b0;
    else
    begin
        if(rfifo_wr_rst_busy_neg == 1'b1)
            read_ddr_delay_cnt <= 5'd31;
        else if(read_ddr_delay_cnt > 5'b0)
            read_ddr_delay_cnt <= read_ddr_delay_cnt - 1'b1;
        else
            read_ddr_delay_cnt <= 5'b0;
    end
end

always @(posedge axi_clk or posedge axi_reset) begin
	if(axi_reset)
		r_rframe_inc <= 0; 
	else
		r_rframe_inc <= rfifo_wr_rst_busy_neg; 
end


wire                                read_ddr_init_flag;
assign read_ddr_init_flag = (read_ddr_delay_cnt == 5'd1) ? 1'b1 : 1'b0;

 





localparam D_IDLE = 2'd0;
localparam D_ADDR = 2'd1;
localparam D_DATA = 2'd2;
localparam D_SEND = 2'd3;

reg [1:0] dump_state;
reg [C_BUF_SIZE-1:0] araddr;
reg [10:0] display_row;
reg [12:0] display_row_bytes_left;
reg [C_BUF_SIZE-1:0] dump_addr;
reg [31:0] dump_size;
reg [127:0] dump_shift;
reg dump_reverse_words;
 
wire [127:0] dump_camera_order = {
    axi_rdata[15:0], axi_rdata[31:16], axi_rdata[47:32], axi_rdata[63:48],
    axi_rdata[79:64], axi_rdata[95:80], axi_rdata[111:96], axi_rdata[127:112]
};
reg [3:0] dump_byte_index;
reg read_active;
reg read_is_dump;
reg ar_is_dump;
reg [31:0] araddr_latched;
reg [7:0] arlen_latched;
reg ar_drop_display;
reg read_drop_display;

assign dump_data = dump_shift[7:0];
assign dump_valid = dump_busy && (dump_state == D_SEND);

 


wire [31:0] active_frame_size = (frame_size_bytes_i != 0) ?
                                frame_size_bytes_i : C_RD_END_ADDR;
wire display_read_req = !r_rfifo_rst && rfifo_wr_rst_busy_dly[15] &&
                        (display_row < 11'd600) &&
                        (araddr < active_frame_size) && !rfifo_wfull;
wire dump_read_req = dump_busy && (dump_state == D_ADDR);
wire [12:0] display_bytes_to_4k = 13'd4096 - {1'b0, araddr[11:0]};
wire [12:0] display_segment_bytes =
    (display_row_bytes_left < display_bytes_to_4k) ?
        display_row_bytes_left : display_bytes_to_4k;
wire [7:0] display_segment_arlen = display_segment_bytes[12:4] - 1'b1;

assign axi_arlen = arlen_latched;
assign axi_araddr = araddr_latched;

always @(posedge axi_clk or posedge axi_reset) begin
    if (axi_reset) begin
        dump_state <= D_IDLE;
        axi_arvalid <= 0;
        ar_is_dump <= 0;
        read_active <= 0;
        read_is_dump <= 0;
        araddr <= 0;
        display_row <= 0;
        display_row_bytes_left <= C_ADDR_INC;
        dump_addr <= 0;
        dump_size <= C_RD_END_ADDR;
        dump_shift <= 0;
        dump_reverse_words <= 1'b0;
        dump_byte_index <= 0;
        dump_busy <= 0;
        dump_done <= 0;

        dump_slot <= 2'd0;
        dump_base <= 0;
        araddr_latched <= 32'd0;
        arlen_latched <= 8'd0;
        ar_drop_display <= 1'b0;
        read_drop_display <= 1'b0;
    end else begin
        dump_done <= 0;

         

        if (r_rfifo_rst) begin
            araddr <= 0;
            display_row <= 0;
            display_row_bytes_left <= C_ADDR_INC;
            if (axi_arvalid && !ar_is_dump && !axi_arready)
                ar_drop_display <= 1'b1;
            if (read_active && !read_is_dump)
                read_drop_display <= 1'b1;
        end

        if (read_ddr_init_flag) begin
            display_row <= 0;
            display_row_bytes_left <= C_ADDR_INC;
            araddr <= display_1080_i ? (32'd3840 * 32'd240 + 32'd896) : 0;
        end

        if (dump_start && !dump_busy && !dump_abort_i) begin
            dump_busy <= 1;
            dump_reverse_words <= dump_reverse_words_i;
            dump_base <= dump_result_select_i ? dump_result_base_i : C_BASE_ADDR + {8'd0,(dump_external_select_i ? dump_external_slot_i : r_wframe_index_last),22'd0};
            dump_slot <= dump_external_select_i ? dump_external_slot_i
                                                : r_wframe_index_last;
            dump_size <= (dump_frame_size_i != 0) ? dump_frame_size_i
                                                  : active_frame_size;
            dump_state <= D_ADDR;
            dump_addr <= 0;
            dump_byte_index <= 0;
        end

         

        if (dump_busy && (dump_state == D_SEND) && dump_ready) begin
            if (dump_byte_index == 4'd15) begin
                if (dump_addr + 16 >= dump_size) begin
                    dump_busy <= 0;
                    dump_done <= 1;
                    dump_state <= D_IDLE;
                end else begin
                    dump_addr <= dump_addr + 16;
                    dump_state <= D_ADDR;
                end
            end else begin
                dump_shift <= {8'h00, dump_shift[127:8]};
                dump_byte_index <= dump_byte_index + 1'b1;
            end
        end

         
        if (axi_arvalid && axi_arready) begin
            axi_arvalid <= 0;
            read_active <= 1;
            read_is_dump <= ar_is_dump;
            read_drop_display <= !ar_is_dump && (ar_drop_display || r_rfifo_rst);
            if (ar_is_dump)
                dump_state <= D_DATA;
            else if (!r_rfifo_rst) begin
                if (display_1080_i) begin
                    if (display_segment_bytes >= display_row_bytes_left) begin
                        display_row <= display_row + 1'b1;
                        display_row_bytes_left <= C_ADDR_INC;
                        araddr <= araddr + display_segment_bytes +
                                  (32'd3840 - C_ADDR_INC);
                    end else begin
                        display_row_bytes_left <= display_row_bytes_left -
                                                  display_segment_bytes;
                        araddr <= araddr + display_segment_bytes;
                    end
                end else begin
                    display_row <= display_row + 1'b1;
                    display_row_bytes_left <= C_ADDR_INC;
                    araddr <= araddr + C_ADDR_INC;
                end
            end
        end

         

        if (axi_rvalid && read_active) begin
            if (read_is_dump && dump_busy && !dump_abort_i) begin
                dump_shift <= dump_reverse_words ? dump_camera_order : axi_rdata;
                dump_byte_index <= 0;
                dump_state <= D_SEND;
            end
            if (axi_rlast) begin
                read_active <= 0;
                read_drop_display <= 1'b0;
            end
        end

         



        if (!read_active && !axi_arvalid) begin
            if (dump_read_req) begin
                ar_is_dump <= 1;
                araddr_latched <= dump_base + dump_addr;
                arlen_latched <= 8'd0;
                ar_drop_display <= 1'b0;
                axi_arvalid <= 1;
            end else if (display_read_req) begin
                ar_is_dump <= 0;
                araddr_latched <= C_BASE_ADDR + {rc_rframe_index, araddr};
                arlen_latched <= display_1080_i ? display_segment_arlen :
                                  C_BURST_LEN - 1'b1;
                ar_drop_display <= 1'b0;
                axi_arvalid <= 1;
            end
        end

         


        if (dump_abort_i) begin
            dump_busy <= 0;
            dump_done <= 0;
            dump_state <= D_IDLE;
            dump_byte_index <= 0;
        end
    end
end

always @(posedge axi_clk)
begin
    if(axi_reset == 1'b1)
        rfifo_wenb <= 1'b0;
    else
    begin
        if((axi_rvalid == 1'b1) && (axi_rready == 1'b1) &&
           read_active && !read_is_dump && !read_drop_display && !w_rfifo_rst)
            rfifo_wenb <= 1'b1;
        else
            rfifo_wenb <= 1'b0;
    end
end

always @(posedge axi_clk)
begin
    rfifo_wdata <= axi_rdata;
end

endmodule
