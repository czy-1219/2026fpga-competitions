`timescale 1ns/1ps
 



module full_student_mac16 #(parameter LANES=8, parameter QUANT_UNITS=2)(
 input wire clk_i,rst_n_i,
 input wire start_valid_i,output wire start_ready_o,
 input wire [LANES*64-1:0] bias_i,
 input wire [LANES*8-1:0] shift_i,
 input wire [LANES-1:0] lane_enable_i,
 input wire term_valid_i,output wire term_ready_o,
 input wire signed [15:0] activation_i,
 input wire [LANES*16-1:0] weights_i,input wire term_last_i,
 output reg result_valid_o,input wire result_ready_i,
 output wire [LANES*64-1:0] accumulator_o,
 output wire [LANES*16-1:0] result_o,
 output wire [LANES-1:0] saturated_o,
 output reg overflow_o
);
 reg active,pending,pending_last,quantizing;
 localparam UNITS=LANES<QUANT_UNITS ? LANES : QUANT_UNITS;
 wire [UNITS-1:0] quant_done;
 reg [LANES-1:0] enabled;
 reg signed [31:0] product[0:LANES-1];
 reg signed [63:0] accum[0:LANES-1];
 reg signed [7:0] shift[0:LANES-1];
 assign start_ready_o=!active && !pending && !quantizing && !result_valid_o;
 assign term_ready_o=active && !(pending && pending_last);
 wire accept=term_valid_i && term_ready_o;
  


 genvar g,u;
 generate for(g=0;g<LANES;g=g+1)begin:lanes
  assign accumulator_o[g*64+:64]=accum[g];
  assign result_o[g*16+:16]=quantizers[g%UNITS].unit_results[g*16+:16];
  assign saturated_o[g]=quantizers[g%UNITS].unit_saturated[g];
 end
 for(u=0;u<UNITS;u=u+1)begin:quantizers
  localparam LANE_BITS=LANES>1 ? $clog2(LANES) : 1;
  reg [LANE_BITS-1:0] quant_lane;
  reg [LANES*16-1:0] unit_results;reg [LANES-1:0] unit_saturated;
  reg unit_active,unit_done;
  reg [1:0] quant_state;reg [63:0] magnitude;reg negative,leftward,guard,sticky;
  reg [6:0] remaining;
  wire [16:0] rounded={1'b0,magnitude[15:0]}+{16'd0,(!leftward && guard && (sticky || magnitude[0]))};
  wire clipped=(|magnitude[63:16]) || (negative ? rounded>17'd32768 : rounded>17'd32767);
  wire [15:0] quant_pixel=clipped ? (negative ? 16'h8000 : 16'h7fff) : negative ? (~rounded[15:0]+16'd1) : rounded[15:0];
  assign quant_done[u]=unit_done;
  always @(posedge clk_i or negedge rst_n_i)begin
   if(!rst_n_i)begin
    quant_lane<=u;unit_results<=0;unit_saturated<=0;unit_active<=0;unit_done<=0;
    quant_state<=0;magnitude<=0;negative<=0;leftward<=0;guard<=0;sticky<=0;remaining<=0;
   end else begin
    if(start_valid_i && start_ready_o)unit_done<=0;
    if(pending && pending_last)begin unit_active<=1;unit_done<=0;quant_lane<=u;quant_state<=0;end
    if(unit_active)begin
    case(quant_state)
     0:begin
      negative<=accum[quant_lane][63];magnitude<=accum[quant_lane][63] ? -accum[quant_lane] : accum[quant_lane];
      leftward<=shift[quant_lane]<0;guard<=0;sticky<=0;
      if(shift[quant_lane]>=64)begin magnitude<=0;remaining<=0;end
      else if(shift[quant_lane]< -15)begin magnitude<=accum[quant_lane]!=0 ? 65536 : 0;remaining<=0;end
      else remaining<=shift[quant_lane]<0 ? -shift[quant_lane] : shift[quant_lane];
      quant_state<=1;
     end
     1:begin
      if(remaining==0)quant_state<=2;
      else if(leftward)begin
       if(magnitude>32768)begin magnitude<=65536;remaining<=0;end
       else begin magnitude<=magnitude<<1;remaining<=remaining-1;end
      end else if(remaining>=16)begin
       sticky<=sticky||guard||(|magnitude[14:0]);guard<=magnitude[15];magnitude<=magnitude>>16;remaining<=remaining-16;
       if(remaining==16)quant_state<=2;
      end else if(remaining>=8)begin
       sticky<=sticky||guard||(|magnitude[6:0]);guard<=magnitude[7];magnitude<=magnitude>>8;remaining<=remaining-8;if(remaining==8)quant_state<=2;
      end else if(remaining>=4)begin
       sticky<=sticky||guard||(|magnitude[2:0]);guard<=magnitude[3];magnitude<=magnitude>>4;remaining<=remaining-4;if(remaining==4)quant_state<=2;
      end else if(remaining>=2)begin
       sticky<=sticky||guard||magnitude[0];guard<=magnitude[1];magnitude<=magnitude>>2;remaining<=remaining-2;if(remaining==2)quant_state<=2;
      end else begin sticky<=sticky||guard;guard<=magnitude[0];magnitude<=magnitude>>1;remaining<=remaining-1;quant_state<=2;end
     end
     2:begin
      unit_results[quant_lane*16+:16]<=enabled[quant_lane] ? quant_pixel : 16'd0;
      unit_saturated[quant_lane]<=enabled[quant_lane] && clipped;
      quant_state<=0;
      if(quant_lane+UNITS>=LANES)begin unit_active<=0;unit_done<=1;end else quant_lane<=quant_lane+UNITS;
     end
    endcase
    end
   end
  end
 end endgenerate
 integer i;
 reg signed [64:0] sum;
 always @(posedge clk_i or negedge rst_n_i)begin
  if(!rst_n_i)begin
   active<=0;pending<=0;pending_last<=0;result_valid_o<=0;enabled<=0;overflow_o<=0;quantizing<=0;
   for(i=0;i<LANES;i=i+1)begin product[i]<=0;accum[i]<=0;shift[i]<=0;end
  end else begin
   if(result_valid_o && result_ready_i)result_valid_o<=0;
   if(quantizing && (&quant_done))begin quantizing<=0;result_valid_o<=1;end
   if(start_valid_i && start_ready_o)begin
    active<=1;overflow_o<=0;enabled<=lane_enable_i;
    for(i=0;i<LANES;i=i+1)begin
     accum[i]<=lane_enable_i[i] ? $signed(bias_i[i*64+:64]) : 64'sd0;
     shift[i]<=shift_i[i*8+:8];
    end
   end
   if(accept)begin
    pending<=1;pending_last<=term_last_i;
    for(i=0;i<LANES;i=i+1)product[i]<=activation_i*$signed(weights_i[i*16+:16]);
   end
   if(pending)begin
    pending<=accept;
    for(i=0;i<LANES;i=i+1)if(enabled[i])begin
     sum=$signed({accum[i][63],accum[i]})+$signed({{33{product[i][31]}},product[i]});
     if(sum[64]!=sum[63])begin
      overflow_o<=1;accum[i]<=sum[64] ? 64'sh8000000000000000 : 64'sh7fffffffffffffff;
     end else accum[i]<=sum[63:0];
    end
    if(pending_last)begin active<=0;quantizing<=1;end
   end
  end
 end
endmodule
