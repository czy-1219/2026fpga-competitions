// Full-page navigation keeps each page's existing task and preview lifecycle.
(()=>{
 document.addEventListener('click',event=>{
  if(event.button!==0||event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;
  const link=event.target.closest?.('nav a[href]');
  if(!link||link.hasAttribute('download')||(link.target&&link.target!=='_self'))return;
  const target=new URL(link.href,location.href);
  if(target.origin!==location.origin||target.hash)return;
  if(target.pathname===location.pathname&&target.search===location.search){if(!event.defaultPrevented)event.preventDefault();return;}
  document.documentElement.setAttribute('data-ti60-pending','');
  clearTimeout(window.Ti60PageTimer);window.Ti60PageTimer=setTimeout(()=>window.Ti60PageReady?.(),12000);
  // Focus preview first releases its lease through its existing click handler.
  if(event.defaultPrevented)return;
  window.Ti60Transfer?.abort();
  event.preventDefault();
  requestAnimationFrame(()=>requestAnimationFrame(()=>location.assign(target.href)));
 });
})();
// Observe the existing requests; inference and transfer still use the firmware API.
const previewTiming={job:null,start:null,fpgaMs:null,resultMs:null,originalMs:null,configuration:null};
const previewFetch=window.fetch.bind(window);
const deviceRead=Ti60Transfer.read;
Ti60Transfer.read=async function(url,options){
 const source=new URL(url,location.href).searchParams.get('source'),began=performance.now();
 const bytes=await deviceRead(url,options);
 if(source==='result')previewTiming.resultMs=performance.now()-began;
 if(source==='frame_original')previewTiming.originalMs=performance.now()-began;
 return bytes;
};
window.fetch=async function(input,options){
 const path=new URL(typeof input==='string'||input instanceof URL?String(input):input.url,location.href).pathname;
 const began=performance.now();const response=await previewFetch(input,options);
 if(response.ok&&path==='/api/student/frame/start'){
  try{const state=await response.clone().json();Object.assign(previewTiming,{job:state.job_id,start:began,fpgaMs:null,resultMs:null,originalMs:null,fpgaFailed:false,trackingLost:false,configuration:String(input)});}catch{}
 }
 if(response.ok&&path==='/api/student/frame/status'){
  try{const state=await response.clone().json();if(previewTiming.start!==null){if(state.job_id!==previewTiming.job)previewTiming.trackingLost=true;else if((state.done||state.error)&&previewTiming.fpgaMs===null){previewTiming.fpgaMs=performance.now()-previewTiming.start;previewTiming.fpgaFailed=!!state.error;}}}catch{}
 }
 return response;
};
const previewXhrOpen=XMLHttpRequest.prototype.open,previewXhrSend=XMLHttpRequest.prototype.send;
XMLHttpRequest.prototype.open=function(method,url,...args){this.previewUrl=new URL(url,location.href);return previewXhrOpen.call(this,method,url,...args)};
XMLHttpRequest.prototype.send=function(...args){
 const began=performance.now();this.addEventListener('load',()=>{if(this.status>=200&&this.status<300&&this.previewUrl?.pathname==='/capture'){
  const source=this.previewUrl.searchParams.get('source');if(source==='result')previewTiming.resultMs=performance.now()-began;if(source==='frame_original')previewTiming.originalMs=performance.now()-began;
 }},{once:true});return previewXhrSend.apply(this,args);
};
document.addEventListener('DOMContentLoaded',async()=>{
 try {
 const banner=document.createElement('div');banner.className='preview-banner';banner.innerHTML='<b>TI60 / 图像处理</b><span class="preview-tag">设备界面</span>';document.body.prepend(banner);
 const navLabels={'/':'拍照','/student':'模型处理','/local':'本地图片','/portrait':'人像','/focus':'视频调焦'};
 const focusLink=document.createElement('a');focusLink.href='/focus';focusLink.textContent='视频调焦';if(location.pathname==='/focus')focusLink.setAttribute('aria-current','page');document.querySelector('nav').append(focusLink);
 document.querySelectorAll('nav a').forEach(a=>{if(navLabels[a.getAttribute('href')])a.textContent=navLabels[a.getAttribute('href')];});
 const topPanels=[...document.body.children].filter(e=>e.matches('section.panel'));
 if(document.getElementById('studentOutput')&&topPanels.length===2){
  const workspace=document.createElement('main');workspace.className='workspace';const aside=document.createElement('aside'),article=document.createElement('article');workspace.append(aside,article);topPanels[0].before(workspace);
  topPanels.forEach(p=>aside.append(p));
  for(const el of [...document.body.children])if(el!==workspace&&el!==banner&&!['SCRIPT','H1','NAV'].includes(el.tagName)&&el.previousElementSibling!==document.querySelector('h1')){
   if(el.matches('.toolbar,#status,#taskProgressLabel,#taskProgress,.images,details,.note')&&!el.textContent.startsWith('固件：'))article.append(el);
  }
  const details=document.createElement('details');details.className='advanced-options';details.innerHTML='<summary>高级选项与处理说明</summary>';
  for(const id of ['browserPreprocess','browserFinish'])details.append(document.getElementById(id).closest('label'));
  const notes=[...topPanels[1].querySelectorAll(':scope>p.note')];notes.forEach(p=>details.append(p));topPanels[1].append(details);
  const timing=document.createElement('div');timing.className='preview-timing';timing.setAttribute('aria-label','本次会话计时');timing.innerHTML='<span>启动至 FPGA 完成<strong id="computeTime">—</strong></span><span>结果回传<strong id="resultTime">—</strong></span><span>原图回传<strong id="originalTime">—</strong></span>';document.getElementById('taskProgress').after(timing);
  const format=ms=>ms===null?'—':(ms/1000).toFixed(1)+' 秒';
  setInterval(()=>{document.getElementById('computeTime').textContent=previewTiming.start===null?'—':previewTiming.trackingLost?'任务已更换':format(previewTiming.fpgaMs??(performance.now()-previewTiming.start))+(previewTiming.fpgaFailed?'（失败）':previewTiming.fpgaMs===null?'（计时中）':'');document.getElementById('resultTime').textContent=format(previewTiming.resultMs);document.getElementById('originalTime').textContent=format(previewTiming.originalMs);},500);
  const exportTiming=document.createElement('button');exportTiming.textContent='导出本次计时';exportTiming.type='button';exportTiming.onclick=()=>{const record={...previewTiming,capturedAt:new Date().toISOString(),note:'本次任务观察的耗时；包含请求与轮询延迟，非 FPGA 内部周期。页面重开或接续旧任务无法恢复此前起点；设备诊断另有断电前的时间检查点。'};delete record.start;const url=URL.createObjectURL(new Blob([JSON.stringify(record,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='ti60-timing-'+(record.job??'no-job')+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};document.getElementById('readDiagnostics').after(exportTiming);
  const exportDiagnostics=document.createElement('button');exportDiagnostics.textContent='导出诊断';exportDiagnostics.onclick=async()=>{await readDiagnostics();const u=URL.createObjectURL(new Blob([document.getElementById('diagnostics').textContent],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='ti60-diagnostics.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);};exportTiming.after(exportDiagnostics);
  // Mobile workflow: large single-column controls and an always reachable action bar.
  document.body.classList.add('mobile-student');
  const actions=document.createElement('div');actions.className='phone-actions';actions.setAttribute('aria-label','处理任务');
  for(const id of ['run','attach','stop'])actions.append(document.getElementById(id));
  document.body.append(actions);
  document.getElementById('attach').textContent='继续读取';document.getElementById('stop').textContent='暂停读取';
  const downloads=article.querySelector(':scope>.toolbar');
  const saveDetails=document.createElement('details');saveDetails.className='panel phone-downloads';saveDetails.innerHTML='<summary>保存图片与结果对比</summary>';downloads.before(saveDetails);saveDetails.append(downloads);
  const images=article.querySelector('.images');
  const tabs=document.createElement('div');tabs.className='image-tabs';tabs.setAttribute('role','tablist');tabs.setAttribute('aria-label','图像对比');
  const sections=[...images.children];
  const selectTab=index=>{sections.forEach((s,i)=>{s.hidden=i!==index;tabs.children[i].setAttribute('aria-selected',String(i===index));tabs.children[i].tabIndex=i===index?0:-1;});};
  sections.forEach((section,i)=>{section.id='phone-image-'+i;section.setAttribute('role','tabpanel');section.setAttribute('aria-labelledby','phone-tab-'+i);section.tabIndex=0;const tab=document.createElement('button');tab.type='button';tab.id='phone-tab-'+i;tab.textContent=i===0?'原图':'处理结果';tab.setAttribute('role','tab');tab.setAttribute('aria-controls',section.id);tab.onclick=()=>selectTab(i);tab.onkeydown=e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();const next=e.key==='Home'?0:e.key==='End'?1:1-i;selectTab(next);tabs.children[next].focus();}};tabs.append(tab);});
  images.before(tabs);images.after(saveDetails);selectTab(0);
  new MutationObserver(()=>{if(document.getElementById('result').width>0)selectTab(1);}).observe(document.getElementById('result'),{attributes:true,attributeFilter:['width']});
  const instructions=document.createElement('details');instructions.className='phone-help';instructions.innerHTML='<summary>图片保存说明</summary>';
  article.querySelectorAll(':scope>p.note').forEach(p=>instructions.append(p));saveDetails.append(instructions);
  const timingDetails=document.createElement('details');timingDetails.className='panel phone-timing';timingDetails.innerHTML='<summary>处理耗时</summary>';saveDetails.after(timingDetails);timingDetails.append(timing);
  const version=document.querySelector('body>p.note');if(version)document.getElementById('diagnostics').before(version);
  document.getElementById('sourceInfo').textContent='从相册选图，或使用板载摄像头。';
 }
 if(!document.getElementById('focusStart'))unifyPhoneWorkflow();
 const footer=document.createElement('footer');footer.textContent='Ti60F225 · 设备界面 · F9-V8-1031-SPI';document.body.append(footer);
 installDeviceControls();
 installImageComparison();
 finalizeResultLayout();
 } finally { window.Ti60PageReady?.(); }
});

function installImageComparison(){
 const source=document.getElementById('converted')||document.getElementById('original');
 const result=document.getElementById('processed')||document.getElementById('result');
 if(!source||!result)return;
 const panel=document.createElement('section');panel.className='panel image-comparison';
 panel.innerHTML='<h3>滑动对比原图 / 处理结果</h3><p class="note">左侧原图，右侧当前处理结果。</p><canvas aria-label="原图和处理结果滑动对比" hidden></canvas><label>对比分界 <input type="range" min="0" max="100" value="50" aria-label="对比分界" disabled></label><p class="compare-message note"></p>';
 result.closest('.images').after(panel);
 const canvas=panel.querySelector('canvas'),slider=panel.querySelector('input'),message=panel.querySelector('.compare-message');
 function draw(){
  const save=document.getElementById('download')||document.getElementById('save');
  const ready=save&&(document.getElementById('studentOutput')?result.dataset.complete==='1':!save.disabled)&&source.width&&result.width&&source.dataset.mismatched!=='1';
  canvas.hidden=!ready;slider.disabled=!ready;
  if(!ready){canvas.width=canvas.height=0;message.textContent=source.dataset.mismatched==='1'?'此任务原图未保留，无法对比。':'完成处理后可拖动对比。';return;}
  if(canvas.width!==result.width||canvas.height!==result.height){canvas.width=result.width;canvas.height=result.height;}
  const ctx=canvas.getContext('2d'),cut=Math.round(canvas.width*Number(slider.value)/100);
  ctx.clearRect(0,0,canvas.width,canvas.height);ctx.fillStyle='#f4f5f3';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(result,0,0);
  ctx.save();ctx.beginPath();ctx.rect(0,0,cut,canvas.height);ctx.clip();ctx.drawImage(source,0,0,canvas.width,canvas.height);ctx.restore();ctx.fillStyle='#fff';ctx.fillRect(cut-1,0,2,canvas.height);
  message.textContent='当前结果已校验；扫描件已完成去阴影与去噪。';
 }
 slider.addEventListener('input',draw);
 const save=document.getElementById('download')||document.getElementById('save');
 new MutationObserver(draw).observe(save,{attributes:true,attributeFilter:['disabled']});
 result.addEventListener('ti60-result',draw);result.addEventListener('pointerup',draw);
 new MutationObserver(draw).observe(source,{attributes:true,attributeFilter:['data-mismatched']});
 document.getElementById('portraitFinish')?.addEventListener('change',()=>setTimeout(draw,0));
 for(const id of ['brushKeep','brushErase','brushOff','brushReset','compareFpga'])document.getElementById(id)?.addEventListener('click',()=>setTimeout(draw,0));
 draw();
}
function finalizeResultLayout(){
 const article=document.querySelector('.workspace article');if(!article||document.getElementById('focusStart'))return;
 for(const d of article.querySelectorAll('details.phone-downloads,details.phone-timing')){
  const section=document.createElement('section');section.className=d.className;
  const title=document.createElement('h3');title.textContent=d.querySelector('summary').textContent;section.append(title);
  for(const child of [...d.children])if(child.tagName!=='SUMMARY')section.append(child);d.replaceWith(section);
 }
 const card=document.createElement('section');card.className='panel result-card';
 const children=[...article.children];article.prepend(card);for(const child of children)card.append(child);
}

// Reparent the firmware's existing controls: IDs, handlers, API requests and
// canvas objects remain intact. This same layout is served by the ESP32.
function unifyPhoneWorkflow(){
 const byId=id=>document.getElementById(id);
 const make=(tag,cls,text)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text)e.textContent=text;return e;};
 const heading=text=>make('h2','step-heading',text);
 const card=text=>{const e=make('section','panel');e.append(heading(text));return e;};
 const fold=text=>{const e=make('details','panel');e.append(make('summary','',text));return e;};
 const move=(parent,...nodes)=>nodes.filter(Boolean).forEach(e=>parent.append(e));
 const page=byId('studentOutput')?'model':byId('capture')?'capture':byId('processed')?'local':'portrait';
 document.body.dataset.page=page;
 const title=document.querySelector('h1'),nav=document.querySelector('nav');title.textContent='图像处理';
 document.querySelector('.preview-banner').after(title,nav);
 for(const a of nav.children){if(a.classList.contains('active')||a.hasAttribute('aria-current'))a.setAttribute('aria-current','page');}
 const descriptions={model:'模型处理 · 彩色、灰阶与文字，可配合联合算法。',capture:'拍照 · 使用板载摄像头，选择传统处理效果。',local:'本地图片 · 调整裁剪与尺寸，再交给 FPGA 处理。',portrait:'人像 · 提取透明背景，支持画笔微调。'};
 nav.after(make('p','mode-description',descriptions[page]));
 if(page==='model'){
  const panels=document.querySelectorAll('.workspace aside>section.panel');
  panels[0].querySelector('h2').textContent='1. 图像来源';panels[1].querySelector('h2').textContent='2. 处理设置';
  panels.forEach(p=>p.querySelector('h2').classList.add('step-heading'));
  byId('status').before(heading('3. 结果与下载'));
  document.querySelector('.phone-downloads>summary').textContent='保存与下载';
  return;
 }
 const oldMain=document.querySelector('main'),workspace=make('main','workspace'),aside=make('aside'),article=make('article');workspace.append(aside,article);oldMain.before(workspace);
 const source=card('1. 图像来源'),settings=card('2. 处理设置');aside.append(source,settings);
 const status=byId('status'),progress=byId('taskProgress')||byId('progress'),progressLabel=byId('taskProgressLabel')||byId('progressLabel');
 article.append(heading('3. 结果与下载'),status,progressLabel,progress);
 const actions=make('div','phone-actions');actions.setAttribute('aria-label','处理任务');document.body.append(actions);
 const saves=fold('保存与下载');saves.classList.add('phone-downloads');const saveButtons=make('div','toolbar');saves.append(saveButtons);
 const images=make('div','images');article.append(images,saves);
 const advanced=oldMain.querySelector('details');
 let imageSections=[],labels=[];
 const imagePanel=(canvas,label)=>{const section=make('section');section.append(make('h2','',label),canvas);images.append(section);return section;};
 if(page==='capture'){
  source.append(make('p','note','板载摄像头 · 点击底部“开始抓拍”获取画面。'),byId('resolutions'));
  source.append(make('p','note','720p 摄像头实际导出为 1024×600。'));
  move(settings,byId('modes'),advanced);
  move(actions,byId('capture'),byId('resume'),byId('freeze'));
  byId('resume').textContent='恢复预览';byId('freeze').textContent='冻结画面';byId('capture').textContent='开始抓拍';byId('capture').classList.add('primary');
  move(saveButtons,byId('download'),byId('downloadRaw'));
  imageSections=[imagePanel(byId('view'),'处理结果')];labels=['处理结果'];
  saves.append(make('p','note','抓拍按原分辨率处理与回传；原图模式下可另存抓拍原图。'));
 }else if(page==='local'){
  source.append(byId('file').closest('.toolbar'));
  const crop=fold('尺寸与裁剪');crop.classList.remove('panel');byId('file').addEventListener('change',()=>{if(byId('file').files.length)crop.open=true;});
  for(const [id,label] of [['targets','输出尺寸'],['orientations','画面方向'],['fits','适配方式']]){crop.append(make('p','field-label',label),byId(id));}
  const sourcePanel=byId('source').closest('section');sourcePanel.classList.remove('panel');crop.append(sourcePanel);source.append(crop);
  move(settings,byId('modes'),advanced,byId('limit'));
  actions.append(byId('process'));byId('process').textContent='开始处理';
  saveButtons.append(byId('download'));
  const converted=byId('converted').closest('section');converted.classList.remove('panel');images.append(converted);
  byId('targetSize').textContent=byId('targetSize').textContent.replace('RGB565','JPEG');
  imageSections=[converted,imagePanel(byId('processed'),'处理结果')];labels=['上传预览','处理结果'];
 }else{
  source.append(byId('file'));const cameras=make('div','toolbar');move(cameras,byId('camera720'),byId('camera1080'));source.append(cameras,make('p','note','从相册选图，或使用板载摄像头。'));
  byId('camera720').textContent='720p摄像头';byId('camera1080').textContent='1080p摄像头';
  settings.append(make('p','field-label','人像提取'),make('p','note','处理完成后生成透明背景 PNG；可在结果区微调边缘。'));
  const finish=make('label');finish.innerHTML='背景清理 <select id="portraitFinish"><option value="clean">轻度清理</option><option value="strong">加强清理</option><option value="raw">关闭 · 原模型掩码</option></select>';settings.append(finish,make('p','note','清除孤立背景并收紧低置信度边缘，不重新运行模型。切换会重置画笔；多人会尽量保留，粘连背景可用去除画笔。'));byId('portraitFinish').onchange=changePortraitFinish;
  move(actions,byId('restore'),byId('run'));byId('restore').textContent='继续读取';byId('run').textContent='开始处理';
  saveButtons.append(byId('download'));
  imageSections=[...oldMain.querySelector('.images').children];imageSections.forEach(e=>images.append(e));labels=['原图','处理结果'];
  const brushes=fold('边缘微调');brushes.classList.add('brush-options');const controls=byId('brushKeep').closest('.controls');brushes.append(controls,make('p','note','在处理结果上使用保留或去除画笔，再保存透明 PNG。'));images.after(brushes);
 }
 actions.style.gridTemplateColumns=actions.children.length===3?'1.45fr 1fr 1fr':`repeat(${actions.children.length}, minmax(0,1fr))`;
 const tabs=make('div','image-tabs');tabs.style.gridTemplateColumns=`repeat(${labels.length}, minmax(0,1fr))`;tabs.setAttribute('role','tablist');tabs.setAttribute('aria-label','图像对比');images.before(tabs);
 const select=index=>imageSections.forEach((s,i)=>{s.hidden=i!==index;tabs.children[i].setAttribute('aria-selected',String(i===index));tabs.children[i].tabIndex=i===index?0:-1;});
 imageSections.forEach((section,i)=>{
  section.id='phone-image-'+i;section.setAttribute('role','tabpanel');section.setAttribute('aria-labelledby','phone-tab-'+i);section.tabIndex=0;
  const tab=make('button','',labels[i]);tab.id='phone-tab-'+i;tab.type='button';tab.setAttribute('role','tab');tab.setAttribute('aria-controls',section.id);tab.onclick=()=>select(i);
  tab.onkeydown=e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();const n=labels.length,next=e.key==='Home'?0:e.key==='End'?n-1:(i+(e.key==='ArrowRight'?1:n-1))%n;select(next);tabs.children[next].focus();}};tabs.append(tab);
 });select(0);
 // Completion is signalled by the existing download control, after CRC/decode.
 const download=byId('download');let wasReady=false;
 new MutationObserver(()=>{const ready=!download.disabled;if(ready&&!wasReady)select(imageSections.length-1);wasReady=ready;}).observe(download,{attributes:true,attributeFilter:['disabled']});
 if(page==='portrait')for(const id of ['brushKeep','brushErase','brushOff','brushReset'])byId(id).addEventListener('click',()=>select(1));
 // Empty previews should be a neutral placeholder, without clearing canvases or
 // changing dimensions used by the original crop/inference routines.
 const waits=page==='capture'?[[byId('view'),download,'disabled']]:page==='local'?[[byId('source'),byId('sourceSize'),'text'],[byId('converted'),byId('sourceSize'),'text'],[byId('processed'),download,'disabled']]:[[byId('original'),byId('original'),'data-loaded'],[byId('result'),download,'disabled']];
 for(const [canvas,signal,attribute] of waits){
  const placeholder=make('p','empty-image',canvas.id==='source'||canvas.id==='original'||canvas.id==='converted'?'选择图片后查看预览':'处理完成后查看结果');canvas.after(placeholder);
  let received=false;const update=()=>{const ready=attribute==='text'?!!signal.textContent:attribute==='disabled'?!signal.disabled:!!signal.dataset.loaded;received=received||ready;canvas.classList.toggle('preview-empty',!received);placeholder.hidden=received;};update();
  new MutationObserver(update).observe(signal,attribute==='text'?{childList:true,subtree:true,characterData:true}:{attributes:true,attributeFilter:[attribute]});
 }
 // Only empty wrappers and explanatory text remain in the old containers.
 oldMain.remove();document.querySelector('header')?.remove();
}
