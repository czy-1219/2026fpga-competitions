`ifndef UPLOAD_NEIGHBORHOOD_RGB565_DEFINED
`define UPLOAD_NEIGHBORHOOD_RGB565_DEFINED
`include "rtl_custom/processing/upload_scan_lookup.v"
`timescale 1ns / 1ps

 


module upload_neighborhood_rgb565 #(parameter EXTERNAL_LEGACY_COLOR = 0)(
    input wire clk,
    input wire rst_n,
    input wire frame_start_i,
    input wire [143:0] window_i,
    input wire window_valid_i,
    output wire window_ready_o,
    input wire color_mode_i,
    input wire smooth_chroma_i,
    input wire scan_color_i,
    output wire [15:0] pixel_o,
    output wire [7:0] luma_o,
    output wire pixel_valid_o,
    input wire pixel_ready_i,
    output wire [15:0] legacy_input_o,
    input wire [15:0] legacy_result_i
);
    localparam [4:0] ST_IDLE=0, ST_LOAD=1, ST_SORT=2, ST_FILTER=3,
        ST_LUMA=4, ST_GATES=5, ST_CORRECT_FIRST=6, ST_CORRECT_SECOND=7,
        ST_BLACK=8, ST_MAX=9, ST_GAIN=10, ST_SCALE=11, ST_PACK=12,
        ST_TEXT=13, ST_LEGACY=14, ST_HOLD=15, ST_MEAN=16, ST_EDGE=17, ST_DELTA=18, ST_MIX=19;
    reg [4:0] state, next_state;
    reg [143:0] window_reg;
    reg color_mode, smooth_chroma, scan_color;
    reg [3:0] load_count, sort_inner, sort_outer;
    reg [7:0] samples [0:8];
    reg [11:0] red_sum, green_sum, blue_sum;
    reg [7:0] left_luma, right_luma, top_luma, bottom_luma;
    reg [15:0] filtered_pixel;
    reg [7:0] luminance, red_excess, correction_part, correction_red;
    reg [8:0] weak_red, bright_red;
    reg [7:0] red_black, green_black, blue_black, maximum;
    reg [16:0] gain;
    reg [24:0] red_product, green_product, blue_product;
    reg [15:0] pixel_reg;
    reg [7:0] luma_reg;
    reg pixel_valid;
    wire [15:0] load_pixel = window_reg[load_count*16 +: 16];
    wire [7:0] load_red={load_pixel[15:11],load_pixel[15:13]};
    wire [7:0] load_green={load_pixel[10:5],load_pixel[10:9]};
    wire [7:0] load_blue={load_pixel[4:0],load_pixel[4:2]};
    wire [15:0] load_weighted=load_red*8'd77+load_green*8'd150+load_blue*8'd29+16'd128;
    wire [2:0] tap_weight=(load_count==4) ? 3'd4 :
        ((load_count==1)||(load_count==3)||(load_count==5)||(load_count==7)) ? 3'd2 : 3'd1;
    wire [15:0] center_pixel=window_reg[79:64];
    wire [7:0] center_red={center_pixel[15:11],center_pixel[15:13]};
    wire [7:0] center_green={center_pixel[10:5],center_pixel[10:9]};
    wire [7:0] center_blue={center_pixel[4:0],center_pixel[4:2]};
    wire [7:0] filtered_red={filtered_pixel[15:11],filtered_pixel[15:13]};
    wire [7:0] filtered_green={filtered_pixel[10:5],filtered_pixel[10:9]};
    wire [7:0] filtered_blue={filtered_pixel[4:0],filtered_pixel[4:2]};
    wire [15:0] filtered_weighted=filtered_red*8'd77+filtered_green*8'd150+filtered_blue*8'd29+16'd128;
    wire [16:0] lookup_gain;
    wire [15:0] legacy_color;
    upload_color_gain_lut u_gain(.level_i(maximum),.value_o(lookup_gain));
    assign legacy_input_o=filtered_pixel;
    generate if(EXTERNAL_LEGACY_COLOR)begin: shared_color
        assign legacy_color=legacy_result_i;
    end else begin: local_color
        upload_color_enhance_rgb565 u_legacy_color(.pixel_i(filtered_pixel),.pixel_o(legacy_color));
    end endgenerate
    assign window_ready_o=(state==ST_IDLE)&&!frame_start_i;
    assign pixel_o=pixel_reg;
    assign luma_o=luma_reg;
    assign pixel_valid_o=pixel_valid;

    reg [7:0] smooth_red, smooth_green, smooth_blue, smooth_luma;
    reg [1:0] quarters;
    reg signed [10:0] delta_red, delta_green, delta_blue;
    reg signed [12:0] mixed_red, mixed_green, mixed_blue;
    wire [15:0] smooth_weighted = smooth_red*8'd77+smooth_green*8'd150+smooth_blue*8'd29+16'd128;
    wire [8:0] edge_horizontal=(right_luma>=left_luma)?right_luma-left_luma:left_luma-right_luma;
    wire [8:0] edge_vertical=(bottom_luma>=top_luma)?bottom_luma-top_luma:top_luma-bottom_luma;
    wire [9:0] edge_total={1'b0,edge_horizontal}+{1'b0,edge_vertical};
    wire [7:0] result_red=(mixed_red<0)?8'd0:(mixed_red>255)?8'd255:mixed_red[7:0];
    wire [7:0] result_green=(mixed_green<0)?8'd0:(mixed_green>255)?8'd255:mixed_green[7:0];
    wire [7:0] result_blue=(mixed_blue<0)?8'd0:(mixed_blue>255)?8'd255:mixed_blue[7:0];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) state<=ST_IDLE;
        else if(frame_start_i) state<=ST_IDLE;
        else state<=next_state;
    end
    always @(*) begin
        next_state=state;
        case(state)
            ST_IDLE: if(window_valid_i&&!frame_start_i) next_state=ST_LOAD;
            ST_LOAD: if(load_count==8) next_state=color_mode?ST_MEAN:ST_SORT;
            ST_SORT: if(sort_inner==8) next_state=ST_TEXT;
            ST_MEAN: next_state=ST_EDGE;
            ST_EDGE: next_state=ST_DELTA;
            ST_DELTA: next_state=ST_MIX;
            ST_MIX: next_state=ST_FILTER;
            ST_FILTER: next_state=scan_color?ST_BLACK:ST_LEGACY;
            ST_LUMA: next_state=ST_GATES;
            ST_GATES: next_state=ST_CORRECT_FIRST;
            ST_CORRECT_FIRST: next_state=ST_CORRECT_SECOND;
            ST_CORRECT_SECOND: next_state=ST_BLACK;
            ST_BLACK: next_state=ST_MAX;
            ST_MAX: next_state=ST_GAIN;
            ST_GAIN: next_state=ST_SCALE;
            ST_SCALE: next_state=ST_PACK;
            ST_PACK,ST_TEXT,ST_LEGACY: next_state=ST_HOLD;
            ST_HOLD: if(pixel_ready_i) next_state=ST_IDLE;
            default: next_state=ST_IDLE;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            window_reg<=0; color_mode<=0; smooth_chroma<=0; scan_color<=0;
            load_count<=0; sort_inner<=0; sort_outer<=8;
            red_sum<=0; green_sum<=0; blue_sum<=0;
            left_luma<=0; right_luma<=0; top_luma<=0; bottom_luma<=0;
            filtered_pixel<=0; luminance<=0; red_excess<=0;
            weak_red<=0; bright_red<=0; correction_part<=0; correction_red<=0;
            red_black<=0; green_black<=0; blue_black<=0; maximum<=0; gain<=0;
            red_product<=0; green_product<=0; blue_product<=0;
            pixel_reg<=0; luma_reg<=0; pixel_valid<=0;
            smooth_red<=0; smooth_green<=0; smooth_blue<=0; smooth_luma<=0; quarters<=0;
            delta_red<=0; delta_green<=0; delta_blue<=0;
            mixed_red<=0; mixed_green<=0; mixed_blue<=0;
        end else if(frame_start_i) begin
            pixel_valid<=0;
        end else begin
            case(state)
                ST_IDLE: if(window_valid_i) begin
                    window_reg<=window_i; color_mode<=color_mode_i;
                    smooth_chroma<=smooth_chroma_i; scan_color<=scan_color_i;
                    load_count<=0; sort_inner<=0; sort_outer<=8;
                    red_sum<=0; green_sum<=0; blue_sum<=0;
                end
                ST_LOAD: begin
                    samples[load_count]<=load_weighted[15:8];
                    red_sum<=red_sum+load_red*tap_weight;
                    green_sum<=green_sum+load_green*tap_weight;
                    blue_sum<=blue_sum+load_blue*tap_weight;
                    if(load_count==1) top_luma<=load_weighted[15:8];
                    if(load_count==3) left_luma<=load_weighted[15:8];
                    if(load_count==5) right_luma<=load_weighted[15:8];
                    if(load_count==7) bottom_luma<=load_weighted[15:8];
                    if(load_count<8) load_count<=load_count+1'b1;
                end
                ST_SORT: begin
                    for(integer j=0;j<8;j=j+1)begin
                        if(j%2==sort_inner[0] && samples[j]>samples[j+1])begin
                            samples[j]<=samples[j+1];samples[j+1]<=samples[j];
                        end
                    end
                    sort_inner<=sort_inner+1'b1;
                end
                ST_TEXT: begin
                    luma_reg<=samples[4];
                    pixel_reg<={samples[4][7:3],samples[4][7:2],samples[4][7:3]};
                    pixel_valid<=1;
                end
                ST_MEAN: begin
                    smooth_red<=(red_sum+12'd8)>>4;
                    smooth_green<=(green_sum+12'd8)>>4;
                    smooth_blue<=(blue_sum+12'd8)>>4;
                end
                ST_EDGE: begin
                    smooth_luma<=smooth_weighted[15:8];
                    quarters<=(!smooth_chroma)?0:(edge_total<=16)?3:(edge_total<=32)?2:(edge_total<=48)?1:0;
                end
                ST_DELTA: begin
                    delta_red<=$signed({3'd0,smooth_red})-$signed({3'd0,center_red})-$signed({3'd0,smooth_luma})+$signed({3'd0,samples[4]});
                    delta_green<=$signed({3'd0,smooth_green})-$signed({3'd0,center_green})-$signed({3'd0,smooth_luma})+$signed({3'd0,samples[4]});
                    delta_blue<=$signed({3'd0,smooth_blue})-$signed({3'd0,center_blue})-$signed({3'd0,smooth_luma})+$signed({3'd0,samples[4]});
                end
                ST_MIX: begin
                    mixed_red<=$signed({5'd0,center_red})+((delta_red*$signed({1'b0,quarters})+13'sd2)>>>2);
                    mixed_green<=$signed({5'd0,center_green})+((delta_green*$signed({1'b0,quarters})+13'sd2)>>>2);
                    mixed_blue<=$signed({5'd0,center_blue})+((delta_blue*$signed({1'b0,quarters})+13'sd2)>>>2);
                end
                ST_FILTER: filtered_pixel<={result_red[7:3],result_green[7:2],result_blue[7:3]};
                ST_LEGACY: begin pixel_reg<=legacy_color; pixel_valid<=1; end
                ST_BLACK: begin
                    red_black<=(filtered_red>8)?filtered_red-8:0;
                    green_black<=(filtered_green>8)?filtered_green-8:0;
                    blue_black<=(filtered_blue>8)?filtered_blue-8:0;
                end
                ST_MAX: maximum<=(red_black>green_black)?((red_black>blue_black)?red_black:blue_black):((green_black>blue_black)?green_black:blue_black);
                ST_GAIN: gain<=(lookup_gain>17'd77824)?17'd77824:lookup_gain;
                ST_SCALE: begin
                    red_product<=red_black*gain+25'd32768;
                    green_product<=green_black*gain+25'd32768;
                    blue_product<=blue_black*gain+25'd32768;
                end
                ST_PACK: begin
                    pixel_reg<={red_product[23:19],green_product[23:18],blue_product[23:19]};
                    pixel_valid<=1;
                end
                ST_HOLD: if(pixel_ready_i) pixel_valid<=0;
                default: begin end
            endcase
        end
    end
endmodule
`endif
