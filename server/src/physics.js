import defaultTrack from './track.js';
const VMAX=88, WIN=40;
const wrap=a=>{while(a>Math.PI)a-=2*Math.PI;while(a<-Math.PI)a+=2*Math.PI;return a};
export function createPhysics(track){
const {N,px,pz,tx,tz,lx,lz,roadHalfWidth,kerbEdge,wallEdge}=track;
function spawn(grid=1){
  if(!Number.isInteger(grid)||grid<1||grid>15)throw new Error('invalid grid position');
  const i=(N-9-Math.floor((grid-1)/2)*2+N)%N,side=grid%2?1:-1;
  return {x:px[i]+lx[i]*side*2,z:pz[i]+lz[i]*side*2,h:Math.atan2(tx[i],tz[i]),v:0,steer:0,lean:0,pitch:0,idx:i,total:i>N/2?i-N:i,lat:side*2,impact:0};
}
function nearest(s){
  let best=Infinity,bi=s.idx;
  for(let k=-WIN;k<=WIN;k++){const j=(s.idx+k+N)%N,dx=s.x-px[j],dz=s.z-pz[j],d=dx*dx+dz*dz;if(d<best){best=d;bi=j}}
  let dl=bi-s.idx;if(dl>N/2)dl-=N;if(dl<-N/2)dl+=N;s.idx=bi;s.total+=dl;s.lat=(s.x-px[bi])*lx[bi]+(s.z-pz[bi])*lz[bi];
}
function step(s,input,dt){
  if(!Number.isFinite(dt)||dt<=0||dt>1/30)throw new Error('invalid physics step');
  const previous=s.total;nearest(s);
  const al=Math.abs(s.lat),grip=al>kerbEdge(s.idx)?.5:al>roadHalfWidth(s.idx)?.92:1,maxV=al>kerbEdge(s.idx)?VMAX*.36:VMAX;
  const thr=input.up?1:0,brk=input.down,hard=input.brake;let a=0;
  if(thr){a=17*(1-Math.pow(Math.max(s.v,0)/maxV,1.6));if(s.v<0)a=22}
  if(brk||hard){if(hard)a=s.v>0?-40*grip:s.v<0?40*grip:0;else if(s.v>.4)a=-30*grip;else if(!thr){a=-9;if(s.v< -9)a=0}}
  if(!thr&&!(brk||hard))a=-(1.3+.0007*s.v*s.v)*Math.sign(s.v||1);
  if(s.v>maxV)a-=Math.min(40,(s.v-maxV)*3+8);
  a-=2.2*Math.abs(s.steer)*(Math.abs(s.v)/VMAX)*Math.sign(s.v||1);
  const old=s.v;s.v+=a*dt;if((hard||!thr&&!(brk||hard))&&old*s.v<=0)s.v=0;
  const target=(input.left?1:0)-(input.right?1:0);s.steer+=(target-s.steer)*Math.min(1,dt*(target===0?(brk||hard?16:9):5.5));
  const av=Math.abs(s.v),yaw=s.steer*Math.min(1.9,18*grip/Math.max(av,.01))*Math.min(1,av/4)*(s.v>=0?1:-.7);
  s.h+=yaw*dt;s.x+=Math.sin(s.h)*s.v*dt;s.z+=Math.cos(s.h)*s.v*dt;nearest(s);
  const offTrack=Math.abs(s.lat)>kerbEdge(s.idx),wall=wallEdge(s.idx);
  if(Math.abs(s.lat)>wall){const sign=s.lat>0?1:-1,over=s.lat-sign*wall;s.x-=lx[s.idx]*over;s.z-=lz[s.idx]*over;if(s.impact<=0){s.v*=.6;s.impact=.5}s.v-=s.v*Math.min(1,2.2*dt);if(s.v>0)s.h+=wrap(Math.atan2(tx[s.idx],tz[s.idx])-s.h)*Math.min(1,2.5*dt)}
  if(s.impact>0)s.impact-=dt;
  const lt=s.steer*1.05*Math.min(1,av/24);s.lean+=(lt-s.lean)*Math.min(1,dt*6.5);
  let pt=0;if(thr&&s.v>0&&s.v<32)pt=-.24*(1-s.v/32)*Math.max(0,a/17);if((brk||hard)&&s.v>25)pt=.06;s.pitch+=(pt-s.pitch)*Math.min(1,dt*5);
  return {previous,offTrack};
}

return {spawn,step};
}
export const {spawn,step}=createPhysics(defaultTrack);
export function parseInput(value){
  if(!value||typeof value!=='object'||Array.isArray(value))return null;
  const out={};for(const key of ['up','down','left','right','brake']){if(typeof value[key]!=='boolean')return null;out[key]=value[key]}
  return out;
}
export const neutralInput=()=>({up:false,down:false,left:false,right:false,brake:false});
