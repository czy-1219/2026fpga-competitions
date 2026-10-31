/* Camera-only display/export trim; FPGA JPEG, uploads and model inputs stay intact. */
(()=>{
 function trim(data){
  for(let i=0;i<data.length;i+=4){
   const r=data[i],g=data[i+1],b=data[i+2],c=Math.min(g,b);
   if(g>=32&&g<=223&&b>=32&&b<=223&&c>r+12){
    const d=Math.min(24,(c-r)>>2);data[i]=r+d;data[i+1]=g-(d>>1);data[i+2]=b-(d>>1);
   }
  }
  return data;
 }
 async function finish(canvas){
  canvas.correctedBlob=null;
  if(!document.getElementById('cameraCyan')?.checked)return false;
  const ctx=canvas.getContext('2d'),pixels=ctx.getImageData(0,0,canvas.width,canvas.height);trim(pixels.data);ctx.putImageData(pixels,0,0);
  canvas.correctedBlob=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',.95));
  if(!canvas.correctedBlob)throw Error('摄像头校色 JPEG 保存失败');return true;
 }
 const api={trim,finish};if(typeof module!=='undefined')module.exports=api;
 if(typeof window==='undefined')return;window.Ti60CameraColor=api;
 document.addEventListener('DOMContentLoaded',()=>{
  if(document.body.dataset.page!=='capture')return;
  const label=document.createElement('label');label.innerHTML='<input id="cameraCyan" type="checkbox" checked> 彩色增强去青色（仅摄像头）';
  document.getElementById('modes').after(label);
 });
})();
