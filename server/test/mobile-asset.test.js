import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

function documentFromGLB(data){assert.equal(data.readUInt32LE(0),0x46546c67);assert.equal(data.readUInt32LE(4),2);assert.equal(data.readUInt32LE(8),data.length);return JSON.parse(data.subarray(20,20+data.readUInt32LE(12)).toString())}
function vertices(doc){return doc.meshes.reduce((n,m)=>n+m.primitives.reduce((v,p)=>v+doc.accessors[p.attributes.POSITION].count,0),0)}
test('mobile Ducati is a smaller standard glTF with preserved animated wheel nodes',()=>{
 const original=Buffer.from(readFileSync(new URL('../../bike-model.txt',import.meta.url),'utf8').trim(),'base64'),mobile=readFileSync(new URL('../../bike-mobile.glb',import.meta.url));const source=documentFromGLB(original),optimized=documentFromGLB(mobile);
 assert.ok(mobile.length<original.length*.7);assert.ok(vertices(optimized)>vertices(source)*.7&&vertices(optimized)<vertices(source)*.9);assert.ok(!optimized.extensionsRequired?.length,'mobile model must work with the existing glTF loader without a decoder');for(const name of ['wheel_front','wheel_rear'])assert.ok(optimized.nodes.some(n=>n.name===name),name);assert.equal(optimized.meshes.length,source.meshes.length);
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

// Decode the actual embedded RGBA PNG, without a browser or third-party image
// dependency, to guard against accidentally tinting the entire suit again.
test('Marc suit preserves contrasting panels and uses Ducati-matched red',async()=>{
 const {inflateSync}=await import('node:zlib');
 const asset=readFileSync(new URL('../../marc-rider.glb',import.meta.url)),doc=documentFromGLB(asset);
 const view=doc.bufferViews[doc.images.find(i=>i.name==='red-suit').bufferView],binOffset=20+asset.readUInt32LE(12)+8;
 const png=asset.subarray(binOffset+view.byteOffset,binOffset+view.byteOffset+view.byteLength);
 assert.equal(png.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
 let pos=8,width,height,parts=[];
 while(pos<png.length){const len=png.readUInt32BE(pos),type=png.toString('ascii',pos+4,pos+8),data=png.subarray(pos+8,pos+8+len);if(type==='IHDR'){width=data.readUInt32BE(0);height=data.readUInt32BE(4);assert.equal(data[8],8);assert.equal(data[9],6)}if(type==='IDAT')parts.push(data);pos+=12+len;if(type==='IEND')break}
 assert.equal(width,1024);assert.equal(height,1024);const raw=inflateSync(Buffer.concat(parts)),stride=width*4,pixels=Buffer.alloc(stride*height);
 function paeth(a,b,c){const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);return pa<=pb&&pa<=pc?a:pb<=pc?b:c}
 for(let y=0;y<height;y++){const filter=raw[y*(stride+1)],src=y*(stride+1)+1,row=y*stride;for(let x=0;x<stride;x++){const left=x>=4?pixels[row+x-4]:0,up=y?pixels[row+x-stride]:0,ul=y&&x>=4?pixels[row+x-stride-4]:0;let pred=0;if(filter===1)pred=left;else if(filter===2)pred=up;else if(filter===3)pred=Math.floor((left+up)/2);else if(filter===4)pred=paeth(left,up,ul);else assert.equal(filter,0);pixels[row+x]=(raw[src+x]+pred)&255}}
 let white=0,navy=0,ducatiRed=0,orange=0;
 for(let i=0;i<pixels.length;i+=4){const r=pixels[i],g=pixels[i+1],b=pixels[i+2];if(r>220&&g>220&&b>220)white++;if(b>40&&b>r*1.3&&b>g*1.1)navy++;if(r>=140&&r<=165&&g<18&&b<18)ducatiRed++;if(r>180&&g>50&&g<120&&b<45)orange++}
 assert.ok(white>150000,'white panels remain white');assert.ok(navy>50000,'navy panels retain their contrast');assert.ok(ducatiRed>50000,'substantial suit areas match the bike paint around #970808');assert.ok(orange<10000,'old orange is mostly replaced');
});
