// CRC proves transport integrity, not whether a computed frame has valid content.
(()=>{
 function statistics(canvas){
  if(!canvas?.width||!canvas.height)return null;
  const d=canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data;
  let maximum=0,bright=0,sum=0;
  for(let i=0;i<d.length;i+=4){const m=Math.max(d[i],d[i+1],d[i+2]);maximum=Math.max(maximum,m);bright+=m>24;sum+=d[i]+d[i+1]+d[i+2];}
  return {width:canvas.width,height:canvas.height,maximum,mean:sum/(canvas.width*canvas.height*3),brightFraction:bright/(canvas.width*canvas.height)};
 }
 async function verify({state,canvas,original,readRaw,progress}){
  const jpeg=statistics(canvas);
  if(!jpeg||jpeg.maximum>1)return;
  const diagnostic={job:state.job_id,cookie:state.cookie,boot:state.boot_id,contentStatus:state.content_status??null,jpeg,original:statistics(original),phase:'checking_raw'};
  window.Ti60ImageDiagnostic=diagnostic;
  progress('结果接近全黑，正在核对同一任务的原始像素',null);
  // Never recompute or substitute the input. The fallback reads the same result.
  if(canvas.dataset.transport!=='rgb565')await readRaw('result',canvas);
  diagnostic.raw=statistics(canvas);
  if(diagnostic.raw.maximum>1){canvas.dataset.recovery='rgb565-content';diagnostic.phase='recovered_from_raw';return;}
  const input=document.createElement('canvas');await readRaw('frame_original',input);
  diagnostic.input=statistics(input);
  if(diagnostic.input.brightFraction<.01 && !(diagnostic.original?.brightFraction>=.01)){
   diagnostic.phase='dark_input';return;
  }
  const flags=state.content_status||0;
  diagnostic.phase=diagnostic.input.brightFraction<.01?'input_black':
   flags&128 ? !(flags&64)?'input_conversion_zero':!(flags&32)?'model_tensor_zero':!(flags&16)?'result_conversion_zero':'result_readback_black':'output_black';
  const e=Error(diagnostic.phase==='input_black'?'输入像素异常为全黑；任务与原图已保留，请导出诊断':
   '处理结果异常：原图有内容，但 JPEG 与原始像素均为全黑；任务已保留，请导出诊断');
  e.code='IMAGE_CONTENT';throw e;
 }
 window.Ti60ResultGuard={statistics,verify};
})();
