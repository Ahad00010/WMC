/* Race-only broadcast results. Game state and race classification remain authoritative. */
(function(root){
'use strict';
var MUSIC='MotoGP 2025 Session Summary Theme Music.mp3';
var POINTS=[25,20,16,13,11,10,9,8,7,6,5,4,3,2,1];
function racePoints(item,index){return !item.dnf&&Number.isFinite(item.finishSeconds)?(POINTS[index]||0):0}
var colors={blue:'#176bb3',red:'#d81822',yellow:'#f2e800',orange:'#f47b20',green:'#268950',cyan:'#00a6bb',purple:'#6d27a6',pink:'#da5696',white:'#f4f4f4',black:'#262626',silver:'#b2b9bb'};
function classify(entries){return entries.slice().sort(function(a,b){var af=Number.isFinite(a.finishSeconds),bf=Number.isFinite(b.finishSeconds);if(af!==bf)return af?-1:1;if(af)return a.finishSeconds-b.finishSeconds||(a.grid||0)-(b.grid||0);if(!!a.dnf!==!!b.dnf)return a.dnf?1:-1;return (b.progress||0)-(a.progress||0)||(a.grid||0)-(b.grid||0)})}
function formatTime(seconds){if(!Number.isFinite(seconds))return '—';var ms=Math.max(0,Math.round(seconds*1000)),minutes=Math.floor(ms/60000);return minutes+':'+String(Math.floor(ms/1000)%60).padStart(2,'0')+'.'+String(ms%1000).padStart(3,'0')}
function text(el,value){el.textContent=value}
function theme(box,winner){var hex=winner&&Object.prototype.hasOwnProperty.call(colors,winner.color)?colors[winner.color]:'#70777e';var n=parseInt(hex.slice(1),16);box.style.setProperty('--results-color-rgb',[(n>>16)&255,(n>>8)&255,n&255].join(','))}
// The supplied rider has no skeleton. Shape only the cloned results mesh into a
// more upright stance; gameplay and the results scene camera stay untouched.
function standRider(model){
 var c=Math.cos(.72),s=Math.sin(.72);
 model.traverse(function(o){
  if(!o.isMesh||!o.geometry||!o.geometry.attributes.position||!/^Pilot_(M_Pilot_0|Decals_M_Pilot_Decals_0)$/.test(o.name))return;
  var geometry=o.geometry.clone(),p=geometry.attributes.position;
  for(var i=0;i<p.count;i++){
   var x=p.getX(i),y=p.getY(i),z=p.getZ(i),up=y*c+z*s,depth=-y*s+z*c;
   var w=Math.max(0,Math.min(1,(.14-up)/.48));w=w*w*(3-2*w);
   up-=.28*w;x*=1-.20*w;depth+=(-.15-depth)*.55*w;
   p.setXYZ(i,x,up*c-depth*s,up*s+depth*c);
  }
  p.needsUpdate=true;geometry.computeVertexNormals();geometry.computeBoundingSphere();o.geometry=geometry;o.userData.resultsStandingGeometry=true;
 });
 return model;
}
function create(options){
 var box=options.box,stage=box.querySelector('.results-stage'),list=box.querySelector('.results-list'),audioButton=box.querySelector('.results-audio'),canvas=box.querySelector('canvas');
 var audio=null,active=false,shown=false,cued=false,start=0,entries=[],renderer=null,scene=null,camera=null,figure=null,loadedModel=null,fadeStart=0,finished=false,renderFailures=0,fadeVolume=null,winnerRevealAt=Infinity,winnerRevealScheduled=false,championshipShown=false,championshipData=null,championshipPending=false,championshipRequestAt=0,championshipUnavailable=false,runId=0;
 function size(){stage.style.setProperty('--results-scale',Math.min(root.innerWidth/1568,root.innerHeight/851))}
 function stopAudio(){if(audio){audio.pause();audio.currentTime=0}audioButton.hidden=true}
 function fadeMusic(progress){if(!audio)return;if(fadeVolume===null)fadeVolume=audio.volume;audio.muted=!!options.muted();audio.volume=fadeVolume*Math.max(0,Math.min(1,1-progress));if(progress>=1)stopAudio()}
 function dispose(){var old=renderer;renderer=null;if(old){if(old.dispose)old.dispose();if(old.forceContextLoss)old.forceContextLoss()}scene=null;camera=null;figure=null;if(loadedModel)loadedModel.traverse(function(o){if(o.userData.resultsStandingGeometry&&o.geometry)o.geometry.dispose()});loadedModel=null}
 function freshCanvas(){var next=root.document.createElement('canvas');canvas.replaceWith(next);canvas=next;next.addEventListener('webglcontextlost',function(event){event.preventDefault();if(!active||canvas!==next||!renderer)return;next.classList.remove('ready');renderFailures++;dispose()})}
 function cancel(){runId++;fadeVolume=null;championshipShown=false;championshipData=null;championshipPending=false;championshipRequestAt=0;championshipUnavailable=false;active=false;shown=false;finished=false;box.classList.remove('visible','winner-reveal','exiting','championship');box.hidden=true;stopAudio();dispose()}
 function play(now){if(!audio)return;fadeStart=typeof now==='number'?now:root.performance.now();audio.volume=0;audio.muted=!!options.muted();var result;try{result=audio.play()}catch(e){audioButton.hidden=false;return}Promise.resolve(result).then(function(){audioButton.hidden=true},function(){if(active)audioButton.hidden=false})}
 audioButton.addEventListener('click',function(){play(root.performance.now())});root.addEventListener('resize',size);
 function begin(now,elapsed,getEntries,circuit){cancel();freshCanvas();renderFailures=0;active=true;cued=false;start=now-Math.max(0,elapsed||0);options.getEntries=getEntries;options.circuit=circuit;if(root.document.fonts&&root.document.fonts.load){['500 77px MGPDisplay','400 112px MGPInline','400 25px MGPText','700 25px MGPText','900 30px MGPText','italic 900 28px MGPText'].forEach(function(font){root.document.fonts.load(font).catch(function(){})})}try{audio=new root.Audio(MUSIC);audio.preload='auto';audio.volume=0;audio.loop=false}catch(e){audio=null}}
 function addRow(item,index,winnerTime){var row=root.document.createElement('div');row.className='results-row';row.style.setProperty('--row',index);var position=root.document.createElement('span');position.className='results-position';text(position,String(index+1));var plate=root.document.createElement('span');plate.className='results-plate';var color=Object.prototype.hasOwnProperty.call(colors,item.color)?item.color:'red';plate.style.backgroundColor=colors[color];plate.style.color=['yellow','white','silver','cyan'].indexOf(color)>=0?'#111':'#fff';text(plate,Number.isInteger(item.number)?String(item.number):'–');
  var name=root.document.createElement('span');name.className='results-name';var parts=(item.name||'Rider').trim().split(/\s+/),last=parts.length>1?parts.pop():'';name.appendChild(root.document.createTextNode(parts.join(' ')+' '));var strong=root.document.createElement('strong');text(strong,last);name.appendChild(strong);
  var pts=root.document.createElement('span');pts.className='results-points';text(pts,Number.isFinite(item.finishSeconds)&&!item.dnf?'+'+racePoints(item,index):item.dnf?'0':'—');var time=root.document.createElement('span');time.className='results-time';text(time,item.dnf?'DNF':!Number.isFinite(item.finishSeconds)?'RACING':index===0?formatTime(item.finishSeconds):Number.isFinite(winnerTime)?'+'+(item.finishSeconds-winnerTime).toFixed(3):'—');var flag=root.document.createElement('span');flag.className='results-flag';text(flag,'—');flag.setAttribute('aria-label','Nationality unavailable');var bike=root.document.createElement('span');bike.className='results-bike';text(bike,'WCM93');row.append(position,plate,name,pts,time,flag,bike);list.appendChild(row)}
 function show(now){var note=box.querySelector('.results-note');if(note)note.hidden=!options.careerEligible||options.careerEligible();text(box.querySelector('.results-winner-word'),'WINNER');var title=box.querySelector('.results-title');if(title)text(title,'GRAND PRIX RESULTS');entries=classify(options.getEntries()||[]);list.replaceChildren();var winner=entries.find(function(e){return Number.isFinite(e.finishSeconds)&&!e.dnf});var winnerTime=winner&&winner.finishSeconds;theme(box,winner);winnerRevealAt=winner?now+2650:Infinity;winnerRevealScheduled=false;if(winner&&root.matchMedia&&root.matchMedia('(prefers-reduced-motion: reduce)').matches)winnerRevealAt=now;entries.slice(0,10).forEach(function(e,i){addRow(e,i,winnerTime)});text(box.querySelector('.results-tag'),options.circuit.hashtag||'');text(box.querySelector('.results-circuit'),options.circuit.name||'');box.querySelector('.results-winner-word').hidden=!winner;box.querySelector('.results-rider').hidden=!winner;size();box.hidden=false;void box.offsetWidth;box.classList.add('visible');shown=true;options.onShow(entries)}

 function requestChampionship(now){
  if(!options.championship||championshipPending||championshipData||championshipUnavailable||now<championshipRequestAt)return;
  championshipRequestAt=now+2000;championshipPending=true;var requestRun=runId;
  Promise.resolve().then(function(){return options.championship()}).then(function(data){
   if(requestRun!==runId)return;championshipPending=false;
   if(data&&data.unavailable){championshipUnavailable=true;if(championshipShown)renderChampionship();return}
   if(data&&data.recorded&&Array.isArray(data.riders)){championshipData=data.riders;if(championshipShown)renderChampionship()}
  },function(){if(requestRun===runId)championshipPending=false});
 }
 function renderChampionship(){
  list.replaceChildren();var values=new Map((championshipData||[]).map(function(p){return [p.id,p.championship_points]}));
  var standings=entries.filter(function(e){return values.has(e.id)&&Number.isInteger(values.get(e.id))&&values.get(e.id)>=0}).sort(function(a,b){return values.get(b.id)-values.get(a.id)||(a.grid||0)-(b.grid||0)||String(a.id).localeCompare(String(b.id))});
  if(!standings.length||standings.length!==entries.length){var notice=root.document.createElement('div');notice.className='results-unavailable';text(notice,championshipData||championshipUnavailable?'Championship standings unavailable for this session':'Waiting for championship points…');list.appendChild(notice);box.querySelector('.results-winner-word').hidden=true;box.querySelector('.results-rider').hidden=true;return}
  box.querySelector('.results-winner-word').hidden=false;box.querySelector('.results-rider').hidden=false;theme(box,standings[0]);standings.slice(0,10).forEach(function(item,index){addRow(item,index,null);var row=list.lastElementChild;row.querySelector('.results-points').textContent=String(values.get(item.id))+' PTS';row.querySelector('.results-time').textContent='';row.querySelector('.results-flag').textContent='';row.querySelector('.results-bike').textContent=''})
 }
 function showChampionship(now){
  championshipShown=true;var note=box.querySelector('.results-note');if(note)note.hidden=true;box.classList.add('championship');box.classList.remove('winner-reveal');
  text(box.querySelector('.results-winner-word'),'LEADER');var title=box.querySelector('.results-title');if(title)text(title,'WORLD CHAMPIONSHIP');
  box.querySelector('.results-winner-word').hidden=false;box.querySelector('.results-rider').hidden=false;
  var content=box.querySelector('.results-content');if(content){content.style.animation='none';void content.offsetWidth;content.style.animation=''}
  canvas.classList.remove('ready');void canvas.offsetWidth;winnerRevealScheduled=false;winnerRevealAt=now+2650;
  if(root.matchMedia&&root.matchMedia('(prefers-reduced-motion: reduce)').matches)winnerRevealAt=now;
  renderChampionship();requestChampionship(now);
 }
 function setup3D(){
  if(!root.THREE||!options.rider()||renderFailures>=2)return;try{var T=root.THREE;renderer=new T.WebGLRenderer({canvas:canvas,alpha:true,antialias:true});renderer.setPixelRatio(Math.min(root.devicePixelRatio||1,1.25));renderer.setSize(500,813,false);if(renderer.setClearColor)renderer.setClearColor(0,0);scene=new T.Scene();camera=new T.PerspectiveCamera(33,500/813,.1,20);camera.position.set(0,.60,3.45);camera.lookAt(0,.49,0);scene.add(new T.HemisphereLight(0xffffff,0x77777f,1.45));var light=new T.DirectionalLight(0xffffff,1.1);light.position.set(-2,4,4);scene.add(light);figure=new T.Group();scene.add(figure);loadedModel=standRider(options.rider().clone(true));loadedModel.position.set(0,.12,0);loadedModel.rotation.x=-.72;figure.add(loadedModel);

  }catch(e){renderFailures++;dispose()}}
 function tick(now){if(!active)return;if(!cued&&now-start>=20000){cued=true;play(now)}if(!shown&&now-start>=23000)show(now);if(shown&&options.championship&&now-start>=23000&&now-start<63000)requestChampionship(now);if(shown&&options.championship&&!championshipShown&&now-start>=43000)showChampionship(now);if(shown&&now-start<63000){if(!renderer&&renderFailures<2){if(renderFailures)freshCanvas();setup3D()}if(renderer&&figure){try{var context=renderer.getContext&&renderer.getContext();if(context&&context.isContextLost&&context.isContextLost())throw Error('Results context lost');var t=(now-start)/1000;figure.rotation.y=.08*Math.sin(t*.45);figure.rotation.z=.015*Math.sin(t*.8);figure.position.y=.008*Math.sin(t*1.3);renderer.render(scene,camera);if(!canvas.classList.contains('ready')&&!winnerRevealScheduled&&!box.classList.contains('winner-reveal')){winnerRevealScheduled=true;winnerRevealAt=Math.min(winnerRevealAt,now+1650)}canvas.classList.add('ready')}catch(e){canvas.classList.remove('ready');renderFailures++;dispose()}}}if(shown&&now>=winnerRevealAt)box.classList.add('winner-reveal');var keepMusic=shown&&options.keepMusic&&options.keepMusic(entries);if(audio){audio.muted=!!options.muted();if(cued)audio.volume=.8*Math.min(1,Math.max(0,(now-fadeStart)/3000))*(keepMusic?1:Math.min(1,Math.max(0,(63000-(now-start))/1000)))}if(shown&&now-start>=63000&&!finished){finished=true;box.classList.add('exiting')}if(finished&&now-start>=63350){active=false;runId++;box.hidden=true;if(!keepMusic)stopAudio();dispose();options.onEnd(entries)}}
 return {begin:begin,tick:tick,cancel:cancel,fadeMusic:fadeMusic,isActive:function(){return active},isShown:function(){return shown&&active},entries:function(){return entries}};
}
root.WMCRaceResults={create:create,classify:classify,formatTime:formatTime,standRider:standRider,racePoints:racePoints};if(typeof module!=='undefined'&&module.exports)module.exports=root.WMCRaceResults;
})(typeof window!=='undefined'?window:globalThis);
