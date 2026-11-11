// Store results using a server-only key. Opaque Supabase keys are API keys,
// not JWTs: do not put sb_secret_ values in the Authorization header.
export function createResultWriter({url,key,request=fetch}) {
  const base=new URL(url);if(base.protocol!=='https:'||!key)throw Error('A server-only Supabase key and HTTPS URL are required');
  const headers={apikey:key,'Content-Type':'application/json'};
  if(!key.startsWith('sb_secret_'))headers.Authorization=`Bearer ${key}`;
  return async snapshot=>{
    const entrants=snapshot.players.slice().sort((a,b)=>Number(a.dnf)-Number(b.dnf)||(a.finishAt??Infinity)-(b.finishAt??Infinity)||(a.grid??0)-(b.grid??0)||a.id.localeCompare(b.id)).map(p=>({id:p.id,dnf:p.dnf}));
    const r=await request(new URL('/rest/v1/rpc/wmc_record_authoritative_match',base),{method:'POST',headers,body:JSON.stringify({match_id:snapshot.matchId,entrants}),signal:AbortSignal.timeout(8000)});
    if(!r.ok)throw Error('Result storage failed');
  };
}
