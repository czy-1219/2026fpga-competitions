(()=>{
 const key='ti60.v4.task';let saved={};try{saved=JSON.parse(localStorage.getItem(key)||'{}')}catch{}
 const persist=()=>{try{localStorage.setItem(key,JSON.stringify(saved))}catch{}};
 const token=()=>Array.from(crypto.getRandomValues(new Uint32Array(4)),x=>x.toString(16).padStart(8,'0')).join('');
 const abort=()=>new DOMException('读取已暂停，任务和缓存保留','AbortError');
 const wait=(ms,signal)=>new Promise((ok,no)=>{if(signal?.aborted)return no(abort());const timer=setTimeout(()=>{signal?.removeEventListener('abort',stop);ok()},ms);const stop=()=>{clearTimeout(timer);no(abort())};signal?.addEventListener('abort',stop,{once:true})});
 const crcTable=Uint32Array.from({length:256},(_,n)=>{let c=n;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);return c>>>0});
 const crc32=data=>{let crc=0xffffffff;for(const byte of data)crc=(crc>>>8)^crcTable[(crc^byte)&255];return (~crc)>>>0};
 const modeKey='ti60.v6.transferMode';let mode='auto';try{if(localStorage.getItem(modeKey)==='cache')mode='cache'}catch{}
 window.Ti60Task={token,get saved(){return saved},begin(request,configuration){saved={request,configuration,startedAt:Date.now(),phase:'submitting'};persist()},bind(s){saved={...saved,job:s.job_id,cookie:s.cookie,boot:s.boot_id,request:s.request||saved.request,lastFrame:s,phase:s.done?'computed':s.busy?'computing':saved.phase};persist()},error(e){saved.lastError={time:new Date().toISOString(),message:String(e.message||e)};persist()},diagnostics(d){saved.diagnostics=d;persist()}};
 async function request(url,options={},signal){
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),15000),stop=()=>controller.abort();
  if(signal?.aborted){clearTimeout(timer);throw abort()}signal?.addEventListener('abort',stop,{once:true});
  try{const r=await fetch(url,{...options,cache:'no-store',signal:controller.signal});if(!r.ok){const e=Error(await r.text());e.status=r.status;throw e}const body=new Uint8Array(await r.arrayBuffer());return {body,headers:r.headers}}finally{clearTimeout(timer);signal?.removeEventListener('abort',stop)}
 }
 async function retry(fn,signal,onprogress){
  let error;for(let n=0;n<5;n++){if(signal?.aborted)throw abort();try{return await fn()}catch(e){if(signal?.aborted)throw abort();error=e;Ti60Task.error(e);if(e.status&&e.status<500&&e.status!==423)throw e;if(n<4){onprogress?.('连接暂时中断，保留已读数据，正在重连 '+(n+1)+'/4',null);await wait(Math.min(4000,500*2**n),signal)}}}throw error;
 }
 const json=async(url,options,signal,onprogress)=>JSON.parse(new TextDecoder().decode((await retry(()=>request(url,options,signal),signal,onprogress)).body));
 const partial=new Map();let active=null;
 const isRaw=b=>b.length>=16&&b[0]===74&&b[1]===80&&b[2]===73&&b[3]===67&&b[4]===1&&b[5]===3;
 function validJpegBoundary(bytes){
  // FPGA DDR writer pads the completed JPEG with 1..16 FF bytes to a 128-bit beat.
  let end=bytes.length;while(end>2&&bytes[end-1]===255&&bytes.length-end<16)end--;
  return bytes.length>=4&&bytes[0]===255&&bytes[1]===216&&bytes[end-2]===255&&bytes[end-1]===217;
 }
 function validateRaw(bytes,expected){
  if(!isRaw(bytes))throw Error('原始像素响应格式错误');
  const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),w=v.getUint16(6,true),h=v.getUint16(8,true),n=v.getUint32(10,true);
  if(!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224))||n!==w*h*2||bytes.length!==n+16||(expected?.width&&(w!==expected.width||h!==expected.height)))throw Error('原始像素尺寸或长度不一致，未发布图像');
 }
 async function directRead(u,task,signal,onprogress,rate=10,timeoutMs=180000){
  const q=new URLSearchParams(u.searchParams),source=q.get('source')||'camera';
  q.set('format',q.get('format')==='rgb565'?'rgb565':'jpeg');q.set('crc','1');q.set('spi_mhz',String(rate));q.set('request',token());q.delete('boot');
  if(source==='result'||source==='frame_original'){
   if(!task.job_id||!task.cookie)throw Error('缺少模型任务身份，已停止读取');
   q.set('job',String(task.job_id));q.set('cookie',String(task.cookie));q.set('keep','1');
  }
  const ctrl=new AbortController(),stop=()=>ctrl.abort(),timer=setTimeout(()=>ctrl.abort(),u.pathname==='/api/preview/frame'?18000:timeoutMs);
  signal.addEventListener('abort',stop,{once:true});if(signal.aborted)ctrl.abort();
  let reader;
  try{
   onprogress?.('正在准备快速回传',null);
   const res=await fetch((u.pathname==='/api/preview/frame'?u.pathname:'/capture')+'?'+q,{cache:'no-store',signal:ctrl.signal});
   if(!res.ok){const e=Error(await res.text());e.status=res.status;throw e}
   const format=Number(res.headers.get('X-Frame-Format')),payload=Number(res.headers.get('X-Payload-Bytes')),total=Number(res.headers.get('Content-Length'));
   if(res.headers.get('X-Ti60-Stream')!=='6.0'||res.headers.get('X-Frame-CRC')!=='trailer')throw Error('当前固件不支持连续校验回传，转为缓存方式');
   if((source==='result'||source==='frame_original')&&(Number(res.headers.get('X-Frame-Job'))!==task.job_id||Number(res.headers.get('X-Frame-Cookie'))!==task.cookie)){
    const e=Error('板卡任务身份已更换，停止读取旧结果');e.status=409;throw e;
   }
   if(![2,3].includes(format)||!Number.isSafeInteger(payload)||payload<2||payload>4147200||total!==payload+(format===3?16:0)+4)throw Error('回传长度或格式无效');
   const bodyStarted=performance.now();const data=new Uint8Array(total);let received=0;reader=res.body.getReader();
   for(;;){const {done,value}=await reader.read();if(done)break;if(received+value.length>total)throw Error('回传长度超过声明值');data.set(value,received);received+=value.length;onprogress?.('快速回传 '+received+'/'+total+' 字节',Math.min(99,received/total*100))}
   if(received!==total)throw Error('回传未完成，结果尚未发布');
   const crc=new DataView(data.buffer).getUint32(total-4,true),end=total-4;
   if(crc32(data.subarray(format===3?16:0,end))!==crc)throw Error('整张图像 CRC 不一致，结果尚未发布');
   const bytes=data.subarray(0,end);
   if(format===3)validateRaw(bytes,task);else if(!validJpegBoundary(bytes))throw Error('JPEG 边界不完整');
   window.Ti60LastTransfer={source,format,payload,spiMHz:rate,freezeMs:Number(res.headers.get('X-Freeze-Ms'))||0,encodeMs:Number(res.headers.get('X-Encode-Ms'))||0,prepareMs:Number(res.headers.get('X-Prepare-Ms'))||0,bodyMs:performance.now()-bodyStarted};onprogress?.('图像完整校验通过',100);return bytes;
  }finally{ctrl.abort();clearTimeout(timer);signal.removeEventListener('abort',stop);if(reader)try{await reader.cancel()}catch{}}
 }
 function rawPacket(data,state){
  if(state.format!==3)return data;
  if(!((state.width===1024&&state.height===600)||(state.width===1920&&state.height===1080)||(state.width===256&&state.height===224))||data.length!==state.width*state.height*2)throw Error('原始像素长度或尺寸不一致，未发布图像');
  const out=new Uint8Array(data.length+16),v=new DataView(out.buffer);out.set([74,80,73,67,1,3]);v.setUint16(6,state.width,true);v.setUint16(8,state.height,true);v.setUint32(10,data.length,true);out.set(data,16);return out;
 }
 async function drawRaw(bytes,canvas,expected){
  const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),w=v.getUint16(6,true),h=v.getUint16(8,true),n=v.getUint32(10,true);
  if(!isRaw(bytes)||!((w===1024&&h===600)||(w===1920&&h===1080)||(w===256&&h===224))||n!==w*h*2||bytes.length!==n+16||(expected&&(w!==expected.width||h!==expected.height)))throw Error('原始像素不完整或任务尺寸不一致');
  const ctx=canvas.getContext('2d'),im=ctx.createImageData(w,h),d=im.data;
  for(let p=0,o=16;p<d.length;p+=4,o+=2){const rgb=bytes[o]|bytes[o+1]<<8;d[p]=Math.round((rgb>>>11)*255/31);d[p+1]=Math.round(((rgb>>>5)&63)*255/63);d[p+2]=Math.round((rgb&31)*255/31);d[p+3]=255;}
  canvas.width=w;canvas.height=h;ctx.putImageData(im,0,0);canvas.fpgaPixels=im;canvas.dataset.transport='rgb565';
  // Display retains exact decoded pixels. JPEG compression is for download
  // only; it is never fed back to the model or used to mask a bad return.
  canvas.jpegBlob=await new Promise((ok,no)=>canvas.toBlob(b=>b?ok(b):no(Error('保存JPEG失败')),'image/jpeg',.92));
 }
 async function read(url,options={}){
  const u=new URL(url,location.href),source=u.searchParams.get('source')||'camera',task=options.task||{},onprogress=options.onprogress;
  const own=new AbortController();active=own;const stop=()=>own.abort();options.signal?.addEventListener('abort',stop,{once:true});if(options.signal?.aborted)own.abort();const signal=own.signal;
  try{
   const recoveryKey=source+':'+(task.job_id||token())+':'+(task.cookie||0),strategy=options.strategy||mode;
   if(strategy!=='cache'&&(strategy==='direct'||saved.transferRecovery?.key!==recoveryKey)){
    try{
     const rates=[5,10,20].includes(options.spiMHz)?[options.spiMHz]:(source==='result'||source==='frame_original')?[20,10,5]:[10];
     for(let i=0;i<rates.length;i++){
      try{return await directRead(u,task,signal,onprogress,rates[i],Math.max(1000,Math.min(180000,options.timeoutMs||180000)));}catch(e){
       if(signal.aborted||e.status&&e.status<500&&e.status!==423&&e.status!==408||i===rates.length-1)throw e;
       Ti60Task.error(e);onprogress?.('回传校验未通过，保留任务并降至 '+rates[i+1]+' MHz 重读',null);await wait(80,signal);
      }
     }
    }catch(e){
     if(signal.aborted)throw abort();Ti60Task.error(e);
     if(strategy==='direct'||(e.status&&e.status<500&&e.status!==423&&e.status!==408))throw e;
     saved.transferRecovery={key:recoveryKey,time:Date.now()};persist();
     onprogress?.(source==='camera'?'快速回传中断，将重新抓拍并使用缓存回传':'快速回传中断，任务保留，切换缓存续传',null);
     await wait(500,signal);
    }
   }
   let state;
   for(const rate of [10,5,5]){
    const q=new URLSearchParams(u.searchParams);q.set('source',source);q.set('request',token());q.set('spi_mhz',rate);q.set('format','jpeg');
    q.set('job',String(task.job_id||0));q.set('cookie',String(task.cookie||0));
    onprogress?.('正在准备并校验图像',null);
    state=await json('/api/result/prepare?'+q,{method:'POST'},signal,onprogress);
    const began=Date.now();
    for(;;){
     const same=state.job_id===(task.job_id||0)&&state.cookie===(task.cookie||0)&&state.source===({result:1,frame_original:2,camera:3,upload:4}[source]);
     if(!same || ((source==='camera'||source==='upload')&&state.request!==q.get('request')))throw Error('缓存任务已更换，已停止读取');
     if(state.phase===3||state.phase===4||state.phase===5)break;
     if(Date.now()-began>180000)throw Error('图像准备超时；任务仍保留，可继续读取');
     onprogress?.(state.phase===1?'FPGA 正在准备图像':'ESP32 正在校验并缓存 '+state.received_bytes+'/'+state.expected_bytes+' 字节',null);
     await wait(500,signal);state=await json('/api/result/status',{},signal,onprogress);
    }
    if(state.phase===3)break;
    if(state.phase===5){
     // Preserve large-image support when the cache partition cannot hold it.
     onprogress?.(state.reason==='cache_unmounted'?'缓存未挂载，使用直传；任务保留':'当前图像超过缓存空间，使用直传；任务保留',null);
     return await directRead(u,task,signal,onprogress,5);
    }
    if(!['crc_mismatch','prepare_failed','spi_timeout'].includes(state.reason))throw Error('图像缓存失败：'+state.reason);
    onprogress?.('SPI 校验/准备未完成，降低速率重新读取',null);
   }
   if(state.phase!==3)throw Error('图像读取三次未通过：'+state.reason+'；模型任务仍保留');
   let p=partial.get(state.cache_id);if(!p){partial.clear();p={bytes:new Uint8Array(state.bytes),offset:0,cookie:state.cookie};partial.set(state.cache_id,p)}
   if(p.bytes.length!==state.bytes||p.cookie!==state.cookie)throw Error('缓存元数据不一致');
   while(p.offset<p.bytes.length){
    const offset=p.offset;
    const r=await retry(async()=>{
     const v=await request('/api/result/chunk?id='+state.cache_id+'&offset='+offset,{},signal);
     if(Number(v.headers.get('X-Cache-Id'))!==state.cache_id||Number(v.headers.get('X-Chunk-Offset'))!==offset||v.body.length!==Math.min(16384,p.bytes.length-offset)||crc32(v.body)!==parseInt(v.headers.get('X-Chunk-CRC32'),16))throw Error('分块长度或 CRC 不一致，重新读取该块');
     return v;
    },signal,onprogress);
    p.bytes.set(r.body,offset);p.offset+=r.body.length;
    onprogress?.('已校验回传 '+p.offset+'/'+p.bytes.length+' 字节（可继续读取）',Math.min(99,p.offset/p.bytes.length*100));
   }
   if(crc32(p.bytes)!==state.crc32){partial.delete(state.cache_id);throw Error('整张图像 CRC 不一致，未发布结果')}
   onprogress?.('图像完整校验通过',100);return rawPacket(p.bytes,state);
  }catch(e){Ti60Task.error(e);throw e}finally{if(active===own)active=null;options.signal?.removeEventListener('abort',stop)}
 }
 window.Ti60Transfer={read,crc32,isRaw,drawRaw,rawPacket,get busy(){return active!==null},get mode(){return mode},setMode(value){mode=value==='cache'?'cache':'auto';delete saved.transferRecovery;persist();try{localStorage.setItem(modeKey,mode)}catch{}},abort(){active?.abort()},json};
})();
