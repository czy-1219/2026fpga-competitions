/* Only the validated 64x64 mask is refined; RGB and FPGA inference stay intact. */
(()=>{
 function refine(input,w=64,h=64,mode='clean'){
  if(input.length!==w*h)throw Error('人像掩码尺寸错误');
  if(!['raw','clean','strong'].includes(mode))throw Error('人像收尾模式错误');
  const n=w*h,a=Float32Array.from(input,v=>Number.isFinite(v)?Math.max(0,Math.min(1,v)):0);
  if(mode==='raw')return a;
  const low=mode==='strong'?.50:.32,high=mode==='strong'?.80:.70;
  const labels=new Int32Array(n),queue=new Int32Array(n),sizes=[0];
  function neighbors(i,visit){const x=i%w,y=(i/w)|0;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const xx=x+dx,yy=y+dy;if((dx||dy)&&xx>=0&&xx<w&&yy>=0&&yy<h)visit(yy*w+xx);}}
  for(let i=0;i<n;i++)if(a[i]>=high&&!labels[i]){
   const id=sizes.length;let head=0,tail=1;queue[0]=i;labels[i]=id;
   while(head<tail)neighbors(queue[head++],j=>{if(a[j]>=high&&!labels[j]){labels[j]=id;queue[tail++]=j;}});
   sizes.push(tail);
  }
  let largest=0;for(const size of sizes)largest=Math.max(largest,size);
  // No confident subject: keep the original mask instead of inventing an empty result.
  if(largest<4)return a;
  const minCore=Math.max(4,Math.ceil(largest*.02)),keep=new Uint8Array(n);let head=0,tail=0;
  for(let i=0;i<n;i++)if(labels[i]&&sizes[labels[i]]>=minCore){queue[tail++]=i;keep[i]=1;}
  while(head<tail)neighbors(queue[head++],j=>{if(!keep[j]&&a[j]>=low){keep[j]=1;queue[tail++]=j;}});
  for(let i=0;i<n;i++)a[i]=keep[i]?Math.max(0,(a[i]-low)/(1-low)):0;
  return a;
 }
 const api={refine};if(typeof module!=='undefined')module.exports=api;
 if(typeof window!=='undefined')window.Ti60Portrait=api;
})();
