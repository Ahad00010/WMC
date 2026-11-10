import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {JSDOM} from 'jsdom';import * as THREE from 'three';

test('actual browser frame keeps the camera behind a smoothly moving server bike',async t=>{
 const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8');
 const script=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(x=>x[1]).find(s=>s.includes('function frame(now)'));
 assert.ok(script);const dom=new JSDOM(html,{runScripts:'outside-only',url:'http://game.test/'}),w=dom.window;t.after(()=>w.close());
 const ctx=new Proxy({createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),measureText:()=>({width:10}),getImageData:()=>({data:new Uint8ClampedArray(64)})},{get:(o,k)=>k in o?o[k]:(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 w.HTMLCanvasElement.prototype.getContext=()=>ctx;w.matchMedia=()=>({matches:false,addListener(){},removeListener(){}});w.requestAnimationFrame=cb=>{w.__frame=cb};w.fetch=async()=>({ok:false});
 class WebGLRenderer{constructor(){this.shadowMap={};this.capabilities={getMaxAnisotropy:()=>1}}setPixelRatio(){}setSize(){}render(){}}class GLTFLoader{parse(_,__,___,error){error()}}
 w.THREE={...THREE,WebGLRenderer,GLTFLoader};w.eval(readFileSync(new URL('../../race-smoothing.js',import.meta.url),'utf8'));
 const instrumented=script.replace('requestAnimationFrame(frame);\n})();',"window.__state=function(){return {x:pos.x,z:pos.z,cameraX:camera.position.x,cameraZ:camera.position.z,speed:v}};window.__start=startBtn;requestAnimationFrame(frame);\n})();");assert.notEqual(instrumented,script);w.eval(instrumented);await new Promise(r=>setTimeout(r,10));assert.equal(w.__start.disabled,false);
 let now=0;Object.defineProperty(w.performance,'now',{value:()=>now});
 const schedule=[0,130,205,330,405,530,605,730,805,930,1005];let next=0,previous=-1;
 for(now=0;now<=1100;now+=5){
   while(next<schedule.length&&schedule[next]<=now){const tick=next*100;const state={x:0,z:tick*.06,h:0,v:60,steer:0,lean:0,pitch:0,idx:0,total:0,lat:0};w.WMCGame.authoritativeReceive({id:'l',mode:'qualifying_race',phase:'qualifying',phaseStart:100000,serverTime:100000+tick,players:[{id:'a',username:'a',display_name:'Test Rider',number:13,color:'red',grid:1,state,completed:false,dnf:false,attempts:0,best:null,invalid:false,flying:false,lap:1,lapStart:100000,sector:0,line:0}],events:[]},'a',{});next++}
   w.__frame(now);const frame=w.__state();assert.ok(frame.z>=previous-1e-8,'rendered bike went backwards');previous=frame.z;
   const distance=Math.hypot(frame.x-frame.cameraX,frame.z-frame.cameraZ);assert.ok(distance>=5.7&&distance<=6.4,`camera drifted ${distance} metres from bike`);
 }
});
