import {randomUUID,randomInt} from 'node:crypto';
import defaultTrack,{getTrack} from './track.js';
import sectorColor from '../../qualifying-colors.js';
import {createPhysics,parseInput,neutralInput} from './physics.js';
import {createAI} from './ai.js';
export const MAX_RIDERS=10,RACE_LAPS=3,QUALIFYING_ATTEMPTS=3,QUALIFYING=240000;
const COUNTDOWN=22000,GRACE=30000,RESULT_DELAY=10000,QUALIFYING_RESULTS_DELAY=15000,GRID_COUNTDOWN=15000;
export class RaceRoom {
  constructor(lobby,track=defaultTrack){this.track=track;this.physics=createPhysics(track);this.aiInput=createAI(track);this.id=lobby.id;this.host=lobby.host_id;this.mode=lobby.mode;this.phase='lobby';this.players=new Map();this.events=[];this.matchId=null;this.phaseStart=0;this.resultsAt=null;this.endReason=null;this.fillAI=false;this.circuit='sepang';this.circuitConfigured=false}
  join(profile,now){let p=this.players.get(profile.id);if(p){if(p.dnf)throw Error('Rider has retired');p.connected=true;p.disconnectedAt=null;p.circuitReady=false;p.input=neutralInput();p.inputAt=now;return}
    if(this.phase!=='lobby')throw Error('Race already started');if(this.players.size>=MAX_RIDERS)throw Error('Lobby full');
    this.players.set(profile.id,{profile,connected:true,disconnectedAt:null,input:neutralInput(),inputAt:now,grid:0,state:null,best:null,attempts:0,flying:false,invalid:false,completed:false,dnf:false,finishAt:null,lap:1,lapStart:0,sector:0,line:0});}
  disconnect(id,now){let p=this.players.get(id);if(!p)return;p.connected=false;p.input=neutralInput();p.disconnectedAt=now;if(this.phase==='lobby'){this.players.delete(id);return}}
  leave(id,now){const p=this.players.get(id);if(!p)return;if(this.phase!=='lobby'&&!p.completed){p.dnf=true;p.completed=true;this.events.push({type:'dnf',id})}this.disconnect(id,now);if(this.phase!=='lobby'&&this.phase!=='complete'&&[...this.players.values()].filter(p=>!p.ai).length===2){this.phase='complete';this.endReason='opponent_left';this.events.push({type:'session_ended',reason:this.endReason})}}
  input(id,raw,now){const p=this.players.get(id),input=parseInput(raw);if(!p||!p.connected||!input)return false;p.input=input;p.inputAt=now;return true}
  emote(id,kind,now){const p=this.players.get(id);if(!p||!p.connected||!['race','qualifying'].includes(this.phase)||!['wheelie','nitro'].includes(kind))return false;
    if(p.emoteAt!=null&&now-p.emoteAt<750)return false;
    if(kind==='wheelie'&&!(p.state?.v>1||p.input.up))return false;
    p.emoteAt=now;p.emote={kind,until:now+3000};return true;
  }
  chat(id,text,now){const p=this.players.get(id);if(!p||!p.connected||!['race','qualifying','complete'].includes(this.phase)||typeof text!=='string')return null;
    if(text.length>180)return null;const clean=text.replace(/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g,' ').replace(/\s+/g,' ').trim();
    if(!clean||p.chatAt!=null&&now-p.chatAt<1000)return null;p.chatAt=now;return {type:'chat',id:p.profile.id,name:p.profile.display_name,number:p.profile.number,color:p.profile.color,text:clean};
  }
  reset(id){const p=this.players.get(id);if(!p||!p.connected||!p.state||!['race','qualifying'].includes(this.phase))return;let s=p.state;const {px,pz,tx,tz}=this.track,i=s.idx;s.x=px[i];s.z=pz[i];s.h=Math.atan2(tx[i],tz[i]);s.v=0;s.steer=0;s.lean=0;s.pitch=0;if(this.phase==='qualifying'&&p.flying&&!p.completed&&!p.invalid){p.invalid=true;this.events.push({type:'invalid',id,reason:'RESET ON TRACK'})}}
  setCircuit(id,circuit){if(id!==this.host||this.phase!=='lobby')throw Error('Only the host can choose a circuit in the lobby');const track=getTrack(circuit);this.track=track;this.physics=createPhysics(track);this.aiInput=createAI(track);this.circuit=circuit;this.circuitConfigured=true;for(const p of this.players.values())p.circuitReady=false}
  readyCircuit(id,circuit){const p=this.players.get(id);if(!p||!p.connected||circuit!==this.circuit)return false;p.circuitReady=true;return true}
  setAI(id,enabled){if(id!==this.host||this.phase!=='lobby'||typeof enabled!=='boolean')throw Error('Only the host can change AI in the lobby');this.fillAI=enabled}
  start(id,now){if(id!==this.host)throw Error('Only the host can start');if(this.phase!=='lobby')throw Error('Match already started');if(this.players.size<2||this.players.size>MAX_RIDERS)throw Error('2–10 connected riders required');if(this.circuitConfigured&&[...this.players.values()].some(p=>!p.connected||!p.circuitReady))throw Error('Waiting for all riders to load the circuit');
    if(this.fillAI){const colors=['blue','red','yellow','orange','green','cyan','purple','pink','white','black','silver'];for(let i=this.players.size;i<MAX_RIDERS;i++){const profile={id:'ai-'+(i+1),username:'ai'+(i+1),display_name:'AI Rider '+(i+1),number:10+i,color:colors[i%colors.length]};this.join(profile,now);this.players.get(profile.id).ai=true}}
    const order=[...this.players.values()];for(let i=order.length-1;i>0;i--){let j=randomInt(i+1);[order[i],order[j]]=[order[j],order[i]]}order.forEach((p,i)=>p.grid=i+1);this.matchId=randomUUID();this.startPhase(this.mode==='race'?'race':'qualifying',now,COUNTDOWN)}
  startPhase(phase,now,delay){this.phase=phase;this.phaseStart=now+delay;this.resultsAt=null;for(const p of this.players.values()){p.state=this.physics.spawn(p.grid);p.gapIndex=p.state.total;p.gapCrossings=new Map([[p.gapIndex,this.phaseStart]]);p.emote=null;p.emoteAt=null;p.completed=p.dnf;p.finishAt=null;p.input=neutralInput();p.inputAt=now;p.lap=1;p.lapStart=this.phaseStart;p.raceBest=null;p.lastLap=null;p.flying=false;p.invalid=false;p.line=0;p.sector=0;p.sectorStart=this.phaseStart;p.sectorTimes=[];if(phase==='qualifying'){p.best=null;p.attempts=0;p.sectorBests=[null,null,null,null]}}this.events.push({type:'phase',phase})}
  advance(now,dt){if(this.phase==='lobby'||this.phase==='complete')return;
    for(const p of this.players.values())if(!p.connected&&!p.dnf&&p.disconnectedAt!==null&&now-p.disconnectedAt>=GRACE&&!p.completed){p.dnf=true;p.completed=true;this.events.push({type:'dnf',id:p.profile.id});if([...this.players.values()].filter(q=>!q.ai).length===2){this.phase='complete';this.endReason='opponent_left';this.events.push({type:'session_ended',reason:this.endReason});return}}
    if(now>=this.phaseStart){for(const p of this.players.values()){
      if(p.dnf)continue;const input=p.ai?this.aiInput(p.state,(p.grid%5)-2):p.connected&&now-p.inputAt<1000?p.input:neutralInput(),result=this.physics.step(p.state,input,dt);
      if(this.phase==='race'&&!p.completed)this.recordGapCrossings(p,now,dt);
      if(p.completed)continue;
      if(this.phase==='race'){if(p.state.total>=this.track.N*p.lap&&p.state.v>0){p.lastLap=(now-p.lapStart)/1000;p.raceBest=p.raceBest===null?p.lastLap:Math.min(p.raceBest,p.lastLap);p.lap++;p.lapStart=now;if(p.lap>RACE_LAPS){p.completed=true;p.finishAt=now;this.events.push({type:'finish',id:p.profile.id})}}}
      else this.qualify(p,result,now);
    }
      // Separate overlapping bikes; both riders remain in the authoritative simulation.
      const active=[...this.players.values()].filter(p=>!p.dnf&&p.state);
      for(let i=0;i<active.length;i++)for(let j=i+1;j<active.length;j++){
        const a=active[i].state,b=active[j].state,dx=b.x-a.x,dz=b.z-a.z;
        if(dx*dx+dz*dz<2.25){const d=Math.hypot(dx,dz),nx=d>0.001?dx/d:1,nz=d>0.001?dz/d:0,shift=(1.5-d)/2;a.x-=nx*shift;a.z-=nz*shift;b.x+=nx*shift;b.z+=nz*shift;a.v*=.98;b.v*=.98;}
      }
    }
    const players=[...this.players.values()];
    if(players.length&&players.every(p=>p.completed)){
      if(this.phase==='qualifying'){if(this.resultsAt===null)this.resultsAt=now+QUALIFYING_RESULTS_DELAY;else if(now>=this.resultsAt){players.sort((a,b)=>Number(a.dnf)-Number(b.dnf)||(a.best??Infinity)-(b.best??Infinity)||a.grid-b.grid);players.forEach((p,i)=>p.grid=i+1);this.startPhase('race',now,GRID_COUNTDOWN)}}
      else if(this.resultsAt===null)this.resultsAt=now+RESULT_DELAY;else if(now>=this.resultsAt){this.phase='complete';this.events.push({type:'results'})}
    }
  }
  // Time differences are measured at the same sampled track positions, never
  // distance divided by current speed. The bounded history covers one lap.
  recordGapCrossings(p,now,dt){
    if(!p.gapCrossings||!Number.isFinite(p.state.total))return;
    const next=Math.floor(p.state.total),from=p.gapIndex;if(next<from){for(let i=next;i<=from;i++)p.gapCrossings.delete(i);p.gapIndex=next;return}if(next===from)return;
    const count=next-from;if(count>80){p.gapCrossings.clear();p.gapIndex=next;return}
    for(let i=from+1;i<=next;i++)p.gapCrossings.set(i,now-dt*1000+(i-from)/count*dt*1000);
    p.gapIndex=next;while(p.gapCrossings.size>this.track.N+80)p.gapCrossings.delete(p.gapCrossings.keys().next().value);
  }
  raceGaps(now){
    const result=new Map();if(!['race','complete'].includes(this.phase)||now<this.phaseStart)return result;
    const riders=[...this.players.values()].filter(p=>!p.dnf&&p.state).sort((a,b)=>Number(b.completed)-Number(a.completed)||(a.completed?(a.finishAt??Infinity)-(b.finishAt??Infinity):b.state.total-a.state.total)||a.grid-b.grid);
    for(let i=1;i<riders.length;i++){
      const ahead=riders[i-1],p=riders[i];let seconds=null,laps=0;
      if(p.completed&&ahead.completed&&p.finishAt!=null&&ahead.finishAt!=null)seconds=Math.max(0,(p.finishAt-ahead.finishAt)/1000);
      else if(!p.completed&&!ahead.completed){
        laps=Math.floor(Math.max(0,ahead.state.total-p.state.total)/this.track.N);
        if(!laps&&p.gapCrossings&&ahead.gapCrossings&&p.gapIndex===Math.floor(p.state.total)){
          const earlier=ahead.gapCrossings.get(p.gapIndex),crossed=p.gapCrossings.get(p.gapIndex);
          if(Number.isFinite(earlier)&&Number.isFinite(crossed)&&crossed>=earlier){const when=Math.abs(p.state.v)<.5&&Math.abs(ahead.state.v)>.5?now:crossed;seconds=Math.max(0,(when-earlier)/1000)}
        }
      }
      if(laps||seconds!==null)result.set(p.profile.id,{ahead:ahead.profile.id,seconds,laps});
    }return result;
  }
  // A clean sector on the current flying lap counts provisionally. If the lap
  // is later invalidated it is excluded; only valid completed laps persist.
  recordSector(p,index,now,emit=true){
    const duration=(now-p.sectorStart)/1000,prior=p.sectorBests[index];
    let sessionBest=Infinity;
    for(const rider of this.players.values()){
      const best=rider.sectorBests?.[index];if(Number.isFinite(best))sessionBest=Math.min(sessionBest,best);
      const provisional=rider.flying&&!rider.invalid?rider.sectorTimes?.[index]:null;
      if(Number.isFinite(provisional))sessionBest=Math.min(sessionBest,provisional);
    }
    const color=sectorColor(duration,prior,sessionBest,this.track.length/4);
    p.sectorTimes[index]=duration;p.sectorStart=now;
    if(emit&&!p.invalid)this.events.push({type:'sector',id:p.profile.id,sector:index+1,split:(now-p.lapStart)/1000,delta:prior==null?null:duration-prior,color});
  }
  qualify(p,result,now){const expired=now>=this.phaseStart+QUALIFYING,s=p.state,{N,kerbEdge}=this.track;
    if(!p.flying){if(expired){p.completed=true;return}if(result.previous<0&&s.total>=0&&s.v>0){p.flying=true;p.lapStart=now;p.sectorStart=now;p.invalid=result.offTrack;if(p.invalid)this.events.push({type:'invalid',id:p.profile.id,reason:'TRACK LIMITS'})}return}
    if(result.offTrack&&!p.invalid){p.invalid=true;this.events.push({type:'invalid',id:p.profile.id,reason:'TRACK LIMITS'})}
    while(p.sector<3&&s.total-p.line>=N*(p.sector+1)/4){this.recordSector(p,p.sector,now);p.sector++}
    if(s.total-p.line>=N&&s.v>0){p.attempts++;const duration=(now-p.lapStart)/1000;const personal=!p.invalid&&(p.best===null||duration<p.best);if(!p.invalid){this.recordSector(p,3,now);if(personal)p.best=duration;p.sectorTimes.forEach((v,i)=>{if(p.sectorBests[i]===null||v<p.sectorBests[i])p.sectorBests[i]=v})}
      this.events.push({type:'lap',id:p.profile.id,valid:!p.invalid,time:duration,personal,fastest:personal&&[...this.players.values()].every(q=>q.best===null||q.best>=duration)});
      if(expired||p.attempts>=QUALIFYING_ATTEMPTS){p.completed=true;p.finishAt=now;return}p.line+=N;p.lapStart=now;p.sectorStart=now;p.sector=0;p.sectorTimes=[];p.invalid=Math.abs(s.lat)>kerbEdge(s.idx);if(p.invalid)this.events.push({type:'invalid',id:p.profile.id,reason:'TRACK LIMITS'});
    }
  }
  snapshot(now){const gaps=this.raceGaps(now);return {id:this.id,matchId:this.matchId,mode:this.mode,circuit:this.circuit,circuitConfigured:this.circuitConfigured,fillAI:this.fillAI,phase:this.phase,endReason:this.endReason,phaseStart:this.phaseStart,serverTime:now,rules:{raceLaps:RACE_LAPS,qualifyingAttempts:QUALIFYING_ATTEMPTS,qualifyingMs:QUALIFYING},players:[...this.players.values()].map(p=>({...p.profile,gap:gaps.get(p.profile.id)||null,ai:!!p.ai,circuitReady:!!p.circuitReady,grid:p.grid,connected:p.connected,completed:p.completed,dnf:p.dnf,finishAt:p.finishAt,emote:p.emote&&p.emote.until>now?p.emote:null,best:p.best,attempts:p.attempts,flying:p.flying,invalid:p.invalid,lap:p.lap,lapStart:p.lapStart,raceBest:p.raceBest,lastLap:p.lastLap,sector:p.sector,line:p.line,state:p.state&&{...p.state}})),events:this.events.splice(0)}}
}
