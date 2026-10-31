#include <Arduino.h>
#include <SPI.h>
#include <WiFi.h>
#include <WebServer.h>
#include <driver/gpio.h>
#include "jpeg_http_guard.h"
#include <lwip/sockets.h>
#include <esp_system.h>
#include "portrait_page.h"

 




static constexpr int PIN_SCLK = 18;
static constexpr int PIN_MISO = 19;
static constexpr int PIN_MOSI = 23;
static constexpr int PIN_CS   = 27;

static constexpr uint32_t SPI_HZ_CONTROL = 1000000;
 

static constexpr uint32_t SPI_HZ_STREAM = 20000000;
static constexpr uint32_t SERIAL_BAUD = 921600;
static constexpr char AP_SSID[] = "Ti60-Capture";
static constexpr char AP_PASSWORD[] = "ti60capture";
static constexpr uint8_t REG_DEVICE_ID = 0x00;
static constexpr uint8_t REG_VERSION   = 0x01;
static constexpr uint8_t REG_STATUS    = 0x02;
static constexpr uint8_t REG_CONTROL   = 0x10;
static constexpr uint8_t REG_PWM       = 0x11;
static constexpr uint8_t REG_SCRATCH   = 0x12;
static constexpr uint8_t REG_SCAN_MODE = 0x13;
static constexpr uint8_t REG_RESOLUTION = 0x14;
static constexpr uint8_t REG_CAM_FRAME_LO = 0x20;
static constexpr uint8_t REG_CAM_LINES_LO = 0x22;
static constexpr uint8_t REG_CAM_MIN_LO = 0x24;
static constexpr uint8_t REG_CAM_MAX_LO = 0x26;
static constexpr uint8_t REG_I2C_INDEX = 0x28;
static constexpr uint8_t REG_I2C_STATUS = 0x29;
static constexpr uint8_t REG_I2C_FIRST_NACK = 0x2A;
static constexpr uint8_t REG_I2C_NACK_COUNT = 0x2B;
static constexpr uint8_t REG_UPLOAD_CONTROL = 0x30;
static constexpr uint8_t REG_UPLOAD_STATUS = 0x31;
static constexpr uint8_t REG_UPLOAD_COUNT_LO = 0x32;
static constexpr uint8_t REG_ALGORITHM = 0x35;

static constexpr uint8_t STATUS_FROZEN = 1u << 0;
static constexpr uint8_t STATUS_BUSY = 1u << 1;
static constexpr uint8_t STATUS_STREAM_READY = 1u << 5;
static constexpr uint8_t STATUS_FRAME_READY = 1u << 6;
static constexpr uint32_t FREEZE_TIMEOUT_MS = 15000;
 

static constexpr uint32_t RESOLUTION_SETTLE_MS = 4000;
static constexpr size_t FRAME_HEADER_BYTES = 16;
static constexpr size_t FRAME_CRC_BYTES = 4;
 

static constexpr size_t FRAME_MAX_PAYLOAD = 1920u * 1080u * 2u;
static constexpr size_t FRAME_720_PAYLOAD = 1024u * 600u * 2u;
 
static constexpr size_t STREAM_CHUNK_BYTES = 16384;
static constexpr size_t JPEG_MAX_PAYLOAD = 4194288u;
static constexpr size_t UPLOAD_MAX_PACKET_BYTES = 20u + JPEG_MAX_PAYLOAD;
static constexpr size_t UPLOAD_BURST_BYTES = 1024;
static constexpr uint32_t UPLOAD_FLOW_TIMEOUT_MS = 10000;
static constexpr uint32_t JPEG_READY_TIMEOUT_MS = 120000;
static size_t uploadExpectedPacketBytes=0,uploadHeaderBytes=0;
static uint16_t uploadFrameWidth=0,uploadFrameHeight=0;
static uint32_t uploadPayloadBytes=0;
static uint8_t uploadHeader[16];
// Fixed size code: 0 LCD, 1 HD, 2 local 256x224. Camera codes are unchanged.
static uint8_t uploadFrame1080=0;
uint16_t taskWidth(uint8_t size){return size==2?256:size==1?1920:1024;}
uint16_t taskHeight(uint8_t size){return size==2?224:size==1?1080:600;}
uint8_t geometrySize(uint8_t geometry){return (geometry&16)?2:(geometry&2)?1:0;}
static constexpr uint8_t UPLOAD_STATUS_PACKET_DONE = 1u << 0;
static constexpr uint8_t UPLOAD_STATUS_PACKET_GOOD = 1u << 1;
static constexpr uint8_t UPLOAD_STATUS_WRITER_ACTIVE = 1u << 2;
static constexpr uint8_t UPLOAD_STATUS_WRITER_SUCCESS = 1u << 3;
static constexpr uint8_t UPLOAD_STATUS_HOST_VALID = 1u << 4;
static constexpr uint8_t UPLOAD_STATUS_ERROR_MASK = 0xE0;

SPIClass fpgaSpi(VSPI);
WebServer http(80);
static bool httpCaptureBusy = false;
static volatile bool resultWorkerActive=false;
static String cachedFrameStatus,cachedBoardStatus;
void refreshFrameJobLock();
uint32_t fpgaTaskCookie();
bool matchingTask();
void invalidateTaskInput();
static bool httpUploadBusy = false;
static bool uploadSpiOpen = false;
static bool uploadResultOk = false;
static bool uploadAttemptFailed = false;
static size_t uploadBytesForwarded = 0;
static String uploadError;
static uint8_t streamTx[STREAM_CHUNK_BYTES];
static uint8_t streamRx[STREAM_CHUNK_BYTES];
#include "transport_diagnostics.h"

bool validFramePayload(uint32_t payload) {
  return payload >= 625u && payload <= JPEG_MAX_PAYLOAD && (payload & 15u)==0;
}

uint8_t fpgaRead(uint8_t address);
void fpgaWrite(uint8_t address, uint8_t value);
uint16_t fpgaRead16(uint8_t lowAddress);
bool waitForStatus(uint8_t mask, bool asserted, uint32_t timeoutMs);
bool waitForRegister(uint8_t address, uint8_t expected, uint8_t mask, uint32_t timeoutMs);

static const char CAPTURE_PAGE[] PROGMEM = R"HTML(<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ti60 屏摄抓拍</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;background:#111;color:#eee}header,main{max-width:1024px;margin:auto;padding:14px}h1{font-size:22px;margin:0 0 12px}nav{display:flex;gap:14px;margin-bottom:12px}nav a{color:#9ad;text-decoration:none}nav a.active{color:#fff;border-bottom:2px solid #24a148}.toolbar{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px}.modes{display:flex;gap:2px}.modes button{background:#333}.modes button.active{background:#1769aa}button{border:0;border-radius:5px;background:#eee;color:#111;font-size:16px;padding:10px 14px}button:disabled{opacity:.45}#capture{background:#24a148;color:#fff}#status{color:#9ad;font-size:14px}label{display:flex;align-items:center;gap:8px}input[type=range]{width:150px}canvas{width:100%;height:auto;background:#222;display:block}
/* Compact offline UI for phone screens. No external assets or fonts. */
.workflow [hidden]{display:none!important}
*{box-sizing:border-box}body{margin:0!important;padding:16px!important;background:#111820!important;color:#edf1f5!important;font:15px/1.5 system-ui,"Microsoft YaHei",sans-serif!important;max-width:1100px!important;margin-inline:auto!important}main{padding:0!important}h1{font-size:23px!important;line-height:1.3;margin:8px 0 16px!important}h2{font-size:17px!important;margin:18px 0 8px!important}p{line-height:1.5!important;margin:10px 0!important}nav{display:flex!important;gap:6px!important;flex-wrap:wrap!important;margin:0 0 18px!important;align-items:center}nav a{display:block;padding:8px 10px;background:#202c39;border-radius:5px;color:#b9cee4!important;text-decoration:none!important;font-size:14px;white-space:nowrap}nav a.active,nav a[aria-current="page"]{background:#164875;color:white!important;border:0!important}button{font:inherit!important;font-size:15px!important;min-height:42px!important;padding:9px 13px!important;margin:3px!important;border:1px solid #3d5061!important;border-radius:5px!important;background:#253444!important;color:#f0f4f8!important}button.active,button.primary,#run,#process,#capture{background:#157347!important;color:white!important}button:disabled{opacity:.45!important}input,select{font:inherit!important;max-width:100%;padding:6px;accent-color:#409fe8}input[type=file]{display:block;width:100%;margin:12px 0!important}input[type=checkbox]{width:18px;height:18px}input[type=range]{padding:0;min-width:120px}select{background:#202c39;color:#edf1f5;border:1px solid #3d5061;border-radius:4px}canvas{display:block!important;width:100%!important;height:auto!important;max-height:none;border:1px solid #33485a!important;border-radius:5px}progress{height:14px!important;margin:8px 0 16px!important;accent-color:#36a269;max-width:100%}#status{padding:10px 12px;background:#1e2b38;border-left:3px solid #409fe8;color:#d8e6f4!important;overflow-wrap:anywhere;min-height:42px;font-size:14px}#taskProgressLabel,#progressLabel{display:block;font-size:13px;color:#aabccd;margin-top:8px}details{padding:8px 0;border-top:1px solid #314252;margin:10px 0}summary{font-size:15px;cursor:pointer}.toolbar,.controls{gap:6px!important;flex-wrap:wrap!important;align-items:center}.note,.hint{font-size:13px!important;color:#aabccd!important}.workflow{padding:12px;background:#1e2b38;border:1px solid #314252;border-radius:6px;margin:12px 0}.workflow label{display:inline-flex;gap:8px;align-items:center;margin:6px 12px 6px 0}.images{gap:14px!important}@media(max-width:680px){.images{grid-template-columns:1fr!important}nav{gap:4px!important}nav a{padding:8px!important;font-size:13px}.toolbar button{flex:1 1 100px}body{padding:14px!important}}
</style><link rel="stylesheet" href="/ui.css"><script src="/transport-v4.js"></script><script defer src="/ui.js"></script>
<header><h1>Ti60 图像处理</h1><nav><a class="active" href="/">摄像头抓拍</a><a href="/local">本地图片</a><a href="/student">模型与联合处理</a><a href="/portrait">人像</a></nav><p>选择处理模式后抓拍。模型及组合处理请进入“模型与联合处理”。</p><div id="status">连接中</div></header>
<main><div class="toolbar modes" id="modes"><button data-mode="0">原图</button><button data-mode="1">灰阶图像</button><button data-mode="2">扫描文档</button><button data-mode="3">彩色课件增强</button></div><div class="toolbar modes" id="resolutions"><span>摄像头：</span><button data-resolution="0">720p</button><button data-resolution="1">1080p</button><button data-resolution="2">720p预览／1080p抓拍</button></div>
<div class="toolbar"><button id="capture">抓拍</button><button id="freeze">冻结</button><button id="resume">恢复</button><button id="download" disabled>下载JPEG</button></div>
<details><summary>高级处理选项</summary><div class="toolbar"><span>可选算法：</span><p class="note">灰阶曲线：拉开文字与背景层次，提升表格和浅字辨识度。色度平滑：针对细碎杂色与彩色网纹，保护文字明暗边缘。保色扫描增强：提亮文档、强化笔画对比，兼顾彩色标题与图表。中值去噪：清理孤立黑白颗粒，适合噪点较多的扫描资料；极细笔画建议关闭作对照。</p><label><input type="checkbox" class="alg" value="1">灰阶曲线（灰阶）</label><label><input type="checkbox" class="alg" value="2">色度平滑（彩色）</label><label><input type="checkbox" class="alg" value="4">保色扫描增强（彩色）</label><label><input type="checkbox" class="alg" value="8">中值去噪（扫描）</label></div></details><p style="color:#bbb;font-size:13px">抓拍按原分辨率处理与回传；1080p保持1920×1080。原图模式可另存原图。</p><button id="downloadRaw" disabled>下载抓拍原图</button><canvas id="view" width="1024" height="600"></canvas></main>
<script>
async function encodeJpegUpload(canvas){
 const w=canvas.width,h=canvas.height;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224)))throw Error('不支持的上传尺寸');
 const blob=await new Promise((ok,fail)=>canvas.toBlob(x=>x?ok(x):fail(Error('JPEG编码失败')),'image/jpeg',0.92));
 const raw=new Uint8Array(await blob.arrayBuffer());if(raw[0]!==255||raw[1]!==216)throw Error('JPEG生成失败');
 const n=((raw.length+15)&~15)+(w===256&&h===224?64:0);if(n>4194288)throw Error('JPEG超过4MiB，请降低图片复杂度');
 const packet=new Uint8Array(n+20),v=new DataView(packet.buffer);packet.set([85,74,73,71,1,2]);
 v.setUint16(6,w,true);v.setUint16(8,h,true);v.setUint32(10,n,true);packet.fill(255,16,n+16);packet.set(raw,16);
 v.setUint32(n+16,crc32(packet.subarray(16,n+16)),true);return packet;
}
async function decodeJpeg(bytes,canvas,expected){
 if(Ti60Transfer.isRaw(bytes))return Ti60Transfer.drawRaw(bytes,canvas,expected);
 Ti60Jpeg.validate(bytes,expected);
 const blob=new Blob([bytes],{type:'image/jpeg'}),url=URL.createObjectURL(blob),im=new Image();
 try{await new Promise((ok,fail)=>{im.onload=ok;im.onerror=()=>fail(Error('JPEG不完整或解码失败'));im.src=url});
 const w=im.naturalWidth,h=im.naturalHeight;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224))||(expected&&(w!==expected.width||h!==expected.height)))throw Error('返回尺寸与任务不一致');
 canvas.width=w;canvas.height=h;canvas.getContext('2d').drawImage(im,0,0);canvas.jpegBlob=blob;canvas.fpgaPixels=null;canvas.dataset.transport='jpeg';
 }finally{URL.revokeObjectURL(url)}
}
function saveJpeg(canvas,name){
 const save=blob=>{if(!blob)return;const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};
 if(canvas.correctedBlob){save(canvas.correctedBlob);}else if(canvas.cleanedBlob){name=name.replace(/\.jpg$/,'.png');save(canvas.cleanedBlob);}else if(canvas.jpegBlob)save(canvas.jpegBlob);else canvas.toBlob(save,'image/jpeg',0.92);
}


const progressBox=document.createElement('div');progressBox.innerHTML='<label id="taskProgressLabel" for="taskProgress">等待处理</label><progress id="taskProgress" max="100" value="0" style="display:block;width:100%;height:22px;margin:10px 0" aria-label="图像处理进度"></progress>';
document.querySelector('#status').after(progressBox);
function setTaskProgress(label,value){const bar=document.querySelector('#taskProgress');document.querySelector('#taskProgressLabel').textContent=label;if(value==null)bar.removeAttribute('value');else bar.value=Math.max(0,Math.min(100,value));}
new MutationObserver(()=>{const text=document.querySelector('#status').textContent;if(/^(完成|抓拍完成)/.test(text))setTaskProgress(text,100);else if(/^(失败|处理未完成|已停止)|超时/.test(text))setTaskProgress('处理已停止',0);}).observe(document.querySelector('#status'),{childList:true,subtree:true,characterData:true});
function progressFetch(url,options={}){
 if(url.startsWith('/capture')&&(!options.method||options.method==='GET'))return Ti60Transfer.read(url,{signal:options.signal,onprogress:setTaskProgress}).then(bytes=>new Response(bytes,{status:200,headers:{'Content-Type':'image/jpeg'}}));
 if(!/^\/(capture|api\/(upload|student\/batch))/.test(url))return fetch(url,options);
 const emit=(text,value)=>setTaskProgress(options.overallProgress==null?text:'模型总体 '+Math.floor(options.overallProgress)+'% · '+text,options.overallProgress==null?value:options.overallProgress);
 emit(options.waitLabel||(options.body?'正在上传':'正在采集 / FPGA处理（暂无内部计数）'),null);
 return new Promise((resolve,reject)=>{const x=new XMLHttpRequest();x.open(options.method||'GET',url);x.responseType='arraybuffer';
 for(const [k,v] of Object.entries(options.headers||{}))x.setRequestHeader(k,v);
 const abort=()=>x.abort();const cleanup=()=>options.signal?.removeEventListener('abort',abort);
 x.upload.onprogress=e=>emit(e.lengthComputable?'上传 '+Math.floor(e.loaded/e.total*100)+'%':'正在上传',e.lengthComputable?e.loaded/e.total*100:null);
 x.upload.onload=()=>emit('等待FPGA处理与回传（暂无内部计数）',null);
 x.onprogress=e=>{const total=e.lengthComputable?e.total:0;emit(total?'结果回传 '+Math.min(100,Math.floor(e.loaded/total*100))+'%':'结果回传 '+Math.floor(e.loaded/1024)+' KB',total?Math.min(99,e.loaded/total*100):null)};
 x.onload=()=>{cleanup();try{emit('正在校验结果',null);const headers={};for(const name of ['X-Student-CRC32','X-Portrait-CRC32','X-Portrait-Input-CRC32']){const value=x.getResponseHeader(name);if(value)headers[name]=value}resolve(new Response(x.response,{status:x.status,statusText:x.statusText,headers}));}catch(e){setTaskProgress('回传响应错误',0);reject(e)}};
 x.onerror=()=>{cleanup();setTaskProgress('网络中断',0);reject(Error('网络中断'));};
 x.onabort=()=>{cleanup();setTaskProgress('请求已取消或超时',0);reject(new DOMException('Aborted','AbortError'));};
 if(options.signal?.aborted){reject(new DOMException('Aborted','AbortError'));return;}
 options.signal?.addEventListener('abort',abort,{once:true});x.send(options.body||null);
 });
}

async function request(url,options={}){const controller=new AbortController,timer=setTimeout(()=>controller.abort(),300000);try{const response=await progressFetch(url,{...options,signal:controller.signal});const body=new Uint8Array(await response.arrayBuffer());if(!response.ok)throw Error(new TextDecoder().decode(body));return{ok:true,text:async()=>new TextDecoder().decode(body),json:async()=>JSON.parse(new TextDecoder().decode(body)),arrayBuffer:async()=>body.buffer}}catch(e){if(e.name==='AbortError')throw Error('请求超时，请点恢复后重试');throw e}finally{clearTimeout(timer)}}

const cap=document.querySelector('#capture'),freeze=document.querySelector('#freeze'),resume=document.querySelector('#resume'),download=document.querySelector('#download'),statusEl=document.querySelector('#status'),cv=document.querySelector('#view'),ctx=cv.getContext('2d');
const processedSource=document.createElement('canvas'),rawCapture=document.createElement('canvas'),rawDownload=document.querySelector('#downloadRaw');

async function makePacket(){return encodeJpegUpload(processedSource)}
let rawAvailable=false;
let captureModeChosen=false;let captureActive=false, transitionBusy=false, selectedMode=0, selectedResolution=0;
function crc32(a){let c=~0;for(const x of a){c^=x;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}return (~c)>>>0}
async function command(url){setTaskProgress('执行摄像头命令，等待板端确认',null);try{const r=await request(url,{method:'POST'});if(!r.ok)throw Error(await r.text());const text=await r.text();setTaskProgress('命令已确认',0);return text}catch(e){setTaskProgress('命令失败：'+e.message,0);throw e}}
function selectMode(mode){selectedMode=mode;updateAlgorithmOptions(mode);document.querySelectorAll('#modes button').forEach(b=>b.classList.toggle('active',+b.dataset.mode===mode))}
function selectResolution(value){selectedResolution=value;document.querySelectorAll('#resolutions button').forEach(b=>b.classList.toggle('active',+b.dataset.resolution===value))}
function setTransitionBusy(busy){transitionBusy=busy;document.querySelectorAll('button,input').forEach(x=>x.disabled=busy);cap.disabled=busy;download.disabled=busy||!download.disabled;statusEl.textContent=busy?'摄像头正在切换，等待画面稳定…':statusEl.textContent}
async function refresh(){if(captureActive||transitionBusy)return;try{const s=await(await request('/api/status',{cache:'no-store'})).json();if(!captureModeChosen)selectMode(s.mode);selectResolution(s.resolution);if(s.preview_restore_failed){statusEl.textContent='720p预览恢复失败，请点恢复重试';setTaskProgress('预览恢复失败',0);return}if(!cv.dataset.complete)statusEl.textContent=`FPGA 0x${s.id.toString(16).padStart(2,'0')} · ${s.camera?'摄像头在线':'摄像头无帧'} · ${s.frozen?'已冻结':'实时'} · ${s.ready?'帧就绪':''}`}catch(e){statusEl.textContent='状态读取失败'}}
document.querySelectorAll('#modes button').forEach(b=>b.onclick=async()=>{if(transitionBusy||captureActive)return;captureModeChosen=true;try{await command('/api/mode?value='+b.dataset.mode);selectMode(+b.dataset.mode)}catch(e){statusEl.textContent=e.message}});
document.querySelectorAll('#resolutions button').forEach(b=>b.onclick=async()=>{if(transitionBusy||captureActive)return;setTransitionBusy(true);try{await command('/api/resolution?value='+b.dataset.resolution);selectResolution(+b.dataset.resolution);statusEl.textContent='切换完成，画面已稳定';}catch(e){statusEl.textContent=e.message}finally{transitionBusy=false;document.querySelectorAll('button,input').forEach(x=>x.disabled=false);download.disabled=true;await refresh()}});
freeze.onclick=async()=>{try{await command('/api/freeze');await refresh()}catch(e){statusEl.textContent=e.message}};
resume.onclick=async()=>{try{await command('/api/resume');await refresh()}catch(e){statusEl.textContent=e.message}};
async function drawFrame(bytes,canvas,expectedMode){await decodeJpeg(bytes,canvas)}
cap.onclick=async()=>{
if(captureActive||transitionBusy)return;
const requestedMode=selectedMode,wireMode=requestedMode===2?1:requestedMode,alg=activeAlgorithms(selectedMode);
captureActive=true;Ti60Document.reset(cv);rawAvailable=false;document.querySelectorAll('button,input').forEach(x=>x.disabled=true);
try{
statusEl.textContent='抓拍并按原分辨率处理';const response=await request('/capture?mode='+wireMode+'&alg='+alg,{cache:'no-store',waitLabel:selectedResolution===2?'切换1080p，等待新完整帧（暂无内部计数）':'正在采集 / FPGA处理（暂无内部计数）'});
const bytes=new Uint8Array(await response.arrayBuffer());await drawFrame(bytes,cv,requestedMode);if(requestedMode===1||requestedMode===2)Ti60Document.assertNeutral(cv);if(requestedMode===2)await Ti60Document.finishCanvas(cv);if(requestedMode===3){await Ti60Screen.finishCourseware(cv);await Ti60CameraColor.finish(cv);}cv.dataset.complete='1';
if(requestedMode===0){await drawFrame(bytes,rawCapture,0);rawAvailable=true}
statusEl.textContent='完成 '+cv.width+'×'+cv.height+' · 原分辨率FPGA处理 · CRC通过'+(requestedMode===2?' · 扫描文档去阴影':requestedMode===3?' · 彩色课件增强':'');
}catch(e){Ti60Document.reset(cv);statusEl.textContent='失败: '+e.message}
finally{captureActive=false;document.querySelectorAll('button,input').forEach(x=>x.disabled=false);download.disabled=!cv.dataset.complete;rawDownload.disabled=!rawAvailable;selectMode(requestedMode)}
};
rawDownload.onclick=()=>saveJpeg(rawCapture,'ti60_capture_raw.jpg');
download.onclick=()=>saveJpeg(cv,'ti60_capture_'+Date.now()+'.jpg');
function algorithmMask(mode){return [0,1,8,6][mode]||0}
function moireBits(){const s=document.getElementById("moireMode");return s?Number(s.value):0}
function activeAlgorithms(mode){return ([...document.querySelectorAll(".alg:checked")].reduce((v,e)=>v|Number(e.value),0)&algorithmMask(mode))|moireBits()}
function updateAlgorithmOptions(mode){if(mode===3&&!updateAlgorithmOptions.colorInitialized){document.querySelector('.alg[value="2"]').checked=true;updateAlgorithmOptions.colorInitialized=true;}document.querySelectorAll(".alg").forEach(e=>{const compatible=!!(Number(e.value)&algorithmMask(mode));if(!compatible)e.checked=false;e.disabled=!compatible;e.parentElement.style.opacity=compatible?"1":"0.45"})}
updateAlgorithmOptions(selectedMode);refresh();setInterval(refresh,3000);
</script>)HTML";

static const char LOCAL_PAGE[] PROGMEM = R"HTML(<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ti60 本地图片处理</title>
<style>
*{box-sizing:border-box}body{font-family:system-ui,sans-serif;margin:0;background:#111;color:#eee}header,main{max-width:1100px;margin:auto;padding:14px}h1{font-size:22px;margin:0 0 12px}h2{font-size:16px;margin:0 0 8px;font-weight:500}nav{display:flex;gap:14px;margin-bottom:12px}nav a{color:#9ad;text-decoration:none}nav a.active{color:#fff;border-bottom:2px solid #24a148}.toolbar{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:12px}.group{display:flex;gap:2px}.group button{background:#333;color:#eee}.group button.active{background:#1769aa}.field{display:flex;gap:7px;align-items:center}button,select,input[type=file]{font:inherit}button{border:0;border-radius:5px;background:#eee;color:#111;padding:10px 14px;min-height:42px}button.primary{background:#24a148;color:#fff}button:disabled{opacity:.42}.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}.panel{min-width:0}.head{display:flex;justify-content:space-between;gap:8px;margin-bottom:6px;color:#bbb;font-size:14px}canvas{width:100%;height:auto;display:block;background:#222;border:1px solid #444;border-radius:5px}#source.can-drag{cursor:grab;touch-action:none}#source.dragging{cursor:grabbing}.status{min-height:24px;color:#9ad;margin:10px 0}.note{color:#bbb;font-size:13px}.processed{margin-top:16px}#processed{max-height:70vh;object-fit:contain}@media(max-width:680px){.grid{grid-template-columns:1fr}}
/* Compact offline UI for phone screens. No external assets or fonts. */
.workflow [hidden]{display:none!important}
*{box-sizing:border-box}body{margin:0!important;padding:16px!important;background:#111820!important;color:#edf1f5!important;font:15px/1.5 system-ui,"Microsoft YaHei",sans-serif!important;max-width:1100px!important;margin-inline:auto!important}main{padding:0!important}h1{font-size:23px!important;line-height:1.3;margin:8px 0 16px!important}h2{font-size:17px!important;margin:18px 0 8px!important}p{line-height:1.5!important;margin:10px 0!important}nav{display:flex!important;gap:6px!important;flex-wrap:wrap!important;margin:0 0 18px!important;align-items:center}nav a{display:block;padding:8px 10px;background:#202c39;border-radius:5px;color:#b9cee4!important;text-decoration:none!important;font-size:14px;white-space:nowrap}nav a.active,nav a[aria-current="page"]{background:#164875;color:white!important;border:0!important}button{font:inherit!important;font-size:15px!important;min-height:42px!important;padding:9px 13px!important;margin:3px!important;border:1px solid #3d5061!important;border-radius:5px!important;background:#253444!important;color:#f0f4f8!important}button.active,button.primary,#run,#process,#capture{background:#157347!important;color:white!important}button:disabled{opacity:.45!important}input,select{font:inherit!important;max-width:100%;padding:6px;accent-color:#409fe8}input[type=file]{display:block;width:100%;margin:12px 0!important}input[type=checkbox]{width:18px;height:18px}input[type=range]{padding:0;min-width:120px}select{background:#202c39;color:#edf1f5;border:1px solid #3d5061;border-radius:4px}canvas{display:block!important;width:100%!important;height:auto!important;max-height:none;border:1px solid #33485a!important;border-radius:5px}progress{height:14px!important;margin:8px 0 16px!important;accent-color:#36a269;max-width:100%}#status{padding:10px 12px;background:#1e2b38;border-left:3px solid #409fe8;color:#d8e6f4!important;overflow-wrap:anywhere;min-height:42px;font-size:14px}#taskProgressLabel,#progressLabel{display:block;font-size:13px;color:#aabccd;margin-top:8px}details{padding:8px 0;border-top:1px solid #314252;margin:10px 0}summary{font-size:15px;cursor:pointer}.toolbar,.controls{gap:6px!important;flex-wrap:wrap!important;align-items:center}.note,.hint{font-size:13px!important;color:#aabccd!important}.workflow{padding:12px;background:#1e2b38;border:1px solid #314252;border-radius:6px;margin:12px 0}.workflow label{display:inline-flex;gap:8px;align-items:center;margin:6px 12px 6px 0}.images{gap:14px!important}@media(max-width:680px){.images{grid-template-columns:1fr!important}nav{gap:4px!important}nav a{padding:8px!important;font-size:13px}.toolbar button{flex:1 1 100px}body{padding:14px!important}}
</style><link rel="stylesheet" href="/ui.css"><script src="/transport-v4.js"></script><script defer src="/ui.js"></script>
<header><h1>Ti60 图像处理</h1><nav><a href="/">摄像头抓拍</a><a class="active" href="/local">本地图片</a><a href="/student">模型与联合处理</a><a href="/portrait">人像</a></nav></header>
<main>
<div class="toolbar"><label class="field">选择图片 <input id="file" type="file" accept="image/jpeg,image/png,image/*"></label></div>
<div class="toolbar">
 <div class="group" id="targets"><button class="active" data-target="1024x600">1024×600</button><button data-target="1920x1080">1920×1080</button><button data-target="256x224">256×224 快速</button></div>
 <div class="group" id="orientations"><button class="active" data-orientation="landscape">横屏</button><button data-orientation="portrait">竖屏</button></div>
 <div class="group" id="fits"><button data-fit="contain">完整保留</button><button class="active" data-fit="cover">填满裁剪</button><button data-fit="pixel">原始像素裁剪</button></div>
</div>
<div class="grid"><section class="panel"><div class="head"><span>原图与保留区域</span><span id="sourceSize"></span></div><canvas id="source" width="800" height="500"></canvas></section><section class="panel"><div class="head"><span>转换结果</span><span id="targetSize">1024×600 RGB565</span></div><canvas id="converted" width="1024" height="600"></canvas></section></div>
<details><summary>高级处理选项</summary><div class="toolbar"><span>可选算法：</span><p class="note">灰阶曲线：拉开文字与背景层次，提升表格和浅字辨识度。色度平滑：针对细碎杂色与彩色网纹，保护文字明暗边缘。保色扫描增强：提亮文档、强化笔画对比，兼顾彩色标题与图表。中值去噪：清理孤立黑白颗粒，适合噪点较多的扫描资料；极细笔画建议关闭作对照。</p><label><input type="checkbox" class="alg" value="1">灰阶曲线（灰阶）</label><label><input type="checkbox" class="alg" value="2">色度平滑（彩色）</label><label><input type="checkbox" class="alg" value="4">保色扫描增强（彩色）</label><label><input type="checkbox" class="alg" value="8">中值去噪（扫描）</label></div></details>
<div class="toolbar"><span>FPGA处理：</span><div class="group" id="modes"><button class="active" data-mode="0">原图</button><button data-mode="1">灰阶图像</button><button data-mode="2">扫描文档</button><button data-mode="3">彩色课件增强</button></div><button id="process" class="primary" disabled>上传并处理</button><button id="download" disabled>下载JPEG</button></div>
<p class="note">本页执行FPGA传统处理；模型及组合处理请进入“模型与联合处理”。</p><div id="status" class="status">请选择本地图片</div><div id="limit" class="note">上传与处理支持256×224、1024×600或1920×1080，保持所选尺寸。</div>
<section class="processed"><h2>FPGA处理结果</h2><canvas id="processed" width="1024" height="600"></canvas></section>
</main>
<script>
async function encodeJpegUpload(canvas){
 const w=canvas.width,h=canvas.height;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224)))throw Error('不支持的上传尺寸');
 const blob=await new Promise((ok,fail)=>canvas.toBlob(x=>x?ok(x):fail(Error('JPEG编码失败')),'image/jpeg',0.92));
 const raw=new Uint8Array(await blob.arrayBuffer());if(raw[0]!==255||raw[1]!==216)throw Error('JPEG生成失败');
 const n=((raw.length+15)&~15)+(w===256&&h===224?64:0);if(n>4194288)throw Error('JPEG超过4MiB，请降低图片复杂度');
 const packet=new Uint8Array(n+20),v=new DataView(packet.buffer);packet.set([85,74,73,71,1,2]);
 v.setUint16(6,w,true);v.setUint16(8,h,true);v.setUint32(10,n,true);packet.fill(255,16,n+16);packet.set(raw,16);
 v.setUint32(n+16,crc32(packet.subarray(16,n+16)),true);return packet;
}
async function decodeJpeg(bytes,canvas,expected){
 if(Ti60Transfer.isRaw(bytes))return Ti60Transfer.drawRaw(bytes,canvas,expected);
 Ti60Jpeg.validate(bytes,expected);
 const blob=new Blob([bytes],{type:'image/jpeg'}),url=URL.createObjectURL(blob),im=new Image();
 try{await new Promise((ok,fail)=>{im.onload=ok;im.onerror=()=>fail(Error('JPEG不完整或解码失败'));im.src=url});
 const w=im.naturalWidth,h=im.naturalHeight;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224))||(expected&&(w!==expected.width||h!==expected.height)))throw Error('返回尺寸与任务不一致');
 canvas.width=w;canvas.height=h;canvas.getContext('2d').drawImage(im,0,0);canvas.jpegBlob=blob;canvas.fpgaPixels=null;canvas.dataset.transport='jpeg';
 }finally{URL.revokeObjectURL(url)}
}
function saveJpeg(canvas,name){
 const save=blob=>{if(!blob)return;const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};
 if(canvas.cleanedBlob){name=name.replace(/\.jpg$/,'.png');save(canvas.cleanedBlob);}else if(canvas.jpegBlob)save(canvas.jpegBlob);else canvas.toBlob(save,'image/jpeg',0.92);
}


const progressBox=document.createElement('div');progressBox.innerHTML='<label id="taskProgressLabel" for="taskProgress">等待处理</label><progress id="taskProgress" max="100" value="0" style="display:block;width:100%;height:22px;margin:10px 0" aria-label="图像处理进度"></progress>';
document.querySelector('#status').after(progressBox);
function setTaskProgress(label,value){const bar=document.querySelector('#taskProgress');document.querySelector('#taskProgressLabel').textContent=label;if(value==null)bar.removeAttribute('value');else bar.value=Math.max(0,Math.min(100,value));}
new MutationObserver(()=>{const text=document.querySelector('#status').textContent;if(/^(完成|抓拍完成)/.test(text))setTaskProgress(text,100);else if(/^(失败|处理未完成|已停止)|超时/.test(text))setTaskProgress('处理已停止',0);}).observe(document.querySelector('#status'),{childList:true,subtree:true,characterData:true});
function progressFetch(url,options={}){
 if(url.startsWith('/capture')&&(!options.method||options.method==='GET'))return Ti60Transfer.read(url,{signal:options.signal,onprogress:setTaskProgress}).then(bytes=>new Response(bytes,{status:200,headers:{'Content-Type':'image/jpeg'}}));
 if(!/^\/(capture|api\/(upload|student\/batch))/.test(url))return fetch(url,options);
 const emit=(text,value)=>setTaskProgress(options.overallProgress==null?text:'模型总体 '+Math.floor(options.overallProgress)+'% · '+text,options.overallProgress==null?value:options.overallProgress);
 emit(options.body?'正在上传':'正在采集 / FPGA处理',null);
 return new Promise((resolve,reject)=>{const x=new XMLHttpRequest();x.open(options.method||'GET',url);x.responseType='arraybuffer';
 for(const [k,v] of Object.entries(options.headers||{}))x.setRequestHeader(k,v);
 const abort=()=>x.abort();const cleanup=()=>options.signal?.removeEventListener('abort',abort);
 x.upload.onprogress=e=>emit(e.lengthComputable?'上传 '+Math.floor(e.loaded/e.total*100)+'%':'正在上传',e.lengthComputable?e.loaded/e.total*100:null);
 x.upload.onload=()=>emit('等待FPGA处理与回传（暂无内部计数）',null);
 x.onprogress=e=>{const total=e.lengthComputable?e.total:0;emit(total?'结果回传 '+Math.min(100,Math.floor(e.loaded/total*100))+'%':'结果回传 '+Math.floor(e.loaded/1024)+' KB',total?Math.min(99,e.loaded/total*100):null)};
 x.onload=()=>{cleanup();try{emit('正在校验结果',null);const headers={};for(const name of ['X-Student-CRC32','X-Portrait-CRC32','X-Portrait-Input-CRC32']){const value=x.getResponseHeader(name);if(value)headers[name]=value}resolve(new Response(x.response,{status:x.status,statusText:x.statusText,headers}));}catch(e){setTaskProgress('回传响应错误',0);reject(e)}};
 x.onerror=()=>{cleanup();setTaskProgress('网络中断',0);reject(Error('网络中断'));};
 x.onabort=()=>{cleanup();setTaskProgress('请求已取消或超时',0);reject(new DOMException('Aborted','AbortError'));};
 if(options.signal?.aborted){reject(new DOMException('Aborted','AbortError'));return;}
 options.signal?.addEventListener('abort',abort,{once:true});x.send(options.body||null);
 });
}

async function request(url,options={}){const controller=new AbortController,timer=setTimeout(()=>controller.abort(),300000);try{const response=await progressFetch(url,{...options,signal:controller.signal});const body=new Uint8Array(await response.arrayBuffer());if(!response.ok)throw Error(new TextDecoder().decode(body));return{ok:true,text:async()=>new TextDecoder().decode(body),json:async()=>JSON.parse(new TextDecoder().decode(body)),arrayBuffer:async()=>body.buffer}}catch(e){if(e.name==='AbortError')throw Error('请求超时，请点恢复后重试');throw e}finally{clearTimeout(timer)}}

const q=s=>document.querySelector(s),qa=s=>[...document.querySelectorAll(s)];
const file=q('#file'),src=q('#source'),dst=q('#converted'),out=q('#processed'),status=q('#status'),processBtn=q('#process'),download=q('#download');
let imageLoadTicket=0;let image=null,imageUrl=null,target='1024x600',orientation='landscape',fit='cover',mode=0,busy=false,focusX=50,focusY=50,cropView=null,drag=null;
function dims(){let [w,h]=target.split('x').map(Number);return orientation==='portrait'?{w:h,h:w}:{w,h}}
function crop(sw,sh,tw,th){const sr=sw/sh,tr=tw/th;let w=sw,h=sh;if(sr>tr)w=sh*tr;else h=sw/tr;return{x:(sw-w)*focusX/100,y:(sh-h)*focusY/100,w,h}}
function pixelCrop(sw,sh,tw,th){const w=Math.min(sw,tw),h=Math.min(sh,th);return{x:(sw-w)*focusX/100,y:(sh-h)*focusY/100,w,h,dx:(tw-w)/2,dy:(th-h)/2}}
function rememberCrop(c,ox,oy,ss,sw,sh){cropView={x:ox+c.x*ss,y:oy+c.y*ss,w:c.w*ss,h:c.h*ss,cx:c.x,cy:c.y,cw:c.w,ch:c.h,ss,sw,sh}}
function updateButtons(group,key,value){qa(group+' button').forEach(b=>b.classList.toggle('active',b.dataset[key]===String(value)))}
function available(){const d=dims();return !!image&&!busy}
function render(){const d=dims();dst.width=d.w;dst.height=d.h;dst.style.aspectRatio=d.w+'/'+d.h;q('#targetSize').textContent=d.w+'×'+d.h+' JPEG';processBtn.disabled=!available();cropView=null;src.classList.toggle('can-drag',fit!=='contain'&&!!image);if(!image)return;const sw=image.naturalWidth||image.width,sh=image.naturalHeight||image.height;q('#sourceSize').textContent=sw+'×'+sh;const sc=src.getContext('2d'),dc=dst.getContext('2d');sc.clearRect(0,0,src.width,src.height);sc.fillStyle='#222';sc.fillRect(0,0,src.width,src.height);const ss=Math.min(src.width/sw,src.height/sh),ox=(src.width-sw*ss)/2,oy=(src.height-sh*ss)/2;sc.drawImage(image,ox,oy,sw*ss,sh*ss);dc.fillStyle='#222';dc.fillRect(0,0,d.w,d.h);if(fit==='contain'){const s=Math.min(d.w/sw,d.h/sh),dw=sw*s,dh=sh*s;dc.drawImage(image,(d.w-dw)/2,(d.h-dh)/2,dw,dh);status.textContent='完整保留原图，未填满区域保留。'}else if(fit==='pixel'){const c=pixelCrop(sw,sh,d.w,d.h);dc.drawImage(image,c.x,c.y,c.w,c.h,c.dx,c.dy,c.w,c.h);sc.fillStyle='rgba(0,0,0,.5)';sc.fillRect(ox,oy,sw*ss,c.y*ss);sc.fillRect(ox,oy+(c.y+c.h)*ss,sw*ss,(sh-c.y-c.h)*ss);sc.fillRect(ox,oy+c.y*ss,c.x*ss,c.h*ss);sc.fillRect(ox+(c.x+c.w)*ss,oy+c.y*ss,(sw-c.x-c.w)*ss,c.h*ss);sc.strokeStyle='#36a269';sc.lineWidth=4;sc.strokeRect(ox+c.x*ss,oy+c.y*ss,c.w*ss,c.h*ss);rememberCrop(c,ox,oy,ss,sw,sh);status.textContent='原始像素1:1裁剪，保留原图区域 '+(c.w*c.h/sw/sh*100).toFixed(1)+'%，没有缩放。'}else{const c=crop(sw,sh,d.w,d.h);dc.drawImage(image,c.x,c.y,c.w,c.h,0,0,d.w,d.h);sc.fillStyle='rgba(0,0,0,.5)';sc.fillRect(ox,oy,sw*ss,c.y*ss);sc.fillRect(ox,oy+(c.y+c.h)*ss,sw*ss,(sh-c.y-c.h)*ss);sc.fillRect(ox,oy+c.y*ss,c.x*ss,c.h*ss);sc.fillRect(ox+(c.x+c.w)*ss,oy+c.y*ss,(sw-c.x-c.w)*ss,c.h*ss);sc.strokeStyle='#36a269';sc.lineWidth=4;sc.strokeRect(ox+c.x*ss,oy+c.y*ss,c.w*ss,c.h*ss);rememberCrop(c,ox,oy,ss,sw,sh);status.textContent='填满画面，保留原图区域 '+(c.w*c.h/sw/sh*100).toFixed(1)+'%。直接拖动绿色取景框可调整位置。'}}
function crc32(a){let c=0xffffffff;for(const x of a){c^=x;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}return (~c)>>>0}

async function makePacket(){return encodeJpegUpload(dst)}
async function showJpeg(b,expectedMode){await decodeJpeg(b,out,{width:dst.width,height:dst.height})}
file.onchange=()=>{const f=file.files&&file.files[0];if(!f||busy)return;const ticket=++imageLoadTicket;image=null;download.disabled=true;Ti60Document.reset(out);if(imageUrl)URL.revokeObjectURL(imageUrl);imageUrl=URL.createObjectURL(f);const im=new Image;im.onload=()=>{if(ticket!==imageLoadTicket)return;image=im;render()};im.onerror=()=>status.textContent='图片读取失败';im.src=imageUrl};
qa('#targets button').forEach(b=>b.onclick=()=>{target=b.dataset.target;updateButtons('#targets','target',target);render()});qa('#orientations button').forEach(b=>b.onclick=()=>{orientation=b.dataset.orientation;updateButtons('#orientations','orientation',orientation);render()});qa('#fits button').forEach(b=>b.onclick=()=>{fit=b.dataset.fit;updateButtons('#fits','fit',fit);render()});qa('#modes button').forEach(b=>b.onclick=()=>{mode=+b.dataset.mode;updateButtons('#modes','mode',mode);updateAlgorithmOptions(mode)});
function canvasPoint(e){const r=src.getBoundingClientRect();return{x:(e.clientX-r.left)*src.width/r.width,y:(e.clientY-r.top)*src.height/r.height}}
src.onpointerdown=e=>{if(!cropView)return;const p=canvasPoint(e),c=cropView;if(p.x<c.x||p.x>c.x+c.w||p.y<c.y||p.y>c.y+c.h)return;drag={id:e.pointerId,x:p.x,y:p.y,cx:c.cx,cy:c.cy,cw:c.cw,ch:c.ch,ss:c.ss,sw:c.sw,sh:c.sh};src.setPointerCapture(e.pointerId);src.classList.add('dragging');e.preventDefault()};
src.onpointermove=e=>{if(!drag||drag.id!==e.pointerId)return;const p=canvasPoint(e),maxX=drag.sw-drag.cw,maxY=drag.sh-drag.ch,newX=Math.max(0,Math.min(maxX,drag.cx+(p.x-drag.x)/drag.ss)),newY=Math.max(0,Math.min(maxY,drag.cy+(p.y-drag.y)/drag.ss));focusX=maxX?newX/maxX*100:50;focusY=maxY?newY/maxY*100:50;render();e.preventDefault()};
function stopDrag(e){if(!drag||drag.id!==e.pointerId)return;drag=null;src.classList.remove('dragging')}
src.onpointerup=stopDrag;src.onpointercancel=stopDrag;
function algorithmMask(mode){return [0,1,8,6][mode]||0}
function moireBits(){const s=document.getElementById("moireMode");return s?Number(s.value):0}
function activeAlgorithms(mode){return ([...document.querySelectorAll(".alg:checked")].reduce((v,e)=>v|Number(e.value),0)&algorithmMask(mode))|moireBits()}
function updateAlgorithmOptions(mode){if(mode===3&&!updateAlgorithmOptions.colorInitialized){document.querySelector('.alg[value="2"]').checked=true;updateAlgorithmOptions.colorInitialized=true;}document.querySelectorAll(".alg").forEach(e=>{const compatible=!!(Number(e.value)&algorithmMask(mode));if(!compatible)e.checked=false;e.disabled=!compatible;e.parentElement.style.opacity=compatible?"1":"0.45"})}
updateAlgorithmOptions(mode);
processBtn.onclick=async()=>{if(!available())return;if(orientation!=='landscape'){status.textContent='FPGA上传支持横屏，请选择横屏';return}render();const requestedMode=mode;const wireMode=requestedMode===2?1:requestedMode;busy=true;Ti60Document.reset(out);processBtn.disabled=true;download.disabled=true;qa('button,input').forEach(b=>b.disabled=true);status.textContent='正在编码JPEG';try{const packet=await makePacket(),form=new FormData;const scanInput=new Blob([packet.subarray(16,packet.length-4)],{type:'image/jpeg'});form.append('frame',new Blob([packet],{type:'application/octet-stream'}),'frame.ujig');status.textContent='正在上传FPGA';let r=await request('/api/upload?size='+(dst.width===256?2:dst.width===1920?1:0)+'&mode='+wireMode+'&alg='+activeAlgorithms(requestedMode),{method:'POST',body:form});if(!r.ok)throw Error(await r.text());status.textContent='FPGA正在处理并回传';r=await request('/capture?source=upload&mode='+wireMode,{cache:'no-store'});if(!r.ok)throw Error(await r.text());try{await showJpeg(new Uint8Array(await r.arrayBuffer()),requestedMode);if(requestedMode===1||requestedMode===2)Ti60Document.assertNeutral(out);}catch(e){if(e.code!=='JPEG_CONTENT')throw e;status.textContent='JPEG 内容异常，重读本次上传的原始像素';const retry=await Ti60Transfer.read('/capture?source=upload&format=rgb565&mode='+wireMode,{strategy:'direct',spiMHz:5,timeoutMs:60000,onprogress:setTaskProgress});if(!Ti60Transfer.isRaw(retry))throw Error('原始像素恢复失败');await showJpeg(retry,requestedMode);if(requestedMode===1||requestedMode===2)Ti60Document.assertNeutral(out);out.dataset.recovery='rgb565';}out.scanInputBlob=(requestedMode===2&&(activeAlgorithms(requestedMode)&8))?null:scanInput;if(requestedMode===3)await Ti60Screen.finishCourseware(out);if(requestedMode===2)await Ti60Document.finishCanvas(out);out.dataset.complete='1';download.disabled=false;status.textContent='完成 '+out.width+'×'+out.height+' · 上传及回传CRC通过'+(requestedMode===2?' · 扫描文档去阴影':requestedMode===3?' · 彩色课件增强':'')}catch(e){Ti60Document.reset(out);status.textContent='失败：'+e.message}finally{busy=false;qa('button,input').forEach(b=>b.disabled=false);download.disabled=!out.dataset.complete;processBtn.disabled=!available();updateAlgorithmOptions(mode)}};
download.onclick=()=>saveJpeg(out,'ti60_local_'+Date.now()+'.jpg');
</script>)HTML";

 

bool uploadCommitAccepted(uint8_t status,uint32_t received,uint32_t expected){
  const uint8_t committed=UPLOAD_STATUS_PACKET_GOOD|UPLOAD_STATUS_WRITER_SUCCESS|UPLOAD_STATUS_HOST_VALID;
  return expected!=0 && received==expected && (status&committed)==committed &&
         (status&(UPLOAD_STATUS_ERROR_MASK|UPLOAD_STATUS_WRITER_ACTIVE))==0;
}

bool writeHttpBytes(WiFiClient &client, const uint8_t *data, size_t length) {
  uint32_t lastProgress = millis();
  while (length) {
    if (!client.connected() || millis() - lastProgress > 15000) return false;
    size_t written = client.write(data, length);
     
    if (!written) { delay(2); continue; }
    lastProgress = millis();
    data += written;
    length -= written;
    if(length)delay(1);
  }
  return true;
}

bool writeHttpChunk(WiFiClient &client, const uint8_t *data, size_t length) {
  char line[12];
  int count = snprintf(line, sizeof(line), "%X\r\n", (unsigned)length);
  if (!writeHttpBytes(client, (const uint8_t *)line, count)) return false;
  if (length && !writeHttpBytes(client, data, length)) return false;
  return writeHttpBytes(client, (const uint8_t *)"\r\n", 2);
}

 
static uint8_t cameraSelection=0;
static bool hybridFrameActive=false;
static bool hybridRestoreFailed=false;

bool switchCameraPhysical(uint8_t resolution){
  if(resolution>1)return false;
  fpgaWrite(REG_CONTROL,0x02);
  if(!waitForStatus(STATUS_FROZEN,false,FREEZE_TIMEOUT_MS))return false;
  if(!waitForStatus(STATUS_FRAME_READY,false,1000))return false;
  if((fpgaRead(REG_RESOLUTION)&3)!=resolution){
    fpgaWrite(REG_RESOLUTION,resolution);
    if(!waitForRegister(REG_RESOLUTION,resolution,3,250))return false;
    delay(RESOLUTION_SETTLE_MS);
  }
   
  const uint16_t before=fpgaRead16(REG_CAM_FRAME_LO);
  const uint32_t start=millis();
  while(millis()-start<FREEZE_TIMEOUT_MS){
    const uint8_t config=fpgaRead(REG_I2C_STATUS);
    const uint16_t frames=fpgaRead16(REG_CAM_FRAME_LO);
    const uint16_t lines=fpgaRead16(REG_CAM_LINES_LO);
    const uint16_t minBytes=fpgaRead16(REG_CAM_MIN_LO),maxBytes=fpgaRead16(REG_CAM_MAX_LO);
    const uint16_t after=fpgaRead16(REG_CAM_FRAME_LO);
    if(frames==after && (config&7)==1 && uint16_t(frames-before)>=2 &&
       lines==(resolution?1080:720) && minBytes==(resolution?3840:2560) && maxBytes==minBytes)return true;
    delay(10);
  }
  return false;
}

bool restoreHybridPreview(){
  if(!hybridFrameActive && !hybridRestoreFailed)return true;
  const bool ok=switchCameraPhysical(0);
  hybridFrameActive=!ok;hybridRestoreFailed=!ok;
  return ok;
}

bool selectCamera(uint8_t selection){
  if(selection>2)return false;
  const uint8_t previous=cameraSelection;
  if(!switchCameraPhysical(selection==1?1:0)){
     
    if(previous==2){hybridFrameActive=true;restoreHybridPreview();}
    else switchCameraPhysical(previous==1?1:0);
    return false;
  }
  cameraSelection=selection;hybridFrameActive=false;hybridRestoreFailed=false;
  return true;
}

bool beginHybridCapture(){
  if(cameraSelection!=2)return true;
  if(hybridFrameActive && (fpgaRead(REG_RESOLUTION)&3)==1 && (fpgaRead(REG_STATUS)&STATUS_FROZEN))return true;
  hybridFrameActive=true;
  if(switchCameraPhysical(1))return true;
  restoreHybridPreview();
  return false;
}


static bool captureRawOutput=false;
static bool capturePreviewOutput=false;

static uint32_t preparedStreamBytes=0;
 

void drainFrameBytes(uint32_t remaining){
  memset(streamTx,0,sizeof(streamTx));
  while(remaining){size_t n=remaining>sizeof(streamRx)?sizeof(streamRx):remaining;
    fpgaSpi.transferBytes(streamTx,streamRx,n);remaining-=n;delay(1);}
}
void prepareStreamLength(){
 preparedStreamBytes=0;
 if(fpgaRead(0x1e)==0x52){for(int i=0;i<3;i++)preparedStreamBytes|=uint32_t(fpgaRead(3+i))<<(8*i);
  if(!validFramePayload(preparedStreamBytes))preparedStreamBytes=0;}
}
static uint8_t capturePrepareStage=0;
static uint32_t captureFreezeMs=0,captureEncodeMs=0;
bool prepareFrameStream(uint8_t header[FRAME_HEADER_BYTES], uint32_t &payload, uint8_t requestedMode) {
  const uint32_t freezeStarted=millis();captureFreezeMs=0;captureEncodeMs=0;
   


  if (requestedMode > 3 || fpgaRead(0x36)!=0xa3) return false;
  const bool reuseHybridFrozen=cameraSelection==2 && hybridFrameActive && (fpgaRead(REG_RESOLUTION)&3)==1 && (fpgaRead(REG_STATUS)&STATUS_FROZEN) && (fpgaRead(REG_STATUS)&STATUS_FRAME_READY);
  capturePrepareStage=1;
  if (!beginHybridCapture()) return false;
   

  if ((fpgaRead(REG_RESOLUTION) & 0x03) == 1)
    delay(RESOLUTION_SETTLE_MS);
  capturePrepareStage=2;
  fpgaWrite(REG_SCAN_MODE, requestedMode);
  if (!waitForRegister(REG_SCAN_MODE, requestedMode, 0x03, 250)) return false;

  capturePrepareStage=3;
  if (!reuseHybridFrozen) {
   

  if (fpgaRead(REG_STATUS) & STATUS_FROZEN) {
    fpgaWrite(REG_CONTROL, 0x02);
    if (!waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS)) return false;
  }
  capturePrepareStage=4;
  if (!waitForStatus(STATUS_FRAME_READY, false, 1000)) return false;
  capturePrepareStage=5;
  if (!waitForStatus(1u << 4, true, 1000)) return false;
   


  capturePrepareStage=6;
  fpgaWrite(REG_CONTROL, 0x01);
  if (!waitForStatus(STATUS_FROZEN, true, FREEZE_TIMEOUT_MS)) return false;
  capturePrepareStage=7;
  if (!waitForStatus(STATUS_FRAME_READY, true, 5000)) return false;
  }
  captureFreezeMs=millis()-freezeStarted;const uint32_t encodeStarted=millis();
  capturePrepareStage=8;
  fpgaWrite(REG_CONTROL, capturePreviewOutput ? 0x88 : captureRawOutput ? 0x48 : 0x08);
  if (!waitForStatus(STATUS_STREAM_READY, true, capturePreviewOutput ? 4000 : JPEG_READY_TIMEOUT_MS)) return false;
  captureEncodeMs=millis()-encodeStarted;
  prepareStreamLength();
  fpgaWrite(REG_CONTROL, 0x10);
   
  delayMicroseconds(20);
  memset(streamTx, 0, sizeof(streamTx));
  fpgaSpi.beginTransaction(SPISettings(SPI_HZ_CONTROL, MSBFIRST, SPI_MODE0));
  digitalWrite(PIN_CS, LOW);
  delayMicroseconds(2);
  fpgaSpi.transferBytes(streamTx, header, FRAME_HEADER_BYTES);
   
  fpgaSpi.endTransaction();
  fpgaSpi.beginTransaction(SPISettings(captureStreamHz, MSBFIRST, SPI_MODE0));
  capturePrepareStage=9;
  uint8_t expectedStreamMode = requestedMode;
  if (memcmp(header, "JPIC", 4) != 0 || header[4] != 1 || header[5] != (captureRawOutput ? 3 : 2) ||
      header[14] != expectedStreamMode) {
    if(preparedStreamBytes)drainFrameBytes(preparedStreamBytes+4);payload=0;
    digitalWrite(PIN_CS, HIGH); fpgaSpi.endTransaction();
    fpgaWrite(REG_CONTROL, 0x02);
    waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS);
    return false;
  }
  payload = (uint32_t)header[10] | ((uint32_t)header[11] << 8) |
            ((uint32_t)header[12] << 16) | ((uint32_t)header[13] << 24);
  const uint16_t frameWidth=uint16_t(header[6])|(uint16_t(header[7])<<8);
  const uint16_t frameHeight=uint16_t(header[8])|(uint16_t(header[9])<<8);
  const bool hybridSizeValid=capturePreviewOutput ? (frameWidth==512 && frameHeight==300) : cameraSelection!=2 || (frameWidth==1920 && frameHeight==1080 && validFramePayload(payload));
  if (!validFramePayload(payload) || !hybridSizeValid || (captureRawOutput && payload!=uint32_t(frameWidth)*frameHeight*2) || (preparedStreamBytes && payload!=preparedStreamBytes)) {
    if(preparedStreamBytes)drainFrameBytes(preparedStreamBytes+4);payload=0;
    digitalWrite(PIN_CS, HIGH); fpgaSpi.endTransaction();
    fpgaWrite(REG_CONTROL, 0x02);
    waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS);
    return false;
  }
  return true;
}

bool waitForUploadedStatus(uint8_t mask, bool expected, uint32_t timeoutMs) {
  const uint32_t started=millis();
  while(millis()-started<timeoutMs){
    if(httpCaptureBusy && !resultWorkerActive && !http.client().connected())return false;
    const uint8_t status=fpgaRead(REG_STATUS);
    if(((status&mask)==mask)==expected)return true;
    if(mask==STATUS_STREAM_READY && (fpgaRead(0x38)&0x80))return false;
    delay(2);
  }
  return false;
}

bool prepareUploadedFrameStream(uint8_t header[FRAME_HEADER_BYTES], uint32_t &payload,
                                uint8_t requestedMode, uint8_t frameSelection=0) {
  capturePrepareStage=20;
  if (requestedMode > 3 || fpgaRead(0x36)!=0xa3) return false;
  if(frameSelection){
    capturePrepareStage=21;
    if(fpgaRead(0x60)!=0xd2 || (fpgaRead(0x4d)&7)!=2)return false;
    if(!(fpgaRead(REG_STATUS)&STATUS_FROZEN))fpgaWrite(REG_CONTROL,1);
    if(!waitForStatus(STATUS_FROZEN,true,FREEZE_TIMEOUT_MS)||!waitForStatus(STATUS_FRAME_READY,true,5000))return false;
    capturePrepareStage=22;
    fpgaWrite(0x4c,frameSelection);
    if(!waitForRegister(0x4e,frameSelection==8?4:1,5,250))return false;
  }else{
    if (!(fpgaRead(REG_UPLOAD_STATUS) & UPLOAD_STATUS_HOST_VALID)) return false;
    if(fpgaRead(0x60)==0xd2)fpgaWrite(0x4c,0);
    if(!(fpgaRead(REG_STATUS)&STATUS_FROZEN))fpgaWrite(REG_CONTROL,1);
    if(!waitForUploadedStatus(STATUS_FROZEN,true,FREEZE_TIMEOUT_MS))return false;
    if(!waitForStatus(STATUS_BUSY | STATUS_STREAM_READY,false,1000))return false;
  }
  const bool nativeUploadSupported=fpgaRead(0x36)==0xa3;
  // Read capability before owning the streaming SPI transaction.
  const bool localUploadSupported=fpgaRead(0x4f)==0x82;
  capturePrepareStage=23;
  fpgaWrite(REG_SCAN_MODE, requestedMode);
  if (!waitForRegister(REG_SCAN_MODE, requestedMode, 0x03, 250)) return false;
   
  fpgaWrite(REG_CONTROL, captureRawOutput ? 0x68 : 0x28);
  capturePrepareStage=24;
  if (!(frameSelection ? waitForStatus(STATUS_STREAM_READY,true,JPEG_READY_TIMEOUT_MS) :
        waitForUploadedStatus(STATUS_STREAM_READY,true,30000))) return false;
  prepareStreamLength();
  fpgaWrite(REG_CONTROL, 0x10);
   
  delayMicroseconds(20);
  memset(streamTx, 0, sizeof(streamTx));
  fpgaSpi.beginTransaction(SPISettings(SPI_HZ_CONTROL, MSBFIRST, SPI_MODE0));
  digitalWrite(PIN_CS, LOW);
  delayMicroseconds(2);
  fpgaSpi.transferBytes(streamTx, header, FRAME_HEADER_BYTES);
   
  fpgaSpi.endTransaction();
  fpgaSpi.beginTransaction(SPISettings(captureStreamHz, MSBFIRST, SPI_MODE0));
  payload = (uint32_t)header[10] | ((uint32_t)header[11] << 8) |
            ((uint32_t)header[12] << 16) | ((uint32_t)header[13] << 24);
  capturePrepareStage=25;
  uint16_t width = (uint16_t)header[6] | ((uint16_t)header[7] << 8);
  uint16_t height = (uint16_t)header[8] | ((uint16_t)header[9] << 8);
  if (memcmp(header, "JPIC", 4) != 0 || header[4] != 1 || header[5] != (captureRawOutput ? 3 : 2) ||
      !((width==1024&&height==600&&validFramePayload(payload))||(nativeUploadSupported&&width==1920&&height==1080&&validFramePayload(payload))||(localUploadSupported&&width==256&&height==224&&validFramePayload(payload))) ||
      header[14] != requestedMode || (captureRawOutput && payload!=uint32_t(width)*height*2) || (preparedStreamBytes && payload!=preparedStreamBytes)) {
    if(preparedStreamBytes)drainFrameBytes(preparedStreamBytes+4);payload=0;
    digitalWrite(PIN_CS, HIGH);
    fpgaSpi.endTransaction();
    if(!frameSelection)fpgaWrite(REG_CONTROL, 0x02);
    return false;
  }
  return true;
}

void cleanupCapturePrepareFailure(uint8_t frameSelection) {
   

  if(!frameSelection){
    fpgaWrite(REG_CONTROL, 0x02);
    waitForStatus(STATUS_BUSY | STATUS_STREAM_READY, false, 1000);
    restoreHybridPreview();
  }
}

void finishFrameStream() {
  digitalWrite(PIN_CS, HIGH);
  fpgaSpi.endTransaction();
  delay(2);
  fpgaWrite(REG_CONTROL, 0x02);
  if (!waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS))
    Serial.println("WARNING: FPGA resume timeout after stream");
  if (!waitForStatus(STATUS_FRAME_READY, false, 1000))
    Serial.println("WARNING: stale frame_ready after stream");
  if (!restoreHybridPreview()) Serial.println("WARNING: hybrid 720p preview restore failed; retry resume");
}

void handleRoot() { http.send_P(200, "text/html; charset=utf-8", CAPTURE_PAGE); }
void handleLocalPage() { http.send_P(200, "text/html; charset=utf-8", LOCAL_PAGE); }

String boardStatusJson() {
  uint8_t id = fpgaRead(REG_DEVICE_ID);
  uint8_t version = fpgaRead(REG_VERSION);
  uint8_t status = fpgaRead(REG_STATUS);
  uint8_t mode = fpgaRead(REG_SCAN_MODE) & 0x03;
  uint8_t resolution = cameraSelection;
  uint8_t i2cIndex = fpgaRead(REG_I2C_INDEX);
  uint8_t i2cStatus = fpgaRead(REG_I2C_STATUS);
  uint8_t i2cFirstNack = fpgaRead(REG_I2C_FIRST_NACK);
  uint8_t i2cNackCount = fpgaRead(REG_I2C_NACK_COUNT);
  uint8_t brightness = fpgaRead(REG_PWM) & 0x7F;
  char body[768];
  snprintf(body, sizeof(body),
           "{\"id\":%u,\"version\":%u,\"status\":%u,\"mode\":%u,\"resolution\":%u,\"brightness\":%u,"
           "\"frozen\":%s,\"busy\":%s,\"camera\":%s,\"ready\":%s,\"preview_restore_failed\":%s}",
           id, version, status, mode, resolution, brightness,
           (status & STATUS_FROZEN) ? "true" : "false",
           (status & STATUS_BUSY) ? "true" : "false",
           (status & (1u << 4)) ? "true" : "false",
           (status & STATUS_FRAME_READY) ? "true" : "false", hybridRestoreFailed ? "true" : "false");
  String diagnostics=body;
  diagnostics.remove(diagnostics.length()-1);
  diagnostics+=",\"firmware\":\"F9-V8-1031-SPI\",\"frame_capability\":";diagnostics+=fpgaRead(0x60);
  diagnostics+=",\"pixel_stream_capability\":";diagnostics+=fpgaRead(0x1e);
  diagnostics+=",\"frame_state\":";diagnostics+=fpgaRead(0x4d);
  diagnostics+=",\"portrait_state\":";diagnostics+=fpgaRead(0x51);
  diagnostics+=",\"upload_status\":";diagnostics+=fpgaRead(REG_UPLOAD_STATUS);
  diagnostics+=",\"camera_frames\":";diagnostics+=fpgaRead16(REG_CAM_FRAME_LO);
  diagnostics+=",\"camera_lines\":";diagnostics+=fpgaRead16(REG_CAM_LINES_LO);
  diagnostics+=",\"camera_min_bytes\":";diagnostics+=fpgaRead16(REG_CAM_MIN_LO);
  diagnostics+=",\"camera_max_bytes\":";diagnostics+=fpgaRead16(REG_CAM_MAX_LO);
  diagnostics+=",\"i2c_index\":";diagnostics+=i2cIndex;
  diagnostics+=",\"i2c_status\":";diagnostics+=i2cStatus;
  diagnostics+=",\"i2c_first_nack\":";diagnostics+=i2cFirstNack;
  diagnostics+=",\"i2c_nack_count\":";diagnostics+=i2cNackCount;diagnostics+="}";
  return diagnostics;
}
void handleStatusHttp(){http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",resultWorkerActive?cachedBoardStatus:boardStatusJson());}

void handleModeHttp() {
  refreshFrameJobLock();
  if (httpCaptureBusy || httpUploadBusy) { http.send(409,"text/plain","已有图像任务占用，请查询模型或人像状态；计算中不能切换摄像头"); return; }
  if (!http.hasArg("value")) { http.send(400, "text/plain", "missing value"); return; }
  int value = http.arg("value").toInt();
  if (value < 0 || value > 3) { http.send(400, "text/plain", "mode must be 0..3"); return; }
  fpgaWrite(REG_SCAN_MODE, static_cast<uint8_t>(value));
  if (!waitForRegister(REG_SCAN_MODE, static_cast<uint8_t>(value), 0x03, 250)) {
    http.send(504, "text/plain; charset=utf-8", "FPGA模式设置超时");
    return;
  }
  http.send(200, "text/plain", "OK");
}

void handleResolutionHttp() {
  refreshFrameJobLock();
  if (httpCaptureBusy || httpUploadBusy) { http.send(409,"text/plain","已有图像任务占用，请查询模型或人像状态；计算中不能切换摄像头"); return; }
  if (!http.hasArg("value")) { http.send(400, "text/plain", "missing value"); return; }
  int value = http.arg("value").toInt();
  if (value < 0 || value > 2) { http.send(400, "text/plain", "resolution must be 0..2"); return; }
  invalidateTaskInput();
  if (!selectCamera(static_cast<uint8_t>(value))) {
    http.send(504, "text/plain; charset=utf-8", "摄像头切换超时，未收到新分辨率完整帧");
    return;
  }
  http.send(200, "text/plain", "OK");
}

void handleFreezeHttp() {
  refreshFrameJobLock();
  if (httpCaptureBusy || httpUploadBusy) { http.send(409,"text/plain","已有图像任务占用，请查询模型或人像状态；计算中不能切换摄像头"); return; }
  if (!beginHybridCapture()) { http.send(504,"text/plain","1080p switch failed; preview restore attempted"); return; }
  if (fpgaRead(REG_STATUS) & STATUS_FROZEN) {
    http.send(200, "text/plain", "OK");
    return;
  }
  fpgaWrite(REG_CONTROL, 0x01);
  if (!waitForStatus(STATUS_FROZEN, true, FREEZE_TIMEOUT_MS) || !waitForStatus(STATUS_FRAME_READY,true,5000)) {
    restoreHybridPreview();
    http.send(504, "text/plain; charset=utf-8", "FPGA freeze timeout");
    return;
  }
  http.send(200, "text/plain", "OK");
}

void handleResumeHttp() {
  refreshFrameJobLock();
  if (httpCaptureBusy || httpUploadBusy) { http.send(409,"text/plain","已有图像任务占用，请查询模型或人像状态；计算中不能切换摄像头"); return; }
  invalidateTaskInput();
  fpgaWrite(REG_CONTROL, 0x02);
  if (!waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS)) {
    http.send(504, "text/plain; charset=utf-8", "FPGA resume timeout");
    return;
  }
  if (!restoreHybridPreview()) { http.send(504,"text/plain","720p preview restore failed; retry resume"); return; }
  http.send(200, "text/plain", "OK");
}

void handleBrightnessHttp() {
  if (!http.hasArg("value")) { http.send(400, "text/plain", "missing value"); return; }
  int value = constrain(http.arg("value").toInt(), 0, 127);
  fpgaWrite(REG_PWM, static_cast<uint8_t>(value));
  if (!waitForRegister(REG_PWM, static_cast<uint8_t>(value), 0x7F, 250)) {
    http.send(504, "text/plain; charset=utf-8", "背光设置超时，请检查FPGA连接");
    return;
  }
  char reply[48];snprintf(reply,sizeof(reply),"{\"brightness\":%u}",unsigned(fpgaRead(REG_PWM)&0x7f));
  http.send(200,"application/json",reply);
}

void handleCaptureHttp() {
  if(!capturePreviewOutput)refreshFrameJobLock();
  if (httpCaptureBusy || httpUploadBusy) { http.send(409, "text/plain; charset=utf-8", "capture busy"); return; }
  httpCaptureBusy = true;
  if(http.hasArg("camera")){
    const String requestedCamera=http.arg("camera");
    if(requestedCamera!="0" && requestedCamera!="1" && requestedCamera!="2"){
      httpCaptureBusy=false;http.send(400,"text/plain; charset=utf-8","摄像头参数必须为0、1或2");return;
    }
    if(!selectCamera(requestedCamera.toInt())){
      httpCaptureBusy=false;http.send(504,"text/plain; charset=utf-8",String("摄像头切换或完整帧检查失败，status=0x")+String(fpgaRead(REG_STATUS),HEX)+"，I2C=0x"+String(fpgaRead(REG_I2C_STATUS),HEX)+"，lines="+String(fpgaRead16(REG_CAM_LINES_LO))+"，min/max="+String(fpgaRead16(REG_CAM_MIN_LO))+"/"+String(fpgaRead16(REG_CAM_MAX_LO)));return;
    }
  }
  captureRawOutput=http.arg("format")=="rgb565" && fpgaRead(0x1e)==0x52;
  const bool includeStreamCrc=http.arg("crc")=="1";
  uint32_t captureStart = millis();
  uint8_t requestedMode = http.hasArg("mode") ? static_cast<uint8_t>(http.arg("mode").toInt()) : (fpgaRead(REG_SCAN_MODE) & 0x03);
  uint8_t frameSelection=0;
  if(http.hasArg("source")){if(http.arg("source")=="result")frameSelection=2;else if(http.arg("source")=="frame_original")frameSelection=8;}
  captureStreamHz=SPI_HZ_STREAM;
  if(http.hasArg("spi_mhz")){
    const String mhz=http.arg("spi_mhz");
    if(mhz!="20" && mhz!="10" && mhz!="5"){httpCaptureBusy=false;http.send(400,"text/plain","spi_mhz must be 20, 10 or 5");return;}
    captureStreamHz=mhz.toInt()*1000000u;
  }
  if(frameSelection && ((http.hasArg("job") && strtoul(http.arg("job").c_str(),nullptr,10)!=currentFrameJobId()) ||
      (http.hasArg("boot") && strtoul(http.arg("boot").c_str(),nullptr,10)!=transportBootId) ||
      (http.hasArg("cookie") && strtoul(http.arg("cookie").c_str(),nullptr,10)!=fpgaTaskCookie()) || !matchingTask())){
    httpCaptureBusy=false;http.send(409,"text/plain; charset=utf-8","板卡任务或启动会话已更换，停止读取旧结果");return;
  }
  bool uploadedSource = frameSelection || (http.hasArg("source") && http.arg("source") == "upload");
  if(frameSelection)requestedMode=0;
  if (requestedMode > 3) {
    httpCaptureBusy = false;
    http.send(400, "text/plain; charset=utf-8", "mode must be 0..3");
    return;
  }
  if (!uploadedSource) {
    invalidateTaskInput();
    int algorithms = http.hasArg("alg") ? http.arg("alg").toInt() : 0;
    if (algorithms < 0 || algorithms > 127) {
      httpCaptureBusy = false;
      http.send(400, "text/plain; charset=utf-8", "alg must be 0..127");
      return;
    }
    fpgaWrite(REG_ALGORITHM, static_cast<uint8_t>(algorithms));
    if (algorithms != 0 && !waitForRegister(REG_ALGORITHM, static_cast<uint8_t>(algorithms), 0x7f, 250)) {
      httpCaptureBusy = false;
      http.send(409, "text/plain; charset=utf-8", "FPGA algorithm register mismatch; update matching bitstream");
      return;
    }
  }
  uint8_t header[FRAME_HEADER_BYTES] = {0};
  uint32_t payload = 0;
  const uint32_t sequence=captureDiagnostic.sequence+1;
  captureDiagnostic=CaptureDiagnostic();captureDiagnostic.sequence=sequence;
  captureDiagnostic.request=http.hasArg("request")?strtoul(http.arg("request").c_str(),nullptr,10):0;
  captureDiagnostic.job=frameSelection?currentFrameJobId():0;captureDiagnostic.spiHz=captureStreamHz;
   

  const uint32_t captureCookie=frameSelection?fpgaTaskCookie():0;
  captureDiagnostic.active=true;captureDiagnostic.phase="prepare";
  uint32_t prepareStart = millis();
  bool prepared = uploadedSource
                    ? prepareUploadedFrameStream(header, payload, requestedMode, frameSelection)
                    : prepareFrameStream(header, payload, requestedMode);
  memcpy(captureDiagnostic.header,header,FRAME_HEADER_BYTES);
  captureDiagnostic.stage=capturePrepareStage;
  if (!prepared) {
    captureDiagnostic.active=false;captureDiagnostic.phase="failed";captureDiagnostic.reason="prepare_failed";
    captureDiagnostic.prepareMs=millis()-prepareStart;
    uint8_t status = fpgaRead(REG_STATUS);
    uint8_t uploadStatus = fpgaRead(REG_UPLOAD_STATUS);
    Serial.printf("[UPLOAD_DIAG] STREAM_PREPARE_FAIL mode=%u status=0x%02X upload_status=0x%02X\n",
                  requestedMode, status, uploadStatus);
    Serial.printf("[HTTP_DIAG] JPEG_STATUS=0x%02X\n",fpgaRead(0x38));
     

    cleanupCapturePrepareFailure(frameSelection);
    httpCaptureBusy = false;
    http.send(504,"text/plain; charset=utf-8",String("抓拍失败，阶段=")+String(capturePrepareStage)+"，状态=0x"+String(status,HEX)+"，配置=0x"+String(fpgaRead(REG_I2C_STATUS),HEX)+"；请先恢复或切720p重试");
    return;
  }
  uint32_t prepareMs = millis() - prepareStart;
  captureDiagnostic.prepareMs=prepareMs;captureDiagnostic.expected=payload;captureDiagnostic.phase="transfer";
  WiFiClient client = http.client();
   
  client.setNoDelay(true);
  int sendBuffer = 64 * 1024;
  client.setSocketOption(SOL_SOCKET, SO_SNDBUF, &sendBuffer, sizeof(sendBuffer));
   
  char responseHeader[512];
  const int headerLength=snprintf(responseHeader,sizeof(responseHeader),
    "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nX-Ti60-Stream: 6.0\r\nX-Frame-Job: %lu\r\nX-Frame-Cookie: %lu\r\nX-Frame-Format: %u\r\nX-Payload-Bytes: %lu\r\n%sX-Prepare-Ms: %lu\r\nX-SPI-MHz: %lu\r\nX-Freeze-Ms: %lu\r\nX-Encode-Ms: %lu\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",
    captureRawOutput?"application/octet-stream":"image/jpeg",(unsigned long)captureDiagnostic.job,(unsigned long)captureCookie,
    captureRawOutput?3u:2u,(unsigned long)payload,includeStreamCrc?"X-Frame-CRC: trailer\r\n":"",
    (unsigned long)prepareMs,(unsigned long)(captureStreamHz/1000000),
    (unsigned long)(capturePreviewOutput?captureFreezeMs:0),(unsigned long)(capturePreviewOutput?captureEncodeMs:0),
    (unsigned long)(payload+(captureRawOutput?16:0)+(includeStreamCrc?4:0)));
  const bool headerSent=headerLength>0 && size_t(headerLength)<sizeof(responseHeader) && writeHttpBytes(client,reinterpret_cast<const uint8_t*>(responseHeader),headerLength);
  uint32_t transferStart = millis();
  uint32_t spiUs = 0;
  uint32_t wifiUs = 0;
  uint32_t ioStart = micros();
  bool ok = headerSent;
  if(!ok)captureDiagnostic.reason="wifi_header_failed";
  JpegHttpGuard guard(payload,captureRawOutput);
  if(ok && captureRawOutput)ok=writeHttpBytes(client,header,16);
  auto writeBody = [&](const uint8_t* data,size_t count){const bool sent=writeHttpBytes(client,data,count);if(!sent)captureDiagnostic.reason="wifi_write_failed";return sent;};
  memset(streamTx, 0, sizeof(streamTx));
  uint32_t remaining = payload + FRAME_CRC_BYTES;
  uint32_t lastYield=millis();
  while (ok && remaining) {
    if (millis() - transferStart > 90000 || !client.connected()) { captureDiagnostic.reason=client.connected()?"transfer_timeout":"peer_closed";ok = false; break; }
    size_t count = remaining > STREAM_CHUNK_BYTES ? STREAM_CHUNK_BYTES : remaining;
    ioStart = micros();
    fpgaSpi.transferBytes(streamTx, streamRx, count);
    spiUs += micros() - ioStart;
    ioStart = micros();
    ok = guard.consume(streamRx,count,writeBody);
    if(!ok && strcmp(captureDiagnostic.reason,"none")==0)captureDiagnostic.reason="invalid_jpeg_stream";
    wifiUs += micros() - ioStart;
    remaining -= count;
     
    if(millis()-lastYield>=4){delay(1);lastYield=millis();}
  }
   
  if(remaining)drainFrameBytes(remaining);
  const bool crcOk=guard.crcOk();
  if(ok && !crcOk)captureDiagnostic.reason="crc_mismatch";
  ok=ok && guard.finish(writeBody,includeStreamCrc);
  if(!capturePreviewOutput || !ok) Serial.printf("JPEG_DIAG magic=JPIC size=%lu sent=%lu crc=%s\n",(unsigned long)payload,(unsigned long)guard.sent(),crcOk?"OK":"FAIL");
  uint32_t transferMs = millis() - transferStart;
  captureDiagnostic.crcOk=crcOk;captureDiagnostic.complete=ok;captureDiagnostic.active=false;
  captureDiagnostic.phase=ok?"complete":"failed";if(ok)captureDiagnostic.reason="none";
  captureDiagnostic.transferMs=transferMs;captureDiagnostic.received=payload+FRAME_CRC_BYTES-remaining;captureDiagnostic.sent=guard.sent();
   
  if(frameSelection && (!ok || (http.hasArg("keep") && http.arg("keep")=="1"))){
    digitalWrite(PIN_CS,HIGH);fpgaSpi.endTransaction();delay(2);
  }else finishFrameStream();
  if(!capturePreviewOutput || !ok) Serial.printf("HTTP capture %s total=%lu ms prepare=%lu ms transfer=%lu ms spi=%lu ms wifi_write=%lu ms (SPI=%lu Hz)\n",
                ok ? "OK" : "FAILED", (unsigned long)(millis() - captureStart),
                (unsigned long)prepareMs, (unsigned long)transferMs,
                (unsigned long)(spiUs / 1000), (unsigned long)(wifiUs / 1000),
                (unsigned long)captureStreamHz);
  client.stop();
  httpCaptureBusy = false;
}

void closeUploadSpi() {
  if (!uploadSpiOpen) return;
  digitalWrite(PIN_CS, HIGH);
  fpgaSpi.endTransaction();
  uploadSpiOpen = false;
}

void failUpload(const String &message, bool resumeCamera) {
  closeUploadSpi();
  httpUploadBusy=false;
  uploadResultOk = false;
  uploadAttemptFailed = true;
  uploadError = message;
  Serial.printf("[UPLOAD_DIAG] FAIL error=%s forwarded=%u expected=%u\n",
                message.c_str(), (unsigned)uploadBytesForwarded,
                (unsigned)uploadExpectedPacketBytes);
  if (resumeCamera) {
    fpgaWrite(REG_CONTROL, 0x02);
    waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS);
  }
}

bool parseUploadHeader() {
  if (uploadHeaderBytes != FRAME_HEADER_BYTES ||
      memcmp(uploadHeader, "UJIG", 4) != 0 ||
      uploadHeader[4] != 1 || uploadHeader[5] != 2) return false;
  uploadFrameWidth = (uint16_t)uploadHeader[6] |
                     ((uint16_t)uploadHeader[7] << 8);
  uploadFrameHeight = (uint16_t)uploadHeader[8] |
                      ((uint16_t)uploadHeader[9] << 8);
  uploadPayloadBytes = (uint32_t)uploadHeader[10] |
                       ((uint32_t)uploadHeader[11] << 8) |
                       ((uint32_t)uploadHeader[12] << 16) |
                       ((uint32_t)uploadHeader[13] << 24);
  if (!validFramePayload(uploadPayloadBytes) ||
      uploadFrameWidth!=(taskWidth(uploadFrame1080)) ||
      uploadFrameHeight!=(taskHeight(uploadFrame1080))) return false;
  uploadExpectedPacketBytes = FRAME_HEADER_BYTES + uploadPayloadBytes +
                              FRAME_CRC_BYTES;
  return uploadExpectedPacketBytes <= UPLOAD_MAX_PACKET_BYTES;
}

void handleUploadData() {
  HTTPUpload &upload = http.upload();
  if (upload.status == UPLOAD_FILE_START) {
    uploadResultOk = false;
    uploadAttemptFailed = false;
    uploadError = "upload not completed";
    uploadBytesForwarded = 0;
    uploadExpectedPacketBytes=0;uploadHeaderBytes=0;uploadFrameWidth=0;uploadFrameHeight=0;uploadPayloadBytes=0;
    memset(uploadHeader,0,sizeof(uploadHeader));
    const String sizeArg=http.hasArg("size")?http.arg("size"):"0";
    if(sizeArg!="0"&&sizeArg!="1"&&sizeArg!="2"){failUpload("unsupported fixed geometry",false);return;}
    uploadFrame1080=sizeArg.toInt();
    if(uploadFrame1080==2&&fpgaRead(0x4f)!=0x82){failUpload("local mode requires paired V8 FPGA",false);return;}
    if(fpgaRead(0x36)!=0xa3){failUpload("需要新版双尺寸上传FPGA位流",false);return;}
    Serial.printf("[UPLOAD_DIAG] START filename=%s expected=%u\n",
                  upload.filename.c_str(), (unsigned)uploadExpectedPacketBytes);
    int requestedMode = http.hasArg("mode") ? http.arg("mode").toInt() : 0;
    if (requestedMode < 0 || requestedMode > 3) {
      failUpload("mode must be 0..3", false);
      return;
    }
    fpgaWrite(REG_SCAN_MODE, static_cast<uint8_t>(requestedMode));
    if (!waitForRegister(REG_SCAN_MODE, static_cast<uint8_t>(requestedMode), 0x03, 250)) {
      failUpload("FPGA模式设置超时", false);
      return;
    }
    refreshFrameJobLock();
  if (httpCaptureBusy || httpUploadBusy) {
      failUpload("FPGA busy", false);
      return;
    }
    invalidateTaskInput();
    httpUploadBusy = true;
    int requestedAlgorithms = http.hasArg("alg") ? http.arg("alg").toInt() : 0;
    if (requestedAlgorithms < 0 || requestedAlgorithms > 127) {
      failUpload("alg must be 0..127", false);
      return;
    }
    fpgaWrite(REG_ALGORITHM, static_cast<uint8_t>(requestedAlgorithms));
    if (requestedAlgorithms != 0 && !waitForRegister(REG_ALGORITHM, static_cast<uint8_t>(requestedAlgorithms), 0x7f, 250)) {
      failUpload("FPGA algorithm update timeout", false);
      return;
    }
    if (!(fpgaRead(REG_STATUS) & STATUS_FROZEN)) {
      fpgaWrite(REG_CONTROL, 0x01);
      if (!waitForStatus(STATUS_FROZEN, true, FREEZE_TIMEOUT_MS)) {
        failUpload("摄像头冻结超时：请先恢复或切720p重试", false);
        return;
      }
    }
    if (!waitForStatus(STATUS_FRAME_READY, true, 5000)) {
      uint8_t status = fpgaRead(REG_STATUS);
      failUpload("no complete camera frame before upload status=0x" +
                 String(status, HEX), true);
      return;
    }
     
    fpgaWrite(REG_UPLOAD_CONTROL, static_cast<uint8_t>(0x01 | (requestedMode << 2) | (uploadFrame1080<<5)));
    if (!waitForRegister(REG_UPLOAD_STATUS, UPLOAD_STATUS_WRITER_ACTIVE,
                         UPLOAD_STATUS_WRITER_ACTIVE, 500)) {
      uint8_t uploadStatus = fpgaRead(REG_UPLOAD_STATUS);
      failUpload("FPGA upload writer did not start status=0x" +
                 String(uploadStatus, HEX), true);
      return;
    }
    uint8_t uploadStatusBeforeArm = fpgaRead(REG_UPLOAD_STATUS);
    uint8_t fpgaStatusBeforeArm = fpgaRead(REG_STATUS);
    Serial.printf("[UPLOAD_DIAG] WRITER_ACTIVE mode=%d status=0x%02X fpga_status=0x%02X\n",
                  requestedMode, uploadStatusBeforeArm, fpgaStatusBeforeArm);
    if (!(uploadStatusBeforeArm & UPLOAD_STATUS_WRITER_ACTIVE) ||
        (uploadStatusBeforeArm & (UPLOAD_STATUS_PACKET_DONE |
                                  UPLOAD_STATUS_ERROR_MASK))) {
      failUpload("FPGA upload receiver ended before raw transfer status=0x" +
                 String(uploadStatusBeforeArm, HEX), true);
      return;
    }
    fpgaWrite(REG_UPLOAD_CONTROL, 0x02);
     

    delayMicroseconds(20);
    fpgaSpi.beginTransaction(SPISettings(SPI_HZ_STREAM, MSBFIRST, SPI_MODE0));
    digitalWrite(PIN_CS, LOW);
    uploadSpiOpen = true;
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (!uploadSpiOpen) return;
    if (upload.currentSize > STREAM_CHUNK_BYTES ||
        uploadBytesForwarded + upload.currentSize > UPLOAD_MAX_PACKET_BYTES) {
      failUpload("upload packet is too large", true);
      return;
    }
    if (uploadHeaderBytes < FRAME_HEADER_BYTES) {
      size_t take = min(upload.currentSize,
                        FRAME_HEADER_BYTES - uploadHeaderBytes);
      memcpy(uploadHeader + uploadHeaderBytes, upload.buf, take);
      uploadHeaderBytes += take;
      if (uploadHeaderBytes == FRAME_HEADER_BYTES && !parseUploadHeader()) {
        failUpload("unsupported or invalid UJIG/JPEG geometry", true);
        return;
      }
    }
    if (uploadExpectedPacketBytes &&
        uploadBytesForwarded + upload.currentSize > uploadExpectedPacketBytes) {
      failUpload("upload packet exceeds declared length", true);
      return;
    }
    size_t offset = 0;
    while (offset < upload.currentSize) {
      uint32_t waitStart = millis();
       

      while (!gpio_get_level(static_cast<gpio_num_t>(PIN_MISO))) {
        if (millis() - waitStart >= UPLOAD_FLOW_TIMEOUT_MS) {
          failUpload("FPGA upload FIFO ready timeout", true);
          return;
        }
        delay(1);
      }
      size_t count = min(UPLOAD_BURST_BYTES, upload.currentSize - offset);
      fpgaSpi.transferBytes(upload.buf + offset, streamRx, count);
      uploadBytesForwarded += count;
      offset += count;
       
      delayMicroseconds(2);
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    closeUploadSpi();
    Serial.printf("[UPLOAD_DIAG] HTTP_END forwarded=%u http_total=%u current=%u failed=%u\n",
                  (unsigned)uploadBytesForwarded, (unsigned)upload.totalSize,
                  (unsigned)upload.currentSize, uploadAttemptFailed ? 1u : 0u);
    if (uploadAttemptFailed) return;
    if (!uploadExpectedPacketBytes || uploadBytesForwarded != uploadExpectedPacketBytes) {
      failUpload("upload packet length mismatch received=" +
                 String((unsigned)uploadBytesForwarded) + " expected=" +
                 String((unsigned)uploadExpectedPacketBytes) + " http_total=" +
                 String((unsigned)upload.totalSize), true);
      return;
    }
    delay(2);
    uint8_t uploadStatus = 0;
    uint8_t stableCommitted=0,previousStatus=0;
    uint32_t deadline = millis() + 10000;
    while ((int32_t)(millis() - deadline) < 0) {
      uploadStatus=fpgaRead(REG_UPLOAD_STATUS);
      if(uploadStatus&UPLOAD_STATUS_ERROR_MASK)break;
      const uint32_t received=(uint32_t)fpgaRead(REG_UPLOAD_COUNT_LO)|
        ((uint32_t)fpgaRead(REG_UPLOAD_COUNT_LO+1)<<8)|
        ((uint32_t)fpgaRead(REG_UPLOAD_COUNT_LO+2)<<16);
      const uint8_t confirmedStatus=fpgaRead(REG_UPLOAD_STATUS);
      if(confirmedStatus==uploadStatus && uploadCommitAccepted(uploadStatus,received,uploadPayloadBytes)){
        stableCommitted=previousStatus==uploadStatus ? stableCommitted+1 : 1;
        if(stableCommitted>=2){uploadResultOk=true;uploadError="";break;}
      }else stableCommitted=0;
      previousStatus=uploadStatus;
      delay(2);
    }
    if (!uploadResultOk) {
      uint32_t received = (uint32_t)fpgaRead(REG_UPLOAD_COUNT_LO) |
                          ((uint32_t)fpgaRead(REG_UPLOAD_COUNT_LO + 1) << 8) |
                          ((uint32_t)fpgaRead(REG_UPLOAD_COUNT_LO + 2) << 16);
      uploadError = "FPGA upload validation failed status=0x" +
                    String(uploadStatus, HEX) + " received=" + String(received);
      uploadAttemptFailed = true;
      Serial.printf("[UPLOAD_DIAG] FPGA_VALIDATE_FAIL status=0x%02X received=%lu\n",
                    uploadStatus, (unsigned long)received);
      fpgaWrite(REG_CONTROL, 0x02);
      waitForStatus(STATUS_FROZEN, false, FREEZE_TIMEOUT_MS);
    } else {
      Serial.printf("[UPLOAD_DIAG] SUCCESS status=0x%02X forwarded=%u\n",
                    uploadStatus, (unsigned)uploadBytesForwarded);
    }
  } else if (upload.status == UPLOAD_FILE_ABORTED) {
    failUpload("HTTP upload aborted", true);
  }
}

void handleUploadComplete() {
  if (uploadResultOk) {
    http.send(200,"application/json",uploadFrame1080==2?"{\"ok\":true,\"width\":256,\"height\":224}":uploadFrame1080==1?"{\"ok\":true,\"width\":1920,\"height\":1080}":"{\"ok\":true,\"width\":1024,\"height\":600}");
  } else {
    http.send(500, "text/plain; charset=utf-8", uploadError.length() ? uploadError : "upload failed");
  }
  httpUploadBusy = false;
}

static const char STUDENT_PAGE[] PROGMEM = R"STUDENT(<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ti60 模型与联合处理</title>
<style>*{box-sizing:border-box}body{margin:0 auto;max-width:1100px;padding:18px;background:#111820;color:#edf1f5;font:15px/1.5 system-ui,"Microsoft YaHei",sans-serif}h1{font-size:24px;margin:8px 0 16px}h2{font-size:17px}nav,.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}nav a,button{background:#253444;color:#edf1f5;border:1px solid #3d5061;padding:10px 12px;border-radius:5px;text-decoration:none;font:inherit}nav a[aria-current],button.active{background:#164875}button.primary{background:#157347}button:disabled{opacity:.45}input,select{font:inherit;max-width:100%;accent-color:#409fe8}select{background:#202c39;color:#edf1f5;padding:8px;border:1px solid #3d5061;border-radius:4px}label{display:inline-flex;align-items:center;gap:8px;margin:6px 12px 6px 0}.panel{padding:12px;border:1px solid #314252;background:#1e2b38;border-radius:6px;margin:14px 0}.note{font-size:13px;color:#aabccd}#status{border-left:3px solid #409fe8;background:#1e2b38;padding:12px;overflow-wrap:anywhere}canvas{display:block;width:100%;height:auto;border:1px solid #33485a;border-radius:5px}canvas[width="0"]{display:none}progress{display:block;width:100%;height:14px;accent-color:#36a269}input[type=file]{display:block;margin:12px 0;width:100%}[hidden]{display:none!important}.images{display:grid;grid-template-columns:1fr 1fr;gap:16px}@media(max-width:680px){body{padding:14px}.images{grid-template-columns:1fr}.toolbar button{flex:1 1 110px}nav a{font-size:14px;padding:8px}}</style><link rel="stylesheet" href="/ui.css"><script src="/transport-v4.js"></script><script defer src="/ui.js"></script></head><body>
<h1>模型与联合处理</h1><p class="note">固件：F9-V8-1031-SPI · 板内整帧处理</p><nav aria-label="处理功能"><a href="/">摄像头抓拍</a><a href="/local">本地图片</a><a href="/student" aria-current="page">模型与联合处理</a><a href="/portrait">人像</a></nav>
<section class="panel"><h2>1. 选择图像来源</h2><input id="file" type="file" accept="image/*"><div class="toolbar"><button id="camera720">720p摄像头</button><button id="camera1080">1080p摄像头</button></div><p id="sourceInfo" class="note">请选择本地图片或摄像头。点击开始后抓拍并在板内处理。</p>
<section id="studentCropPanel" hidden><h2>本地图片裁剪</h2><label>适配方式<select id="studentCropFit"><option value="cover">填满画面</option><option value="contain">完整保留</option><option value="pixel">原始像素1:1</option></select></label><button id="studentCropReset">居中</button><p id="studentCropInfo" class="note"></p><canvas id="studentCropPreview" style="touch-action:none"></canvas></section></section>
<section class="panel"><h2>2. 选择处理方式</h2><label id="jointSizeGroup">本地输出尺寸<select id="jointSize"><option value="720">1024×600</option><option value="1080">1920×1080</option><option value="small">256×224 快速</option></select></label><label>输出<select id="studentOutput"><option value="color">彩色</option><option value="gray">灰阶黑白</option><option value="document">扫描文档（模型辅助）</option></select></label><label>流程<select id="studentPipeline"><option value="model">学生模型</option><option value="joint">模型 → FPGA传统收尾</option></select></label><label><input id="returnOriginal" type="checkbox" checked>抓拍完成后同时取回原图</label>
<label>上传前补光<select id="browserPreprocess"><option value="none">关闭</option><option value="light">轻微补光</option></select></label><label>结果优化<select id="browserFinish"><option value="auto">默认</option><option value="none">关闭（保留FPGA结果）</option><option value="sharp">轻微锐化</option></select></label><p class="note">扫描自动去阴影、去噪；补光仅用于上传图片。</p><p id="pipelineInfo" class="note">扫描文档：模型增强后生成黑白扫描件，可下载原始结果对照。</p><p class="note">模型：直接增强；联合：增加传统收尾。继续读取按原任务设置恢复；彩纹可另行应用到当前结果。</p></section>
<div class="toolbar"><button id="run" class="primary" disabled>开始处理</button><button id="stop" disabled>暂停读取</button><button id="attach">查询 / 继续读取</button><button id="saveOriginal" disabled>下载原图JPEG</button><button id="save" disabled>下载当前结果</button><button id="saveFpga" disabled>下载FPGA原始结果JPEG</button><button id="compareFpga" disabled>对比FPGA结果 / 结果优化</button></div><p id="status" role="status">正在检查FPGA…</p><label id="taskProgressLabel" for="taskProgress">等待处理</label><progress id="taskProgress" max="100" value="0"></progress>
<p class="note">原图与结果文件名包含同一任务编号。摄像头原图需勾选同时取回原图并通过CRC；本地原图保存本任务裁剪输入快照（RGB565编码前）。切换页面后将恢复本次任务已保存的原图。</p><div class="images"><section><h2>原图</h2><canvas id="original" width="0" height="0"></canvas></section><section><h2>处理结果</h2><canvas id="result" width="0" height="0"></canvas></section></div>
<details class="panel"><summary>设备诊断</summary><button id="readDiagnostics">读取设备状态</button><pre id="diagnostics" style="white-space:pre-wrap;overflow-wrap:anywhere">失败后会自动读取诊断；可展开并截图。</pre></details>
<script>
async function encodeJpegUpload(canvas){
 const w=canvas.width,h=canvas.height;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224)))throw Error('不支持的上传尺寸');
 const blob=await new Promise((ok,fail)=>canvas.toBlob(x=>x?ok(x):fail(Error('JPEG编码失败')),'image/jpeg',0.92));
 const raw=new Uint8Array(await blob.arrayBuffer());if(raw[0]!==255||raw[1]!==216)throw Error('JPEG生成失败');
 const n=((raw.length+15)&~15)+(w===256&&h===224?64:0);if(n>4194288)throw Error('JPEG超过4MiB，请降低图片复杂度');
 const packet=new Uint8Array(n+20),v=new DataView(packet.buffer);packet.set([85,74,73,71,1,2]);
 v.setUint16(6,w,true);v.setUint16(8,h,true);v.setUint32(10,n,true);packet.fill(255,16,n+16);packet.set(raw,16);
 v.setUint32(n+16,crc32(packet.subarray(16,n+16)),true);return packet;
}
async function decodeJpeg(bytes,canvas,expected){
 if(Ti60Transfer.isRaw(bytes))return Ti60Transfer.drawRaw(bytes,canvas,expected);
 Ti60Jpeg.validate(bytes,expected);
 const blob=new Blob([bytes],{type:'image/jpeg'}),url=URL.createObjectURL(blob),im=new Image();
 try{await new Promise((ok,fail)=>{im.onload=ok;im.onerror=()=>fail(Error('JPEG不完整或解码失败'));im.src=url});
 const w=im.naturalWidth,h=im.naturalHeight;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224))||(expected&&(w!==expected.width||h!==expected.height)))throw Error('返回尺寸与任务不一致');
 canvas.width=w;canvas.height=h;canvas.getContext('2d').drawImage(im,0,0);canvas.jpegBlob=blob;canvas.fpgaPixels=null;canvas.dataset.transport='jpeg';
 }finally{URL.revokeObjectURL(url)}
}
function saveJpeg(canvas,name){
 const save=blob=>{if(!blob)return;const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};
 if(canvas.jpegBlob)save(canvas.jpegBlob);else canvas.toBlob(save,'image/jpeg',0.92);
}
const $=id=>document.getElementById(id);
const original=$('original'),result=$('result'),statusEl=$('status'),run=$('run'),stop=$('stop'),save=$('save');
let available=false,processing=false,complete=false,studentOriginalFile=null;
let sourceKind='local',cameraResolution=720,activeJob=null,pauseRequested=false;
let originalDownload=null,localInputSnapshot=null,resultDownloadName='';
// Optional browser adjustments. Model inference and main filtering stay on FPGA.
function browserLightRgba(rgba){
 for(let i=0;i<rgba.length;i+=4)for(let c=0;c<3;c++)rgba[i+c]=Math.max(0,Math.min(255,(rgba[i+c]-128)*1.03+134));
 return rgba;
}
function browserFinishRgba(rgba,w,h,mode){
 if(mode==='none'||!mode)return rgba;
 if(mode==='document')return Ti60Document.scan(rgba,w,h);
 if(mode==='specks')return Ti60Document.clean(rgba,w,h);
 if(mode!=='sharp')throw Error('未知结果优化选项');
 const source=rgba.slice();
 for(let y=0;y<h;y++)for(let x=0;x<w;x++)for(let c=0;c<3;c++){
  let sum=0;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)sum+=source[(Math.max(0,Math.min(h-1,y+dy))*w+Math.max(0,Math.min(w-1,x+dx)))*4+c];
  const i=(y*w+x)*4+c,delta=Math.max(-6,Math.min(6,(source[i]-sum/9)*.25));rgba[i]=source[i]+delta;
 }return rgba;
}
function prepareBrowserInput(canvas){
 if(($('browserPreprocess').value||'none')==='none')return canvas;
 const out=document.createElement('canvas');out.width=canvas.width;out.height=canvas.height;
 const ctx=out.getContext('2d');ctx.drawImage(canvas,0,0);const image=ctx.getImageData(0,0,out.width,out.height);
 browserLightRgba(image.data);ctx.putImageData(image,0,0);return out;
}
async function finishBrowserCanvas(canvas,mode){
 if(!mode||mode==='none')return;
 const ctx=canvas.getContext('2d'),image=ctx.getImageData(0,0,canvas.width,canvas.height);
 browserFinishRgba(image.data,canvas.width,canvas.height,mode);ctx.putImageData(image,0,0);
 canvas.cleanedBlob=await new Promise((ok,fail)=>canvas.toBlob(b=>b?ok(b):fail(Error('PNG编码失败')),'image/png'));
}

// Deterministic local processing after validated FPGA results; no network/model download.
function componentMap(mask,w,h){
 const labels=new Int32Array(w*h),queue=new Int32Array(w*h),sizes=[0];let count=0;
 for(let start=0;start<mask.length;start++){
  if(!mask[start]||labels[start])continue;const id=++count;let head=0,tail=1;queue[0]=start;labels[start]=id;
  while(head<tail){const i=queue[head++],x=i%w,y=(i/w)|0;
   for(let dy=-1;dy<=1;dy++){const yy=y+dy;if(yy<0||yy>=h)continue;
    for(let dx=-1;dx<=1;dx++){const xx=x+dx;if(xx<0||xx>=w)continue;const j=yy*w+xx;if(mask[j]&&!labels[j]){labels[j]=id;queue[tail++]=j;}}}
  }sizes.push(tail);
 }return{labels,sizes};
}
function refinePortraitAlpha(input,w=64,h=64){
 if(input.length!==w*h)throw Error('人像掩码尺寸错误');const a=new Float32Array(input.length),mask=new Uint8Array(input.length);
 for(let i=0;i<a.length;i++){a[i]=Math.max(0,Math.min(1,(input[i]-.10)/.85));mask[i]=a[i]>.15?1:0;}
 const c=componentMap(mask,w,h);let largest=0;for(let i=1;i<c.sizes.length;i++)largest=Math.max(largest,c.sizes[i]);
 const minimum=Math.max(4,largest*.05);for(let i=0;i<a.length;i++)if(c.labels[i]&&c.sizes[c.labels[i]]<minimum)a[i]=0;
 return a;
}
function cleanTextRgba(rgba,w,h){
 if(rgba.length!==w*h*4)throw Error('文字图像尺寸错误');const mask=new Uint8Array(w*h);
 for(let i=0;i<mask.length;i++)mask[i]=(rgba[i*4]+2*rgba[i*4+1]+rgba[i*4+2])<512?1:0;
 const c=componentMap(mask,w,h),keep=new Uint8Array(c.sizes.length);
 for(let id=1;id<keep.length;id++)keep[id]=c.sizes[id]>12?1:0;
 for(let i=0;i<mask.length;i++){
  const id=c.labels[i];if(!id||keep[id])continue;const x=i%w,y=(i/w)|0;
  for(let dy=-5;dy<=5&&!keep[id];dy++){const yy=y+dy;if(yy<0||yy>=h)continue;
   for(let dx=-5;dx<=5;dx++){const xx=x+dx;if(xx>=0&&xx<w&&c.sizes[c.labels[yy*w+xx]]>12){keep[id]=1;break;}}}
 }
 for(let i=0;i<mask.length;i++){const v=keep[c.labels[i]]?0:255;rgba[i*4]=v;rgba[i*4+1]=v;rgba[i*4+2]=v;}
 return rgba;
}
if(typeof module!=='undefined')module.exports={componentMap,refinePortraitAlpha,cleanTextRgba,browserLightRgba,browserFinishRgba};

async function cleanTextCanvas(canvas){const ctx=canvas.getContext("2d"),im=ctx.getImageData(0,0,canvas.width,canvas.height);cleanTextRgba(im.data,canvas.width,canvas.height);ctx.putImageData(im,0,0);canvas.cleanedBlob=await new Promise((ok,fail)=>canvas.toBlob(b=>b?ok(b):fail(Error("PNG编码失败")),"image/png"));}
function taskImageName(kind,s){return 'fpga_'+kind+'_job'+s.job_id+'_'+s.width+'x'+s.height+'.jpg';}
function setTaskProgress(label,value){$('taskProgressLabel').textContent=label;if(value==null)$('taskProgress').removeAttribute('value');else $('taskProgress').value=Math.max(0,Math.min(100,value));}
function controls(){document.querySelectorAll('button,input,select').forEach(e=>e.disabled=processing);run.disabled=processing||!available||(sourceKind==='local'&&!original.dataset.loaded);stop.disabled=!processing;save.disabled=processing||!complete;$('saveOriginal').disabled=processing||!complete||!originalDownload;$('saveFpga').disabled=processing||!complete||!result.jpegBlob;$('compareFpga').disabled=processing||!complete||!result.cleanedBlob;$('jointSizeGroup').hidden=sourceKind==='camera';$('camera720').classList.toggle('active',sourceKind==='camera'&&cameraResolution===720);$('camera1080').classList.toggle('active',sourceKind==='camera'&&cameraResolution===1080);}
function crc32(bytes){let c=0xffffffff;for(const x of bytes){c^=x;for(let k=0;k<8;k++)c=(c>>>1)^((c&1)?0xedb88320:0);}return (~c)>>>0;}
$('readDiagnostics').onclick=readDiagnostics;
// Embedded into STUDENT_PAGE by patch_transport_client.py; no external fetch.
let activeTransfer=null,frameComputationDone=false,activeBoot=null;
let transferSequence=Date.now()>>>0;
const transferPause=()=>new Error('读取已暂停，板端任务保留；点击继续读取恢复');
async function api(url,options={}){
 const {timeoutMs=60000,...requestOptions}=options;
 const ac=new AbortController(),timer=setTimeout(()=>ac.abort(),timeoutMs);
 try{
  const response=await fetch(url,{...requestOptions,signal:ac.signal,cache:'no-store'});
  if(!response.ok){const e=new Error(await response.text());e.httpStatus=response.status;throw e;}
  return await response.json();
 }catch(e){
  Ti60Task.error(e);
  if(url.startsWith('/api/student/frame/start')&&!e.httpStatus){
   try{const state=await Ti60Transfer.json('/api/student/frame/status',{});const requested=new URL(url,location.href).searchParams.get('request');if(state.request===requested&&state.cookie&&(state.busy||state.done))return {...state,accepted:true};}catch{}
  }throw e;
 }finally{clearTimeout(timer);}
}
async function readDiagnostics(){
 const diagnostics={browser:{...Ti60Task.saved,diagnostics:undefined},image:window.Ti60ImageDiagnostic||null};
 for(const [key,url] of [['board','/api/status'],['frame','/api/student/frame/status'],['transport','/api/transport/status'],['device','/api/device/diagnostics']]){
  try{diagnostics[key]=await api(url,{timeoutMs:10000});}catch(e){diagnostics[key]={unavailable:e.message};}
 }
 Ti60Task.diagnostics(diagnostics);$('diagnostics').textContent=JSON.stringify(diagnostics,null,2);
}
function transfer(url,options,label){
 return new Promise((resolve,reject)=>{
  const x=new XMLHttpRequest();activeTransfer=x;let received=0;
  const finish=(error,body)=>{if(activeTransfer===x)activeTransfer=null;error?reject(error):resolve(body);};
  x.open(options.method||'GET',url);x.responseType='arraybuffer';
  // FPGA JPEG preparation (120 s) + body deadline (90 s) + cleanup margin.
  x.timeout=options.method==='POST'?120000:240000;
  x.upload.onprogress=e=>setTaskProgress(label+'：'+(e.lengthComputable?Math.floor(e.loaded/e.total*100)+'%':'上传中'),e.lengthComputable?e.loaded/e.total*100:null);
  x.upload.onload=()=>setTaskProgress('等待FPGA确认输入',null);
  x.onprogress=e=>{received=e.loaded;setTaskProgress(label+'：'+(e.lengthComputable?Math.floor(e.loaded/e.total*100)+'%':Math.floor(e.loaded/1024)+' KB')+'（传输进度）',e.lengthComputable?Math.min(99,e.loaded/e.total*100):null);};
  x.onload=()=>{
   if(x.status<200||x.status>=300){const e=new Error(new TextDecoder().decode(x.response||new ArrayBuffer(0)));e.httpStatus=x.status;finish(e);return;}
   finish(null,new Uint8Array(x.response));
  };
  x.onerror=()=>finish(new Error(label+'连接中断或校验被拒绝；已接收 '+received+' 字节'));
  x.ontimeout=()=>finish(new Error(label+'超时；已接收 '+received+' 字节'));
  x.onabort=()=>finish(transferPause());x.send(options.body||null);
 });
}
async function pollFrame(){
 let failures=0;
 for(;;){
  if(pauseRequested)throw transferPause();
  let s;
  try{s=await api('/api/student/frame/status',{timeoutMs:10000});failures=0;}
  catch(e){
   if(e.httpStatus&&e.httpStatus<500)throw e;
   if(++failures>=5)throw new Error('任务查询连续失败；板端可能仍在处理，请继续读取。'+e.message);
   statusEl.textContent='任务查询暂时中断，正在重新连接（'+failures+'/3）；不会重新提交计算';
   await new Promise(r=>setTimeout(r,1000));continue;
  }
  if(!s.available)throw Error('FPGA整帧接口不可用');
  if(activeJob!=null&&s.job_id!==activeJob)throw Error('板卡任务已更换，请重新查询');
  if(Ti60Task.saved.cookie&&s.cookie!==Ti60Task.saved.cookie)throw Error('FPGA任务身份已更换，停止读取旧结果');Ti60Task.bind(s);activeBoot=s.boot_id??null;
  if(activeBoot==null&&s.boot_id!=null)activeBoot=s.boot_id;
  if(s.error)throw Error('FPGA处理错误，尚无完整结果；错误码 '+(s.model_error??'未知'));
  if(!s.busy&&!s.done)throw Error('板卡上没有可读取的任务');
  const pct=(s.full_model||s.full_color)&&s.commands_total?Math.min(99,Math.floor(s.command/s.commands_total*100)):s.pixels_total?Math.min(99,Math.floor(s.pixels_done/s.pixels_total*100)):0;
  setTaskProgress((s.full_model||s.full_color)?'FPGA计算：指令进度 '+pct+'% · '+s.command+'/'+s.commands_total:'FPGA处理 '+pct+'% · '+s.pixels_done+'/'+s.pixels_total+' 像素',pct);
  statusEl.textContent='正在板内处理 '+s.width+'×'+s.height+'；指令进度不等于剩余时间';
  if(s.done){if(s.busy||s.pixels_done!==s.pixels_total)throw Error('写回计数未完成');frameComputationDone=true;return s;}
  await new Promise(resolve=>setTimeout(resolve,600));
 }
}
async function readValidatedFrame(s,source,canvas,label,keep=false){
 if(pauseRequested)throw transferPause();
 let bytes=await Ti60Transfer.read('/capture?source='+source,{task:s,onprogress:(label,value)=>setTaskProgress(label,value)});
 if(pauseRequested)throw transferPause();
 canvas.dataset.recovery='';
 if(!Ti60Transfer.isRaw(bytes)){
  try{Ti60Jpeg.validate(bytes,s);}catch(e){
   if(e.code!=='JPEG_CONTENT')throw e;Ti60Task.error(e);setTaskProgress('JPEG 内容异常，保留任务并直接读取原始像素',null);
   bytes=await Ti60Transfer.read('/capture?source='+source+'&format=rgb565',{task:s,strategy:'direct',spiMHz:5,onprogress:(label,value)=>setTaskProgress(label,value)});
   if(!Ti60Transfer.isRaw(bytes))throw Error('JPEG 内容异常且固件未返回原始像素；任务保留，请检查配套位流');
   canvas.dataset.recovery='rgb565';
  }
 }
 if(pauseRequested)throw transferPause();await decodeFrame(bytes,canvas,s);
}
async function readFrameResult(s){
 frameComputationDone=true;window.Ti60ImageDiagnostic=null;
 const identity=[s.boot_id,s.cookie,s.job_id].join(':');
 if(result.dataset.task!==identity){complete=false;Ti60Document.reset(result);}
 await Ti60Session.restoreTask(s);
 const profile=await Ti60Session.taskProfile(s),incoming=document.createElement('canvas');
 let nextName=taskImageName('result',s);
 try{
 setTaskProgress('FPGA计算已完成，正在回传处理结果',null);
 const wantOriginal=s.source==='camera'&&$('returnOriginal').checked;
 if(s.source==='camera'&&original.dataset.task!==identity)original.dataset.mismatched='1';
 await readValidatedFrame(s,'result',incoming,'结果回传',wantOriginal);
 await Ti60ResultGuard.verify({state:s,canvas:incoming,original:original.dataset.mismatched==='1'?null:original,progress:setTaskProgress,readRaw:async(source,canvas)=>{if(pauseRequested)throw transferPause();const bytes=await Ti60Transfer.read('/capture?source='+source+'&format=rgb565',{task:s,strategy:'direct',spiMHz:5,onprogress:setTaskProgress});if(!Ti60Transfer.isRaw(bytes))throw Error('原始像素核对失败；任务已保留');await decodeFrame(bytes,canvas,s);}});
 const selectedFinish=profile.browserFinish||'auto',finish=profile.studentOutput==='document'?'document':selectedFinish==='auto'?(s.output==='binary'?'specks':'none'):selectedFinish;
 if(finish!=='none'){setTaskProgress(finish==='document'?'扫描文档去阴影 / 转黑白':'可选结果优化',null);await finishBrowserCanvas(incoming,finish);nextName=nextName.replace(/\.jpg$/,'.png');}
 if(profile.studentOutput==='color'&&await Ti60Screen.finish(incoming,profile.chromaStrength||'off',profile.chromaScale||'medium'))nextName=nextName.replace(/\.jpg$/,'.png');
 // Commit a fully validated replacement; a failed reread leaves the previous image intact.
 Ti60Document.reset(result);result.width=incoming.width;result.height=incoming.height;
 result.getContext('2d').drawImage(incoming,0,0);
 for(const key of ['jpegBlob','fpgaPixels','cleanedBlob','scanBaseBlob','colorBaseBlob'])result[key]=incoming[key]||null;
 result.dataset.transport=incoming.dataset.transport;result.dataset.recovery=incoming.dataset.recovery||'';
 result.dataset.task=identity;result.dataset.complete='1';showingFpga=false;
 resultDownloadName=nextName;originalDownload=null;complete=true;
 $('saveFpga').textContent=result.dataset.transport==='rgb565'?'下载原始像素转存JPEG':'下载FPGA原始结果JPEG';
 if(s.source==='upload'&&localInputSnapshot&&localInputSnapshot.job===s.job_id&&(localInputSnapshot.cookie==null||localInputSnapshot.cookie===s.cookie))originalDownload={blob:localInputSnapshot.blob,name:taskImageName('original',s)};
 if(wantOriginal){
  try{await readValidatedFrame(s,'frame_original',original,'原图回传');original.dataset.task=identity;original.dataset.mismatched='';originalDownload={blob:original.jpegBlob,name:taskImageName('original',s)};}
  catch(e){statusEl.textContent='结果已完成；原图读取失败：'+e.message;setTaskProgress('结果已校验，原图未返回',100);return;}
 }
 statusEl.textContent='完成 '+s.width+'×'+s.height+'；结果已通过CRC校验'+(result.dataset.recovery?.startsWith('rgb565')?'；JPEG 异常已改读原始像素并重新生成下载文件':'');setTaskProgress('完成',100);
 }finally{incoming.width=incoming.height=0;result.dispatchEvent(new Event('ti60-result'));}
}

async function encodeUpload(canvas){return encodeJpegUpload(canvas)}
async function decodeFrame(bytes,canvas,expected){await decodeJpeg(bytes,canvas,expected)}
async function processFrame(attach=false){await Ti60Session.ready;if(processing)return;if(!available&&!attach){statusEl.textContent='接口未连接，请先点击查询 / 继续读取';return;}if(!attach&&sourceKind==='local'&&!original.dataset.loaded)return;processing=true;if(!attach){complete=false;Ti60Document.reset(result);}frameComputationDone=false;pauseRequested=false;controls();try{if(!attach){originalDownload=null;localInputSnapshot=null;if(sourceKind==='local'){const uploadInput=prepareBrowserInput(original),packet=await encodeUpload(uploadInput),form=new FormData();localInputSnapshot={blob:new Blob([packet.subarray(16,packet.length-4)],{type:'image/jpeg'}),job:null};form.append('frame',new Blob([packet],{type:'application/octet-stream'}),'frame.ujig');statusEl.textContent='上传裁剪后的原图';await transfer('/api/upload?size='+(original.width===256?2:original.width===1920?1:0)+'&mode=0&alg=0',{method:'POST',body:form},'上传原图');}setTaskProgress('正在冻结完整帧并启动处理',null);const query=new URLSearchParams({source:sourceKind==='camera'?'camera':'upload',resolution:String(cameraResolution),output:$('studentOutput').value==='document'?'color':$('studentOutput').value,pipeline:$('studentPipeline').value});const requestToken=Ti60Task.token();query.set('request',requestToken);Ti60Task.begin(requestToken,String(query));await Ti60Session.savePending(localInputSnapshot,requestToken);const accepted=await api('/api/student/frame/start?'+query,{method:'POST'});Ti60Task.bind(accepted);activeJob=accepted.job_id;activeBoot=accepted.boot_id??null;if(localInputSnapshot){localInputSnapshot.job=activeJob;localInputSnapshot.boot=activeBoot;localInputSnapshot.cookie=accepted.cookie;}await Ti60Session.bindTask(localInputSnapshot,accepted);}else{const s=await api('/api/student/frame/status');available=s.available;if(!available)throw Error(window.TI60_OFFLINE?'未连接设备，当前为界面预览':'模型接口暂不可用，请查看设备诊断');if(!s.busy&&!s.done)throw Error('板卡上没有任务');activeJob=s.job_id;activeBoot=s.boot_id??null;Ti60Task.bind(s);}const state=await pollFrame();await readFrameResult(state);}catch(e){statusEl.textContent=e.message;setTaskProgress(e.code==='IMAGE_CONTENT'?'结果内容异常，任务已保留':complete?'重读未完成，保留上次已校验结果':frameComputationDone?'FPGA已完成，回传未完成':'任务查询或读取未完成',complete?100:null);await readDiagnostics();}finally{processing=false;controls();}}
$('file').onchange=async e=>{const f=e.target.files[0];if(!f||processing)return;sourceKind='local';complete=false;Ti60Document.reset(result);studentOriginalFile=f;try{await loadStudentCrop(f);$('sourceInfo').textContent='本地图片：按绿色裁剪框准备输入';}catch(e){original.dataset.loaded='';statusEl.textContent='图片读取失败：'+e.message;}controls();};
async function chooseCamera(resolution){
 if(processing)return;processing=true;controls();statusEl.textContent='正在切换 '+resolution+'p摄像头';
 try{const ac=new AbortController(),timer=setTimeout(()=>ac.abort(),60000);let response;try{response=await fetch('/api/resolution?value='+(resolution===1080?1:0),{method:'POST',signal:ac.signal});if(!response.ok)throw Error(await response.text());}finally{clearTimeout(timer);}
 clearStudentCrop();sourceKind='camera';cameraResolution=resolution;original.width=0;original.height=0;original.dataset.loaded='';result.width=0;complete=false;$('sourceInfo').textContent=resolution+'p摄像头已切换；开始时冻结并处理';statusEl.textContent='摄像头已切换至 '+resolution+'p';
 }catch(e){statusEl.textContent='切换失败：'+e.message;}finally{processing=false;controls();}
}
$('camera720').onclick=()=>chooseCamera(720);$('camera1080').onclick=()=>chooseCamera(1080);
let showingFpga=false;
$('saveFpga').onclick=()=>{if(processing||!complete||!result.jpegBlob)return;saveJpeg({jpegBlob:result.jpegBlob},resultDownloadName.replace(/\.(png|jpg)$/,'_fpga.jpg'));};
$('compareFpga').onclick=async()=>{
 if(processing||!complete||!result.cleanedBlob)return;
 showingFpga=!showingFpga;
 const epoch=result.taskEpoch,bitmap=await createImageBitmap(showingFpga?result.jpegBlob:result.cleanedBlob);
 if(processing||epoch!==result.taskEpoch){bitmap.close();return;}
 result.getContext('2d').clearRect(0,0,result.width,result.height);result.getContext('2d').drawImage(bitmap,0,0);bitmap.close();result.dispatchEvent(new Event('ti60-result'));
 statusEl.textContent=showingFpga?'显示：FPGA原始结果（未作后续优化）':'显示：优化结果';
};
run.onclick=()=>processFrame(false);$('attach').onclick=()=>processFrame(true);stop.onclick=()=>{pauseRequested=true;Ti60Transfer.abort();if(activeTransfer)activeTransfer.abort();};save.onclick=()=>{if(processing||!complete)return;saveJpeg(!showingFpga&&result.cleanedBlob?{jpegBlob:result.cleanedBlob}:result,showingFpga?resultDownloadName.replace(/\.(png|jpg)$/,'_fpga.jpg'):resultDownloadName);};$('saveOriginal').onclick=()=>{if(processing||!complete||!originalDownload)return;saveJpeg({jpegBlob:originalDownload.blob},originalDownload.name);};
// Local input crop shared by model-only and joint processing. Camera frames remain native.
let studentLoadTicket=0;let studentCropImage=null,studentCropFocusX=.5,studentCropFocusY=.5,studentCropDrag=null,studentCropView=null;
const cropPanel=document.querySelector('#studentCropPanel'),cropCanvas=document.querySelector('#studentCropPreview');
function studentCropGeometry(sw,sh,tw,th,fit,fx,fy){
 let w=sw,h=sh,dx=0,dy=0,dw=tw,dh=th;
 if(fit==='contain'){const scale=Math.min(tw/sw,th/sh);dw=sw*scale;dh=sh*scale;dx=(tw-dw)/2;dy=(th-dh)/2;}
 else if(fit==='pixel'){w=Math.min(sw,tw);h=Math.min(sh,th);dw=w;dh=h;dx=(tw-w)/2;dy=(th-h)/2;}
 else if(sw/sh>tw/th)w=sh*tw/th;else h=sw*th/tw;
 return{x:(sw-w)*Math.max(0,Math.min(1,fx)),y:(sh-h)*Math.max(0,Math.min(1,fy)),w,h,dx,dy,dw,dh};
}
function renderStudentCrop(){
 if(!studentCropImage||processing)return;
 const sw=studentCropImage.width,sh=studentCropImage.height,big=document.querySelector('#jointSize').value==='1080',small=document.querySelector('#jointSize').value==='small',
       tw=small?256:big?1920:1024,th=small?224:big?1080:600,fit=document.querySelector('#studentCropFit').value,
       g=studentCropGeometry(sw,sh,tw,th,fit,studentCropFocusX,studentCropFocusY);
 original.width=tw;original.height=th;const ctx=original.getContext('2d');ctx.fillStyle='#222';ctx.fillRect(0,0,tw,th);
 ctx.drawImage(studentCropImage,g.x,g.y,g.w,g.h,g.dx,g.dy,g.dw,g.dh);
 cropCanvas.width=640;cropCanvas.height=360;const pc=cropCanvas.getContext('2d'),scale=Math.min(640/sw,360/sh),ox=(640-sw*scale)/2,oy=(360-sh*scale)/2;
 pc.fillStyle='#222';pc.fillRect(0,0,640,360);pc.drawImage(studentCropImage,ox,oy,sw*scale,sh*scale);
 if(fit!=='contain'){pc.strokeStyle='#36a269';pc.lineWidth=3;pc.strokeRect(ox+g.x*scale,oy+g.y*scale,g.w*scale,g.h*scale);}
 studentCropView={g,scale,ox,oy,sw,sh,fit};original.dataset.loaded='1';original.dataset.prepared='';original.dataset.cameraResolution='';original.dataset.mismatched='';original.dataset.task='';complete=false;Ti60Document.reset(result);
 document.querySelector('#studentCropInfo').textContent=sw+'×'+sh+' → '+tw+'×'+th+' · '+(fit==='contain'?'完整保留':fit==='pixel'?'原始像素1:1裁剪':'保留区域 '+(g.w*g.h/sw/sh*100).toFixed(1)+'%')+'；绿色框可拖动';
 controls();
}
async function loadStudentCrop(file){
 const ticket=++studentLoadTicket;const image=await createImageBitmap(file);if(ticket!==studentLoadTicket){image.close();return;}if(studentCropImage)studentCropImage.close();studentCropImage=image;
 studentCropFocusX=.5;studentCropFocusY=.5;cropPanel.hidden=false;document.querySelector('#jointSizeGroup').hidden=false;
 renderStudentCrop();statusEl.textContent='已加载图片，请调整裁剪后开始处理';
}
function clearStudentCrop(){if(studentCropImage)studentCropImage.close();studentCropImage=null;studentCropView=null;studentCropDrag=null;cropPanel.hidden=true;studentOriginalFile=null;}
function studentCropPoint(e){const r=cropCanvas.getBoundingClientRect();return{x:(e.clientX-r.left)*cropCanvas.width/r.width,y:(e.clientY-r.top)*cropCanvas.height/r.height};}
cropCanvas.onpointerdown=e=>{if(processing||!studentCropView||studentCropView.fit==='contain')return;const p=studentCropPoint(e),v=studentCropView,g=v.g;
 if(p.x<v.ox+g.x*v.scale||p.x>v.ox+(g.x+g.w)*v.scale||p.y<v.oy+g.y*v.scale||p.y>v.oy+(g.y+g.h)*v.scale)return;
 studentCropDrag={id:e.pointerId,p,x:g.x,y:g.y,w:g.w,h:g.h,sw:v.sw,sh:v.sh,scale:v.scale};cropCanvas.setPointerCapture(e.pointerId);e.preventDefault();};
cropCanvas.onpointermove=e=>{const d=studentCropDrag;if(!d||d.id!==e.pointerId||processing)return;const p=studentCropPoint(e),mx=d.sw-d.w,my=d.sh-d.h;
 studentCropFocusX=mx?Math.max(0,Math.min(1,(d.x+(p.x-d.p.x)/d.scale)/mx)):.5;
 studentCropFocusY=my?Math.max(0,Math.min(1,(d.y+(p.y-d.p.y)/d.scale)/my)):.5;renderStudentCrop();e.preventDefault();};
function stopStudentCropDrag(e){if(studentCropDrag?.id===e.pointerId)studentCropDrag=null;}
cropCanvas.onpointerup=stopStudentCropDrag;cropCanvas.onpointercancel=stopStudentCropDrag;
document.querySelector('#studentCropFit').onchange=renderStudentCrop;
document.querySelector('#studentCropReset').onclick=()=>{studentCropFocusX=.5;studentCropFocusY=.5;renderStudentCrop();};
document.querySelector('#jointSize').onchange=renderStudentCrop;
document.querySelector('#studentPipeline').onchange=()=>{document.querySelector('#jointSizeGroup').hidden=!studentCropImage&&document.querySelector('#studentPipeline').value!=='joint';};

$('studentPipeline').onchange=()=>{$('pipelineInfo').textContent=$('studentPipeline').value==='joint'?'共享网络 → FPGA亮度校正/保笔画二值算法；结果优化可选。':'FPGA共享主干与对应输出头；结果优化可选。';controls();};
async function refreshModelConnection(){
 if(window.TI60_OFFLINE){available=false;statusEl.textContent='未连接设备，当前为界面预览';controls();return;}
 try{
  const s=await api('/api/student/frame/status');available=!!s.available&&!s.error;
  if(s.error){statusEl.textContent='模型处理异常，错误码 '+(s.model_error??'未知')+'；请查看设备诊断';}
  else if(s.busy||s.done)statusEl.textContent=s.busy?'任务正在处理，可继续读取':'已有任务结果，可继续读取';
  else{
   const boot=await api('/api/boot-model/status');
   if(boot.error){available=false;statusEl.textContent='模型装载异常，请查看设备诊断';}
   else if(boot.busy){available=false;statusEl.textContent='模型正在装载，请稍候';setTimeout(()=>{if(!processing)refreshModelConnection()},3000);}
   else statusEl.textContent=available?'设备就绪，可开始处理':'当前设备不支持模型接口';
  }
 }catch(e){available=false;statusEl.textContent='设备未连接或通信中断，请检查连接';}
 controls();
}
refreshModelConnection();
</script></body></html>
)STUDENT";
uint8_t fpgaTransfer(uint8_t command,uint8_t data);
void studentWrite(uint8_t address,uint8_t value){fpgaTransfer(address & 0x7f,value);}

 

static String modelRawBody;
static bool modelRawComplete=false;
static String modelRawError;
void receiveModelRawBody(){
  HTTPRaw &raw=http.raw();
  if(raw.status==RAW_START){
    refreshFrameJobLock();
    modelRawBody="";modelRawComplete=false;modelRawError="";
    if(httpCaptureBusy||httpUploadBusy){modelRawError="已有图像任务正在运行，请先完成或读取结果";return;}
  }
  if(raw.status==RAW_WRITE && modelRawError.length()==0){
    const size_t limit=http.uri()=="/api/portrait/load"?49152u:http.uri()=="/api/student/batch"?6144u:768u;
    if(modelRawBody.length()+raw.currentSize>limit){modelRawError="输入数据超过长度限制";modelRawBody="";return;}
    if(raw.currentSize>HTTP_RAW_BUFLEN){modelRawError="原始数据块长度错误";return;}
     
    char chunk[HTTP_RAW_BUFLEN+1];memcpy(chunk,raw.buf,raw.currentSize);chunk[raw.currentSize]=0;
    if(!modelRawBody.concat(chunk,raw.currentSize)){modelRawError="ESP32内存不足，请重新载入图片";modelRawBody="";}
  }
  if(raw.status==RAW_END)modelRawComplete=modelRawError.length()==0 && modelRawBody.length()==raw.totalSize;
  if(raw.status==RAW_ABORTED){modelRawBody="";modelRawComplete=false;modelRawError="上传中断，请重新发送图片";}
}
bool modelBodyReady(){
  if(modelRawComplete)return true;
  http.send(modelRawError.length()?409:400,"text/plain; charset=utf-8",modelRawError.length()?modelRawError:"原始图像数据未接收完整，请刷新页面重试");
  return false;
}



 
uint32_t studentCrc(const uint8_t *p,size_t n){return ti60Crc32(p,n);}







#include "portrait_handlers.h"

void handleImageDiagnostics(){
 char body[384];snprintf(body,sizeof(body),"{\"device\":%u,\"status\":%u,\"i2c\":%u,\"camera_frames\":%u,\"camera_lines\":%u,\"line_bytes_min\":%u,\"line_bytes_max\":%u,\"capture_stage\":%u,\"student_id\":%u,\"student_status\":%u,\"portrait_id\":%u,\"portrait_status\":%u,\"portrait_stage\":%u,\"native_upload\":%u}",fpgaRead(REG_DEVICE_ID),fpgaRead(REG_STATUS),fpgaRead(REG_I2C_STATUS),fpgaRead16(REG_CAM_FRAME_LO),fpgaRead16(REG_CAM_LINES_LO),fpgaRead16(REG_CAM_MIN_LO),fpgaRead16(REG_CAM_MAX_LO),capturePrepareStage,fpgaRead(0x40),fpgaRead(0x43),fpgaRead(0x50),fpgaRead(0x51),fpgaRead(0x55),fpgaRead(0x36));
 http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",body);
}

bool bootModelBusy();
String bootModelStatus();
bool ensureBootProgram(uint8_t hd);
#include "full_student_handlers.h"
#include "task_journal.h"
#include "boot_model_loader.h"
#include "student_frame_handlers.h"
#include "result_cache.h"
#include "device_ui_assets.h"
#include "focus_preview.h"
#include "focus_preview_page.h"
#include "camera_profile.h"
void onFpga(const char *path,HTTPMethod method,WebServer::THandlerFunction fn){
 http.on(path,method,[fn](){if(rejectPreviewMutation())return;if(resultWorkerActive){http.send(423,"text/plain","JPEG cache preparation owns SPI; retry shortly");return;}fn();});
}
void onFpga(const char *path,HTTPMethod method,WebServer::THandlerFunction fn,WebServer::THandlerFunction upload){
 http.on(path,method,[fn](){if(rejectPreviewMutation())return;if(resultWorkerActive){http.send(423,"text/plain","JPEG cache preparation owns SPI");return;}fn();},[upload](){if(!previewActive&&!resultWorkerActive)upload();});
}

static bool accessPointStarted=false;

bool tryStartAccessPoint() {
  IPAddress ip(192, 168, 4, 1), gateway(192, 168, 4, 1), mask(255, 255, 255, 0);
  const bool modeOk=WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);
  const bool configOk=modeOk && WiFi.softAPConfig(ip, gateway, mask);
  const bool apOk=configOk && WiFi.softAP(AP_SSID, AP_PASSWORD, 6, false, 2);
  accessPointStarted=apOk && WiFi.softAPIP()==ip;
  Serial.printf("[WIFI_BOOT] mode=%u config=%u ap=%u ready=%u ip=%s heap=%lu min_heap=%lu\n",
                unsigned(modeOk),unsigned(configOk),unsigned(apOk),unsigned(accessPointStarted),
                WiFi.softAPIP().toString().c_str(),(unsigned long)ESP.getFreeHeap(),
                (unsigned long)ESP.getMinFreeHeap());
  return accessPointStarted;
}

void startAccessPoint() {
  onFpga("/api/boot-model/status",HTTP_GET,[](){http.sendHeader("Cache-Control","no-store");http.send(200,"application/json",bootModelStatus());});
  for(uint8_t attempt=0;attempt<3 && !tryStartAccessPoint();++attempt)delay(250);
  onFpga("/api/student/frame/start",HTTP_POST,handleFrameStudentStart);
  http.on("/api/student/frame/status",HTTP_GET,handleFrameStudentStatus);
  http.on("/model",HTTP_GET,[](){http.sendHeader("Cache-Control","no-store");http.send_P(200,"text/html; charset=utf-8",FULL_MODEL_PAGE);});
  onFpga("/api/full-model/status",HTTP_GET,handleFullModelStatus);
  onFpga("/api/full-model/load",HTTP_POST,handleFullModelLoad,receiveFullModel);
  http.on("/", HTTP_GET, handleRoot);
  onFpga("/api/student/batch",HTTP_POST,[](){http.send(410,"text/plain; charset=utf-8","旧学生页面已停用，请刷新 /student 使用D2整帧处理");});
  onFpga("/api/student/tile",HTTP_POST,[](){http.send(410,"text/plain; charset=utf-8","旧学生页面已停用，请刷新 /student 使用D2整帧处理");});
  http.on("/student",HTTP_GET,[](){http.sendHeader("Cache-Control","no-store");http.send_P(200,"text/html; charset=utf-8",STUDENT_PAGE);});
  http.on("/local", HTTP_GET, handleLocalPage);
  onFpga("/capture", HTTP_GET, handleCaptureHttp);
  onFpga("/api/upload", HTTP_POST, handleUploadComplete, handleUploadData);
  http.on("/api/status", HTTP_GET, handleStatusHttp);
  http.on("/api/transport/status",HTTP_GET,handleTransportStatus);
  onFpga("/api/camera/profile",HTTP_GET,handleCameraProfileStatus);
  onFpga("/api/camera/profile",HTTP_POST,handleCameraProfileApply);
  onFpga("/api/mode", HTTP_POST, handleModeHttp);
  onFpga("/api/resolution", HTTP_POST, handleResolutionHttp);
  onFpga("/api/freeze", HTTP_POST, handleFreezeHttp);
  onFpga("/api/resume", HTTP_POST, handleResumeHttp);
  onFpga("/api/brightness", HTTP_POST, handleBrightnessHttp);
  http.on("/portrait",HTTP_GET,[](){http.send_P(200,"text/html; charset=utf-8",PORTRAIT_PAGE);});
  onFpga("/api/portrait/status",HTTP_GET,handlePortraitStatus);
  onFpga("/api/portrait/load",HTTP_POST,handlePortraitLoad,receiveModelRawBody);
  onFpga("/api/portrait/result",HTTP_GET,handlePortraitResult);
  onFpga("/api/diagnostics",HTTP_GET,handleImageDiagnostics);
  http.onNotFound([]() { http.send(404, "text/plain; charset=utf-8", "not found"); });
  http.on("/api/result/prepare",HTTP_POST,[](){if(!rejectPreviewMutation())handleResultPrepare();});
  http.on("/focus",HTTP_GET,[](){http.sendHeader("Cache-Control","no-store");http.send_P(200,"text/html; charset=utf-8",FOCUS_PAGE);});
  http.on("/api/preview/start",HTTP_POST,handlePreviewStart);
  http.on("/api/preview/stop",HTTP_POST,handlePreviewStop);
  http.on("/api/preview/status",HTTP_GET,handlePreviewStatus);
  http.on("/api/preview/frame",HTTP_GET,handlePreviewFrame);
  http.on("/api/result/status",HTTP_GET,handleResultStatus);
  http.on("/api/result/chunk",HTTP_GET,handleResultChunk);
  http.on("/api/device/diagnostics",HTTP_GET,handlePersistentDiagnostics);
  http.on("/ui.css",HTTP_GET,[](){http.sendHeader("Cache-Control","no-cache");http.sendHeader("Content-Encoding","gzip");http.send_P(200,"text/css; charset=utf-8",DEVICE_CSS,sizeof(DEVICE_CSS));});
  http.on("/ui.js",HTTP_GET,[](){http.sendHeader("Cache-Control","no-cache");http.sendHeader("Content-Encoding","gzip");http.send_P(200,"application/javascript; charset=utf-8",DEVICE_UI_JS,sizeof(DEVICE_UI_JS));});
  http.on("/transport-v4.js",HTTP_GET,[](){http.sendHeader("Cache-Control","no-cache");http.sendHeader("Content-Encoding","gzip");http.send_P(200,"application/javascript; charset=utf-8",DEVICE_TRANSPORT_JS,sizeof(DEVICE_TRANSPORT_JS));});
  http.begin();
  if(accessPointStarted)
    Serial.printf("HTTP AP: SSID=%s PASS=%s URL=http://%s/\n", AP_SSID, AP_PASSWORD, WiFi.softAPIP().toString().c_str());
  else Serial.println("[WIFI_BOOT] AP failed; retrying every 5 seconds, see preceding error/heap logs");
}

uint8_t fpgaTransfer(uint8_t command, uint8_t data) {
  fpgaSpi.beginTransaction(SPISettings(SPI_HZ_CONTROL, MSBFIRST, SPI_MODE0));
  digitalWrite(PIN_CS, LOW);
  fpgaSpi.transfer(command);
  uint8_t response = fpgaSpi.transfer(data);
  delayMicroseconds(2);  
  digitalWrite(PIN_CS, HIGH);
  fpgaSpi.endTransaction();
  delayMicroseconds(20);
  return response;
}

uint8_t fpgaRead(uint8_t address) {
  return fpgaTransfer(0x80 | (address & 0x7F), 0x00);
}

uint16_t fpgaRead16(uint8_t lowAddress) {
  uint8_t low = fpgaRead(lowAddress);
  uint8_t high = fpgaRead(lowAddress + 1);
  return static_cast<uint16_t>(low) | (static_cast<uint16_t>(high) << 8);
}

void fpgaWrite(uint8_t address, uint8_t value) {
  fpgaTransfer(address & 0x7F, value);
  delay(1);
}

void printStatus() {
  uint8_t value = fpgaRead(REG_STATUS);
  Serial.printf("STATUS=0x%02X frozen=%u dump_busy=%u ddr_done=%u ddr_pass=%u camera_alive=%u stream_ready=%u frame_ready=%u mode=%u\n",
                value, value & 1, (value >> 1) & 1, (value >> 2) & 1,
                (value >> 3) & 1, (value >> 4) & 1, (value >> 5) & 1,
                (value >> 6) & 1, fpgaRead(REG_SCAN_MODE) & 3);
}

bool readCameraDiagnostic(uint16_t &frame, uint16_t &lines,
                          uint16_t &minBytes, uint16_t &maxBytes) {
  for (uint8_t attempt = 0; attempt < 5; ++attempt) {
    uint16_t before = fpgaRead16(REG_CAM_FRAME_LO);
    uint16_t readLines = fpgaRead16(REG_CAM_LINES_LO);
    uint16_t readMin = fpgaRead16(REG_CAM_MIN_LO);
    uint16_t readMax = fpgaRead16(REG_CAM_MAX_LO);
    uint16_t after = fpgaRead16(REG_CAM_FRAME_LO);
    if (before == after) {
      frame = after;
      lines = readLines;
      minBytes = readMin;
      maxBytes = readMax;
      return true;
    }
  }
  return false;
}

void printCameraDiagnostic() {
  uint16_t frame0, lines, minBytes, maxBytes;
  if (!readCameraDiagnostic(frame0, lines, minBytes, maxBytes)) {
    Serial.println("CAM_DIAG ERROR: unstable snapshot; run diag again");
    return;
  }
  delay(1000);
  uint16_t frame1;
  if (!readCameraDiagnostic(frame1, lines, minBytes, maxBytes)) {
    Serial.println("CAM_DIAG ERROR: unstable snapshot; run diag again");
    return;
  }

  uint8_t resolution = fpgaRead(REG_RESOLUTION) & 0x03;
  uint8_t i2cIndex = fpgaRead(REG_I2C_INDEX);
  uint8_t i2cStatus = fpgaRead(REG_I2C_STATUS);
  uint8_t i2cFirstNack = fpgaRead(REG_I2C_FIRST_NACK);
  uint8_t i2cNackCount = fpgaRead(REG_I2C_NACK_COUNT);
   

  bool uses1080Geometry = (resolution != 0);
  uint16_t expectedLines = uses1080Geometry ? 1080 : 720;
  uint16_t expectedBytes = uses1080Geometry ? 3840 : 2560;
  uint16_t framesPerSecond = static_cast<uint16_t>(frame1 - frame0);
  Serial.printf("CAM_DIAG resolution=%s frame=%u fps=%u lines=%u line_bytes_min=%u line_bytes_max=%u expected=%ux%u_bytes\n",
                resolution == 1 ? "1080p" : (resolution == 2 ? "1080p-safe-clock" : "720p"),
                frame1, framesPerSecond, lines, minBytes, maxBytes,
                expectedLines, expectedBytes);
  Serial.printf("I2C_DIAG index=%u done=%u reconfig_active=%u nack_seen=%u first_nack_index=%u nack_count=%u\n",
                i2cIndex, i2cStatus & 1, (i2cStatus >> 1) & 1,
                (i2cStatus >> 2) & 1, i2cFirstNack, i2cNackCount);
  if (frame1 == frame0) {
    Serial.println("CAM_DIAG FAIL: no complete VSYNC frame in 1 second");
  } else if (lines != expectedLines || minBytes != expectedBytes || maxBytes != expectedBytes) {
    Serial.println("CAM_DIAG FAIL: OV5640 output timing does not match selected resolution");
  } else {
    Serial.println("CAM_DIAG PASS: OV5640 raw frame timing matches selected resolution");
    Serial.println("CAM_DIAG NEXT: if image is still corrupt, fault is after the sensor input (crop/DDR/read path)");
  }
}

void printHelp() {
  Serial.println("Commands: id, status, diag, freeze, resume, send, capture, mode <0..3>, resolution <720|1080|hybrid>, brightness <0..127>, read <hex>, write <hex> <hex>, help");
}

bool waitForStatus(uint8_t mask, bool asserted, uint32_t timeoutMs) {
  uint32_t start = millis();
  while ((millis() - start) < timeoutMs) {
    bool state = (fpgaRead(REG_STATUS) & mask) != 0;
    if (state == asserted) return true;
    delay(2);
  }
  return false;
}

bool waitForRegister(uint8_t address, uint8_t expected, uint8_t mask, uint32_t timeoutMs) {
  uint32_t start = millis();
  while ((millis() - start) < timeoutMs) {
    if ((fpgaRead(address) & mask) == (expected & mask)) return true;
    delay(1);
  }
  return false;
}

 


bool streamFrameToSerial() {
  if(httpCaptureBusy||httpUploadBusy){Serial.println("ERROR: image job busy");return false;}
  uint8_t header[FRAME_HEADER_BYTES]={0};uint32_t payload=0;
  if(!prepareFrameStream(header,payload,fpgaRead(REG_SCAN_MODE)&3)){
    fpgaWrite(REG_CONTROL,0x02);restoreHybridPreview();Serial.println("ERROR: native capture preparation failed");return false;
  }
  Serial.write(header,FRAME_HEADER_BYTES);size_t remaining=payload+FRAME_CRC_BYTES;
  while(remaining){const size_t count=remaining>STREAM_CHUNK_BYTES?STREAM_CHUNK_BYTES:remaining;
    fpgaSpi.transferBytes(streamTx,streamRx,count);Serial.write(streamRx,count);remaining-=count;
  }
  Serial.flush();finishFrameStream();return true;
}

void runCommand(String line) {
  line.trim();
  line.toLowerCase();
  if (line.length() == 0) return;
  if((httpCaptureBusy||httpUploadBusy)&&line!="id"&&line!="status"&&line!="diag"&&!line.startsWith("read ")){Serial.println("ERROR: image job busy");return;}

  if (line == "id") {
    Serial.printf("FPGA id=0x%02X protocol=%u\n", fpgaRead(REG_DEVICE_ID), fpgaRead(REG_VERSION));
  } else if (line == "status") {
    printStatus();
  } else if (line == "diag") {
    printCameraDiagnostic();
  } else if (line == "freeze") {
    if(!beginHybridCapture()){Serial.println("ERROR: 1080p switch failed");return;}
    fpgaWrite(REG_CONTROL, 0x01);
    Serial.println("OK freeze requested");
  } else if (line == "resume") {
    fpgaWrite(REG_CONTROL, 0x02);
    if(!restoreHybridPreview()){Serial.println("ERROR: preview restore failed");return;}
    Serial.println("OK resume requested");
  } else if (line == "send") {
    fpgaWrite(REG_CONTROL, 0x04);
    Serial.println("OK UART frame upload requested");
  } else if (line == "capture" || line == "frame") {
     
    streamFrameToSerial();
  } else if (line.startsWith("mode ")) {
    int value = constrain(line.substring(5).toInt(), 0, 3);
    fpgaWrite(REG_SCAN_MODE, static_cast<uint8_t>(value));
    Serial.printf("OK mode=%d\n", value);
  } else if (line.startsWith("resolution ")) {
    String value = line.substring(11);
    uint8_t code = 0;
    if (value == "1080" || value == "1") code = 1;
    else if (value == "hybrid" || value == "mix" || value == "2") code = 2;
    if(httpCaptureBusy||httpUploadBusy||!selectCamera(code)){Serial.println("FAILED camera selection");return;}
    Serial.printf("OK resolution=%u\n", code);
  } else if (line.startsWith("brightness ")) {
    int value = line.substring(11).toInt();
    value = constrain(value, 0, 127);
    fpgaWrite(REG_PWM, static_cast<uint8_t>(value));
    Serial.printf("OK brightness=%d\n", value);
  } else if (line.startsWith("read ")) {
    uint8_t address = strtoul(line.c_str() + 5, nullptr, 0);
    Serial.printf("[0x%02X]=0x%02X\n", address, fpgaRead(address));
  } else if (line.startsWith("write ")) {
    char *end = nullptr;
    const char *text = line.c_str() + 6;
    uint8_t address = strtoul(text, &end, 0);
    uint8_t value = strtoul(end, nullptr, 0);
    fpgaWrite(address, value);
    Serial.printf("OK [0x%02X]=0x%02X\n", address, value);
  } else {
    printHelp();
  }
}

void setup() {
  transportBootId=esp_random();
  Serial.begin(SERIAL_BAUD);
  pinMode(PIN_CS, OUTPUT);
  digitalWrite(PIN_CS, HIGH);
  fpgaSpi.begin(PIN_SCLK, PIN_MISO, PIN_MOSI, PIN_CS);
  delay(100);

  Serial.println("ESP32 -> Ti60 SPI bridge ready");
  Serial.printf("[BOOT] build=wifi-first-20261024 reset_reason=%u heap=%lu\n",
                unsigned(esp_reset_reason()),(unsigned long)ESP.getFreeHeap());
   
  startAccessPoint();
  printHelp();
  uint8_t id = 0;
  for (uint8_t attempt = 0; attempt < 50; ++attempt) {
    id = fpgaRead(REG_DEVICE_ID);
    if (id == 0x60) break;
    delay(100);
  }
  Serial.printf("FPGA probe: %s (0x%02X)\n", id == 0x60 ? "OK" : "FAILED", id);
  uint32_t initStart=millis();
  Serial.println("[BOOT] task journal start");
  beginTaskJournal();
  Serial.printf("[BOOT] task journal done ms=%lu heap=%lu\n",
                (unsigned long)(millis()-initStart),(unsigned long)ESP.getFreeHeap());
  cameraSelection=(fpgaRead(REG_RESOLUTION)&3)==1?1:0;
  initStart=millis();
  Serial.println("[BOOT] result cache start");
  beginResultCache();
  Serial.printf("[BOOT] result cache done ms=%lu ready=%u heap=%lu\n",
                (unsigned long)(millis()-initStart),unsigned(resultFsReady),
                (unsigned long)ESP.getFreeHeap());
  beginBootModel();
}

void loop() {
  static uint32_t lastApRetry=0;
  if(!accessPointStarted && millis()-lastApRetry>=5000){lastApRetry=millis();tryStartAccessPoint();}
  servicePreviewLease();
  if(!resultWorkerActive && !previewActive)serviceBootModel();
  static uint32_t lastFrameLockPoll=0;
  if(!resultWorkerActive && !previewActive && millis()-lastFrameLockPoll>=500){lastFrameLockPoll=millis();refreshFrameJobLock();serviceTaskJournal();}
  if(!resultWorkerActive && !previewActive)servicePortraitLoad();
  http.handleClient();
  delay(1);
  if (!resultWorkerActive && !previewActive && Serial.available()) {
    runCommand(Serial.readStringUntil('\n'));
  }
}


