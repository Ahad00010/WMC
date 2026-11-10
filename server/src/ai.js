// Simple steering and braking controller: it sends the same inputs through the
// authoritative physics as a human rider; it never teleports or changes speed.
import defaultTrack from './track.js';
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
export function createAI(track){
const {N,px,pz,tx,tz}=track;
// Track curvature is fixed; compute it once per track controller instead of
// thousands of atan2 calls every second for a full grid.
const bends=new Float64Array(N);for(let a=0;a<N;a++){const b=(a+5)%N;bends[a]=Math.abs(wrap(Math.atan2(tx[b],tz[b])-Math.atan2(tx[a],tz[a])))}
return function aiInput(s,skill=0){
 const look=Math.max(5,Math.min(22,Math.round(5+Math.abs(s.v)*.08))),j=(s.idx+look)%N;
 const target=Math.atan2(px[j]-s.x,pz[j]-s.z),angle=wrap(target-s.h);
 let curve=0;for(let k=4;k<look+16;k+=4){const a=(s.idx+k)%N;curve=Math.max(curve,bends[a])}
 const cap=Math.max(13,Math.min(49+skill*2,60/(1+curve*4)));
 return {up:s.v<cap-1,down:s.v>cap+2,left:angle>.035,right:angle<-.035,brake:false};
}

}
export const aiInput=createAI(defaultTrack);
