import http from 'node:http';
import {WebSocketServer,WebSocket} from 'ws';
import {RaceRoom} from './race.js';
import {AuthError} from './auth.js';
export function createServer({authenticate,allowedOrigins,recordResult=null,diagnostics=null,now=Date.now}){
  if(typeof authenticate!=='function'||!allowedOrigins?.length)throw Error('Authentication and origins required');
  const rooms=new Map(),sockets=new Map(),allowed=new Set(allowedOrigins);
  const server=http.createServer(async (req,res)=>{
    const headers={'content-type':'application/json','cache-control':'no-store'};
    if(req.method==='GET'&&req.url==='/health'){res.writeHead(200,headers);res.end('{"ok":true}');return}
    if(req.method==='GET'&&new URL(req.url,'http://localhost').pathname==='/health/diagnostics'&&diagnostics){
      try{const info=await diagnostics();res.writeHead(200,headers);res.end(JSON.stringify(info))}
      catch{res.writeHead(503,headers);res.end('{"ok":false}')}
      return;
    }
    res.writeHead(404,headers);res.end('{"error":"not found"}');
  });
  const wss=new WebSocketServer({noServer:true,maxPayload:4096,perMessageDeflate:false});
  server.on('upgrade',(req,socket,head)=>{if(req.url!=='/race'||!allowed.has(req.headers.origin)){socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');socket.destroy();return}wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws))});
  const send=(ws,msg)=>{if(ws.readyState===WebSocket.OPEN&&ws.bufferedAmount<100000)ws.send(JSON.stringify(msg))};
  wss.on('connection',ws=>{let state='auth',id,room,token,alive=true,checking=false,count=0,windowStart=now();
    const authTimeout=setTimeout(()=>{if(state!=='ready')ws.close(1008,'authentication timeout')},10000);
    ws.on('pong',()=>alive=true);ws.on('error',()=>{});
    ws.on('message',async raw=>{if(now()-windowStart>=1000){windowStart=now();count=0}if(++count>60){ws.close(1008,'rate limit');return}
      let msg;try{msg=JSON.parse(raw.toString())}catch{ws.close(1007,'invalid JSON');return}if(!msg||typeof msg!=='object'||Array.isArray(msg)){ws.close(1007,'invalid message');return}
      if(state==='auth'){if(msg.type!=='auth'||typeof msg.token!=='string'||msg.token.length>8192){ws.close(1008,'authentication required');return}state='checking';try{const a=await authenticate(msg.token);if(ws.readyState!==WebSocket.OPEN)return;if(!a.userId||a.profile?.id!==a.userId||!a.lobby?.id||!['race','qualifying_race'].includes(a.lobby.mode))throw Error();id=a.userId;token=msg.token;room=rooms.get(a.lobby.id);if(!room){room=new RaceRoom(a.lobby);rooms.set(a.lobby.id,room)}if(room.host!==a.lobby.host_id||room.mode!==a.lobby.mode)throw Error();room.join(a.profile,now());const old=sockets.get(id);if(old&&old.room&&old.room!==room)old.room.disconnect(id,now());ws.room=room;sockets.set(id,ws);if(old)old.close(1008,'replaced');state='ready';clearTimeout(authTimeout);send(ws,{type:'ready',id})}catch(e){if(e instanceof AuthError){console.warn('Race connection:',e.code,e.status||'',e.upstreamCode||'',e.kind||'');ws.close(1008,e.message)}else{console.warn('Race connection: ROOM_VALIDATION_FAILED');ws.close(1008,'Race room validation failed')}}return}
      if(state!=='ready')return;
      try{if(msg.type==='input')room.input(id,msg.input,now());else if(msg.type==='start')room.start(id,now());else if(msg.type==='reset')room.reset(id);else if(msg.type==='leave'){room.leave(id,now());ws.close(1000,'left session')}else throw Error('Unknown command')}catch(e){send(ws,{type:'error',message:e.message})}
    });
    const check=setInterval(async()=>{if(!alive){ws.terminate();return}alive=false;ws.ping();if(state!=='ready'||checking)return;checking=true;try{const a=await authenticate(token);if(a.userId!==id||a.lobby?.id!==room.id)ws.close(1008,'lobby access ended')}catch{ws.close(1008,'session expired')}finally{checking=false}},15000);check.unref();
    ws.on('close',()=>{clearTimeout(authTimeout);clearInterval(check);if(id&&sockets.get(id)===ws){sockets.delete(id);room.disconnect(id,now())}});
  });
  let last=now(),acc=0,broadcast=last;const timer=setInterval(()=>{const t=now();acc+=Math.min(250,Math.max(0,t-last));last=t;while(acc>=1000/60){for(const r of rooms.values())r.advance(t,1/60);acc-=1000/60}if(t-broadcast>=100){broadcast=t;for(const [id,r] of rooms){const snapshot=r.snapshot(t);if(recordResult&&snapshot.events.some(e=>e.type==='results')){const save=async attempt=>{try{await recordResult(snapshot)}catch{if(attempt<5){const retry=setTimeout(()=>save(attempt+1),Math.min(30000,1000*2**attempt));retry.unref()}else console.error('Could not save race results after retries')}};save(0)}for(const p of r.players.values()){const ws=sockets.get(p.profile.id);if(ws&&ws.room===r)send(ws,{type:'snapshot',...snapshot})}if(!r.players.size||(r.phase==='complete'&&[...r.players.values()].every(p=>!p.connected)))rooms.delete(id)}}},1000/60);timer.unref();
  return {server,rooms,close:()=>{clearInterval(timer);for(const ws of wss.clients)ws.terminate();return new Promise(resolve=>wss.close(()=>server.close(resolve)))}};
}
