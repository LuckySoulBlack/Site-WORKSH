'use strict';
// Shared calendar math for the workspace and exported HTML. All day arithmetic is UTC.
globalThis.WorkshTimeline=(tasks,reference)=>{
 const day=value=>{if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return null;const n=Date.parse(value+'T00:00:00Z');return Number.isFinite(n)&&new Date(n).toISOString().slice(0,10)===value?n/86400000:null;};
 const key=n=>new Date(n*86400000).toISOString().slice(0,10),format=(n,options)=>new Date(n*86400000).toLocaleDateString('pt-BR',{...options,timeZone:'UTC'});
 const today=day(reference);if(today===null)throw Error('Data de referência inválida.');
 const dates=tasks.flatMap(t=>[day(t.start_date),day(t.due)]).filter(n=>n!==null),start=dates.length?Math.min(...dates)-1:today-2;
 const span=Math.max(7,(dates.length?Math.max(...dates):today+4)-start+2),step=span<=31?1:span<=180?7:Math.ceil(span/30);
 const ticks=[];for(let offset=0;offset<span;offset+=step){const size=Math.min(step,span-offset),n=start+offset;ticks.push({left:offset/span*100,width:size/span*100,label:format(n,{day:'2-digit',month:'2-digit'}),weekday:step===1?format(n,{weekday:'short'}):'',weekend:step===1&&[0,6].includes(new Date(n*86400000).getUTCDay()),reference:today>=n&&today<n+size});}
 return {start,span,step,ticks,first:key(start),last:key(start+span-1),period:[...new Set([format(start,{month:'long',year:'numeric'}),format(start+span-1,{month:'long',year:'numeric'})])].join(' — '),referenceLabel:format(today,{day:'2-digit',month:'2-digit',year:'numeric'}),referencePct:today>=start&&today<start+span?(today-start+.5)/span*100:null,bar(t){const a=day(t.start_date)??day(t.due),b=day(t.due)??day(t.start_date);return a===null?null:{left:(a-start)/span*100,width:Math.max(.2,(Math.max(a,b)-a+1)/span*100)};}};
};
