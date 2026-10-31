#pragma once
 

static bool previewActive=false,previewRestoreFailed=false;
static String previewOwner;
static uint8_t previewSavedCamera=0,previewSavedMode=0,previewSavedAlgorithm=0;
static uint32_t previewTouched=0,previewRestoreAttempt=0,previewFrames=0;
static constexpr uint32_t PREVIEW_LEASE_MS=15000;
static uint32_t previewFailures=0,previewLastFailureAt=0,previewLastPrepareMs=0,previewLastTransferMs=0;
static uint8_t previewFailureStage=0,previewFailureHeader[16]={0};
bool previewTokenValid(const String &s){if(s.length()!=32)return false;for(size_t i=0;i<s.length();i++)if(!isxdigit(s[i]))return false;return true;}
bool previewIsOwner(){return previewActive && http.arg("lease")==previewOwner;}
void handlePreviewStatus(){
 String s="{\"active\":";s+=previewActive?"true":"false";
 s+=",\"restore_failed\":";s+=previewRestoreFailed?"true":"false";
 s+=",\"owned\":";s+=previewIsOwner()?"true":"false";
 s+=",\"width\":";s+=512;s+=",\"height\":";s+=300;s+=",\"frames\":";s+=previewFrames;s+=",\"failures\":";s+=previewFailures;
 s+=",\"last_failure_ms\":";s+=previewLastFailureAt;s+=",\"last_failure_stage\":";s+=previewFailureStage;
 s+=",\"prepare_ms\":";s+=previewLastPrepareMs;s+=",\"transfer_ms\":";s+=previewLastTransferMs;
 s+=",\"last_bad_header\":\"";for(uint8_t b:previewFailureHeader){char h[3];snprintf(h,sizeof(h),"%02x",b);s+=h;}s+="\"}";
 http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",s);
}
bool releasePreview(){
 if(!previewActive)return true;
 previewRestoreAttempt=millis();
  
 bool ok=selectCamera(previewSavedCamera);
 if(ok){fpgaWrite(REG_SCAN_MODE,previewSavedMode);fpgaWrite(REG_ALGORITHM,previewSavedAlgorithm);
  ok=waitForRegister(REG_SCAN_MODE,previewSavedMode,3,250)&&waitForRegister(REG_ALGORITHM,previewSavedAlgorithm,127,250);}
 previewRestoreFailed=!ok;
  
 if(ok){while(Serial.available())Serial.read();previewActive=false;previewOwner="";capturePreviewOutput=false;}
 return ok;
}
void servicePreviewLease(){
 if(previewActive && !httpCaptureBusy && uint32_t(millis()-previewTouched)>PREVIEW_LEASE_MS && uint32_t(millis()-previewRestoreAttempt)>5000)releasePreview();
}
void handlePreviewStart(){
 const String owner=http.arg("lease");
 if(!previewTokenValid(owner)){http.send(400,"text/plain","invalid preview lease");return;}
 if(previewActive){if(owner==previewOwner&&!previewRestoreFailed){previewTouched=millis();handlePreviewStatus();}else http.send(423,"text/plain; charset=utf-8","调焦预览已占用，请先退出预览或等待断线释放");return;}
 if(resultWorkerActive){http.send(423,"text/plain","cache owns SPI");return;}
 refreshFrameJobLock();
 if(httpCaptureBusy||httpUploadBusy||uploadSpiOpen||frameJobActive||portraitActive||bootModelBusy()||(fpgaRead(0x4d)&1)){
  http.send(423,"text/plain; charset=utf-8","正在处理图像或装载模型，请完成后进入调焦");return;}
 const uint8_t previewCapability=fpgaRead(0x1f);
 if(previewCapability!=0x51 && previewCapability!=0x52){http.send(409,"text/plain; charset=utf-8","请同时更新 V6 FPGA，当前固件不支持低分辨率预览");return;}
  
 previewSavedCamera=cameraSelection;previewSavedMode=fpgaRead(REG_SCAN_MODE)&3;previewSavedAlgorithm=fpgaRead(REG_ALGORITHM)&127;
 previewOwner=owner;previewActive=true;previewTouched=millis();previewFrames=0;previewFailures=0;previewLastFailureAt=0;previewFailureStage=0;memset(previewFailureHeader,0,16);previewRestoreFailed=false;
 invalidateTaskInput();
 if(!selectCamera(0)){releasePreview();http.send(504,"text/plain; charset=utf-8","摄像头预览切换失败；请退出预览重试");return;}
 fpgaWrite(REG_SCAN_MODE,0);fpgaWrite(REG_ALGORITHM,0);
 if(!waitForRegister(REG_SCAN_MODE,0,3,250)||!waitForRegister(REG_ALGORITHM,0,127,250)){
  releasePreview();http.send(504,"text/plain","preview register verification failed");return;}
 previewTouched=millis();handlePreviewStatus();
}
void handlePreviewStop(){
 if(!previewActive){handlePreviewStatus();return;}
 if(!previewIsOwner()){http.send(423,"text/plain","preview owned by another session");return;}
 if(!releasePreview()){http.send(504,"text/plain; charset=utf-8","退出预览后摄像头恢复未确认，其他模式保持锁定，请重试退出");return;}
 handlePreviewStatus();
}
void handlePreviewFrame(){
 if(!previewIsOwner()||previewRestoreFailed){http.send(423,"text/plain","preview lease unavailable");return;}
  
 if(http.arg("source")!="camera"||http.arg("format")!="jpeg"||http.arg("mode")!="0"||http.arg("alg")!="0"||http.hasArg("camera")){
  http.send(400,"text/plain","invalid preview frame parameters");return;}
 previewTouched=millis();capturePreviewOutput=true;
 handleCaptureHttp();
 capturePreviewOutput=false;previewTouched=millis();
 previewLastPrepareMs=captureDiagnostic.prepareMs;previewLastTransferMs=captureDiagnostic.transferMs;
 if(captureDiagnostic.complete)previewFrames++;
 else{previewFailures++;previewLastFailureAt=millis();previewFailureStage=captureDiagnostic.stage;memcpy(previewFailureHeader,captureDiagnostic.header,16);}
}
bool rejectPreviewMutation(){
 if(!previewActive)return false;
 http.send(423,"text/plain; charset=utf-8","调焦预览独占图像硬件，请先退出预览再抓拍、上传或运行模型");return true;
}
