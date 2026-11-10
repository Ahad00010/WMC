(function(){
  'use strict';
  class RaceTransport {
    constructor(url,handlers){this.url=url;this.handlers=handlers;this.ws=null;this.ready=false;this.token=null;this.pendingToken=null}
    connect(token){this.token=token;this.pendingToken=null;if(this.ws&&this.ws.readyState<2)return;const ws=new WebSocket(this.url);this.ws=ws;
      ws.onopen=()=>ws.send(JSON.stringify({type:'auth',token}));
      ws.onmessage=e=>{if(this.ws!==ws)return;let msg;try{msg=JSON.parse(e.data)}catch{return}if(msg.type==='auth_refresh_failed'){this.pendingToken=null}else if(msg.type==='auth_refreshed'){this.token=this.pendingToken;this.pendingToken=null}else if(msg.type==='ready'){this.ready=true;this.handlers.status(true)}else if(msg.type==='snapshot')this.handlers.snapshot(msg);else if(msg.type==='chat'&&this.handlers.chat)this.handlers.chat(msg);else if(msg.type==='error')this.handlers.error(msg.message)};
      ws.onerror=()=>{};ws.onclose=e=>{if(this.ws!==ws)return;this.ws=null;this.ready=false;this.pendingToken=null;this.handlers.status(false,e.code,e.reason)};
    }
    refreshAuth(token){if(!token||token===this.token||token===this.pendingToken||!this.ready||!this.ws||this.ws.readyState!==WebSocket.OPEN)return;this.pendingToken=token;this.ws.send(JSON.stringify({type:'refresh_auth',token}))}
    send(type,input){if(!this.ready||!this.ws||this.ws.readyState!==WebSocket.OPEN)return false;this.ws.send(JSON.stringify({type,input}));return true}
    close(){const ws=this.ws;this.ws=null;this.ready=false;if(ws)ws.close()}
  }
  window.WMCRaceTransport=RaceTransport;
})();
