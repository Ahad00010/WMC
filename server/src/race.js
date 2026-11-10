import {randomUUID,randomInt} from 'node:crypto';
import {N,length,px,pz,tx,tz,kerbEdge} from './track.js';
import sectorColor from '../../qualifying-colors.js';
import {spawn,step,parseInput,neutralInput} from './physics.js';
export const RACE_LAPS=3,QUALIFYING_ATTEMPTS=3,QUALIFYING=240000;
const COUNTDOWN=22000,GRACE=30000,RESULT_DELAY=10000;
export class RaceRoom {
  constructor(lobby){this.id=lobby.id;this.host=lobby.host_id;this.mode=lobby.mode;this.phase='lobby';this.players=new Map();this.events=[];this.matchId=null;this.phaseStart=0;this.resultsAt=null;this.endReason=null}
  join(profile,now){let p=this.players.get(profile.id);if(p){if(p.dnf)throw Error('Rider has retired');p.connected=true;p.disconnectedAt=null;p.input=neutralInput();p.inputAt=now;return}
    if(this.phase!=='lobby')throw Error('Race already started');if(this.players.size>=15)throw Error('Lobby full');
    this.players.set(profile.id,{profile,connected:true,disconnectedAt:null,input:neutralInput(),inputAt:now,grid:0,state:null,best:null,attempts:0,flying:false,invalid:false,completed:false,dnf:false,finishAt:null,lap:1,lapStart:0,sector:0,line:0});}
  disconnect(id,now){let p=this.players.get(id);if(!p)return;p.connected=false;p.input=neutralInput();p.disconnectedAt=now;if(this.phase==='lobby'){this.players.delete(id);return}if(this.phase!=='complete'&&this.players.size===2){if(!p.completed){p.dnf=true;p.completed=true;this.events.push({type:'dnf',id})}this.phase='complete';this.endReason='opponent_left';this.events.push({type:'session_ended',reason:this.endReason})}}
  leave(id,now){const p=this.players.get(id);if(!p)return;if(this.phase!=='lobby'&&!p.completed){p.dnf=true;p.completed=true;this.events.push({type:'dnf',id})}this.disconnect(id,now)}
  input(id,raw,now){const p=this.players.get(id),input=parseInput(raw);if(!p||!p.connected||!input)return false;p.input=input;p.inputAt=now;return true}
  reset(id){const p=this.players.get(id);if(!p||!p.connected||!p.state||!['race','qualifying'].includes(this.phase))return;let s=p.state;const i=s.idx;s.x=px[i];s.z=pz[i];s.h=Math.atan2(tx[i],tz[i]);s.v=0;s.steer=0;s.lean=0;s.pitch=0;if(this.phase==='qualifying'&&p.flying&&!p.completed&&!p.invalid){p.invalid=true;this.events.push({type:'invalid',id,reason:'RESET ON TRACK'})}}
  start(id,now){if(id!==this.host)throw Error('Only the host can start');if(this.phase!=='lobby')throw Error('Match already started');if(this.players.size<2||this.players.size>15)throw Error('2–15 connected riders required');
    const order=[...this.players.values()];for(let i=order.length-1;i>0;i--){let j=randomInt(i+1);[order[i],order[j]]=[order[j],order[i]]}order.forEach((p,i)=>p.grid=i+1);this.matchId=randomUUID();this.startPhase(this.mode==='race'?'race':'qualifying',now,COUNTDOWN)}
  startPhase(phase,now,delay){this.phase=phase;this.phaseStart=now+delay;this.resultsAt=null;for(const p of this.players.values()){p.state=spawn(p.grid);p.completed=p.dnf;p.finishAt=null;p.input=neutralInput();p.inputAt=now;p.lap=1;p.lapStart=this.phaseStart;p.raceBest=null;p.lastLap=null;p.flying=false;p.invalid=false;p.line=0;p.sector=0;p.sectorStart=this.phaseStart;p.sectorTimes=[];if(phase==='qualifying'){p.best=null;p.attempts=0;p.sectorBests=[null,null,null,null]}}this.events.push({type:'phase',phase})}
  advance(now,dt){if(this.phase==='lobby'||this.phase==='complete')return;
    for(const p of this.players.values())if(!p.connected&&!p.dnf&&p.disconnectedAt!==null&&now-p.disconnectedAt>=GRACE&&!p.completed){p.dnf=true;p.completed=true;this.events.push({type:'dnf',id:p.profile.id})}
    if(now>=this.phaseStart){for(const p of this.players.values()){
      if(p.dnf)continue;const input=p.connected&&now-p.inputAt<1000?p.input:neutralInput(),result=step(p.state,input,dt);
      if(p.completed)continue;
      if(this.phase==='race'){if(p.state.total>=N*p.lap&&p.state.v>0){p.lastLap=(now-p.lapStart)/1000;p.raceBest=p.raceBest===null?p.lastLap:Math.min(p.raceBest,p.lastLap);p.lap++;p.lapStart=now;if(p.lap>RACE_LAPS){p.completed=true;p.finishAt=now;this.events.push({type:'finish',id:p.profile.id})}}}
      else this.qualify(p,result,now);
    }
      // Separate overlapping bikes; both riders remain in the authoritative simulation.
      const active=[...this.players.values()].filter(p=>!p.dnf&&p.state);
      for(let i=0;i<active.length;i++)for(let j=i+1;j<active.length;j++){
        const a=active[i].state,b=active[j].state,dx=b.x-a.x,dz=b.z-a.z,d=Math.hypot(dx,dz);
        if(d<1.5){const nx=d>0.001?dx/d:1,nz=d>0.001?dz/d:0,shift=(1.5-d)/2;a.x-=nx*shift;a.z-=nz*shift;b.x+=nx*shift;b.z+=nz*shift;a.v*=.98;b.v*=.98;}
      }
    }
    const players=[...this.players.values()];
    if(players.length&&players.every(p=>p.completed)){
      if(this.phase==='qualifying'){players.sort((a,b)=>Number(a.dnf)-Number(b.dnf)||(a.best??Infinity)-(b.best??Infinity)||a.grid-b.grid);players.forEach((p,i)=>p.grid=i+1);this.startPhase('race',now,15000)}
      else if(this.resultsAt===null)this.resultsAt=now+RESULT_DELAY;else if(now>=this.resultsAt){this.phase='complete';this.events.push({type:'results'})}
    }
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
    const color=sectorColor(duration,prior,sessionBest,length/4);
    p.sectorTimes[index]=duration;p.sectorStart=now;
    if(emit&&!p.invalid)this.events.push({type:'sector',id:p.profile.id,sector:index+1,split:(now-p.lapStart)/1000,delta:prior==null?null:duration-prior,color});
  }
  qualify(p,result,now){const expired=now>=this.phaseStart+QUALIFYING,s=p.state;
    if(!p.flying){if(expired){p.completed=true;return}if(result.previous<0&&s.total>=0&&s.v>0){p.flying=true;p.lapStart=now;p.sectorStart=now;p.invalid=result.offTrack;if(p.invalid)this.events.push({type:'invalid',id:p.profile.id,reason:'TRACK LIMITS'})}return}
    if(result.offTrack&&!p.invalid){p.invalid=true;this.events.push({type:'invalid',id:p.profile.id,reason:'TRACK LIMITS'})}
    while(p.sector<3&&s.total-p.line>=N*(p.sector+1)/4){this.recordSector(p,p.sector,now);p.sector++}
    if(s.total-p.line>=N&&s.v>0){p.attempts++;const duration=(now-p.lapStart)/1000;const personal=!p.invalid&&(p.best===null||duration<p.best);if(!p.invalid){this.recordSector(p,3,now);if(personal)p.best=duration;p.sectorTimes.forEach((v,i)=>{if(p.sectorBests[i]===null||v<p.sectorBests[i])p.sectorBests[i]=v})}
      this.events.push({type:'lap',id:p.profile.id,valid:!p.invalid,time:duration,personal,fastest:personal&&[...this.players.values()].every(q=>q.best===null||q.best>=duration)});
      if(expired||p.attempts>=QUALIFYING_ATTEMPTS){p.completed=true;return}p.line+=N;p.lapStart=now;p.sectorStart=now;p.sector=0;p.sectorTimes=[];p.invalid=Math.abs(s.lat)>kerbEdge(s.idx);if(p.invalid)this.events.push({type:'invalid',id:p.profile.id,reason:'TRACK LIMITS'});
    }
  }
  snapshot(now){return {id:this.id,matchId:this.matchId,mode:this.mode,phase:this.phase,endReason:this.endReason,phaseStart:this.phaseStart,serverTime:now,rules:{raceLaps:RACE_LAPS,qualifyingAttempts:QUALIFYING_ATTEMPTS,qualifyingMs:QUALIFYING},players:[...this.players.values()].map(p=>({...p.profile,grid:p.grid,connected:p.connected,completed:p.completed,dnf:p.dnf,finishAt:p.finishAt,best:p.best,attempts:p.attempts,flying:p.flying,invalid:p.invalid,lap:p.lap,lapStart:p.lapStart,raceBest:p.raceBest,lastLap:p.lastLap,sector:p.sector,line:p.line,state:p.state&&{...p.state}})),events:this.events.splice(0)}}
}
