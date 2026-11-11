import test from 'node:test';import assert from 'node:assert/strict';import {createRequire} from 'node:module';import {readFileSync} from 'node:fs';import {JSDOM} from 'jsdom';
const replay=createRequire(import.meta.url)('../../winner-replay.js');
test('each race rider retains only their real finishing motion, not movement after finish',()=>{
 const r=replay.create();for(let t=0;t<=10000;t+=100){r.record('a',t,{x:t/1000,z:3,h:0,v:1},t===8000);r.record('b',t,{x:t/500,z:4,h:0,v:2},t===10000)}
 const a=r.clip('a'),b=r.clip('b');assert.ok(a.length<=62&&b.length<=62);assert.equal(a.at(-1).t,8000);assert.equal(b.at(-1).t,10000);assert.equal(replay.sample(a,1).x,8);assert.equal(replay.sample(a,0).x,2);r.clear();assert.equal(r.clip('a'),null);
});
test('replay interpolates angles over the short arc and avoids fabricating missing segments',()=>{
 const r=replay.create();r.record('a',0,{x:0,z:0,h:Math.PI-.1});r.record('a',100,{x:10,z:0,h:-Math.PI+.1},true);const middle=replay.sample(r.clip('a'),.5);assert.equal(middle.x,5);assert.ok(Math.abs(Math.abs(middle.h)-Math.PI)<.001);
 const r2=replay.create();r2.record('b',0,{x:0,z:0,h:0});r2.record('b',5000,{x:50,z:0,h:0},true);assert.equal(r2.clip('b'),null);r2.clear();r2.record('x',0,{x:NaN,z:0,h:0});assert.equal(r2.clip('x'),null);
});
test('winner graphic uses real name and number safely and omits championship box',()=>{
 const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8'),dom=new JSDOM(html),doc=dom.window.document,card=doc.getElementById('winnerCard');assert.match(card.textContent,/RACE WINNER/);assert.match(card.textContent,/WMC Grand Prix Team/);assert.match(card.textContent,/\+25/);assert.doesNotMatch(card.textContent,/CHAMPIONSHIP/);assert.match(card.querySelector('img').getAttribute('src'),/tissot-reference/);assert.ok(doc.getElementById('winnerMenu'));dom.window.close();
});
