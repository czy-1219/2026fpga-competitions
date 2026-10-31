#pragma once
#include "shared_model_metadata.h"
 

static bool fullLoadOwned=false,fullLoadReceiving=false,fullLoadComplete=false;
static uint32_t fullLoadExpected=0,fullLoadForwarded=0;
static String fullLoadError;
uint32_t fullRead32(uint8_t reg){
  for(int attempt=0;attempt<4;attempt++){
    uint32_t a=0,b=0;for(int i=3;i>=0;i--)a=(a<<8)|fpgaRead(reg+i);
    for(int i=3;i>=0;i--)b=(b<<8)|fpgaRead(reg+i);
    if(a==b)return a;
  }return 0;
}
// Hardware snapshot freezes all 64 bits before byte-wise SPI reads.
uint64_t frameReadCycles(bool task){
 fpgaWrite(0x7b,task?1:0);fpgaWrite(0x7a,0);uint32_t lo=fullRead32(0x7a);
 fpgaWrite(0x7a,1);uint32_t hi=fullRead32(0x7a);fpgaWrite(0x7a,0);fpgaWrite(0x7c,0);
 return (uint64_t(hi)<<32)|lo;
}
String frameTimingJson(){
 if(fpgaRead(0x4f)!=0x82)return "null";
 char buf[192];const uint64_t model=frameReadCycles(false),task=frameReadCycles(true);
 snprintf(buf,sizeof(buf),"{\"model_cycles\":\"%llu\",\"frame_cycles\":\"%llu\",\"clock_hz\":96000000,\"source\":\"fpga_counter\"}",(unsigned long long)model,(unsigned long long)task);
 return String(buf);
}
void refreshFullModelLock(){
  if(!fullLoadOwned||fullLoadReceiving)return;
  if(fpgaRead(0x7e)!=FULL_RUNTIME_ID)return;
  uint8_t a=fpgaRead(0x66),b=fpgaRead(0x66);
  if(a==b&&!(b&1)){fullLoadOwned=false;httpCaptureBusy=false;}
}
void handleFullModelStatus(){
  refreshFullModelLock();const bool available=fpgaRead(0x7e)==FULL_RUNTIME_ID;
  const uint8_t s=available?fpgaRead(0x66):0;
  const uint8_t profile=available?((fpgaRead(0x65)>>2)&3):3;
  String r="{\"available\":";r+=available?"true":"false";
  r+=",\"busy\":";r+=(s&1)?"true":"false";r+=",\"done\":";r+=(s&2)?"true":"false";
  r+=",\"weights_ready\":";r+=(s&8)?"true":"false";r+=",\"program_ready\":";r+=(s&16)?"true":"false";
  r+=",\"profile\":";r+=profile==2?"\"local\"":profile==1?"1080":profile==0?"720":"null";
  r+=",\"size_code\":";r+=profile;r+=",\"width\":";r+=profile<3?taskWidth(profile):0;r+=",\"height\":";r+=profile<3?taskHeight(profile):0;
  r+=",\"error\":";r+=available?fpgaRead(0x67):255;
  r+=",\"bytes_done\":";r+=available?fullRead32(0x72):0;r+=",\"command\":";r+=available?fullRead32(0x76):0;
  r+=",\"boot\":";r+=bootModelStatus();r+="}";
  http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",r);
}
static bool fullWaitCredit(){
  const uint32_t begin=millis();
  while(millis()-begin<6000){
    uint8_t s=fpgaRead(0x66);if(!(s&1)||(s&0x84)){fullLoadError="FPGA装载失败，错误码="+String(fpgaRead(0x67));return false;}
    if(fpgaRead(0x71)>=16)return true;delay(1);
  }fullLoadError="模型装载流控超时";return false;
}
void receiveFullModel(){
  HTTPRaw &raw=http.raw();
  if(raw.status==RAW_START){
    refreshFrameJobLock();fullLoadReceiving=false;fullLoadComplete=false;fullLoadError="";fullLoadForwarded=0;
    if(httpCaptureBusy||httpUploadBusy||(fpgaRead(0x4d)&1)){fullLoadError="已有任务运行，请等待完成";return;}
    if(fpgaRead(0x7e)!=FULL_RUNTIME_ID){fullLoadError="需要配套的共享模型FPGA位流";return;}
    const String kind=http.arg("kind"),profile=http.arg("profile");
    if((kind!="weights"&&kind!="program")||(profile!="720"&&profile!="1080"&&profile!="local")){fullLoadError="模型类型或分辨率错误";return;}
    const bool program=kind=="program";const uint8_t hd=profile=="local"?2:profile=="1080"?1:0;
    const uint32_t bytes=program?SHARED_PROGRAM_BYTES[hd]:SHARED_MODEL_BYTES;
    const uint32_t crc=program?SHARED_PROGRAM_CRC[hd]:SHARED_MODEL_CRC;
    if(http.arg("size")!=String(bytes)||http.arg("crc")!=String(crc)){fullLoadError="模型包与本版工程不匹配";return;}
    if((fpgaRead(REG_STATUS)&0x0c)!=0x0c){fullLoadError="DDR未校准";return;}
    invalidateTaskInput();
    fullLoadExpected=bytes;fullLoadOwned=true;fullLoadReceiving=true;httpCaptureBusy=true;
    for(uint8_t i=0;i<4;i++){fpgaWrite(0x68+i,bytes>>(8*i));fpgaWrite(0x6c+i,crc>>(8*i));}
    fpgaWrite(0x65,1|(program?2:0)|(hd<<2));delay(1);
    uint8_t s=fpgaRead(0x66);
    if(!(s&1)||(s&0x84)){fullLoadError="FPGA拒绝装载，错误码="+String(fpgaRead(0x67));fullLoadReceiving=false;refreshFullModelLock();}
    Serial.printf("[FULL_MODEL] START kind=%s bytes=%lu profile=%s\n",kind.c_str(),(unsigned long)bytes,profile.c_str());
  }
  if(raw.status==RAW_WRITE&&fullLoadError.length()==0){
    if(raw.currentSize>HTTP_RAW_BUFLEN||raw.currentSize>fullLoadExpected-fullLoadForwarded){fullLoadError="模型长度越界";return;}
    for(size_t i=0;i<raw.currentSize;i++){
      if((fullLoadForwarded&15)==0&&!fullWaitCredit())break;
      fpgaWrite(0x70,raw.buf[i]);fullLoadForwarded++;
      if((fullLoadForwarded&255)==0)yield();
    }
  }
  if(raw.status==RAW_END){
    fullLoadReceiving=false;
    if(fullLoadError.length()==0&&fullLoadForwarded==fullLoadExpected&&raw.totalSize==fullLoadExpected){
      const uint32_t start=millis();uint8_t s;
      do{s=fpgaRead(0x66);if(!(s&1))break;delay(2);}while(millis()-start<60000);
      fullLoadComplete=!(s&0x85)&&(s&2)&&fullRead32(0x72)==fullLoadExpected;
      if(!fullLoadComplete)fullLoadError="FPGA CRC/DDR回读校验失败，错误码="+String(fpgaRead(0x67));
    }else if(fullLoadError.length()==0)fullLoadError="模型未传完整";
    refreshFullModelLock();
    Serial.printf("[FULL_MODEL] END forwarded=%lu ok=%u error=%s\n",(unsigned long)fullLoadForwarded,fullLoadComplete,fullLoadError.c_str());
  }
  if(raw.status==RAW_ABORTED){fullLoadReceiving=false;fullLoadComplete=false;fullLoadError="上传中断；FPGA会使不完整模型失效，请重新装载";refreshFullModelLock();}
}
void handleFullModelLoad(){
  refreshFullModelLock();http.sendHeader("Cache-Control","no-store");
  if(!fullLoadComplete){http.send(422,"text/plain; charset=utf-8",fullLoadError.length()?fullLoadError:"模型未接收完整");return;}
  http.send(200,"application/json","{\"loaded\":true,\"verified\":true}");
}
static const char FULL_MODEL_PAGE[] PROGMEM=R"FM(<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>共享模型装载</title><style>body{max-width:720px;margin:24px auto;padding:16px;font:17px sans-serif;line-height:1.7}button,select,input{padding:10px;margin:8px 0}progress{width:100%}pre{white-space:pre-wrap}</style><h1>共享三输出模型</h1><p>配套Flash包会在上电后自动装载权重和尺寸程序，模型仍在FPGA内执行。本页保留手动恢复入口。启动状态可查看 /api/boot-model/status。</p><p>请选择工程 runtime 文件夹中的 weights.payload.bin，以及所需尺寸的 program_1024x600.bin、program_1920x1080.bin 或 program_256x224.bin。</p><input id="files" type="file" multiple accept=".bin"><br><select id="profile"><option value="720">1024×600</option><option value="1080">1920×1080</option><option value="local">局部256×224</option></select><br><button id="load">装载权重和程序</button> <button id="program">只切换尺寸程序</button><progress id="progress" max="100" value="0"></progress><pre id="status">等待选择文件</pre><p>装载期间请保持热点连接。处理单张图片可能持续较长时间，可在图像处理页查询进度。正确烧录FPGA Flash完整镜像和配套ESP32固件后，断电重启会自动装载；手动上传的数据仅保存在DDR。</p><a href="/student">返回图像处理</a><script>
const $=id=>document.getElementById(id),sizes={"weights":[308496,3388694345],"720":[117888,3237296641],"1080":[366720,1988155149],"local":[19456,3748291448]};
function crc32(a){let c=0xffffffff;for(const v of a){c^=v;for(let j=0;j<8;j++)c=(c>>>1)^((c&1)?0xedb88320:0)}return (~c)>>>0}
async function send(kind,profile){const name=kind==='weights'?'weights.payload.bin':profile==='local'?'program_256x224.bin':profile==='1080'?'program_1920x1080.bin':'program_1024x600.bin',f=Array.from($('files').files).find(x=>x.name===name);if(!f)throw Error('未选择 '+name);const [n,c]=sizes[kind==='weights'?'weights':profile];if(f.size!==n)throw Error(name+' 长度不匹配');$('status').textContent='检查 '+name;const b=await f.arrayBuffer();if(crc32(new Uint8Array(b))!==c)throw Error(name+' 校验不匹配');await new Promise((resolve,reject)=>{const x=new XMLHttpRequest();x.open('POST','/api/full-model/load?'+new URLSearchParams({kind,profile,size:String(n),crc:String(c)}));x.timeout=1800000;x.setRequestHeader('Content-Type','application/octet-stream');x.upload.onprogress=e=>{$('progress').value=e.lengthComputable?e.loaded/e.total*100:0;$('status').textContent='装载 '+name+' '+Math.floor($('progress').value)+'%'};x.upload.onload=()=>{$('status').textContent='等待FPGA完成CRC和DDR回读校验'};x.onload=()=>x.status===200?resolve():reject(Error(x.responseText));x.onerror=()=>reject(Error('网络中断，请重新装载'));x.ontimeout=()=>reject(Error('装载超时'));x.send(b)});}
async function run(weights){$('load').disabled=$('program').disabled=true;try{const p=$('profile').value;if(weights)await send('weights',p);await send('program',p);const s=await (await fetch('/api/full-model/status',{cache:'no-store'})).json();if(!s.weights_ready||!s.program_ready)throw Error('模型尚未就绪');$('status').textContent='装载和校验完成，可以返回图像处理页';$('progress').value=100}catch(e){$('status').textContent=e.message}finally{$('load').disabled=$('program').disabled=false}}
$('load').onclick=()=>run(true);$('program').onclick=()=>run(false);
</script></html>)FM";
