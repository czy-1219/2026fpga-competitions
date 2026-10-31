#pragma once
 


void refreshFrameJobLock(){
  refreshFullModelLock();
  if(!frameJobActive || httpUploadBusy || uploadSpiOpen)return;
  if(fpgaRead(REG_DEVICE_ID)!=0x60 || fpgaRead(0x60)!=0xd2)return;
  const uint8_t first=fpgaRead(0x4d),second=fpgaRead(0x4d);
  if(first!=second || (second&0xf0)!=0 || (second&1)!=0)return;
  if((second&2)!=0 || second==0){frameJobActive=false;httpCaptureBusy=false;}
}
String frameStatusJson(){
  refreshFrameJobLock();
  bool available=fpgaRead(0x60)==0xd2;
  uint8_t state=available?fpgaRead(0x4d):0,geometry=available?fpgaRead(0x4e):0;
  const uint8_t size=geometrySize(geometry);
  uint32_t pixels=0;
  if(available)for(int attempt=0;attempt<4;attempt++){
    uint8_t hi=fpgaRead(0x64),mi=fpgaRead(0x63),lo=fpgaRead(0x62);
    if(hi==fpgaRead(0x64)&&mi==fpgaRead(0x63)){pixels=(uint32_t(hi)<<16)|(uint32_t(mi)<<8)|lo;break;}
  }
  if(frameJobActive && !(state&1) && (state&2)){frameJobActive=false;httpCaptureBusy=false;}
  String reply="{\"available\":";reply+=available?"true":"false";
  reply+=",\"busy\":";reply+=(state&1)?"true":"false";
  const bool recoverable=matchingTask();
  reply+=",\"done\":";reply+=((state&2)&&recoverable)?"true":"false";
  reply+=",\"recoverable\":";reply+=recoverable?"true":"false";
  reply+=",\"error\":";reply+=(state&12)?"true":"false";
  reply+=",\"frame_state\":";reply+=state;
  reply+=",\"firmware\":\"SHARED-FPGA-V4-1024\"";
  const bool full=fpgaRead(0x7e)==FULL_RUNTIME_ID;
  const bool color=(fpgaRead(0x61)&3)==0;
  reply+=",\"full_color\":";reply+=(full&&color)?"true":"false";
  reply+=",\"full_model\":";reply+=full?"true":"false";
  reply+=",\"command\":";reply+=full?fullRead32(0x76):0;
  reply+=",\"commands_total\":";reply+=(fpgaRead(0x61)&4)?SHARED_COMMANDS[size]:SHARED_MODEL_COMMANDS[size];
  reply+=",\"model_error\":";reply+=full?fpgaRead(0x67):0;
  reply+=",\"content_status\":";reply+=full?fpgaRead(0x7f):0;
  const uint8_t outputMode=fpgaRead(0x61)&3;
  reply+=",\"output\":\"";reply+=outputMode==2?"binary":outputMode==1?"gray":"color";reply+="\"";
  reply+=",\"job_id\":";reply+=frameJobId;
  reply+=",\"request\":\"";reply+=taskRecord.request;reply+="\"";
  reply+=",\"boot_id\":";reply+=transportBootId;
  reply+=",\"cookie\":";reply+=fpgaTaskCookie();reply+=",\"recovered\":";reply+=taskRecovered?"true":"false";
  reply+=",\"source\":\"";reply+=(geometry&8)?"camera":"upload";reply+="\"";
  reply+=",\"pixels_done\":";reply+=pixels;reply+=",\"pixels_total\":";reply+=uint32_t(taskWidth(size))*taskHeight(size);
  reply+=",\"width\":";reply+=taskWidth(size);
  reply+=",\"height\":";reply+=taskHeight(size);
  reply+=",\"size_code\":";reply+=size;
  reply+=",\"timing\":";reply+=frameTimingJson();reply+="}";
  return reply;
}
void handleFrameStudentStatus(){http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",resultWorkerActive?cachedFrameStatus:frameStatusJson());}
void handleFrameStudentStart(){
  const String request=http.hasArg("request")?http.arg("request"):String(esp_random(),HEX)+String(esp_random(),HEX);
  if(request.length()>47){http.send(400,"text/plain","invalid request token");return;}
  for(size_t i=0;i<request.length();i++)if(!isalnum(request[i])&&request[i]!='-'&&request[i]!='_'){http.send(400,"text/plain","invalid request token");return;}
  if(request==taskRecord.request){
    if(matchingTask() && (fpgaRead(0x4d)&3)){frameJobId=taskRecord.job;http.send(202,"application/json",taskIdentityJson());}
    else http.send(409,"text/plain","saved request no longer matches FPGA; no automatic restart");
    return;
  }
  if(fpgaRead(0x15)!=0xc4){http.send(409,"text/plain; charset=utf-8","请先更新配套 V4 FPGA 完整位流");return;}
  refreshFrameJobLock();
  if(fpgaRead(0x60)!=0xd2){http.send(503,"text/plain; charset=utf-8","当前位流不支持DDR帧处理");return;}
  if(frameJobActive && (fpgaRead(0x4d)&3)==2){frameJobActive=false;httpCaptureBusy=false;}
  if(httpCaptureBusy||httpUploadBusy||frameJobActive||(fpgaRead(0x4d)&1)){http.send(409,"text/plain; charset=utf-8","已有图像任务运行，请先继续读取");return;}
  String source=http.hasArg("source")?http.arg("source"):"upload";
  String output=http.hasArg("output")?http.arg("output"):"color";
  String pipeline=http.hasArg("pipeline")?http.arg("pipeline"):"model";
  if((source!="camera"&&source!="upload")||(output!="color"&&output!="gray"&&output!="binary")||(pipeline!="model"&&pipeline!="joint")){http.send(400,"text/plain","invalid source/output/pipeline");return;}
  const bool camera=source=="camera";
  {
    const uint8_t m=fpgaRead(0x66);
    if(fpgaRead(0x7e)!=FULL_RUNTIME_ID||(m&8)==0){http.send(409,"text/plain; charset=utf-8",bootModelBusy()?"开机正在自动装载共享模型，请稍后重试":"模型未就绪，请查看 /api/boot-model/status；也可到 /model 手动恢复");return;}
  }
  if(camera){
    invalidateTaskInput();
    if(http.hasArg("resolution")){
      int resolution=http.arg("resolution").toInt();
      if((resolution!=720&&resolution!=1080)||!selectCamera(resolution==1080?1:0)){http.send(504,"text/plain; charset=utf-8","摄像头切换失败");return;}
    }
     

    fpgaWrite(REG_SCAN_MODE,0);fpgaWrite(REG_ALGORITHM,0);
    if((fpgaRead(REG_STATUS)&STATUS_FROZEN)!=0){fpgaWrite(REG_CONTROL,2);if(!waitForStatus(STATUS_FROZEN,false,FREEZE_TIMEOUT_MS)){http.send(504,"text/plain","camera resume timeout");return;}}
    if(!beginHybridCapture()){http.send(504,"text/plain; charset=utf-8","1080p切换失败");return;}
  }else if(!(fpgaRead(REG_UPLOAD_STATUS)&UPLOAD_STATUS_HOST_VALID)){http.send(409,"text/plain; charset=utf-8","请先上传原图");return;}
  if(!(fpgaRead(REG_STATUS)&STATUS_FROZEN))fpgaWrite(REG_CONTROL,1);
  if(!waitForStatus(STATUS_FROZEN,true,FREEZE_TIMEOUT_MS)||!waitForStatus(STATUS_FRAME_READY,true,5000)){http.send(504,"text/plain; charset=utf-8","完整帧冻结失败");return;}
  uint8_t config=(output=="gray"?1:output=="binary"?2:0)|(pipeline=="joint"?4:0);
  {
    const uint8_t hd=camera?(fpgaRead(REG_RESOLUTION)==1):uploadFrame1080;
    const uint8_t m=fpgaRead(0x66);
    if(((fpgaRead(0x65)>>2)&3)!=hd || !(m&16)){
      if(!ensureBootProgram(hd)){http.send(409,"text/plain; charset=utf-8","尺寸程序自动装载失败，请查看 /api/boot-model/status 或到 /model 手动恢复");return;}
    }
  }
  fpgaWrite(0x61,config);
  if(!waitForRegister(0x61,config,7,250)){http.send(409,"text/plain; charset=utf-8","处理配置不匹配，请更新配套位流");return;}
  if(!prepareTaskRecord(config,camera,camera?(fpgaRead(REG_RESOLUTION)==1):uploadFrame1080,request)){http.send(507,"text/plain","task journal/cookie preparation failed; computation not started");return;}
  fpgaWrite(0x4c,camera?5:1);
  uint32_t started=millis();uint8_t state=0;
  do{state=fpgaRead(0x4d);if(state&3)break;delay(2);}while(millis()-started<300);
  if((state&12)||!(state&3)){http.send(409,"text/plain; charset=utf-8","FPGA拒绝任务，请查询状态");return;}
  frameJobId=taskRecord.job;taskRecord.phase=2;saveTaskRecord();frameJobActive=(state&1)!=0;httpCaptureBusy=frameJobActive;
  http.send(202,"application/json",taskIdentityJson());
}
