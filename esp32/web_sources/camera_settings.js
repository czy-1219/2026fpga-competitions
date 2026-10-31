(()=>{
 function focusScore(data,w,h){
  const gray=i=>(77*data[i*4]+150*data[i*4+1]+29*data[i*4+2])/256;
  let total=0,n=0;
  for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++){const i=y*w+x;total+=Math.abs(4*gray(i)-gray(i-1)-gray(i+1)-gray(i-w)-gray(i+w));n++;}
  return n?total/n:0;
 }
 if(typeof module!=='undefined')module.exports={focusScore};
 if(typeof window==='undefined')return;window.Ti60FocusScore=focusScore;
 document.addEventListener('DOMContentLoaded',()=>{
  if(!['/','/focus','/student'].includes(location.pathname))return;
  const panel=document.createElement('details');panel.className='camera-settings';
  panel.innerHTML='<summary>摄像头设置</summary><label>画面曝光 <select id="cameraExposure"><option value="0">标准（原设置）</option><option value="1">减亮</option><option value="2">明显减亮</option><option value="3">提亮</option><option value="4">明显提亮</option></select></label><label>增益上限 <select id="cameraGain"><option value="0">平衡 · 7.5×</option><option value="1">低噪 · 4×</option><option value="2">暗场 · 15.5×</option></select></label><label>白平衡 <select id="cameraWhite"><option value="0">自动（原设置）</option><option value="1">日光预设</option><option value="2">室内预设</option></select></label><button id="applyCameraProfile" disabled>应用采集参数</button><p class="note">调整拍摄明暗与偏色。请先保存结果并退出预览；应用会释放旧任务。</p><p id="cameraProfileStatus" class="note">正在读取采集参数…</p>';
  const target=document.querySelector('.workspace aside section');if(!target)return;target.append(panel);
  const by=id=>panel.querySelector('#'+id),button=by('applyCameraProfile'),note=by('cameraProfileStatus');
  const show=s=>{by('cameraExposure').value=s.profile&7;by('cameraGain').value=(s.profile>>3)&3;by('cameraWhite').value=(s.profile>>5)&3;button.disabled=!s.supported||!!window.TI60_OFFLINE;};
  if(window.TI60_OFFLINE){note.textContent='连接设备后可调整摄像头';return;}
  Ti60Transfer.json('/api/camera/profile',{}).then(s=>{show(s);note.textContent=s.supported?'已读取；应用后由设备确认配置和新帧。':'当前设备不支持采集设置';}).catch(()=>{note.textContent='采集设置暂不可用，可刷新页面重试。';});
  button.onclick=async()=>{
   if(window.Ti60Preview?.engaged){note.textContent='请先退出预览，再修改采集参数。';return;}
   const value=Number(by('cameraExposure').value)|(Number(by('cameraGain').value)<<3)|(Number(by('cameraWhite').value)<<5);
   button.disabled=true;note.textContent='正在配置摄像头并等待新帧…';
   try{const s=await Ti60Transfer.json('/api/camera/profile?value='+value,{method:'POST'});if(s.profile!==value)throw Error('参数读回不一致');show(s);note.textContent='参数与新帧已确认；可重新预览或抓拍。';}
   catch(e){note.textContent=e.message;}finally{button.disabled=false;}
  };
 });
})();
