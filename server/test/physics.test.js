import test from 'node:test';
import assert from 'node:assert/strict';
import {N,length,roadHalfWidth,kerbEdge,px,pz,tx,tz} from '../src/track.js';
import {spawn,step,parseInput,neutralInput} from '../src/physics.js';
test('track geometry matches game dimensions and normalized direction',()=>{
  assert.ok(length>4000&&length<7000);assert.ok(N>800);
  assert.equal(roadHalfWidth(0),8);assert.equal(roadHalfWidth(N/2),11);assert.equal(kerbEdge(0),10.5);
  for(let i=0;i<N;i++)assert.ok(Number.isFinite(px[i])&&Number.isFinite(pz[i])&&Math.abs(Math.hypot(tx[i],tz[i])-1)<1e-6);
});
test('physics accepts controls only and accelerates at a fixed step',()=>{
  assert.equal(parseInput({x:5}),null);const input={...neutralInput(),up:true,x:999};assert.deepEqual(parseInput(input),{...neutralInput(),up:true});
  const s=spawn(1),start=s.total;for(let i=0;i<600;i++)step(s,input,1/60);
  assert.ok(s.v>0);assert.ok(s.total>start);assert.throws(()=>step(s,input,1));assert.throws(()=>spawn(16));
});

test('hard braking stops without reversing, and released steering settles symmetrically under braking',()=>{
 const hard={...neutralInput(),brake:true};for(const start of [0,.1,10,-3]){const s=spawn(1);s.v=start;for(let i=0;i<180;i++)step(s,hard,1/60);assert.equal(s.v,0,'hard brake should hold a stop, not drive backwards')}
 const left=spawn(1),right={...left},straight={...left};left.v=right.v=straight.v=30;left.steer=.7;right.steer=-.7;for(let i=0;i<12;i++){step(left,hard,1/60);step(right,hard,1/60);step(straight,hard,1/60)}assert.ok(Math.abs((left.h-straight.h)+(right.h-straight.h))<.0001,'braking does not introduce a one-sided turn');assert.ok(Math.abs(left.steer)<.03,'released steering settles promptly while braking');
 const reverse=spawn(1);for(let i=0;i<100;i++)step(reverse,{...neutralInput(),down:true},1/60);assert.ok(reverse.v<0,'the regular reverse control remains available');
});
