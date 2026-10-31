#pragma once
 

struct CaptureDiagnostic {
 uint32_t sequence=0,request=0,job=0,expected=0,received=0,sent=0;
 uint32_t prepareMs=0,transferMs=0,spiHz=20000000;
 uint8_t header[16]={0},stage=0;
 bool active=false,crcOk=false,complete=false;
 const char *phase="idle",*reason="none";
};
static CaptureDiagnostic captureDiagnostic;
static uint32_t captureStreamHz=20000000;
static uint32_t transportBootId=0;
uint32_t currentFrameJobId();
String transportStatusJson(){
 const auto &d=captureDiagnostic;
 String s="{\"sequence\":";s+=d.sequence;s+=",\"request\":";s+=d.request;
 s+=",\"job_id\":";s+=d.job;s+=",\"boot_id\":";s+=transportBootId;
 s+=",\"phase\":\"";s+=d.phase;s+="\",\"reason\":\"";s+=d.reason;s+="\"";
 s+=",\"active\":";s+=d.active?"true":"false";
 s+=",\"complete\":";s+=d.complete?"true":"false";
 s+=",\"crc_ok\":";s+=d.crcOk?"true":"false";
 s+=",\"expected_bytes\":";s+=d.expected;s+=",\"received_bytes\":";s+=d.received;s+=",\"sent_bytes\":";s+=d.sent;
 s+=",\"prepare_ms\":";s+=d.prepareMs;s+=",\"transfer_ms\":";s+=d.transferMs;s+=",\"spi_hz\":";s+=d.spiHz;
 s+=",\"capture_stage\":";s+=d.stage;s+=",\"header_hex\":\"";
 for(uint8_t b:d.header){char hex[3];snprintf(hex,sizeof(hex),"%02x",b);s+=hex;}s+="\"}";return s;
}
void handleTransportStatus(){http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",transportStatusJson());}
