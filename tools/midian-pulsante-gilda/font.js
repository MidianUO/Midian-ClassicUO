// font.js: legge i font ASCII di fonts.mul e scrive "Guild" con ognuno (anteprima)
const fs=require('fs');const b=fs.readFileSync('C:/Users/paolo/OneDrive/Desktop/Midian-ClientUo/UO/fonts.mul');let p=0;const F=[];
for(let f=0;f<10;f++){p++;const ch=[];for(let c=0;c<224;c++){const w=b[p],h=b[p+1];p+=3;const px=[];for(let i=0;i<w*h;i++){px.push(b.readUInt16LE(p));p+=2;}ch.push({w,h,px});}F.push(ch);}
module.exports=F;
if(require.main===module){const txt=process.argv[2]||'Guild';const rows=[];
 for(let f=0;f<10;f++){const g=[...txt].map(c=>F[f][c.charCodeAt(0)-32]);const W=g.reduce((a,x)=>a+x.w,0),H=Math.max(...g.map(x=>x.h));rows.push({f,W,H,g});console.log('font',f,W+'x'+H);}
 // ppm
 const S=3,TW=Math.max(...rows.map(r=>r.W))*S+10,TH=rows.reduce((a,r)=>a+r.H*S+6,0);const px=Buffer.alloc(TW*TH*3,30);let y0=0;
 for(const r of rows){let x0=0;for(const gl of r.g){for(let y=0;y<gl.h;y++)for(let x=0;x<gl.w;x++){const c=gl.px[y*gl.w+x];if(!c)continue;for(let a=0;a<S;a++)for(let bb=0;bb<S;bb++){const i=((y0+y*S+a)*TW+x0+x*S+bb)*3;px[i]=((c>>10)&31)<<3;px[i+1]=((c>>5)&31)<<3;px[i+2]=(c&31)<<3;}}x0+=gl.w*S;}y0+=r.H*S+6;}
 fs.writeFileSync('gilda/font.ppm',Buffer.concat([Buffer.from(`P6 ${TW} ${TH} 255\n`),px]));}
