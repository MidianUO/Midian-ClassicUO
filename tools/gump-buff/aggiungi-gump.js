// Aggiunge a Gumpart.mul/Gumpidx.mul di Midian le gump che mancano, prese dal gumpartLegacyMUL.uop di un client nuovo.
// Non tocca le gump che Midian ha gia'. Uso: node aggiungi-gump.js <uop> <idx> <mul> <idx nuovo> <mul nuovo> id...
const fs=require('fs');const u=require('./uop.js');
const [uopF,idxF,mulF,idxOut,mulOut,...ids]=process.argv.slice(2);
const t=u.leggiTabella(uopF);const idx=Buffer.from(fs.readFileSync(idxF));const mul=fs.readFileSync(mulF);
const pezzi=[mul];let fine=mul.length,aggiunte=[],saltate=[],mancanti=[];
for(const s of ids){const id=parseInt(s,16);
 if(idx.readInt32LE(id*12)!==-1&&idx.readInt32LE(id*12+4)>0){saltate.push(s);continue;}
 const g=u.gump(t,id);if(!g){mancanti.push(s);continue;}
 idx.writeInt32LE(fine,id*12);idx.writeInt32LE(g.dati.length,id*12+4);idx.writeInt32LE((g.w<<16)|g.h,id*12+8);
 pezzi.push(g.dati);fine+=g.dati.length;aggiunte.push(s);}
fs.writeFileSync(idxOut,idx);fs.writeFileSync(mulOut,Buffer.concat(pezzi));
console.log('aggiunte',aggiunte.length,'gia\' in Midian',saltate.join(' ')||'-','non trovate',mancanti.join(' ')||'-');
