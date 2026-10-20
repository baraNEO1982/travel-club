import {DatabaseSync} from 'node:sqlite';
import {mkdir,readFile,writeFile,rename,unlink} from 'node:fs/promises';
import {join} from 'node:path';
export async function storage(directory){
 await mkdir(join(directory,'photos'),{recursive:true,mode:0o700});
 const sqlite=new DatabaseSync(join(directory,'club.sqlite'));
 sqlite.exec('PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;');
 const DB={prepare(sql){let values=[];return {bind(...v){values=v;return this;},async first(){return sqlite.prepare(sql).get(...values)??null;},async all(){return {results:sqlite.prepare(sql).all(...values)};},async run(){const r=sqlite.prepare(sql).run(...values);return {meta:{changes:Number(r.changes)}};}};}};
 const file=id=>{if(!/^[a-f0-9-]{36}$/.test(id))throw Error('Invalid photo id');return join(directory,'photos',id);};
 const PHOTOS={async put(id,bytes){const target=file(id),temp=target+'.'+crypto.randomUUID()+'.tmp';await writeFile(temp,bytes,{mode:0o600});await rename(temp,target);},async get(id){try{return new Uint8Array(await readFile(file(id)));}catch(e){if(e.code==='ENOENT')return null;throw e;}},async delete(id){await unlink(file(id)).catch(e=>{if(e.code!=='ENOENT')throw e;});}};
 return {DB,PHOTOS,sqlite};
}
