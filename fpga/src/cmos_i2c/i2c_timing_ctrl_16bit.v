/*-----------------------------------------------------------------------
								 \\\|///
							   \\  - -  //
								(  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2013-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author				:		CrazyBingo
Technology blogs 	: 		http://blog.chinaaet.com/crazybingo
Email Address 		: 		thereturnofbingo@gmail.com
Filename			:		i2c_timing_ctrl.v
Data				:		2013-04-13
Description			:		The testbench of I2C Ctrl timing.
Modification History	:
Data			By			Version			Change Description
=========================================================================
13/04/13		CrazyBingo	1.0				Original
13/04/14		CrazyBingo	1.1				add i2c_wdata for avoid bit width warming
14/05/13		CrazyBingo	2.0				Change to 16Bit Data module
-------------------------------------------------------------------------
|                                     Oooo								|
+-------------------------------oooO--(   )-----------------------------+
                               (   )   ) /
                                \ (   (_/
                                 \_)
-----------------------------------------------------------------------*/
`timescale 1ns/1ns
module	i2c_timing_ctrl_16bit
#(
	parameter	CLK_FREQ	= 100_000000,	 
	parameter	I2C_FREQ	= 400_000		 
)
(
	 
	input				clk,			 
	input				rst_n,		 


	output			i2c_sclk,		 

	input               	i2c_sdat_IN,
	output              	i2c_sdat_OUT,
	output              	i2c_sdat_OE,

	 
	input		[7:0]		i2c_config_size,	 
	output reg	[7:0]		i2c_config_index,	 
	input		[31:0]	i2c_config_data,	 
	output			i2c_config_done,	 
	output reg		i2c_nack_seen,		 
	output reg [7:0]	i2c_first_nack_index,
	output reg [7:0]	i2c_nack_count,
	output reg	[15:0]	i2c_rdata		 
);

 

reg [26:0]  delay_cnt;
 
localparam  DELAY_TOP = CLK_FREQ;   
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        delay_cnt <= 0;
    else if(delay_cnt < DELAY_TOP)
        delay_cnt <= delay_cnt + 1'b1;
    else
        delay_cnt <= delay_cnt;
end 

wire    delay_done = (delay_cnt == DELAY_TOP) ? 1'b1 : 1'b0;     






localparam [31:0] POST_SOFT_RESET_DELAY_CYCLES = CLK_FREQ / 200;
reg [31:0] post_soft_reset_delay_cnt;
wire post_soft_reset_delay_active = (i2c_config_index == 8'd2);
wire post_soft_reset_delay_done = !post_soft_reset_delay_active ||
                                  (post_soft_reset_delay_cnt >= POST_SOFT_RESET_DELAY_CYCLES);
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        post_soft_reset_delay_cnt <= 32'd0;
    else if (!post_soft_reset_delay_active)
        post_soft_reset_delay_cnt <= 32'd0;
    else if (!post_soft_reset_delay_done)
        post_soft_reset_delay_cnt <= post_soft_reset_delay_cnt + 1'b1;
end


 

reg [15:0]  clk_cnt;     
 









reg i2c_ctrl_clk;        
reg i2c_transfer_en;     
reg i2c_capture_en;      
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        clk_cnt <= 0;
        i2c_ctrl_clk <= 0;
        i2c_transfer_en <= 0;
        i2c_capture_en <= 0;
        end
    else if(delay_done)
        begin
        if(clk_cnt < (CLK_FREQ/I2C_FREQ) - 1'b1)
            clk_cnt <= clk_cnt + 1'd1;
        else
            clk_cnt <= 0;
         
        i2c_ctrl_clk <= ((clk_cnt >= (CLK_FREQ/I2C_FREQ)/4 + 1'b1) &&
                        (clk_cnt < (3*CLK_FREQ/I2C_FREQ)/4 + 1'b1)) ? 1'b1 : 1'b0;
         
        i2c_transfer_en <= (clk_cnt == 16'd0) ? 1'b1 : 1'b0;
         
        i2c_capture_en <= (clk_cnt == (2*CLK_FREQ/I2C_FREQ)/4 - 1'b1) ? 1'b1 : 1'b0;
        end
    else
        begin
        clk_cnt <= 0;
        i2c_ctrl_clk <= 0;
        i2c_transfer_en <= 0;
        i2c_capture_en <= 0;
        end
end

 

localparam  I2C_IDLE        =   4'd0;
 
localparam  I2C_WR_START    =   4'd1;
localparam  I2C_WR_IDADDR   =   4'd2;
localparam  I2C_WR_ACK1     =   4'd3;
localparam  I2C_WR_REGADDR1 =   4'd4;
localparam  I2C_WR_ACK2     =   4'd5;
localparam  I2C_WR_REGADDR2 =   4'd6;
localparam  I2C_WR_ACK3     =   4'd7;
localparam  I2C_WR_REGDATA  =   4'd8;
localparam  I2C_WR_ACK4     =   4'd9;
localparam  I2C_WR_STOP     =   4'd10;


 

reg	[3:0]	current_state, next_state;  
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        current_state <= I2C_IDLE;
    else if(i2c_transfer_en)
        current_state <= next_state;
end

                                
 
wire    i2c_transfer_end = (current_state == I2C_WR_STOP) ? 1'b1 : 1'b0;
reg     i2c_ack;     
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        i2c_config_index <= 0;
    else if(i2c_transfer_en)
        begin
		 
		if(i2c_transfer_end)	 

            begin
            if(i2c_config_index < i2c_config_size)  
                i2c_config_index <= i2c_config_index + 1'b1;
 
            else
                i2c_config_index <= i2c_config_size;
            end
        else
            i2c_config_index <= i2c_config_index;
        end
    else
        i2c_config_index <= i2c_config_index;
end
assign  i2c_config_done = (i2c_config_index == i2c_config_size) ? 1'b1 : 1'b0;


 

reg [3:0]   i2c_stream_cnt;  
always@(*)
begin
    next_state = I2C_IDLE;   
    case(current_state)
    I2C_IDLE:        
        begin
        if(delay_done == 1'b1 && post_soft_reset_delay_done)   
            begin
            if(i2c_transfer_en)
                begin                
                if(i2c_config_index < i2c_config_size)
                    next_state = I2C_WR_START;   
                else 
                    next_state = I2C_IDLE;       
					 end
            else
                next_state = next_state;
            end
        else
                next_state = I2C_IDLE;       
        end
     
    I2C_WR_START:   
        if(i2c_transfer_en) next_state = I2C_WR_IDADDR;
        else                next_state = I2C_WR_START;
    I2C_WR_IDADDR:  
        if(i2c_transfer_en == 1'b1 && i2c_stream_cnt == 4'd8)   
                            next_state = I2C_WR_ACK1;
        else                next_state = I2C_WR_IDADDR;
    I2C_WR_ACK1:    
        if(i2c_transfer_en) next_state = I2C_WR_REGADDR1;
        else                next_state = I2C_WR_ACK1;        
    I2C_WR_REGADDR1: 
        if(i2c_transfer_en == 1'b1 && i2c_stream_cnt == 4'd8)   
                            next_state = I2C_WR_ACK2;
        else                next_state = I2C_WR_REGADDR1;
    I2C_WR_ACK2:    
        if(i2c_transfer_en) next_state = I2C_WR_REGADDR2;
        else                next_state = I2C_WR_ACK2;
    I2C_WR_REGADDR2: 
        if(i2c_transfer_en == 1'b1 && i2c_stream_cnt == 4'd8)   
                            next_state = I2C_WR_ACK3;
        else                next_state = I2C_WR_REGADDR2;        
    I2C_WR_ACK3:    
        if(i2c_transfer_en) next_state = I2C_WR_REGDATA;
        else                next_state = I2C_WR_ACK3;        
    I2C_WR_REGDATA:    
        if(i2c_transfer_en == 1'b1 && i2c_stream_cnt == 4'd8)   
                            next_state = I2C_WR_ACK4;
        else                next_state = I2C_WR_REGDATA;
    I2C_WR_ACK4:    
        if(i2c_transfer_en) next_state = I2C_WR_STOP;
        else                next_state = I2C_WR_ACK4;

    I2C_WR_STOP:    
        if(i2c_transfer_en) next_state = I2C_IDLE;
        else                next_state = I2C_WR_STOP;

    default:;    
    endcase
end


 


reg i2c_sdat_out;        

reg [7:0]   i2c_wdata;   
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        i2c_sdat_out <= 1'b1;
        i2c_stream_cnt <= 0;
        i2c_wdata <= 0;
        end
    else if(i2c_transfer_en)
        begin
        case(next_state)
        I2C_IDLE:   
            begin
            i2c_sdat_out <= 1'b1;        
            i2c_stream_cnt <= 0;
            i2c_wdata <= 0;
            end
         
        I2C_WR_START:   
            begin
            i2c_sdat_out <= 1'b0;
            i2c_stream_cnt <= 0;
            i2c_wdata <= i2c_config_data[31:24];     
            end
        I2C_WR_IDADDR:  
            begin
            i2c_stream_cnt <= i2c_stream_cnt + 1'b1;
            i2c_sdat_out <= i2c_wdata[3'd7 - i2c_stream_cnt];
            end
        I2C_WR_ACK1:    
            begin
            i2c_stream_cnt <= 0;
            i2c_wdata <= i2c_config_data[23:16];         
            end            
        I2C_WR_REGADDR1: 
            begin
            i2c_stream_cnt <= i2c_stream_cnt + 1'b1;
            i2c_sdat_out <= i2c_wdata[3'd7 - i2c_stream_cnt];
            end
        I2C_WR_ACK2:    
            begin
            i2c_stream_cnt <= 0;
            i2c_wdata <= i2c_config_data[15:8];         
            end
        I2C_WR_REGADDR2: 
            begin
            i2c_stream_cnt <= i2c_stream_cnt + 1'b1;
            i2c_sdat_out <= i2c_wdata[3'd7 - i2c_stream_cnt];
            end         
        I2C_WR_ACK3:    
            begin
            i2c_stream_cnt <= 0;
            i2c_wdata <= i2c_config_data[7:0];      
            end            
        I2C_WR_REGDATA:    
            begin
            i2c_stream_cnt <= i2c_stream_cnt + 1'b1;
            i2c_sdat_out <= i2c_wdata[3'd7 - i2c_stream_cnt];
            end
        I2C_WR_ACK4:    
            i2c_stream_cnt <= 0;

        I2C_WR_STOP:    
            i2c_sdat_out <= 1'b0;

        endcase
        end
    else
        begin
        i2c_stream_cnt <= i2c_stream_cnt;
        i2c_sdat_out <= i2c_sdat_out;
        i2c_wdata <= i2c_wdata;
        end
end




 

reg i2c_ack1, i2c_ack2, i2c_ack3, i2c_ack4;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
		{i2c_ack1, i2c_ack2, i2c_ack3, i2c_ack4} <= 4'b1111;
        i2c_ack <= 1'b1;
        end
    else if(i2c_capture_en)
        begin
        case(next_state)
        I2C_IDLE:
        begin
        {i2c_ack1, i2c_ack2, i2c_ack3, i2c_ack4} <= 4'b1111;
        i2c_ack <= 1'b1;
        end
         
        I2C_WR_ACK1:    i2c_ack1 <= i2c_sdat_IN;
        I2C_WR_ACK2:    i2c_ack2 <= i2c_sdat_IN;
        I2C_WR_ACK3:    i2c_ack3 <= i2c_sdat_IN;
        I2C_WR_ACK4:    i2c_ack4 <= i2c_sdat_IN;
        I2C_WR_STOP:    i2c_ack <= (i2c_ack1 | i2c_ack2 | i2c_ack3); 

        default:;
        endcase
        end
    else
        begin
        {i2c_ack1, i2c_ack2, i2c_ack3, i2c_ack4} <= {i2c_ack1, i2c_ack2, i2c_ack3, i2c_ack4};
        i2c_ack <= i2c_ack;
        end
end 

 


always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
		begin
		i2c_nack_seen <= 1'b0;
		i2c_first_nack_index <= 8'd0;
		i2c_nack_count <= 8'd0;
		end
	else if (i2c_capture_en && i2c_sdat_IN &&
	        ((next_state == I2C_WR_ACK1) || (next_state == I2C_WR_ACK2) ||
	         (next_state == I2C_WR_ACK3) || (next_state == I2C_WR_ACK4))) begin
		if (!i2c_nack_seen)
			i2c_first_nack_index <= i2c_config_index;
		i2c_nack_seen <= 1'b1;
		if (i2c_nack_count != 8'hff)
			i2c_nack_count <= i2c_nack_count + 1'b1;
	end
end

 
wire    bir_en =(   current_state == I2C_WR_ACK1 || current_state == I2C_WR_ACK2 || 
	            current_state == I2C_WR_ACK3 || current_state == I2C_WR_ACK4) ? 1'b1 : 1'b0;
assign  i2c_sclk = (current_state >= I2C_WR_IDADDR && current_state <= I2C_WR_ACK4) ? 
                    i2c_ctrl_clk : 1'b1;
 
assign i2c_sdat_OUT = i2c_sdat_out;
assign i2c_sdat_OE = ~bir_en;


endmodule
