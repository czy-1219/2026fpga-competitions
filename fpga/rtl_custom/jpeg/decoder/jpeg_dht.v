`include "rtl_custom/jpeg/decoder/jpeg_dht_serial.v"
//-----------------------------------------------------------------
//                      Baseline JPEG Decoder
//                             V0.1
//                       Ultra-Embedded.com
//                        Copyright 2020
//
//                   admin@ultra-embedded.com
//-----------------------------------------------------------------
//                      License: Apache 2.0
// This IP can be freely used in commercial projects, however you may
// want access to unreleased materials such as verification environments,
// or test vectors, as well as changes to the IP for integration purposes.
// If this is the case, contact the above address.
// I am interested to hear how and where this IP is used, so please get
// in touch!
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module jpeg_dht
 


#(
     parameter SUPPORT_WRITABLE_DHT = 0
)
 


(
     
     input           clk_i
    ,input           rst_i
    ,input           cfg_valid_i
    ,input  [  7:0]  cfg_data_i
    ,input           cfg_last_i
    ,input           lookup_req_i
    ,input  [  1:0]  lookup_table_i
    ,input  [ 15:0]  lookup_input_i

     
    ,output          cfg_accept_o
    ,output          lookup_valid_o
    ,output [  4:0]  lookup_width_o
    ,output [  7:0]  lookup_value_o
);




localparam DHT_TABLE_Y_DC      = 8'h00;
localparam DHT_TABLE_Y_AC      = 8'h10;
localparam DHT_TABLE_CX_DC     = 8'h01;
localparam DHT_TABLE_CX_AC     = 8'h11;

 


generate
if (SUPPORT_WRITABLE_DHT)begin
 jpeg_dht_serial serial_tables(.clk_i(clk_i),.rst_i(rst_i),.cfg_valid_i(cfg_valid_i),.cfg_data_i(cfg_data_i),.cfg_last_i(cfg_last_i),.cfg_accept_o(cfg_accept_o),
 .lookup_req_i(lookup_req_i),.lookup_table_i(lookup_table_i),.lookup_input_i(lookup_input_i),.lookup_valid_o(lookup_valid_o),.lookup_width_o(lookup_width_o),.lookup_value_o(lookup_value_o));
end

else
begin
     


    wire [7:0] y_dc_value_w;
    wire [4:0] y_dc_width_w;

    jpeg_dht_std_y_dc
    u_fixed_y_dc
    (
         .lookup_input_i(lookup_input_i)
        ,.lookup_value_o(y_dc_value_w)
        ,.lookup_width_o(y_dc_width_w)
    );

     


    wire [7:0] y_ac_value_w;
    wire [4:0] y_ac_width_w;

    jpeg_dht_std_y_ac
    u_fixed_y_ac
    (
         .lookup_input_i(lookup_input_i)
        ,.lookup_value_o(y_ac_value_w)
        ,.lookup_width_o(y_ac_width_w)
    );

     


    wire [7:0] cx_dc_value_w;
    wire [4:0] cx_dc_width_w;

    jpeg_dht_std_cx_dc
    u_fixed_cx_dc
    (
         .lookup_input_i(lookup_input_i)
        ,.lookup_value_o(cx_dc_value_w)
        ,.lookup_width_o(cx_dc_width_w)
    );

     


    wire [7:0] cx_ac_value_w;
    wire [4:0] cx_ac_width_w;

    jpeg_dht_std_cx_ac
    u_fixed_cx_ac
    (
         .lookup_input_i(lookup_input_i)
        ,.lookup_value_o(cx_ac_value_w)
        ,.lookup_width_o(cx_ac_width_w)
    );

     


    reg lookup_valid_q;

    always @ (posedge clk_i )
    if (rst_i)
        lookup_valid_q <= 1'b0;
    else
        lookup_valid_q <= lookup_req_i;

    assign lookup_valid_o = lookup_valid_q;

    reg [7:0] lookup_value_q;

    always @ (posedge clk_i )
    if (rst_i)
        lookup_value_q <= 8'b0;
    else
    begin
        case (lookup_table_i)
        2'd0: lookup_value_q <= y_dc_value_w;
        2'd1: lookup_value_q <= y_ac_value_w;
        2'd2: lookup_value_q <= cx_dc_value_w;
        2'd3: lookup_value_q <= cx_ac_value_w;
        endcase
    end

    assign lookup_value_o = lookup_value_q;

    reg [4:0] lookup_width_q;

    always @ (posedge clk_i )
    if (rst_i)
        lookup_width_q <= 5'b0;
    else
    begin
        case (lookup_table_i)
        2'd0: lookup_width_q <= y_dc_width_w;
        2'd1: lookup_width_q <= y_ac_width_w;
        2'd2: lookup_width_q <= cx_dc_width_w;
        2'd3: lookup_width_q <= cx_ac_width_w;
        endcase
    end

    assign lookup_width_o = lookup_width_q;

    assign cfg_accept_o = 1'b1;
end
endgenerate


endmodule
