/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
`include "rtl_custom/jpeg/encoder/jpeg_encoder.vh"
module quant_tables #(
    parameter N = 2,         
    parameter AW = 6,        
    parameter DW = 13        
)(
    input   logic               clk,
    input   logic[2:0]          qf_select,  
    input   logic [AW-1:0]      ra,
    input   logic               re,
    output  logic [DW-1:0]      rd[N-1:0]
);
 

`ifdef INFER_QUANTIZATION_TABLES_ROM
`include "rtl_custom/jpeg/encoder/jenc/quant_tables.vh"
logic[25:0] qt_mem[7:0][63:0]; /* synthesis syn_ramstyle="Block_RAM" */
generate
    for(genvar i=0; i<2; i++) begin : I
        for(genvar j=0; j<32; j++) begin : J
            always_comb qt_mem[0][32*i + j] = `QT(50, i, j);  
            always_comb qt_mem[1][32*i + j] = `QT(100, i, j);  
            always_comb qt_mem[2][32*i + j] = `QT(10, i, j);  
            always_comb qt_mem[3][32*i + j] = `QT(25, i, j);  

            always_comb qt_mem[4][32*i + j] = `QT(20, i, j);  
            always_comb qt_mem[5][32*i + j] = `QT(30, i, j);  
            always_comb qt_mem[6][32*i + j] = `QT(40, i, j);  
            always_comb qt_mem[7][32*i + j] = `QT(80, i, j);  
        end
    end
endgenerate

always @(posedge clk) if (re) begin
    rd[0] <= qt_mem[qf_select][ra][12:0];
    rd[1] <= qt_mem[qf_select][ra][25:13];
end

`else
`include "rtl_custom/jpeg/encoder/jenc/quant_tables_EBR.vh"

wire VDD, VSS;
VLO INST1( .Z(VSS));
VHI INST2( .Z(VDD));
PDP16K_MODE EBR_inst(
        .DI0    (VSS),
        .DI1    (VSS),
        .DI2    (VSS),
        .DI3    (VSS),
        .DI4    (VSS),
        .DI5    (VSS),
        .DI6    (VSS),
        .DI7    (VSS),
        .DI8    (VSS),
        .DI9    (VSS),
        .DI10   (VSS),
        .DI11   (VSS),
        .DI12   (VSS),
        .DI13   (VSS),
        .DI14   (VSS),
        .DI15   (VSS),
        .DI16   (VSS),
        .DI17   (VSS),
        .DI18   (VSS),
        .DI19   (VSS),
        .DI20   (VSS),
        .DI21   (VSS),
        .DI22   (VSS),
        .DI23   (VSS),
        .DI24   (VSS),
        .DI25   (VSS),
        .DI26   (VSS),
        .DI27   (VSS),
        .DI28   (VSS),
        .DI29   (VSS),
        .DI30   (VSS),
        .DI31   (VSS),
        .DI32   (VSS),
        .DI33   (VSS),
        .DI34   (VSS),
        .DI35   (VSS),
        .ADW0   (VSS),
        .ADW1   (VSS),
        .ADW2   (VSS),
        .ADW3   (VSS),
        .ADW4   (VSS),
        .ADW5   (VSS),
        .ADW6   (VSS),
        .ADW7   (VSS),
        .ADW8   (VSS),
        .ADW9   (VSS),
        .ADW10  (VSS),
        .ADW11  (VSS),
        .ADW12  (VSS),
        .ADW13  (VSS),
        .ADR0   (VDD),
        .ADR1   (VDD),
        .ADR2   (VDD),
        .ADR3   (VDD),
        .ADR4   (VDD),
        .ADR5   (ra[0]),
        .ADR6   (ra[1]),
        .ADR7   (ra[2]),
        .ADR8   (ra[3]),
        .ADR9   (ra[4]),
        .ADR10  (ra[5]),
        .ADR11  (qf_select[0]),
        .ADR12  (qf_select[1]),
        .ADR13  (qf_select[2]),
        .CLKW   (VSS),
        .CLKR   (clk),
        .CEW    (VSS),
        .CER    (re),
        .CSW0   (VSS),
        .CSW1   (VSS),
        .CSW2   (VSS),
        .CSR0   (re),
        .CSR1   (re),
        .CSR2   (re),
        .RST    (VSS),
        .DO0    (rd[0][0]),
        .DO1    (rd[0][1]),
        .DO2    (rd[0][2]),
        .DO3    (rd[0][3]),
        .DO4    (rd[0][4]),
        .DO5    (rd[0][5]),
        .DO6    (rd[0][6]),
        .DO7    (rd[0][7]),
        .DO8    (rd[0][8]),
        .DO9    (rd[0][9]),
        .DO10   (rd[0][10]),
        .DO11   (rd[0][11]),
        .DO12   (rd[0][12]),
        .DO13   ( ),
        .DO14   ( ),
        .DO15   ( ),
        .DO16   ( ),
        .DO17   ( ),
        .DO18   (rd[1][0]),
        .DO19   (rd[1][1]),
        .DO20   (rd[1][2]),
        .DO21   (rd[1][3]),
        .DO22   (rd[1][4]),
        .DO23   (rd[1][5]),
        .DO24   (rd[1][6]),
        .DO25   (rd[1][7]),
        .DO26   (rd[1][8]),
        .DO27   (rd[1][9]),
        .DO28   (rd[1][10]),
        .DO29   (rd[1][11]),
        .DO30   (rd[1][12]),
        .DO31   ( ),
        .DO32   ( ),
        .DO33   ( ),
        .DO34   ( ),
        .DO35   ( ),
        .ONEBITERR ( ),
        .TWOBITERR ( )
    );

defparam EBR_inst.DATA_WIDTH_W = "X36";
defparam EBR_inst.DATA_WIDTH_R = "X36";
defparam EBR_inst.OUTREG = "BYPASSED";
defparam EBR_inst.RESETMODE = "SYNC";
defparam EBR_inst.GSR = "DISABLED";
defparam EBR_inst.ECC = "DISABLED";
defparam EBR_inst.CSDECODE_W = "000";
defparam EBR_inst.CSDECODE_R = "000";
defparam EBR_inst.ASYNC_RST_RELEASE = "SYNC";
 

defparam EBR_inst.INITVAL_00 = QT50_INITVAL_0;  
defparam EBR_inst.INITVAL_01 = QT50_INITVAL_1;
defparam EBR_inst.INITVAL_02 = QT50_INITVAL_2;
defparam EBR_inst.INITVAL_03 = QT50_INITVAL_3;
defparam EBR_inst.INITVAL_04 = QT50_INITVAL_4;
defparam EBR_inst.INITVAL_05 = QT50_INITVAL_5;
defparam EBR_inst.INITVAL_06 = QT50_INITVAL_6;
defparam EBR_inst.INITVAL_07 = QT50_INITVAL_7;
 
defparam EBR_inst.INITVAL_08 = QT100_INITVAL_0;  
defparam EBR_inst.INITVAL_09 = QT100_INITVAL_1;
defparam EBR_inst.INITVAL_0A = QT100_INITVAL_2;
defparam EBR_inst.INITVAL_0B = QT100_INITVAL_3;
defparam EBR_inst.INITVAL_0C = QT100_INITVAL_4;
defparam EBR_inst.INITVAL_0D = QT100_INITVAL_5;
defparam EBR_inst.INITVAL_0E = QT100_INITVAL_6;
defparam EBR_inst.INITVAL_0F = QT100_INITVAL_7;
 
defparam EBR_inst.INITVAL_10 = QT10_INITVAL_0;  
defparam EBR_inst.INITVAL_11 = QT10_INITVAL_1;
defparam EBR_inst.INITVAL_12 = QT10_INITVAL_2;
defparam EBR_inst.INITVAL_13 = QT10_INITVAL_3;
defparam EBR_inst.INITVAL_14 = QT10_INITVAL_4;
defparam EBR_inst.INITVAL_15 = QT10_INITVAL_5;
defparam EBR_inst.INITVAL_16 = QT10_INITVAL_6;
defparam EBR_inst.INITVAL_17 = QT10_INITVAL_7;
 
defparam EBR_inst.INITVAL_18 = QT25_INITVAL_0;  
defparam EBR_inst.INITVAL_19 = QT25_INITVAL_1;
defparam EBR_inst.INITVAL_1A = QT25_INITVAL_2;
defparam EBR_inst.INITVAL_1B = QT25_INITVAL_3;
defparam EBR_inst.INITVAL_1C = QT25_INITVAL_4;
defparam EBR_inst.INITVAL_1D = QT25_INITVAL_5;
defparam EBR_inst.INITVAL_1E = QT25_INITVAL_6;
defparam EBR_inst.INITVAL_1F = QT25_INITVAL_7;
 

defparam EBR_inst.INITVAL_20 = QT20_INITVAL_0;  
defparam EBR_inst.INITVAL_21 = QT20_INITVAL_1;
defparam EBR_inst.INITVAL_22 = QT20_INITVAL_2;
defparam EBR_inst.INITVAL_23 = QT20_INITVAL_3;
defparam EBR_inst.INITVAL_24 = QT20_INITVAL_4;
defparam EBR_inst.INITVAL_25 = QT20_INITVAL_5;
defparam EBR_inst.INITVAL_26 = QT20_INITVAL_6;
defparam EBR_inst.INITVAL_27 = QT20_INITVAL_7;
 
defparam EBR_inst.INITVAL_28 = QT30_INITVAL_0;  
defparam EBR_inst.INITVAL_29 = QT30_INITVAL_1;
defparam EBR_inst.INITVAL_2A = QT30_INITVAL_2;
defparam EBR_inst.INITVAL_2B = QT30_INITVAL_3;
defparam EBR_inst.INITVAL_2C = QT30_INITVAL_4;
defparam EBR_inst.INITVAL_2D = QT30_INITVAL_5;
defparam EBR_inst.INITVAL_2E = QT30_INITVAL_6;
defparam EBR_inst.INITVAL_2F = QT30_INITVAL_7;
 
defparam EBR_inst.INITVAL_30 = QT40_INITVAL_0;  
defparam EBR_inst.INITVAL_31 = QT40_INITVAL_1;
defparam EBR_inst.INITVAL_32 = QT40_INITVAL_2;
defparam EBR_inst.INITVAL_33 = QT40_INITVAL_3;
defparam EBR_inst.INITVAL_34 = QT40_INITVAL_4;
defparam EBR_inst.INITVAL_35 = QT40_INITVAL_5;
defparam EBR_inst.INITVAL_36 = QT40_INITVAL_6;
defparam EBR_inst.INITVAL_37 = QT40_INITVAL_7;
 
defparam EBR_inst.INITVAL_38 = QT80_INITVAL_0;  
defparam EBR_inst.INITVAL_39 = QT80_INITVAL_1;
defparam EBR_inst.INITVAL_3A = QT80_INITVAL_2;
defparam EBR_inst.INITVAL_3B = QT80_INITVAL_3;
defparam EBR_inst.INITVAL_3C = QT80_INITVAL_4;
defparam EBR_inst.INITVAL_3D = QT80_INITVAL_5;
defparam EBR_inst.INITVAL_3E = QT80_INITVAL_6;
defparam EBR_inst.INITVAL_3F = QT80_INITVAL_7;
`endif  

endmodule

 
 






















 








































































 






























































































































































