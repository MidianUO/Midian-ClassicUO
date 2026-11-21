// cuoci.js: fondo pulito del pulsante (moda di 8 pulsanti del paperdoll) + "Guild" col font ASCII 1 di Midian.
// Scrive gilda/guild-N.argb (64x21, uint32 ARGB little endian) per i 3 stati e un'anteprima.
const fs=require('fs');const D='C:/Users/paolo/OneDrive/Desktop/Midian-ClientUo/UO/';
const idx=fs.readFileSync(D+'Gumpidx.mul'),art=fs.openSync(D+'Gumpart.mul','r');const F=require('./font.js');
function leggi(id){const o=idx.readInt32LE(id*12),len=idx.readInt32LE(id*12+4),ex=idx.readInt32LE(id*12+8);const w=(ex>>16)&0xffff,h=ex&0xffff;
 const b=Buffer.alloc(len);fs.readSync(art,b,0,len,o);const px=new Uint16Array(w*h);
 for(let y=0;y<h;y++){const lo=b.readInt32LE(y*4)*4;const end=y<h-1?b.readInt32LE((y+1)*4)*4:len;let x=0;
  for(let p=lo;p<end&&x<w;p+=4){const c=b.readUInt16LE(p),n=b.readUInt16LE(p+2);for(let k=0;k<n&&x<w;k++,x++)px[y*w+x]=c;}}return {w,h,px};}
const txt=process.argv[2]||'Guild',FONT=+(process.argv[3]||1);const out=[];
for(let s=0;s<3;s++){
 const tutti=[0x7d6,0x7d9,0x7dc,0x7df,0x7e2,0x7e5,0x7e8,0x7eb].map(i=>leggi(i+s));const W=64,H=21;const px=new Uint16Array(W*H);
 for(let i=0;i<W*H;i++){const m=new Map();for(const t of tutti)m.set(t.px[i],(m.get(t.px[i])||0)+1);let best=0,bn=0;for(const [k,v] of m)if(v>bn){bn=v;best=k;}px[i]=best;}
 const g=[...txt].map(c=>F[FONT][c.charCodeAt(0)-32]);const TW=g.reduce((a,x)=>a+x.w,0),TH=Math.max(...g.map(x=>x.h));
 let x0=3+Math.floor((52-TW)/2);const y0=Math.floor((H-TH)/2)+(s===1?1:0);
 for(const gl of g){for(let y=0;y<gl.h;y++)for(let x=0;x<gl.w;x++){let c=gl.px[y*gl.w+x];if(!c)continue;
   if(s===1&&(c&0x7fff)>0x2000){/* premuto: un po' piu' scuro */const r=(c>>10)&31,gg=(c>>5)&31,b=c&31;c=((r*3>>2)<<10)|((gg*3>>2)<<5)|(b*3>>2);}
   if(s===2&&(c&0x7fff)>0x2000){/* sopra: piu' chiaro */const r=Math.min(31,((c>>10)&31)+4),gg=Math.min(31,((c>>5)&31)+4),b=c&31;c=(r<<10)|(gg<<5)|b;}
   px[(y0+y)*W+x0+x]=c;}x0+=gl.w;}
 const a=Buffer.alloc(W*H*4);for(let i=0;i<W*H;i++){const c=px[i];const r=((c>>10)&31)*255/31|0,gg=((c>>5)&31)*255/31|0,b=(c&31)*255/31|0;a.writeUInt32LE(c?((0xff<<24)|(r<<16)|(gg<<8)|b)>>>0:0,i*4);}
 fs.writeFileSync(`gilda/guild-${s}.argb`,a);out.push({w:W,h:H,px});
 const pp=Buffer.alloc(W*H*3);for(let i=0;i<W*H;i++){const c=px[i];pp[i*3]=((c>>10)&31)<<3;pp[i*3+1]=((c>>5)&31)<<3;pp[i*3+2]=(c&31)<<3;}
 fs.writeFileSync(`gilda/guild-${s}.ppm`,Buffer.concat([Buffer.from(`P6 ${W} ${H} 255\n`),pp]));}
console.log('ok');
