import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash,randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
import {storage} from './storage.mjs';
import worker from './club.mjs';
const dir=await mkdtemp(join(tmpdir(),'club-portable-'));
const env=await storage(dir);env.ASSETS={fetch:()=>new Response('test')};
try{
 for(const f of ['0001.sql','0002_story_details.sql','0003_email_recovery.sql'])env.sqlite.exec(await readFile(new URL('../database/club/'+f,import.meta.url),'utf8'));
 const invitation=randomBytes(32).toString('hex');env.sqlite.prepare('INSERT INTO invitations(hash,expires) VALUES(?,?)').run(createHash('sha256').update(invitation).digest('hex'),Math.floor(Date.now()/1000)+600);
 let cookie='';const call=async(path,body,extra={})=>worker.fetch(new Request('https://club.test/api'+path,{method:body===undefined?'GET':'POST',headers:{origin:'https://club.test','content-type':'application/json',cookie,...extra},body:body===undefined?undefined:JSON.stringify(body)}),env,{waitUntil:p=>p.catch(()=>{})});
 assert.equal((await call('/trips')).status,401);
 const r=await call('/register',{username:'owner',name:'Owner',password:'synthetic test password',invite:invitation});assert.equal(r.status,201);cookie=r.headers.get('set-cookie').split(';')[0];
 assert.equal((await call('/register',{username:'friend',name:'Friend',password:'synthetic test password',invite:invitation})).status,403);
 const t=await call('/trips',{title:'Test',place:'Lake',body:'Story'});assert.equal(t.status,201);const {id}=await t.json();
 assert.equal((await call('/trips/'+id+'/comments',{body:'Comment'})).status,201);
 const photo=crypto.randomUUID(),bytes=new Uint8Array([255,216,255,224,1,2]);
 const uploaded=await worker.fetch(new Request('https://club.test/api/trips/'+id+'/photos',{method:'POST',headers:{origin:'https://club.test',cookie,'X-Photo-Id':photo},body:bytes}),env,{});assert.equal(uploaded.status,201);
 assert.deepEqual(new Uint8Array(await (await call('/photos/'+photo)).arrayBuffer()),bytes);
 assert.equal((await call('/photos/'+photo+'/comments',{body:'Nice photo'})).status,201);
 assert.equal((await call('/photos/'+photo+'/details')).status,200);
 assert.equal((await call('/trips',{title:'x',body:'x'},{origin:'https://evil.test'})).status,403);
 cookie='';assert.equal((await call('/photos/'+photo)).status,401);
 console.log('Portable database, registration, private photos and comments checks passed');
}finally{env.sqlite.close();await rm(dir,{recursive:true,force:true});}
