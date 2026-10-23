'use strict';
// Arithmetic parser: never interprets JavaScript or accesses global objects.
globalThis.WorkshFormula=(expression,resolve)=>{
 if(typeof expression!=='string'||expression.length>500)throw Error('Fórmula inválida');
 const tokens=[];let rest=expression;
 while(rest.trim()){
  const m=/^\s*(\d+(?:\.\d+)?|\{[^{}]{1,100}\}|[A-Z]+|[()+*/,\-])/.exec(rest);
  if(!m)throw Error('Símbolo inválido');tokens.push(m[1]);rest=rest.slice(m[0].length);
 }
 let i=0,depth=0;
 const numeric=v=>{if(typeof v==='object'||typeof v==='boolean')throw Error('Use uma coluna numérica');const n=Number(v??0);if(!Number.isFinite(n))throw Error('Valor não numérico');return n;};
 function primary(){if(++depth>40)throw Error('Fórmula muito complexa');let value,t=tokens[i++];
  if(t==='-')value=-primary();
  else if(t==='('){value=add();if(tokens[i++]!==')')throw Error('Feche os parênteses');}
  else if(t?.startsWith('{'))value=numeric(resolve(t.slice(1,-1)));
  else if(/^\d/.test(t||''))value=Number(t);
  else if(['SUM','AVG','MIN','MAX','ROUND'].includes(t)){
   if(tokens[i++]!=='(')throw Error('Função inválida');const args=[add()];while(tokens[i]===','){i++;args.push(add());}if(tokens[i++]!==')')throw Error('Feche os parênteses');
   value=t==='SUM'?args.reduce((a,b)=>a+b,0):t==='AVG'?args.reduce((a,b)=>a+b,0)/args.length:t==='MIN'?Math.min(...args):t==='MAX'?Math.max(...args):Math.round(args[0]);
  }else throw Error('Expressão incompleta');depth--;return value;
 }
 function multiply(){let n=primary();while(tokens[i]==='*'||tokens[i]==='/'){const op=tokens[i++],v=primary();if(op==='/'&&v===0)throw Error('Divisão por zero');n=op==='*'?n*v:n/v;}return n;}
 function add(){let n=multiply();while(tokens[i]==='+'||tokens[i]==='-'){const op=tokens[i++],v=multiply();n=op==='+'?n+v:n-v;}return n;}
 const value=add();if(i!==tokens.length||!Number.isFinite(value))throw Error('Fórmula inválida');return value;
};
