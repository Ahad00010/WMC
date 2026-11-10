import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {JSDOM} from 'jsdom';import WebSocket from 'ws';import {createServer} from '../src/server.js';
const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8'),transport=readFileSync(new URL('../../race-transport.js',import.meta.url),'utf8'),lobbyScript=readFileSync(new URL('../../lobby.js',import.meta.url),'utf8');const sleep=ms=>new Promise(r=>setTimeout(r,ms));async function until(f){for(let i=0;i<120;i++){if(f())return;await sleep(25)}throw Error('client timeout')}
test('browser lobby transport connects two riders and starts one synchronized race',async t=>{
 const players=['a','b'].map(id=>({id,username:id,display_name:id,number:1,color:'red'})),lobby={id:'l',host_id:'a',mode:'race',members:players};const app=createServer({allowedOrigins:['http://test.local'],authenticate:async token=>({userId:token,lobby,profile:players.find(p=>p.id===token)})});await new Promise(r=>app.server.listen(0,'127.0.0.1',r));t.after(()=>app.close());const url=`ws://127.0.0.1:${app.server.address().port}/race`;
 function client(id){const dom=new JSDOM(html,{url:'http://test.local',runScripts:'outside-only'}),w=dom.window;let last=null,active=true;class Socket extends WebSocket{constructor(u){super(u,{origin:'http://test.local'})}}w.WebSocket=Socket;w.WMC_RACE_SERVER_URL=url;w.document.getElementById('start').disabled=false;w.WMCCurrentCircuit='assen';w.eval(readFileSync(new URL('../../circuits.js',import.meta.url),'utf8'));w.WMCAuth={client:{auth:{getSession:async()=>({data:{session:{access_token:id}}})},rpc:async(name,args)=>{if(name==='wmc_lobby_action'&&args.action==='leave')active=false;return {data:name==='wmc_lobby_snapshot'?{user_id:id,lobby:active?lobby:null,invites:[],server_time:new Date().toISOString()}:[],error:null}}}};w.WMCGame={network(){},input:()=>({up:false,down:false,left:false,right:false,brake:false}),authoritativeReceive(m){last=m}};w.eval(transport);w.eval(lobbyScript);w.document.getElementById('modeOverlay').hidden=false;w.document.getElementById('multiModes').hidden=false;w.dispatchEvent(new w.Event('wmc-lobby-open'));return {w,get last(){return last}}}
 const a=client('a'),b=client('b');t.after(()=>{a.w.close();b.w.close()});await until(()=>!a.w.document.getElementById('resumeLobby').hidden);await until(()=>app.rooms.get('l')?.players.size===2);app.rooms.get('l').setCircuit('a','assen');a.w.document.getElementById('resumeLobby').click();await until(()=>app.rooms.get('l').players.size===2&&[...app.rooms.get('l').players.values()].every(p=>p.circuitReady));assert.match(a.w.document.getElementById('lobbyMode').textContent,/TT CIRCUIT ASSEN/);await until(()=>!a.w.document.getElementById('startMultiplayer').disabled);a.w.document.getElementById('startMultiplayer').click();await until(()=>a.last?.phase==='race'&&b.last?.phase==='race');assert.equal(a.last.matchId,b.last.matchId);assert.equal(a.last.players.length,2);await a.w.WMCMatch.leave();await b.w.WMCMatch.leave();await sleep(100);
});

test('leaving blocks stale snapshots and reconnects until lobby leave succeeds',async t=>{
 const dom=new JSDOM(html,{url:'http://test.local',runScripts:'outside-only'}),w=dom.window;t.after(()=>w.close());
 let resolveSnapshot,resolveLeave,calls=0,connections=0,received=0;
 const lobby={id:'l',mode:'race',host_id:'a',members:[]};
 w.WMC_RACE_SERVER_URL='ws://test.local';
 w.WMCRaceTransport=class {constructor(url,handlers){this.handlers=handlers;connections++}connect(){this.ws={};this.ready=true}close(){this.ws=null}send(){}};
 w.WMCAuth={client:{auth:{getSession:async()=>({data:{session:{access_token:'a'}}})},rpc:async(name)=>{
   if(name==='wmc_lobby_snapshot'){calls++;return new Promise(r=>{resolveSnapshot=r})}
   if(name==='wmc_lobby_action')return new Promise(r=>{resolveLeave=r});return {data:[],error:null};
 }}};
 w.WMCGame={network(){},input:()=>({}),authoritativeReceive(){received++}};w.eval(lobbyScript);
 await until(()=>resolveSnapshot);const leaving=w.WMCMatch.leave();await until(()=>resolveLeave);
 resolveSnapshot({data:{user_id:'a',lobby,invites:[],server_time:new Date().toISOString()},error:null});await sleep(20);
 assert.equal(connections,0);assert.equal(received,0);assert.equal(w.document.getElementById('resumeLobby').hidden,true);
 resolveLeave({error:null});assert.equal(await leaving,true);assert.equal(w.sessionStorage.getItem('wmc-leaving'),null);
});

test('active client keeps race connection when host leaving deletes the lobby',async t=>{
 const dom=new JSDOM(html,{url:'http://test.local',runScripts:'outside-only'}),w=dom.window;t.after(()=>w.close());let active=true,instance,received=0;
 const lobby={id:'l',mode:'race',host_id:'a',members:[{id:'b',display_name:'B',username:'b',number:2}]};
 w.WMC_RACE_SERVER_URL='ws://test.local';w.WMCRaceTransport=class{constructor(url,handlers){instance=this;this.handlers=handlers;this.closed=false}connect(){this.ws={};this.ready=true}close(){this.closed=true;this.ws=null}send(){}};
 w.WMCAuth={client:{auth:{getSession:async()=>({data:{session:{access_token:'b'}}})},rpc:async name=>({data:name==='wmc_lobby_snapshot'?{user_id:'b',lobby:active?lobby:null,invites:[],server_time:new Date().toISOString()}:[],error:null})}};
 w.WMCGame={inSession:()=>true,network(){},input:()=>({}),authoritativeReceive(){received++}};w.eval(lobbyScript);await until(()=>instance?.ready);
 active=false;w.dispatchEvent(new w.Event('wmc-lobby-open'));await sleep(50);assert.equal(instance.closed,false);instance.handlers.snapshot({phase:'complete',players:[]});assert.equal(received,1);
});

test('chat arriving just before the first match snapshot is shown once the game enters',async t=>{
 const dom=new JSDOM(html,{url:'http://test.local',runScripts:'outside-only'}),w=dom.window;t.after(()=>w.close());let instance,inSession=false,received=[];
 const lobby={id:'l',mode:'race',host_id:'a',members:[{id:'b',display_name:'B',username:'b',number:66,color:'blue'}]};
 w.WMC_RACE_SERVER_URL='ws://test.local';w.WMCRaceTransport=class{constructor(url,handlers){instance=this;this.handlers=handlers}connect(){this.ws={};this.ready=true}close(){this.ws=null}send(){}};
 w.WMCAuth={client:{auth:{getSession:async()=>({data:{session:{access_token:'b'}}})},rpc:async name=>({data:name==='wmc_lobby_snapshot'?{user_id:'b',lobby,invites:[],server_time:new Date().toISOString()}:[],error:null})}};
 w.WMCGame={inSession:()=>inSession,network(){},input:()=>({}),authoritativeReceive(){inSession=true},receiveChat(m){received.push(m)}};w.eval(lobbyScript);await until(()=>instance?.ready);
 const message={id:'a',name:'A',text:'hello',number:13,color:'red'};instance.handlers.chat(message);assert.equal(received.length,0);instance.handlers.snapshot({phase:'race',players:[]});assert.equal(received.length,1);assert.equal(received[0].text,'hello');instance.handlers.snapshot({phase:'race',players:[]});assert.equal(received.length,1);
});

test('choosing multiplayer circuit configures the room and confirms local track readiness',async t=>{
 const dom=new JSDOM(html,{url:'http://test.local',runScripts:'outside-only'}),w=dom.window;t.after(()=>w.close());let instance,lobby=null;const sent=[];
 w.WMC_RACE_SERVER_URL='ws://test.local';w.document.getElementById('start').disabled=false;w.WMCCurrentCircuit='assen';w.eval(readFileSync(new URL('../../circuits.js',import.meta.url),'utf8'));w.WMCCircuitSelect=(where,choose)=>{assert.equal(where,'multiplayer');choose('assen')};
 w.WMCRaceTransport=class{constructor(url,handlers){instance=this;this.handlers=handlers}connect(){this.ws={};this.ready=true;this.handlers.status(true)}close(){}send(type,input){sent.push([type,input]);return true}};
 w.WMCAuth={client:{auth:{getSession:async()=>({data:{session:{access_token:'a'}}})},rpc:async(name,args)=>{if(name==='wmc_lobby_action'&&args.action==='create')lobby={id:'l',host_id:'a',mode:'race',members:[{id:'a',display_name:'A',username:'a',number:13}]};return {data:name==='wmc_lobby_snapshot'?{user_id:'a',lobby,invites:[],server_time:new Date().toISOString()}:[],error:null}}}};
 w.WMCGame={network(){},input:()=>({}),authoritativeReceive(){},inSession:()=>false};w.eval(lobbyScript);w.document.getElementById('multiRace').click();await until(()=>instance?.ready);
 instance.handlers.snapshot({phase:'lobby',circuit:'sepang',circuitConfigured:false,players:[{id:'a',connected:true}]});assert.deepEqual(sent.find(x=>x[0]==='circuit'),['circuit','assen']);
 instance.handlers.snapshot({phase:'lobby',circuit:'assen',circuitConfigured:true,players:[{id:'a',connected:true,circuitReady:false}]});assert.deepEqual(sent.find(x=>x[0]==='circuit_ready'),['circuit_ready','assen']);assert.match(w.document.getElementById('lobbyMode').textContent,/TT CIRCUIT ASSEN/);assert.equal(w.document.getElementById('startMultiplayer').disabled,true);
});
