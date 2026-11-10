import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

function documentFromGLB(data){assert.equal(data.readUInt32LE(0),0x46546c67);assert.equal(data.readUInt32LE(4),2);assert.equal(data.readUInt32LE(8),data.length);return JSON.parse(data.subarray(20,20+data.readUInt32LE(12)).toString())}
function vertices(doc){return doc.meshes.reduce((n,m)=>n+m.primitives.reduce((v,p)=>v+doc.accessors[p.attributes.POSITION].count,0),0)}
test('mobile Ducati is a smaller standard glTF with preserved animated wheel nodes',()=>{
 const original=Buffer.from(readFileSync(new URL('../../bike-model.txt',import.meta.url),'utf8').trim(),'base64'),mobile=readFileSync(new URL('../../bike-mobile.glb',import.meta.url));const source=documentFromGLB(original),optimized=documentFromGLB(mobile);
 assert.ok(mobile.length<original.length*.5);assert.ok(vertices(optimized)<vertices(source)*.7);assert.ok(!optimized.extensionsRequired?.length,'mobile model must work with the existing glTF loader without a decoder');for(const name of ['wheel_front','wheel_rear'])assert.ok(optimized.nodes.some(n=>n.name===name),name);assert.equal(optimized.meshes.length,source.meshes.length);
});
