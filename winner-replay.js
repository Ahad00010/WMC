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
// Capture the actual rendered local view, including wheelies, nitro, and camera.
// Only the local rider's view is recorded; never label someone else's view as
// the winner's footage. Small JPEG frames keep memory bounded on mobile.
function createFootage(doc){
 var frames=[],rider=null,finished=false,last=-Infinity,buffer=null,ctx=null,wheelieAt=null,favorite=null;
 function clear(){frames=[];rider=null;finished=false;last=-Infinity;buffer=null;ctx=null;wheelieAt=null;favorite=null}
 function record(id,time,source,done,wheelie){
  if(!id||!Number.isFinite(time)||!source||finished||time<last||(!done&&time-last<100))return;
  if(rider&&rider!==id){clear()}rider=id;
  try{
   if(!source.width||!source.height)return;
   if(!buffer){buffer=doc.createElement('canvas');ctx=buffer.getContext('2d');if(!ctx)return}
   var scale=Math.min(1,640/source.width,360/source.height),w=Math.max(1,Math.round(source.width*scale)),h=Math.max(1,Math.round(source.height*scale));
   if(buffer.width!==w)buffer.width=w;if(buffer.height!==h)buffer.height=h;
   ctx.drawImage(source,0,0,w,h);var image=buffer.toDataURL('image/jpeg',.72);if(!image||image==='data:,')return;
   frames.push({t:time,image:image});last=time;while(frames.length>62||(frames.length>2&&frames[1].t<time-6000))frames.shift();if(wheelie&&wheelieAt===null&&!favorite)wheelieAt=time;if(wheelieAt!==null&&!favorite&&time-wheelieAt>=3000){favorite=continuous(frames);if(!favorite)wheelieAt=null}if(done)finished=true;
  }catch(e){clear()}
 }
 function continuous(a){if(a.length<2)return null;var end=a[a.length-1].t,start=a.length-1;while(start>0&&a[start].t-a[start-1].t<=500&&a[start].t>end-6000)start--;var result=a.slice(start);return end-result[0].t>=5500?result:null}
 function clip(id){if(id!==rider||!finished)return null;var result=favorite||continuous(frames);return result?result.slice():null}
 return {clear:clear,record:record,clip:clip};
}
function footageFrame(clip,progress){var t=clip[0].t+Math.max(0,Math.min(1,progress))*(clip[clip.length-1].t-clip[0].t),i=0;while(i+1<clip.length&&clip[i+1].t<=t)i++;return i}
root.WMCWinnerReplay={create:create,sample:sample,createFootage:createFootage,footageFrame:footageFrame};if(typeof module!=='undefined'&&module.exports)module.exports=root.WMCWinnerReplay;
})(typeof window!=='undefined'?window:globalThis);
