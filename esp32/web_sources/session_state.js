/* Route-local draft and exact model-input persistence. Images remain on this
 * browser; job + boot + cookie/request must match before restoring a comparison. */
(()=>{
 let tab=sessionStorage.getItem('ti60.images.tab');if(!tab){tab=Ti60Task.token();sessionStorage.setItem('ti60.images.tab',tab);}
 const prefix=tab+':',route=location.pathname;let dbPromise,restoring=false,chosenFile=null,pending=Promise.resolve(),readyResolve;
 const ready=new Promise(ok=>readyResolve=ok);
 function database(){return dbPromise||(dbPromise=new Promise((ok,fail)=>{
  const req=indexedDB.open('ti60-images-v73',1);req.onupgradeneeded=()=>req.result.createObjectStore('images');req.onsuccess=()=>ok(req.result);req.onerror=()=>fail(req.error);
 }));}
 async function get(key){const db=await database();return new Promise((ok,fail)=>{const req=db.transaction('images').objectStore('images').get(prefix+key);req.onsuccess=()=>ok(req.result);req.onerror=()=>fail(req.error);});}
 async function put(key,value){const db=await database();return new Promise((ok,fail)=>{const tx=db.transaction('images','readwrite');tx.objectStore('images').put(value,prefix+key);tx.oncomplete=ok;tx.onerror=()=>fail(tx.error);tx.onabort=()=>fail(tx.error||Error('图片保存被取消'));});}
 function report(e){const node=document.getElementById('sessionNotice');if(node)node.textContent='本机图片保留失败：'+e.message+'。切页后可能需要重新选图。';}
 function settings(){const values={};for(const id of ['uploadSize','uploadFit','studentOutput','studentPipeline','browserPreprocess','browserFinish','returnOriginal','chromaStrength','chromaScale']){const n=document.getElementById(id);if(n)values[id]=n.type==='checkbox'?n.checked:n.value;}return values;}
 function saveDraft(){if(restoring)return pending;const data={file:chosenFile,values:settings(),at:Date.now()};
  if(route==='/student'){data.fx=studentCropFocusX;data.fy=studentCropFocusY;data.kind=sourceKind;data.resolution=cameraResolution;}
  if(route==='/local'){data.fx=focusX;data.fy=focusY;data.mode=mode;}
  pending=pending.then(()=>put('draft:'+route,data)).catch(report);return pending;
 }
 async function paint(blob,canvas){const im=await createImageBitmap(blob);canvas.width=im.width;canvas.height=im.height;canvas.getContext('2d').drawImage(im,0,0);im.close();canvas.dataset.loaded='1';canvas.dataset.mismatched='';canvas.classList.remove('preview-empty');}
 async function restoreTask(state){
  if(route!=='/student')return false;
  let saved;try{saved=await get('model-task');}catch(e){report(e);}
  const match=saved?.blob&&state.source==='upload'&&saved.boot===state.boot_id&&saved.cookie===state.cookie&&saved.job===state.job_id;
  // The request token can also bind an input saved before an interrupted POST.
  let input=match?saved:null;
  if(!input&&state.source==='upload')try{const x=await get('model-pending');if(x?.blob&&x.request&&x.request===state.request)input={...x,job:state.job_id,boot:state.boot_id,cookie:state.cookie};}catch(e){report(e);}
  if(input){const identity=[state.boot_id,state.cookie,state.job_id].join(':');if(original.dataset.task!==identity||original.dataset.mismatched==='1')await paint(input.blob,original);original.dataset.task=identity;localInputSnapshot=input;sourceKind='local';return true;}
  if(state.source==='upload')original.dataset.mismatched='1';
  return false;
 }
 // Immutable processing settings are bound to the board task, separate from
 // editable page drafts and explicit "apply to current result" controls.
 let profileRecord=null;
 const profileMatches=(x,state)=>x && (x.job!=null ? x.job===state.job_id&&x.boot===state.boot_id&&x.cookie===state.cookie : x.request&&x.request===state.request);
 async function taskProfile(state){
  let x=profileRecord;if(!profileMatches(x,state))try{x=await get('model-profile');}catch(e){report(e);}
  if(profileMatches(x,state)&&x.profile){
   const wire=x.profile.studentOutput==='document'?'color':x.profile.studentOutput;
   if(wire===state.output){profileRecord=x;return {...x.profile};}
  }
  // Old/foreign jobs have no trustworthy finishing settings. Never infer
 // scanning or sharpening from a selector changed after the job was started.
  return {studentOutput:state.output,browserFinish:'auto',chromaStrength:'off',chromaScale:'medium'};
 }
 async function savePending(input,request){
  await saveDraft();profileRecord={request,profile:settings(),at:Date.now()};
  try{await put('model-profile',profileRecord);await put('model-pending',input?{blob:input.blob,request,at:Date.now()}:null);await put('model-task',null);}catch(e){report(e);}
 }
 async function bindTask(input,state){
  try{
   if(!profileRecord)profileRecord=await get('model-profile');
   if(profileRecord?.request&&profileRecord.request===state.request){profileRecord={...profileRecord,job:state.job_id,boot:state.boot_id,cookie:state.cookie};await put('model-profile',profileRecord);}
   await put('model-task',input?{...input,job:state.job_id,boot:state.boot_id,cookie:state.cookie,request:state.request,at:Date.now()}:null);
  }catch(e){report(e);}
 }
 window.Ti60Session={ready,savePending,bindTask,restoreTask,saveDraft,taskProfile};
 document.addEventListener('DOMContentLoaded',async()=>{
  const file=document.getElementById('file');if(!file){readyResolve();return;}
  const notice=document.createElement('p');notice.id='sessionNotice';notice.className='note';file.parentElement.append(notice);
  try{
   restoring=true;const saved=await get('draft:'+route);
   if(saved){
    for(const [id,v] of Object.entries(saved.values||{})){const n=document.getElementById(id);if(n){if(n.type==='checkbox')n.checked=v;else n.value=v;}}
    if(saved.file&&!(route==='/student'&&saved.kind==='camera')){
     chosenFile=saved.file;const dt=new DataTransfer();dt.items.add(saved.file);file.files=dt.files;
     if(route==='/student'){
      sourceKind='local';studentOriginalFile=saved.file;
      document.getElementById('jointSize').value=saved.values.uploadSize||'720';document.getElementById('studentCropFit').value=saved.values.uploadFit||'cover';
      await loadStudentCrop(saved.file);studentCropFocusX=saved.fx??.5;studentCropFocusY=saved.fy??.5;renderStudentCrop();
     }else{
      file.dispatchEvent(new Event('change',{bubbles:true}));
      if(route==='/local'){target=saved.values.uploadSize==='1080'?'1920x1080':'1024x600';fit=saved.values.uploadFit||'cover';focusX=saved.fx??50;focusY=saved.fy??50;mode=saved.mode??0;updateButtons('#modes','mode',mode);}
     }
     notice.textContent='已恢复本页上传图片。模型任务可点击“继续读取”。';
    }
    if(route==='/student'){
     if(saved.kind==='camera'){sourceKind='camera';cameraResolution=saved.resolution||720;}
     const state=await Ti60Transfer.json('/api/student/frame/status',{}).catch(()=>null);if(state&&(state.busy||state.done))await restoreTask(state);
     controls();
    }
   }
  }catch(e){report(e);}finally{restoring=false;readyResolve();}
  file.addEventListener('change',()=>{if(restoring)return;chosenFile=file.files[0]||null;saveDraft();});
  document.addEventListener('change',e=>{if(!e.target.closest('.image-comparison'))saveDraft();});document.addEventListener('pointerup',e=>{if(e.target.closest('.upload-crop,#studentCropPanel'))saveDraft();});
  document.querySelectorAll('nav a').forEach(a=>a.addEventListener('click',async e=>{if(e.ctrlKey||e.metaKey||e.shiftKey||e.button)return;e.preventDefault();await saveDraft();location.href=a.href;}));
  window.addEventListener('pagehide',()=>{saveDraft();});
 });
})();
