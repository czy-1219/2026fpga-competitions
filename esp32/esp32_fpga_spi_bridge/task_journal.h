#pragma once
#include <Preferences.h>
 
struct TaskRecord {
 uint32_t magic=0x344a3654,version=1,job=0,cookie=0;
 uint32_t config=0,geometry=0,phase=0,lastCommand=0,elapsedMs=0;
 char request[48]={0};uint32_t crc=0;
};
static TaskRecord taskRecord;
static bool frameJobActive=false,journalAvailable=false,taskRecovered=false;
static uint32_t frameJobId=0,jobClock=0,journalSavedAt=0;
static const char *recoveryReason="no_saved_task";
static Preferences taskPreferences;
uint32_t currentFrameJobId(){return frameJobId;}
uint32_t taskRecordCrc(const TaskRecord &r){return studentCrc((const uint8_t*)&r,offsetof(TaskRecord,crc));}
bool saveTaskRecord(){
 taskRecord.crc=taskRecordCrc(taskRecord);
 return journalAvailable&&taskPreferences.putBytes("record",&taskRecord,sizeof(taskRecord))==sizeof(taskRecord);
}
uint32_t fpgaTaskCookie(){return fpgaRead(0x15)==0xc4?fullRead32(0x16):0;}
bool matchingTask(){
 return taskRecord.cookie && taskRecord.phase!=5 && fpgaRead(REG_DEVICE_ID)==0x60 && fpgaTaskCookie()==taskRecord.cookie &&
  (fpgaRead(0x61)&7)==taskRecord.config && (fpgaRead(0x4e)&26)==taskRecord.geometry && (fpgaRead(0x66)&0x18)==0x18;
}
void invalidateTaskInput(){
 if(taskRecord.job && taskRecord.phase!=5){taskRecord.phase=5;saveTaskRecord();}
 taskRecovered=false;recoveryReason="input_replaced_by_explicit_action";
}
void recoverTask(){
 if(!taskRecord.job){recoveryReason="no_saved_task";return;}
 if(fpgaRead(REG_DEVICE_ID)!=0x60){recoveryReason="fpga_unreachable";return;}
 const uint8_t state=fpgaRead(0x4d);
 if(matchingTask() && (state&3) && !(state&0xfc)){
  frameJobId=taskRecord.job;frameJobActive=state&1;httpCaptureBusy=frameJobActive;taskRecovered=true;
  recoveryReason="recovered_from_fpga_cookie";jobClock=millis();journalSavedAt=millis();
 }else recoveryReason=fpgaTaskCookie()==0?"fpga_reset_or_task_not_started":"fpga_task_changed";
}
void beginTaskJournal(){
 journalAvailable=taskPreferences.begin("ti60-task-v4",false);
 TaskRecord saved;
 if(journalAvailable && taskPreferences.getBytesLength("record")==sizeof(saved) && taskPreferences.getBytes("record",&saved,sizeof(saved))==sizeof(saved) &&
    saved.magic==taskRecord.magic && saved.version==1 && saved.crc==taskRecordCrc(saved) && saved.request[47]==0){taskRecord=saved;frameJobId=saved.job;}
 recoverTask();
}
bool prepareTaskRecord(uint8_t config,bool camera,uint8_t hd,const String &request){
 if(fpgaRead(0x15)!=0xc4 || request.length()==0 || request.length()>47)return false;
 TaskRecord next;next.job=frameJobId+1;if(!next.job)next.job=1;
 do{next.cookie=esp_random();}while(!next.cookie || next.cookie==taskRecord.cookie);
 next.config=config;next.geometry=(camera?8:0)|((hd&1)<<1)|((hd&2)<<3);next.phase=1;request.toCharArray(next.request,sizeof(next.request));
 TaskRecord previous=taskRecord;taskRecord=next;
 if(!saveTaskRecord()){taskRecord=previous;return false;}
 for(unsigned i=0;i<4;i++)fpgaWrite(0x16+i,next.cookie>>(i*8));
 if(fullRead32(0x1a)!=next.cookie){recoveryReason="cookie_write_failed";return false;}
 jobClock=journalSavedAt=millis();taskRecovered=false;recoveryReason="new_task";return true;
}
void serviceTaskJournal(){
 if(!taskRecord.cookie || !matchingTask())return;
 uint8_t state=fpgaRead(0x4d);if(state&0xf0)return;
 uint32_t phase=(state&12)?4:(state&2)?3:(state&1)?2:taskRecord.phase;
 if(phase!=taskRecord.phase || (state&1 && millis()-journalSavedAt>=30000)){
  if(taskRecord.phase==2)taskRecord.elapsedMs+=millis()-jobClock;
  jobClock=journalSavedAt=millis();taskRecord.phase=phase;taskRecord.lastCommand=fullRead32(0x76);saveTaskRecord();
 }
}
String taskIdentityJson(){
 String s="{\"accepted\":true,\"job_id\":";s+=frameJobId;s+=",\"boot_id\":";s+=transportBootId;
 s+=",\"cookie\":";s+=taskRecord.cookie;s+=",\"request\":\"";s+=taskRecord.request;s+="\"}";return s;
}
String taskJournalJson(){
 String s="{\"available\":";s+=journalAvailable?"true":"false";s+=",\"job_id\":";s+=taskRecord.job;
 s+=",\"cookie\":";s+=taskRecord.cookie;s+=",\"phase\":";s+=taskRecord.phase;s+=",\"last_command\":";s+=taskRecord.lastCommand;
 s+=",\"elapsed_ms_checkpoint\":";s+=taskRecord.elapsedMs;s+=",\"recovered\":";s+=taskRecovered?"true":"false";
 s+=",\"reason\":\"";s+=recoveryReason;s+="\",\"request\":\"";s+=taskRecord.request;s+="\"}";return s;
}
