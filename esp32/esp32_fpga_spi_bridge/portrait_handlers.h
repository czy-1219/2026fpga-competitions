#pragma once
static bool portraitActive=false,portraitResumeAfter=false;
static uint32_t portraitInputCrc=0;
static bool portraitLoading=false,portraitLoadFailed=false;
static size_t portraitSent=0;
static uint32_t portraitLoadSince=0;
static String portraitPendingBody;
static uint8_t portraitAlpha[4096];
static size_t portraitFetched=0;
static bool portraitResultCached=false;
uint32_t portraitReadCrc(){uint32_t c=0;for(uint8_t k=0;k<4;k++)c|=uint32_t(fpgaRead(0x5c+k))<<(8*k);return c;}
void portraitRelease(){portraitLoading=false;portraitPendingBody="";portraitActive=false;httpCaptureBusy=false;if(portraitResumeAfter){fpgaWrite(REG_CONTROL,0x02);portraitResumeAfter=false;}}
// Advance at most 64 bytes / 3 ms per loop; never wait for DDR in an HTTP handler.
void servicePortraitLoad(){
  if(!portraitLoading)return;
  if(uint32_t(millis()-portraitLoadSince)>=120000){portraitLoadFailed=true;portraitRelease();return;}
  const uint32_t slice=millis();
  for(unsigned n=0;n<64 && uint32_t(millis()-slice)<3;n++){
    const uint8_t s=fpgaRead(0x51);
    if(s&8){portraitLoadFailed=true;portraitRelease();return;}
    if(portraitSent<49152){
      if(!(s&1))return;
      studentWrite(0x52,static_cast<uint8_t>(portraitPendingBody[portraitSent++]));
    }else{
      if(!(s&0x20))return;
      if(fpgaRead16(0x53)!=49152 || portraitReadCrc()!=portraitInputCrc){portraitLoadFailed=true;portraitRelease();return;}
      studentWrite(0x50,2);portraitLoading=false;portraitPendingBody="";return;
    }
  }
}
void handlePortraitStatus(){
  const bool supported=fpgaRead(0x50)==0x70;const uint8_t s=supported?fpgaRead(0x51):0;
   
  if(portraitActive && (s&0x0c)==0x0c && !(s&2))portraitRelease();
  String text="{\"available\":";text+=supported?"true":"false";text+=",\"busy\":";text+=(portraitLoading||(s&2))?"true":"false";
  text+=",\"done\":";text+=(!portraitLoading&&(s&4))?"true":"false";text+=",\"error\":";text+=(portraitLoadFailed||(s&8))?"true":"false";
  text+=",\"has_task\":";text+=(portraitActive||portraitResultCached)?"true":"false";
  text+=",\"loading\":";text+=portraitLoading?"true":"false";text+=",\"loaded_bytes\":";text+=portraitSent;
  text+=",\"stage\":";text+=supported?fpgaRead(0x55):0;text+="}";http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",text);
}
void handlePortraitLoad(){
  refreshFrameJobLock();
  if(fpgaRead(0x50)!=0x70){http.send(503,"text/plain","当前FPGA不支持人像，请烧录联合版位流");return;}
  if(httpCaptureBusy||httpUploadBusy||portraitActive||(fpgaRead(0x51)&2)){http.send(409,"text/plain","已有图像任务正在运行，请先读取上一任务结果");return;}
  if((fpgaRead(REG_STATUS)&0x0c)!=0x0c){http.send(503,"text/plain","DDR尚未校准完成，请等待板卡启动");return;}
  if(!modelBodyReady())return;const String &body=modelRawBody;if(body.length()!=49152){http.send(400,"text/plain; charset=utf-8","人像输入长度错误，应为49152字节");return;}
  portraitLoadFailed=false;portraitActive=true;httpCaptureBusy=true;portraitResumeAfter=false;portraitFetched=0;portraitResultCached=false;
  const uint8_t camera=fpgaRead(REG_STATUS);
  if((camera&0x10)&&!(camera&STATUS_FROZEN)){
    portraitResumeAfter=true;fpgaWrite(REG_CONTROL,0x01);
    if(!waitForStatus(STATUS_FROZEN,true,FREEZE_TIMEOUT_MS)||!waitForStatus(STATUS_FRAME_READY,true,FREEZE_TIMEOUT_MS)){
      portraitRelease();http.send(504,"text/plain","摄像头冻结超时：请先恢复或切720p重试");return;
    }
  }
  studentWrite(0x50,1);
  if(fpgaRead16(0x53)!=0){portraitRelease();http.send(503,"text/plain; charset=utf-8",String("人像装载器未接受新输入，status=0x")+String(fpgaRead(0x51),HEX)+"；请先读取上一任务结果");return;}
  const uint32_t expected=studentCrc(reinterpret_cast<const uint8_t*>(body.c_str()),49152);
  portraitInputCrc=expected;
  portraitPendingBody=static_cast<String&&>(modelRawBody);modelRawComplete=false;
  portraitSent=0;portraitLoadSince=millis();portraitLoading=true;
  char reply[64];snprintf(reply,sizeof(reply),"{\"started\":true,\"input_crc\":\"%08lx\"}",static_cast<unsigned long>(expected));
  http.sendHeader("Cache-Control","no-store");http.send(202,"application/json",reply);
}
void handlePortraitResult(){
  if(fpgaRead(0x50)!=0x70){http.send(503,"text/plain","当前FPGA不支持人像，请烧录联合版位流");return;}
  if(portraitLoading){http.send(409,"text/plain","portrait input loading; retry shortly");return;}
  uint8_t s=fpgaRead(0x51);
  if(s&8){portraitRelease();http.send(502,"text/plain","FPGA人像任务失败，请重新处理");return;}
  if(!(s&4)||(s&2)){http.send(409,"text/plain","人像仍在计算，请等待完成后再读取");return;}
  if(!portraitActive&&!portraitResultCached){http.send(409,"text/plain","ESP32任务记录已丢失，请重新处理");return;}
  if(httpUploadBusy){http.send(409,"text/plain","upload busy");return;}
  const uint32_t deadline=millis()+30000;
  for(size_t index=portraitFetched;index<4096;index++){
    for(;;){s=fpgaRead(0x51);if(s&8){portraitRelease();http.send(502,"text/plain","人像DDR读取失败");return;}if(s&0x10)break;if(int32_t(millis()-deadline)>=0){http.send(504,"text/plain","人像回传超时，请保留原图并继续读取");return;}delay(1);}
    if(fpgaRead16(0x58)!=index){http.send(502,"text/plain","人像结果顺序错误，请重新处理");portraitRelease();return;}
    if((index&31)==0)delay(1);
    portraitAlpha[index]=fpgaRead(0x56);studentWrite(0x57,1);portraitFetched=index+1;
  }
  if(fpgaRead16(0x58)!=4096||portraitReadCrc()!=studentCrc(portraitAlpha,4096)){portraitRelease();http.send(502,"text/plain","人像结果CRC或长度错误，请重新处理");return;}
  portraitResultCached=true;
  char crc[9],input[9];snprintf(crc,sizeof(crc),"%08lx",static_cast<unsigned long>(portraitReadCrc()));snprintf(input,sizeof(input),"%08lx",static_cast<unsigned long>(portraitInputCrc));
  http.sendHeader("X-Portrait-CRC32",crc);http.sendHeader("X-Portrait-Input-CRC32",input);http.sendHeader("Cache-Control","no-store");
  http.send_P(200,"application/octet-stream",reinterpret_cast<const char*>(portraitAlpha),4096);portraitRelease();
}
