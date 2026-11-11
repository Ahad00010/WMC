import test from 'node:test';import assert from 'node:assert/strict';import {createRequire} from 'node:module';import {RaceRoom} from '../src/race.js';import {getTrack} from '../src/track.js';
const require=createRequire(import.meta.url),contact=require('../../bike-contact.js'),practice=require('../../practice-ai.js');
const state=(x,z,h,v)=>({x,z,h,v});
test('swept rear, head-on and side contact separates bikes and reduces only approaching speed',()=>{
 let a=state(0,6,0,60),b=state(0,4,0,10);assert.equal(contact.resolve(a,b,{x:0,z:0},{x:0,z:4}),true);assert.ok(a.z<b.z,'fast rider cannot tunnel through the bike ahead');assert.ok(a.v<60&&a.v>=0);assert.ok(b.v>10,'the struck bike is pushed forward');assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=contact.length-1e-8);
 a=state(0,5,0,60);b=state(0,1,0,0);assert.equal(contact.resolve(a,b,{x:0,z:0},{x:0,z:1}),true);assert.ok(a.z<b.z,'an initially overlapping bike cannot tunnel through');
 a=state(0,1,0,20);b=state(0,2,Math.PI,20);assert.equal(contact.resolve(a,b,{x:0,z:0},{x:0,z:3}),true);assert.ok(a.v<20&&b.v<20);
 a=state(0,0,Math.PI/2,20);b=state(1,0,0,0);assert.equal(contact.resolve(a,b,{x:-1,z:0},{x:2,z:0}),true);assert.ok(a.v<20);assert.ok(b.pushX>0,'side contact pushes the other bike sideways');
});
test('stationary and separating bikes are not repeatedly slowed or boosted',()=>{
 let a=state(0,0,0,0),b=state(0,1,0,0);assert.equal(contact.resolve(a,b,{...a},{...b}),false);assert.equal(a.v,0);assert.equal(b.v,0);assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=contact.length-1e-8);
 a=state(0,0,Math.PI,10);b=state(0,2,0,10);assert.equal(contact.resolve(a,b,{...a},{...b}),false);assert.equal(a.v,10);assert.equal(b.v,10);
});
test('authoritative room resolves human and AI contact and publishes a correction sequence',()=>{
 const r=new RaceRoom({id:'contact',host_id:'a',mode:'race'});for(const id of ['a','b'])r.join({id,display_name:id,username:id,number:1,color:'red'},0);r.start('a',0);const a=r.players.get('a'),b=r.players.get('b'),track=r.track,i=a.state.idx,h=Math.atan2(track.tx[i],track.tz[i]);
 Object.assign(a.state,{x:track.px[i],z:track.pz[i],h,v:60});Object.assign(b.state,{x:a.state.x+Math.sin(h)*3,z:a.state.z+Math.cos(h)*3,h,v:0,idx:i,total:a.state.total});r.advance(r.phaseStart,1/30);assert.ok(a.state.v<55);assert.ok(Math.hypot(a.state.x-b.state.x,a.state.z-b.state.z)>=contact.length-1e-6);assert.equal(r.snapshot(r.phaseStart).players.find(p=>p.id==='a').state.contactSeq,1);
 b.ai=true;Object.assign(a.state,{x:track.px[i],z:track.pz[i],h,v:50,idx:i});Object.assign(b.state,{x:a.state.x+Math.sin(h)*3,z:a.state.z+Math.cos(h)*3,h,v:0,idx:i});r.advance(r.phaseStart+50,1/30);assert.ok(a.state.contactSeq>1,'human and AI use the same contact');
});
test('practice player collides with an AI rider in race and qualifying',()=>{
 for(const mode of ['race','qualifying']){const track=getTrack('sepang'),session=practice.createPracticeAI(track,mode),bot=session.riders[0],s=bot.state,h=s.h;
 const player=state(s.x-Math.sin(h),s.z-Math.cos(h),h,30),previous={x:player.x-Math.sin(h),z:player.z-Math.cos(h)};session.step(1/60,player,previous);assert.ok(player.v<30,mode);assert.ok(Math.hypot(player.x-s.x,player.z-s.z)>=contact.length-1e-6,mode)}
});
test('riders travelling together do not freeze at the contact plane',()=>{
 const a=state(0,0,0,41),b=state(0,contact.length,0,40);let hits=0;
 for(let i=0;i<120;i++){const pa={...a},pb={...b};a.z+=a.v/60;b.z+=b.v/60;if(contact.resolve(a,b,pa,pb))hits++;assert.ok(a.z<b.z,'bikes remain in order')}
 assert.ok(a.z>75&&b.z>77,'both riders continue moving while touching');assert.ok(hits<10,'nearly matched bikes do not repeatedly trigger hard collision corrections');
});
test('side impacts transfer momentum and drift decays through authoritative physics',async()=>{
 const {createPhysics}=await import('../src/physics.js'),track=getTrack('sepang'),physics=createPhysics(track),a=physics.spawn(1),b=physics.spawn(2);a.x=0;a.z=0;a.h=Math.PI/2;a.v=20;b.x=1.5;b.z=0;b.h=0;b.v=0;contact.resolve(a,b,{x:-.5,z:0},{x:1.5,z:0},1/60);assert.ok(b.pushX>1,'hit bike gains sideways velocity');const before=b.x;physics.step(b,{up:false,down:false,left:false,right:false,brake:false},1/60);assert.ok(b.x>before,'sideways impulse actually moves the hit bike');const initial=b.pushX;for(let i=0;i<120;i++)physics.step(b,{up:false,down:false,left:false,right:false,brake:false},1/60);assert.ok(Math.abs(b.pushX)<Math.abs(initial)*.01,'sideways impulse settles');
});
test('finished multiplayer riders keep moving without changing results while others finish',()=>{
 const r=new RaceRoom({id:'finish',host_id:'a',mode:'race'});for(const id of ['a','b'])r.join({id,display_name:id,username:id,number:1,color:'red'},0);r.start('a',0);const a=r.players.get('a'),b=r.players.get('b'),s=a.state;Object.assign(s,{x:r.track.px[0],z:r.track.pz[0],h:Math.atan2(r.track.tx[0],r.track.tz[0]),v:60,total:r.track.N*3+1,idx:0});a.lap=3;r.advance(r.phaseStart,1/60);assert.equal(a.completed,true);const finish=a.finishAt,start={x:s.x,z:s.z};for(let i=1;i<=240;i++){const now=r.phaseStart+i*1000/60;r.input('a',{up:true,down:false,left:false,right:false,brake:false},now);r.advance(now,1/60)}assert.equal(b.completed,false);assert.equal(a.finishAt,finish);assert.ok(Math.hypot(s.x-start.x,s.z-start.z)>45,'finished rider continues moving instead of being frozen at the line');assert.equal(r.phase,'race');
});
test('bike-shaped contact does not create a magnetic gap beside parallel bikes',()=>{
 const a=state(0,0,0,30),b=state(1.1,0,0,30);a.pushX=2;
 assert.equal(contact.resolve(a,b,{x:-.05,z:0},{x:1.1,z:0},1/60),false,'1.1m apart is not a side impact');assert.equal(a.v,30);assert.equal(b.v,30);assert.equal(a.x,0);assert.equal(b.x,1.1);
 b.x=.85;assert.equal(contact.resolve(a,b,{x:-.05,z:0},{x:.85,z:0},1/60),true,'side impact starts only at the bike width');assert.ok(b.pushX>0);assert.ok(contact.distance(a,b)>=contact.width-1e-5);
});
test('parallel bikes can ride 1m apart while front-to-back contact retains full bike length',()=>{
 for(const h of [0,Math.PI/4,Math.PI/2]){let a=state(0,0,h,25),fx=Math.sin(h),fz=Math.cos(h),b=state(fz,-fx,h,25);assert.equal(contact.resolve(a,b,{...a},{...b},1/60),false);assert.equal(a.v,25);assert.equal(b.v,25);
  b=state(fx*(contact.length+.03),fz*(contact.length+.03),h,0);a.v=35;const before={...a};a.x+=fx*.1;a.z+=fz*.1;assert.equal(contact.resolve(a,b,before,{...b},1/60),true);assert.ok(b.v>0,'bike in front is pushed');assert.ok(contact.distance(a,b)>=contact.width-1e-4);
 }
});
test('fast sideways crossings and diagonal encounters cannot tunnel',()=>{
 let a=state(2,0,0,20),b=state(0,0,0,0);a.pushX=200;assert.equal(contact.resolve(a,b,{x:-2,z:0},{...b},.02),true);assert.ok(a.x<b.x,'the bike cannot tunnel through sideways');assert.ok(b.pushX>0);assert.ok(contact.distance(a,b)>=contact.width-1e-4);
 a=state(2,0,Math.PI/2,100);b=state(0,0,0,0);assert.equal(contact.resolve(a,b,{x:-3,z:0},{...b},.03),true);assert.ok(a.x<b.x);assert.ok(contact.distance(a,b)>=contact.width-1e-4);
});
test('contact dimensions closely match the scaled Ducati model',async()=>{
 const {readFileSync}=await import('node:fs'),bytes=readFileSync(new URL('../../bike-mobile.glb',import.meta.url)),length=bytes.readUInt32LE(12),gltf=JSON.parse(bytes.subarray(20,20+length).toString());
 function meshBounds(name){const node=gltf.nodes.find(n=>n.name===name),primitive=gltf.meshes[node.mesh].primitives[0];return {node,accessor:gltf.accessors[primitive.attributes.POSITION]}}
 const fairing=meshBounds('Object_11').accessor,front=meshBounds('wheel_front'),rear=meshBounds('wheel_rear'),scale=1.15;
 const modelWidth=(fairing.max[0]-fairing.min[0])*scale,modelLength=(front.node.translation[2]+front.accessor.max[2]-rear.node.translation[2]-rear.accessor.min[2])*scale;
 assert.ok(Math.abs(contact.width-modelWidth)<.05,`collision width ${contact.width} should match ${modelWidth.toFixed(3)}m Ducati`);assert.ok(Math.abs(contact.length-modelLength)<.08,`collision length ${contact.length} should match ${modelLength.toFixed(3)}m Ducati`);
});
