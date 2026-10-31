function installDeviceControls(){
 const banner=document.querySelector('.preview-banner'),tag=banner.querySelector('span');tag.textContent='连接设备中';
 const panel=document.createElement('section');panel.className='panel device-status';panel.innerHTML='<div class="device-summary"><strong>设备状态</strong><span id="deviceConnection">查询中</span></div><p id="deviceTask">尚未读取任务</p>';
 document.querySelector('nav').after(panel);
 const transfer=document.createElement('label');transfer.innerHTML='回传方式 <select id="transferMode"><option value="auto">JPEG 快速回传（推荐）</option><option value="cache">稳定续传（先缓存）</option></select>';panel.append(transfer);
 const transferMode=transfer.querySelector('select');transferMode.value=Ti60Transfer.mode;transferMode.onchange=()=>Ti60Transfer.setMode(transferMode.value);
 const transferNote=document.createElement('small');transferNote.textContent='直接回传；中断时可续传，任务保留。';panel.append(transferNote);
 let diag=document.getElementById('diagnostics'),button=document.getElementById('readDiagnostics');
 if(!diag){const details=document.createElement('details');details.className='panel device-diagnostics';details.innerHTML='<summary>设备诊断</summary><div class="toolbar"><button id="readDiagnostics">刷新诊断</button><button id="exportDiagnostics">保存诊断</button></div><pre id="diagnostics">等待查询</pre>';(document.querySelector('.workspace article')||document.body).append(details);diag=details.querySelector('pre');button=details.querySelector('#readDiagnostics')}
 if(!document.getElementById('exportDiagnostics')){const b=document.createElement('button');b.id='exportDiagnostics';b.textContent='保存诊断';button.after(b)}
 const loadDiag=async()=>{const data={browser:location.pathname==='/focus'?{mode:'focus',...(window.Ti60Preview||{})}:{...Ti60Task.saved,diagnostics:undefined,lastTransfer:window.Ti60LastTransfer}};for(const [k,u] of [['device','/api/device/diagnostics'],['board','/api/status'],['frame','/api/student/frame/status'],['transport','/api/transport/status'],['preview','/api/preview/status']])try{data[k]=await Ti60Transfer.json(u,{})}catch(e){data[k]={unavailable:e.message}}diag.textContent=JSON.stringify(data,null,2);Ti60Task.diagnostics(data)};
 button.onclick=loadDiag;
 document.getElementById('exportDiagnostics').onclick=()=>{const b=new Blob([diag.textContent],{type:'application/json'}),a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='ti60-diagnostics-'+Date.now()+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};
 if(location.pathname!=='/focus'&&Ti60Task.saved.diagnostics)diag.textContent=JSON.stringify(Ti60Task.saved.diagnostics,null,2);
 let polling=false,noticed=false;
 const poll=async()=>{
  if(polling||window.TI60_OFFLINE||Ti60Transfer.busy||window.Ti60Preview?.engaged)return;polling=true;
  try{
   const s=await Ti60Transfer.json('/api/status',{});tag.textContent=s.firmware||'设备已连接';document.getElementById('deviceConnection').textContent=s.id===96?'FPGA 已连接':'FPGA 通信异常';
   const f=await Ti60Transfer.json('/api/student/frame/status',{}),same=Ti60Task.saved.cookie&&f.cookie===Ti60Task.saved.cookie;
   if(same||(Ti60Task.saved.request&&Ti60Task.saved.request===f.request))Ti60Task.bind(f);
   const preview=await Ti60Transfer.json('/api/preview/status',{});
   document.getElementById('deviceTask').textContent=preview.active?'调焦预览占用 · 退出后可处理图像':f.busy?'模型计算中 · 指令 '+f.command+'/'+f.commands_total:f.done?'FPGA 计算完成 · 任务 '+f.job_id+' · 可继续读取':'设备空闲';
   if(!noticed&&f.cookie&&(f.done||f.busy)){noticed=true;if(document.getElementById('attach')&&Ti60Task.saved.cookie===f.cookie&&!processing){statusEl.textContent='已找到保留任务 '+f.job_id+'；点击“继续读取”恢复，不会重新计算'}}
  }catch(e){tag.textContent='连接暂时中断';document.getElementById('deviceConnection').textContent='任务记录保留';Ti60Task.error(e)}finally{polling=false}
 };
 poll();setInterval(()=>{if(!document.hidden)poll()},3000);window.addEventListener('online',poll);document.addEventListener('visibilitychange',()=>{if(!document.hidden)poll()});
 if(window.TI60_OFFLINE){tag.textContent='电脑离线预览';document.getElementById('deviceConnection').textContent='未连接设备';const ids=['run','process','capture','freeze','resume','camera720','camera1080','attach','stop','restore'];const nodes=ids.map(id=>document.getElementById(id)).filter(Boolean);const guard=()=>nodes.forEach(n=>{if(!n.disabled)n.disabled=true});guard();new MutationObserver(guard).observe(document.body,{attributes:true,subtree:true,attributeFilter:['disabled']})}
}
