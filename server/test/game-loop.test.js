import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {JSDOM} from 'jsdom';import * as THREE from 'three';

test('actual browser frame keeps the camera behind a smoothly moving server bike',async t=>{
 const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8');
 const script=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(x=>x[1]).find(s=>s.includes('function frame(now)'));
 assert.ok(script);const dom=new JSDOM(html,{runScripts:'outside-only',url:'http://game.test/'}),w=dom.window;t.after(()=>w.close());w.Math.random=()=>.5;
 const ctx=new Proxy({createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),measureText:()=>({width:10}),getImageData:()=>({data:new Uint8ClampedArray(64)})},{get:(o,k)=>k in o?o[k]:(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 w.HTMLCanvasElement.prototype.getContext=()=>ctx;w.matchMedia=()=>({matches:false,addListener(){},removeListener(){}});w.requestAnimationFrame=cb=>{w.__frame=cb};w.fetch=async()=>({ok:false});
 class WebGLRenderer{constructor(){this.shadowMap={};this.capabilities={getMaxAnisotropy:()=>1}}setPixelRatio(){}setSize(){}render(){}}class GLTFLoader{parse(_,__,___,error){error()}}
 w.THREE={...THREE,WebGLRenderer,GLTFLoader};w.eval(readFileSync(new URL('../../race-smoothing.js',import.meta.url),'utf8'));
 const instrumented=script.replace('requestAnimationFrame(frame);\n})();',"window.__state=function(){return {x:pos.x,z:pos.z,cameraX:camera.position.x,cameraZ:camera.position.z,speed:v,steer:steer}};window.__start=startBtn;requestAnimationFrame(frame);\n})();");assert.notEqual(instrumented,script);w.eval(instrumented);await new Promise(r=>setTimeout(r,10));assert.equal(w.__start.disabled,false);
 let now=0;Object.defineProperty(w.performance,'now',{value:()=>now});
 const schedule=[0,130,205,330,405,530,605,730,805,930,1005];let next=0,previous=-1;
 for(now=0;now<=1100;now+=5){
   while(next<schedule.length&&schedule[next]<=now){const tick=next*100;const state={x:0,z:tick*.06,h:0,v:60,steer:0,lean:0,pitch:0,idx:0,total:0,lat:0};w.WMCGame.authoritativeReceive({id:'l',mode:'qualifying_race',phase:'qualifying',phaseStart:100000,serverTime:100000+tick,players:[{id:'a',username:'a',display_name:'Test Rider',number:13,color:'red',grid:1,state,completed:false,dnf:false,attempts:0,best:null,invalid:false,flying:false,lap:1,lapStart:100000,sector:0,line:0}],events:[]},'a',{});next++}
   w.__frame(now);const frame=w.__state();assert.ok(frame.z>=previous-1e-8,'rendered bike went backwards');previous=frame.z;
   const distance=Math.hypot(frame.x-frame.cameraX,frame.z-frame.cameraZ);assert.ok(distance>=5.7&&distance<=6.4,`camera drifted ${distance} metres from bike`);
 }
 // Local controls must affect the rendered bike before another server snapshot arrives.
 const before=w.__state();w.document.body.dispatchEvent(new w.KeyboardEvent('keydown',{code:'KeyA',bubbles:true}));now+=16;w.__frame(now);assert.ok(w.__state().steer>before.steer,'steering should respond without waiting for the server');
});

test('multiplayer music, synchronized countdown and overtakes use real game UI paths',async t=>{
 const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8');
 const script=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(x=>x[1]).find(s=>s.includes('function frame(now)'));
 const dom=new JSDOM(html,{runScripts:'outside-only',url:'http://game.test/'}),w=dom.window;t.after(()=>w.close());let now=0,tones=0,animations=[];
 Object.defineProperty(w.performance,'now',{value:()=>now});
 const param=()=>({value:0,setValueAtTime(){},exponentialRampToValueAtTime(){},setTargetAtTime(){}});
 class AudioContext{constructor(){this.state='suspended';this.destination={}}get currentTime(){return now/1000}resume(){this.state='running';return Promise.resolve()}createOscillator(){return {frequency:param(),connect(){},disconnect(){},start(){tones++},stop(){}}}createGain(){return {gain:param(),connect(){},disconnect(){}}}createBiquadFilter(){return {frequency:param(),connect(){}}}}
 w.AudioContext=AudioContext;const ctx=new Proxy({createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),measureText:()=>({width:10}),getImageData:()=>({data:new Uint8ClampedArray(64)})},{get:(o,k)=>k in o?o[k]:(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 w.HTMLCanvasElement.prototype.getContext=()=>ctx;w.matchMedia=()=>({matches:false,addListener(){},removeListener(){}});w.requestAnimationFrame=cb=>{w.__frame=cb};w.fetch=async()=>({ok:false});
 w.HTMLElement.prototype.getBoundingClientRect=function(){return {top:Number(this.style.order||0)*29}};w.HTMLElement.prototype.animate=function(frames){animations.push({row:this,frames});return {cancel(){}}};
 class WebGLRenderer{constructor(){this.shadowMap={};this.capabilities={getMaxAnisotropy:()=>1}}setPixelRatio(){}setSize(){}render(){}}class GLTFLoader{parse(_,__,___,error){error()}}
 w.THREE={...THREE,WebGLRenderer,GLTFLoader};w.eval(readFileSync(new URL('../../race-smoothing.js',import.meta.url),'utf8'));
 const instrumented=script.replace('requestAnimationFrame(frame);\n})();',"window.__cues=[];var originalCue=playMatchCue;playMatchCue=function(k){window.__cues.push(k);originalCue(k)};requestAnimationFrame(frame);\n})();");w.eval(instrumented);await new Promise(r=>setTimeout(r,10));
 w.document.getElementById('start').dispatchEvent(new w.Event('pointerdown',{bubbles:true}));
 w.document.getElementById('start').click();w.document.getElementById('multiplayerButton').click();now=16;w.__frame(now);
 assert.ok(tones>2,'lobby music should schedule notes after a user gesture');
 const beforeMute=tones;w.document.getElementById('modeSound').click();now+=300;w.__frame(now);assert.equal(tones,beforeMute,'muted music must not schedule more notes');w.document.getElementById('modeSound').click();
 const player=(id,total,grid)=>({id,username:id,display_name:'Rider '+id,number:grid,color:'red',grid,state:{x:0,z:0,h:0,v:0,steer:0,lean:0,pitch:0,idx:0,total,lat:0},completed:false,dnf:false,attempts:0,best:null,invalid:false,flying:false,lap:1,lapStart:104500,sector:0,line:0});
 let raw={id:'l',mode:'race',phase:'race',phaseStart:104500,serverTime:100000,players:[player('a',100,1),player('b',90,2)],events:[]};
 w.WMCGame.authoritativeReceive(raw,'a',{});let own=w.document.getElementById('ownRaceRow'),other=[...w.document.getElementById('raceRoster').children].find(e=>e!==own);assert.equal(own.style.order,'0');
 raw={...raw,players:[player('a',90,1),player('b',110,2)]};w.WMCGame.authoritativeReceive(raw,'a',{});
 assert.equal(own.style.order,'1');assert.equal(other.style.order,'0');assert.equal(animations.length,2,'both riders should animate the overtake');
 w.WMCGame.authoritativeReceive(raw,'a',{});assert.equal(animations.length,2,'unchanged snapshots must not restart the animation');
 for(let i=0;i<95;i++){now+=50;w.__frame(now)}
 assert.ok(w.__cues.filter(c=>c==='tick').length>=4,'race lights should produce countdown sounds');assert.ok(w.__cues.includes('go'),'start must produce a go sound');
 const ticks=w.__cues.filter(c=>c==='tick').length,gos=w.__cues.filter(c=>c==='go').length;
 const qualifying={...raw,mode:'qualifying_race',phase:'qualifying',phaseStart:200000,serverTime:197500};
 w.WMCGame.authoritativeReceive(qualifying,'a',{});
 w.WMCGame.authoritativeReceive({...qualifying,serverTime:198500},'a',{});
 w.WMCGame.authoritativeReceive({...qualifying,serverTime:199500},'a',{});
 w.WMCGame.authoritativeReceive({...qualifying,serverTime:200000},'a',{});
 assert.equal(w.__cues.filter(c=>c==='tick').length-ticks,3,'qualifying intro should count down');assert.equal(w.__cues.filter(c=>c==='go').length-gos,1);
 const a={...player('a',100,1),color:'red',flying:true,lapStart:200000},b={...player('b',120,2),color:'blue',flying:true,lapStart:200000};
 w.WMCGame.authoritativeReceive({...qualifying,serverTime:210000,players:[a,b],events:[]},'a',{});now+=16;w.__frame(now);
 const qualRows=[...w.document.getElementById('qualRoster').children],ownQual=qualRows.find(r=>r.dataset.riderId==='a'),otherQual=qualRows.find(r=>r.dataset.riderId==='b');
 assert.equal(ownQual.querySelector('.qual-stripe').style.backgroundColor,'rgb(228, 32, 44)');assert.equal(otherQual.querySelector('.qual-stripe').style.backgroundColor,'rgb(23, 107, 179)');
 const card=w.document.getElementById('otherQual').firstElementChild;assert.ok(card.querySelector('.other-name').textContent.includes('B'));assert.match(card.querySelector('.other-time').textContent,/0:10\.0/);
 w.WMCGame.authoritativeReceive({...qualifying,serverTime:210100,players:[a,{...b,invalid:true}],events:[{type:'invalid',id:'b',reason:'TRACK LIMITS'}]},'a',{});now+=16;w.__frame(now);assert.equal(card.querySelector('.other-time').textContent,'LAP CANCELLED');
 w.WMCGame.authoritativeReceive({...qualifying,phase:'complete',endReason:'opponent_left',serverTime:210200,players:[a,{...b,dnf:true}],events:[]},'a',{});await new Promise(r=>setTimeout(r,5));assert.equal(w.document.getElementById('sessionEnd').hidden,false);assert.match(w.document.getElementById('sessionResult').textContent,/other rider left/);
});
