/* Offline practice uses the same physics and AI controller as the race server.
   Keep createPhysics/createAI synchronized with server/src/{physics,ai}.js. */
(function(root){
'use strict';
const contact=root.WMCBikeContact||(typeof require==='function'?require('./bike-contact.js'):null);
const VMAX=88,WIN=40;
const wrap=a=>{while(a>Math.PI)a-=2*Math.PI;while(a<-Math.PI)a+=2*Math.PI;return a};
function createPhysics(track){
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

return {spawn,step,reconcile:nearest};
}
function createAI(track){
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

function createPracticeAI(track,mode){
 const physics=createPhysics(track),controller=createAI(track),colors=['blue','red','yellow','orange','green','cyan','purple','pink','white'];
 const riders=Array.from({length:9},(_,i)=>({id:'practice-ai-'+(i+1),display_name:'AI Rider '+(i+1),number:21+i,color:colors[i],grid:i+2,state:physics.spawn(i+2),lap:1,line:0,lapStart:0,attempts:0,best:null,flying:false,invalid:false,completed:false,finish_at:null}));
 let elapsed=0;
 function step(dt,player,previousPlayer){if(!(dt>0))return;const n=Math.ceil(dt/(1/60)),step=dt/n;
  for(let k=0;k<n;k++){elapsed+=step;const active=riders.filter(p=>!p.completed),before=new Map(active.map(p=>[p,{x:p.state.x,z:p.state.z}]));for(const p of riders){if(p.completed)continue;const s=p.state,result=physics.step(s,controller(s,(p.grid%5)-2),step);
   if(mode==='race'){if(s.total>=track.N*p.lap&&s.v>0){p.lap++;if(p.lap>3){p.completed=true;p.finish_at=elapsed}}}
   else if(!p.flying){if(result.previous<0&&s.total>=0&&s.v>0){p.flying=true;p.line=0;p.lapStart=elapsed;p.invalid=result.offTrack}}
   else{if(result.offTrack)p.invalid=true;if(s.total>=p.line+track.N&&s.v>0){const time=elapsed-p.lapStart;p.attempts++;if(!p.invalid)p.best=p.best==null?time:Math.min(p.best,time);p.line+=track.N;p.lapStart=elapsed;p.invalid=false;if(p.attempts>=3||elapsed>=240)p.completed=true}}
   if(mode==='qualifying'&&elapsed>=240&&!p.flying)p.completed=true;
  }
  if(contact){for(let i=0;i<active.length;i++){if(player)contact.resolve(player,active[i].state,previousPlayer||player,before.get(active[i]))}for(const p of active)physics.reconcile(p.state)}
  }
 }
 return {riders,step};
}
const api={createPhysics,createAI,createPracticeAI};root.WMCPracticeAI=api;if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
