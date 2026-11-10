import test from 'node:test';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
const {create}=createRequire(import.meta.url)('../../menu-music.js');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fakeAudio(allowed){return {paused:true,volume:0,muted:false,attempts:0,allow:allowed,play(){this.attempts++;if(!this.allow)return Promise.reject(Error('blocked'));this.paused=false;return Promise.resolve()},pause(){this.paused=true}}}
test('autoplay rejection waits for a user gesture and does not retry every frame',async()=>{
 const audio=fakeAudio(false),prompts=[],music=create(audio,v=>prompts.push(v));music.tick(0,true,false);await flush();assert.equal(audio.attempts,1);assert.deepEqual(prompts,[true]);
 for(let i=1;i<30;i++)music.tick(i*16,true,false);assert.equal(audio.attempts,1);audio.allow=true;music.unlock();await flush();assert.equal(audio.paused,false);assert.equal(music.hasStarted(),true);assert.equal(prompts.at(-1),false);assert.equal(audio.loop,true);
});
test('track fades into menus and out for sessions, mutes and resumes on return',async()=>{
 const audio=fakeAudio(true),music=create(audio);music.tick(0,true,false);await flush();for(let t=100;t<=1000;t+=100)music.tick(t,true,false);assert.ok(Math.abs(audio.volume-.55)<.001);assert.equal(audio.paused,false);
 music.tick(1100,true,true);assert.equal(audio.muted,true);music.tick(1200,true,false);assert.equal(audio.muted,false);
 let before=audio.volume;music.tick(1300,false,false);assert.ok(audio.volume<before&&audio.volume>0);for(let t=1400;t<=2300;t+=100)music.tick(t,false,false);assert.equal(audio.volume,0);assert.equal(audio.paused,true);
 music.tick(2400,true,false);await flush();assert.equal(audio.paused,false);for(let t=2500;t<=3400;t+=100)music.tick(t,true,false);assert.ok(audio.volume>.5);
});
test('late autoplay completion is paused if a race starts while it is pending',async()=>{
 let resolve;const audio={paused:true,volume:0,play(){return new Promise(r=>{resolve=()=>{this.paused=false;r()}})},pause(){this.paused=true}};const music=create(audio);music.tick(0,true,false);music.tick(100,false,false);resolve();await flush();assert.equal(audio.paused,true);
});
