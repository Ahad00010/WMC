import test from 'node:test';import assert from 'node:assert/strict';import {createRequire} from 'node:module';import {RaceRoom} from '../src/race.js';import {getTrack} from '../src/track.js';
const require=createRequire(import.meta.url),contact=require('../../bike-contact.js'),practice=require('../../practice-ai.js');
const state=(x,z,h,v)=>({x,z,h,v});
test('swept rear, head-on and side contact separates bikes and reduces only approaching speed',()=>{
 let a=state(0,6,0,60),b=state(0,4,0,10);assert.equal(contact.resolve(a,b,{x:0,z:0},{x:0,z:4}),true);assert.ok(a.z<b.z,'fast rider cannot tunnel through the bike ahead');assert.ok(a.v<60&&a.v>=0);assert.equal(b.v,10);assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=contact.diameter-1e-8);
 a=state(0,5,0,60);b=state(0,1,0,0);assert.equal(contact.resolve(a,b,{x:0,z:0},{x:0,z:1}),true);assert.ok(a.z<b.z,'an initially overlapping bike cannot tunnel through');
 a=state(0,1,0,20);b=state(0,2,Math.PI,20);assert.equal(contact.resolve(a,b,{x:0,z:0},{x:0,z:3}),true);assert.ok(a.v<20&&b.v<20);
 a=state(0,0,Math.PI/2,20);b=state(1,0,0,0);assert.equal(contact.resolve(a,b,{x:-1,z:0},{x:2,z:0}),true);assert.ok(a.v<20);assert.equal(b.v,0);
});
test('stationary and separating bikes are not repeatedly slowed or boosted',()=>{
 let a=state(0,0,0,0),b=state(0,1,0,0);assert.equal(contact.resolve(a,b,{...a},{...b}),false);assert.equal(a.v,0);assert.equal(b.v,0);assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=contact.diameter-1e-8);
 a=state(0,0,Math.PI,10);b=state(0,2,0,10);assert.equal(contact.resolve(a,b,{...a},{...b}),false);assert.equal(a.v,10);assert.equal(b.v,10);
});
test('authoritative room resolves human and AI contact and publishes a correction sequence',()=>{
 const r=new RaceRoom({id:'contact',host_id:'a',mode:'race'});for(const id of ['a','b'])r.join({id,display_name:id,username:id,number:1,color:'red'},0);r.start('a',0);const a=r.players.get('a'),b=r.players.get('b'),track=r.track,i=a.state.idx,h=Math.atan2(track.tx[i],track.tz[i]);
 Object.assign(a.state,{x:track.px[i],z:track.pz[i],h,v:60});Object.assign(b.state,{x:a.state.x+Math.sin(h)*3,z:a.state.z+Math.cos(h)*3,h,v:0,idx:i,total:a.state.total});r.advance(r.phaseStart,1/30);assert.ok(a.state.v<55);assert.ok(Math.hypot(a.state.x-b.state.x,a.state.z-b.state.z)>=contact.diameter-1e-6);assert.equal(r.snapshot(r.phaseStart).players.find(p=>p.id==='a').state.contactSeq,1);
 b.ai=true;Object.assign(a.state,{x:track.px[i],z:track.pz[i],h,v:50,idx:i});Object.assign(b.state,{x:a.state.x+Math.sin(h)*3,z:a.state.z+Math.cos(h)*3,h,v:0,idx:i});r.advance(r.phaseStart+50,1/30);assert.ok(a.state.contactSeq>1,'human and AI use the same contact');
});
test('practice player collides with an AI rider in race and qualifying',()=>{
 for(const mode of ['race','qualifying']){const track=getTrack('sepang'),session=practice.createPracticeAI(track,mode),bot=session.riders[0],s=bot.state,h=s.h;
 const player=state(s.x-Math.sin(h),s.z-Math.cos(h),h,30),previous={x:player.x-Math.sin(h),z:player.z-Math.cos(h)};session.step(1/60,player,previous);assert.ok(player.v<30,mode);assert.ok(Math.hypot(player.x-s.x,player.z-s.z)>=contact.diameter-1e-6,mode)}
});
test('riders travelling together do not freeze at the contact plane',()=>{
 const a=state(0,0,0,41),b=state(0,contact.diameter,0,40);let hits=0;
 for(let i=0;i<120;i++){const pa={...a},pb={...b};a.z+=a.v/60;b.z+=b.v/60;if(contact.resolve(a,b,pa,pb))hits++;assert.ok(a.z<b.z,'bikes remain in order')}
 assert.ok(a.z>75&&b.z>77,'both riders continue moving while touching');assert.ok(hits<10,'nearly matched bikes do not repeatedly trigger hard collision corrections');
});
