`timescale 1ns/1ps

module jpeg_q50_header_rom (
    input wire clk,
    input  wire [9:0]  index_i,
    input  wire [11:0] width_i,
    input  wire [11:0] height_i,
    output reg  [7:0]  byte_o
);
    (* syn_ramstyle="block_ram" *) reg [7:0] rom [0:622];
    reg [7:0] rom_byte;reg [9:0] index_q;
    always @(posedge clk)begin rom_byte<=rom[index_i];index_q<=index_i;end
    initial $readmemh("rtl_custom/jpeg/jpeg_q50_header.hex", rom);

    always @(*) begin
        case (index_q)
            10'd163: byte_o = {4'd0, height_i[11:8]};
            10'd164: byte_o = height_i[7:0];
            10'd165: byte_o = {4'd0, width_i[11:8]};
            10'd166: byte_o = width_i[7:0];
            default: byte_o = rom_byte;
        endcase
    end
endmodule
