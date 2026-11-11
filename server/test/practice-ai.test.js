import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {getTrack} from '../src/track.js';
import {createAI} from '../src/ai.js';
import {createPhysics} from '../src/physics.js';
const practice=createRequire(import.meta.url)('../../practice-ai.js');
test('practice riders use the same physics and AI controls as the authoritative server',()=>{
 for(const id of ['sepang','assen','jerez','silverstone','brno','monza']){
  const track=getTrack(id),server=createPhysics(track),offline=practice.createPhysics(track),ai=createAI(track),localAI=practice.createAI(track),a=server.spawn(2),b=offline.spawn(2);
  assert.deepEqual(a,b);for(let i=0;i<600;i++){const input=ai(a,0);assert.deepEqual(localAI(b,0),input);assert.deepEqual(offline.step(b,input,1/60),server.step(a,input,1/60));assert.deepEqual(a,b)}
 }
});
test('practice creates nine real AI riders with movement and finite timing',()=>{
 const track=getTrack('sepang');for(const mode of ['race','qualifying']){
  const session=practice.createPracticeAI(track,mode);assert.equal(session.riders.length,9);assert.deepEqual(session.riders.map(r=>r.grid),[2,3,4,5,6,7,8,9,10]);const initial=session.riders.map(r=>r.state.total);for(let n=0;n<600;n++)session.step(1/60);assert.ok(session.riders.every((r,i)=>r.state.total>initial[i]&&Number.isFinite(r.state.x)));assert.ok(session.riders.every(r=>r.best===null||Number.isFinite(r.best)));
 }
});

test('practice AI completes a real three-lap race and invalid qualifying laps do not set a best',()=>{
 const track=getTrack('sepang'),race=practice.createPracticeAI(track,'race'),qual=practice.createPracticeAI(track,'qualifying');
 for(let i=0;i<1800;i++){race.step(1/60);qual.step(1/60)}assert.ok(qual.riders.every(r=>r.flying));qual.riders.forEach(r=>{r.invalid=true});
 while(qual.riders.some(r=>r.attempts<1))qual.step(1/60);
 assert.ok(qual.riders.every(r=>r.best===null),'invalid attempts cannot produce a best lap');
 for(let i=0;i<36000;i++){race.step(1/60);qual.step(1/60)}
 assert.ok(race.riders.every(r=>r.completed&&r.lap===4&&Number.isFinite(r.finish_at)));
 assert.ok(qual.riders.every(r=>r.completed&&r.attempts<=3&&r.best!==null));
});

test('practice AI respects one and ten lap race limits',()=>{
 const track=getTrack('sepang');for(const laps of [1,10]){const session=practice.createPracticeAI(track,'race',laps),r=session.riders[0];
  if(laps>1){r.lap=laps-1;r.state.total=(laps-1)*track.N;r.state.v=5;session.step(1/60);assert.equal(r.completed,false);assert.equal(r.lap,laps)}
  r.lap=laps;r.state.total=laps*track.N;r.state.v=5;session.step(1/60);assert.equal(r.completed,true);assert.equal(r.lap,laps+1);assert.ok(Number.isFinite(r.finish_at));
 }
});
