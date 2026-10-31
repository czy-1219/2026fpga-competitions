#pragma once
 
static uint8_t bootHeader[128];
static String bootError;
static uint8_t bootStage=0;
static uint32_t bootSince=0,bootOffset=0;
static bool bootAttempted=false,bootProgramBusy=false,bootHeaderValid=false;
static uint32_t bootSent=0,bootProgressAt=0;
static uint16_t bootHeaderBytes=0;
static uint8_t bootHeaderAttempt=0;
static uint32_t bootWord(size_t offset){
  return uint32_t(bootHeader[offset])|(uint32_t(bootHeader[offset+1])<<8)|(uint32_t(bootHeader[offset+2])<<16)|(uint32_t(bootHeader[offset+3])<<24);
}
static uint32_t bootCrc(const uint8_t *data,size_t bytes){
  uint32_t c=0xffffffff;
  for(size_t i=0;i<bytes;i++){c^=data[i];for(int bit=0;bit<8;bit++)c=(c>>1)^((c&1)?0xedb88320u:0);}
  return ~c;
}
static void bootWrite(uint8_t address,uint8_t value){fpgaTransfer(address,value);}
static bool bootStopReader(){
  bootWrite(0x3d,0);const uint32_t began=millis();
  while(fpgaRead(0x3f)&1){if(millis()-began>250)return false;delay(1);}return true;
}
static bool bootStartReader(uint32_t address,bool direct){
  if(address<0x140000u||address>=0x800000u||!bootStopReader())return false;
  bootWrite(0x3a,address);bootWrite(0x3b,address>>8);bootWrite(0x3c,address>>16);bootWrite(0x3d,direct?2:1);
  return (fpgaRead(0x3f)&9)==1;
}
static bool bootFetchHeader(){
  bootHeaderBytes=0;memset(bootHeader,0,sizeof(bootHeader));
  if(!bootStartReader(0x140000,false)){bootError="header reader start failed";return false;}
  const uint32_t began=millis();
  for(size_t i=0;i<sizeof(bootHeader);i++){
    uint8_t s;
    do{s=fpgaRead(0x3f);if((s&8)||millis()-began>3000){bootError=(s&8)?"header Flash address rejected":"header byte wait timed out";bootStopReader();return false;}yield();}while(!(s&4));
    bootHeader[i]=fpgaRead(0x3e);bootWrite(0x3e,0);
    bootHeaderBytes=i+1;
  }
  if(!bootStopReader()){bootError="header reader stop timed out";return false;}
  if(memcmp(bootHeader,"T60SHR20",8)){bootError="header magic mismatch";return false;}
  if(bootWord(8)!=2){bootError="header version mismatch";return false;}
  if(bootCrc(bootHeader,124)!=bootWord(124)){bootError="header CRC mismatch";return false;}
  uint32_t previousEnd=0x141000u;
  for(size_t i=0;i<4;i++){
    const size_t p=16+i*12;const uint32_t address=bootWord(p),bytes=bootWord(p+4),crc=bootWord(p+8);
    const uint32_t expectedBytes=i?SHARED_PROGRAM_BYTES[i-1]:SHARED_MODEL_BYTES;
    const uint32_t expectedCrc=i?SHARED_PROGRAM_CRC[i-1]:SHARED_MODEL_CRC;
    if(address<previousEnd||(address&15)||address>=0x800000u||bytes>0x800000u-address){bootError="header entry bounds invalid";return false;}
    if(bytes!=expectedBytes){bootError="header entry length differs from firmware";return false;}
    if(crc!=expectedCrc){bootError="header entry CRC differs from firmware";return false;}
    previousEnd=address+bytes;
  }
  bootError="";return true;
}
bool bootModelBusy(){return bootProgramBusy||(bootAttempted&&bootStage<4);}
String bootModelStatus(){
  String s="{\"stage\":";s+=bootStage;s+=",\"busy\":";s+=bootModelBusy()?"true":"false";
  s+=",\"bytes_sent\":";s+=bootSent;s+=",\"ddr_bytes_done\":";s+=bootOffset;
  s+=",\"transport\":\"fpga_flash_direct_ordered\",\"loader_state\":";s+=fpgaRead(0x66);
  s+=",\"loader_error\":";s+=fpgaRead(0x67);s+=",\"flash_state\":";s+=fpgaRead(0x3f);
  s+=",\"boot_build\":\"dsp-tiles-1021\",\"header_attempt\":";s+=bootHeaderAttempt;
  s+=",\"header_bytes\":";s+=bootHeaderBytes;s+=",\"header_prefix\":\"";
  const char *hex="0123456789abcdef";
  for(uint8_t i=0;i<16;i++){char pair[3]={hex[bootHeader[i]>>4],hex[bootHeader[i]&15],0};s+=pair;}
  s+="\",\"header_crc_read\":";s+=bootWord(124);s+=",\"header_crc_computed\":";s+=bootCrc(bootHeader,124);
  s+=",\"header_entries\":[";
  for(uint8_t i=0;i<4;i++){if(i)s+=",";s+="[";s+=bootWord(16+i*12);s+=",";s+=bootWord(20+i*12);s+=",";s+=bootWord(24+i*12);s+="]";}s+="]";
  s+=",\"storage\":\"fpga_flash_only\",\"error\":\"";s+=bootError;s+="\"}";return s;
}
static void bootFail(const char *message){
  bootError=message;bootStage=5;bootStopReader();fullLoadReceiving=false;
  if(!fullLoadOwned)httpCaptureBusy=false;Serial.printf("[MODEL_BOOT] failed: %s\n",message);
}
static bool bootStartLoad(bool program,uint8_t hd){
  const uint32_t bytes=program?SHARED_PROGRAM_BYTES[hd]:SHARED_MODEL_BYTES;
  const uint32_t crc=program?SHARED_PROGRAM_CRC[hd]:SHARED_MODEL_CRC;
  if((fpgaRead(0x66)&1)||(fpgaRead(0x4d)&1))return false;
  fullLoadOwned=true;fullLoadReceiving=true;httpCaptureBusy=true;fullLoadError="";
  bootSent=0;bootOffset=0;bootProgressAt=millis();
  for(uint8_t i=0;i<4;i++){bootWrite(0x68+i,bytes>>(i*8));bootWrite(0x6c+i,crc>>(i*8));}
  bootWrite(0x65,1|(program?2:0)|(hd<<2));delay(2);return (fpgaRead(0x66)&0x85)==1;
}
static bool bootVerified(uint32_t bytes){
  const uint8_t s=fpgaRead(0x66);return !(s&0x85)&&(s&2)&&fullRead32(0x72)==bytes;
}
bool ensureBootProgram(uint8_t hd){
  const uint8_t state=fpgaRead(0x66);
  if((state&0x18)==0x18&&((fpgaRead(0x65)>>2)&3)==hd)return true;
  if(bootProgramBusy||httpCaptureBusy||httpUploadBusy||(state&1))return false;
  if(!bootHeaderValid){bootHeaderValid=bootFetchHeader();if(!bootHeaderValid)return false;}
  if(hd>2 || fpgaRead(0x4f)!=0x82)return false;
  bootProgramBusy=true;const size_t index=28+12*hd;
   


  bool ok=bootStartReader(bootWord(index),true)&&bootStartLoad(true,hd);const uint32_t began=millis();
  while(ok&&(fpgaRead(0x66)&1)){
    bootOffset=fullRead32(0x72);if(bootOffset>bootSent)bootSent=bootOffset;
    if(millis()-began>180000||(fpgaRead(0x3f)&8)){ok=false;break;}delay(1);
  }
   
  ok=bootStopReader()&&ok&&bootVerified(SHARED_PROGRAM_BYTES[hd]);
  if(ok){bootOffset=SHARED_PROGRAM_BYTES[hd];bootSent=bootOffset;}
  fullLoadReceiving=false;bootProgramBusy=false;refreshFullModelLock();
  bootError=ok?"":"program transfer/DDR verification failed";return ok;
}
void beginBootModel(){
  bootAttempted=true;bootSince=millis();bootStage=0;bootError="";bootOffset=0;bootHeaderValid=false;
}
void serviceBootModel(){
  if(!bootAttempted||bootStage>=4)return;
  if(millis()-bootSince>900000){bootFail("startup model load timeout");return;}
  if(bootStage==0){
    if(fpgaRead(0x7e)!=FULL_RUNTIME_ID||(fpgaRead(0x3f)&0xf0)!=0xb0){
      if(millis()-bootSince>15000)bootFail("paired FPGA runtime/Flash interface unavailable");return;
    }
    if((fpgaRead(REG_STATUS)&0x0c)!=0x0c)return;
     
    if((fpgaRead(0x66)&0x99)==0x18){bootStage=4;bootError="";recoverTask();return;}
    if(fpgaRead(0x4d)&1){bootError="FPGA task active; preserving DDR, no model reload";return;}
    bootHeaderValid=false;
    for(bootHeaderAttempt=1;bootHeaderAttempt<=3;bootHeaderAttempt++){
      if(bootFetchHeader()){bootHeaderValid=true;break;}
      if(bootHeaderAttempt<3)delay(20);
    }
    if(!bootHeaderValid){bootHeaderAttempt=3;bootFail(bootError.c_str());return;}
    if(!bootStartReader(bootWord(16),true)||!bootStartLoad(false,false)){bootFail("startup weight transfer rejected");return;}
    bootStage=1;return;
  }
  if(bootStage==1){
    bootOffset=fullRead32(0x72);
    bootSent=bootOffset;
    if(fpgaRead(0x66)&1)return;
    if(!bootStopReader()||!bootVerified(SHARED_MODEL_BYTES)){bootFail("weights CRC/DDR verification failed");return;}
    fullLoadReceiving=false;refreshFullModelLock();bootStage=2;
    if(!ensureBootProgram((fpgaRead(REG_RESOLUTION)&3)==1)){bootFail("startup program load failed");return;}
    bootStage=4;bootError="";Serial.println("[MODEL_BOOT] shared weights and program verified from FPGA Flash");
  }
}
