/* Optional upload preparation; final dimensions still come from the existing
 * 1024x600/1920x1080 crop pipeline. No inference weights or outputs are changed. */
(()=>{
 const unit=()=>[[0,0],[1,0],[1,1],[0,1]];
 function matrix(q){
  if(q.length!==4||q.some(p=>p.length!==2||p.some(v=>!Number.isFinite(v)||v<0||v>1)))throw Error('四角坐标无效');
  for(let i=0;i<4;i++){
   const a=q[i],b=q[(i+1)%4],c=q[(i+2)%4];
   if((b[0]-a[0])*(c[1]-b[1])-(b[1]-a[1])*(c[0]-b[0])<.002)throw Error('请按左上、右上、右下、左下设置四角，避免交叉或过小区域');
  }
  const [[x0,y0],[x1,y1],[x2,y2],[x3,y3]]=q,dx1=x1-x2,dx2=x3-x2,dy1=y1-y2,dy2=y3-y2;
  const sx=x0-x1+x2-x3,sy=y0-y1+y2-y3,det=dx1*dy2-dx2*dy1;
  if(Math.abs(det)<1e-8)throw Error('校正区域退化');
  const g=(sx*dy2-dx2*sy)/det,h=(dx1*sy-sx*dy1)/det;
  return [x1-x0+g*x1,x3-x0+h*x3,x0,y1-y0+g*y1,y3-y0+h*y3,y0,g,h];
 }
 function warp(data,w,h,q,ow,oh,preserveAlpha=false){
  if(data.length!==w*h*4||ow<2||oh<2||ow*oh>(preserveAlpha?24000000:2073600))throw Error('校正尺寸超限');
  const m=matrix(q),out=new Uint8ClampedArray(ow*oh*4);
  for(let y=0;y<oh;y++)for(let x=0;x<ow;x++){
   const u=x/(ow-1),v=y/(oh-1),z=m[6]*u+m[7]*v+1;
   const sx=Math.max(0,Math.min(w-1,(m[0]*u+m[1]*v+m[2])/z*(w-1))),sy=Math.max(0,Math.min(h-1,(m[3]*u+m[4]*v+m[5])/z*(h-1)));
   const ix=Math.floor(sx),iy=Math.floor(sy),jx=Math.min(w-1,ix+1),jy=Math.min(h-1,iy+1),fx=sx-ix,fy=sy-iy,o=(y*ow+x)*4;
   for(let c=0;c<(preserveAlpha?4:3);c++)out[o+c]=(data[(iy*w+ix)*4+c]*(1-fx)+data[(iy*w+jx)*4+c]*fx)*(1-fy)+(data[(jy*w+ix)*4+c]*(1-fx)+data[(jy*w+jx)*4+c]*fx)*fy;
   if(!preserveAlpha)out[o+3]=255;
  }return out;
 }
 if(typeof module!=='undefined')module.exports={matrix,warp,unit};
 if(typeof window==='undefined')return;window.Ti60Geometry={matrix,warp,unit};
 document.addEventListener('DOMContentLoaded',()=>{
  const file=document.getElementById('file'),fold=document.querySelector('.upload-crop');
  if(!file||!fold||!['/local','/student'].includes(location.pathname))return;
  const box=document.createElement('details');box.className='document-geometry';
  box.innerHTML='<summary>文档四角校正与旋转</summary><p class="note">拖动四角框选课件或文档，拉正倾斜页面并去除周围干扰。应用后仍按所选输出尺寸处理；整页建议选择“完整保留”。</p><canvas id="geometryView" width="640" height="400" style="touch-action:none;width:100%"></canvas><div class="toolbar"><button id="geometryRotate">顺时针旋转</button><button id="geometryReset">重置四角</button><button id="geometryApply">应用取景校正</button><button id="geometryRestore">恢复最初选图</button></div><p id="geometryNote" class="note">选择图片后可使用。</p>';
  fold.append(box);const by=id=>box.querySelector('#'+id),view=by('geometryView'),note=by('geometryNote'),src=document.createElement('canvas');
  let points=unit(),frame=null,drag=-1,originalFile=null,ticket=0,applying=false,internalChange=false;
  const busy=()=>applying||(location.pathname==='/student'?processing:window.Ti60Transfer?.busy||document.getElementById('process')?.disabled&&!file.files.length)||file.disabled;
  function draw(){
   const ctx=view.getContext('2d');ctx.fillStyle='#e8eeea';ctx.fillRect(0,0,640,400);if(!frame)return;
   const k=Math.min(640/src.width,400/src.height),w=src.width*k,h=src.height*k,ox=(640-w)/2,oy=(400-h)/2;frame={w,h,ox,oy};ctx.drawImage(src,ox,oy,w,h);
   ctx.lineWidth=2;ctx.strokeStyle='#1c8050';ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(ox+x*w,oy+y*h):ctx.moveTo(ox+x*w,oy+y*h));ctx.closePath();ctx.stroke();
   points.forEach(([x,y],i)=>{ctx.fillStyle='white';ctx.beginPath();ctx.arc(ox+x*w,oy+y*h,9,0,7);ctx.fill();ctx.stroke();ctx.fillStyle='#163e2e';ctx.font='12px sans-serif';ctx.fillText(String(i+1),ox+x*w-3,oy+y*h+4);});
  }
  async function load(f){const id=++ticket;try{const im=await createImageBitmap(f);if(id!==ticket){im.close();return;}
   const scale=Math.min(1,1920/im.width,1080/im.height);src.width=Math.max(2,Math.round(im.width*scale));src.height=Math.max(2,Math.round(im.height*scale));src.getContext('2d').drawImage(im,0,0,src.width,src.height);im.close();points=unit();frame={};draw();note.textContent='四角顺序：左上 → 右上 → 右下 → 左下。';
  }catch(e){note.textContent=e.message;}}
  box.ontoggle=()=>{if(box.open&&!frame&&file.files[0]){originalFile=file.files[0];load(originalFile);}};
  file.addEventListener('change',()=>{if(internalChange){internalChange=false;return;}originalFile=file.files[0]||null;if(originalFile)load(originalFile);});
  const position=e=>{const r=view.getBoundingClientRect();return[(e.clientX-r.left)*640/r.width,(e.clientY-r.top)*400/r.height];};
  view.onpointerdown=e=>{if(busy()||!frame)return;const [x,y]=position(e);let distance=45;drag=-1;points.forEach(([px,py],i)=>{const d=Math.hypot(x-frame.ox-px*frame.w,y-frame.oy-py*frame.h);if(d<distance){distance=d;drag=i;}});if(drag>=0){view.setPointerCapture(e.pointerId);e.preventDefault();}};
  view.onpointermove=e=>{if(drag<0||busy())return;const [x,y]=position(e);points[drag]=[Math.max(0,Math.min(1,(x-frame.ox)/frame.w)),Math.max(0,Math.min(1,(y-frame.oy)/frame.h))];draw();};
  view.onpointerup=view.onpointercancel=()=>{drag=-1;};
  by('geometryReset').onclick=()=>{if(busy())return;points=unit();draw();};
  by('geometryRotate').onclick=()=>{if(busy()||!frame)return;const tmp=document.createElement('canvas');tmp.width=src.height;tmp.height=src.width;const c=tmp.getContext('2d');c.translate(tmp.width,0);c.rotate(Math.PI/2);c.drawImage(src,0,0);src.width=tmp.width;src.height=tmp.height;src.getContext('2d').drawImage(tmp,0,0);tmp.width=tmp.height=0;points=unit();draw();};
  function choose(f){internalChange=true;const dt=new DataTransfer();dt.items.add(f);file.files=dt.files;file.dispatchEvent(new Event('change',{bubbles:true}));}
  by('geometryRestore').onclick=()=>{if(busy()||!originalFile)return;choose(originalFile);load(originalFile);};
  by('geometryApply').onclick=async()=>{
   if(busy()||!frame||!originalFile)return;applying=true;by('geometryApply').disabled=true;note.textContent='正在拉正文档…';const id=ticket,tmp=document.createElement('canvas');
   try{
    await new Promise(r=>setTimeout(r,0));matrix(points);
    const distance=(a,b)=>Math.hypot((a[0]-b[0])*src.width,(a[1]-b[1])*src.height);
    const w=Math.max(2,Math.round(Math.max(distance(points[0],points[1]),distance(points[3],points[2])))),h=Math.max(2,Math.round(Math.max(distance(points[0],points[3]),distance(points[1],points[2]))));
    const scale=Math.min(1,1920/w,1080/h);tmp.width=Math.max(2,Math.round(w*scale));tmp.height=Math.max(2,Math.round(h*scale));
    const pixels=src.getContext('2d').getImageData(0,0,src.width,src.height),d=warp(pixels.data,src.width,src.height,points,tmp.width,tmp.height);tmp.getContext('2d').putImageData(new ImageData(d,tmp.width,tmp.height),0,0);
    const blob=await new Promise(r=>tmp.toBlob(r,'image/png'));if(id!==ticket)throw Error('选图已更换，未覆盖新图片');if(file.disabled||(location.pathname==='/student'&&processing))throw Error('处理已开始，未替换本次任务的输入');if(!blob)throw Error('校正图保存失败');
    choose(new File([blob],'ti60_document_rectified.png',{type:'image/png'}));note.textContent='已应用校正；确认预览后开始处理。可恢复最初选图。';
   }catch(e){note.textContent=e.message;}finally{tmp.width=tmp.height=0;applying=false;by('geometryApply').disabled=false;}
  };
 });
})();
