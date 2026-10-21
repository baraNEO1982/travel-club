'use client';
import {useEffect,useState,useRef} from 'react';
import {Bell} from 'lucide-react';
import {api} from '@/lib/club-api';
type Notice={id:string;trip_id:string;title:string;inviter:string;read_at:number|null;created_at:number};
export function ClubNotifications({onOpen}:{onOpen:(id:string)=>Promise<void>}){
 const [items,setItems]=useState<Notice[]>([]),[expanded,setExpanded]=useState(false),[error,setError]=useState(''),[busy,setBusy]=useState(false);const live=useRef(true);
 async function refresh(){try{const r=await api('/notifications');if(live.current){setItems(r.notifications);setError('');}}catch{if(live.current)setError('Не удалось проверить уведомления.');}}
 useEffect(()=>{live.current=true;void refresh();const focus=()=>{if(!document.hidden)void refresh();};window.addEventListener('focus',focus);document.addEventListener('visibilitychange',focus);const timer=setInterval(focus,60000);return()=>{live.current=false;clearInterval(timer);window.removeEventListener('focus',focus);document.removeEventListener('visibilitychange',focus);};},[]);
 const unread=items.filter(n=>!n.read_at),visible=expanded?items:unread;
 async function read(n:Notice,open:boolean){if(busy)return;setBusy(true);try{if(open)await onOpen(n.trip_id);await api('/notifications/read',{id:n.id});await refresh();}catch(e){if(live.current)setError(e instanceof Error?e.message:'Не удалось открыть уведомление.');}finally{if(live.current)setBusy(false);}}
 return <section className="club-notifications" aria-label="Уведомления"><button className="notifications-toggle" type="button" aria-expanded={expanded} onClick={()=>setExpanded(!expanded)}><Bell size={18}/> Уведомления {unread.length>0&&<span className="notifications-count">{unread.length}</span>}</button>{error&&<p role="status">{error} <button type="button" onClick={refresh}>Повторить</button></p>}{unread.length>0&&<p className="notifications-summary" role="status">Вас добавили в {unread.length===1?'путешествие':'путешествия'} — можно присоединяться к общему рассказу.</p>}{expanded&&items.length===0&&<p>Пока нет уведомлений.</p>}{visible.map(n=><div key={n.id} className={'club-notification'+(!n.read_at?' unread':'')}><div><strong>{n.inviter}</strong> добавил(а) вас в попутчики<p>{n.title}</p></div><div className="notification-actions"><button className="text-button" type="button" disabled={busy} onClick={()=>read(n,true)}>Открыть путешествие →</button>{!n.read_at&&<button type="button" disabled={busy} onClick={()=>read(n,false)}>Прочитано</button>}</div></div>)}</section>;
}
