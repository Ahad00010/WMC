(function () {
  'use strict';
  const $=id=>document.getElementById(id);
  let snapshot=null, checking=null, pending=false, clockOffset=0, leaving=sessionStorage.getItem('wmc-leaving')==='1', leavePromise=null, generation=0;
  const serverUrl=window.WMC_RACE_SERVER_URL||'';let transport=null, serverSnapshot=null, connecting=false,stats={},statsAt=0,connectionError='',knownMembers=null,lastInvite=null,connected=false;
  function cue(kind){if(window.WMCGame&&window.WMCGame.matchCue)window.WMCGame.matchCue(kind)}
  async function getClient() {
    const c=window.WMCAuth&&window.WMCAuth.client;
    if(!c)throw new Error('Sign in with Google first.');
    const {data,error}=await c.auth.getSession();
    if(error||!data.session)throw new Error('Sign in with Google and complete your profile first.');
    return c;
  }
  async function refresh(force) {
    if(leaving){leaveSession();return;}
    if(checking){await checking;if(force)return refresh();return;}
    const currentGeneration=generation;let finish;checking=new Promise(resolve=>{finish=resolve});
    try {
      const c=await getClient(), {data,error}=await c.rpc('wmc_lobby_snapshot');
      if(error)throw error;
      if(leaving||currentGeneration!==generation)return;
      snapshot=data;clockOffset=Date.parse(data.server_time)-Date.now();
      if(data.lobby&&serverUrl){connectRace();if(Date.now()-statsAt>30000){statsAt=Date.now();const result=await c.rpc('wmc_lobby_stats');if(!result.error)stats=Object.fromEntries(result.data.map(p=>[p.id,p]))}}else if(!data.lobby&&transport){transport.close();transport=null;serverSnapshot=null;stats={};statsAt=0;}
      render();
    } catch(e) {
      if(leaving||currentGeneration!==generation)return;
      snapshot=null;$('inviteNotice').hidden=true;if(window.WMCGame&&window.WMCGame.network)window.WMCGame.network(false);
      if(!$('modeOverlay').hidden&&!$('multiModes').hidden)$('modeTitle').textContent='MULTIPLAYER · SIGN IN REQUIRED';
      if(!$('lobbyPanel').hidden)$('lobbyMessage').textContent=e.message||'Unable to load lobby.';
    } finally {checking=null;finish();}
  }
  function render() {
    const lobby=snapshot&&snapshot.lobby;
    if(lobby){const ids=lobby.members.map(m=>m.id).sort().join('|');if(knownMembers!==null&&ids!==knownMembers&&!$('lobbyPanel').hidden)cue('join');knownMembers=ids}else knownMembers=null;
    $('resumeLobby').hidden=!lobby;
    const inPanel=!$('modeOverlay').hidden&&!$('lobbyPanel').hidden;
    if(inPanel){
      if(!lobby){$('lobbyPanel').hidden=true;$('multiModes').hidden=false;$('modeTitle').textContent='MULTIPLAYER';}
      else{
        $('lobbyMode').textContent=(lobby.mode==='race'?'Race only':'Qualifying + Race')+' · '+lobby.members.length+'/15 riders';
        $('inviteForm').hidden=lobby.host_id!==snapshot.user_id;
        $('startMultiplayer').hidden=lobby.host_id!==snapshot.user_id;
        const connected=serverSnapshot?serverSnapshot.players.filter(p=>p.connected).length:0;
        $('startMultiplayer').disabled=!serverUrl||!transport||!transport.ready||connected<2;
        $('startHint').textContent=!serverUrl?'Race server not configured yet.':!transport||!transport.ready?(connectionError||'Connecting to race server…'):connected<2?'Waiting for at least two connected riders.':'Ready to start · '+connected+'/15 connected';
        const list=$('lobbyMembers');list.replaceChildren();
        lobby.members.forEach(member=>{const row=document.createElement('div');row.className='friend-row';const name=document.createElement('div');name.className='friend-row-name';const title=document.createElement('strong');title.textContent=member.display_name+(member.id===lobby.host_id?' · HOST':'');const sub=document.createElement('small');sub.textContent='@'+member.username+' · #'+member.number;name.append(title,sub);row.appendChild(name);list.appendChild(row)});
      }
    }
    const invite=snapshot&&snapshot.invites[0],notice=$('inviteNotice');
    if(!invite){notice.hidden=true;lastInvite=null;return;}
    if(invite.id!==lastInvite){lastInvite=invite.id;cue('invite')}
    const left=Math.max(0,Math.ceil((Date.parse(invite.expires_at)-(Date.now()+clockOffset))/1000));
    if(left<=0){notice.hidden=true;return;}
    $('inviteText').textContent=invite.sender+' invited you to a lobby';$('inviteRemaining').textContent=left+'s remaining';notice.hidden=false;
  }
  function showLobby() {
    $('modeOverlay').hidden=false;$('menu').inert=true;$('playButtons').hidden=true;$('modeButtons').hidden=true;$('multiModes').hidden=true;$('multiplayerNotice').hidden=true;$('lobbyPanel').hidden=false;$('modeBack').hidden=false;$('modeTitle').textContent='LOBBY';$('lobbyMessage').textContent='';render();
  }
  async function act(action,params) {
    if(pending)return false;
    pending=true;
    try{const c=await getClient();const {error}=await c.rpc('wmc_lobby_action',{action,params:params||{}});if(error)throw error;await refresh(true);return true;}
    catch(e){$('lobbyMessage').textContent=e.message||'Lobby action failed.';$('multiMessage').textContent=e.message||'Lobby action failed.';$('inviteError').textContent=e.message||'Lobby action failed.';return false;}
    finally{pending=false;}
  }
  async function create(mode) {
    if(leaving){$('multiMessage').textContent='Leaving the previous session. Please wait…';leaveSession();return;}
    $('multiMessage').textContent='Connecting…';
    await refresh();
    if(snapshot&&snapshot.lobby){
      if(snapshot.lobby.mode===mode){$('multiMessage').textContent='';showLobby();}
      else $('multiMessage').textContent='You are already in a '+(snapshot.lobby.mode==='race'?'Race only':'Qualifying + Race')+' lobby. Open it and leave before choosing another mode.';
      return;
    }
    if(await act('create',{mode})){$('multiMessage').textContent='';showLobby();}
  }
  async function connectRace(){
    if(leaving||connecting||!snapshot||!snapshot.lobby||!serverUrl||transport&&transport.ws)return;
    connecting=true;const currentGeneration=generation;
    try{const c=await getClient(),{data,error}=await c.auth.getSession();if(error||!data.session)throw Error('Sign in first');if(leaving||currentGeneration!==generation||!snapshot||!snapshot.lobby)return;
      if(!transport)transport=new window.WMCRaceTransport(serverUrl,{
        status:(ok,code,reason)=>{if(ok&&!connected)cue('ready');connected=ok;if(ok)connectionError='';else{serverSnapshot=null;connectionError=code===1008?'Race server rejected the connection ('+(reason||'authentication failed')+'). Retrying…':'Race server connection failed. Retrying…'}if(window.WMCGame)window.WMCGame.network(ok);render()},
        error:message=>{$('lobbyMessage').textContent=message},
        snapshot:message=>{if(leaving||currentGeneration!==generation)return;serverSnapshot=message;if(snapshot&&window.WMCGame)window.WMCGame.authoritativeReceive(message,snapshot.user_id,stats);render()}
      });transport.connect(data.session.access_token);
    }catch(e){$('lobbyMessage').textContent=e.message||'Race server connection failed.'}finally{connecting=false}
  }
  function sendInput(){if(!leaving&&transport&&transport.ready&&window.WMCGame)transport.send('input',window.WMCGame.input())}
  setInterval(sendInput,100);
  function leaveSession(){
    if(leavePromise)return leavePromise;
    leaving=true;generation++;sessionStorage.setItem('wmc-leaving','1');
    if(transport){transport.send('leave');transport.close();transport=null}connected=false;serverSnapshot=null;snapshot=null;render();
    leavePromise=(async()=>{try{const c=await getClient(),{error}=await c.rpc('wmc_lobby_action',{action:'leave',params:{}});if(error)throw error;leaving=false;sessionStorage.removeItem('wmc-leaving');$('multiMessage').textContent='';return true}
      catch(e){$('multiMessage').textContent='Could not leave the previous session. Retrying; check your connection.';return false}
      finally{leavePromise=null}})();return leavePromise;
  }
  $('startMultiplayer').onclick=()=>{if(!transport||!transport.send('start'))$('lobbyMessage').textContent='Race server is not connected.';else cue('ready')};
  window.WMCMatch={reset:()=>{if(transport)transport.send('reset')},sendInput,leave:leaveSession};
  $('resumeLobby').onclick=()=>{if(snapshot&&snapshot.lobby){$('multiMessage').textContent='';showLobby()}};
  $('multiRace').onclick=()=>{cue('select');create('race')};$('multiQualRace').onclick=()=>{cue('select');create('qualifying_race')};
  $('inviteForm').onsubmit=async e=>{e.preventDefault();const username=$('inviteUsername').value.trim();if(await act('invite',{username})){cue('join');$('lobbyMessage').textContent='Invite sent (expires in 10 seconds).';$('inviteForm').reset()}};
  $('leaveLobby').onclick=async()=>{if(await leaveSession()){$('multiMessage').textContent='';$('lobbyPanel').hidden=true;$('multiModes').hidden=false;$('modeTitle').textContent='MULTIPLAYER'}};
  $('acceptInvite').onclick=async()=>{if(!$('menu')||$('menu').hidden){$('inviteError').textContent='Return to the main menu to accept.';return}const invite=snapshot&&snapshot.invites[0];if(invite&&await act('accept',{invite_id:invite.id})){$('inviteError').textContent='';showLobby()}};
  $('declineInvite').onclick=async()=>{const invite=snapshot&&snapshot.invites[0];if(invite)await act('decline',{invite_id:invite.id})};
  window.addEventListener('wmc-lobby-open',()=>{refresh()});
  window.addEventListener('wmc-auth-ready',refresh);
  setInterval(()=>{if(!document.hidden)refresh()},2000);
  setInterval(render,250);
  refresh();
})();
