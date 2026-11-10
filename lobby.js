(function () {
  'use strict';
  const $=id=>document.getElementById(id);
  let snapshot=null, checking=null, pending=false, clockOffset=0;
  async function getClient() {
    const c=window.WMCAuth&&window.WMCAuth.client;
    if(!c)throw new Error('Sign in with Google first.');
    const {data,error}=await c.auth.getSession();
    if(error||!data.session)throw new Error('Sign in with Google and complete your profile first.');
    return c;
  }
  async function refresh(force) {
    if(checking){await checking;if(force)return refresh();return;}
    let finish;checking=new Promise(resolve=>{finish=resolve});
    try {
      const c=await getClient(), {data,error}=await c.rpc('wmc_lobby_snapshot');
      if(error)throw error;
      snapshot=data;clockOffset=Date.parse(data.server_time)-Date.now();
      render();
    } catch(e) {
      snapshot=null;$('inviteNotice').hidden=true;if(window.WMCGame&&window.WMCGame.network)window.WMCGame.network(false);
      if(!$('modeOverlay').hidden&&!$('multiModes').hidden)$('modeTitle').textContent='MULTIPLAYER · SIGN IN REQUIRED';
      if(!$('lobbyPanel').hidden)$('lobbyMessage').textContent=e.message||'Unable to load lobby.';
    } finally {checking=null;finish();}
  }
  function render() {
    const lobby=snapshot&&snapshot.lobby, inPanel=!$('modeOverlay').hidden&&!$('lobbyPanel').hidden;
    if(inPanel){
      if(!lobby){$('lobbyPanel').hidden=true;$('multiModes').hidden=false;$('modeTitle').textContent='MULTIPLAYER';}
      else{
        $('lobbyMode').textContent=(lobby.mode==='race'?'Race only':'Qualifying + Race')+' · '+lobby.members.length+'/15 riders';
        $('inviteForm').hidden=lobby.host_id!==snapshot.user_id;
        $('startMultiplayer').hidden=lobby.host_id!==snapshot.user_id;
        $('startMultiplayer').disabled=lobby.members.length<2;
        $('startHint').textContent=lobby.members.length<2?'At least two riders are needed to start.':'Ready to start · '+lobby.members.length+'/15 riders';
        const list=$('lobbyMembers');list.replaceChildren();
        lobby.members.forEach(member=>{const row=document.createElement('div');row.className='friend-row';const name=document.createElement('div');name.className='friend-row-name';const title=document.createElement('strong');title.textContent=member.display_name+(member.id===lobby.host_id?' · HOST':'');const sub=document.createElement('small');sub.textContent='@'+member.username+' · #'+member.number;name.append(title,sub);row.appendChild(name);list.appendChild(row)});
      }
    }
    const invite=snapshot&&snapshot.invites[0],notice=$('inviteNotice');
    if(!invite){notice.hidden=true;return;}
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
    $('multiMessage').textContent='Connecting…';
    await refresh();
    if(snapshot&&snapshot.lobby){$('multiMessage').textContent='';showLobby();return;}
    if(await act('create',{mode})){$('multiMessage').textContent='';showLobby();}
  }
  $('startMultiplayer').onclick=async()=>{
    try{const c=await getClient();$('startMultiplayer').disabled=true;$('lobbyMessage').textContent='Starting match…';const {error}=await c.rpc('wmc_match_start');if(error)throw error;await matchTick();}
    catch(e){$('lobbyMessage').textContent=e.message||'Could not start match.';render();}
  };
  let ticking=false, leaving=false;
  async function matchTick(){
    if(ticking||leaving||!snapshot||!snapshot.lobby||!window.WMCGame)return;
    ticking=true;
    try{const c=await getClient();const {data,error}=await c.rpc('wmc_match_tick',{report:window.WMCGame.report()});if(error)throw error;if(window.WMCGame.network)window.WMCGame.network(true);if(!leaving)window.WMCGame.receive(data);}
    catch(e){if(window.WMCGame.network)window.WMCGame.network(false);if(!$('lobbyPanel').hidden)$('lobbyMessage').textContent=e.message||'Match connection failed.';}
    finally{ticking=false;}
  }
  window.WMCMatch={leave:async()=>{leaving=true;try{await act('leave')}finally{snapshot=null;leaving=false}}};
  setInterval(matchTick,750);
  $('multiRace').onclick=()=>create('race');$('multiQualRace').onclick=()=>create('qualifying_race');
  $('inviteForm').onsubmit=async e=>{e.preventDefault();const username=$('inviteUsername').value.trim();if(await act('invite',{username})){$('lobbyMessage').textContent='Invite sent (expires in 10 seconds).';$('inviteForm').reset()}};
  $('leaveLobby').onclick=async()=>{if(await act('leave')){$('lobbyPanel').hidden=true;$('multiModes').hidden=false;$('modeTitle').textContent='MULTIPLAYER'}};
  $('acceptInvite').onclick=async()=>{if(!$('menu')||$('menu').hidden){$('inviteError').textContent='Return to the main menu to accept.';return}const invite=snapshot&&snapshot.invites[0];if(invite&&await act('accept',{invite_id:invite.id})){$('inviteError').textContent='';showLobby()}};
  $('declineInvite').onclick=async()=>{const invite=snapshot&&snapshot.invites[0];if(invite)await act('decline',{invite_id:invite.id})};
  window.addEventListener('wmc-lobby-open',async()=>{await refresh();if(snapshot&&snapshot.lobby&&!$('modeOverlay').hidden&&!$('multiModes').hidden)showLobby()});
  window.addEventListener('wmc-auth-ready',refresh);
  setInterval(()=>{if(!document.hidden)refresh()},2000);
  setInterval(render,250);
  refresh();
})();
