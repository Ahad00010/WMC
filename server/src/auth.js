// The lobby RPC is called with the rider's own JWT, never a service key.
// PostgREST validates the JWT before invoking it, and the RPC derives user_id
// from auth.uid(); a client-supplied user id is never accepted.
const messages={LOBBY_REQUEST_FAILED:'Supabase lobby service unreachable',LOBBY_HTTP:'Supabase rejected lobby check',LOBBY_INVALID:'Invalid lobby response',LOBBY_MISSING:'Rider is not in an eligible lobby'};
export class AuthError extends Error {
  constructor(code,status,upstreamCode,kind){super(messages[code]||'Race authentication failed');this.code=code;this.status=Number.isInteger(status)?status:undefined;this.upstreamCode=upstreamCode;this.kind=kind}
}
export function createSupabaseAuth({url,key,request=fetch}){
  const base=new URL(url);if(base.protocol!=='https:')throw Error('Supabase URL must use HTTPS');if(!key)throw Error('Supabase API key is required');
  return async function authenticate(token){
    if(typeof token!=='string'||!token||token.length>8192)throw new AuthError('LOBBY_MISSING');
    const headers={apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'};
    let response;
    try{response=await request(new URL('/rest/v1/rpc/wmc_lobby_snapshot',base),{method:'POST',body:'{}',headers,signal:AbortSignal.timeout(8000)})}
    catch{throw new AuthError('LOBBY_REQUEST_FAILED')}
    if(!response.ok){
      let upstreamCode;const type=response.headers?.get('content-type')||'';const kind=response.headers?.get('cf-mitigated')==='challenge'?'challenge':type.includes('json')?'json':type.includes('html')?'html':'other';
      try{const body=await response.json();const allowed=new Set(['bad_jwt','session_not_found','user_not_found','user_banned','invalid_api_key','not_admin','insufficient_aal','unexpected_failure','PGRST301','PGRST302']);const candidate=body?.code||body?.error_code;if(allowed.has(candidate))upstreamCode=candidate}catch{}
      throw new AuthError('LOBBY_HTTP',response.status,upstreamCode,kind);
    }
    let snap;try{snap=await response.json()}catch{throw new AuthError('LOBBY_INVALID')}
    const userId=snap?.user_id,lobby=snap?.lobby,profile=Array.isArray(lobby?.members)?lobby.members.find(p=>p.id===userId):null;
    if(typeof userId!=='string'||!userId||!lobby||!profile)throw new AuthError('LOBBY_MISSING');
    return {userId,lobby,profile};
  };
}
