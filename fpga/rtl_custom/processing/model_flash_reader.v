`timescale 1ns/1ps
 

module model_flash_reader (
    input wire clk_i, rst_n_i,
    input wire write_i,
    input wire [6:0] address_i, read_address_i,
    input wire [7:0] data_i,
    input wire flash_data_i,
    input wire byte_ready_i,
    output wire byte_valid_o,
    output wire [7:0] byte_o,
    output wire [7:0] read_data_o,
    output wire active_o, flash_clock_o, flash_select_n_o, flash_data_o
);
    localparam IDLE=0, HEADER=1, RECEIVE=2, HOLD=3, RELEASE=4;
    reg [2:0] state, next_state;
    reg [6:0] release_count;
    reg [23:0] address;
    reg [31:0] transmit;
    reg [7:0] receive, held;
    reg [5:0] bits;
    reg [2:0] divider;
    reg clock_level, error, direct;
    wire start = write_i && address_i==7'h3d && (data_i==1 || data_i==2);
    wire abort = write_i && address_i==7'h3d && data_i==0;
    wire pop = (write_i && address_i==7'h3e && !direct) || (direct && byte_ready_i);
    wire permitted = address>=24'h140000 && address<24'h800000;
    wire edge_tick = divider==5;
    wire last_header = edge_tick && clock_level && bits==31;
    wire last_data = edge_tick && clock_level && bits==7;

    assign active_o = state!=IDLE;
    assign flash_clock_o = clock_level;
    assign flash_select_n_o = state==IDLE || state==RELEASE;
    assign flash_data_o = state==HEADER ? transmit[31] : 1'b0;
    assign byte_valid_o = direct && state==HOLD;
    assign byte_o = held;
    assign read_data_o = read_address_i==7'h3e ? held :
                         read_address_i==7'h3f ? {4'hb,error,state==HOLD,1'b0,active_o} : 8'd0;

    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) state<=RELEASE;
        else state<=next_state;
    end
    always @(*) begin
        next_state=state;
        case(state)
            IDLE: if(start && permitted) next_state=HEADER;
            HEADER: if(last_header) next_state=RECEIVE;
            RECEIVE: if(last_data) next_state=HOLD;
            HOLD: if(pop) next_state=address==24'h7fffff ? RELEASE : RECEIVE;
            RELEASE: if(release_count==127) next_state=IDLE;
            default: next_state=RELEASE;
        endcase
        if(abort && state!=IDLE && state!=RELEASE) next_state=RELEASE;
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            address<=0;transmit<=0;receive<=0;held<=0;bits<=0;
            divider<=0;clock_level<=0;error<=0;direct<=0;
            release_count<=0;
        end else begin
            if(state!=RELEASE) release_count<=0;
            else if(release_count!=127) release_count<=release_count+1'b1;
            if(state==IDLE && write_i) begin
                case(address_i)
                    7'h3a: address[7:0]<=data_i;
                    7'h3b: address[15:8]<=data_i;
                    7'h3c: address[23:16]<=data_i;
                endcase
            end
            if(start && state==IDLE) begin
                transmit<={8'h03,address};bits<=0;divider<=0;clock_level<=0;
                receive<=0;error<=!permitted;
                direct<=data_i==2;
            end else if(state==HEADER || state==RECEIVE) begin
                if(edge_tick) begin
                    divider<=0;clock_level<=!clock_level;
                    if(!clock_level && state==RECEIVE) receive<={receive[6:0],flash_data_i};
                    if(clock_level) begin
                        transmit<={transmit[30:0],1'b0};bits<=bits+1'b1;
                        if(last_header) begin bits<=0;receive<=0;end
                        if(last_data && state==RECEIVE) begin held<=receive;bits<=0;end
                    end
                end else divider<=divider+1'b1;
            end else if(state==HOLD && pop) begin
                address<=address+1'b1;bits<=0;receive<=0;divider<=0;
            end
            if(abort) begin clock_level<=0;divider<=0;bits<=0;end
        end
    end
endmodule
