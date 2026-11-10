(function(){
  'use strict';
  class RaceTransport {
    constructor(url,handlers){this.url=url;this.handlers=handlers;this.ws=null;this.ready=false}
    connect(token){if(this.ws&&this.ws.readyState<2)return;const ws=new WebSocket(this.url);this.ws=ws;
      ws.onopen=()=>ws.send(JSON.stringify({type:'auth',token}));
      ws.onmessage=e=>{if(this.ws!==ws)return;let msg;try{msg=JSON.parse(e.data)}catch{return}if(msg.type==='ready'){this.ready=true;this.handlers.status(true)}else if(msg.type==='snapshot')this.handlers.snapshot(msg);else if(msg.type==='error')this.handlers.error(msg.message)};
      ws.onerror=()=>{};ws.onclose=()=>{if(this.ws!==ws)return;this.ws=null;this.ready=false;this.handlers.status(false)};
    }
    send(type,input){if(!this.ready||!this.ws||this.ws.readyState!==WebSocket.OPEN)return false;this.ws.send(JSON.stringify({type,input}));return true}
    close(){const ws=this.ws;this.ws=null;this.ready=false;if(ws)ws.close()}
  }
  window.WMCRaceTransport=RaceTransport;
})();
