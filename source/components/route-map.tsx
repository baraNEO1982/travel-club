'use client';
import {useEffect,useRef,useState} from 'react';
type Stop={title:string;note:string;lat:number|null;lon:number|null};
export function RouteMap({stops,active,onSelect}:{stops:Stop[];active:number;onSelect:(index:number)=>void}){
 const el=useRef<HTMLDivElement>(null),map=useRef<any>(null),markers=useRef<any[]>([]),select=useRef(onSelect);select.current=onSelect;
 const [error,setError]=useState('');
 function fit(){const L=(window as any).L;const points=stops.filter(s=>s.lat!=null&&s.lon!=null).map(s=>[s.lat,s.lon]);if(map.current&&points.length)map.current.fitBounds(L.latLngBounds(points),{padding:[35,35],maxZoom:13});}
 useEffect(()=>{const L=(window as any).L;if(!L||!el.current){setError('Карта не загрузилась. Обновите страницу.');return;}const m=L.map(el.current,{scrollWheelZoom:false});map.current=m;markers.current=[];
 const tiles=L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'}).addTo(m);tiles.on('tileerror',()=>setError('Фон карты недоступен. Точки и список маршрута остаются доступны.'));
 const points:number[][]=[];stops.forEach((s,i)=>{if(s.lat==null||s.lon==null)return;points.push([s.lat,s.lon]);const content=document.createElement('div');const title=document.createElement('strong');title.textContent=s.title;content.append(title);const note=document.createElement('p');note.textContent=s.note;content.append(note);const marker=L.marker([s.lat,s.lon],{title:s.title,icon:L.divIcon({className:'route-pin',html:`<span>${i+1}</span>`,iconSize:[30,30],iconAnchor:[15,15]})}).addTo(m).bindPopup(content);marker.on('click',()=>select.current(i));markers.current[i]=marker;});
 if(points.length){L.polyline(points,{color:'#647447',weight:2,dashArray:'5 8',opacity:.65,interactive:false}).addTo(m);fit();}else m.setView([40,40],2);
 const observer=new ResizeObserver(()=>m.invalidateSize());observer.observe(el.current);return()=>{observer.disconnect();m.remove();map.current=null;};},[stops]);
 useEffect(()=>{const marker=markers.current[active];if(marker&&map.current){map.current.setView(marker.getLatLng(),Math.max(map.current.getZoom(),11));marker.openPopup();}},[active]);
 return <div className="route-overview"><div ref={el} className="route-map-canvas" aria-label="Карта всех остановок"/><div className="route-map-toolbar"><button type="button" className="text-button" onClick={fit}>Весь маршрут ↗</button><small>Пунктир — порядок остановок, не дорога.</small></div>{error&&<p role="status">{error}</p>}</div>;
}
