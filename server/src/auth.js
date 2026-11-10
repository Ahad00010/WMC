// Only fixed diagnostic codes are exposed; tokens, headers, responses and user data stay private.
const messages={AUTH_REQUEST_FAILED:'Supabase sign-in service unreachable',AUTH_HTTP:'Supabase rejected sign-in check',AUTH_INVALID:'Invalid sign-in response',LOBBY_REQUEST_FAILED:'Supabase lobby service unreachable',LOBBY_HTTP:'Supabase rejected lobby check',LOBBY_INVALID:'Invalid lobby response',LOBBY_MISSING:'Rider is not in an eligible lobby'};
export class AuthError extends Error {
  constructor(code,status,upstreamCode,kind){super(messages[code]||'Race authentication failed');this.code=code;this.status=Number.isInteger(status)?status:undefined;this.upstreamCode=upstreamCode;this.kind=kind}
}
export function createSupabaseAuth({url,key,request=fetch}){
  const base=new URL(url);if(base.protocol!=='https:')throw Error('Supabase URL must use HTTPS');if(!key)throw Error('Supabase API key is required');
  return async function authenticate(token){
    const headers={apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'};
    async function get(path,stage,options={}){
      let response;
      try{response=await request(new URL(path,base),{...options,headers,signal:AbortSignal.timeout(8000)})}
      catch{throw new AuthError(stage+'_REQUEST_FAILED')}
      if(!response.ok){
        // Only report documented, fixed error identifiers; never log upstream text or tokens.
        let upstreamCode;const type=response.headers?.get('content-type')||'';const kind=response.headers?.get('cf-mitigated')==='challenge'?'challenge':type.includes('json')?'json':type.includes('html')?'html':'other';
        try{const body=await response.json();const allowed=new Set(['bad_jwt','session_not_found','user_not_found','user_banned','invalid_api_key','not_admin','insufficient_aal','unexpected_failure']);const candidate=body?.code||body?.error_code;if(allowed.has(candidate))upstreamCode=candidate}catch{}
        throw new AuthError(stage+'_HTTP',response.status,upstreamCode,kind);
      }
      try{return await response.json()}catch{throw new AuthError(stage+'_INVALID')}
    }
    const user=await get('/auth/v1/user','AUTH');
    if(!user||typeof user.id!=='string')throw new AuthError('AUTH_INVALID');
    const snap=await get('/rest/v1/rpc/wmc_lobby_snapshot','LOBBY',{method:'POST',body:'{}'});
    const lobby=snap?.lobby,profile=Array.isArray(lobby?.members)?lobby.members.find(p=>p.id===user.id):null;
    if(snap?.user_id!==user.id||!lobby||!profile)throw new AuthError('LOBBY_MISSING');
    return {userId:user.id,lobby,profile};
  };
}
