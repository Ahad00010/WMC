import {createServer} from './server.js';
const {SUPABASE_URL,SUPABASE_ANON_KEY,SUPABASE_SERVICE_ROLE_KEY,ALLOWED_ORIGINS,PORT='8080'}=process.env;
if(!SUPABASE_URL||!SUPABASE_ANON_KEY||!ALLOWED_ORIGINS)throw Error('SUPABASE_URL, SUPABASE_ANON_KEY and ALLOWED_ORIGINS are required');
const base=new URL(SUPABASE_URL);if(base.protocol!=='https:')throw Error('Supabase URL must use HTTPS');
const origins=ALLOWED_ORIGINS.split(',').map(s=>s.trim()).filter(Boolean);for(const origin of origins)if(new URL(origin).origin!==origin)throw Error('Invalid origin');
async function authenticate(token){const headers={apikey:SUPABASE_ANON_KEY,Authorization:`Bearer ${token}`,'Content-Type':'application/json'};async function get(path,options={}){const r=await fetch(new URL(path,base),{...options,headers,signal:AbortSignal.timeout(8000)});if(!r.ok)throw Error('Unauthorized');return r.json()}const user=await get('/auth/v1/user');const snap=await get('/rest/v1/rpc/wmc_lobby_snapshot',{method:'POST',body:'{}'});const profile=snap?.lobby?.members?.find(p=>p.id===user.id);if(!user.id||snap.user_id!==user.id||!profile)throw Error('Not in lobby');return {userId:user.id,lobby:snap.lobby,profile}}
const recordResult=SUPABASE_SERVICE_ROLE_KEY?async snapshot=>{
  const entrants=snapshot.players.slice().sort((a,b)=>Number(a.dnf)-Number(b.dnf)||(a.finishAt??Infinity)-(b.finishAt??Infinity)||a.id.localeCompare(b.id)).map(p=>({id:p.id,dnf:p.dnf}));
  const r=await fetch(new URL('/rest/v1/rpc/wmc_record_authoritative_match',base),{method:'POST',headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({match_id:snapshot.matchId,entrants}),signal:AbortSignal.timeout(8000)});if(!r.ok)throw Error('Result storage failed');
}:null;
if(!recordResult)console.warn('Results persistence is disabled: SUPABASE_SERVICE_ROLE_KEY not set');
async function diagnostics(){
  let supabase=false;
  try{const r=await fetch(new URL('/auth/v1/settings',base),{headers:{apikey:SUPABASE_ANON_KEY},signal:AbortSignal.timeout(5000)});supabase=r.ok}catch{}
  return {ok:true,websiteOriginAllowed:origins.includes('https://ahad00010.github.io'),supabaseAuthReachable:supabase};
}
const app=createServer({authenticate,allowedOrigins:origins,recordResult,diagnostics});app.server.listen(Number(PORT),'0.0.0.0',()=>console.log(`WMC race server listening on ${PORT}`));
for(const sig of ['SIGINT','SIGTERM'])process.on(sig,()=>app.close().then(()=>process.exit(0)));
