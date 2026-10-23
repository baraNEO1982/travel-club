'use client';
import {useEffect,useRef,useState} from 'react';
import {Dialog,DialogContent,DialogHeader,DialogTitle,DialogDescription} from '@/components/ui/dialog';
type Stop={title:string;note:string;lat:number|null;lon:number|null;photoIds?:string[]};
export function RouteMap({stops,active,onSelect}:{stops:Stop[];active:number;onSelect:(index:number)=>void}){
 const el=useRef<HTMLDivElement>(null),map=useRef<any>(null),markers=useRef<any[]>([]),select=useRef(onSelect);select.current=onSelect;
 const [error,setError]=useState('');
 const [viewer,setViewer]=useState<{stop:number;photo:number}|null>(null);
 const selected=viewer?stops[viewer.stop]:null;const ids=selected?.photoIds||[];
 const [popup,setPopup]=useState<number|null>(null);
 function fit(){const ol=(window as any).ol;const points=stops.filter(s=>s.lat!=null&&s.lon!=null).map(s=>ol.proj.fromLonLat([s.lon,s.lat]));if(map.current&&points.length)map.current.getView().fit(ol.extent.boundingExtent(points),{padding:[40,40,40,40],maxZoom:13});}
 useEffect(()=>{
 const ol=(window as any).ol;if(!ol||!el.current){setError('Карта не загрузилась. Обновите страницу.');return;}
 const tiles=new ol.source.OSM();tiles.on('tileloaderror',()=>setError('Фон карты недоступен. Точки и список маршрута остаются доступны.'));
 const m=new ol.Map({target:el.current,layers:[new ol.layer.Tile({source:tiles})],view:new ol.View({center:ol.proj.fromLonLat([40,40]),zoom:2}),controls:ol.control.defaults.defaults({zoomOptions:{zoomOutLabel:'−',zoomInTipLabel:'Приблизить',zoomOutTipLabel:'Отдалить'},attributionOptions:{collapsible:false}}),interactions:ol.interaction.defaults.defaults({mouseWheelZoom:false})});map.current=m;markers.current=[];
 const points:number[][]=[];
 stops.forEach((s,i)=>{if(s.lat==null||s.lon==null)return;const point=ol.proj.fromLonLat([s.lon,s.lat]);points.push(point);markers.current[i]=point;
 const button=document.createElement('button');button.type='button';button.className='ol-route-pin';button.textContent=String(i+1);button.title=s.title;button.setAttribute('aria-label',`Остановка ${i+1}: ${s.title}`);button.onclick=()=>{setPopup(i);select.current(i);};
 m.addOverlay(new ol.Overlay({element:button,position:point,positioning:'center-center',stopEvent:true}));});
 if(points.length>1){const feature=new ol.Feature(new ol.geom.LineString(points));m.addLayer(new ol.layer.Vector({source:new ol.source.Vector({features:[feature]}),style:new ol.style.Style({stroke:new ol.style.Stroke({color:'#647447',width:2,lineDash:[5,8]})})}));}
 if(points.length)fit();const observer=new ResizeObserver(()=>m.updateSize());observer.observe(el.current);return()=>{observer.disconnect();m.setTarget(undefined);m.dispose();map.current=null;};
 },[stops]);
 useEffect(()=>{const point=markers.current[active];if(point&&map.current){map.current.getView().setCenter(point);map.current.getView().setZoom(Math.max(map.current.getView().getZoom(),11));setPopup(active);}},[active]);
 const stop=popup===null?null:stops[popup];
 return <div className="route-overview"><div ref={el} className="route-map-canvas" tabIndex={0} aria-label="Карта всех остановок"/>{stop&&popup!==null&&<div className="route-point-card"><button className="route-point-close" aria-label="Закрыть описание точки" onClick={()=>setPopup(null)}>×</button><strong>{stop.title}</strong><p>{stop.note}</p>{!!stop.photoIds?.length&&<div className="route-popup-photos">{stop.photoIds.map((id,j)=><button key={id} type="button" aria-label={`Открыть фото ${j+1}: ${stop.title}`} onClick={()=>setViewer({stop:popup,photo:j})}><img src={'/api/photos/'+id} alt={stop.title} loading="lazy"/></button>)}</div>}</div>}<div className="route-map-toolbar"><button type="button" className="text-button" onClick={fit}>Весь маршрут ↗</button><small>Пунктир — порядок остановок, не дорога.</small></div>{error&&<p role="status">{error}</p>}<Dialog open={!!viewer} onOpenChange={open=>{if(!open)setViewer(null);}}><DialogContent className="route-photo-dialog"><DialogHeader><DialogTitle>{selected?.title}</DialogTitle><DialogDescription>{selected?.note}</DialogDescription></DialogHeader>{viewer&&ids[viewer.photo]&&<><img className="route-full-photo" src={'/api/photos/'+ids[viewer.photo]} alt={selected?.title||'Фото путешествия'}/><div className="route-photo-navigation"><button type="button" disabled={viewer.photo===0} onClick={()=>setViewer({...viewer,photo:viewer.photo-1})}>← Предыдущее</button><span>{viewer.photo+1} / {ids.length}</span><button type="button" disabled={viewer.photo===ids.length-1} onClick={()=>setViewer({...viewer,photo:viewer.photo+1})}>Следующее →</button></div></>}</DialogContent></Dialog></div>;
}
