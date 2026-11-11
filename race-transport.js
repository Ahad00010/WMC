(function(){
  'use strict';
  class RaceTransport {
    constructor(url,handlers){this.url=url;this.handlers=handlers;this.ws=null;this.ready=false;this.token=null;this.pendingToken=null;this.pendingPing=null;this.canPing=false;this.lastReceived=0}
    connect(token){this.token=token;this.pendingToken=null;if(this.ws&&this.ws.readyState<2)return;const ws=new WebSocket(this.url);this.ws=ws;
      ws.onopen=()=>ws.send(JSON.stringify({type:'auth',token}));
      ws.onmessage=e=>{if(this.ws!==ws)return;this.lastReceived=performance.now();let msg;try{msg=JSON.parse(e.data)}catch{return}if(msg.type==='auth_refresh_failed'){this.pendingToken=null}else if(msg.type==='auth_refreshed'){this.token=this.pendingToken;this.pendingToken=null}else if(msg.type==='ready'){this.ready=true;this.canPing=msg.latencyPing===true;this.handlers.status(true);this.ping()}else if(msg.type==='pong'&&msg.input===this.pendingPing){const rtt=performance.now()-this.pendingPing;this.pendingPing=null;if(rtt>=0&&rtt<5000&&this.handlers.latency)this.handlers.latency(rtt/2)}else if(msg.type==='snapshot')this.handlers.snapshot(msg);else if(msg.type==='chat'&&this.handlers.chat)this.handlers.chat(msg);else if(msg.type==='error')this.handlers.error(msg.message)};
      ws.onerror=()=>{};ws.onclose=e=>{if(this.ws!==ws)return;this.ws=null;this.ready=false;this.pendingToken=null;this.pendingPing=null;this.canPing=false;this.handlers.status(false,e.code,e.reason)};
    }
    ping(){if(!this.ready)return;const stamp=performance.now();if(stamp-this.lastReceived>15000){const ws=this.ws;this.ws=null;this.ready=false;this.pendingPing=null;this.canPing=false;if(ws)ws.close();this.handlers.status(false,1006,'connection timed out');return}if(!this.canPing)return;if(this.pendingPing!==null){if(stamp-this.pendingPing<5000)return;this.pendingPing=null}if(this.send('ping',stamp))this.pendingPing=stamp}
    refreshAuth(token){if(!token||token===this.token||token===this.pendingToken||!this.ready||!this.ws||this.ws.readyState!==WebSocket.OPEN)return;this.pendingToken=token;this.ws.send(JSON.stringify({type:'refresh_auth',token}))}
    send(type,input){if(!this.ready||!this.ws||this.ws.readyState!==WebSocket.OPEN)return false;this.ws.send(JSON.stringify({type,input}));return true}
    close(){const ws=this.ws;this.ws=null;this.ready=false;this.pendingPing=null;this.canPing=false;if(ws)ws.close()}
  }
  window.WMCRaceTransport=RaceTransport;
})();
