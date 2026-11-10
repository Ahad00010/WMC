import test from 'node:test';import assert from 'node:assert/strict';
import sectorColor from '../../qualifying-colors.js';
import {length} from '../src/track.js';
test('sector colors avoid automatic red and preserve meaningful personal/session comparisons',()=>{
 const metres=length/4;
 assert.equal(sectorColor(100,null,Infinity,metres),'slow');
 assert.equal(sectorColor(90,100,100,metres),'best'); // too slow to be red
 assert.equal(sectorColor(51,50,50,metres),'slow');
 assert.equal(sectorColor(49.5,50,50,metres),'best'); // personal best, under 2%
 assert.equal(sectorColor(48,50,50,metres),'record');
 assert.equal(sectorColor(48,48,48,metres),'slow');
 assert.equal(sectorColor(48,null,50,metres),'record'); // real faster opponent benchmark
 for(const v of [null,0,-1,NaN,Infinity])assert.equal(sectorColor(v,50,50,metres),'slow');
});
