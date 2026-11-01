#pragma once
static const char PORTRAIT_PAGE[] PROGMEM = R"HTML(<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ti60 人像处理</title>
<style>
body{margin:0;background:#111;color:#eee;font:16px system-ui,sans-serif}main{max-width:1100px;margin:auto;padding:14px}h1{font-size:22px}nav,.controls{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:14px}nav a{color:#9ad;text-decoration:none}nav .active{color:#fff;border-bottom:2px solid #24a148}button,input{font:inherit}button{padding:10px 14px;border:0;border-radius:5px;min-height:42px}button.primary{background:#24a148;color:#fff}button:disabled{opacity:.4}#status{color:#9ad;min-height:24px}progress{display:block;width:100%;height:22px;margin:10px 0}.images{display:grid;grid-template-columns:1fr 1fr;gap:14px}canvas{width:100%;height:auto;background:#222;display:block}#result{background:repeating-conic-gradient(#ddd 0 25%,#888 0 50%) 0/20px 20px}.note{color:#bbb;font-size:13px}@media(max-width:680px){.images{grid-template-columns:1fr}}/* Compact offline UI for phone screens. No external assets or fonts. */
*{box-sizing:border-box}body{margin:0!important;padding:16px!important;background:#111820!important;color:#edf1f5!important;font:15px/1.5 system-ui,"Microsoft YaHei",sans-serif!important;max-width:1100px!important;margin-inline:auto!important}main{padding:0!important}h1{font-size:23px!important;line-height:1.3;margin:8px 0 16px!important}h2{font-size:17px!important;margin:18px 0 8px!important}p{line-height:1.5!important;margin:10px 0!important}nav{display:flex!important;gap:6px!important;flex-wrap:wrap!important;margin:0 0 18px!important;align-items:center}nav a{display:block;padding:8px 10px;background:#202c39;border-radius:5px;color:#b9cee4!important;text-decoration:none!important;font-size:14px;white-space:nowrap}nav a.active,nav a[aria-current="page"]{background:#164875;color:white!important;border:0!important}button{font:inherit!important;font-size:15px!important;min-height:42px!important;padding:9px 13px!important;margin:3px!important;border:1px solid #3d5061!important;border-radius:5px!important;background:#253444!important;color:#f0f4f8!important}button.active,button.primary,#run,#process,#capture{background:#157347!important;color:white!important}button:disabled{opacity:.45!important}input,select{font:inherit!important;max-width:100%;padding:6px;accent-color:#409fe8}input[type=file]{display:block;width:100%;margin:12px 0!important}input[type=checkbox]{width:18px;height:18px}input[type=range]{padding:0;min-width:120px}select{background:#202c39;color:#edf1f5;border:1px solid #3d5061;border-radius:4px}canvas{display:block!important;width:100%!important;height:auto!important;max-height:none;border:1px solid #33485a!important;border-radius:5px}progress{height:14px!important;margin:8px 0 16px!important;accent-color:#36a269;max-width:100%}#status{padding:10px 12px;background:#1e2b38;border-left:3px solid #409fe8;color:#d8e6f4!important;overflow-wrap:anywhere;min-height:42px;font-size:14px}#taskProgressLabel,#progressLabel{display:block;font-size:13px;color:#aabccd;margin-top:8px}details{padding:8px 0;border-top:1px solid #314252;margin:10px 0}summary{font-size:15px;cursor:pointer}.toolbar,.controls{gap:6px!important;flex-wrap:wrap!important;align-items:center}.note,.hint{font-size:13px!important;color:#aabccd!important}.workflow{padding:12px;background:#1e2b38;border:1px solid #314252;border-radius:6px;margin:12px 0}.workflow label{display:inline-flex;gap:8px;align-items:center;margin:6px 12px 6px 0}.images{gap:14px!important}@media(max-width:680px){.images{grid-template-columns:1fr!important}nav{gap:4px!important}nav a{padding:8px!important;font-size:13px}.toolbar button{flex:1 1 100px}body{padding:14px!important}}
</style><style id="ti60-page-transition">html[data-ti60-pending]{background:#f5f7f4!important}html[data-ti60-pending] body{visibility:hidden!important}html[data-ti60-pending]::after{content:'正在打开页面…';position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;background:#f5f7f4;color:#456d62;font:16px system-ui,sans-serif}</style><script>document.documentElement.setAttribute('data-ti60-pending','');window.Ti60PageReady=function(){clearTimeout(window.Ti60PageTimer);document.documentElement.removeAttribute('data-ti60-pending')};window.Ti60PageTimer=setTimeout(window.Ti60PageReady,12000);window.addEventListener('pageshow',function(e){if(e.persisted)window.Ti60PageReady()});</script><link rel="stylesheet" href="/ui.css?v=0fd28c6dd621cc7a"><script src="/transport-v4.js?v=2b4cbb0250fd55ab"></script><script defer src="/ui.js?v=79d1ef5971cfde1c"></script>
<main><h1>Ti60 图像处理</h1><nav><a href="/">摄像头抓拍</a><a href="/local">本地图片</a><a href="/student">模型与联合处理</a><a class="active" href="/portrait">人像</a></nav>
<p id="status">读取板端状态…</p><label id="progressLabel" for="progress">等待图像</label><progress id="progress" max="100" value="0"></progress>
<div class="controls"><input id="file" type="file" accept="image/*"><button id="camera720">抓拍720p</button><button id="camera1080">抓拍1080p</button><button class="primary" id="run" disabled>人像提取</button><button id="restore" disabled>继续读取结果</button><button id="download" disabled>下载透明PNG</button></div>
<p class="note">先选择图片或抓拍，再点击人像提取。处理完成后可下载透明PNG。</p>
<div class="controls"><span>边缘微调：</span><button id="brushKeep" disabled>保留画笔</button><button id="brushErase" disabled>去除画笔</button><button id="brushOff" disabled>结束微调</button><button id="brushReset" disabled>重置微调</button><label>画笔大小 <input id="brushSize" type="range" min="2" max="35" value="12" disabled></label></div><p class="note">若头发或背景有遗漏，可在结果图上用画笔修正后下载。</p><div class="images"><section><h2>原图</h2><canvas id="original"></canvas></section><section><h2>人像结果</h2><canvas id="result"></canvas></section></div></main>
<script>
async function encodeJpegUpload(canvas){
 const w=canvas.width,h=canvas.height;
 if(!((w===1024&&h===600)||(w===1920&&h===1080)))throw Error('不支持的上传尺寸');
 const blob=await new Promise((ok,fail)=>canvas.toBlob(x=>x?ok(x):fail(Error('JPEG编码失败')),'image/jpeg',0.92));
 const raw=new Uint8Array(await blob.arrayBuffer());if(raw[0]!==255||raw[1]!==216)throw Error('JPEG生成失败');
 const n=(raw.length+15)&~15;if(n>4194288)throw Error('JPEG超过4MiB，请降低图片复杂度');
 const packet=new Uint8Array(n+20),v=new DataView(packet.buffer);packet.set([85,74,73,71,1,2]);
 v.setUint16(6,w,true);v.setUint16(8,h,true);v.setUint32(10,n,true);packet.fill(255,16,n+16);packet.set(raw,16);
 v.setUint32(n+16,crc32(packet.subarray(16,n+16)),true);return packet;
}
async function decodeJpeg(bytes,canvas,expected){
 if(Ti60Transfer.isRaw(bytes))return Ti60Transfer.drawRaw(bytes,canvas,expected);
 if(bytes.length<4||bytes[0]!==255||bytes[1]!==216)throw Error('返回数据不是JPEG');
 const blob=new Blob([bytes],{type:'image/jpeg'}),url=URL.createObjectURL(blob),im=new Image();
 try{await new Promise((ok,fail)=>{im.onload=ok;im.onerror=()=>fail(Error('JPEG不完整或解码失败'));im.src=url});
 const w=im.naturalWidth,h=im.naturalHeight;
 if(!((w===1024&&h===600)||(w===1920&&h===1080))||(expected&&(w!==expected.width||h!==expected.height)))throw Error('返回尺寸与任务不一致');
 canvas.width=w;canvas.height=h;canvas.getContext('2d').drawImage(im,0,0);canvas.jpegBlob=blob;
 }finally{URL.revokeObjectURL(url)}
}
function saveJpeg(canvas,name){
 const save=blob=>{if(!blob)return;const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};
 if(canvas.jpegBlob)save(canvas.jpegBlob);else canvas.toBlob(save,'image/jpeg',0.92);
}

const q=s=>document.querySelector(s),original=q('#original'),result=q('#result'),status=q('#status'),bar=q('#progress'),label=q('#progressLabel');
let available=false,busy=false,complete=false,jobStarted=false,lastPortraitMask=null;
function progress(text,value){label.textContent=text;if(value==null)bar.removeAttribute('value');else bar.value=Math.max(0,Math.min(100,value))}
function controls(){document.querySelectorAll('button,input,select').forEach(e=>e.disabled=busy);q('#run').disabled=busy||!available||!original.dataset.loaded;q('#restore').disabled=busy||!available||!original.dataset.loaded||!jobStarted;q('#download').disabled=busy||!complete;brushControls()}
window.updatePortraitControls=controls;
function crc32(bytes){let c=0xffffffff;for(const x of bytes){c^=x;for(let j=0;j<8;j++)c=(c>>>1)^((c&1)?0xedb88320:0)}return (~c)>>>0}
function hex(c){return c.toString(16).padStart(8,'0')}
function portraitTransport(url,options){
if(url.startsWith('/capture'))return Ti60Transfer.read(url,{signal:options.signal,onprogress:progress}).then(bytes=>new Response(bytes,{status:200,headers:{'Content-Type':'image/jpeg'}}));
if(!url.startsWith('/capture')&&!url.startsWith('/api/portrait/result'))return fetch(url,options);
progress(url.startsWith('/capture')?'正在采集 / FPGA处理（暂无内部计数）':'读取人像掩码',null);
return new Promise((resolve,reject)=>{const x=new XMLHttpRequest;x.open(options.method||'GET',url);x.responseType='arraybuffer';
const abort=()=>x.abort(),cleanup=()=>options.signal?.removeEventListener('abort',abort);
x.onprogress=e=>{const total=e.lengthComputable?e.total:options.expectedBytes||(url.startsWith('/api/portrait/result')?4096:0);progress(total?'回传 '+Math.min(100,Math.floor(e.loaded/total*100))+'%':'回传 '+Math.floor(e.loaded/1024)+' KB',total?Math.min(99,e.loaded/total*100):null)};
x.onload=()=>{cleanup();if(x.status!==200){const detail=x.response?new TextDecoder().decode(x.response):'';reject(Error('回传失败 HTTP '+x.status+(detail?'：'+detail:'')));return}progress('正在校验结果',null);resolve({ok:true,headers:{get:name=>x.getResponseHeader(name)},arrayBuffer:async()=>x.response})};
x.onerror=()=>{cleanup();reject(Error('网络中断，可稍后读取结果'))};x.onabort=()=>{cleanup();const e=Error('Aborted');e.name='AbortError';reject(e)};
if(options.signal?.aborted){abort();return}options.signal?.addEventListener('abort',abort,{once:true});x.send(null);
})}
async function request(url,options={}){const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),300000);try{const r=await portraitTransport(url,{...options,signal:controller.signal}),body=await r.arrayBuffer();if(!r.ok)throw Error(new TextDecoder().decode(body));return{headers:r.headers,arrayBuffer:async()=>body,json:async()=>JSON.parse(new TextDecoder().decode(body))}}catch(e){if(e.name==='AbortError')throw Error('回传超时，可稍后读取处理结果');throw e}finally{clearTimeout(timer)}}
function roundedEven(v){const f=Math.floor(v),d=v-f;return d<.5?f:d>.5?f+1:(f%2?f+1:f)}
// Area reduction keeps the full scene and matches the model's square input.
async function modelInput(){const w=original.width,h=original.height,p=original.getContext('2d').getImageData(0,0,w,h).data,out=new Uint8Array(128*128*3),sx=w/128,sy=h/128,area=sx*sy;
for(let y=0;y<128;y++){const y0=y*sy,y1=(y+1)*sy;for(let x=0;x<128;x++){const x0=x*sx,x1=(x+1)*sx,sums=[0,0,0];for(let iy=Math.floor(y0);iy<Math.ceil(y1);iy++){const wy=Math.min(y1,iy+1)-Math.max(y0,iy);for(let ix=Math.floor(x0);ix<Math.ceil(x1);ix++){const weight=wy*(Math.min(x1,ix+1)-Math.max(x0,ix)),i=(iy*w+ix)*4;for(let k=0;k<3;k++)sums[k]+=p[i+k]*weight}}for(let k=0;k<3;k++)out[(y*128+x)*3+k]=roundedEven(sums[k]/area)}if(y%8===7){progress('准备图像 '+Math.round((y+1)/128*100)+'%',(y+1)/128*100);await new Promise(r=>setTimeout(r,0))}}
return out}
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
if(typeof module!=='undefined')module.exports={componentMap,refinePortraitAlpha,cleanTextRgba};

function applyAlpha(raw){if(raw.length!==4096)throw Error('人像掩码长度错误');let a=new Float32Array(4096);for(let i=0;i<4096;i++){const signed=raw[i]<128?raw[i]:raw[i]-256;a[i]=Math.max(0,Math.min(1,(signed+116)*0.004581033252179623))}
lastPortraitMask=raw.slice();a=Ti60Portrait.refine(a,64,64,q('#portraitFinish')?.value||'clean');
const w=original.width,h=original.height,im=original.getContext('2d').getImageData(0,0,w,h);for(let y=0;y<h;y++){const fy=(y+.5)*64/h-.5,y0=Math.floor(fy),vy=fy-y0,lo=Math.max(0,Math.min(63,y0)),hi=Math.max(0,Math.min(63,y0+1));for(let x=0;x<w;x++){const fx=(x+.5)*64/w-.5,x0=Math.floor(fx),vx=fx-x0,left=Math.max(0,Math.min(63,x0)),right=Math.max(0,Math.min(63,x0+1));const top=a[lo*64+left]*(1-vx)+a[lo*64+right]*vx,bottom=a[hi*64+left]*(1-vx)+a[hi*64+right]*vx;im.data[(y*w+x)*4+3]=Math.round(im.data[(y*w+x)*4+3]*(top*(1-vy)+bottom*vy))}}
result.width=w;result.height=h;result.getContext('2d').putImageData(im,0,0);complete=true;brushSnapshot=result.getContext('2d').getImageData(0,0,w,h);chooseBrush(0);brushControls()}
async function loadFrame(bytes){await decodeJpeg(bytes,original);original.dataset.loaded='1';complete=false;jobStarted=false;lastPortraitMask=null}
async function capture(resolution){busy=true;complete=false;controls();try{progress('正在抓拍',null);original.dataset.loaded='';jobStarted=false;lastPortraitMask=null;await loadFrame(new Uint8Array(await(await request('/capture?camera='+resolution+'&mode=0&alg=0',{expectedBytes:resolution===1?4147220:1228820})).arrayBuffer()));status.textContent='原图 '+original.width+'×'+original.height;progress('图像已就绪',0)}catch(e){status.textContent='失败：'+e.message;progress('抓拍失败',0)}finally{busy=false;controls()}}
q('#camera720').onclick=()=>capture(0);q('#camera1080').onclick=()=>capture(1);
q('#file').onchange=async()=>{const file=q('#file').files[0];if(!file)return;busy=true;complete=false;jobStarted=false;lastPortraitMask=null;controls();const url=URL.createObjectURL(file);try{const im=await new Promise((resolve,reject)=>{const i=new Image;i.onload=()=>resolve(i);i.onerror=()=>reject(Error('无法解码图片'));i.src=url});original.width=im.naturalWidth;original.height=im.naturalHeight;original.getContext('2d').drawImage(im,0,0);original.dataset.loaded='1';status.textContent='原图 '+original.width+'×'+original.height;progress('图像已就绪',0)}catch(e){status.textContent='失败：'+e.message;progress('图像载入失败',0)}finally{URL.revokeObjectURL(url);busy=false;controls()}};
function uploadInput(body){return new Promise((resolve,reject)=>{const x=new XMLHttpRequest;x.open('POST','/api/portrait/load');x.setRequestHeader('Content-Type','application/octet-stream');x.responseType='text';x.timeout=120000;x.upload.onprogress=e=>progress(e.lengthComputable?'上传 '+Math.floor(e.loaded/e.total*100)+'%':'上传图像',e.lengthComputable?e.loaded/e.total*100:null);x.upload.onload=()=>progress('板端装载图像',null);x.onload=()=>{try{if(x.status!==202)throw Error(x.responseText);resolve(JSON.parse(x.responseText))}catch(e){reject(e)}};x.onerror=()=>reject(Error('网络中断，可稍后读取结果'));x.ontimeout=()=>reject(Error('装载超时'));x.send(body)})}
async function collect(expectedCrc){const r=await request('/api/portrait/result'),body=new Uint8Array(await r.arrayBuffer()),crc=r.headers.get('X-Portrait-CRC32'),input=r.headers.get('X-Portrait-Input-CRC32');if(input!==hex(expectedCrc))throw Error('结果与当前原图不匹配，请重新处理');if(!crc||!/^[0-9a-f]{8}$/i.test(crc)||crc32(body)!==parseInt(crc,16))throw Error('人像回传CRC错误');progress('生成原分辨率结果',null);applyAlpha(body);status.textContent='完成 '+result.width+'×'+result.height+' · CRC通过 · '+(q('#portraitFinish').value==='raw'?'原模型掩码':'背景清理');progress('处理完成',100)}
q('#run').onclick=async()=>{if(busy||!available||!original.dataset.loaded)return;busy=true;complete=false;controls();try{const body=await modelInput(),inputCrc=crc32(body);jobStarted=true;const ack=await uploadInput(body);if(ack.input_crc!==hex(inputCrc))throw Error('输入CRC错误');jobStarted=true;const deadline=Date.now()+120000;for(;;){const s=await(await request('/api/portrait/status')).json();if(s.error)throw Error('板端处理失败');if(s.done)break;if(Date.now()>deadline)throw Error('处理仍未结束，可稍后读取结果');status.textContent='正在处理人像';if(s.loading)progress('板端装载 '+s.loaded_bytes+'/49152 字节',s.loaded_bytes/49152*100);else progress('网络阶段 '+(Math.min(24,s.stage)+1)+'/25',Math.min(24,s.stage)*4);await new Promise(r=>setTimeout(r,250))}progress('回传人像掩码',null);await collect(inputCrc)}catch(e){status.textContent='未完成：'+e.message;progress('处理未完成',0)}finally{busy=false;controls()}};
q('#restore').onclick=async()=>{if(!jobStarted)return;busy=true;complete=false;controls();try{progress('等待人像计算结果',null);const deadline=Date.now()+120000;for(;;){const s=await(await request('/api/portrait/status')).json();if(s.error)throw Error('FPGA人像任务失败');if(s.has_task===false)throw Error('尚未提交人像任务，请点击人像提取');if(s.done)break;if(Date.now()>deadline)throw Error('仍在计算，请稍后继续读取');await new Promise(r=>setTimeout(r,250))}await collect(crc32(await modelInput()))}catch(e){status.textContent='未完成：'+e.message;progress('结果读取失败',0)}finally{busy=false;controls()}};
function changePortraitFinish(){if(busy||!complete||!lastPortraitMask)return;applyAlpha(lastPortraitMask);status.textContent=q('#portraitFinish').value==='raw'?'已恢复原模型掩码':'已按原掩码重新清理背景；可用画笔补回细发丝';}
q('#download').onclick=()=>result.toBlob(blob=>{if(!blob)return;const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='ti60_portrait_'+result.width+'x'+result.height+'.png';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)},'image/png');
// Optional correction of semantic misses; alpha edits leave original RGB untouched.
let brushMode=0,brushDown=false,brushSnapshot=null;
function brushControls(){for(const id of ['brushKeep','brushErase','brushOff','brushReset','brushSize'])q('#'+id).disabled=busy||!complete;}
function chooseBrush(mode){brushMode=mode;result.style.touchAction=mode?'none':'auto';result.style.cursor=mode?'crosshair':'default';}
function editPortraitPixel(e){
 if(!complete||busy||!brushMode)return;e.preventDefault();const rect=result.getBoundingClientRect(),sx=result.width/rect.width,sy=result.height/rect.height;
 const px=(e.clientX-rect.left)*sx,py=(e.clientY-rect.top)*sy,radius=Number(q('#brushSize').value)*Math.min(sx,sy);
 const x0=Math.max(0,Math.floor(px-radius)),y0=Math.max(0,Math.floor(py-radius)),x1=Math.min(result.width,Math.ceil(px+radius)),y1=Math.min(result.height,Math.ceil(py+radius));
 if(x1<=x0||y1<=y0)return;const ctx=result.getContext('2d'),im=ctx.getImageData(x0,y0,x1-x0,y1-y0);
 for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){
  const distance=Math.hypot(x+.5-px,y+.5-py)/radius;if(distance>=1)continue;const i=((y-y0)*(x1-x0)+x-x0)*4+3,weight=Math.min(1,(1-distance)*4);
  const target=brushMode===1?255:0;im.data[i]=Math.round(im.data[i]*(1-weight)+target*weight);
 }ctx.putImageData(im,x0,y0);
}
q('#brushKeep').onclick=()=>chooseBrush(1);q('#brushErase').onclick=()=>chooseBrush(-1);q('#brushOff').onclick=()=>chooseBrush(0);
q('#brushReset').onclick=()=>{if(!busy&&complete&&brushSnapshot){result.getContext('2d').putImageData(brushSnapshot,0,0);chooseBrush(0);}};
result.onpointerdown=e=>{if(brushMode&&complete&&!busy){brushDown=true;result.setPointerCapture(e.pointerId);editPortraitPixel(e);}};
result.onpointermove=e=>{if(brushDown)editPortraitPixel(e);};result.onpointerup=result.onpointercancel=()=>{brushDown=false;};

(async()=>{try{const s=await(await request('/api/portrait/status')).json();available=s.available;status.textContent=available?'人像模式就绪':'当前FPGA不支持人像模式'}catch(e){status.textContent='状态读取失败：'+e.message}controls()})();
</script>)HTML";
