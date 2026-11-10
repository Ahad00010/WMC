/* Shared menu soundtrack. Playback can require a browser user gesture. */
(function(root){
  'use strict';
  function create(audio,showPrompt){
    var active=false,muted=false,blocked=false,pending=false,started=false,last=null,volume=0,request=0;
    audio.loop=true;audio.preload='metadata';audio.volume=0;
    function prompt(show){if(showPrompt)showPrompt(show)}
    function attempt(gesture){
      if(!active||muted||!audio.paused||blocked&&!gesture)return;
      if(pending){if(!gesture)return;request++;pending=false}
      if(gesture)blocked=false;
      pending=true;var id=++request,result;
      try{result=audio.play()}catch(e){pending=false;blocked=true;prompt(true);return}
      Promise.resolve(result).then(function(){
        if(id!==request)return;pending=false;blocked=false;started=true;prompt(false);if(!active&&volume===0)audio.pause();
      },function(){if(id!==request)return;pending=false;blocked=true;prompt(true)});
    }
    function tick(now,wantActive,isMuted){
      active=wantActive;muted=isMuted;audio.muted=muted;
      var dt=last==null?0:Math.max(0,Math.min(.1,(now-last)/1000));last=now;
      if(active&&!muted)attempt(false);
      var target=active&&!muted?.55:0,amount=dt*.55/.85;
      volume=target>volume?Math.min(target,volume+amount):Math.max(target,volume-amount);audio.volume=volume;
      if(!active&&volume===0&&!audio.paused){audio.pause();request++;pending=false}
    }
    return {tick:tick,unlock:function(){attempt(true)},hasStarted:function(){return started}};
  }
  root.WMCMenuMusic={create:create};if(typeof module!=='undefined'&&module.exports)module.exports=root.WMCMenuMusic;
})(typeof window!=='undefined'?window:globalThis);
