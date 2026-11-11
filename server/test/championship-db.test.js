import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';

const ids=['00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003'];
const match='00000000-0000-4000-8000-000000000010';
const sql=name=>readFileSync(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8');
test('Postgres migration awards durable points once and exposes only lobby members',async()=>{
 const db=new PGlite();try{
  await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth;
   create function auth.role() returns text language sql as $$ select current_setting('test.role',true) $$;
   create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
   create table public.rider_profiles(id uuid primary key);
   create table public.wmc_lobby_members(lobby_id uuid,user_id uuid);`);
  for(const id of ids)await db.query('insert into rider_profiles values ($1)',[id]);
  await db.query('insert into wmc_lobby_members values ($1,$2),($1,$3)',[match,ids[0],ids[1]]);
  await db.exec(sql('202611100004_authoritative_stats.sql'));await db.exec(sql('202611100006_championship_points.sql'));
  const entrants=JSON.stringify([{id:ids[0],dnf:false},{id:ids[1],dnf:false},{id:ids[2],dnf:true}]);
  await db.exec("select set_config('test.role','authenticated',false)");
  await assert.rejects(db.query('select public.wmc_record_authoritative_match($1,$2::jsonb)',[match,entrants]),/server only/);
  await db.exec("select set_config('test.role','service_role',false)");
  let result=await db.query('select public.wmc_record_authoritative_match($1,$2::jsonb) as recorded',[match,entrants]);assert.equal(result.rows[0].recorded,true);
  result=await db.query('select public.wmc_record_authoritative_match($1,$2::jsonb) as recorded',[match,entrants]);assert.equal(result.rows[0].recorded,false);
  result=await db.query('select user_id,championship_points,races from public.wmc_authoritative_stats order by user_id');assert.deepEqual(result.rows.map(x=>[x.championship_points,x.races]),[[25,1],[20,1],[0,1]]);
  const many=Array.from({length:15},(_,i)=>`00000000-0000-4000-8000-${String(i+100).padStart(12,'0')}`);
  for(const id of many)await db.query('insert into rider_profiles values ($1)',[id]);
  await db.query('select public.wmc_record_authoritative_match($1,$2::jsonb)',[ids[0],JSON.stringify(many.map(id=>({id,dnf:false})))]);
  result=await db.query('select championship_points from public.wmc_authoritative_stats where user_id=any($1::uuid[]) order by user_id',[many]);assert.deepEqual(result.rows.map(r=>r.championship_points),[25,20,16,13,11,10,9,8,7,6,5,4,3,2,1]);
  await assert.rejects(db.query('select public.wmc_record_authoritative_match($1,$2::jsonb)',[ids[1],JSON.stringify([{id:ids[0],dnf:false},{id:ids[0],dnf:false}])]),/duplicate/);
  await db.query("select set_config('test.uid',$1,false)",[ids[0]]);
  result=await db.query('select public.wmc_session_championship($1) as data',[match]);assert.equal(result.rows[0].data.recorded,true);assert.deepEqual(result.rows[0].data.riders.map(x=>x.id).sort(),ids.slice(0,2));
  result=await db.query('select public.wmc_session_championship($1) as data',[ids[2]]);assert.equal(result.rows[0].data.recorded,false);
  await db.query("select set_config('test.uid',$1,false)",[ids[2]]);result=await db.query('select public.wmc_session_championship($1) as data',[match]);assert.equal(result.rows[0].data,null);
 }finally{await db.close()}
});
