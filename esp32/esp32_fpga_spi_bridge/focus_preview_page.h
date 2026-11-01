#pragma once
static const char FOCUS_PAGE[] PROGMEM=R"FOCUS(<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>Ti60 视频调焦</title><style id="ti60-page-transition">html[data-ti60-pending]{background:#f5f7f4!important}html[data-ti60-pending] body{visibility:hidden!important}html[data-ti60-pending]::after{content:'正在打开页面…';position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;background:#f5f7f4;color:#456d62;font:16px system-ui,sans-serif}</style><script>document.documentElement.setAttribute('data-ti60-pending','');window.Ti60PageReady=function(){clearTimeout(window.Ti60PageTimer);document.documentElement.removeAttribute('data-ti60-pending')};window.Ti60PageTimer=setTimeout(window.Ti60PageReady,12000);window.addEventListener('pageshow',function(e){if(e.persisted)window.Ti60PageReady()});</script><link rel="stylesheet" href="/ui.css?v=0fd28c6dd621cc7a"><style>.focus-view{width:100%;aspect-ratio:512/300;object-fit:contain;background:#e8eeea;border-radius:12px}.focus-actions{display:flex;gap:12px;flex-wrap:wrap}.focus-actions button{flex:1;min-height:48px}nav{overflow-x:auto;white-space:nowrap}.focus-info{color:#64716b;line-height:1.7}</style><script src="/transport-v4.js?v=2b4cbb0250fd55ab"></script><script defer src="/ui.js?v=79d1ef5971cfde1c"></script></head><body>
<h1>视频调焦</h1><nav><a href="/">拍照</a><a href="/local">本地图片</a><a href="/student">模型处理</a><a href="/portrait">人像</a></nav>
<main class="workspace"><aside><section class="panel"><h2>摄像头调焦</h2><p class="focus-info">512×300 实时取景与手动调焦。清晰度数值仅作同一场景参考。</p><p class="focus-info">请先保存结果。预览会释放板上旧图，退出后可使用其他模式。</p><div class="focus-actions"><button id="focusStart">开始预览</button><button id="focusStop" disabled>退出预览</button></div></section></aside><article><section class="panel"><h2>实时画面</h2><p id="status" role="status">尚未开始预览</p><img id="focusImage" class="focus-view" alt="等待摄像头预览"><p id="focusRate" class="focus-info">512 × 300 · JPEG</p></section></article></main>
<script>
document.addEventListener('DOMContentLoaded',()=>{
 const start=document.getElementById('focusStart'),stop=document.getElementById('focusStop'),status=document.getElementById('status'),image=document.getElementById('focusImage'),rate=document.getElementById('focusRate');
 let lease=sessionStorage.getItem('ti60.focus.lease')||Ti60Task.token();sessionStorage.setItem('ti60.focus.lease',lease);
 const frameWidth=512,frameHeight=300;
 let engaged=false,running=false,framePromise=null,blobUrl='',lastFrame=0,count=0,stopping=null,failures=0,totalFailures=0,spiMHz=10,rateErrors=0,recoveries=0,goodStreak=0,intervals=[];
 const url=p=>p+'?lease='+encodeURIComponent(lease);
 function buttons(){start.disabled=engaged||!!window.TI60_OFFLINE;stop.disabled=!engaged||!!stopping;const transfer=document.getElementById('transferMode');if(transfer)transfer.disabled=engaged;if(engaged&&document.getElementById('deviceTask'))document.getElementById('deviceTask').textContent='调焦预览占用 · 退出后可处理图像';}
 async function frames(){
  let pending=null;const read=()=>Ti60Transfer.read(url('/api/preview/frame')+'&source=camera&format=jpeg&mode=0&alg=0',{strategy:'direct',spiMHz,onprogress:()=>{}}).then(data=>({data,transfer:window.Ti60LastTransfer}),error=>({error}));
  const meter=document.createElement('canvas');meter.width=128;meter.height=75;let focus=0;
  try{while(running){
   try{
    const began=performance.now();
    const packet=await(pending||read());pending=null;if(packet.error)throw packet.error;const data=packet.data,transfer=packet.transfer;
    // At most one next frame overlaps decoding/presentation. Every image still
    // passes the same CRC checks; exit aborts and drains the pending read.
    if(running)pending=read();
    if(!running)break;
    const next=URL.createObjectURL(new Blob([data],{type:'image/jpeg'})),probe=new Image();probe.src=next;
    try{await probe.decode();if(probe.naturalWidth!==frameWidth||probe.naturalHeight!==frameHeight)throw Error('预览尺寸不一致');}catch(e){URL.revokeObjectURL(next);throw e;}
    if(!running){URL.revokeObjectURL(next);break;}
    if(count%8===0&&window.Ti60FocusScore){const c=meter.getContext('2d');c.drawImage(probe,0,0,128,75);focus=Ti60FocusScore(c.getImageData(0,0,128,75).data,128,75);}
    const now=performance.now();image.src=next;if(blobUrl)URL.revokeObjectURL(blobUrl);blobUrl=next;count++;failures=0;goodStreak++;if(lastFrame){intervals.push(now-lastFrame);if(intervals.length>8)intervals.shift();}const meanInterval=intervals.length?intervals.reduce((a,b)=>a+b,0)/intervals.length:now-began;
    rate.textContent=frameWidth+' × '+frameHeight+' · 已更新 '+count+' 帧 · '+(1000/meanInterval).toFixed(2)+' 帧/秒（近8帧平均）'+' · SPI '+spiMHz+' MHz'+' · 准备 '+Math.round(transfer?.prepareMs||0)+' ms / 回传 '+Math.round(transfer?.bodyMs||0)+' ms'+' · 等帧 '+Math.round(transfer?.freezeMs||0)+' ms / 编码 '+Math.round(transfer?.encodeMs||0)+' ms · 相对清晰度 '+focus.toFixed(1);lastFrame=now;
    status.textContent='预览中，请调整镜头焦距';
    window.Ti60Preview={engaged,running,frames:count,failures:totalFailures,spiMHz,meanIntervalMs:meanInterval,lastIntervalMs:intervals.at(-1)||meanInterval,focusScore:focus,transfer};
    if(spiMHz===5&&goodStreak>=48&&recoveries===0){spiMHz=10;goodStreak=0;rateErrors=0;recoveries++;}
    // Preview keeps a conservative 10 MHz ceiling; repeated errors prefer 5 MHz.
    if(spiMHz===10&&goodStreak>=48)rateErrors=0;
    await new Promise(r=>setTimeout(r,0));
   }catch(e){
    if(!running)break;
    goodStreak=0;failures++;totalFailures++;rateErrors++;if(spiMHz===10&&(rateErrors>=2||recoveries>0))spiMHz=5;
    window.Ti60Preview={engaged,running,frames:count,failures:totalFailures,spiMHz,lastError:e.message};
    if(e.status===409||e.status===423||failures>=6){running=false;status.textContent='预览暂停：'+e.message+'；请退出预览后重试';break;}
    status.textContent='预览中，请调整镜头焦距';
    await new Promise(r=>setTimeout(r,Math.min(300,20*failures*failures)));
   }
  }}finally{if(pending){Ti60Transfer.abort();await pending;}meter.width=meter.height=0;}
  buttons();
 }
 async function exit(){
  if(stopping)return stopping;if(!engaged)return;
  running=false;Ti60Transfer.abort();
  stopping=(async()=>{if(framePromise)await framePromise;status.textContent='正在退出预览并恢复摄像头…';const s=await Ti60Transfer.json(url('/api/preview/stop'),{method:'POST'});if(s.active||s.restore_failed)throw Error('摄像头恢复未确认');engaged=false;window.Ti60Preview={engaged:false,running:false};status.textContent='预览已退出，可使用拍照、模型和上传';})();buttons();
  try{await stopping;}catch(e){status.textContent='退出未确认：'+e.message+'；请重试退出';throw e;}finally{stopping=null;buttons();}
 }
 start.onclick=async()=>{engaged=true;window.Ti60Preview={engaged:true,running:false};buttons();status.textContent='正在申请独占预览…';try{const s=await Ti60Transfer.json(url('/api/preview/start'),{method:'POST'});if(!s.active||!s.owned)throw Error('未获得预览会话');if(s.width!==512||s.height!==300)throw Error("预览尺寸不一致");running=true;count=0;lastFrame=0;failures=0;totalFailures=0;spiMHz=10;rateErrors=0;recoveries=0;goodStreak=0;intervals=[];framePromise=frames();}catch(e){status.textContent='启动未确认：'+e.message+'；请点击退出预览释放会话';}buttons();};
 stop.onclick=()=>exit().catch(()=>{});
 document.querySelectorAll('nav a').forEach(a=>{a.addEventListener('click',async e=>{if(!engaged)return;e.preventDefault();try{await exit();location.href=a.href;}catch(e){status.textContent='退出预览失败：'+e.message;window.Ti60PageReady?.();}})});
 window.addEventListener('pagehide',()=>{running=false;Ti60Transfer.abort();if(engaged)navigator.sendBeacon(url('/api/preview/stop'),'');if(blobUrl)URL.revokeObjectURL(blobUrl);});
 document.addEventListener('visibilitychange',()=>{if(document.hidden&&engaged)exit().catch(()=>{});});
 buttons();if(window.TI60_OFFLINE){status.textContent='电脑界面预览，连接设备后可开始调焦';return;}
 Ti60Transfer.json(url('/api/preview/status'),{}).then(s=>{if(s.active&&s.owned){engaged=true;status.textContent='已找到本页面保留的预览会话，请先退出再开始';buttons();}}).catch(()=>{});
});
</script></body></html>
)FOCUS";
