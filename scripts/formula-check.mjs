import assert from 'node:assert/strict';import '../assets/js/formula-engine.js';
const f=globalThis.WorkshFormula;
assert.equal(f('{Horas} * 50 + 10',name=>name==='Horas'?2:0),110);
assert.equal(f('SUM(1,2,3) / AVG(2,4)',()=>0),2);
assert.equal(f('ROUND((5 + 2) / 2)',()=>0),4);
for(const input of ['window.location','1/0','{x}.constructor','fetch(1)','1;2','(1+2','SUM()'])assert.throws(()=>f(input,()=>0));
console.log('PASS: formulas, references, precedence, functions, invalid input and injection rejection.');
