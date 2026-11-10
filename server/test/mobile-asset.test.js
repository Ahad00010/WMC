import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

function documentFromGLB(data){assert.equal(data.readUInt32LE(0),0x46546c67);assert.equal(data.readUInt32LE(4),2);assert.equal(data.readUInt32LE(8),data.length);return JSON.parse(data.subarray(20,20+data.readUInt32LE(12)).toString())}
function vertices(doc){return doc.meshes.reduce((n,m)=>n+m.primitives.reduce((v,p)=>v+doc.accessors[p.attributes.POSITION].count,0),0)}
test('mobile Ducati is a smaller standard glTF with preserved animated wheel nodes',()=>{
 const original=Buffer.from(readFileSync(new URL('../../bike-model.txt',import.meta.url),'utf8').trim(),'base64'),mobile=readFileSync(new URL('../../bike-mobile.glb',import.meta.url));const source=documentFromGLB(original),optimized=documentFromGLB(mobile);
 assert.ok(mobile.length<original.length*.5);assert.ok(vertices(optimized)<vertices(source)*.7);assert.ok(!optimized.extensionsRequired?.length,'mobile model must work with the existing glTF loader without a decoder');for(const name of ['wheel_front','wheel_rear'])assert.ok(optimized.nodes.some(n=>n.name===name),name);assert.equal(optimized.meshes.length,source.meshes.length);
});

test('Marc rider is a compact textured glTF 2 asset without the Honda bike',()=>{
 const asset=readFileSync(new URL('../../marc-rider.glb',import.meta.url)),doc=documentFromGLB(asset);
 assert.ok(asset.length<2_000_000);assert.ok(!doc.extensionsRequired?.length);
 const meshes=doc.nodes.filter(n=>n.mesh!==undefined).map(n=>n.name);
 assert.ok(meshes.includes('Pilot_M_Pilot_0'));assert.ok(meshes.length>1);assert.ok(meshes.every(n=>n.startsWith('Pilot_')));
 assert.ok(vertices(doc)<30000,'simplified rider keeps geometry bounded');
 assert.ok(doc.images.length>=2,'suit and decals remain textured');
 assert.ok(doc.materials.some(m=>m.pbrMetallicRoughness?.baseColorTexture));
});
