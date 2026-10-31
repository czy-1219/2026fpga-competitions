#pragma once
#include <LittleFS.h>
#include <esp_partition.h>
 

struct ResultMeta {
 uint32_t magic=0x35433654,id=0,job=0,cookie=0,size=0,crc=0,width=0,height=0,source=0,format=2;
 char request[48]={0};uint32_t metaCrc=0;
};
struct ResultState {
 uint32_t phase=0,received=0,expected=0,spiHz=10000000,prepareMs=0,readMs=0;
 const char *reason="none";ResultMeta meta;
};
static ResultState resultState;
static portMUX_TYPE resultMux=portMUX_INITIALIZER_UNLOCKED;
static bool resultFsReady=false;
static constexpr const char *RESULT_FILE="/ti60-v5.frame",*RESULT_TMP="/ti60-v5.tmp",*RESULT_META="/ti60-v5.meta";
struct ResultRequest {ResultMeta meta;uint32_t hz=10000000;uint8_t mode=0,alg=0;int camera=-1;bool raw=false;};
static ResultRequest resultRequest;
ResultState resultSnapshot(){portENTER_CRITICAL(&resultMux);ResultState s=resultState;portEXIT_CRITICAL(&resultMux);return s;}
void publishResult(const ResultState &s){portENTER_CRITICAL(&resultMux);resultState=s;portEXIT_CRITICAL(&resultMux);}
uint32_t resultMetaCrc(const ResultMeta&m){return studentCrc((const uint8_t*)&m,offsetof(ResultMeta,metaCrc));}
bool blankResultPartition(){
 const esp_partition_t *p=esp_partition_find_first(ESP_PARTITION_TYPE_DATA,ESP_PARTITION_SUBTYPE_ANY,"storage");if(!p)return false;
 uint8_t block[256];
 for(size_t o=0;o<p->size;o+=sizeof(block)){
  if(esp_partition_read(p,o,block,sizeof(block))!=ESP_OK)return false;
  for(uint8_t c:block)if(c!=0xff)return false;if((o&4095)==0)delay(1);
 }return true;
}
void beginResultCache(){
 resultFsReady=LittleFS.begin(false,"/littlefs",5,"storage");
  

 const esp_partition_t *cachePartition=esp_partition_find_first(ESP_PARTITION_TYPE_DATA,ESP_PARTITION_SUBTYPE_ANY,"storage");
  


 const bool ownedCache=cachePartition && cachePartition->address==0x150000 && cachePartition->size==0x2b0000;
 if(!resultFsReady && (ownedCache || blankResultPartition()) && LittleFS.format())resultFsReady=LittleFS.begin(false,"/littlefs",5,"storage");
 if(!resultFsReady)return;
 File f=LittleFS.open(RESULT_META,"r");ResultMeta m;
 if(f && f.size()==sizeof(m) && f.read((uint8_t*)&m,sizeof(m))==sizeof(m) && m.magic==0x35433654 && m.metaCrc==resultMetaCrc(m) && m.request[47]==0){
  f.close();File jpg=LittleFS.open(RESULT_FILE,"r");uint32_t crc=0xffffffff;
  if(jpg && jpg.size()==m.size){
   uint32_t read=0;
   while(jpg.available()){size_t n=jpg.read(streamRx,sizeof(streamRx));if(!n)break;read+=n;crc=ti60CrcUpdate(crc,streamRx,n);delay(1);}
   if(read==m.size && ~crc==m.crc){resultState.meta=m;resultState.phase=3;resultState.expected=resultState.received=m.size;}
  }
 }
 LittleFS.remove(RESULT_TMP);
}
void persistResultDiagnostic(const ResultState&s){
 char text[512];snprintf(text,sizeof(text),"{\"job_id\":%lu,\"cookie\":%lu,\"cache_id\":%lu,\"phase\":%lu,\"reason\":\"%s\",\"received_bytes\":%lu,\"expected_bytes\":%lu,\"spi_hz\":%lu,\"prepare_ms\":%lu,\"read_ms\":%lu}",
 (unsigned long)s.meta.job,(unsigned long)s.meta.cookie,(unsigned long)s.meta.id,(unsigned long)s.phase,s.reason,(unsigned long)s.received,(unsigned long)s.expected,(unsigned long)s.spiHz,(unsigned long)s.prepareMs,(unsigned long)s.readMs);
 Preferences diag;if(diag.begin("ti60-diag-v4",false)){diag.putString("result",text);diag.end();}
}
void resultCacheWorker(void*){
 ResultRequest req=resultRequest;ResultState s=resultSnapshot();uint8_t header[16]={0};uint32_t size=0;bool opened=false;
 const uint32_t began=millis();captureStreamHz=req.hz;captureRawOutput=req.raw;
  

 if(!resultFsReady){s.phase=5;s.reason="cache_unmounted";persistResultDiagnostic(s);publishResult(s);resultWorkerActive=false;vTaskDelete(nullptr);return;}
 uint32_t remaining=0;
 bool ok=true;
 if(req.meta.source==3){
  if(req.camera>=0)ok=selectCamera(req.camera);
  if(ok){fpgaWrite(REG_ALGORITHM,req.alg);ok=waitForRegister(REG_ALGORITHM,req.alg,0x7f,250);}
 }
 if(ok)ok=req.meta.source==3 ? prepareFrameStream(header,size,req.mode) : prepareUploadedFrameStream(header,size,req.mode,req.meta.source==1?2:req.meta.source==2?8:0);
 opened=ok;remaining=ok?size+4:0;s.prepareMs=millis()-began;s.expected=size;
 if(!ok){s.phase=4;s.reason="prepare_failed";}
 else if(!resultFsReady || size+32768>LittleFS.totalBytes()-LittleFS.usedBytes()){
  s.phase=5;s.reason="direct_required";ok=false;
 }else{
  s.phase=2;publishResult(s);persistResultDiagnostic(s);File file=LittleFS.open(RESULT_TMP,"w");
  JpegHttpGuard guard(size,header[5]==3);const uint32_t readBegan=millis();
  auto writer=[&](const uint8_t *data,size_t n){return file && file.write(data,n)==n;};
  memset(streamTx,0,sizeof(streamTx));ok=bool(file);
  while(ok && remaining){
   if(millis()-readBegan>90000){s.reason="spi_timeout";ok=false;break;}
   const size_t n=remaining>sizeof(streamRx)?sizeof(streamRx):remaining;
   fpgaSpi.transferBytes(streamTx,streamRx,n);ok=guard.consume(streamRx,n,writer);remaining-=n;
   s.received=size+4-remaining;publishResult(s);delay(1);
  }
  if(ok && !guard.crcOk()){s.reason="crc_mismatch";ok=false;}
  if(ok)ok=guard.finish(writer);
  file.flush();file.close();s.readMs=millis()-readBegan;
  if(ok){
   s.meta.format=header[5];s.meta.size=size;s.meta.crc=guard.verifiedCrc();s.meta.width=uint16_t(header[6])|(uint16_t(header[7])<<8);s.meta.height=uint16_t(header[8])|(uint16_t(header[9])<<8);
   s.meta.metaCrc=resultMetaCrc(s.meta);
   ok=LittleFS.rename(RESULT_TMP,RESULT_FILE);
   if(ok){File mf=LittleFS.open(RESULT_META,"w");ok=mf && mf.write((const uint8_t*)&s.meta,sizeof(s.meta))==sizeof(s.meta);mf.close();}
  }
  if(ok){s.phase=3;s.reason="none";}else{s.phase=4;if(!strcmp(s.reason,"none"))s.reason="cache_write_failed";LittleFS.remove(RESULT_TMP);}
 }
 if(opened){if(remaining)drainFrameBytes(remaining);digitalWrite(PIN_CS,HIGH);fpgaSpi.endTransaction();delay(2);}
  
 if(!ok && !opened && req.meta.source>=3)cleanupCapturePrepareFailure(0);
 persistResultDiagnostic(s);publishResult(s);resultWorkerActive=false;vTaskDelete(nullptr);
}
String resultStatusJson(){
 const ResultState s=resultSnapshot();String r="{\"phase\":";r+=s.phase;r+=",\"reason\":\"";r+=s.reason;r+="\"";
 r+=",\"storage_ready\":";r+=resultFsReady?"true":"false";r+=",\"active\":";r+=resultWorkerActive?"true":"false";
 r+=",\"cache_id\":";r+=s.meta.id;r+=",\"job_id\":";r+=s.meta.job;r+=",\"cookie\":";r+=s.meta.cookie;
 r+=",\"source\":";r+=s.meta.source;r+=",\"request\":\"";r+=s.meta.request;r+="\"";
 r+=",\"format\":";r+=s.meta.format;r+=",\"bytes\":";r+=s.meta.size;r+=",\"crc32\":";r+=s.meta.crc;r+=",\"width\":";r+=s.meta.width;r+=",\"height\":";r+=s.meta.height;
 r+=",\"received_bytes\":";r+=s.received;r+=",\"expected_bytes\":";r+=s.expected;r+=",\"spi_hz\":";r+=s.spiHz;
 r+=",\"prepare_ms\":";r+=s.prepareMs;r+=",\"read_ms\":";r+=s.readMs;r+="}";return r;
}
void handleResultStatus(){http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",resultStatusJson());}
void handleResultPrepare(){
 const String request=http.arg("request"),source=http.arg("source");
 if(request.length()==0 || request.length()>47){http.send(400,"text/plain","request token required");return;}
 for(size_t i=0;i<request.length();i++)if(!isalnum(request[i])&&request[i]!='-'&&request[i]!='_'){http.send(400,"text/plain","invalid request token");return;}
 uint8_t sel=source=="result"?1:source=="frame_original"?2:source=="camera"?3:source=="upload"?4:0;
 if(!sel){http.send(400,"text/plain","invalid source");return;}
 uint32_t job=strtoul(http.arg("job").c_str(),nullptr,10),cookie=strtoul(http.arg("cookie").c_str(),nullptr,10);
 ResultState old=resultSnapshot();
 if(old.meta.request[0] && request==old.meta.request){
  if(old.meta.source!=sel || old.meta.job!=job || old.meta.cookie!=cookie){http.send(409,"text/plain","request identity conflict");return;}
  handleResultStatus();return;
 }
 if(resultWorkerActive){http.send(423,"text/plain","JPEG cache preparation in progress");return;}
  

 if(sel<=2 && old.phase==3 && old.meta.job==job && old.meta.cookie==cookie && old.meta.source==sel && old.meta.format==(http.arg("format")=="rgb565" && fpgaRead(0x1e)==0x52 ? 3u : 2u)){handleResultStatus();return;}
 refreshFrameJobLock();
 if(httpCaptureBusy || httpUploadBusy || (fpgaRead(0x4d)&1) || (fpgaRead(0x51)&2)){http.send(409,"text/plain","FPGA task is still running");return;}
 if(sel<=2 && (job!=frameJobId || !matchingTask() || cookie!=taskRecord.cookie || (fpgaRead(0x4d)&15)!=2)){
  http.send(409,"text/plain","task changed or no complete result");return;
 }
 int rate=http.hasArg("spi_mhz")?http.arg("spi_mhz").toInt():10;
 int mode=http.hasArg("mode")?http.arg("mode").toInt():0,alg=http.hasArg("alg")?http.arg("alg").toInt():0;
 if((rate!=20 && rate!=10 && rate!=5)||mode<0||mode>3||alg<0||alg>127){http.send(400,"text/plain","invalid mode/rate/algorithm");return;}
 resultRequest=ResultRequest();resultRequest.raw=http.arg("format")=="rgb565" && fpgaRead(0x1e)==0x52;resultRequest.meta.format=resultRequest.raw?3:2;resultRequest.meta.source=sel;resultRequest.meta.job=job;resultRequest.meta.cookie=cookie;
 do{resultRequest.meta.id=esp_random();}while(!resultRequest.meta.id || resultRequest.meta.id==old.meta.id);
 request.toCharArray(resultRequest.meta.request,48);resultRequest.hz=rate*1000000u;resultRequest.mode=sel<=2?0:mode;resultRequest.alg=alg;
 if(http.hasArg("camera")){int c=http.arg("camera").toInt();if(c<0||c>2){http.send(400,"text/plain","invalid camera");return;}resultRequest.camera=c;}
 if(sel==3)invalidateTaskInput();
 cachedFrameStatus=frameStatusJson();cachedBoardStatus=boardStatusJson();
  
 if(resultFsReady){LittleFS.remove(RESULT_FILE);LittleFS.remove(RESULT_META);LittleFS.remove(RESULT_TMP);}
 ResultState state;state.phase=1;state.spiHz=resultRequest.hz;state.meta=resultRequest.meta;publishResult(state);persistResultDiagnostic(state);
 resultWorkerActive=true;
 if(xTaskCreatePinnedToCore(resultCacheWorker,"jpeg-cache",8192,nullptr,1,nullptr,1)!=pdPASS){resultWorkerActive=false;state.phase=4;state.reason="worker_allocation_failed";publishResult(state);}
 handleResultStatus();
}
void handleResultChunk(){
 const ResultState s=resultSnapshot();const uint32_t id=strtoul(http.arg("id").c_str(),nullptr,10),offset=strtoul(http.arg("offset").c_str(),nullptr,10);
 if(resultWorkerActive){http.send(423,"text/plain","cache worker finalizing; retry shortly");return;}
 if(s.phase!=3 || id!=s.meta.id){http.send(409,"text/plain","cache identity changed or not ready");return;}
 if(offset>=s.meta.size){http.send(416,"text/plain","offset outside JPEG");return;}
 const size_t n=(s.meta.size-offset)>sizeof(streamRx)?sizeof(streamRx):s.meta.size-offset;
 File f=LittleFS.open(RESULT_FILE,"r");if(!f || !f.seek(offset) || f.read(streamRx,n)!=n){http.send(500,"text/plain","cache read failed");return;}f.close();
 http.sendHeader("Cache-Control","no-store");http.sendHeader("Connection","close");http.sendHeader("X-Chunk-CRC32",String(studentCrc(streamRx,n),HEX));
 http.sendHeader("X-Cache-Id",String(id));http.sendHeader("X-Chunk-Offset",String(offset));http.setContentLength(n);http.send(200,"application/octet-stream","");
 WiFiClient client=http.client();writeHttpBytes(client,streamRx,n);client.stop();
}
void handlePersistentDiagnostics(){
 Preferences d;String previous="null";if(d.begin("ti60-diag-v4",true)){previous=d.getString("result","null");d.end();}
 String s="{\"boot_id\":";s+=transportBootId;s+=",\"reset_reason\":";s+=uint32_t(esp_reset_reason());s+=",\"uptime_ms\":";s+=millis();
 s+=",\"free_heap\":";s+=ESP.getFreeHeap();s+=",\"minimum_free_heap\":";s+=ESP.getMinFreeHeap();s+=",\"ap_clients\":";s+=WiFi.softAPgetStationNum();
 s+=",\"journal\":";s+=taskJournalJson();s+=",\"result\":";s+=resultStatusJson();s+=",\"last_result_diagnostic\":";s+=previous;s+="}";
 http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",s);
}
