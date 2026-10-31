/* Optional screen chroma finishing. Bounded O(width*height) sliding windows;
 * FPGA JPEG and model math remain available unchanged for comparison/export. */
(()=>{
 const clamp=v=>Math.max(0,Math.min(255,Math.round(v)));
 function box(src,w,h,r,tmp,out){
  const d=2*r+1;
  for(let y=0;y<h;y++){
   const row=y*w;let sum=0;
   for(let k=-r;k<=r;k++)sum+=src[row+Math.max(0,Math.min(w-1,k))];
   for(let x=0;x<w;x++){tmp[row+x]=sum/d;sum+=src[row+Math.min(w-1,x+r+1)]-src[row+Math.max(0,x-r)];}
  }
  for(let x=0;x<w;x++){
   let sum=0;for(let k=-r;k<=r;k++)sum+=tmp[Math.max(0,Math.min(h-1,k))*w+x];
   for(let y=0;y<h;y++){out[y*w+x]=sum/d;sum+=tmp[Math.min(h-1,y+r+1)*w+x]-tmp[Math.max(0,y-r)*w+x];}
  }
 }
 function chroma(data,w,h,strength='medium',scale='medium'){
  if(data.length!==w*h*4||w<1||h<1)throw Error('图像尺寸错误');
  const amount={off:0,auto:.8,weak:.35,medium:.65,strong:.9}[strength];if(amount===undefined)throw Error('彩纹强度无效');if(!amount)return data;
  const radius={fine:3,medium:9,wide:25}[scale];if(!radius)throw Error('彩纹尺度无效');
  const r=Math.max(1,Math.round(radius*Math.max(w,h)/1024)),n=w*h;
  const y=new Float32Array(n),plane=new Float32Array(n),tmp=new Float32Array(n),blur=new Float32Array(n);
  // Keep luminance fixed: smoothing chroma should not blur black text strokes.
  for(let i=0;i<n;i++)y[i]=(77*data[i*4]+150*data[i*4+1]+29*data[i*4+2])/256;
  for(const channel of [0,2]){
   for(let i=0;i<n;i++)plane[i]=data[i*4+channel]-y[i];
   box(plane,w,h,r,tmp,blur);
   for(let j=0;j<h;j++)for(let x=0;x<w;x++){
    const i=j*w+x,edge=Math.abs(y[j*w+Math.max(0,x-1)]-y[j*w+Math.min(w-1,x+1)])+Math.abs(y[Math.max(0,j-1)*w+x]-y[Math.min(h-1,j+1)*w+x]);
    const ce=Math.abs(plane[j*w+Math.max(0,x-1)]-plane[j*w+Math.min(w-1,x+1)])+Math.abs(plane[Math.max(0,j-1)*w+x]-plane[Math.min(h-1,j+1)*w+x]);
    // Automatic strength protects sharp chroma boundaries such as colored
    // annotations. Manual levels retain the V7.6 transform for comparison.
    const adaptive=strength==='auto'?Math.min(1,Math.abs(blur[i]-plane[i])/10)*(ce>100?.1:ce>60?.45:1):1;
    const blend=amount*(edge>48?.15:edge>24?.4:1)*adaptive;
    data[i*4+channel]=clamp(y[i]+plane[i]+blend*(blur[i]-plane[i]));
   }
  }
  for(let i=0;i<n;i++)data[i*4+1]=clamp((256*y[i]-77*data[i*4]-29*data[i*4+2])/150);
  return data;
 }
 function courseware(data,w,h,scan=false){
  const n=w*h,y=new Float32Array(n),tmp=new Float32Array(n),local=new Float32Array(n),wide=new Float32Array(n);
  for(let i=0;i<n;i++)y[i]=(77*data[4*i]+150*data[4*i+1]+29*data[4*i+2])/256;
  box(y,w,h,Math.max(8,Math.round(Math.max(w,h)/32)),tmp,wide);
  box(y,w,h,1,tmp,local);
  for(let i=0;i<n;i++){
   // Bounded common gain protects colored slide backgrounds and black strokes.
   const gain=y[i]>32?1+Math.min(scan?.22:.12,Math.max(0,((scan?220:200)-wide[i])/(scan?400:500))):1;
   const detail=Math.max(-4,Math.min(4,(y[i]-local[i])*(scan?.3:.2)));
   for(let c=0;c<3;c++)data[4*i+c]=clamp(data[4*i+c]*gain+detail);
  }return data;
 }
 async function finishCourseware(canvas){
  const epoch=canvas.taskEpoch,ctx=canvas.getContext('2d'),d=ctx.getImageData(0,0,canvas.width,canvas.height);
  courseware(d.data,canvas.width,canvas.height,!!document.querySelector('.alg[value="4"]:checked'));ctx.putImageData(d,0,0);
  const blob=await new Promise(ok=>canvas.toBlob(ok,'image/png'));
  if(epoch!==canvas.taskEpoch)throw Error('图像已更换，已丢弃旧增强结果');if(!blob)throw Error('增强图片保存失败');
  canvas.cleanedBlob=blob;return true;
 }
 async function finish(canvas,level,scale){
  level=level||document.getElementById('chromaStrength')?.value||'off';
  scale=scale||document.getElementById('chromaScale')?.value||'medium';
  if(level==='off'&&!canvas.colorBaseBlob)return false;
  const epoch=canvas.taskEpoch,base=canvas.colorBaseBlob||canvas.cleanedBlob||canvas.jpegBlob;
  if(!base)throw Error('尚无可处理的结果');
  const im=await createImageBitmap(base),tmp=document.createElement('canvas');tmp.width=im.width;tmp.height=im.height;
  try{
   const ctx=tmp.getContext('2d');ctx.drawImage(im,0,0);im.close();
   if(level!=='off'){const d=ctx.getImageData(0,0,tmp.width,tmp.height);chroma(d.data,tmp.width,tmp.height,level,scale);ctx.putImageData(d,0,0);}
   const blob=level==='off'?base:await new Promise(ok=>tmp.toBlob(ok,'image/png'));
   if(epoch!==canvas.taskEpoch)throw Error('图像已更换，已丢弃旧彩纹处理');if(!blob)throw Error('彩纹图片保存失败');
   canvas.width=tmp.width;canvas.height=tmp.height;canvas.getContext('2d').drawImage(tmp,0,0);
   canvas.colorBaseBlob=base;canvas.cleanedBlob=blob;canvas.dispatchEvent(new Event('ti60-result'));return true;
  }finally{tmp.width=tmp.height=0;}
 }
 const api={chroma,courseware,finish,finishCourseware};if(typeof module!=='undefined')module.exports=api;
 if(typeof window==='undefined')return;window.Ti60Screen=api;
 document.addEventListener('DOMContentLoaded',()=>{
  if(!document.getElementById('studentOutput'))return;
  const block=document.createElement('div');block.className='chroma-options';
  block.innerHTML='<label>彩纹抑制 <select id="chromaStrength"><option value="off">关闭 · 保留原效果</option><option value="auto">自适应 · 兼顾彩纹与标注</option><option value="weak">弱 · 保留颜色细节</option><option value="medium">中 · 平衡抑制</option><option value="strong">强 · 加强色纹平滑</option></select></label><label>彩纹尺度 <select id="chromaScale"><option value="fine">细密网纹</option><option value="medium" selected>中等波纹</option><option value="wide">宽彩纹</option></select></label><button id="applyChroma">应用到当前结果</button><p class="note">减轻彩色摩尔纹，强档可能减弱细小标注。点击应用仅调整当前结果；关闭可恢复。</p><p id="chromaStatus" class="note"></p>';
  document.getElementById('browserFinish').closest('details').append(block);
  document.getElementById('applyChroma').onclick=async()=>{
   if(processing||!complete)return;
   const note=document.getElementById('chromaStatus');if(document.getElementById('studentOutput').value!=='color'){note.textContent='彩纹抑制适用于彩色结果。';return;}
   processing=true;controls();note.textContent='正在抑制彩纹…';
   try{await new Promise(ok=>setTimeout(ok,0));await finish(result);showingFpga=false;resultDownloadName=resultDownloadName.replace(/\.(jpg|png)$/,result.cleanedBlob?.type==='image/png'?'.png':'.jpg');note.textContent='已更新；可滑动对比或下载。';}
   catch(e){note.textContent=e.message;}finally{processing=false;controls();}
  };
 });
})();
