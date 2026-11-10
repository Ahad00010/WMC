/* Smooth rendering of authoritative snapshots; never changes race-server state. */
(function(root){
  'use strict';
  function angle(a,b,t){var d=b-a;while(d>Math.PI)d-=2*Math.PI;while(d< -Math.PI)d+=2*Math.PI;return a+d*t}
  function SnapshotSmoother(delay){this.delay=delay==null?100:delay;this.samples=[]}
  SnapshotSmoother.prototype.clear=function(){this.samples=[]};
  SnapshotSmoother.prototype.push=function(state,time){
    if(!state||!Number.isFinite(state.x)||!Number.isFinite(state.z)||!Number.isFinite(state.h)||!Number.isFinite(time))return;
    var samples=this.samples,last=samples[samples.length-1];
    if(last&&time<=last.t)return;
    // Resets and phase changes should not glide the bike across the track.
    if(last&&(time-last.t>1000||Math.hypot(state.x-last.s.x,state.z-last.s.z)>45))samples.length=0;
    samples.push({t:time,s:{x:state.x,z:state.z,h:state.h}});
    while(samples.length>20)samples.shift();
  };
  SnapshotSmoother.prototype.sample=function(now){
    var samples=this.samples;if(!samples.length)return null;
    var t=now-this.delay;
    while(samples.length>2&&samples[1].t<=t)samples.shift();
    var a=samples[0],b=samples[1];if(!b||t<=a.t)return a.s;
    var f=Math.max(0,Math.min(1,(t-a.t)/(b.t-a.t)));
    return {x:a.s.x+(b.s.x-a.s.x)*f,z:a.s.z+(b.s.z-a.s.z)*f,h:angle(a.s.h,b.s.h,f)};
  };
  root.WMCSnapshotSmoother=SnapshotSmoother;
  if(typeof module!=='undefined'&&module.exports)module.exports=SnapshotSmoother;
})(typeof window!=='undefined'?window:globalThis);
