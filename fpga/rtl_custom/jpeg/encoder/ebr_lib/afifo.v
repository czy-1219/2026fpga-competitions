////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	afifo.v
//
// Project:	afifo, A formal proof of Cliff Cummings' asynchronous FIFO
//
// Purpose:	This file defines the behaviour of an asynchronous FIFO.
//		It was originally copied from a paper by Clifford E. Cummings
//	of Sunburst Design, Inc.  Since then, many of the variable names have
//	been changed and the logic has been rearranged.  However, the
//	fundamental logic remains the same.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
//  Adopted by: Robert Metchev / Chips & Scripts (rmetchev@ieee.org)
//  for Brilliant Labs Ltd.
//
////////////////////////////////////////////////////////////////////////////////
//
// The Verilog logic for this project comes from the paper by Clifford E.
// Cummings, of Sunburst Design, Inc, titled: "Simulation and Synthesis
// Techniques for Asynchronous FIFO Design".  This paper may be found at
// sunburst-design.com.
//
// Minor edits to that logic have been made by Gisselquist Technology, LLC.
// Gisselquist Technology, LLC, asserts no copywrite or ownership of these
// minor edits.
//
//
//
// The formal properties within this project, contained between the
// `ifdef FORMAL line and its corresponding `endif, are owned by Gisselquist
// Technology, LLC, and Copyrighted as such.  Hence, the following copyright
// statement regarding these properties:
//
// Copyright (C) 2018, Gisselquist Technology, LLC
//
// These properties are free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//

//`default_nettype	none
//
//
module afifo(i_wclk, i_wrst_n, i_wr, i_wdata, o_wfull,
		i_rclk, i_rrst_n, i_rd, o_rdata, o_rempty, wptr, rptr);
	parameter	DSIZE = 2,
			ASIZE = 4, FULL_EMPTY_SAFEGUARD = 1;
	localparam	DW = DSIZE,
			AW = ASIZE;
	input	wire			i_wclk, i_wrst_n, i_wr;
	input	wire	[DW-1:0]	i_wdata;
	output	reg			o_wfull;
	input	wire			i_rclk, i_rrst_n, i_rd;
	output	wire	[DW-1:0]	o_rdata;
	output	reg			o_rempty;
	output	wire    [AW:0]          wptr, rptr;

	wire	[AW-1:0]	waddr, raddr;
	wire			wfull_next, rempty_next;
	reg	[AW:0]		wgray, wbin, wq2_rgray, wq1_rgray,
				rgray, rbin, rq2_wgray, rq1_wgray;
	 
	wire	[AW:0]		wgraynext, wbinnext;
	wire	[AW:0]		rgraynext, rbinnext;

	reg	[DW-1:0]	mem	[0:((1<<AW)-1)];

	 











	initial	{ wq2_rgray,  wq1_rgray } = 0;
	always @(posedge i_wclk )  
	if (!i_wrst_n)
		{ wq2_rgray, wq1_rgray } <= 0;
	else
		{ wq2_rgray, wq1_rgray } <= { wq1_rgray, rgray };



	 
	assign	wbinnext  = wbin + { {(AW){1'b0}}, ((i_wr) && (!o_wfull || !FULL_EMPTY_SAFEGUARD)) };
	assign	wgraynext = (wbinnext >> 1) ^ wbinnext;

	assign	waddr = wbin[AW-1:0];
	assign	wptr = wbin;

	 

	initial	{ wbin, wgray } = 0;
	always @(posedge i_wclk )  
	if (!i_wrst_n)
		{ wbin, wgray } <= 0;
	else
		{ wbin, wgray } <= { wbinnext, wgraynext };

	 


	assign	wfull_next = (wgray == (wq2_rgray ^ (2'b11 << (AW-1))) );

	 


	always_comb	o_wfull = wfull_next;
	 








	always @(posedge i_wclk)
	if ((i_wr)&&(!o_wfull || !FULL_EMPTY_SAFEGUARD))
		mem[waddr] <= i_wdata;

	 















	initial	{ rq2_wgray,  rq1_wgray } = 0;
	always @(posedge i_rclk )  
	if (!i_rrst_n)
		{ rq2_wgray, rq1_wgray } <= 0;
	else
		{ rq2_wgray, rq1_wgray } <= { rq1_wgray, wgray };


	 
	assign	rbinnext  = rbin + { {(AW){1'b0}}, ((i_rd)&&(!o_rempty || !FULL_EMPTY_SAFEGUARD)) };
	 
	assign	rgraynext = (rbinnext >> 1) ^ rbinnext;

	 


	initial	{ rbin, rgray } = 0;
	always @(posedge i_rclk )  
	if (!i_rrst_n)
		{ rbin, rgray } <= 0;
	else
		{ rbin, rgray } <= { rbinnext, rgraynext };

	 
	assign	raddr = rbin[AW-1:0];
	assign	rptr = rbin;

	 

	assign	rempty_next = (rgray == rq2_wgray);

	always_comb o_rempty = rempty_next;
	 










	assign	o_rdata = mem[raddr];


	 








`ifdef	FORMAL
`ifdef	AFIFO
`define	ASSUME	assume
`define	ASSERT	assert
`else
`define	ASSUME	assert
`define	ASSERT	assume
`endif
	 




	reg	f_past_valid_rd, f_past_valid_wr, f_past_valid_gbl;

	initial	f_past_valid_gbl = 0;
	always @($global_clock)
		f_past_valid_gbl <= 1'b1;

	initial	f_past_valid_wr  = 0;
	always @(posedge i_wclk)
		f_past_valid_wr  <= 1'b1;

	initial	f_past_valid_rd  = 0;
	always @(posedge i_rclk)
		f_past_valid_rd  <= 1'b1;

	always @(*)
	if (!f_past_valid_gbl)
		`ASSERT((!f_past_valid_wr)&&(!f_past_valid_rd));

	 







`ifdef	AFIFO
	localparam	F_CLKBITS=5;
	wire	[F_CLKBITS-1:0]	f_wclk_step, f_rclk_step;

	assign	f_wclk_step = $anyconst;
	assign	f_rclk_step = $anyconst;
	always @(*)
		assume(f_wclk_step != 0);
	always @(*)
		assume(f_rclk_step != 0);

	reg	[F_CLKBITS-1:0]	f_wclk_count, f_rclk_count;

	always @($global_clock)
		f_wclk_count <= f_wclk_count + f_wclk_step;
	always @($global_clock)
		f_rclk_count <= f_rclk_count + f_rclk_step;

	always @(*)
	begin
		assume(i_wclk == f_wclk_count[F_CLKBITS-1]);
		assume(i_rclk == f_rclk_count[F_CLKBITS-1]);
	end
`endif

	 











	initial	assume(i_rrst_n == i_wrst_n);

	always @($global_clock)
		assume($fell(i_wrst_n)==$fell(i_rrst_n));

	always @($global_clock)
	if (!$rose(i_wclk))
		assume(!$rose(i_wrst_n));

	always @($global_clock)
	if (!$rose(i_rclk))
		assume(!$rose(i_rrst_n));

	always @($global_clock)
	if (!i_wrst_n)
		assert(rbin == 0);


	 







	always @($global_clock)
	if (f_past_valid_gbl)
	begin
		if (!$rose(i_wclk))
		begin
			assume($stable(i_wr));
			assume($stable(i_wdata));
			assert($stable(o_wfull)||(!i_wrst_n));
		end

		if (!$rose(i_rclk))
		begin
			assume($stable(i_rd));
			assert((o_rempty)||($stable(o_rdata)));
			assert((!i_rrst_n)||($stable(o_rempty)));
		end
	end


	 









	always @($global_clock)
	if ((!f_past_valid_wr)||(!i_wrst_n))
	begin
		`ASSUME(i_wr == 0);
		 
		`ASSERT(wgray == 0);
		`ASSERT(wbin == 0);
		`ASSERT(!o_wfull);
		 
		`ASSERT(wq1_rgray == 0);
		`ASSERT(wq2_rgray == 0);
		`ASSERT(rq1_wgray == 0);
		`ASSERT(rq2_wgray == 0);
		 
		`ASSERT(rbin == 0);
		`ASSERT(o_rempty);
	end

	always @($global_clock)
	if ((!f_past_valid_rd)||(!i_rrst_n))
	begin
		`ASSUME(i_rd == 0);
		 
		`ASSERT(rgray == 0);
		`ASSERT(rbin == 0);
		`ASSERT(rq1_wgray == 0);
		`ASSERT(rq2_wgray == 0);
		`ASSERT(wq1_rgray == 0);
		`ASSERT(wq2_rgray == 0);
	end

	 









	wire	[AW:0]		f_fill;

	assign	f_fill = (wbin - rbin);

	initial	`ASSERT(f_fill == 0);
	always @($global_clock)
		`ASSERT(f_fill <= { 1'b1, {(AW){1'b0}} });

	 


	always @($global_clock)
	if (f_fill == {1'b1,{(AW){1'b0}}})
		`ASSERT(o_wfull);

	 

	always @($global_clock)
	if (f_fill == {1'b0,{(AW){1'b1}}})
		`ASSERT((wfull_next)||(!i_wr)||(o_wfull));

	 


	always @($global_clock)
	if (f_fill == 0)
		`ASSERT(o_rempty);

	 

	always @($global_clock)
	if (f_fill == 1)
		`ASSERT((rempty_next)||(!i_rd)||(o_rempty));

	 

	always @(*)
		`ASSERT(wgray == ((wbin>>1)^wbin));
	 
	always @(*)
		`ASSERT(rgray == ((rbin>>1)^rbin));

	 



	always @(*)
		`ASSERT( (rgray == { ~wgray[AW:AW-1], wgray[AW-2:0] })
			== (f_fill == { 1'b1, {(AW){1'b0}} }) );

	 

	always @(*)
		`ASSERT((rgray == wgray) == (f_fill == 0));

	 






	reg	[AW:0]	f_w2r_rbin, f_w1r_rbin,
			f_r2w_wbin, f_r1w_wbin;
	wire	[AW:0]	f_w2r_fill, f_r2w_fill;

	 


	initial	{ f_w2r_rbin, f_w1r_rbin } = 0;
	always @(posedge i_wclk or negedge i_wrst_n)
	if (!i_wrst_n)
		{ f_w2r_rbin, f_w1r_rbin } <= 0;
	else
		{ f_w2r_rbin, f_w1r_rbin } <= { f_w1r_rbin, rbin };

	initial	{ f_r2w_wbin, f_r1w_wbin } = 0;
	always @(posedge i_rclk or negedge i_rrst_n)
	if (!i_rrst_n)
		{ f_r2w_wbin, f_r1w_wbin } <= 0;
	else
		{ f_r2w_wbin, f_r1w_wbin } <= { f_r1w_wbin, wbin };

	 



	always @(*)
		`ASSERT(rq1_wgray == ((f_r1w_wbin>>1)^f_r1w_wbin));
	always @(*)
		`ASSERT(rq2_wgray == ((f_r2w_wbin>>1)^f_r2w_wbin));

	always @(*)
		`ASSERT(wq1_rgray == ((f_w1r_rbin>>1)^f_w1r_rbin));
	always @(*)
		`ASSERT(wq2_rgray == ((f_w2r_rbin>>1)^f_w2r_rbin));

	assign	f_w2r_fill = wbin - f_w2r_rbin;
	assign	f_r2w_fill = f_r2w_wbin - rbin;

	 


	always @(*)
		`ASSERT(f_w2r_fill <= { 1'b1, {(AW){1'b0}} });
	always @(*)
		`ASSERT(f_r2w_fill <= { 1'b1, {(AW){1'b0}} });

	 



	always @(*)
	if (wgray == { ~wq2_rgray[AW:AW-1], wq2_rgray[AW-2:0] })
		`ASSERT(o_wfull);

	 


	always @(*)
	if (rgray == rq2_wgray)
		`ASSERT(o_rempty);

	 











`ifdef	ONEHOT
	always @(*)
		`ASSERT((wgray == wgray_next)
			||($onehot(wgray ^ wgray_next)));
	always @(*)
		`ASSERT((rq2_wgray == rq1_wgray)
			||($onehot(rq2_wgray ^ rq1_wgray)));
`else
	genvar	k;
	generate for(k=0; k<= AW; k=k+1)
	begin : CHECK_ONEHOT_WGRAY
		always @(*)
			`ASSERT((wgray[k] == wgraynext[k])
				||(wgray ^ wgraynext ^ (1<<k) == 0));
		always @(*)
			`ASSERT((rq2_wgray[k] == rq1_wgray[k])
				||(rq2_wgray ^ rq1_wgray ^ (1<<k) == 0));
	end endgenerate
`endif

`ifdef ONEHOT
	always @(*)
		`ASSERT((rgray == rgray_next)
			||($onehot(rgray ^ rgray_next)));
	always @(*)
		`ASSERT((wq2_rgray == wq1_rgray)
			||($onehot(wq2_rgray ^ wq1_rgray)));
`else
	genvar	k;
	generate for(k=0; k<= AW; k=k+1)
	begin : CHECK_ONEHOT_RGRAY
		always @(*)
			`ASSERT((rgray[k] == rgraynext[k])
				||(rgray ^ rgraynext ^ (1<<k) == 0));
		always @(*)
			`ASSERT((wq2_rgray[k] == wq1_rgray[k])
				||(wq2_rgray ^ wq1_rgray ^ (1<<k) == 0));
	end endgenerate
`endif

	 








`ifdef	AFIFO
	(* anyconst *) wire [AW:0]		f_const_addr;

	wire	[AW:0]		f_const_next_addr;
	assign	f_const_next_addr = f_const_addr + 1;

	(* anyconst *) reg [DW-1:0]	f_const_first, f_const_next;


	reg			f_addr_valid, f_next_valid;

	always @(*)
	begin
		f_addr_valid = 1'b0;
		if((wbin > rbin)&&(wbin > f_const_addr)
					&&(rbin <= f_const_addr))
			 
			f_addr_valid = 1'b1;
		else if ((wbin < rbin)&&(f_const_addr < wbin))
			 
			f_addr_valid = 1'b1;
		else if ((wbin < rbin)&&(rbin <= f_const_addr))
			 
			f_addr_valid = 1'b1;
	end

	always @(*)
	begin
		f_next_valid = 1'b0;
		if((wbin > rbin)&&(wbin > f_const_next_addr)
					&&(rbin <= f_const_next_addr))
			 
			f_next_valid = 1'b1;
		else if ((wbin < rbin)&&(f_const_next_addr < wbin))
			 
			f_next_valid = 1'b1;
		else if ((wbin < rbin)&&(rbin <= f_const_next_addr))
			 
			f_next_valid = 1'b1;
	end

	reg	f_first_in_fifo, f_second_in_fifo, f_both_in_fifo;

	always @(*)
		f_first_in_fifo = (f_addr_valid)
				&&(mem[f_const_addr[AW-1:0]]==f_const_first);
	always @(*)
		f_second_in_fifo = (f_next_valid)
				&&(mem[f_const_next_addr[AW-1:0]]==f_const_next);

	always @(*)
		f_both_in_fifo = (f_first_in_fifo)&&(f_second_in_fifo);

	reg	f_wait_for_first_read, f_read_first, f_read_second,
		f_wait_for_second_read;

	 
	always @(*)
		f_wait_for_first_read = (f_both_in_fifo)
				&&((!i_rd)||(f_const_addr != rbin)||(o_rempty));

	always @(*)
		f_read_first = (i_rd)&&(o_rdata == f_const_first)&&(!o_rempty)
			&&(rbin == f_const_addr)&&(f_both_in_fifo);

	always @(*)
		f_wait_for_second_read = (f_second_in_fifo)
				&&((!i_rd)||(o_rempty))
				&&(f_const_next_addr == rbin);

	always @(*)
		f_read_second = (i_rd)&&(o_rdata == f_const_next)&&(!o_rempty)
				&&(rbin == f_const_next_addr)
				&&(f_second_in_fifo);

	always @($global_clock)
	if ((f_past_valid_gbl)&&(i_wrst_n))
	begin
		if ((!$past(f_read_first))&&(($past(f_both_in_fifo))))
			assert((f_wait_for_first_read)
				|| (($rose(i_rclk))&&(f_read_first)));
		if ($past(f_read_first))
			assert(
				((!$rose(i_rclk))&&(f_read_first))
				||($rose(i_rclk)&&((f_read_second)
						||(f_wait_for_second_read))));
		if ($past(f_wait_for_second_read))
			assert((f_wait_for_second_read)
				||(($rose(i_rclk))&&(f_read_second)));
	end
`endif

	 








	always @(posedge i_wclk)
		cover(i_wrst_n);

	always @(posedge i_rclk)
		cover(i_rrst_n);

	always @($global_clock)
	if (f_past_valid_gbl)
		cover((o_rempty)&&(!$past(o_rempty)));

	always @(*)
	if (f_past_valid_gbl)
		cover(o_wfull);

	always @(posedge i_wclk)
	if (f_past_valid_wr)
		cover($past(o_wfull)&&($past(i_wr))&&(o_wfull));

	always @(posedge i_wclk)
	if (f_past_valid_wr)
		cover($past(o_wfull)&&(!o_wfull));

	always @(posedge i_wclk)
		cover((o_wfull)&&(i_wr));

	always @(posedge i_wclk)
		cover(i_wr);

	always @(posedge i_rclk)
		cover((o_rempty)&&(i_rd));

`endif
endmodule
