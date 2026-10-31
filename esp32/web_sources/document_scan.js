/* Optional, local document finishing. The FPGA JPEG and model are untouched. */
(()=>{
 function clean(rgba,w,h,options={}){
  if(!Number.isInteger(w)||!Number.isInteger(h)||w<1||h<1||rgba.length!==w*h*4)throw Error('文字图像尺寸错误');
  const n=w*h,labels=new Int32Array(n),queue=new Int32Array(n),sizes=[0];
  const black=i=>(77*rgba[4*i]+150*rgba[4*i+1]+29*rgba[4*i+2])<128*256;
  for(let start=0;start<n;start++)if(!labels[start]&&black(start)){
   const id=sizes.length;let head=0,tail=1;queue[0]=start;labels[start]=id;
   while(head<tail){const i=queue[head++],x=i%w,y=(i/w)|0;
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const xx=x+dx,yy=y+dy;if(xx<0||xx>=w||yy<0||yy>=h)continue;const j=yy*w+xx;if(!labels[j]&&black(j)){labels[j]=id;queue[tail++]=j;}}
   }sizes.push(tail);
  }
  // Keep real strokes and small punctuation next to text. Only isolated islands
  // are removed; no erosion/opening of all characters, no filling letter holes.
  const scale=Math.max(1,w*h/(1024*600)),limit=Math.round((options.strong?10:4)*scale),radius=Math.round((options.strong?5:9)*Math.sqrt(scale));
  const keep=Uint8Array.from(sizes,s=>s>limit?1:0);
  // Fixed anchor map: deleted islands must never become each other's text anchors.
  for(let i=0;i<n;i++)if(labels[i]&&!keep[labels[i]]){
   const x=i%w,y=(i/w)|0;let found=false;
   for(let yy=Math.max(0,y-radius);yy<=Math.min(h-1,y+radius)&&!found;yy++)for(let xx=Math.max(0,x-radius);xx<=Math.min(w-1,x+radius);xx++)if(sizes[labels[yy*w+xx]]>limit){found=true;break;}
   if(found)keep[labels[i]]=1;
  }
  for(let i=0;i<n;i++)if(labels[i]&&!keep[labels[i]])rgba[4*i]=rgba[4*i+1]=rgba[4*i+2]=255;
  return rgba;
 }
 function scan(rgba,w,h,options={}){
  if(!Number.isInteger(w)||!Number.isInteger(h)||w<1||h<1||rgba.length!==w*h*4)throw Error('扫描图像尺寸错误');
  const n=w*h,gray=new Uint8Array(n),cell=32,cols=Math.ceil(w/cell),rows=Math.ceil(h/cell);
  const paper=new Float32Array(cols*rows),hist=new Uint32Array(256);
  for(let i=0;i<n;i++)gray[i]=(77*rgba[4*i]+150*rgba[4*i+1]+29*rgba[4*i+2]+128)>>8;
  // Local bright quantile follows the paper under uneven illumination. Unlike
  // one global threshold, a shaded region does not become a solid black block.
  for(let ty=0;ty<rows;ty++)for(let tx=0;tx<cols;tx++){
   hist.fill(0);let count=0;
   for(let y=ty*cell;y<Math.min(h,(ty+1)*cell);y++)for(let x=tx*cell;x<Math.min(w,(tx+1)*cell);x++){hist[gray[y*w+x]]++;count++;}
   let total=0,bg=0;for(;bg<255;bg++){total+=hist[bg];if(total>=count*.85)break;}
   paper[ty*cols+tx]=Math.max(16,bg);
  }
  const strength=Math.max(.06,Math.min(.18,options.strength??.10));
  for(let y=0;y<h;y++){
   const gy=Math.max(0,Math.min(rows-1,(y+.5)/cell-.5)),y0=Math.floor(gy),y1=Math.min(rows-1,y0+1),fy=gy-y0;
   for(let x=0;x<w;x++){
    const gx=Math.max(0,Math.min(cols-1,(x+.5)/cell-.5)),x0=Math.floor(gx),x1=Math.min(cols-1,x0+1),fx=gx-x0;
    const top=paper[y0*cols+x0]*(1-fx)+paper[y0*cols+x1]*fx,bottom=paper[y1*cols+x0]*(1-fx)+paper[y1*cols+x1]*fx;
    const bg=top*(1-fy)+bottom*fy,i=y*w+x;
    const value=gray[i]<bg-Math.max(8,bg*strength)?0:255;
    rgba[4*i]=rgba[4*i+1]=rgba[4*i+2]=value;rgba[4*i+3]=255;
   }
  }
  if(options.denoise!==false)clean(rgba,w,h,{strong:options.strong});
  return rgba;
 }
 function reset(canvas){
  canvas.dataset.complete='';canvas.dataset.recovery='';canvas.jpegBlob=null;canvas.fpgaPixels=null;canvas.cleanedBlob=null;canvas.correctedBlob=null;canvas.scanInputBlob=null;canvas.scanBaseBlob=null;canvas.colorBaseBlob=null;
  canvas.taskEpoch=(canvas.taskEpoch||0)+1;
  canvas.getContext('2d').clearRect(0,0,canvas.width,canvas.height);
  canvas.dispatchEvent(new Event('ti60-result'));
 }
 async function finishCanvas(canvas){
  const epoch=canvas.taskEpoch||0,original=canvas.scanInputBlob||canvas.scanBaseBlob||canvas.jpegBlob;
  if(!original)throw Error('扫描原图未准备完成');
  const strength=Number(document.getElementById('documentStrength')?.value||.10);
  const im=await createImageBitmap(original),tmp=document.createElement('canvas');tmp.width=im.width;tmp.height=im.height;
  const ctx=tmp.getContext('2d');ctx.drawImage(im,0,0);im.close();
  const d=ctx.getImageData(0,0,tmp.width,tmp.height);scan(d.data,tmp.width,tmp.height,{strength,denoise:strength!==.06,strong:strength>.10});ctx.putImageData(d,0,0);
  const blob=await new Promise(ok=>tmp.toBlob(ok,'image/png'));if(!blob)throw Error('扫描件 PNG 编码失败');
  if((canvas.taskEpoch||0)!==epoch)throw Error('图像已更换，已丢弃旧扫描结果');
  canvas.width=tmp.width;canvas.height=tmp.height;canvas.getContext('2d').drawImage(tmp,0,0);canvas.cleanedBlob=blob;canvas.scanBaseBlob=original;
  canvas.dispatchEvent(new Event('ti60-result'));return true;
 }
 // Monochrome output must not contain saturated chroma. This catches a valid
 // transport CRC with a damaged JPEG chroma/DC stream; it does not repair it.
 function assertNeutral(canvas){
  const d=canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data;let bad=0,total=0;
  for(let i=0;i<d.length;i+=16){total++;const spread=Math.max(d[i],d[i+1],d[i+2])-Math.min(d[i],d[i+1],d[i+2]);if(spread>36)bad++;}
  if(bad>Math.max(12,total*.01)){const e=Error('灰阶图出现异常彩色，请保留诊断并重试');e.code='JPEG_CONTENT';throw e;}
 }
 const api={scan,clean,finishCanvas,reset,assertNeutral};if(typeof module!=='undefined'&&module.exports)module.exports=api;
 if(typeof window!=='undefined'){
  window.Ti60Document=api;
  document.addEventListener('DOMContentLoaded',()=>{
   const source=document.getElementById('view')||document.getElementById('processed');if(!source)return;
   const settings=document.querySelector('.workspace aside>section:nth-child(2)'),panel=document.createElement('div');panel.className='scan-options';
   panel.innerHTML='<label>扫描文档 <select id="documentStrength"><option value="0.10">标准去阴影</option><option value="0.06">保留浅字与标点</option><option value="0.14">加强去噪</option></select></label><p class="note">去阴影、转黑白，保存为 PNG。浅字较多时选“保留浅字与标点”。</p><p id="documentNote" class="note" role="status"></p>';
   settings.append(panel);
   const fpgaSave=document.createElement('button');fpgaSave.id='saveScanFpga';fpgaSave.textContent='下载 FPGA 原始 JPEG';fpgaSave.disabled=true;
   document.querySelector('.phone-downloads .toolbar').append(fpgaSave);
   fpgaSave.onclick=()=>{if(!source.dataset.complete||!source.jpegBlob)return;const u=URL.createObjectURL(source.jpegBlob),a=document.createElement('a');a.href=u;a.download='ti60_fpga_'+Date.now()+'.jpg';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);};
   const note=panel.querySelector('#documentNote'),save=document.getElementById('download');
   new MutationObserver(()=>{fpgaSave.disabled=!source.dataset.complete||!source.jpegBlob;save.textContent=source.correctedBlob?'下载当前结果':source.scanBaseBlob?'下载扫描件 PNG':source.cleanedBlob?'下载增强图片 PNG':'下载当前结果';}).observe(source,{attributes:true,attributeFilter:['data-complete']});
   panel.querySelector('select').onchange=async()=>{
    if(!source.dataset.complete||!source.scanBaseBlob)return;
    const epoch=source.taskEpoch;save.disabled=true;
    try{await finishCanvas(source);note.textContent='扫描件已更新';}catch(e){note.textContent=e.message;}finally{if(epoch===source.taskEpoch)save.disabled=!source.dataset.complete;}
   };
  });
 }
})();
