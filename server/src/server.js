import http from 'node:http';
import {WebSocketServer,WebSocket} from 'ws';
import {RaceRoom} from './race.js';
import {AuthError} from './auth.js';
export function createServer({authenticate,allowedOrigins,recordResult=null,diagnostics=null,now=Date.now,heartbeatMs=15000,authGraceMs=120000}){
  if(typeof authenticate!=='function'||!allowedOrigins?.length)throw Error('Authentication and origins required');
  const rooms=new Map(),sockets=new Map(),allowed=new Set(allowedOrigins),replays=new Map(),uploads=new Set();
  const MAX_REPLAY=48*1024*1024,MAX_REPLAY_TOTAL=96*1024*1024,REPLAY_TTL=5*60*1000;
  function winner(room){if(!room||!(room.phase==='race'||room.phase==='complete'&&room.completedPhase==='race'))return null;return [...room.players.values()].filter(p=>!p.dnf&&Number.isFinite(p.finishAt)).sort((a,b)=>a.finishAt-b.finishAt||a.grid-b.grid)[0]||null}
  function pruneReplays(){for(const [key,clip] of replays)if(now()-clip.created>REPLAY_TTL||rooms.get(clip.roomId)!==clip.room||clip.room.matchId!==key)replays.delete(key)}
  async function replayRequest(req,res,matchId){
    const origin=req.headers.origin;if(!allowed.has(origin)){res.writeHead(403);res.end();return}
    const cors={'access-control-allow-origin':origin,'vary':'Origin','access-control-allow-methods':'GET, POST, OPTIONS','access-control-allow-headers':'Authorization, Content-Type, X-WMC-Duration','access-control-expose-headers':'X-WMC-Duration, X-WMC-Winner','cache-control':'no-store'};
    if(req.method==='OPTIONS'){res.writeHead(204,cors);res.end();return}
    if(req.method!=='GET'&&req.method!=='POST'){res.writeHead(405,cors);res.end();return}
    const token=(req.headers.authorization||'').match(/^Bearer (\S{1,8192})$/);let auth;try{if(!token)throw Error();auth=await authenticate(token[1])}catch{res.writeHead(401,cors);res.end();return}
    const room=rooms.get(auth.lobby?.id),rider=room?.players.get(auth.userId),leader=winner(room);
    if(!auth.userId||auth.profile?.id!==auth.userId||!rider||!room||room.matchId!==matchId){res.writeHead(403,cors);res.end();return}
    pruneReplays();
    if(req.method==='GET'){const clip=replays.get(matchId);if(!clip||!leader||leader.profile.id!==clip.winner){res.writeHead(404,cors);res.end();return}res.writeHead(200,{...cors,'content-type':clip.type,'content-length':clip.data.length,'x-wmc-duration':String(clip.duration),'x-wmc-winner':clip.winner,'x-content-type-options':'nosniff'});res.end(clip.data);return}
    if(!leader||leader.profile.id!==auth.userId||rider.ai){res.writeHead(403,cors);res.end();return}
    if(replays.has(matchId)){res.writeHead(200,cors);res.end();return}
    const type=(req.headers['content-type']||'').split(';')[0].trim().toLowerCase(),duration=Number(req.headers['x-wmc-duration']),length=Number(req.headers['content-length']);
    if(!['video/webm','video/mp4'].includes(type)||!Number.isFinite(duration)||duration<200||duration>21000||Number.isFinite(length)&&length>MAX_REPLAY){res.writeHead(400,cors);res.end();return}
    if(uploads.has(matchId)||uploads.size>=2){res.writeHead(429,cors);res.end();return}
    uploads.add(matchId);let total=0,chunks=[];req.setTimeout(60000,()=>req.destroy());const uploadDeadline=setTimeout(()=>req.destroy(),90000);uploadDeadline.unref();
    try{for await(const chunk of req){total+=chunk.length;if(total>MAX_REPLAY){res.writeHead(413,cors);res.end();req.resume();return}chunks.push(chunk)}
      if(!total||rooms.get(room.id)!==room||room.matchId!==matchId||winner(room)?.profile.id!==auth.userId){res.writeHead(409,cors);res.end();return}
      pruneReplays();let used=0;for(const [key,clip] of replays)if(key!==matchId)used+=clip.data.length;if(used+total>MAX_REPLAY_TOTAL){res.writeHead(503,cors);res.end();return}
      replays.set(matchId,{room,roomId:room.id,winner:auth.userId,data:Buffer.concat(chunks,total),duration,type,created:now()});res.writeHead(201,cors);res.end();
    }catch{if(!res.headersSent&&!res.destroyed){res.writeHead(400,cors);res.end()}}finally{clearTimeout(uploadDeadline);uploads.delete(matchId)}
  }
  const server=http.createServer(async (req,res)=>{
    const headers={'content-type':'application/json','cache-control':'no-store'};
    const path=new URL(req.url,'http://localhost').pathname,match=path.match(/^\/replay\/([a-zA-Z0-9-]{1,80})$/);if(match){await replayRequest(req,res,match[1]);return}
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
  const sendEncoded=(ws,payload)=>{if(ws.readyState===WebSocket.OPEN&&ws.bufferedAmount<100000)ws.send(payload)};
  const send=(ws,msg)=>sendEncoded(ws,JSON.stringify(msg));
  wss.on('connection',ws=>{let state='auth',id,room,token,alive=true,checking=false,count=0,windowStart=now(),authFailureAt=null;
    const authTimeout=setTimeout(()=>{if(state!=='ready')ws.close(1008,'authentication timeout')},10000);
    ws.on('pong',()=>alive=true);ws.on('error',()=>{});
    ws.on('message',async raw=>{if(now()-windowStart>=1000){windowStart=now();count=0}if(++count>60){ws.close(1008,'rate limit');return}
      let msg;try{msg=JSON.parse(raw.toString())}catch{ws.close(1007,'invalid JSON');return}if(!msg||typeof msg!=='object'||Array.isArray(msg)){ws.close(1007,'invalid message');return}
      if(state==='auth'){if(msg.type!=='auth'||typeof msg.token!=='string'||msg.token.length>8192){ws.close(1008,'authentication required');return}state='checking';try{const a=await authenticate(msg.token);if(ws.readyState!==WebSocket.OPEN)return;if(!a.userId||a.profile?.id!==a.userId||!a.lobby?.id||!['race','qualifying_race'].includes(a.lobby.mode))throw Error();id=a.userId;token=msg.token;room=rooms.get(a.lobby.id);if(!room){room=new RaceRoom(a.lobby);rooms.set(a.lobby.id,room)}if(room.host!==a.lobby.host_id||room.mode!==a.lobby.mode)throw Error();room.join(a.profile,now());const old=sockets.get(id);if(old&&old.room&&old.room!==room)old.room.disconnect(id,now());ws.room=room;sockets.set(id,ws);if(old)old.close(1008,'replaced');state='ready';clearTimeout(authTimeout);send(ws,{type:'ready',id,latencyPing:true})}catch(e){if(e instanceof AuthError){console.warn('Race connection:',e.code,e.status||'',e.upstreamCode||'',e.kind||'');ws.close(1008,e.message)}else{console.warn('Race connection: ROOM_VALIDATION_FAILED');ws.close(1008,'Race room validation failed')}}return}
      if(state!=='ready'||sockets.get(id)!==ws)return;
      if(msg.type==='refresh_auth'){if(typeof msg.token!=='string'||!msg.token||msg.token.length>8192)return;try{const a=await authenticate(msg.token);if(sockets.get(id)!==ws||ws.readyState!==WebSocket.OPEN)return;if(a.userId!==id||a.lobby?.id!==room.id){ws.close(1008,'lobby access ended');return}token=msg.token;authFailureAt=null;send(ws,{type:'auth_refreshed'})}catch(e){console.warn('Race token refresh failed:',e.code||'unknown');send(ws,{type:'auth_refresh_failed'})}return}
      try{if(msg.type==='ping'){if(typeof msg.input==='number'&&Number.isFinite(msg.input))send(ws,{type:'pong',input:msg.input})}else if(msg.type==='input')room.input(id,msg.input,now());else if(msg.type==='start')room.start(id,now());else if(msg.type==='fill_ai')room.setAI(id,msg.input);else if(msg.type==='race_laps')room.setRaceLaps(id,msg.input);else if(msg.type==='circuit')room.setCircuit(id,msg.input);else if(msg.type==='circuit_ready')room.readyCircuit(id,msg.input);else if(msg.type==='reset')room.reset(id);else if(msg.type==='emote'){if(!room.emote(id,msg.input,now()))throw Error('Emote unavailable; wheelies require movement.')}else if(msg.type==='chat'){const chat=room.chat(id,msg.input,now());if(!chat)throw Error('Chat message not sent; wait a moment and try again.');for(const p of room.players.values()){const peer=sockets.get(p.profile.id);if(peer&&peer.room===room)send(peer,chat)}}else if(msg.type==='leave'){room.leave(id,now());ws.close(1000,'left session')}else throw Error('Unknown command')}catch(e){send(ws,{type:'error',message:e.message})}
    });
    const check=setInterval(async()=>{if(!alive){ws.terminate();return}alive=false;ws.ping();if(state!=='ready'||checking)return;checking=true;const checkedToken=token;try{const a=await authenticate(checkedToken);if(checkedToken!==token)return;authFailureAt=null;if(a.userId!==id||a.lobby?.id!==room.id)ws.close(1008,'lobby access ended')}catch(e){if(checkedToken!==token)return;
      // Network and upstream outages are not proof of revoked access. Keep the
      // already-authenticated socket alive briefly and retry, but fail closed.
      if(e instanceof AuthError&&e.code==='LOBBY_MISSING'){ws.close(1008,'lobby access ended');return}
      if(authFailureAt===null)authFailureAt=now();if(now()-authFailureAt>=authGraceMs)ws.close(1013,'authentication service unavailable');
    }finally{checking=false}},heartbeatMs);check.unref();
    ws.on('close',()=>{clearTimeout(authTimeout);clearInterval(check);if(id&&sockets.get(id)===ws){sockets.delete(id);room.disconnect(id,now())}});
  });
  let last=now(),acc=0,broadcast=last;const timer=setInterval(()=>{const t=now();acc+=Math.min(250,Math.max(0,t-last));last=t;while(acc>=1000/60){for(const r of rooms.values())r.advance(t,1/60);acc-=1000/60}if(t-broadcast>=100){broadcast=t;pruneReplays();for(const [id,r] of rooms){const snapshot=r.snapshot(t);if(recordResult&&!snapshot.players.some(p=>p.ai)&&snapshot.events.some(e=>e.type==='results')){const save=async attempt=>{try{await recordResult(snapshot)}catch{if(attempt<5){const retry=setTimeout(()=>save(attempt+1),Math.min(30000,1000*2**attempt));retry.unref()}else console.error('Could not save race results after retries')}};save(0)}const payload=JSON.stringify({type:'snapshot',...snapshot});for(const p of r.players.values()){const ws=sockets.get(p.profile.id);if(ws&&ws.room===r)sendEncoded(ws,payload)}if(!r.players.size||(r.phase==='complete'&&[...r.players.values()].every(p=>p.ai||!p.connected))||(r.fillAI&&r.phase!=='lobby'&&[...r.players.values()].filter(p=>!p.ai).every(p=>!p.connected&&p.disconnectedAt!==null&&t-p.disconnectedAt>=30000)))rooms.delete(id)}}},1000/60);timer.unref();
  return {server,rooms,close:()=>{clearInterval(timer);for(const ws of wss.clients)ws.terminate();return new Promise(resolve=>wss.close(()=>server.close(resolve)))}};
}
