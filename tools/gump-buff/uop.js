// Lettore di gumpartLegacyMUL.uop: elenco id -> {off, len (compresso), dlen, flag}
const fs=require('fs'),zlib=require('zlib');
function hash(s){let eax,ecx,edx,ebx,esi,edi;eax=ecx=edx=0;ebx=edi=esi=(s.length+0xDEADBEEF)>>>0;let i=0;
for(;i+12<s.length;i+=12){edi=(((s.charCodeAt(i+7)<<24)|(s.charCodeAt(i+6)<<16)|(s.charCodeAt(i+5)<<8)|s.charCodeAt(i+4))+edi)>>>0;esi=(((s.charCodeAt(i+11)<<24)|(s.charCodeAt(i+10)<<16)|(s.charCodeAt(i+9)<<8)|s.charCodeAt(i+8))+esi)>>>0;edx=(((s.charCodeAt(i+3)<<24)|(s.charCodeAt(i+2)<<16)|(s.charCodeAt(i+1)<<8)|s.charCodeAt(i))-esi)>>>0;
edx=((edx+ebx)^(esi>>>28)^(esi<<4))>>>0;esi=(esi+edi)>>>0;edi=((edi-edx)^(edx>>>26)^(edx<<6))>>>0;edx=(edx+esi)>>>0;esi=((esi-edi)^(edi>>>24)^(edi<<8))>>>0;edi=(edi+edx)>>>0;ebx=((edx-esi)^(esi>>>16)^(esi<<16))>>>0;esi=(esi+edi)>>>0;edi=((edi-ebx)^(ebx>>>13)^(ebx<<19))>>>0;ebx=(ebx+esi)>>>0;esi=((esi-edi)^(edi>>>28)^(edi<<4))>>>0;edi=(edi+ebx)>>>0;}
if(s.length-i>0){switch(s.length-i){case 12:esi=(esi+(s.charCodeAt(i+11)<<24))>>>0;case 11:esi=(esi+(s.charCodeAt(i+10)<<16))>>>0;case 10:esi=(esi+(s.charCodeAt(i+9)<<8))>>>0;case 9:esi=(esi+s.charCodeAt(i+8))>>>0;case 8:edi=(edi+(s.charCodeAt(i+7)<<24))>>>0;case 7:edi=(edi+(s.charCodeAt(i+6)<<16))>>>0;case 6:edi=(edi+(s.charCodeAt(i+5)<<8))>>>0;case 5:edi=(edi+s.charCodeAt(i+4))>>>0;case 4:ebx=(ebx+(s.charCodeAt(i+3)<<24))>>>0;case 3:ebx=(ebx+(s.charCodeAt(i+2)<<16))>>>0;case 2:ebx=(ebx+(s.charCodeAt(i+1)<<8))>>>0;case 1:ebx=(ebx+s.charCodeAt(i))>>>0;}
esi=((esi^edi)-((edi>>>18)^(edi<<14)))>>>0;ecx=((esi^ebx)-((esi>>>21)^(esi<<11)))>>>0;edi=((edi^ecx)-((ecx>>>7)^(ecx<<25)))>>>0;esi=((esi^edi)-((edi>>>16)^(edi<<16)))>>>0;edx=((esi^ecx)-((esi>>>28)^(esi<<4)))>>>0;edi=((edi^edx)-((edx>>>18)^(edx<<14)))>>>0;eax=((esi^edi)-((edi>>>8)^(edi<<24)))>>>0;return (BigInt(edi)<<32n)|BigInt(eax);}
return (BigInt(esi)<<32n)|BigInt(eax);}
function apri(f){const fd=fs.openSync(f,'r');const h=Buffer.alloc(28);fs.readSync(fd,h,0,28,0);let next=h.readBigUInt64LE(12);const tab=new Map();
while(next>0n){const b=Buffer.alloc(12);fs.readSync(fd,b,0,12,Number(next));const n=b.readInt32LE(0);next=b.readBigUInt64LE(4);const e=Buffer.alloc(n*34);fs.readSync(fd,e,0,n*34,Number(next?0:0)+Number(BigInt(0))+0);}
return {fd,tab};}
function leggiTabella(f){const fd=fs.openSync(f,'r');const h=Buffer.alloc(28);fs.readSync(fd,h,0,28,0);let next=Number(h.readBigUInt64LE(12));const tab=new Map();
while(next>0){const b=Buffer.alloc(12);fs.readSync(fd,b,0,12,next);const n=b.readInt32LE(0);const nn=Number(b.readBigUInt64LE(4));const e=Buffer.alloc(n*34);fs.readSync(fd,e,0,n*34,next+12);
for(let k=0;k<n;k++){const o=k*34;const off=Number(e.readBigInt64LE(o));if(!off)continue;const hl=e.readInt32LE(o+8),cl=e.readInt32LE(o+12),dl=e.readInt32LE(o+16),hs=e.readBigUInt64LE(o+20),fl=e.readInt16LE(o+32);tab.set(hs,{off:off+hl,cl,dl,fl});}next=nn;}
return {fd,tab};}
function gump(u,id){const t=u.tab.get(hash(`build/gumpartlegacymul/${String(id).padStart(8,'0')}.tga`));if(!t)return null;let b=Buffer.alloc(t.cl);fs.readSync(u.fd,b,0,t.cl,t.off);if(t.fl===1)b=zlib.inflateSync(b);
const w=b.readInt32LE(0),h=b.readInt32LE(4);return {w,h,dati:b.subarray(8)};}
module.exports={leggiTabella,gump,hash};
if(require.main===module){const u=leggiTabella(process.argv[2]);console.log('voci',u.tab.size);for(const s of process.argv.slice(3)){const g=gump(u,parseInt(s,16));console.log(s,g?g.w+'x'+g.h+' '+g.dati.length:'no');}}
