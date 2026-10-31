/* One phone-facing upload workflow, adapting the existing per-mode handlers. */
(()=>{
 function geometry(sw,sh,tw,th,fit,fx=.5,fy=.5){
  let w=sw,h=sh,dx=0,dy=0,dw=tw,dh=th;
  if(fit==='contain'){const k=Math.min(tw/sw,th/sh);dw=sw*k;dh=sh*k;dx=(tw-dw)/2;dy=(th-dh)/2;}
  else if(fit==='pixel'){w=Math.min(sw,tw);h=Math.min(sh,th);dw=w;dh=h;dx=(tw-w)/2;dy=(th-h)/2;}
  else if(sw/sh>tw/th)w=sh*tw/th;else h=sw*th/tw;
  return {x:(sw-w)*Math.max(0,Math.min(1,fx)),y:(sh-h)*Math.max(0,Math.min(1,fy)),w,h,dx,dy,dw,dh};
 }
 if(typeof module!=='undefined')module.exports={geometry};
 if(typeof window==='undefined')return;
 document.addEventListener('DOMContentLoaded',()=>{
  const page=document.body.dataset.page,file=document.getElementById('file');if(!file||!['local','model','portrait'].includes(page))return;
  const by=id=>document.getElementById(id),card=file.closest('section.panel');if(!card)return;
  let fold;
  if(page==='local')fold=card.querySelector('details');
  else{fold=document.createElement('details');fold.className='upload-crop';fold.innerHTML='<summary>尺寸与裁剪</summary>';card.append(fold);}
  fold.classList.add('upload-crop');
  const controls=document.createElement('div');controls.className='upload-options';
  controls.innerHTML='<label>处理尺寸<select id="uploadSize">'+(page==='portrait'?'<option value="original">原始尺寸</option>':'')+'<option value="720">1024 × 600</option><option value="1080">1920 × 1080</option>'+(page==='portrait'?'':'<option value="small">256 × 224 · 快速</option>')+'</select></label><label>适配方式<select id="uploadFit"><option value="cover">填满裁剪</option><option value="contain">完整保留</option><option value="pixel">原始像素 1:1</option></select></label><button id="uploadReset" type="button">居中重置</button><p class="note">选择图片 → 调整尺寸与取景 → 开始处理。绿色取景框可以拖动。</p>';
  fold.querySelector('summary').after(controls);
  const size=by('uploadSize'),fitSelect=by('uploadFit'),reset=by('uploadReset');
  const hide=id=>{const e=by(id);if(e)e.style.display='none';};
  if(page==='model'){
   fold.append(by('studentCropPanel'));hide('jointSizeGroup');by('studentCropFit').closest('label').style.display='none';hide('studentCropReset');
   size.value=by('jointSize').value;fitSelect.value=by('studentCropFit').value;
   size.onchange=()=>{by('jointSize').value=size.value;renderStudentCrop();};fitSelect.onchange=()=>{by('studentCropFit').value=fitSelect.value;renderStudentCrop();};reset.onclick=()=>by('studentCropReset').click();
  }else if(page==='local'){
   for(const id of ['targets','orientations','fits']){const e=by(id);if(e.previousElementSibling?.classList.contains('field-label'))e.previousElementSibling.style.display='none';hide(id);}
   size.value=target==='256x224'?'small':target==='1920x1080'?'1080':'720';fitSelect.value=fit;
   const invalidate=()=>{out.dataset.complete='';out.cleanedBlob=null;download.disabled=true;};
   size.onchange=()=>{if(busy)return;invalidate();by('targets').querySelector('[data-target="'+(size.value==='small'?'256x224':size.value==='1080'?'1920x1080':'1024x600')+'"]').click();};
   fitSelect.onchange=()=>{if(busy)return;invalidate();by('fits').querySelector('[data-fit="'+fitSelect.value+'"]').click();};
   reset.onclick=()=>{if(busy)return;invalidate();focusX=focusY=50;render();};
  }else{
   let photo=null,fx=.5,fy=.5,view=null,drag=null,ticket=0;
   const canvas=document.createElement('canvas');canvas.id='portraitCropPreview';canvas.width=640;canvas.height=360;canvas.style.touchAction='none';
   const info=document.createElement('p');info.className='note';fold.append(info,canvas);
   function clear(){photo?.close();photo=null;view=null;drag=null;ticket++;}
   function renderCrop(){
    if(!photo||busy)return;const tw=size.value==='original'?photo.width:size.value==='1080'?1920:1024,th=size.value==='original'?photo.height:size.value==='1080'?1080:600;
    const g=geometry(photo.width,photo.height,tw,th,fitSelect.value,fx,fy),ctx=original.getContext('2d');original.width=tw;original.height=th;ctx.fillStyle='#222';ctx.fillRect(0,0,tw,th);ctx.drawImage(photo,g.x,g.y,g.w,g.h,g.dx,g.dy,g.dw,g.dh);
    const scale=Math.min(640/photo.width,360/photo.height),ox=(640-photo.width*scale)/2,oy=(360-photo.height*scale)/2,pc=canvas.getContext('2d');pc.fillStyle='#222';pc.fillRect(0,0,640,360);pc.drawImage(photo,ox,oy,photo.width*scale,photo.height*scale);
    if(fitSelect.value!=='contain'){pc.strokeStyle='#36a269';pc.lineWidth=3;pc.strokeRect(ox+g.x*scale,oy+g.y*scale,g.w*scale,g.h*scale);}
    view={g,scale,ox,oy};original.dataset.loaded='1';complete=false;jobStarted=false;lastPortraitMask=null;controlsPortrait();
    info.textContent=photo.width+'×'+photo.height+' → '+tw+'×'+th+' · '+(size.value==='original'?'原始尺寸':fitSelect.options[fitSelect.selectedIndex].textContent);
    by('status').textContent='已加载图片，请调整裁剪后开始处理';
   }
   // The existing controls() remains authoritative for model availability and busy state.
   const controlsPortrait=()=>window.updatePortraitControls();
   file.onchange=async()=>{const f=file.files[0];if(!f||busy)return;const seq=++ticket;busy=true;complete=false;jobStarted=false;lastPortraitMask=null;original.dataset.loaded='';controlsPortrait();
    try{const im=await createImageBitmap(f);if(seq!==ticket){im.close();return;}photo?.close();photo=im;fx=fy=.5;busy=false;renderCrop();fold.open=true;}catch(e){by('status').textContent='图片读取失败：'+e.message;}finally{busy=false;controlsPortrait();}
   };
   size.onchange=fitSelect.onchange=renderCrop;reset.onclick=()=>{fx=fy=.5;renderCrop();};
   const point=e=>{const rect=canvas.getBoundingClientRect();return{x:(e.clientX-rect.left)*640/rect.width,y:(e.clientY-rect.top)*360/rect.height};};
   canvas.onpointerdown=e=>{if(busy||!view||fitSelect.value==='contain')return;const p=point(e),{g,scale,ox,oy}=view;if(p.x<ox+g.x*scale||p.x>ox+(g.x+g.w)*scale||p.y<oy+g.y*scale||p.y>oy+(g.y+g.h)*scale)return;drag={id:e.pointerId,p,...view};canvas.setPointerCapture(e.pointerId);e.preventDefault();};
   canvas.onpointermove=e=>{if(!drag||busy||drag.id!==e.pointerId)return;const p=point(e),mx=photo.width-drag.g.w,my=photo.height-drag.g.h;fx=mx?Math.max(0,Math.min(1,(drag.g.x+(p.x-drag.p.x)/drag.scale)/mx)):.5;fy=my?Math.max(0,Math.min(1,(drag.g.y+(p.y-drag.p.y)/drag.scale)/my)):.5;renderCrop();e.preventDefault();};
   canvas.onpointerup=canvas.onpointercancel=()=>{drag=null;};
   for(const id of ['camera720','camera1080']){const btn=by(id),handler=btn.onclick;btn.onclick=async e=>{if(busy)return;clear();fold.open=false;return handler(e);};}
  }
  file.addEventListener('change',()=>{if(file.files.length)fold.open=true;});
 });
})();
