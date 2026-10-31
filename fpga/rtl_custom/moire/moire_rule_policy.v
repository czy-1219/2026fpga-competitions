 



module moire_rule_policy (
    input  [7:0] periodic_x_i,
    input  [7:0] periodic_y_i,
    input  [7:0] high_frequency_i,
    input  [7:0] edge_i,
    output reg [7:0] weight_c0_o,
    output reg [7:0] weight_c1_o,
    output reg [7:0] weight_c2_o,
    output reg [7:0] weight_c3_o,
    output reg [7:0] weight_c4_o,
    output reg [7:0] text_protect_o
);
    reg [7:0] pmax;
    reg [7:0] pmin;
    reg [7:0] periodic;
    reg [7:0] horizontal;
    reg [7:0] vertical;
    reg [7:0] dct;
    reg [7:0] guided;
    reg [8:0] used;
    reg [7:0] protect;
    reg [15:0] protect_product;

    always @* begin
        pmax = (periodic_x_i >= periodic_y_i) ? periodic_x_i : periodic_y_i;
        pmin = (periodic_x_i < periodic_y_i) ? periodic_x_i : periodic_y_i;

         
        periodic = ((pmax * 9) + (high_frequency_i * 7)) >> 4;

         
        horizontal = (periodic_x_i >= periodic_y_i) ? (periodic * 3 >> 3)
                                                     : (periodic * 1 >> 3);
        vertical   = (periodic_x_i >= periodic_y_i) ? (periodic * 1 >> 3)
                                                     : (periodic * 3 >> 3);
        dct = (pmin * 3) >> 4;
        guided = (edge_i * (8'd255 - periodic) * 3) >> 11;

        used = horizontal + vertical + dct + guided;
        if (used > 9'd220)
            used = 9'd220;

        weight_c1_o = horizontal;
        weight_c2_o = vertical;
        weight_c3_o = dct;
        weight_c4_o = guided;
        weight_c0_o = 8'd255 - used[7:0];

         
        protect_product = edge_i * (8'd255 - periodic);
        protect = protect_product[15:8];
        if (protect < (edge_i >> 2))
            protect = edge_i >> 2;
        text_protect_o = protect;
    end
endmodule
