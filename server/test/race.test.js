import test from 'node:test';import assert from 'node:assert/strict';
import {RaceRoom} from '../src/race.js';import {N} from '../src/track.js';
const profile=id=>({id,display_name:id,username:id,number:1,color:'red'});
function room(mode='race'){const r=new RaceRoom({id:'lobby',host_id:'a',mode});r.join(profile('a'),0);r.join(profile('b'),0);r.start('a',0);return r}
test('only host can start, connections are capped, and positions are not client supplied',()=>{let r=new RaceRoom({id:'1',host_id:'a',mode:'race'});r.join(profile('a'),0);r.join(profile('b'),0);assert.throws(()=>r.start('b',0));r.start('a',0);assert.equal(r.phase,'race');assert.deepEqual(r.snapshot(0).rules,{raceLaps:3,qualifyingAttempts:3,qualifyingMs:240000});assert.throws(()=>r.join(profile('c'),0));assert.equal(r.input('a',{up:true,down:false,left:false,right:false,brake:false,x:1e8},0),true);assert.notEqual(r.players.get('a').state.x,1e8)});
test('qualifying invalid laps count and three attempts end session',()=>{const r=room('qualifying'),p=r.players.get('a');p.flying=true;p.state.v=20;for(let i=0;i<3;i++){p.invalid=i===0;p.state.total=p.line+N;r.qualify(p,{previous:p.state.total-1,offTrack:false},r.phaseStart+(i+1)*10000)}assert.equal(p.attempts,3);assert.equal(p.completed,true);assert.equal(p.best,10)});
test('race with more than two riders waits through disconnect grace and delays results',()=>{const r=new RaceRoom({id:'l',host_id:'a',mode:'race'});for(const id of ['a','b','c'])r.join(profile(id),0);r.start('a',0);const a=r.players.get('a'),b=r.players.get('b'),c=r.players.get('c');a.completed=true;a.finishAt=100;c.completed=true;c.finishAt=200;r.advance(23000,1/60);assert.equal(r.resultsAt,null);r.disconnect('b',23000);r.advance(53001,1/60);assert.equal(b.dnf,true);assert.equal(r.resultsAt,63001);r.advance(63001,1/60);assert.equal(r.phase,'complete')});
test('two-rider qualifying and race end immediately when one rider disconnects or leaves',()=>{for(const mode of ['qualifying_race','race'])for(const method of ['disconnect','leave']){const r=room(mode);r[method]('b',23000);assert.equal(r.phase,'complete');assert.equal(r.endReason,'opponent_left');assert.equal(r.players.get('b').dnf,true);const snapshot=r.snapshot(23000);assert.equal(snapshot.endReason,'opponent_left');assert.ok(snapshot.events.some(e=>e.type==='session_ended'));assert.ok(!snapshot.events.some(e=>e.type==='results'))}});
test('15 riders can run fixed steps without non-finite positions and a disconnected rider can reconnect',()=>{
 const r=new RaceRoom({id:'l',host_id:'0',mode:'race'});for(let i=0;i<15;i++)r.join(profile(String(i)),0);assert.throws(()=>r.join(profile('extra'),0));r.start('0',0);r.disconnect('1',23000);r.join(profile('1'),24000);for(let n=0;n<600;n++){for(let i=0;i<15;i++)r.input(String(i),{up:true,down:false,left:false,right:false,brake:false},23000+n*1000/60);r.advance(23000+n*1000/60,1/60)}assert.equal(r.players.get('1').dnf,false);for(const p of r.players.values())for(const v of [p.state.x,p.state.z,p.state.v,p.state.h])assert.ok(Number.isFinite(v));
});

test('race ends on lap three and qualifying expires after four minutes',()=>{const r=room(),p=r.players.get('a');p.lap=3;p.state.total=3*N;p.state.v=5;r.advance(r.phaseStart+1000,1/60);assert.equal(p.completed,true);assert.equal(p.lap,4);const q=room('qualifying'),rider=q.players.get('a');q.advance(q.phaseStart+240000,1/60);assert.equal(q.phase,'race')});

test('explicitly leaving an active race immediately retires the rider',()=>{
 const room=new RaceRoom({id:'leave-test',host_id:'a',mode:'race'});
 room.join({id:'a',username:'a'},0);room.join({id:'b',username:'b'},0);room.start('a',0);
 room.leave('b',100);const rider=room.players.get('b');
 assert.equal(rider.dnf,true);assert.equal(rider.completed,true);assert.equal(rider.connected,false);
 assert.ok(room.events.some(e=>e.type==='dnf'&&e.id==='b'));
});
