#pragma once
 

void handleCameraProfileStatus(){
 char data[160];const bool supported=fpgaRead(0x2d)==0x77;
 snprintf(data,sizeof(data),"{\"supported\":%s,\"profile\":%u,\"i2c_status\":%u}",supported?"true":"false",unsigned(supported?fpgaRead(0x2c):0),unsigned(fpgaRead(0x29)));
 http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",data);
}
bool cameraProfileReady(){
 if(!waitForRegister(0x29,1,3,4000)||(fpgaRead(0x29)&4))return false;
 fpgaWrite(REG_CONTROL,2);
 if(!waitForStatus(STATUS_FROZEN,false,FREEZE_TIMEOUT_MS))return false;
 uint8_t count=fpgaRead(0x20);uint32_t start=millis();
 while(millis()-start<3000){if(uint8_t(fpgaRead(0x20)-count)>=3)return true;delay(5);}
 return false;
}
void handleCameraProfileApply(){
 const String arg=http.arg("value");
 if(arg.length()==0||arg.length()>3){http.send(400,"text/plain","invalid camera profile");return;}
 for(size_t i=0;i<arg.length();++i)if(!isDigit(arg[i])){http.send(400,"text/plain","invalid camera profile");return;}
 const unsigned value=arg.toInt();
 if(value>127||(value&7)>4||((value>>3)&3)>2||((value>>5)&3)>2){http.send(400,"text/plain","invalid camera profile");return;}
 refreshFrameJobLock();
 if(httpCaptureBusy||httpUploadBusy||uploadSpiOpen||frameJobActive||portraitActive||bootModelBusy()||(fpgaRead(0x4d)&1)){
  http.send(423,"text/plain; charset=utf-8","图像任务占用，请完成后修改采集参数");return;
 }
 if(fpgaRead(0x2d)!=0x77){http.send(409,"text/plain; charset=utf-8","请同时更新 V7.7 FPGA 与 ESP32");return;}
 const uint8_t old=fpgaRead(0x2c);
 if(old==value){handleCameraProfileStatus();return;}
 invalidateTaskInput();fpgaWrite(REG_CONTROL,2);
 if(!waitForStatus(STATUS_FROZEN,false,FREEZE_TIMEOUT_MS)){http.send(504,"text/plain","camera resume not confirmed");return;}
 fpgaWrite(0x2c,value);delay(3);
 if(fpgaRead(0x2c)!=value||!cameraProfileReady()){
  fpgaWrite(0x2c,old);delay(3);const bool restored=cameraProfileReady();
  http.send(504,"text/plain; charset=utf-8",restored?"采集设置未确认，已恢复原参数":"采集设置与恢复均未确认，请重启设备并保留诊断");return;
 }
 handleCameraProfileStatus();
}
