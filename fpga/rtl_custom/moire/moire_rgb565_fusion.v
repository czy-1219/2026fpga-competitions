 

module moire_rgb565_fusion (
    input        clk_i,
    input        rst_n_i,
    input        valid_i,
    input  [15:0] c0_i,
    input  [15:0] c1_i,
    input  [15:0] c2_i,
    input  [15:0] c3_i,
    input  [15:0] c4_i,
    input  [7:0]  weight_c0_i,
    input  [7:0]  weight_c1_i,
    input  [7:0]  weight_c2_i,
    input  [7:0]  weight_c3_i,
    input  [7:0]  weight_c4_i,
    input  [7:0]  text_protect_i,
    output reg [15:0] pixel_o,
    output reg        valid_o
);
    reg [15:0] c0_d1, c1_d1, c2_d1, c3_d1, c4_d1;
    reg [7:0] w0_d1, w1_d1, w2_d1, w3_d1, w4_d1, protect_d1;
    reg [15:0] r_sum_d2, g_sum_d2, b_sum_d2;
    reg valid_d1, valid_d2;
    integer w0_eff, w1_eff, w2_eff, w3_eff, w4_eff;
    integer r_sum, g_sum, b_sum;

    always @* begin
         

        w0_eff = w0_d1 + ((255 - w0_d1) * protect_d1 >> 8);
        w1_eff = w1_d1 * (255 - protect_d1) >> 8;
        w2_eff = w2_d1 * (255 - protect_d1) >> 8;
        w3_eff = w3_d1 * (255 - protect_d1) >> 8;
        w4_eff = w4_d1 * (255 - protect_d1) >> 8;
        r_sum = c0_d1[15:11]*w0_eff + c1_d1[15:11]*w1_eff
              + c2_d1[15:11]*w2_eff + c3_d1[15:11]*w3_eff
              + c4_d1[15:11]*w4_eff;
        g_sum = c0_d1[10:5]*w0_eff + c1_d1[10:5]*w1_eff
              + c2_d1[10:5]*w2_eff + c3_d1[10:5]*w3_eff
              + c4_d1[10:5]*w4_eff;
        b_sum = c0_d1[4:0]*w0_eff + c1_d1[4:0]*w1_eff
              + c2_d1[4:0]*w2_eff + c3_d1[4:0]*w3_eff
              + c4_d1[4:0]*w4_eff;
    end

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            c0_d1 <= 0; c1_d1 <= 0; c2_d1 <= 0; c3_d1 <= 0; c4_d1 <= 0;
            w0_d1 <= 0; w1_d1 <= 0; w2_d1 <= 0; w3_d1 <= 0; w4_d1 <= 0;
            protect_d1 <= 0;
            r_sum_d2 <= 0; g_sum_d2 <= 0; b_sum_d2 <= 0;
            valid_d1 <= 0; valid_d2 <= 0; valid_o <= 0; pixel_o <= 0;
        end else begin
             
            c0_d1 <= c0_i; c1_d1 <= c1_i; c2_d1 <= c2_i;
            c3_d1 <= c3_i; c4_d1 <= c4_i;
            w0_d1 <= weight_c0_i; w1_d1 <= weight_c1_i;
            w2_d1 <= weight_c2_i; w3_d1 <= weight_c3_i;
            w4_d1 <= weight_c4_i; protect_d1 <= text_protect_i;
            valid_d1 <= valid_i;

             
            r_sum_d2 <= r_sum[15:0];
            g_sum_d2 <= g_sum[15:0];
            b_sum_d2 <= b_sum[15:0];
            valid_d2 <= valid_d1;

             
            pixel_o[15:11] <= (r_sum_d2 > 7905) ? 5'h1f : r_sum_d2[12:8];
            pixel_o[10:5]  <= (g_sum_d2 > 16065) ? 6'h3f : g_sum_d2[13:8];
            pixel_o[4:0]   <= (b_sum_d2 > 7905) ? 5'h1f : b_sum_d2[12:8];
            valid_o <= valid_d2;
        end
    end
endmodule
