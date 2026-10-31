/*-------------------------------------------------------------------------
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo.www.cnblogs.com/crazybingo
(C) COPYRIGHT 2012 CrazyBingo. ALL RIGHTS RESERVED
Filename			:		I2C_OV5640_1280720_Config.v
Author				:		CrazyBingo
Date				:		2019-08-03
Version				:		1.0
Description			:		I2C Configure Data of OV5640.
Modification History	:
Date			By			Version			Change Description
===========================================================================
19/08/03		CrazyBingo	1.0				Original
--------------------------------------------------------------------------*/

`timescale 1ns/1ns
module	I2C_OV5640_1280720_Config #(		 
  parameter IMAGE_WIDTH  = 16'd1280,
            IMAGE_HEIGHT = 16'd720,
            IMAGE_FLIP   = 8'h40,
            IMAGE_MIRROR = 4'h7,
            C_MANUAL_WB = 1'b0,  
            C_WB_R_GAIN = 12'h480,  
            C_WB_G_GAIN = 12'h3e0,
            C_WB_B_GAIN = 12'h3e0,
            C_AGC_CEILING = 10'h078,  
            C_LENC_ENABLE = 1'b0  
)
(
	input [6:0] CAMERA_PROFILE,
	input		[7:0]	LUT_INDEX,
	input		[1:0]	RESOLUTION_MODE,
	output	reg	[23:0]	LUT_DATA,
	output		[7:0]	LUT_SIZE
);
 

wire manual_wb=C_MANUAL_WB || CAMERA_PROFILE[6:5]!=0;
wire [11:0] wb_r=CAMERA_PROFILE[6:5]==1 ? 12'h5e0 : CAMERA_PROFILE[6:5]==2 ? 12'h520 : C_WB_R_GAIN;
wire [11:0] wb_g=CAMERA_PROFILE[6:5]!=0 ? 12'h410 : C_WB_G_GAIN;
wire [11:0] wb_b=CAMERA_PROFILE[6:5]==1 ? 12'h540 : CAMERA_PROFILE[6:5]==2 ? 12'h660 : C_WB_B_GAIN;
wire [9:0] gain_ceiling=CAMERA_PROFILE[4:3]==1 ? 10'h040 : CAMERA_PROFILE[4:3]==2 ? 10'h0f8 : C_AGC_CEILING;
wire [7:0] ae_hi=CAMERA_PROFILE[2:0]==1 ? 8'd37 : CAMERA_PROFILE[2:0]==2 ? 8'd27 : CAMERA_PROFILE[2:0]==3 ? 8'd70 : CAMERA_PROFILE[2:0]==4 ? 8'd91 : 8'h30;
wire [7:0] ae_lo=CAMERA_PROFILE[2:0]==1 ? 8'd32 : CAMERA_PROFILE[2:0]==2 ? 8'd23 : CAMERA_PROFILE[2:0]==3 ? 8'd59 : CAMERA_PROFILE[2:0]==4 ? 8'd78 : 8'h28;
`define PLL_EN
`define AE_EN

 


wire use_1080_geometry = (RESOLUTION_MODE != 2'd0);
wire use_1080_clock = 1'b0;

assign	LUT_SIZE = 1'b1 + 8'd251 ;

 

always@(*)
begin
	case(LUT_INDEX)
0 :     LUT_DATA    =   24'h3103_11;	 
1 :     LUT_DATA    =   24'h3008_82;	 

2 :     LUT_DATA    =   24'h3008_42;	 
3 :     LUT_DATA    =   24'h3103_03;	 
4 :     LUT_DATA    =   24'h3017_ff;	 
5 :     LUT_DATA    =   24'h3018_ff;	 
6 :     LUT_DATA    =   24'h3034_1a;	 
7 :     LUT_DATA    =   24'h3037_13;	 
8 :     LUT_DATA    =   24'h3108_01;	 
9 :     LUT_DATA    =   24'h3630_36;	 
10:     LUT_DATA    =   24'h3631_0e;		
11:     LUT_DATA    =   24'h3632_e2;		
12:     LUT_DATA    =   24'h3633_12;		
13:     LUT_DATA    =   24'h3621_e0;		
14:     LUT_DATA    =   24'h3704_a0;		
15:     LUT_DATA    =   24'h3703_5a;		
16:     LUT_DATA    =   24'h3715_78;		
17:     LUT_DATA    =   24'h3717_01;		
18:     LUT_DATA    =   24'h370b_60;		
19:     LUT_DATA    =   24'h3705_1a;		
20:     LUT_DATA    =   24'h3905_02;		
21:     LUT_DATA    =   24'h3906_10;		
22:     LUT_DATA    =   24'h3901_0a;		
23:     LUT_DATA    =   24'h3731_12;		
24:     LUT_DATA    =   24'h3600_08;	 
25:     LUT_DATA    =   24'h3601_33;	 
26:     LUT_DATA    =   24'h302d_60;	 
27:     LUT_DATA    =   24'h3620_52;		
28:     LUT_DATA    =   24'h371b_20;		
29:     LUT_DATA    =   24'h471c_50;		
30:     LUT_DATA    =   24'h3a13_43;	 
31:     LUT_DATA    =   {16'h3a18, 6'b000000, gain_ceiling[9:8]};  
32:     LUT_DATA    =   {16'h3a19, gain_ceiling[7:0]};  
33:     LUT_DATA    =   24'h3635_13;		
34:     LUT_DATA    =   24'h3636_03;		
35:     LUT_DATA    =   24'h3634_40;		
36:     LUT_DATA    =   24'h3622_01;		
   	 
37:     LUT_DATA    =   24'h3c01_34;	 
38:     LUT_DATA    =   24'h3c04_28;	 
39:     LUT_DATA    =   24'h3c05_98;	 
40:     LUT_DATA    =   24'h3c06_00;	 
41:     LUT_DATA    =   24'h3c07_08;	 
42:     LUT_DATA    =   24'h3c08_00;	 
43:     LUT_DATA    =   24'h3c09_1c;	 
44:     LUT_DATA    =   24'h3c0a_9c;	 
45:     LUT_DATA    =   24'h3c0b_40;	 
46:     LUT_DATA    =   24'h3810_00;	 
47:     LUT_DATA    =   24'h3811_10;	 
48:     LUT_DATA    =   24'h3812_00;	 
49:     LUT_DATA    =   24'h3708_64;		
50:     LUT_DATA    =   24'h4001_02;	 
51:     LUT_DATA    =   24'h4005_1a;	 
52:     LUT_DATA    =   24'h3000_00;	 
53:     LUT_DATA    =   24'h3004_ff;	 
54:     LUT_DATA    =   24'h300e_58;	 
55:     LUT_DATA    =   24'h302e_00;		
56:     LUT_DATA    =   24'h4300_61; 	 
57:     LUT_DATA    =   24'h501f_01;	 
58:     LUT_DATA    =   24'h440e_00;		
59:     LUT_DATA    =   (C_LENC_ENABLE ? 24'h5000_a7 : 24'h5000_27);  

60:     LUT_DATA    =   {16'h3a0f,ae_hi};	 
61:     LUT_DATA    =   {16'h3a10,ae_lo};	 
62:     LUT_DATA    =   {16'h3a1b,ae_hi};	 
63:     LUT_DATA    =   {16'h3a1e,(CAMERA_PROFILE[2:0]==0 ? 8'h26 : ae_lo)};	 
64:     LUT_DATA    =   {16'h3a11,ae_hi[6:0],1'b0};	 
65:     LUT_DATA    =   {16'h3a1f,1'b0,ae_lo[7:1]};	 

66 :     LUT_DATA    =   24'h5800_23;		
67 :     LUT_DATA    =   24'h5801_14;		
68 :     LUT_DATA    =   24'h5802_0f;		
69 :     LUT_DATA    =   24'h5803_0f;		
70 :     LUT_DATA    =   24'h5804_12;		
71 :     LUT_DATA    =   24'h5805_26;		
72 :     LUT_DATA    =   24'h5806_0c;		
73 :     LUT_DATA    =   24'h5807_08;		
74 :     LUT_DATA    =   24'h5808_05;		
75 :     LUT_DATA    =   24'h5809_05;		
76 :     LUT_DATA    =   24'h580a_08;		
77 :     LUT_DATA    =   24'h580b_0d;		
78 :     LUT_DATA    =   24'h580c_08;		
79 :     LUT_DATA    =   24'h580d_03;		
80 :     LUT_DATA    =   24'h580e_00;		
81 :     LUT_DATA    =   24'h580f_00;		
82 :     LUT_DATA    =   24'h5810_03;		
83 :     LUT_DATA    =   24'h5811_09;		
84 :     LUT_DATA    =   24'h5812_07;		
85 :     LUT_DATA    =   24'h5813_03;		
86 :     LUT_DATA    =   24'h5814_00;		
87 :     LUT_DATA    =   24'h5815_01;		
88 :     LUT_DATA    =   24'h5816_03;		
89 :     LUT_DATA    =   24'h5817_08;		
90 :     LUT_DATA    =   24'h5818_0d;		
91 :     LUT_DATA    =   24'h5819_08;		
92 :     LUT_DATA    =   24'h581a_05;		
93 :     LUT_DATA    =   24'h581b_06;		
94 :     LUT_DATA    =   24'h581c_08;		
95 :     LUT_DATA    =   24'h581d_0e;		
96 :     LUT_DATA    =   24'h581e_29;		
97 :     LUT_DATA    =   24'h581f_17;		
98 :     LUT_DATA    =   24'h5820_11;		
99 :     LUT_DATA    =   24'h5821_11;		
100:     LUT_DATA    =   24'h5822_15;		
101:     LUT_DATA    =   24'h5823_28;		
102:     LUT_DATA    =   24'h5824_46;		
103:     LUT_DATA    =   24'h5825_26;		
104:     LUT_DATA    =   24'h5826_08;		
105:     LUT_DATA    =   24'h5827_26;		
106:     LUT_DATA    =   24'h5828_64;		
107:     LUT_DATA    =   24'h5829_26;		
108:     LUT_DATA    =   24'h582a_24;		
109:     LUT_DATA    =   24'h582b_22;		
110:     LUT_DATA    =   24'h582c_24;		
111:     LUT_DATA    =   24'h582d_24;		
112:     LUT_DATA    =   24'h582e_06;		
113:     LUT_DATA    =   24'h582f_22;		
114:     LUT_DATA    =   24'h5830_40;		
115:     LUT_DATA    =   24'h5831_42;		
116:     LUT_DATA    =   24'h5832_24;		
117:     LUT_DATA    =   24'h5833_26;		
118:     LUT_DATA    =   24'h5834_24;		
119:     LUT_DATA    =   24'h5835_22;		
120:     LUT_DATA    =   24'h5836_22;		
121:     LUT_DATA    =   24'h5837_26;		
122:     LUT_DATA    =   24'h5838_44;		
123:     LUT_DATA    =   24'h5839_24;		
124:     LUT_DATA    =   24'h583a_26;		
125:     LUT_DATA    =   24'h583b_28;		
126:     LUT_DATA    =   24'h583c_42;		
127:     LUT_DATA    =   24'h583d_ce;	 

128:     LUT_DATA    =   24'h5180_ff;	 
129:     LUT_DATA    =   24'h5181_f2;	 
130:     LUT_DATA    =   24'h5182_00;	 
131:     LUT_DATA    =   24'h5183_14;	 
132:     LUT_DATA    =   24'h5184_25;		
133:     LUT_DATA    =   24'h5185_24;		
134:     LUT_DATA    =   24'h5186_09;		
135:     LUT_DATA    =   24'h5187_09;		
136:     LUT_DATA    =   24'h5188_09;		
137:     LUT_DATA    =   24'h5189_75;		
138:     LUT_DATA    =   24'h518a_54;		
139:     LUT_DATA    =   24'h518b_e0;		
140:     LUT_DATA    =   24'h518c_b2;		
141:     LUT_DATA    =   24'h518d_42;		
142:     LUT_DATA    =   24'h518e_3d;		
143:     LUT_DATA    =   24'h518f_56;		
144:     LUT_DATA    =   24'h5190_46;		
145:     LUT_DATA    =   24'h5191_f8;	 
146:     LUT_DATA    =   24'h5192_04;	 
147:     LUT_DATA    =   24'h5193_70;	 
148:     LUT_DATA    =   24'h5194_f0;	 
149:     LUT_DATA    =   24'h5195_f0;	 
150:     LUT_DATA    =   24'h5196_03;	 
151:     LUT_DATA    =   24'h5197_01;	 
152:     LUT_DATA    =   (manual_wb ? {16'h3400, 4'b0000, wb_r[11:8]} : 24'h5198_04);  
153:     LUT_DATA    =   (manual_wb ? {16'h3401, wb_r[7:0]} : 24'h5199_12);  
154:     LUT_DATA    =   (manual_wb ? {16'h3402, 4'b0000, wb_g[11:8]} : 24'h519a_04);  
155:     LUT_DATA    =   (manual_wb ? {16'h3403, wb_g[7:0]} : 24'h519b_00);  
156:     LUT_DATA    =   (manual_wb ? {16'h3404, 4'b0000, wb_b[11:8]} : 24'h519c_06);  
157:     LUT_DATA    =   (manual_wb ? {16'h3405, wb_b[7:0]} : 24'h519d_82);  
158:     LUT_DATA    =   (manual_wb ? 24'h3406_01 : 24'h519e_38);  

159:     LUT_DATA    =   24'h5480_01;	 
160:     LUT_DATA    =   24'h5481_08;		
161:     LUT_DATA    =   24'h5482_14;		
162:     LUT_DATA    =   24'h5483_28;		
163:     LUT_DATA    =   24'h5484_51;		
164:     LUT_DATA    =   24'h5485_65;		
165:     LUT_DATA    =   24'h5486_71;		
166:     LUT_DATA    =   24'h5487_7d;		
167:     LUT_DATA    =   24'h5488_87;		
168:     LUT_DATA    =   24'h5489_91;		
169:     LUT_DATA    =   24'h548a_9a;		
170:     LUT_DATA    =   24'h548b_aa;		
171:     LUT_DATA    =   24'h548c_b8;		
172:     LUT_DATA    =   24'h548d_cd;		
173:     LUT_DATA    =   24'h548e_dd;		
174:     LUT_DATA    =   24'h548f_ea;		
175:     LUT_DATA    =   24'h5490_1d;		
   	 
176:     LUT_DATA    =   24'h5381_1e;	 
177:     LUT_DATA    =   24'h5382_5b;	 
178:     LUT_DATA    =   24'h5383_08;	 
179:     LUT_DATA    =   24'h5384_0a;	 
180:     LUT_DATA    =   24'h5385_7e;	 
181:     LUT_DATA    =   24'h5386_88;	 
182:     LUT_DATA    =   24'h5387_7c;	 
183:     LUT_DATA    =   24'h5388_6c;	 
184:     LUT_DATA    =   24'h5389_10;	 
185:     LUT_DATA    =   24'h538a_01;	 
186:     LUT_DATA    =   24'h538b_98;	 

187:     LUT_DATA    =   24'h5580_06;	 
188:     LUT_DATA    =   24'h5583_40;		
189:     LUT_DATA    =   24'h5584_10;		
190:     LUT_DATA    =   24'h5589_10;		
191:     LUT_DATA    =   24'h558a_00;		
192:     LUT_DATA    =   24'h558b_f8;		
193:     LUT_DATA    =   24'h501d_40;	 

194:     LUT_DATA    =   24'h5300_08;	 
195:     LUT_DATA    =   24'h5301_30;	 
196:     LUT_DATA    =   24'h5302_10;	 
197:     LUT_DATA    =   24'h5303_00;	 
198:     LUT_DATA    =   24'h5304_08;	 
199:     LUT_DATA    =   24'h5305_30;	 
200:     LUT_DATA    =   24'h5306_08;	 
201:     LUT_DATA    =   24'h5307_16;	 
202:     LUT_DATA    =   24'h5309_08;	 
203:     LUT_DATA    =   24'h530a_30;	 
204:     LUT_DATA    =   24'h530b_04;	 
205:     LUT_DATA    =   24'h530c_06;	 
206:     LUT_DATA    =   24'h5025_00;		
207:     LUT_DATA    =   24'h3008_02;	 



208:     LUT_DATA    = 24'h3035_21;  
209:     LUT_DATA    = use_1080_clock ? 24'h3036_54 : 24'h3036_69;  
210:     LUT_DATA    = 24'h3c07_07;  
211:     LUT_DATA    = {16'h3820, IMAGE_FLIP};  
212:     LUT_DATA    = use_1080_geometry ? 24'h3821_06 :
                  {20'h38210, IMAGE_MIRROR};  
213:     LUT_DATA    = use_1080_geometry ? 24'h3814_11 : 24'h3814_31;  
214:     LUT_DATA    = use_1080_geometry ? 24'h3815_11 : 24'h3815_31;  
215:     LUT_DATA    = use_1080_geometry ? 24'h3800_01 : 24'h3800_00;  
216:     LUT_DATA    = use_1080_geometry ? 24'h3801_50 : 24'h3801_00;  
217:     LUT_DATA    = use_1080_geometry ? 24'h3802_01 : 24'h3802_00;  
218:     LUT_DATA    = use_1080_geometry ? 24'h3803_b2 : 24'h3803_fa;  
219:     LUT_DATA    = use_1080_geometry ? 24'h3804_08 : 24'h3804_0a;  
220:     LUT_DATA    = use_1080_geometry ? 24'h3805_ef : 24'h3805_3f;  
221:     LUT_DATA    = use_1080_geometry ? 24'h3806_05 : 24'h3806_06;  
222:     LUT_DATA    = use_1080_geometry ? 24'h3807_f1 : 24'h3807_a9;  
223:     LUT_DATA    = use_1080_geometry ? 24'h3808_07 : {16'h3808, IMAGE_WIDTH[15:8]};  
224:     LUT_DATA    = use_1080_geometry ? 24'h3809_80 : {16'h3809, IMAGE_WIDTH[ 7:0]};  
225:     LUT_DATA    = use_1080_geometry ? 24'h380a_04 : {16'h380a, IMAGE_HEIGHT[15:8]};  
226:     LUT_DATA    = use_1080_geometry ? 24'h380b_38 : {16'h380b, IMAGE_HEIGHT[ 7:0]};  
227:     LUT_DATA    = use_1080_geometry ? 24'h380c_09 : 24'h380c_07;  
228:     LUT_DATA    = use_1080_geometry ? 24'h380d_c4 : 24'h380d_64;  
229:     LUT_DATA    = use_1080_geometry ? 24'h380e_04 : 24'h380e_02;  
230:     LUT_DATA    = use_1080_geometry ? 24'h380f_60 : 24'h380f_e4;  
231:     LUT_DATA    = 24'h3813_04;  
232:     LUT_DATA    = use_1080_geometry ? 24'h3618_04 : 24'h3618_00;
233:     LUT_DATA    = use_1080_geometry ? 24'h3612_2b : 24'h3612_29;
234:     LUT_DATA    = use_1080_geometry ? 24'h3709_12 : 24'h3709_52;
235:     LUT_DATA    = use_1080_geometry ? 24'h370c_00 : 24'h370c_03;
236:     LUT_DATA    = use_1080_geometry ? 24'h3a02_04 : 24'h3a02_02;  
237:     LUT_DATA    = use_1080_geometry ? 24'h3a03_60 : 24'h3a03_e0;  
238:     LUT_DATA    = use_1080_geometry ? 24'h3a14_04 : 24'h3a14_02;  
239:     LUT_DATA    = use_1080_geometry ? 24'h3a15_60 : 24'h3a15_e0;  
240:     LUT_DATA    = use_1080_geometry ? 24'h4004_06 : 24'h4004_02;  
241:     LUT_DATA    = 24'h3002_1c;  
242:     LUT_DATA    = 24'h3006_c3;  
243:     LUT_DATA    = 24'h4713_03;  
244:     LUT_DATA    = 24'h4407_04;  
245:     LUT_DATA    = use_1080_clock ? 24'h460b_35 : 24'h460b_37;
246:     LUT_DATA    = use_1080_clock ? 24'h460c_22 : 24'h460c_20;
247:     LUT_DATA    = 24'h4837_16;  
248:     LUT_DATA    = use_1080_clock ? 24'h3824_02 : 24'h3824_04;  
249:     LUT_DATA    = manual_wb ? 24'h5001_82 : 24'h5001_83;  
250:     LUT_DATA    = 24'h3503_00;  
251:     LUT_DATA    = 24'h4740_21;  
	default:LUT_DATA	=	{16'h0000, 8'h0000};
	endcase
end

endmodule




