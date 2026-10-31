`timescale 1ns/1ps
 

module axi_single_request (
    input wire clk,rst_n,
    input wire request_i,write_i,input wire [31:0] address_i,
    input wire [127:0] data_i,input wire [15:0] strobe_i,
    output wire ready_o,output reg response_o,error_o,
    output reg [127:0] response_data_o,
    output reg [31:0] araddr_o,awaddr_o,
    output reg arvalid_o,awvalid_o,wvalid_o,
    input wire arready_i,awready_i,wready_i,
    output reg [127:0] wdata_o,output reg [15:0] wstrb_o,
    input wire rvalid_i,bvalid_i,input wire [127:0] rdata_i,
    input wire [1:0] rresp_i,bresp_i,
    output wire rready_o,bready_o
);
    reg busy,writing;
    assign ready_o=!busy && !response_o;
    assign rready_o=busy && !writing && !arvalid_o;
    assign bready_o=busy && writing && !awvalid_o && !wvalid_o;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            busy<=0;writing<=0;response_o<=0;error_o<=0;response_data_o<=0;
            araddr_o<=0;awaddr_o<=0;arvalid_o<=0;awvalid_o<=0;wvalid_o<=0;
            wdata_o<=0;wstrb_o<=0;
        end else begin
            response_o<=0;
            if(request_i && ready_o)begin
                busy<=1;writing<=write_i;error_o<=0;
                araddr_o<=address_i;awaddr_o<=address_i;
                arvalid_o<=!write_i;awvalid_o<=write_i;wvalid_o<=write_i;
                wdata_o<=data_i;wstrb_o<=strobe_i;
            end
            if(arvalid_o && arready_i)arvalid_o<=0;
            if(awvalid_o && awready_i)awvalid_o<=0;
            if(wvalid_o && wready_i)wvalid_o<=0;
            if((rvalid_i && rready_o)||(bvalid_i && bready_o))begin
                busy<=0;response_o<=1;response_data_o<=rdata_i;
                error_o<=writing ? bresp_i!=0 : rresp_i!=0;
            end
        end
    end
endmodule
