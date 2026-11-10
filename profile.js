(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const colors = {blue:'#176bb3',red:'#e4202c',yellow:'#f2ca24',orange:'#f47b20',green:'#268950',cyan:'#00a6bb',purple:'#814bb5',pink:'#da5696',white:'#f4f4f4',black:'#262626',silver:'#b2b9bb'};
  const config = window.WMC_AUTH_CONFIG || {};
  const account = $('accountButton'), out = $('signOutButton'), status = $('accountStatus');
  const form = $('profileForm'), overlay = $('profileOverlay'), error = $('profileError');
  let client = null, user = null;

  function riderLabel(name) {
    const words = name.trim().split(/\s+/);
    return (words[0].charAt(0) + ' ' + words[words.length - 1].slice(0, 3)).toUpperCase();
  }
  function applyProfile(profile) {
    // The in-world tag uses the full profile name, not the abbreviated tower label.
    window.WMCRiderProfile = {display_name:profile.display_name, number:profile.rider_number, color:profile.plate_color};
    document.querySelectorAll('.rider-short').forEach(el => { el.textContent = riderLabel(profile.display_name); });
    document.querySelectorAll('.rider-number').forEach(el => {
      el.textContent = profile.rider_number;
      el.style.backgroundColor = colors[profile.plate_color];
      el.style.color = ['yellow','white','silver','cyan'].includes(profile.plate_color) ? '#111' : '#fff';
    });
  }
  function resetRider() {
    window.WMCRiderProfile = null;
    document.querySelectorAll('.rider-short').forEach(el => { el.textContent = 'D EFA'; });
    document.querySelectorAll('.rider-number').forEach(el => { el.textContent = '0'; el.style.backgroundColor=''; el.style.color=''; });
  }
  function edit(profile) {
    error.textContent = '';
    $('displayName').value = profile ? profile.display_name : '';
    $('username').value = profile ? profile.username : '';
    $('riderNumber').value = profile ? profile.rider_number : '';
    $('plateColor').value = profile ? profile.plate_color : 'blue';
    overlay.hidden = false;
  }
  async function loadProfile() {
    if (!user) return;
    const {data, error: problem} = await client.from('rider_profiles').select('display_name,username,rider_number,plate_color').eq('id', user.id).maybeSingle();
    if (problem) { status.textContent = 'Could not load profile. Try again.'; return; }
    account.textContent = 'Edit profile'; out.hidden = false;
    if (data) { applyProfile(data); status.textContent = '@' + data.username; account.onclick = () => edit(data); }
    else { resetRider(); status.textContent = 'Complete your rider profile'; account.onclick = () => edit(null); edit(null); }
  }
  window.wmcAuthCallback = async function (code, authError) {
    if (!client) { status.textContent = 'Sign-in is not configured.'; return; }
    if (authError) { status.textContent = 'Google sign-in was cancelled or failed.'; return; }
    const {error: problem} = await client.auth.exchangeCodeForSession(code);
    if (problem) status.textContent = 'Sign-in failed: ' + problem.message;
  };
  if (!config.url || !config.anonKey || !window.supabase) {
    account.onclick = () => { status.textContent = 'Google sign-in is not configured yet; guest play is available.'; };
    return;
  }
  client = window.supabase.createClient(config.url, config.anonKey, {auth:{flowType:'pkce',detectSessionInUrl:true}});
  window.WMCAuth = { client: client };
  window.dispatchEvent(new Event('wmc-auth-ready'));
  account.onclick = async () => {
    status.textContent = 'Opening Google sign-in…';
    const native = !!(window.WMCAndroid && window.WMCAndroid.openAuth);
    const redirectTo = native ? 'wmc://auth-callback' : new URL('index.html', location.href).href.split('?')[0].split('#')[0];
    const {data, error: problem} = await client.auth.signInWithOAuth({provider:'google', options:{redirectTo, skipBrowserRedirect:native}});
    if (problem) status.textContent = 'Sign-in failed: ' + problem.message;
    else if (native && data.url) window.WMCAndroid.openAuth(data.url);
  };
  out.onclick = async () => {
    const {error: problem} = await client.auth.signOut();
    if (problem) { status.textContent = 'Sign-out failed: ' + problem.message; return; }
    user = null; overlay.hidden = true; out.hidden = true; resetRider(); account.textContent = 'Sign in with Google'; location.reload();
  };
  $('profileClose').onclick = () => { overlay.hidden = true; };
  form.onsubmit = async event => {
    event.preventDefault();
    if (!user) return;
    const name = $('displayName').value.trim().replace(/\s+/g,' '), username = $('username').value.toLowerCase(), number = Number($('riderNumber').value), color = $('plateColor').value;
    if (name.length > 15 || !/^\S+ \S+(?: .*\S)?$/.test(name)) { error.textContent = 'Use a display name with at least two words and no more than 15 characters.'; return; }
    if (!/^[a-z0-9_]{3,20}$/.test(username)) { error.textContent = 'Username must be 3–20 letters, numbers, or underscores.'; return; }
    if (!Number.isInteger(number) || number < 10 || number > 99 || !colors[color]) { error.textContent = 'Choose a two-digit number and a plate color.'; return; }
    const profile = {id:user.id, display_name:name, username, rider_number:number, plate_color:color};
    const {error: problem} = await client.from('rider_profiles').upsert(profile);
    if (problem) { error.textContent = problem.code === '23505' ? 'That username is already taken.' : 'Could not save profile: ' + problem.message; return; }
    overlay.hidden = true; await loadProfile();
  };
  client.auth.onAuthStateChange((_event, session) => {
    user = session && session.user;
    if (user) setTimeout(loadProfile, 0);
    else resetRider();
  });
})();
