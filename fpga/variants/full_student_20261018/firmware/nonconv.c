// Exact integer non-convolution command interpreter, executed INSIDE the FPGA.
// No floating point, host inference, image resize approximation or model change.
typedef unsigned int u32; typedef signed int i32;
typedef unsigned long long u64; typedef signed long long i64;
typedef signed short i16;
#define REG(n) (*(volatile u32 *)(0x10000u+(n)*4u))
static u32 cmd[32];
static u32 outputs,clips,failed;
#include "exp_table.h"
static u64 magnitude(i64 a){return a<0 ? 0-(u64)a : (u64)a;}
static i64 rnd(i64 a,u64 d){
 if(!d){failed=1;return 0;} u64 m=magnitude(a),q,r;
 // Scale conversions dominate the graph. Avoid software 64-bit division
 // for powers of two without changing nearest-even rounding.
 if(!(d&(d-1))){unsigned s=d==65536?16:__builtin_ctzll(d);q=m>>s;r=m&(d-1);}
 else {q=m/d;r=m%d;}
 q+=(r>d-r || (r==d-r && (q&1))); return a<0 ? (i64)(0-q):(i64)q;
}
static i32 sat32(i64 a){if(a>2147483647LL){clips++;return 2147483647;}if(a< -2147483648LL){clips++;return (-2147483647-1);}return a;}
static i16 sat16(i64 a){if(a>32767){clips++;return 32767;}if(a< -32768){clips++;return -32768;}return a;}
static i64 scale(i64 a,int s){return s>=0 ? (i64)((u64)a<<s):rnd(a,1ULL<<-s);}
static i32 scalar(u32 op,i32 a,i32 b,i32 c){
 i64 v=0;u64 aa=a<0 ? 0u-(u32)a:(u32)a;
 switch(op){
 case 0:v=(i64)a+b;break;case 1:v=(i64)a-b;break;
 case 2:v=rnd((i64)a*b,65536);break;
 case 3:v=rnd((i64)a*65536,b<0 ? 0u-(u32)b:(u32)b);if(b<0)v=-v;break;
 case 4:v=a<b?a:b;break;case 5:v=a>b?a:b;break;
 case 6:v=aa;break;case 7:v=-(i64)a;break;
 case 8:if(b>c)failed=1;v=a<b?b:a>c?c:a;break;
 case 9:case 10:case 11:case 12:{
  u32 x=op==12 ? (a>=0?0:aa):op==10 ? (aa>=524288?1048576:aa*2):aa;
  u32 e=0;
  if(x<1048576){u32 i=x>>12; e=exp_table[i]-(((u64)(exp_table[i]-exp_table[i+1])*(x&4095)+2048)>>12);}
  if(op==12)v=rnd(e,16);
  else if(op==10){v=rnd((i64)(1048576-e)*65536,1048576+e);if(a<0)v=-v;}
  else {v=rnd((i64)(a<0?e:1048576)*65536,1048576+e);if(op==11)v=rnd((i64)a*v,65536);}
  break;
 }
 case 13:v=a>b?65536:0;break;case 14:v=a>=b?65536:0;break;
 case 15:v=a>=0?b:c;break;case 16:v=a&~65535;break;
 case 17:v=rnd(a,65536)*65536;break;case 18:v=a?b:c;break;
 case 19:v=a<=0?0:b<=0 || a>=b?65536:rnd((i64)a*65536,b);break;
 case 20:case 21:
  if(b<0 || b>2031616 || (b&65535)){failed=1;break;}
  v=op==20 ? ((i64)(a>>16)>>(b>>16))*65536 : (i64)((u64)(i64)(a>>16)<<(b>>16))*65536;break;
 case 22:v=(i64)((a>>16)|(b>>16))*65536;break;
 default:failed=1;
 }
 return sat32(v);
}
static i16 get(u32 a){return *(volatile i16 *)a;}
static void put(u32 a,i64 v){*(volatile i16 *)a=sat16(v);outputs++;}
static u32 lo(u32 a){return a&65535;}static u32 hi(u32 a){return a>>16;}
static int clamp(int a,int n){return a<0?0:a>=n?n-1:a;}
static int invalid(u32 begin,u32 end){for(u32 j=begin;j<=end;j++)if(cmd[j]&1)return 1;return 0;}
// Exact sliding mean for the already separable, unpadded filters in the
// deployed joint graph. The first window is summed once; each subsequent
// window removes its outgoing sample and adds its incoming sample.
// With at most 255 INT16 samples the signed sum fits INT32. Hardware DIVU
// plus a multiply supplies quotient/remainder without a software INT64
// division. Round-to-nearest-even is identical to rnd(), including negatives.
static int sliding_mean(void){
 u32 iw=lo(cmd[1]),ih=hi(cmd[1]),w=lo(cmd[2]),h=hi(cmd[2]),nc=lo(cmd[3]);
 u32 kw=lo(cmd[4]),kh=hi(cmd[4]),n=kw>kh?kw:kh;
 if(cmd[0]!=1 || cmd[5]!=1 || cmd[6]!=0x10001 || cmd[7] ||
    (kw!=1 && kh!=1) || !n || n>255 || (cmd[17]&255)>24 || (cmd[17]&255)!=((cmd[17]>>8)&255) ||
    !w || !h || !nc || iw<w+kw-1 || ih<h+kh-1 || invalid(8,16))return 0;
 // Only canonical, non-aliasing output layouts may change traversal order.
 if(cmd[14]!=(u64)nc*2 || cmd[15]!=(u64)w*nc*2 || cmd[16]!=2)return 0;
 // Bound the address arithmetic and exclude overlapping input/output, since
 // sliding traversal may visit output pixels in a different order.
 for(u32 i=9;i<=12;i++)if(cmd[i]>65535)return 0;
 for(u32 i=14;i<=16;i++)if(cmd[i]>65535)return 0;
 u64 ib=cmd[8],ie=ib+(u64)(iw-1)*cmd[9]+(u64)(ih-1)*cmd[10]+(u64)(nc-1)*cmd[12]+2;
 u64 ob=cmd[13],oe=ob+(u64)(w-1)*cmd[14]+(u64)(h-1)*cmd[15]+(u64)(nc-1)*cmd[16]+2;
 if(ie>0xffffffffu || oe>0xffffffffu || !(ie<=ob || oe<=ib))return 0;
 u32 vertical=kw==1,lines=vertical?w:h,length=vertical?h:w;
 u32 step=cmd[vertical?10:9],lineStep=cmd[vertical?9:10];
 u32 outStep=cmd[vertical?15:14],outLine=cmd[vertical?14:15];
 for(u32 line=0;line<lines;line++)for(u32 c=0;c<nc;c++){
  u32 a=cmd[8]+line*lineStep+c*cmd[12],out=cmd[13]+line*outLine+c*cmd[16];
  i32 sum=0;for(u32 k=0;k<n;k++)sum+=get(a+k*step);
  u32 incoming=a+n*step;
  for(u32 pos=0;pos<length;pos++){
   u32 m=sum<0?0u-(u32)sum:(u32)sum,q=m/n,r=m-q*n;
   q+=(r>n-r || (r==n-r && (q&1)));
   *(volatile i16*)out=(i16)(sum<0?-(i32)q:(i32)q);outputs++;
   if(pos+1<length){sum-=get(a);sum+=get(incoming);a+=step;incoming+=step;out+=outStep;}
  }
 }
 return 1;
}
static void vector(void){
 u32 w=lo(cmd[1]),h=hi(cmd[1]),nc=lo(cmd[2]),fo=(cmd[2]>>16)&255;
 if(!w||!h||!nc||fo>24||(cmd[3]&1)){failed=1;return;}
 for(u32 j=0;j<3;j++)if(!(cmd[13+7*j]&1) && (cmd[11+7*j]>24 || (cmd[7+7*j]&1))){failed=1;return;}
 for(u32 y=0;y<h;y++)for(u32 x=0;x<w;x++)for(u32 c=0;c<nc;c++){
  i32 v[3];for(u32 j=0;j<3;j++){u32 z=7+7*j;v[j]=(cmd[z+6]&1)?(i32)cmd[z+5]:scale(get(cmd[z]+x*cmd[z+1]+y*cmd[z+2]+c*cmd[z+3]),16-(int)cmd[z+4]);}
  i32 a=scalar(cmd[0]&31,v[0],v[1],v[2]);
  if(failed)return;put(cmd[3]+x*cmd[4]+y*cmd[5]+c*cmd[6],scale(a,(int)fo-16));
 }
}
static void reduce(void){
 if(sliding_mean())return;
 int iw=lo(cmd[1]),ih=hi(cmd[1]),w=lo(cmd[2]),h=hi(cmd[2]),nc=lo(cmd[3]);
 int kw=lo(cmd[4]),kh=hi(cmd[4]),kc=lo(cmd[5]),sx=lo(cmd[6]),sy=hi(cmd[6]),px=lo(cmd[7]),py=hi(cmd[7]);
 int fi=cmd[17]&255,fo=(cmd[17]>>8)&255;u32 op=cmd[0]&3,rep=cmd[0]&256,inc=cmd[0]&512;
 if(!iw||!ih||!w||!h||!nc||!kw||!kh||!kc||fi>24||fo>24||invalid(8,16)){failed=1;return;}
 for(int y=0;y<h;y++)for(int x=0;x<w;x++)for(int c=0;c<nc;c++){
  i64 sum=0;int extreme=op==3?32767:-32768;u32 count=0;
  for(int ky=0;ky<kh;ky++)for(int kx=0;kx<kw;kx++)for(int cc=0;cc<kc;cc++){
   int xx=x*sx-px+kx,yy=y*sy-py+ky,inside=xx>=0&&xx<iw&&yy>=0&&yy<ih;
   if(inside||rep){int v=get(cmd[8]+c*cmd[12]+clamp(xx,iw)*cmd[9]+clamp(yy,ih)*cmd[10]+cc*cmd[11]);
    i64 next=(i64)((u64)sum+(i64)v);if((sum<0)==(v<0) && (next<0)!=(sum<0)){failed=1;return;}sum=next;
    if(op==2 && v>extreme || op==3 && v<extreme)extreme=v;
   }
   if(inside||rep||inc){if(count==0xffffffffu){failed=1;return;}count++;}
  }
  i64 v=op>=2?extreme:sum;u64 den=op==1?count:1;
  if(fo>fi){i64 nv=(i64)((u64)v<<(fo-fi));if((nv>>(fo-fi))!=v){failed=1;return;}v=nv;}else den<<=fi-fo;
  v=rnd(v,den);if(failed)return;put(cmd[13]+x*cmd[14]+y*cmd[15]+c*cmd[16],v);
 }
}
static void transform(void){
 int iw=lo(cmd[1]),ih=hi(cmd[1]),w=lo(cmd[2]),h=hi(cmd[2]),nc=lo(cmd[3]);
 int fi=cmd[12]&255,fo=(cmd[12]>>8)&255,op=cmd[0]&7,sc=(cmd[0]>>16)&7,down=cmd[0]&256,rep=cmd[0]&512;
 // Shared graph uses direct align_corners=false x8/x32 interpolation.
 // Composed x2 resizes would change the trained model's interpolation kernel.
 if(!iw||!ih||!w||!h||!nc||fi>24||fo>24||op>3||invalid(4,11)||(op==1&&(sc<1||sc>5))){failed=1;return;}
 for(int y=0;y<h;y++)for(int x=0;x<w;x++)for(int c=0;c<nc;c++){
  int xx=x-(i32)cmd[13],yy=y-(i32)cmd[14],cc=c,fx=0,fy=0,den=1,ds=0;
  if(op==1){if(down){xx=(x<<sc)+(1<<(sc-1))-1;yy=(y<<sc)+(1<<(sc-1))-1;fx=fy=1;den=2;ds=1;}
   else {int tx=2*x+1-(1<<sc),ty=2*y+1-(1<<sc);ds=sc+1;den=1<<ds;xx=tx>>ds;yy=ty>>ds;fx=tx&(den-1);fy=ty&(den-1);}}
  else if(op==2){xx=x>>1;yy=y>>1;cc=c*4+(y&1)*2+(x&1);}
  else if(op==3){xx=x*2+(c&1);yy=y*2+((c>>1)&1);cc=c>>2;}
  i64 sum=0;
  for(int t=0;t<(op==1?4:1);t++){
   int cx=xx+(op==1?(t&1):0),cy=yy+(op==1?(t>>1):0);int inside=cx>=0&&cx<iw&&cy>=0&&cy<ih;
   if(!inside && op>=2){failed=1;return;}
   if(inside||op==1||rep){int v=get(cmd[4]+clamp(cx,iw)*cmd[5]+clamp(cy,ih)*cmd[6]+cc*cmd[7]);
    int weight=op==1?((t&1)?fx:den-fx)*((t&2)?fy:den-fy):1;sum+=(i64)v*weight;}
  }
  put(cmd[8]+x*cmd[9]+y*cmd[10]+c*cmd[11],scale(sum,fo-fi-2*ds));
 }
}
void main(void){
 outputs=clips=failed=0;
 for(u32 i=0;i<32;i++)cmd[i]=((const volatile u32 *)0x10100u)[i];
 switch(cmd[31]&255){case 2:vector();break;case 3:reduce();break;case 4:transform();break;default:failed=1;}
 REG(1)=outputs;REG(2)=clips;REG(0)=failed?3:1;for(;;)__asm__ volatile("nop");
}
