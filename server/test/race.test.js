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

test('sector colors use real benchmarks, sensible margins and exclude invalid laps',()=>{
 const r=room('qualifying_race'),a=r.players.get('a'),b=r.players.get('b');
 for(const p of [a,b]){p.flying=true;p.invalid=false;p.sectorStart=0;p.lapStart=0;p.sectorTimes=[];p.sectorBests=[null,null,null,null]}
 r.events=[];r.recordSector(a,0,50000);assert.equal(r.events.at(-1).color,'slow','first sector is a baseline, not automatic red');
 r.recordSector(b,0,55000);assert.equal(r.events.at(-1).color,'slow','no personal benchmark is not an automatic best');
 b.sectorBests[0]=55;b.sectorTimes=[];b.sectorStart=0;r.recordSector(b,0,54500);assert.equal(r.events.at(-1).color,'best');assert.equal(r.events.at(-1).delta,-.5);
 b.sectorTimes=[];b.sectorStart=0;r.recordSector(b,0,49500);assert.equal(r.events.at(-1).color,'best','a small session improvement is orange');
 b.sectorTimes=[];b.sectorStart=0;r.recordSector(b,0,48000);assert.equal(r.events.at(-1).color,'record','a competitive session improvement is red');
 b.sectorTimes=[];b.sectorStart=0;r.recordSector(b,0,56000);assert.equal(r.events.at(-1).color,'slow');
 a.invalid=true;b.sectorTimes=[];b.sectorStart=0;r.recordSector(b,0,50000);assert.equal(r.events.at(-1).color,'record','invalid flying lap no longer sets the session benchmark');
 b.sectorTimes=[];b.sectorBests[0]=100;b.sectorStart=0;r.recordSector(b,0,90000);assert.equal(r.events.at(-1).color,'best','slow sector improvement is orange, not red');
 b.invalid=true;const count=r.events.length;b.sectorStart=0;r.recordSector(b,1,10000);assert.equal(r.events.length,count,'invalid sectors do not emit timing events');
});

test('fourth clean sector and valid lap are both broadcast',()=>{
 const r=room('qualifying_race'),p=r.players.get('a');p.flying=true;p.state.v=20;p.lapStart=0;p.sectorStart=0;p.sectorBests[3]=50;p.sector=3;p.state.total=p.line+N;r.events=[];
 r.qualify(p,{previous:p.state.total-1,offTrack:false},45000);
 assert.deepEqual(r.events.map(e=>e.type),['sector','lap']);assert.equal(r.events[0].sector,4);assert.equal(r.events[0].color,'record');assert.equal(r.events[1].fastest,true);
});

test('qualification flag is set only for a rider completing at the finish line',()=>{
 const r=room('qualifying_race'),a=r.players.get('a'),b=r.players.get('b');
 a.flying=true;a.attempts=2;a.state.v=20;a.sector=3;a.state.total=a.line+N;r.qualify(a,{previous:a.state.total-1,offTrack:false},r.phaseStart+60000);
 assert.equal(a.completed,true);assert.equal(a.finishAt,r.phaseStart+60000);assert.equal(b.finishAt,null);
 b.flying=false;r.qualify(b,{previous:-1,offTrack:false},r.phaseStart+240000);assert.equal(b.completed,true);assert.equal(b.finishAt,null,'expiration on an out lap is not a finish-line crossing');
});

test('emotes are cosmetic, movement-gated, bounded and rate-limited',()=>{
 const r=room(),p=r.players.get('a'),before={...p.state};assert.equal(r.emote('a','wheelie',30000),false);
 r.input('a',{up:true,down:false,left:false,right:false,brake:false},30000);assert.equal(r.emote('a','wheelie',30000),true);assert.deepEqual(p.state,before);
 assert.equal(r.emote('a','nitro',30100),false);assert.equal(r.emote('a','nitro',31000),true);assert.deepEqual(p.state,before);
 assert.equal(r.emote('a','teleport',32000),false);assert.equal(r.snapshot(32000).players.find(p=>p.id==='a').emote.kind,'nitro');assert.equal(r.snapshot(35000).players.find(p=>p.id==='a').emote,null);
});

test('chat uses server identity, validates length and limits spam',()=>{
 const r=room(),p=r.players.get('a');p.profile.display_name='Actual Rider';assert.deepEqual(r.chat('a',' hi\n<test> ',30000),{type:'chat',id:'a',name:'Actual Rider',number:1,color:'red',text:'hi <test>'});
 assert.equal(r.chat('a','second',30001),null);assert.equal(r.chat('a','x'.repeat(181),32000),null);assert.equal(r.chat('a','   ',32000),null);assert.equal(r.chat('a','OK',32000).text,'OK');
 r.phase='qualifying';assert.equal(r.chat('a','qualifying',33001).text,'qualifying');r.phase='complete';assert.equal(r.chat('a','post race',34002).text,'post race');
});
