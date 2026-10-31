`timescale 1ns/1ps

 



module spatial_wb_rgb565 #(
    parameter integer WIDTH = 1024,
    parameter integer HEIGHT = 600,
    parameter integer ENABLE = 1
)(
    input  wire [10:0] pixel_x_i,
    input  wire [9:0] pixel_y_i,
    input  wire [15:0] pixel_i,
    output reg  [15:0] pixel_o
);
     

    wire [2:0] cell_x = (pixel_x_i >= WIDTH-1) ? 3'd7 :
                        (pixel_x_i < WIDTH/8) ? 3'd0 :
                        (pixel_x_i < WIDTH*2/8) ? 3'd1 :
                        (pixel_x_i < WIDTH*3/8) ? 3'd2 :
                        (pixel_x_i < WIDTH*4/8) ? 3'd3 :
                        (pixel_x_i < WIDTH*5/8) ? 3'd4 :
                        (pixel_x_i < WIDTH*6/8) ? 3'd5 :
                        (pixel_x_i < WIDTH*7/8) ? 3'd6 : 3'd7;
     
    wire [2:0] cell_y = (pixel_y_i < HEIGHT/6) ? 3'd0 :
                        (pixel_y_i < HEIGHT*2/6) ? 3'd1 :
                        (pixel_y_i < HEIGHT*3/6) ? 3'd2 :
                        (pixel_y_i < HEIGHT*4/6) ? 3'd3 :
                        (pixel_y_i < HEIGHT*5/6) ? 3'd4 : 3'd5;
    wire [5:0] cell_index = cell_y * 8 + cell_x;

    reg [9:0] gain_r;
    reg [9:0] gain_g;
    reg [9:0] gain_b;
    reg [17:0] red_scaled;
    reg [17:0] green_scaled;
    reg [17:0] blue_scaled;
    reg [7:0] red_8;
    reg [7:0] green_8;
    reg [7:0] blue_8;

    always @(*) begin
        gain_r = 10'd256;
        gain_g = 10'd256;
        gain_b = 10'd256;
        case (cell_index)
            6'd0: begin gain_r=205; gain_g=205; gain_b=205; end
            6'd1: begin gain_r=205; gain_g=205; gain_b=205; end
            6'd2: begin gain_r=206; gain_g=205; gain_b=205; end
            6'd3: begin gain_r=209; gain_g=205; gain_b=206; end
            6'd4: begin gain_r=213; gain_g=206; gain_b=210; end
            6'd5: begin gain_r=221; gain_g=210; gain_b=215; end
            6'd6: begin gain_r=234; gain_g=219; gain_b=225; end
            6'd7: begin gain_r=245; gain_g=232; gain_b=237; end
            6'd8: begin gain_r=213; gain_g=211; gain_b=212; end
            6'd9: begin gain_r=212; gain_g=208; gain_b=210; end
            6'd10: begin gain_r=216; gain_g=207; gain_b=211; end
            6'd11: begin gain_r=226; gain_g=209; gain_b=218; end
            6'd12: begin gain_r=240; gain_g=214; gain_b=228; end
            6'd13: begin gain_r=254; gain_g=225; gain_b=240; end
            6'd14: begin gain_r=266; gain_g=240; gain_b=253; end
            6'd15: begin gain_r=277; gain_g=255; gain_b=266; end
            6'd16: begin gain_r=236; gain_g=230; gain_b=233; end
            6'd17: begin gain_r=232; gain_g=218; gain_b=225; end
            6'd18: begin gain_r=239; gain_g=214; gain_b=228; end
            6'd19: begin gain_r=254; gain_g=219; gain_b=239; end
            6'd20: begin gain_r=269; gain_g=227; gain_b=252; end
            6'd21: begin gain_r=281; gain_g=238; gain_b=263; end
            6'd22: begin gain_r=290; gain_g=253; gain_b=274; end
            6'd23: begin gain_r=299; gain_g=270; gain_b=286; end
            6'd24: begin gain_r=258; gain_g=248; gain_b=253; end
            6'd25: begin gain_r=253; gain_g=232; gain_b=244; end
            6'd26: begin gain_r=259; gain_g=225; gain_b=244; end
            6'd27: begin gain_r=272; gain_g=228; gain_b=255; end
            6'd28: begin gain_r=283; gain_g=235; gain_b=264; end
            6'd29: begin gain_r=289; gain_g=242; gain_b=271; end
            6'd30: begin gain_r=297; gain_g=256; gain_b=280; end
            6'd31: begin gain_r=305; gain_g=272; gain_b=292; end
            6'd32: begin gain_r=271; gain_g=262; gain_b=267; end
            6'd33: begin gain_r=267; gain_g=246; gain_b=258; end
            6'd34: begin gain_r=269; gain_g=235; gain_b=255; end
            6'd35: begin gain_r=278; gain_g=234; gain_b=260; end
            6'd36: begin gain_r=285; gain_g=238; gain_b=267; end
            6'd37: begin gain_r=289; gain_g=244; gain_b=271; end
            6'd38: begin gain_r=297; gain_g=259; gain_b=281; end
            6'd39: begin gain_r=308; gain_g=278; gain_b=297; end
            6'd40: begin gain_r=277; gain_g=269; gain_b=274; end
            6'd41: begin gain_r=272; gain_g=253; gain_b=265; end
            6'd42: begin gain_r=273; gain_g=241; gain_b=260; end
            6'd43: begin gain_r=279; gain_g=239; gain_b=262; end
            6'd44: begin gain_r=283; gain_g=240; gain_b=265; end
            6'd45: begin gain_r=284; gain_g=243; gain_b=266; end
            6'd46: begin gain_r=292; gain_g=260; gain_b=279; end
            6'd47: begin gain_r=310; gain_g=289; gain_b=304; end
            default: begin end
        endcase

        red_scaled = {pixel_i[15:11], 3'b000} * gain_r;
        green_scaled = {pixel_i[10:5], 2'b00} * gain_g;
        blue_scaled = {pixel_i[4:0], 3'b000} * gain_b;
        red_8 = (red_scaled[17:8] > 8'd255) ? 8'd255 : red_scaled[17:8];
        green_8 = (green_scaled[17:8] > 8'd255) ? 8'd255 : green_scaled[17:8];
        blue_8 = (blue_scaled[17:8] > 8'd255) ? 8'd255 : blue_scaled[17:8];
        if (ENABLE != 0)
            pixel_o = {red_8[7:3], green_8[7:2], blue_8[7:3]};
        else
            pixel_o = pixel_i;
    end
endmodule
