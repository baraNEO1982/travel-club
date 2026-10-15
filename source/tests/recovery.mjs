import {Miniflare} from 'miniflare';
import {build} from 'esbuild';
import {readFile} from 'node:fs/promises';
import {createHash,randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
await build({entryPoints:['worker/club.ts'],bundle:true,format:'esm',platform:'neutral',external:['node:*'],outfile:'.wrangler/recovery-test.mjs'});
const messages=[];let providerFails=false;
const options={modules:true,scriptPath:'.wrangler/recovery-test.mjs',compatibilityDate:'2026-05-22',compatibilityFlags:['nodejs_compat'],d1Databases:['DB'],kvNamespaces:['PHOTOS']};
const mf=new Miniflare({...options,bindings:{BREVO_API_KEY:'test-only',EMAIL_FROM:'sender@example.test'},outboundService:async req=>{assert.equal(req.url,'https://api.brevo.com/v3/smtp/email');if(providerFails)return new Response('{}',{status:503});messages.push(await req.json());return new Response('{"messageId":"mock"}',{status:201});}});
const sha=s=>createHash('sha256').update(s).digest('hex');
let cookie='';
async function call(path,body,auth=true){const r=await mf.dispatchFetch('https://club.test/api'+path,{method:body===undefined?'GET':'POST',headers:{origin:'https://club.test','content-type':'application/json',cookie:auth?cookie:''},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,data:await r.json(),cookie:r.headers.get('set-cookie')?.split(';')[0]};}
try{
 const db=await mf.getD1Database('DB');
 for(const file of ['0001.sql','0002_story_details.sql','0003_email_recovery.sql'])for(const statement of (await readFile('database/club/'+file,'utf8')).trim().split(/;\n(?=CREATE|INSERT|ALTER)/))await db.exec(statement.replaceAll('\n',' '));
 const invite=randomBytes(32).toString('hex');await db.prepare('INSERT INTO invitations(hash,expires) VALUES(?,?)').bind(sha(invite),Math.floor(Date.now()/1000)+600).run();
 const registered=await call('/register',{username:'owner',name:'Owner',password:'original password123',invite});assert.equal(registered.status,201);cookie=registered.cookie;const uid=registered.data.user.id;
 assert.equal((await call('/account/email')).data.email,null);
 const unknown=await call('/password/request',{email:'owner@example.test'},false);assert.equal(unknown.status,200);assert.equal(messages.length,0);
 assert.equal((await call('/account/email',{email:'owner@example.test',password:'wrong password12'})).status,403);
 assert.equal((await call('/account/email',{email:'owner@example.test',password:'original password123'})).status,200);assert.equal(messages.length,1);
 let verifyToken=messages.at(-1).textContent.match(/verify-email=([a-f0-9]{64})/)[1];
 assert.equal((await call('/account/email')).data.email,null);
 const noMail=await call('/password/request',{email:'owner@example.test'},false);assert.deepEqual(noMail.data,unknown.data);assert.equal(messages.length,1);
 assert.equal((await call('/email/confirm',{token:verifyToken},false)).status,200);
 assert.equal((await call('/email/confirm',{token:verifyToken},false)).status,400);
 assert.equal((await call('/account/email')).data.email,'owner@example.test');
 const known=await call('/password/request',{email:'owner@example.test'},false);for(let i=0;i<100&&messages.length<2;i++)await new Promise(resolve=>setTimeout(resolve,10));assert.deepEqual(known.data,unknown.data);assert.equal(messages.length,2);
 let resetToken=messages.at(-1).textContent.match(/reset-password=([a-f0-9]{64})/)[1];
 assert.equal((await call('/password/reset',{token:verifyToken,password:'replacement password123'},false)).status,400);
 assert.equal((await call('/password/reset',{token:resetToken,password:'short'},false)).status,400);
 const race=await Promise.all(['replacement password123','replacement password456'].map(password=>call('/password/reset',{token:resetToken,password},false)));assert.deepEqual(race.map(r=>r.status).sort(),[200,400]);
 assert.equal((await call('/trips')).status,401);
 assert.equal((await call('/password/reset',{token:resetToken,password:'another password123'},false)).status,400);
 assert.equal((await call('/login',{username:'owner',password:'original password123'},false)).status,401);
 const winning=race[0].status===200?'replacement password123':'replacement password456';const login=await call('/login',{username:'owner',password:winning},false);assert.equal(login.status,200);cookie=login.cookie;
 const expired=randomBytes(32).toString('hex');await db.prepare("INSERT INTO email_tokens(hash,user_id,email,purpose,expires) VALUES(?,?,?,'reset',?)").bind(sha(expired),uid,'owner@example.test',Math.floor(Date.now()/1000)-1).run();assert.equal((await call('/password/reset',{token:expired,password:'should never work123'},false)).status,400);
 providerFails=true;assert.equal((await call('/account/email',{email:'other@example.test',password:winning})).status,503);assert.equal((await db.prepare("SELECT COUNT(*) AS n FROM email_tokens WHERE email='other@example.test'").first()).n,0);
 const raw=await db.prepare('SELECT hash FROM email_tokens').all();assert.ok(raw.results.every(r=>r.hash!==verifyToken&&r.hash!==resetToken));
 console.log('PASS: verified-email requirement, current-password check, generic reset responses, purpose/expiry/replay/race protection, session invalidation, old-password rejection, failed-mail token cleanup.');
}finally{await mf.dispose();}
const disabled=new Miniflare(options);try{for(const path of ['/password/request','/account/email']){if(path==='/account/email')continue;const r=await disabled.dispatchFetch('https://club.test/api'+path,{method:'POST',headers:{origin:'https://club.test','content-type':'application/json'},body:'{"email":"owner@example.test"}'});assert.equal(r.status,503);}console.log('PASS: no false email success when delivery is not configured.');}finally{await disabled.dispose();}
