`timescale 1ns / 1ps

 

module student_residual_add #(
    parameter RUNTIME_SECOND_ZERO=0,
    parameter signed [31:0] FIRST_MULTIPLIER=1073741824,
    parameter FIRST_SHIFT=0,
    parameter signed [31:0] SECOND_MULTIPLIER=1200769939,
    parameter SECOND_SHIFT=1,
    parameter signed [31:0] OUTPUT_MULTIPLIER=1474791907,
    parameter OUTPUT_SHIFT=19,
    parameter signed [31:0] FIRST_ZERO=-128, SECOND_ZERO=-124, OUTPUT_ZERO=-128
) (
    input wire clk_i, rst_n_i,
    input wire valid_i,
    output wire ready_o,
    input wire signed [7:0] first_i, second_i,
    output wire valid_o,
    input wire ready_i,
    output wire signed [7:0] pixel_o,
    input wire signed [31:0] second_zero_i
);
    localparam [2:0] IDLE=0, MULTIPLY_FIRST=1, SCALE_FIRST=2,
        MULTIPLY_SECOND=3, SCALE_SECOND=4, MULTIPLY_OUTPUT=5, SCALE_OUTPUT=6, RESULT=7;
    reg [2:0] state;
    reg signed [31:0] first_value, second_value, first_scaled, second_scaled;
    reg signed [63:0] product;
    reg signed [7:0] pixel;
    wire signed [63:0] nudged, quotient;
    wire signed [31:0] high;
    wire [5:0] shift;
    wire [31:0] mask, remainder, threshold;
    wire signed [31:0] rounded;
    wire signed [31:0] shifted_high;
    wire signed [32:0] output_value;
    assign ready_o=rst_n_i && state==IDLE;
    assign valid_o=rst_n_i && state==RESULT;
    assign pixel_o=pixel;
    assign nudged=product+(product>=0 ? 64'sd1073741824 : -64'sd1073741823);
    assign quotient=nudged/64'sd2147483648;
    assign high=quotient[31:0];
    assign shift=state==SCALE_FIRST ? FIRST_SHIFT : state==SCALE_SECOND ? SECOND_SHIFT : OUTPUT_SHIFT;
    assign mask=(32'h1<<shift)-1'b1;
    assign remainder=high&mask;
    assign threshold=(mask>>1)+(high<0);
    assign shifted_high=$signed(high)>>>shift;
    assign rounded=shifted_high+(remainder>threshold);
    assign output_value=$signed(rounded)+OUTPUT_ZERO;
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)begin
            state<=IDLE;first_value<=0;second_value<=0;first_scaled<=0;second_scaled<=0;product<=0;pixel<=0;
        end else begin
            case(state)
                IDLE:if(valid_i && ready_o)begin
                    first_value<=($signed(first_i)-FIRST_ZERO)<<<20;
                    second_value<=($signed(second_i)-(RUNTIME_SECOND_ZERO ? second_zero_i : SECOND_ZERO))<<<20;
                    state<=MULTIPLY_FIRST;
                end
                MULTIPLY_FIRST:begin product<=first_value*FIRST_MULTIPLIER;state<=SCALE_FIRST;end
                SCALE_FIRST:begin first_scaled<=rounded;state<=MULTIPLY_SECOND;end
                MULTIPLY_SECOND:begin product<=second_value*SECOND_MULTIPLIER;state<=SCALE_SECOND;end
                SCALE_SECOND:begin second_scaled<=rounded;state<=MULTIPLY_OUTPUT;end
                MULTIPLY_OUTPUT:begin product<=(first_scaled+second_scaled)*OUTPUT_MULTIPLIER;state<=SCALE_OUTPUT;end
                SCALE_OUTPUT:begin
                    if(output_value < -128)pixel<=-8'sd128;
                    else if(output_value > 127)pixel<=8'sd127;
                    else pixel<=output_value[7:0];
                    state<=RESULT;
                end
                RESULT:if(ready_i)state<=IDLE;
                default:state<=IDLE;
            endcase
        end
    end
endmodule
