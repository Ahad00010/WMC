/* Bounded race-only motion history: each rider keeps the last six seconds
   through their actual finish. Coordinates come from live game/server state. */
(function(root){
'use strict';
function create(){var riders=Object.create(null),windowMs=6500,interval=100,maxSamples=68;
 function clear(){riders=Object.create(null)}
 function record(id,time,pose,finished){
  if(!id||!Number.isFinite(time)||!pose||!Number.isFinite(pose.x)||!Number.isFinite(pose.z)||!Number.isFinite(pose.h))return;
  var r=riders[id]||(riders[id]={samples:[],finished:false});if(r.finished)return;
  var a=r.samples,last=a[a.length-1];if(last&&time<last.t)return;if(last&&time-last.t<interval&&!finished)return;
  var sample={t:time,x:pose.x,z:pose.z,h:pose.h,lean:Number.isFinite(pose.lean)?pose.lean:0,pitch:Number.isFinite(pose.pitch)?pose.pitch:0,steer:Number.isFinite(pose.steer)?pose.steer:0,v:Number.isFinite(pose.v)?pose.v:0};
  if(last&&time===last.t)a[a.length-1]=sample;else a.push(sample);while(a.length>maxSamples||(a.length>2&&a[1].t<time-windowMs))a.shift();if(finished)r.finished=true;
 }
 function clip(id){var r=riders[id];if(!r||r.samples.length<2)return null;var a=r.samples,end=a[a.length-1].t,start=a.length-1;while(start>0&&a[start].t-a[start-1].t<=500&&a[start].t>end-6000)start--;var result=a.slice(start);if(result.length<2||end<=result[0].t)return null;return result.map(function(s){return Object.assign({},s)})}

 return {clear:clear,record:record,clip:clip};
}
 function sample(a,progress){if(!a||!a.length)return null;var start=Math.max(a[0].t,a[a.length-1].t-6000),t=start+Math.max(0,Math.min(1,progress))*(a[a.length-1].t-start),i=1;while(i<a.length&&a[i].t<t)i++;if(i===a.length)return Object.assign({},a[a.length-1]);var before=a[i-1],after=a[i],f=after.t===before.t?1:(t-before.t)/(after.t-before.t),out={};['x','z','lean','pitch','steer','v'].forEach(function(k){out[k]=before[k]+(after[k]-before[k])*f});var delta=((after.h-before.h+Math.PI*3)%(Math.PI*2))-Math.PI;out.h=before.h+delta*f;return out}
root.WMCWinnerReplay={create:create,sample:sample};if(typeof module!=='undefined'&&module.exports)module.exports=root.WMCWinnerReplay;
})(typeof window!=='undefined'?window:globalThis);
