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

test('winner graphic is narrower and positioned on the right',()=>{const css=readFileSync(new URL('../../winner-highlight.css',import.meta.url),'utf8');const rule=css.match(/\.winner-card\{([^}]*)\}/)[1];assert.match(rule,/right:max\(4vw,20px\)/);assert.match(rule,/width:min\(28vw,320px,60vh\)/);assert.doesNotMatch(rule,/left:/)});

test('footage records actual drawn frames, retains six seconds, and never substitutes another rider',()=>{
 let serial=0;const source={width:1280,height:720},draws=[];const doc={createElement(){return {width:0,height:0,getContext(){return {drawImage(...args){draws.push(args)}}},toDataURL(){return 'data:image/jpeg;frame='+serial++}}}};
 const r=replay.createFootage(doc);for(let t=0;t<=10000;t+=100)r.record('self',t,source,t===10000);
 const clip=r.clip('self');assert.ok(clip);assert.equal(clip[0].t,4000);assert.equal(clip.at(-1).t,10000);assert.equal(draws.at(-1)[0],source);assert.equal(draws.at(-1)[3],640);assert.equal(draws.at(-1)[4],360);assert.equal(r.clip('other'),null);assert.equal(replay.footageFrame(clip,0),0);assert.equal(replay.footageFrame(clip,1),clip.length-1);const last=clip.at(-1).image;r.record('self',10100,source,true);assert.equal(r.clip('self').at(-1).image,last);r.clear();assert.equal(r.clip('self'),null);
});
test('footage does not stretch incomplete or interrupted recordings into a fake replay',()=>{
 const doc={createElement(){return {getContext(){return {drawImage(){}}},toDataURL(){return 'data:image/jpeg;test'}}}},r=replay.createFootage(doc),source={width:100,height:100};r.record('self',0,source,false);r.record('self',3000,source,true);assert.equal(r.clip('self'),null);r.clear();for(let t=0;t<=3000;t+=100)r.record('self',t,source,false);for(let t=5000;t<=7000;t+=100)r.record('self',t,source,t===7000);assert.equal(r.clip('self'),null);
});

test('a real wheelie segment earlier in the race is kept for the winning replay',()=>{
 let frame=0;const doc={createElement(){return {getContext(){return {drawImage(){}}},toDataURL(){return 'frame-'+frame++}}}},r=replay.createFootage(doc),source={width:100,height:100};for(let t=0;t<=20000;t+=100)r.record('self',t,source,t===20000,t>=8000&&t<9000);const clip=r.clip('self');assert.ok(clip);assert.ok(clip[0].t<=8000&&clip.at(-1).t>=8000);assert.ok(clip.at(-1).t<20000,'wheelie footage survives later racing');
});
