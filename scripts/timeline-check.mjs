import assert from 'node:assert/strict';import '../assets/js/timeline-layout.js';
const l=globalThis.WorkshTimeline([{start_date:'2026-10-21',due:'2026-10-27'}],'2026-10-23');
assert.equal(l.first,'2026-10-20');assert.equal(l.span,9);assert.equal(l.ticks.length,9);assert.ok(Math.abs(l.referencePct-38.8888888889)<.0001);assert.ok(l.ticks[3].reference);assert.equal(l.ticks[3].label,'23/10');assert.ok(Math.abs(l.bar({start_date:'2026-10-21',due:'2026-10-27'}).width-7/9*100)<.0001);
assert.equal(globalThis.WorkshTimeline([{start_date:'2024-02-28',due:'2024-03-02'}],'2024-02-29').ticks.filter(t=>t.reference).length,1);
assert.equal(l.bar({due:'2026-02-30'}),null);
assert.equal(globalThis.WorkshTimeline([{due:'2020-01-01'}],'2026-10-23').referencePct,null);
assert.ok(globalThis.WorkshTimeline([],'2026-10-23').referencePct>0);
assert.ok(globalThis.WorkshTimeline([{start_date:'2000-01-01',due:'2100-01-01'}],'2026-10-23').ticks.length<=31);
console.log('PASS: exact date/bar/reference alignment, leap dates, invalid dates, off-range reference, empty and long timelines.');
