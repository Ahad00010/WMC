/* Smooth rendering of authoritative snapshots; never changes race-server state. */
(function(root){
  'use strict';
  function angle(a,b,t){var d=b-a;while(d>Math.PI)d-=2*Math.PI;while(d< -Math.PI)d+=2*Math.PI;return a+d*t}
  function SnapshotSmoother(delay){this.delay=delay==null?100:delay;this.clear()}
  SnapshotSmoother.prototype.clear=function(){this.samples=[];this.clockOffset=null;this.lastArrival=null};
  SnapshotSmoother.prototype.push=function(state,arrival,serverTime){
    if(!state||!Number.isFinite(state.x)||!Number.isFinite(state.z)||!Number.isFinite(state.h)||!Number.isFinite(arrival))return;
    var samples=this.samples,last=samples[samples.length-1];
    if(this.lastArrival!==null&&arrival<=this.lastArrival)return;
    // A fresh connection or a reset must not slide a rider across the track.
    if(last&&(arrival-this.lastArrival>1000||Math.hypot(state.x-last.s.x,state.z-last.s.z)>45)){this.clear();samples=this.samples;last=null}
    var time=arrival;
    if(Number.isFinite(serverTime)){
      if(this.clockOffset===null)this.clockOffset=arrival-serverTime;
      time=serverTime+this.clockOffset;
      // A server clock correction is a discontinuity, not an interpolation target.
      if(last&&(time<=last.t||Math.abs(time-arrival)>2000)){
        if(time<=last.t&&Math.abs(time-arrival)<=2000)return;
        this.clear();samples=this.samples;last=null;this.clockOffset=arrival-serverTime;time=arrival;
      }
    }
    if(last&&time<=last.t)return;
    this.lastArrival=arrival;var pose={x:state.x,z:state.z,h:state.h};['v','steer','lean','pitch'].forEach(function(key){if(Number.isFinite(state[key]))pose[key]=state[key]});samples.push({t:time,s:pose});
    while(samples.length>20)samples.shift();
  };
  SnapshotSmoother.prototype.sample=function(now,extrapolateMs){
    var samples=this.samples;if(!samples.length)return null;
    var t=now-this.delay,last=samples[samples.length-1];
    // Remote rendering only: bridge a short late packet without freezing. This
    // bounded visual prediction never changes server state, timing or results.
    if(extrapolateMs>0&&t>last.t&&Number.isFinite(last.s.v)){
      var seconds=Math.min(100,extrapolateMs,t-last.t)/1000,velocity=Math.max(-9,Math.min(88,last.s.v));
      var predicted=Object.assign({},last.s);predicted.x+=Math.sin(last.s.h)*velocity*seconds;predicted.z+=Math.cos(last.s.h)*velocity*seconds;return predicted;
    }
    while(samples.length>2&&samples[1].t<=t)samples.shift();
    var a=samples[0],b=samples[1];if(!b||t<=a.t)return a.s;
    var f=Math.max(0,Math.min(1,(t-a.t)/(b.t-a.t)));
    var result={x:a.s.x+(b.s.x-a.s.x)*f,z:a.s.z+(b.s.z-a.s.z)*f,h:angle(a.s.h,b.s.h,f)};
    ['v','steer','lean','pitch'].forEach(function(key){if(Number.isFinite(a.s[key])&&Number.isFinite(b.s[key]))result[key]=a.s[key]+(b.s[key]-a.s[key])*f;else if(Number.isFinite(b.s[key]))result[key]=b.s[key];else if(Number.isFinite(a.s[key]))result[key]=a.s[key]});
    return result;
  };
  root.WMCSnapshotSmoother=SnapshotSmoother;
  if(typeof module!=='undefined'&&module.exports)module.exports=SnapshotSmoother;
})(typeof window!=='undefined'?window:globalThis);
