/* Validate the FPGA's baseline JPEG entropy stream, without IDCT or re-encoding.
 * Browsers may silently fill a damaged JPEG with grey even when decode succeeds.
 * CRC covers transport bytes; it does not prove that the encoder completed MCUs.
 */
(()=>{
 function validate(b,expected){
  const bad=reason=>{const e=Error('JPEG 内容不完整：'+reason);e.code='JPEG_CONTENT';throw e;};
  if(b.length<4||b[0]!==255||b[1]!==216)bad('SOI');
  let p=2,frame=null,scan=null,restart=0;const huff=[[],[]];
  const word=i=>(b[i]<<8)|b[i+1];
  while(p<b.length&&!scan){
   if(b[p++]!==255)bad('标记');while(b[p]===255)p++;const m=b[p++];
   if(m===217||m===0||m===216)bad('扫描头缺失');
   const length=word(p),end=p+length;if(length<2||end>b.length)bad('标记长度');p+=2;
   if(m===192){
    const count=b[p+5],height=word(p+1),width=word(p+3);if(b[p]!==8||![1,3].includes(count)||length!==8+3*count||!width||!height)bad('帧头');
    const components=[];for(let i=0;i<count;i++){const id=b[p+6+3*i],f=b[p+7+3*i],x=f>>4,y=f&15;if(!x||!y||x>2||y>2||components.some(c=>c.id===id))bad('采样');components.push({id,x,y});}
    frame={width,height,components};
   }else if(m===196){
    while(p<end){
     const info=b[p++],kind=info>>4,id=info&15;if(kind>1||id>3||p+16>end)bad('Huffman 表');
     const min=new Int32Array(17),max=new Int32Array(17),offset=new Int32Array(17);max.fill(-1);let code=0,total=0;
     for(let len=1;len<=16;len++){const count=b[p++];min[len]=code;max[len]=count?code+count-1:-1;offset[len]=total;total+=count;code=(code+count)*2;if(code>2**(len+1))bad('Huffman 码长');}
     if(!total||total>256||p+total>end)bad('Huffman 符号');huff[kind][id]={min,max,offset,values:b.subarray(p,p+total)};p+=total;
    }
   }else if(m===221){if(length!==4)bad('重启间隔');restart=word(p);}
   else if(m===218){
    if(!frame)bad('帧头缺失');const count=b[p++];if(count!==frame.components.length||length!==6+2*count)bad('扫描组件');
    scan=[];for(let i=0;i<count;i++){const id=b[p++],tables=b[p++],c=frame.components.find(v=>v.id===id);if(!c||scan.some(v=>v.id===id)||!huff[0][tables>>4]||!huff[1][tables&15])bad('扫描表');scan.push({...c,dc:huff[0][tables>>4],ac:huff[1][tables&15]});}
    if(b[p]!==0||b[p+1]!==63||b[p+2]!==0)bad('非基线扫描');
   }else if(m>=193&&m<=207&&![196,200,204].includes(m))bad('非基线 JPEG');
   p=end;
  }
  if(!frame||!scan)bad('无图像数据');
  if(expected?.width&&(frame.width!==expected.width||frame.height!==expected.height))bad('尺寸与任务不一致');
  let bits=0,byte=0;
  function bit(){if(!bits){if(p>=b.length)bad('熵数据截断');byte=b[p++];if(byte===255){if(b[p++]!==0)bad('MCU 未完成即遇到标记');}bits=8;}return (byte>>--bits)&1;}
  function symbol(t){let code=0;for(let len=1;len<=16;len++){code=code*2+bit();if(t.max[len]>=0&&code<=t.max[len]&&code>=t.min[len])return t.values[t.offset[len]+code-t.min[len]];}bad('无效 Huffman 码');}
  const maxX=Math.max(...scan.map(c=>c.x)),maxY=Math.max(...scan.map(c=>c.y)),mcus=Math.ceil(frame.width/(8*maxX))*Math.ceil(frame.height/(8*maxY));
  let rst=0;
  for(let mcu=0;mcu<mcus;mcu++){
   if(restart&&mcu&&mcu%restart===0){bits=0;if(b[p++]!==255)bad('重启标记');while(b[p]===255)p++;if(b[p++]!==208+(rst++&7))bad('重启序号');}
   for(const c of scan)for(let block=0;block<c.x*c.y;block++){
    const dc=symbol(c.dc);if(dc>11)bad('DC 长度');for(let i=0;i<dc;i++)bit();
    let k=1;while(k<64){const ac=symbol(c.ac),run=ac>>4,size=ac&15;if(!size){if(!run)break;if(run!==15||k+16>64)bad('AC 零游程');k+=16;continue;}if(size>10||k+run>=64)bad('AC 长度');k+=run;for(let i=0;i<size;i++)bit();k++;}
   }
  }
  // FPGA entropy words may have up to three fill bytes before EOI, followed
  // by at most 80 FF bytes (16-byte alignment plus the small-image decoder drain) for the DDR write beat. Do not decode those as MCUs.
  let end=b.length;while(end>2&&b[end-1]===255&&b.length-end<80)end--;
  if(b[end-2]!==255||b[end-1]!==217||p>end-2||end-2-p>8)bad('EOI 或尾部长度');
  return {width:frame.width,height:frame.height,mcus};
 }
 const api={validate};if(typeof module!=='undefined')module.exports=api;if(typeof window!=='undefined')window.Ti60Jpeg=api;
})();
