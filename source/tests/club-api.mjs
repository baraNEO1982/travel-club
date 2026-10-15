import {Miniflare} from 'miniflare';
import {build} from 'esbuild';
import {readFile} from 'node:fs/promises';
import {createHash,randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
await build({entryPoints:['worker/club.ts'],bundle:true,format:'esm',platform:'neutral',external:['node:*'],outfile:'.wrangler/club-test.mjs'});
const mf=new Miniflare({modules:true,scriptPath:'.wrangler/club-test.mjs',compatibilityDate:'2026-05-22',compatibilityFlags:['nodejs_compat'],d1Databases:['DB'],kvNamespaces:['PHOTOS']});
try{
 const db=await mf.getD1Database('DB');
 for(const statement of (await readFile('database/club/0001.sql','utf8')).trim().split(/;\n(?=CREATE|INSERT)/))await db.exec(statement.replaceAll('\n',' '));
 const invitation=randomBytes(32).toString('hex');
 await db.prepare('INSERT INTO invitations(hash,expires) VALUES(?,?)').bind(createHash('sha256').update(invitation).digest('hex'),Math.floor(Date.now()/1000)+600).run();
 let cookie='';
 async function call(path,body,opts={}){const response=await mf.dispatchFetch('https://club.test/api'+path,{method:body===undefined?'GET':'POST',headers:{origin:'https://club.test','content-type':'application/json',cookie,...opts.headers},body:body===undefined?undefined:JSON.stringify(body)});return {response,status:response.status,data:await response.json()};}
 assert.equal((await call('/trips')).status,401);
 assert.equal((await call('/register',{username:'owner',name:'Owner',password:'test password 12345',invite:'a'.repeat(64)})).status,403);
 const registration=await call('/register',{username:'owner',name:'Owner',password:'test password 12345',invite:invitation});assert.equal(registration.status,201,JSON.stringify(registration.data));cookie=registration.response.headers.get('set-cookie').split(';')[0];assert.match(registration.response.headers.get('set-cookie'),/HttpOnly/);
 assert.equal((await call('/me')).data.user.username,'owner');
 assert.equal((await call('/register',{username:'other',name:'Other',password:'test password 12345',invite:invitation})).status,403);
 assert.equal((await call('/trips', {title:'bad',body:'bad'},{headers:{origin:'https://evil.test'}})).status,403);
 const tripId=crypto.randomUUID();const trip=await call('/trips',{id:tripId,title:'Test trip',place:'Lake',body:'A family story'});assert.equal(trip.status,201);const tid=trip.data.id;assert.equal((await call('/trips',{id:tripId,title:'Test trip',place:'Lake',body:'A family story'})).data.id,tid);assert.equal((await call('/trips')).data.trips.length,1);
 assert.equal((await call('/trips/'+tid+'/comments',{body:'Hello'})).status,201);
 assert.equal((await call('/trips/'+tid+'/comments')).data.comments.length,1);
 const bytes=new Uint8Array([255,216,255,224,1,2,3,4]);
 const upload=await mf.dispatchFetch('https://club.test/api/trips/'+tid+'/photos',{method:'POST',headers:{origin:'https://club.test','content-type':'image/jpeg',cookie},body:bytes});assert.equal(upload.status,201,await upload.clone().text());const photo=await upload.json();
 let response=await mf.dispatchFetch('https://club.test'+photo.url,{headers:{cookie}});assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');assert.deepEqual(new Uint8Array(await response.arrayBuffer()),bytes);
 response=await mf.dispatchFetch('https://club.test'+photo.url);assert.equal(response.status,401);
 const invite=(await call('/invites',{})).data.token;
 const registrations=await Promise.all(['friend1','friend2'].map(username=>call('/register',{username,name:'Friend',password:'friend password 12345',invite})));assert.deepEqual(registrations.map(r=>r.status).sort(),[201,403]);
 const other=registrations.find(r=>r.status===201).response.headers.get('set-cookie').split(';')[0];
 response=await mf.dispatchFetch('https://club.test/api/trips/'+tid+'/photos',{method:'POST',headers:{origin:'https://club.test',cookie:other},body:bytes});assert.equal(response.status,403);
 assert.equal((await call('/logout',{})).status,200);assert.equal((await call('/trips')).status,401);
 const login=await call('/login',{username:'owner',password:'test password 12345'});assert.equal(login.status,200);assert.equal((await call('/login',{username:'owner',password:'incorrect password'})).status,401);
 console.log('PASS: invite-only registration, replay/race rejection, password login, sessions/logout, CSRF, private stories/photos, comments, author-only upload.');
}finally{await mf.dispose();}
