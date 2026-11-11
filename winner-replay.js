/* Record the actual race canvas, not an approximation of rider movements. */
(function(root){
'use strict';
function createFootage(env){
 var stream=null,recorder=null,segment=null,best=Object.create(null),generation=0,lastSample=-Infinity,disabled=false,slowStart=null,slowFrames=0,slowTime=0;
 function stopTracks(){if(stream){stream.getTracks().forEach(function(t){t.stop()});stream=null}}
 function clear(){generation++;if(recorder&&recorder.state!=='inactive'){try{recorder.stop()}catch(e){}}recorder=null;segment=null;stopTracks();best=Object.create(null);lastSample=-Infinity;disabled=false;slowStart=null;slowFrames=0;slowTime=0}
 function start(source,now){
  if(disabled||!source.captureStream||!env.MediaRecorder)return false;
  try{
   if(!stream)stream=source.captureStream(12);
   var types=['video/webm;codecs=vp8','video/webm','video/mp4'],mime=types.find(function(type){return env.MediaRecorder.isTypeSupported&&env.MediaRecorder.isTypeSupported(type)}),options={videoBitsPerSecond:1000000};if(mime)options.mimeType=mime;
   var r=new env.MediaRecorder(stream,options),g=generation,part={start:now,end:now,scores:Object.create(null),chunks:[]};recorder=r;segment=part;
   r.ondataavailable=function(e){if(e.data&&e.data.size)part.chunks.push(e.data)};
   r.onstop=function(){if(g!==generation||!part.chunks.length||part.end-part.start<5500)return;var blob=new env.Blob(part.chunks,{type:r.mimeType||mime||'video/webm'});if(!blob.size)return;Object.keys(part.scores).forEach(function(id){var score=part.scores[id];if(!best[id]||score>best[id].score)best[id]={blob:blob,score:score,duration:part.end-part.start}})};
   r.onerror=function(){if(g===generation){disabled=true;stopTracks()}};r.start();return true;
  }catch(e){disabled=true;stopTracks();return false}
 }
 function finishPart(now){if(!recorder)return;segment.end=now;var r=recorder;recorder=null;segment=null;try{if(r.state!=='inactive')r.stop()}catch(e){disabled=true;stopTracks()}}
 // Called after the game's regular render; no synchronous canvas reads or JPEG encoding.
 // visible contains only riders actually near the camera and in its view.
 function record(now,source,visible,frameMs){
  if(!Number.isFinite(now)||disabled)return;
  // A suspended tab is not six seconds of race footage. End before the gap.
  if(Number.isFinite(frameMs)&&frameMs>=1000&&recorder){finishPart(segment.end);stopTracks()}
  // Never keep recording at the expense of playable race performance.
  if(Number.isFinite(frameMs)&&frameMs>0&&frameMs<1000){if(slowStart===null)slowStart=now;slowFrames++;slowTime+=frameMs;if(now-slowStart>=3000){if(slowFrames>10&&slowTime/slowFrames>45){finish(now);disabled=true;return}slowStart=now;slowFrames=0;slowTime=0}}else{slowStart=null;slowFrames=0;slowTime=0}
  if(!recorder&&!start(source,now))return;
  if(now-segment.start>=6000){finishPart(now);if(!start(source,now))return}
  segment.end=now;if(now-lastSample<250)return;lastSample=now;
  (visible||[]).forEach(function(item){if(!item||!item.id)return;segment.scores[item.id]=(segment.scores[item.id]||0)+1+(item.wheelie?2:0)})
 }
 function finish(now){finishPart(now);stopTracks()}
 function clip(id){return best[id]||null}
 return {clear:clear,record:record,finish:finish,clip:clip};
}
root.WMCWinnerReplay={createFootage:createFootage};if(typeof module!=='undefined'&&module.exports)module.exports=root.WMCWinnerReplay;
})(typeof window!=='undefined'?window:globalThis);
