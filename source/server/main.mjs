import {createServer} from 'node:http';
import {Readable} from 'node:stream';
import {readFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import worker from './club.mjs';
import {storage} from './storage.mjs';
const origin=process.env.PUBLIC_ORIGIN||'https://marshrutclub.ru';
const root=resolve(process.env.WEB_ROOT||'dist-web');
const {DB,PHOTOS}=await storage(process.env.DATA_DIR||'data');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.webp':'image/webp','.ico':'image/x-icon','.woff2':'font/woff2'};
const ASSETS={async fetch(req){let path;try{path=decodeURIComponent(new URL(req.url).pathname);}catch{return new Response('Bad request',{status:400});}let target=resolve(root,'.'+path);if(target!==root&&!target.startsWith(root+sep))return new Response('Forbidden',{status:403});if(path.endsWith('/'))target=resolve(root,'index.html');try{const body=await readFile(target);return new Response(body,{headers:{'Content-Type':mime[extname(target)]||'application/octet-stream'}});}catch(e){if(e.code!=='ENOENT')return new Response('Not found',{status:404});if(extname(path))return new Response('Not found',{status:404});return new Response(await readFile(resolve(root,'index.html')),{headers:{'Content-Type':'text/html; charset=utf-8'}});}}};
const env={DB,PHOTOS,ASSETS,PUBLIC_ORIGIN:origin,BREVO_API_KEY:process.env.BREVO_API_KEY,EMAIL_FROM:process.env.EMAIL_FROM};
createServer(async(req,res)=>{try{
 const headers=new Headers();for(const [k,v]of Object.entries(req.headers))if(v!==undefined)headers.set(k,Array.isArray(v)?v.join(','):v);
 // Only the local reverse proxy can reach this listener; it must overwrite X-Real-IP.
 headers.set('CF-Connecting-IP',req.headers['x-real-ip']||req.socket.remoteAddress||'local');
 const init={method:req.method,headers};if(!['GET','HEAD'].includes(req.method)){init.body=Readable.toWeb(req);init.duplex='half';}
 const request=new Request(new URL(origin+req.url),init);
 const response=await worker.fetch(request,env,{waitUntil(p){p.catch(()=>console.error('Background operation failed'));}});
 res.writeHead(response.status,Object.fromEntries(response.headers));if(response.body&&req.method!=='HEAD')Readable.fromWeb(response.body).pipe(res);else res.end();
 }catch{res.writeHead(500,{'Cache-Control':'no-store'});res.end('Server error');}
}).listen(Number(process.env.PORT||3000),'127.0.0.1');
