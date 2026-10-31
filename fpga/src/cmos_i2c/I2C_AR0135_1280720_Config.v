/*-------------------------------------------------------------------------
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo.www.cnblogs.com/crazybingo
(C) COPYRIGHT 2012 CrazyBingo. ALL RIGHTS RESERVED
Filename			:		I2C_AR0144_1280720_Config.v
Author				:		CrazyBingo
Date				:		2019-08-03
Version				:		1.0
Description			:		I2C Configure Data of AR0135.
Modification History	:
Date			By			Version			Change Description
===========================================================================
19/08/03		CrazyBingo	1.0				Original
--------------------------------------------------------------------------*/

`timescale 1ns/1ns
module	I2C_AR0135_1280720_Config    
(
	input		[7:0]	LUT_INDEX,
	output	reg	[31:0]	LUT_DATA,
	output		[7:0]	LUT_SIZE
);
`define PLL_EN
`define AE_EN

assign	LUT_SIZE = 1'b1 + 8'd23 ;

 

always@(*)
begin
	case(LUT_INDEX)
 
	0 :		LUT_DATA	=	{16'h3000, 16'h0554};   

    1 :     LUT_DATA    =   {16'h301A, 16'h00D9};   
    2 :     LUT_DATA    =   {16'h0000, 16'h0000};   
    3 :     LUT_DATA    =   {16'h301A, 16'h10D8};   
    
    4 :     LUT_DATA    =   {16'h302C, 16'h0001};   
    5 :     LUT_DATA    =   {16'h302A, 16'h0008};   
    6 :     LUT_DATA    =   {16'h302E, 16'h0002};   
    7 :     LUT_DATA    =   {16'h3030, 16'h002C};   
    8 :     LUT_DATA    =   {16'h30B0, 16'h04A0};   
    9 :     LUT_DATA    =   {16'h0000, 16'h0000};   
    
    10 :    LUT_DATA    =   {16'h3002, 16'h0078};   
    11 :    LUT_DATA    =   {16'h3004, 16'h0000};   
    12 :    LUT_DATA    =   {16'h3006, 16'h0347};   
    13 :    LUT_DATA    =   {16'h3008, 16'h04FF};   
    14 :    LUT_DATA    =   {16'h300A, 16'h02EB};   
    15 :    LUT_DATA    =   {16'h300C, 16'h0672};   
    
    16 :    LUT_DATA    =   {16'h30A2, 16'h0001};   
    17 :    LUT_DATA    =   {16'h30A6, 16'h0001};   
    18 :    LUT_DATA    =   {16'h3040, 16'h8000};   
    19 :    LUT_DATA    =   {16'h3028, 16'h0010};   


    20 :    LUT_DATA    =   {16'h305E, 16'h0020};    
    21 :    LUT_DATA    =   {16'h3012, 16'd960};    


    22 :    LUT_DATA    =   {16'h3100, 16'h0013};   

    23 :    LUT_DATA    =   {16'h301A, 16'h10DC};   

	default:LUT_DATA	=	{16'h0000, 16'h0000};
	endcase
end

endmodule
