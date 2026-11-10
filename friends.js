(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const message = $('friendMessage'), list = $('friendList'), form = $('friendForm');
  let generation = 0, working = false;
  function available() { return !$('modeOverlay').hidden && !$('multiplayerNotice').hidden; }
  async function client() {
    const c = window.WMCAuth && window.WMCAuth.client;
    if (!c) throw new Error('Google sign-in is unavailable.');
    const {data, error} = await c.auth.getSession();
    if (error || !data.session) throw new Error('Sign in with Google and complete your rider profile first.');
    return c;
  }
  async function refresh() {
    if (!available()) return;
    const current = ++generation;
    try {
      const c = await client();
      const {data, error} = await c.rpc('wmc_friends');
      if (error) throw error;
      if (current !== generation || !available()) return;
      list.replaceChildren();
      if (!data.length) { const p=document.createElement('p');p.className='friend-note';p.textContent='No friends or requests yet.';list.appendChild(p);return; }
      data.forEach(row => {
        const item=document.createElement('div'), name=document.createElement('div'), title=document.createElement('strong'), detail=document.createElement('small');
        item.className='friend-row';name.className='friend-row-name';title.textContent=row.display_name;detail.textContent='@'+row.username+' · '+(row.status==='incoming'?'Request received':row.status==='outgoing'?'Request sent':'Friend');name.append(title,detail);item.appendChild(name);
        function button(label, fn, alternate) { const b=document.createElement('button');b.type='button';b.textContent=label;if(alternate)b.className='alt';b.onclick=()=>action(fn);item.appendChild(b); }
        if (row.status==='incoming') {
          button('Accept',()=>c.rpc('wmc_friend_respond',{request_id:row.id,accept_request:true}));
          button('Decline',()=>c.rpc('wmc_friend_respond',{request_id:row.id,accept_request:false}),true);
        } else button(row.status==='friend'?'Remove':'Cancel',()=>c.rpc('wmc_friend_remove',{friendship_id:row.id}),true);
        list.appendChild(item);
      });
    } catch (err) { if (current===generation && available()) { list.replaceChildren();message.textContent=err.message || 'Unable to load friends.'; } }
  }
  async function action(fn) {
    if (working) return;
    working=true;message.textContent='Working…';
    try { const {error}=await fn();if(error)throw error;message.textContent='Done.';await refresh(); }
    catch(err){message.textContent=err.message || 'Could not complete that action.';}
    finally {working=false;}
  }
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const name=$('friendUsername').value.trim();
    if(!/^[A-Za-z0-9_]{3,20}$/.test(name)){message.textContent='Enter a valid username.';return;}
    await action(async()=>{const c=await client();const result=await c.rpc('wmc_friend_request',{target_username:name});if(!result.error)form.reset();return result;});
  });
  window.addEventListener('wmc-friends-open',()=>{message.textContent='';refresh();});
  window.setInterval(refresh,8000);
})();
