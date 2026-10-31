 

module jpeg_dht_serial(
 input wire clk_i,rst_i,cfg_valid_i,input wire [7:0] cfg_data_i,input wire cfg_last_i,
 input wire lookup_req_i,input wire [1:0] lookup_table_i,input wire [15:0] lookup_input_i,
 output wire cfg_accept_o,output reg lookup_valid_o,output reg [4:0] lookup_width_o,output reg [7:0] lookup_value_o
);
 (* syn_ramstyle="block_ram" *) reg [31:0] codes[0:63];
 (* syn_ramstyle="block_ram" *) reg [7:0] symbols[0:1023];
 reg [31:0] code_q;reg [7:0] symbol_q;
 reg [4:0] position;reg [1:0] table_id;reg table_supported;
 reg [16:0] next_code;reg [8:0] symbol_count,symbol_index;
 reg [3:0] configured;
 reg [2:0] state;reg [1:0] search_table;reg [3:0] length_index;reg [15:0] bits;
 reg [9:0] symbol_address;
 localparam IDLE=0,READ=1,CHECK=2,SYMBOL_READ=3,SYMBOL_RESULT=4;
 wire [15:0] prefix=bits>>(15-length_index);
 wire [16:0] delta={1'b0,prefix}-{1'b0,code_q[31:16]};
 wire match=prefix>=code_q[31:16] && delta<{9'd0,code_q[15:8]};
 assign cfg_accept_o=1'b1;
 always @(posedge clk_i)begin
  if(cfg_valid_i && position>=1 && position<=16 && table_supported)
   codes[{table_id,position[3:0]-4'd1}]<={next_code[15:0],cfg_data_i,symbol_count[7:0]};
  if(cfg_valid_i && position==17 && table_supported)
   symbols[{table_id,symbol_index[7:0]}]<=cfg_data_i;
  if(state==READ)code_q<=codes[{search_table,length_index}];
  if(state==SYMBOL_READ)symbol_q<=symbols[symbol_address];
 end
 always @(posedge clk_i)begin
  if(rst_i)begin
   position<=0;table_id<=0;table_supported<=0;next_code<=0;symbol_count<=0;symbol_index<=0;configured<=0;
   state<=IDLE;search_table<=0;length_index<=0;bits<=0;symbol_address<=0;lookup_valid_o<=0;lookup_width_o<=0;lookup_value_o<=0;
  end else begin
   lookup_valid_o<=0;
   if(cfg_valid_i)begin
    if(position==0)begin
     table_id<={cfg_data_i[0],cfg_data_i[4]};table_supported<=(cfg_data_i&8'hee)==0;
     configured[{cfg_data_i[0],cfg_data_i[4]}]<=0;next_code<=0;symbol_count<=0;symbol_index<=0;position<=1;
    end else if(position<=16)begin
     next_code<=(next_code+{9'd0,cfg_data_i})<<1;symbol_count<=symbol_count+{1'b0,cfg_data_i};position<=position+1;
    end else begin
     symbol_index<=symbol_index+1;
     if(symbol_index+1==symbol_count)begin position<=0;configured[table_id]<=table_supported && symbol_count<=256;end
    end
    if(cfg_last_i)position<=0;
   end
   case(state)
    IDLE:if(lookup_req_i)begin search_table<=lookup_table_i;bits<=lookup_input_i;length_index<=0;state<=READ;end
    READ:state<=CHECK;
    CHECK:begin
     if(configured[search_table] && match)begin symbol_address<={search_table,code_q[7:0]+delta[7:0]};lookup_width_o<={1'b0,length_index}+1;state<=SYMBOL_READ;end
     else if(length_index==15)begin lookup_width_o<=16;lookup_value_o<=0;lookup_valid_o<=1;state<=IDLE;end
     else begin length_index<=length_index+1;state<=READ;end
    end
    SYMBOL_READ:state<=SYMBOL_RESULT;
    SYMBOL_RESULT:begin lookup_value_o<=symbol_q;lookup_valid_o<=1;state<=IDLE;end
   endcase
  end
 end
endmodule
