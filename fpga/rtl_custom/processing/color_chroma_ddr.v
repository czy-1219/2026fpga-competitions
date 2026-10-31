`ifndef COLOR_CHROMA_DDR_V
`define COLOR_CHROMA_DDR_V
`timescale 1ns/1ps
 




module color_chroma_ddr #(
    parameter [31:0] GRID_BASE=32'h03400000,
    parameter [31:0] SMOOTH_BASE=32'h03500000
) (
    input wire clk_i,rst_n_i,start_i,
    input wire [15:0] width_i,height_i,
    input wire [31:0] input_base_i,output_base_i,
    output reg busy_o,done_o,error_o,
    output reg [23:0] pixels_done_o,
    output wire arvalid_o,input wire arready_i,output wire [31:0] araddr_o,
    input wire rvalid_i,rlast_i,input wire [1:0] rresp_i,
    input wire [127:0] rdata_i,output wire rready_o,
    output wire awvalid_o,input wire awready_i,output wire [31:0] awaddr_o,
    output wire wvalid_o,input wire wready_i,output wire [127:0] wdata_o,
    output wire [15:0] wstrb_o,output wire wlast_o,
    input wire bvalid_i,input wire [1:0] bresp_i,output wire bready_o
);
    localparam IDLE=0,G_INIT=1,G_READ=2,G_GOT=3,G_NEXT=4,G_ACC_INIT=5,
      G_FETCH=6,G_ACC=7,D_SETUP=8,D_RUN=9,D_SAVE=10,G_STORE=11,
      G_ADVANCE=12,F_CENTER=13,F_GOT_CENTER=14,F_READ=15,F_ACC=16,
      F_NEXT=17,F_STORE=18,F_ADVANCE=19,O_CORNERS=20,O_GOT_CORNER=21,
      O_READ=22,O_GOT=23,O_H=24,O_V=25,O_DELTA=26,O_RGB=27,
      O_GAMUT=28,O_PACK=29,O_WRITE=30,O_ADVANCE=31,M_WAIT=32;
    reg [5:0] state,return_state;
    reg [15:0] width,height;
    reg [8:0] gw,gh,bx,by;
    reg [2:0] ix,iy;
    reg [4:0] nx,ny;
    reg [31:0] input_base,output_base;
    (* syn_ramstyle = "block_ram" *) reg [25:0] block_mem[0:63];
    reg [25:0] block_q;
    reg [5:0] block_index;
    reg [25:0] sample,center,corners[0:3];
    reg [7:0] max_y;
    reg [17:0] sums[0:5];
    reg [8:0] count,small_count;
    reg [8:0] averages[0:5];
    reg filter_phase;
    reg [2:0] channel;
    reg [17:0] dividend,quotient;
    reg [18:0] remainder;
    reg [8:0] divisor;
    reg [4:0] div_bit;
    wire [18:0] trial_remainder={remainder[17:0],dividend[17]};
    wire quotient_bit=trial_remainder >= {10'd0,divisor};
    reg [1:0] corner_index;
    reg [8:0] horizontal[0:5],background[0:2];
    reg [15:0] source_pixel,result_pixel;
    reg signed [10:0] du,dv,dr,dg,db;
    reg [2:0] attenuate_count;
    integer k;

    wire [7:0] red={source_pixel[15:11],source_pixel[15:13]};
    wire [7:0] green={source_pixel[10:5],source_pixel[10:9]};
    wire [7:0] blue={source_pixel[4:0],source_pixel[4:2]};
    wire [9:0] luma_sum={2'd0,red}+{1'd0,green,1'b0}+{2'd0,blue}+10'd2;
    wire [7:0] luma=luma_sum[9:2];
    wire [8:0] chroma_u=9'd256+{1'b0,blue}-{1'b0,luma};
    wire [8:0] chroma_v=9'd256+{1'b0,red}-{1'b0,luma};
    wire [25:0] pixel_yuv={chroma_v,chroma_u,luma};
    function [9:0] distance;
        input [8:0] a,b;
        begin distance=a>=b ? a-b : b-a;end
    endfunction
    function signed [10:0] bounded_delta;
        input [8:0] a,b;
        reg signed [10:0] d;
        begin d=$signed({2'b0,a})-$signed({2'b0,b});
            bounded_delta=d>16 ? 11'sd16 : d< -16 ? -11'sd16 : d;
        end
    endfunction
    function [8:0] lerp;
        input [8:0] a,b;
        input [2:0] f;
        reg signed [13:0] d,t;
        begin
            d=$signed({5'd0,b})-$signed({5'd0,a});
            t=$signed({2'd0,a,3'b000})+14'sd4;
            if(f[0])t=t+d;
            if(f[1])t=t+(d<<<1);
            if(f[2])t=t+(d<<<2);
            lerp=t[11:3];
        end
    endfunction
    function signed [10:0] halve;
        input signed [10:0] d;
        begin halve=d<0 ? -((-d)>>>1) : d>>>1;end
    endfunction
    function [4:0] nearest5;
        input [7:0] c;
        reg [15:0] p,q;
        begin p=({8'd0,c}<<5)-{8'd0,c}+16'd127;
            q=p+16'd1+(p>>8);nearest5=q[12:8];end
    endfunction
    function [5:0] nearest6;
        input [7:0] c;
        reg [15:0] p,q;
        begin p=({8'd0,c}<<6)-{8'd0,c}+16'd127;
            q=p+16'd1+(p>>8);nearest6=q[13:8];end
    endfunction
    wire signed [11:0] corrected_r=$signed({4'd0,red})+dr;
    wire signed [11:0] corrected_g=$signed({4'd0,green})+dg;
    wire signed [11:0] corrected_b=$signed({4'd0,blue})+db;
    wire out_of_gamut=corrected_r<0 || corrected_r>255 || corrected_g<0 || corrected_g>255 || corrected_b<0 || corrected_b>255;
    wire background_pixel=luma>=128 && distance({1'b0,luma},background[0])<=24 &&
        (distance(chroma_u,9'd256)+distance(chroma_v,9'd256))<=64;
    wire support=distance({1'b0,sample[7:0]},{1'b0,center[7:0]})<=24 &&
        (distance(sample[16:8],center[16:8])+distance(sample[25:17],center[25:17]))<=32;
    wire local_support=nx>=6 && nx<=10 && ny>=6 && ny<=10;
    wire bright_support=({1'b0,block_q[7:0]}+9'd24)>={1'b0,max_y};
    wire [11:0] px={bx,3'b000}+{9'd0,ix};
    wire [11:0] py={by,3'b000}+{9'd0,iy};
    wire [15:0] sample_x={4'd0,px}>=width ? width-1'b1 : {4'd0,px};
    wire [15:0] sample_y={4'd0,py}>=height ? height-1'b1 : {4'd0,py};
     

    wire [31:0] pixel_offset=((sample_y*width)+{16'd0,sample_x})<<1;
    wire signed [10:0] fx=$signed({2'b0,bx})+$signed({6'd0,nx})-11'sd8;
    wire signed [10:0] fy=$signed({2'b0,by})+$signed({6'd0,ny})-11'sd8;
    wire [8:0] filter_x=fx<0 ? 9'd0 : fx>=$signed({2'b0,gw}) ? gw-1'b1 : fx[8:0];
    wire [8:0] filter_y=fy<0 ? 9'd0 : fy>=$signed({2'b0,gh}) ? gh-1'b1 : fy[8:0];
    wire [8:0] corner_x=corner_index[0] && bx+1<gw ? bx+1'b1 : bx;
    wire [8:0] corner_y=corner_index[1] && by+1<gh ? by+1'b1 : by;
    wire [8:0] grid_x=state==F_READ ? filter_x : state==O_CORNERS ? corner_x : bx;
    wire [8:0] grid_y=state==F_READ ? filter_y : state==O_CORNERS ? corner_y : by;
    wire [31:0] grid_offset=((grid_y*gw)+{23'd0,grid_x})<<4;
    wire [10:0] mixed_y=({2'd0,averages[0]}<<1)+{2'd0,averages[0]}+{2'd0,averages[3]}+11'd2;
    wire [10:0] mixed_u=({2'd0,averages[1]}<<1)+{2'd0,averages[1]}+{2'd0,averages[4]}+11'd2;
    wire [10:0] mixed_v=({2'd0,averages[2]}<<1)+{2'd0,averages[2]}+{2'd0,averages[5]}+11'd2;

     

    reg request,request_write;
    reg [31:0] request_address;
    reg [127:0] request_data;
    reg [15:0] request_strobe;
    reg response_valid,response_error;
    reg [127:0] response_data;
    localparam B_IDLE=0,B_AR=1,B_R=2,B_AW=3,B_W=4,B_B=5;
    reg [2:0] bus_state;
    reg [31:0] bus_address,cache_address;
    reg [127:0] bus_data,cache_data;
    reg [15:0] bus_strobe;
    reg cache_valid;
    assign arvalid_o=bus_state==B_AR;
    assign araddr_o=bus_address;
    assign rready_o=bus_state==B_R;
    assign awvalid_o=bus_state==B_AW;
    assign awaddr_o=bus_address;
    assign wvalid_o=bus_state==B_W;
    assign wdata_o=bus_data;
    assign wstrb_o=bus_strobe;
    assign wlast_o=1'b1;
    assign bready_o=bus_state==B_B;
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)begin
            bus_state<=B_IDLE;response_valid<=0;response_error<=0;response_data<=0;
            bus_address<=0;bus_data<=0;bus_strobe<=0;
            cache_address<=0;cache_data<=0;cache_valid<=0;
        end else begin
            response_valid<=0;response_error<=0;
            if(start_i && !busy_o)cache_valid<=0;
            case(bus_state)
                B_IDLE:if(request)begin
                    bus_address<=request_address & 32'hfffffff0;
                    bus_data<=request_data;bus_strobe<=request_strobe;
                    if(request_write)begin cache_valid<=0;bus_state<=B_AW;end
                    else if(cache_valid && cache_address==(request_address & 32'hfffffff0))begin
                        response_data<=cache_data;response_valid<=1;
                    end else bus_state<=B_AR;
                end
                B_AR:if(arready_i)bus_state<=B_R;
                B_R:if(rvalid_i)begin
                    response_valid<=1;response_data<=rdata_i;
                    response_error<=rresp_i!=0 || !rlast_i;
                    cache_valid<=rresp_i==0 && rlast_i;cache_address<=bus_address;cache_data<=rdata_i;
                    bus_state<=B_IDLE;
                end
                B_AW:if(awready_i)bus_state<=B_W;
                B_W:if(wready_i)bus_state<=B_B;
                B_B:if(bvalid_i)begin response_valid<=1;response_error<=bresp_i!=0;bus_state<=B_IDLE;end
                default:bus_state<=B_IDLE;
            endcase
        end
    end
    task read_word;
        input [31:0] address;
        input [5:0] next_state;
        begin request<=1;request_write<=0;request_address<=address;return_state<=next_state;state<=M_WAIT;end
    endtask
    task write_word;
        input [31:0] address;
        input [127:0] data;
        input [15:0] strobe;
        input [5:0] next_state;
        begin request<=1;request_write<=1;request_address<=address;request_data<=data;
            request_strobe<=strobe;return_state<=next_state;state<=M_WAIT;end
    endtask
     
    always @(posedge clk_i)begin
        if(state==G_NEXT)block_mem[block_index]<=pixel_yuv;
        block_q<=block_mem[block_index];
        if(state==M_WAIT && response_valid && return_state==F_ACC)sample<=response_data[25:0];
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i)begin
            state<=IDLE;return_state<=IDLE;busy_o<=0;done_o<=0;error_o<=0;pixels_done_o<=0;
            request<=0;request_write<=0;request_address<=0;request_data<=0;request_strobe<=0;
            width<=0;height<=0;gw<=0;gh<=0;bx<=0;by<=0;ix<=0;iy<=0;nx<=0;ny<=0;
            input_base<=0;output_base<=0;block_index<=0;max_y<=0;center<=0;
            count<=0;small_count<=0;filter_phase<=0;channel<=0;
            dividend<=0;quotient<=0;remainder<=0;divisor<=1;div_bit<=0;corner_index<=0;
            source_pixel<=0;result_pixel<=0;du<=0;dv<=0;dr<=0;dg<=0;db<=0;attenuate_count<=0;
            for(k=0;k<6;k=k+1)begin sums[k]<=0;averages[k]<=0;horizontal[k]<=0;end
            for(k=0;k<3;k=k+1)background[k]<=0;
            for(k=0;k<4;k=k+1)corners[k]<=0;
        end else begin
            request<=0;
            case(state)
                IDLE:if(start_i)begin
                    done_o<=0;error_o<=0;pixels_done_o<=0;
                    if(width_i==0 || height_i==0 || width_i>1920 || height_i>1080)begin done_o<=1;error_o<=1;end
                    else begin
                        width<=width_i;height<=height_i;gw<=(width_i+7)>>3;gh<=(height_i+7)>>3;
                        input_base<=input_base_i;output_base<=output_base_i;
                        bx<=0;by<=0;busy_o<=1;state<=G_INIT;
                    end
                end
                G_INIT:begin ix<=0;iy<=0;block_index<=0;max_y<=0;state<=G_READ;end
                G_READ:read_word(input_base+pixel_offset,G_GOT);
                G_GOT:begin source_pixel<=response_data[pixel_offset[3:0]*8 +: 16];state<=G_NEXT;end
                G_NEXT:begin
                    if(luma>max_y)max_y<=luma;
                    if(block_index==63)state<=G_ACC_INIT;
                    else begin block_index<=block_index+1'b1;ix<=ix+1'b1;if(ix==7)iy<=iy+1'b1;state<=G_READ;end
                end
                G_ACC_INIT:begin
                    block_index<=0;count<=0;filter_phase<=0;
                    for(k=0;k<3;k=k+1)sums[k]<=0;
                    state<=G_FETCH;
                end
                G_FETCH:state<=G_ACC;
                G_ACC:begin
                    if(bright_support)begin
                        sums[0]<=sums[0]+{10'd0,block_q[7:0]};
                        sums[1]<=sums[1]+{9'd0,block_q[16:8]};
                        sums[2]<=sums[2]+{9'd0,block_q[25:17]};count<=count+1'b1;
                    end
                    if(block_index==63)begin channel<=0;state<=D_SETUP;end
                    else begin block_index<=block_index+1'b1;state<=G_FETCH;end
                end
                D_SETUP:begin
                    dividend<=sums[channel]+((channel<3 ? count : small_count)>>1);
                    divisor<=channel<3 ? count : small_count;
                    quotient<=0;remainder<=0;div_bit<=17;state<=D_RUN;
                end
                D_RUN:begin
                    remainder<=quotient_bit ? trial_remainder-{10'd0,divisor} : trial_remainder;
                    dividend<={dividend[16:0],1'b0};quotient<={quotient[16:0],quotient_bit};
                    if(div_bit==0)state<=D_SAVE;else div_bit<=div_bit-1'b1;
                end
                D_SAVE:begin
                    averages[channel]<=quotient[8:0];
                    if(channel==(filter_phase ? 5 : 2))state<=filter_phase ? F_STORE : G_STORE;
                    else begin channel<=channel+1'b1;state<=D_SETUP;end
                end
                G_STORE:write_word(GRID_BASE+grid_offset,{102'd0,averages[2],averages[1],averages[0][7:0]},16'hffff,G_ADVANCE);
                G_ADVANCE:begin
                    if(bx+1<gw)begin bx<=bx+1'b1;state<=G_INIT;end
                    else if(by+1<gh)begin bx<=0;by<=by+1'b1;state<=G_INIT;end
                    else begin bx<=0;by<=0;state<=F_CENTER;end
                end
                F_CENTER:read_word(GRID_BASE+grid_offset,F_GOT_CENTER);
                F_GOT_CENTER:begin
                    center<=response_data[25:0];count<=0;small_count<=0;nx<=0;ny<=0;filter_phase<=1;
                    for(k=0;k<6;k=k+1)sums[k]<=0;
                    state<=F_READ;
                end
                F_READ:read_word(GRID_BASE+grid_offset,F_ACC);
                F_ACC:begin
                    if(support)begin
                        sums[0]<=sums[0]+sample[7:0];sums[1]<=sums[1]+sample[16:8];sums[2]<=sums[2]+sample[25:17];count<=count+1'b1;
                        if(local_support)begin
                            sums[3]<=sums[3]+sample[7:0];sums[4]<=sums[4]+sample[16:8];sums[5]<=sums[5]+sample[25:17];small_count<=small_count+1'b1;
                        end
                    end
                    state<=F_NEXT;
                end
                F_NEXT:begin
                    if(nx==16 && ny==16)begin channel<=0;state<=D_SETUP;end
                    else begin nx<=nx==16 ? 0 : nx+1'b1;if(nx==16)ny<=ny+1'b1;state<=F_READ;end
                end
                F_STORE:write_word(SMOOTH_BASE+grid_offset,{102'd0,mixed_v[10:2],mixed_u[10:2],mixed_y[9:2]},16'hffff,F_ADVANCE);
                F_ADVANCE:begin
                    if(bx+1<gw)begin bx<=bx+1'b1;state<=F_CENTER;end
                    else if(by+1<gh)begin bx<=0;by<=by+1'b1;state<=F_CENTER;end
                    else begin bx<=0;by<=0;corner_index<=0;state<=O_CORNERS;end
                end
                O_CORNERS:read_word(SMOOTH_BASE+grid_offset,O_GOT_CORNER);
                O_GOT_CORNER:begin
                    corners[corner_index]<=response_data[25:0];
                    if(corner_index==3)begin ix<=0;iy<=0;state<=O_READ;end
                    else begin corner_index<=corner_index+1'b1;state<=O_CORNERS;end
                end
                O_READ:read_word(input_base+pixel_offset,O_GOT);
                O_GOT:begin source_pixel<=response_data[pixel_offset[3:0]*8 +: 16];state<=O_H;end
                O_H:begin
                    horizontal[0]<=lerp({1'b0,corners[0][7:0]},{1'b0,corners[1][7:0]},ix);
                    horizontal[1]<=lerp(corners[0][16:8],corners[1][16:8],ix);
                    horizontal[2]<=lerp(corners[0][25:17],corners[1][25:17],ix);
                    horizontal[3]<=lerp({1'b0,corners[2][7:0]},{1'b0,corners[3][7:0]},ix);
                    horizontal[4]<=lerp(corners[2][16:8],corners[3][16:8],ix);
                    horizontal[5]<=lerp(corners[2][25:17],corners[3][25:17],ix);state<=O_V;
                end
                O_V:begin
                    background[0]<=lerp(horizontal[0],horizontal[3],iy);
                    background[1]<=lerp(horizontal[1],horizontal[4],iy);
                    background[2]<=lerp(horizontal[2],horizontal[5],iy);state<=O_DELTA;
                end
                O_DELTA:begin
                    du<=background_pixel ? bounded_delta(background[1],chroma_u) : 11'sd0;
                    dv<=background_pixel ? bounded_delta(background[2],chroma_v) : 11'sd0;state<=O_RGB;
                end
                O_RGB:begin dr<=dv;db<=du;dg<=-((du+dv)>>>1);attenuate_count<=0;state<=O_GAMUT;end
                O_GAMUT:begin
                    if(out_of_gamut && attenuate_count<5)begin dr<=halve(dr);dg<=halve(dg);db<=halve(db);attenuate_count<=attenuate_count+1'b1;end
                    else state<=O_PACK;
                end
                O_PACK:begin result_pixel<={nearest5(corrected_r[7:0]),nearest6(corrected_g[7:0]),nearest5(corrected_b[7:0])};state<=O_WRITE;end
                O_WRITE:write_word(output_base+pixel_offset,{112'd0,result_pixel}<<(pixel_offset[3:0]*8),16'h0003<<pixel_offset[3:0],O_ADVANCE);
                O_ADVANCE:begin
                    pixels_done_o<=pixels_done_o+1'b1;
                    if(ix<7 && px+1<width)begin ix<=ix+1'b1;state<=O_READ;end
                    else if(iy<7 && py+1<height)begin ix<=0;iy<=iy+1'b1;state<=O_READ;end
                    else if(bx+1<gw)begin bx<=bx+1'b1;corner_index<=0;state<=O_CORNERS;end
                    else if(by+1<gh)begin bx<=0;by<=by+1'b1;corner_index<=0;state<=O_CORNERS;end
                    else begin busy_o<=0;done_o<=1;state<=IDLE;end
                end
                M_WAIT:if(response_valid)begin
                    if(response_error)begin error_o<=1;done_o<=1;busy_o<=0;state<=IDLE;end
                    else state<=return_state;
                end
                default:begin error_o<=1;done_o<=1;busy_o<=0;state<=IDLE;end
            endcase
        end
    end
endmodule
`endif
