/* Visibility only: preserve existing controls, values and processing paths. */
(()=>{document.addEventListener('DOMContentLoaded',()=>{
 const modes=document.getElementById('modes'),output=document.getElementById('studentOutput');
 const notes={1:'灰阶曲线：提升文字与背景对比。',2:'中值去噪：清理黑白噪点，细字可关闭。',3:'色度平滑：减轻杂色。保色扫描增强：提亮文档，保留彩色标注。'};
 function update(){
  const mode=output ? output.value : Number(modes?.querySelector('button.active')?.dataset.mode||0);
  const scan=document.querySelector('.scan-options');if(scan)scan.hidden=output ? mode!=='document' : mode!==2;
  if(modes){
   const mask=[0,1,8,6][mode]||0;
   for(const e of document.querySelectorAll('.alg'))e.closest('label').hidden=!(Number(e.value)&mask);
   const advanced=document.querySelector('.alg')?.closest('details');
   if(advanced){advanced.hidden=!mask;const note=advanced.querySelector('p.note');if(note)note.textContent=notes[mode]||'';}
   const cyan=document.getElementById('cameraCyan');if(cyan)cyan.closest('label').hidden=mode!==3;
  }
  if(output){
   const chroma=document.querySelector('.chroma-options');if(chroma)chroma.hidden=mode!=='color';
   // Document output already has its dedicated scan finishing path.
   const finish=document.getElementById('browserFinish');finish.closest('label').hidden=mode==='document';
   
   if(mode!=='document'&&finish.value==='specks')finish.value='auto';
   const preprocess=document.getElementById('browserPreprocess');
   const camera=typeof sourceKind!=='undefined'&&sourceKind==='camera';
   preprocess.closest('label').hidden=camera;
   const captureSettings=document.querySelector('.camera-settings');if(captureSettings)captureSettings.hidden=!camera;
  }
 }
 if(modes)new MutationObserver(update).observe(modes,{subtree:true,attributes:true,attributeFilter:['class']});
 output?.addEventListener('change',update);
 const sourceGroup=document.getElementById('jointSizeGroup');
 if(sourceGroup)new MutationObserver(update).observe(sourceGroup,{attributes:true,attributeFilter:['hidden']});
 update();
 if(window.Ti60Session)Ti60Session.ready.then(update);
});})();
