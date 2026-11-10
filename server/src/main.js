import {createServer} from './server.js';
import {createSupabaseAuth} from './auth.js';
import {createResultWriter} from './results.js';
import {readFileSync} from 'node:fs';
const {SUPABASE_URL,ALLOWED_ORIGINS,PORT='8080'}=process.env;
const SUPABASE_ANON_KEY=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY;
const secretKey=process.env.SUPABASE_SECRET_KEY||process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!SUPABASE_URL||!SUPABASE_ANON_KEY||!ALLOWED_ORIGINS)throw Error('SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and ALLOWED_ORIGINS are required');
const base=new URL(SUPABASE_URL);if(base.protocol!=='https:')throw Error('Supabase URL must use HTTPS');
const origins=ALLOWED_ORIGINS.split(',').map(s=>s.trim()).filter(Boolean);for(const origin of origins)if(new URL(origin).origin!==origin)throw Error('Invalid origin');
const authenticate=createSupabaseAuth({url:SUPABASE_URL,key:SUPABASE_ANON_KEY});
const recordResult=secretKey?createResultWriter({url:SUPABASE_URL,key:secretKey}):null;
if(!recordResult)console.warn('Results persistence is disabled: SUPABASE_SECRET_KEY not set');
// The site's URL and publishable key are intentionally public. Only comparisons,
// never their values or any secret, are returned to diagnose deployment mismatches.
const gameConfig=readFileSync(new URL('../../auth-config.js',import.meta.url),'utf8');
const gameUrl=gameConfig.match(/url:\s*'([^']+)'/)?.[1];
const gameKey=gameConfig.match(/anonKey:\s*'([^']+)'/)?.[1];
async function diagnostics(){
  let supabase=false;
  try{const r=await fetch(new URL('/auth/v1/settings',base),{headers:{apikey:SUPABASE_ANON_KEY},signal:AbortSignal.timeout(5000)});supabase=r.ok}catch{}
  return {ok:true,version:'connection-diagnostics-3',projectMatchesGame:!!gameUrl&&base.origin===new URL(gameUrl).origin,publishableKeyMatchesGame:!!gameKey&&SUPABASE_ANON_KEY===gameKey,websiteOriginAllowed:origins.includes('https://ahad00010.github.io'),supabaseAuthReachable:supabase};
}
const app=createServer({authenticate,allowedOrigins:origins,recordResult,diagnostics});app.server.listen(Number(PORT),'0.0.0.0',()=>console.log(`WMC race server listening on ${PORT}`));
for(const sig of ['SIGINT','SIGTERM'])process.on(sig,()=>app.close().then(()=>process.exit(0)));
