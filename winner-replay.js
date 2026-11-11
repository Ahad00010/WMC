/* Record the actual race canvas, not an approximation of rider movements. */
(function(root){
'use strict';
function createFootage(env){
 var stream=null,recorder=null,segment=null,best=Object.create(null),completed=Object.create(null),generation=0,lastSample=-Infinity,disabled=false,slowStart=null,slowFrames=0,slowTime=0,highQuality=false,clipHandler=null;
 function stopTracks(){if(stream){stream.getTracks().forEach(function(t){t.stop()});stream=null}}
 function clear(){generation++;if(recorder&&recorder.state!=='inactive'){try{recorder.stop()}catch(e){}}recorder=null;segment=null;stopTracks();best=Object.create(null);completed=Object.create(null);lastSample=-Infinity;disabled=false;slowStart=null;slowFrames=0;slowTime=0;highQuality=false}
 function start(source,now){
  if(disabled)return false;if(!source.captureStream||!env.MediaRecorder){disabled=true;return false;}
  try{
   if(!stream)stream=source.captureStream(highQuality?60:30);
   var types=['video/webm;codecs=vp8','video/webm','video/mp4'],mime=types.find(function(type){return env.MediaRecorder.isTypeSupported&&env.MediaRecorder.isTypeSupported(type)}),options={videoBitsPerSecond:highQuality?16000000:6000000};if(mime)options.mimeType=mime;
   var r=new env.MediaRecorder(stream,options),g=generation,part={start:now,end:now,scores:Object.create(null),finishers:Object.create(null),chunks:[]};recorder=r;segment=part;
   r.ondataavailable=function(e){if(e.data&&e.data.size)part.chunks.push(e.data)};
   r.onstop=function(){var duration=part.end-part.start;if(g!==generation||!part.chunks.length||duration<200)return;var blob=new env.Blob(part.chunks,{type:r.mimeType||mime||'video/webm'});if(!blob.size)return;Object.keys(part.scores).forEach(function(id){var atFinish=!!part.finishers[id],previous=best[id];if(!atFinish&&duration<5500)return;if(!previous||(atFinish&&!previous.atFinish)||(atFinish===previous.atFinish&&part.end>previous.end)){best[id]={blob:blob,score:part.scores[id],duration:duration,end:part.end,atFinish:atFinish};if(clipHandler)clipHandler(id,best[id])}})};
   r.onerror=function(){if(g===generation){disabled=true;stopTracks()}};r.start();return true;
  }catch(e){disabled=true;stopTracks();return false}
 }
 function finishPart(now){if(!recorder)return;segment.end=now;var r=recorder;recorder=null;segment=null;try{if(r.state!=='inactive')r.stop()}catch(e){disabled=true;stopTracks()}}
 // Called after the game's regular render; no synchronous canvas reads or JPEG encoding.
 // visible contains only riders actually near the camera and in its view.
 function record(now,source,visible,frameMs,endRace){
  if(!Number.isFinite(now)||disabled)return !!endRace;
  // A suspended tab is not six seconds of race footage. End before the gap.
  if(Number.isFinite(frameMs)&&frameMs>=1000&&recorder){finishPart(segment.end);stopTracks()}
  // Never keep recording at the expense of playable race performance.
  if(!highQuality&&Number.isFinite(frameMs)&&frameMs>0&&frameMs<1000){if(slowStart===null)slowStart=now;slowFrames++;slowTime+=frameMs;if(now-slowStart>=3000){if(slowFrames>10&&slowTime/slowFrames>45){finish(now);disabled=true;return}slowStart=now;slowFrames=0;slowTime=0}}else{slowStart=null;slowFrames=0;slowTime=0}
  if(!recorder&&!start(source,now))return !!endRace;
  segment.end=now;var crossed=false,sample=now-lastSample>=250;if(sample)lastSample=now;
  (visible||[]).forEach(function(item){if(!item||!item.id)return;if(sample||item.finished)segment.scores[item.id]=(segment.scores[item.id]||0)+1;if(item.finished&&!completed[item.id]){completed[item.id]=true;segment.finishers[item.id]=true;crossed=true}});
  // Allow the capture stream to sample the rendered finish frame before stopping.
  if((crossed||endRace)&&segment.closeAt==null)segment.closeAt=now+120;
  if(endRace)segment.endRace=true;
  if(segment.closeAt!=null&&now>=segment.closeAt){var ending=segment.endRace;finishPart(now);if(ending){stopTracks();return true}start(source,now)}
  else if(segment.closeAt==null&&now-segment.start>=20000){finishPart(now);start(source,now)}
  return false;
 }
 function finish(now){finishPart(now);stopTracks()}
 function clip(id){return best[id]||null}
 return {clear:clear,record:record,finish:finish,clip:clip,onClip:function(fn){clipHandler=fn},isAvailable:function(){return !disabled},setHighQuality:function(enabled){if(!recorder&&!stream)highQuality=!!enabled}};
}
// Start only in the final approach. Track progress is measured in laps, not
// straight-line distance, so the start line cannot be mistaken for the finish.
function nearFinish(progress,laps,trackLength){if(!Number.isFinite(progress)||!Number.isFinite(laps)||!Number.isFinite(trackLength)||laps<1||trackLength<=0)return false;var remaining=(laps-progress)*trackLength;return remaining<=Math.min(1300,trackLength*.4)&&remaining>=-100}
function nearWinnerFinish(progress,laps,trackLength,speed){if(!Number.isFinite(progress)||!Number.isFinite(laps)||!Number.isFinite(trackLength)||!Number.isFinite(speed)||trackLength<=0||laps<1||speed<5)return false;var remaining=(laps-progress)*trackLength;return remaining>=0&&remaining<=Math.min(trackLength*.4,Math.max(120,speed*8))}
root.WMCWinnerReplay={createFootage:createFootage,nearFinish:nearFinish,nearWinnerFinish:nearWinnerFinish};if(typeof module!=='undefined'&&module.exports)module.exports=root.WMCWinnerReplay;
})(typeof window!=='undefined'?window:globalThis);
