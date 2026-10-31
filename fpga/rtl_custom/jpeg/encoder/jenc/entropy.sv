/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 */
module entropy (
    input   logic signed[10:0]      q[1:0], 
    input   logic                   q_valid,
    output  logic                   q_hold,
    input   logic [4:0]             q_cnt,
    input   logic [1:0]             q_chroma,
    input   logic                   q_last_mcu,

     
    output  logic [5:0]             out_codecoeff_length,
    output  logic [51:0]            out_codecoeff,
    output  logic                   out_tlast,
    output  logic                   out_valid,
    input   logic                   out_hold,

    input   logic                   clk,
    input   logic                   resetn
);

always_comb q_hold = out_hold;

 
function automatic [3:0] bit_length(input logic[11:0] coeff);
    int length = 0;
    for (int v = coeff ; v > 0; v = v >> 1)
        length++;
    bit_length = length;
endfunction

 
logic signed[10:0]          previousDC[2:0];
always @(posedge clk)
if (!resetn)
     

    for (int c=0; c<3; c++)
        previousDC[c] <= '0;
else if (q_valid & !q_hold)
    if (q_last_mcu & &q_cnt)   


        for (int c=0; c<3; c++)
            previousDC[c] <= '0;
    else if (q_cnt == 0)
        previousDC[q_chroma] <= q[0];
    
 
logic unsigned[3:0]     rl[1:0], next_rl[1:0], rl_stored;
logic unsigned[1:0]     rl16[1:0], next_rl16[1:0], rl16_stored;
logic                   rl_valid[1:0];

always @(posedge clk) if (q_valid & !q_hold) rl_stored <= next_rl[1];
always @(posedge clk) if (q_valid & !q_hold) rl16_stored <= next_rl16[1];

always_comb
    for (int i=0; i<2; i++) begin
        rl[i] = i==0 ? rl_stored : next_rl[i-1];
        rl16[i] = i==0 ? rl16_stored : next_rl16[i-1];

        if (i==0 & q_cnt==0 || q[i] != 0) begin  
            rl_valid[i] = 1;
            next_rl[i] = 0;
            next_rl16[i] = 0;
        end
        else if(i==1 & &q_cnt) begin         
            rl_valid[i] = 1;
            next_rl[1] = 0;                  
            next_rl[0] = 0;                  
            next_rl16[1] = 0;
            next_rl16[0] = 0;
        end
        else if(rl[i]==15) begin             
            rl_valid[i] = 0;
            next_rl[i] = 0;
            next_rl16[i] = rl16[i] + 1;
        end
        else begin                           
            rl_valid[i] = 0;
            next_rl[i] = rl[i] + 1;
            next_rl16[i] = rl16[i];
        end
    end

 
logic signed[11:0]          tmp_coeff[1:0];      
logic unsigned[10:0]        coeff[1:0];          
logic unsigned[3:0]         coeff_length[1:0];
always_comb
    for (int i=0; i<2; i++) begin
        tmp_coeff[i] = (i==0 & q_cnt==0) ? q[i] - previousDC[q_chroma] : q[i];
        coeff_length[i] = bit_length(tmp_coeff[i] < 0 ? -tmp_coeff[i] : tmp_coeff[i]);
        if (tmp_coeff[i] < 0)
            coeff[i] = tmp_coeff[i] + ~('1 << coeff_length[i]);
        else 
            coeff[i] = tmp_coeff[i];
    end


 
logic [7:0]         ht_symbol[1:0];   
logic [3:0]         ht_rl[1:0], ht_coeff_length[1:0];
logic [1:0]         ht_re;
logic               ht_chroma;
logic [1:0]         ht_ac;
logic [4:0]         code_length0[1:0];
logic [15:0]        code0[1:0];

always_comb for (int i=0; i<2; i++) begin
    ht_rl[i]            =  rl_valid[i] ? ((q[i]==0 & i==1 & &q_cnt) ?  4'h0 :           rl[i]) : 8'hf;
    ht_coeff_length[i]  =  rl_valid[i] ? ((q[i]==0 & i==1 & &q_cnt) ?  4'h0 : coeff_length[i]) : 4'h0;
    ht_symbol[i] = {ht_rl[i], ht_coeff_length[i]};  

    ht_re[i] = q_valid & !q_hold & (rl_valid[i] | rl[i]==13-i | rl[i]==12-i);  
    ht_ac[i] = ~(i==0 & q_cnt==0);
end
always_comb ht_chroma = |q_chroma;

`ifndef INFER_HUFFMAN_CODES_ROM
logic [4:0] rom_len[1:0];
`endif  

huff_tables ht (
    .rl         (ht_rl),
    .coeff_length (ht_coeff_length),
    .re         (~out_hold),
    .chroma     (ht_chroma),
    .ac         (ht_ac),
`ifdef INFER_HUFFMAN_CODES_ROM
    .len        (code_length0),
    .code       (code0),
`else
    .len        (rom_len),  
    .code       ( ),
`endif  
    .clk
);

`ifndef INFER_HUFFMAN_CODES_ROM
logic [17:0] rom_rd[1:0];
logic [8:0] rom_addr[1:0];

generate
for (genvar i=0; i<2; i++) begin
always_comb rom_addr[i][8:5] = ht_ac[i] ? ht_coeff_length[i]  : 4'hb;  
always_comb rom_addr[i][4:1] = ht_ac[i] ? ht_rl[i] : ht_coeff_length[i];  
always_comb rom_addr[i][0] =  ht_chroma;

always_comb code_length0[i][4:2] = rom_len[i][4:2];
always_comb code_length0[i][1:0] = 1 + rom_rd[i][17:16];
always_comb code0[i] = rom_rd[i][15:0];
end
endgenerate

huffman_codes_rom_EBR huffman_codes_rom (
    .rd_clk_i   (clk), 
    .rd_en_i    (~out_hold), 
    .rd_addr0_i (rom_addr[0]), 
    .rd_addr1_i (rom_addr[1]), 
    .rd_data0_o (rom_rd[0]),
    .rd_data1_o (rom_rd[1])
);
`endif  

 














 



















 

logic unsigned[10:0]        coeff0[1:0];         
logic unsigned[10:0]        coeff1[1:0];         
logic unsigned[10:0]        coeff2[1:0];         
logic unsigned[3:0]         coeff_length0[1:0];
logic unsigned[3:0]         coeff_length1[1:0];
logic unsigned[3:0]         coeff_length2[1:0];
 
logic unsigned[15:0]        code1[1:0];
logic unsigned[15:0]        code2[1:0];
logic unsigned[4:0]         code_length1[1:0];
logic unsigned[4:0]         code_length2[1:0];
 
logic [4:0]                 codecoeff_length3[1:0];
logic [25:0]                codecoeff3[1:0];
 
logic [1:0]                 out_valid0, out_valid1, out_valid2, out_valid3;
logic [3:0]                 last_mcu;

always @(posedge clk)
for (int i=0; i<2; i++)
    if (!out_hold) begin
         
        if(q_valid & rl_valid[i]) begin
            coeff0[i] <= coeff[i];
            coeff_length0[i] <= coeff_length[i];
        end    

        if(out_valid0[i]) begin
            coeff1[i] <= coeff0[i];
            coeff_length1[i] <= coeff_length0[i];
        end else if (q_valid & (rl_valid[0] & q[0]!=0 & rl16[0][1]) | (rl_valid[1] & q[1]!=0 & rl16[1][1]))
            coeff_length1[i] <= 0;  

        if(out_valid1[i]) begin
            coeff2[i] <= coeff1[i];
            coeff_length2[i] <= coeff_length1[i];
        end else if (i==1 & q_valid & (rl_valid[0] & q[0]!=0 & rl16[0][0]) | (rl_valid[1] & q[1]!=0 & rl16[1][0]))
            coeff_length2[i] <= 0;  


        if (out_valid0[i] | (q_valid & (rl_valid[0] & q[0]!=0 & rl16[0][1]) | (rl_valid[1] & q[1]!=0 & rl16[1][1]))) begin   
            code1[i] <= code0[i];
            code_length1[i] <= code_length0[i];
        end
    
        if(out_valid1[i]) begin
            code2[i] <= code1[i];
            code_length2[i] <= code_length1[i];
        end
        else if(i==1 & q_valid & (rl_valid[0] & q[0]!=0 & rl16[0][0]) | (rl_valid[1] & q[1]!=0 & rl16[1][0])) begin  
            code2[i] <= code0[i];
            code_length2[i] <= code_length0[i];
        end
        
         
        if (out_valid2[i]) begin
            logic [4:0] tmp_codecoeff_length;
            tmp_codecoeff_length = code_length2[i] + coeff_length2[i];
            codecoeff_length3[i] <= tmp_codecoeff_length;
            if (tmp_codecoeff_length > 26 | tmp_codecoeff_length < 1)
                codecoeff3[i] <= 'hx;
            else
                codecoeff3[i] <= (code_length2[i] != 0 ? (code2[i] << 10) : 0) | (coeff_length2[i] != 0 ? (coeff2[i] << (26 - tmp_codecoeff_length)) : 0);
        end
    end

 
logic [4:0] tmp_codecoeff_length0;
logic [4:0] tmp_codecoeff_length1;
logic [5:0] tmp_codecoeff_length;
always_comb tmp_codecoeff_length0 = out_valid3[0] ? codecoeff_length3[0] : 0;
always_comb tmp_codecoeff_length1 = out_valid3[1] ? codecoeff_length3[1] : 0;
always_comb tmp_codecoeff_length = tmp_codecoeff_length0 + tmp_codecoeff_length1;

always @(posedge clk)
if (|out_valid3 & !out_hold) begin
    out_codecoeff_length <= tmp_codecoeff_length;
    if (tmp_codecoeff_length > 52 | tmp_codecoeff_length < 2)
        out_codecoeff <= {52{1'hx}};
    else
        out_codecoeff <= 
            (out_valid3[0] ? (codecoeff3[0] << 26) : 0) | 
            (out_valid3[1] ? (codecoeff3[1] << (26 - tmp_codecoeff_length0)) : 0);
end

 
always @(posedge clk)
if (!out_hold) begin
    if (q_valid) last_mcu[0] <= q_last_mcu & &q_cnt;
    if (out_valid0) last_mcu[1] <= last_mcu[0];
    if (out_valid1) last_mcu[2] <= last_mcu[1];
    if (out_valid2) last_mcu[3] <= last_mcu[2];
    if (out_valid3) out_tlast <= last_mcu[3];
end

always @(posedge clk)
if (!resetn)  begin
    out_valid0 <= 0;
    out_valid1 <= 0;
    out_valid2 <= 0;
    out_valid3 <= 0;
    out_valid <= 0;
end
else if (!out_hold) begin
    out_valid0[0] <= q_valid & rl_valid[0];
    out_valid0[1] <= q_valid & rl_valid[1];

    if (q_valid & ((rl_valid[0] & q[0]!=0 & rl16[0][1]) | (rl_valid[1] & q[1]!=0 & rl16[1][1])))  
        out_valid1 <= {1'b1, 1'b1};
    else
        out_valid1 <= out_valid0;

    if (q_valid & ((rl_valid[0] & q[0]!=0 & rl16[0][0]) | (rl_valid[1] & q[1]!=0 & rl16[1][0])))  
        out_valid2[1] <= '1;
    else
        out_valid2 <= out_valid1;

    out_valid3 <= out_valid2;

     
    out_valid <= |out_valid3;
end

endmodule



 




















 






















 




























