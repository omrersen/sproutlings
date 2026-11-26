/* Sproutlings V2 browser-native WebGL farm. No CDN, no external assets. */
(() => {
"use strict";
const style=document.createElement("style");
style.textContent=`
.world-card{position:relative;overflow:hidden;border:1px solid #63846e;border-radius:18px;background:#203d32;margin:14px 0 20px;box-shadow:0 12px 34px #06150d55}
.world-canvas{display:block;width:100%;height:clamp(280px,50vw,520px);touch-action:none;outline:none;background:#adcfc7}
.world-head{position:absolute;top:14px;left:14px;max-width:75%;background:#173329ed;border:1px solid #7a9d7a66;border-radius:12px;padding:10px 14px;pointer-events:none}
.world-head strong{display:block;color:#f5dda0;font-size:16px}.world-head span{font-size:12px;color:#c6d9cb}
.world-tools{padding:10px 14px;display:flex;gap:7px;flex-wrap:wrap;align-items:center;background:#18332a}
.world-tools button{padding:7px 10px}.world-tools .status{flex:1;font-size:13px;color:#d4e4ce}
.world-note{padding:0 14px 12px;font-size:12px;color:#b8cbb9}.world-fallback{padding:24px}
.online-hero{margin:0 0 14px;padding:20px 24px;border-radius:18px;background:linear-gradient(110deg,#294c38,#355e46 70%,#67815d);border:1px solid #73907155}
.online-hero h2{margin:0 0 5px;font-size:26px;color:#f5dfae}.online-hero p{margin:0;color:#e1ead9}
.online-live{display:inline-block;color:#a9e5ae;font-size:12px;margin:6px 0}
@media(max-width:650px){.world-head{top:8px;left:8px;padding:7px 9px}.world-tools{padding:8px}.world-canvas{height:350px}}
`;document.head.appendChild(style);
const rgb=h=>[parseInt(h.slice(1,3),16)/255,parseInt(h.slice(3,5),16)/255,parseInt(h.slice(5,7),16)/255];
const palettes=["#b9a27a","#e69d9d","#72cddb","#81bd67","#db7650","#87b9dd","#665d99","#d0e8e9","#edb74d","#adbde8","#6261bd","#6aa47c"].map(rgb);
const col={grass:rgb("#85b66e"),earth:rgb("#6e5141"),soil:rgb("#966d4c"),wet:rgb("#73503b"),path:rgb("#ded4b3"),wood:rgb("#947051"),roof:rgb("#ae6155"),wall:rgb("#ead7b1"),leaf:rgb("#4f8751"),leaf2:rgb("#75af62"),water:rgb("#64c4cb"),white:rgb("#fff0d3"),eye:rgb("#273832"),gold:rgb("#f9d27d")};
const plantCols=["#edcf73","#f18d4e","#f0d44b","#bf78ce","#e45742","#8bd7eb","#fff2b0"].map(rgb);
const dark=(c,f)=>c.map(v=>Math.max(0,Math.min(1,v*f)));
const unit=(a)=>{let l=Math.hypot(...a)||1;return a.map(v=>v/l)};
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
const light=unit([-0.5,0.9,0.65]);
let vertices=[];
function tri(a,b,c,color){let n=unit(cross(sub(b,a),sub(c,a))),shade=.66+.34*Math.max(0,dot(n,light));for(let p of [a,b,c])vertices.push(...p,...dark(color,shade))}
function quad(a,b,c,d,color){tri(a,b,c,color);tri(a,c,d,color)}
function box(x,y,z,w,h,d,c){let a=x-w/2,b=x+w/2,l=y-h/2,t=y+h/2,m=z-d/2,n=z+d/2;
let p=[[a,l,m],[b,l,m],[b,l,n],[a,l,n],[a,t,m],[b,t,m],[b,t,n],[a,t,n]];
quad(p[4],p[7],p[6],p[5],c);quad(p[0],p[1],p[2],p[3],c);
quad(p[3],p[2],p[6],p[7],c);quad(p[1],p[0],p[4],p[5],c);quad(p[0],p[3],p[7],p[4],c);quad(p[2],p[1],p[5],p[6],c)}
function cylinder(x,y,z,r1,r2,h,c,n=9){let l=y-h/2,t=y+h/2;
for(let i=0;i<n;i++){let a=i*Math.PI*2/n,b=(i+1)*Math.PI*2/n;
let p=[x+Math.cos(a)*r1,l,z+Math.sin(a)*r1],q=[x+Math.cos(b)*r1,l,z+Math.sin(b)*r1],r=[x+Math.cos(b)*r2,t,z+Math.sin(b)*r2],s=[x+Math.cos(a)*r2,t,z+Math.sin(a)*r2];
quad(p,s,r,q,c);tri([x,t,z],r,s,c);tri([x,l,z],p,q,c)}}
function ball(x,y,z,rx,ry,rz,c,n=10,m=5){function point(i,j){let a=i*Math.PI/m,b=j*Math.PI*2/n;return[x+rx*Math.sin(a)*Math.cos(b),y+ry*Math.cos(a),z+rz*Math.sin(a)*Math.sin(b)]}
for(let i=0;i<m;i++)for(let j=0;j<n;j++)quad(point(i,j),point(i+1,j),point(i+1,j+1),point(i,j+1),c)}
function gem(x,y,z,r,h,c){cylinder(x,y+h*.22,z,r,0,h*.56,c,5);cylinder(x,y-h*.22,z,0,r,h*.56,dark(c,.88),5)}
function tree(x,z,k=1){cylinder(x,.55*k,z,.13*k,.09*k,1.1*k,col.wood,7);ball(x,1.4*k,z,.68*k,.84*k,.64*k,col.leaf);ball(x+.18*k,1.82*k,z,.5*k,.55*k,.48*k,col.leaf2)}
function flower(x,z,c){box(x,.14,z,.035,.28,.035,col.leaf);ball(x,.31,z,.13,.07,.13,c,7,3);ball(x,.36,z,.055,.04,.055,col.gold,6,3)}
function barn(x,z){box(x,.65,z,1.9,1.3,1.55,col.wall);box(x,.48,z+.79,.65,.95,.045,col.wood);let a=x-1.06,b=x+1.06,l=z-.91,r=z+.91;
tri([a,1.3,r],[b,1.3,r],[x,2.07,r],col.roof);tri([b,1.3,l],[a,1.3,l],[x,2.07,l],col.roof);quad([a,1.3,l],[a,1.3,r],[x,2.07,r],[x,2.07,l],col.roof);quad([x,2.07,l],[x,2.07,r],[b,1.3,r],[b,1.3,l],col.roof);box(x+.62,.94,z+.795,.35,.35,.05,col.water)}
function pet(p,x,z,time){let i=p.species,c=p.shiny?rgb("#ed8fd6"):palettes[i],y=.35+Math.abs(Math.sin(time*2.1+p.id))*.13;ball(x,y,z,.35,.34,.35,c);ball(x,y+.18,z+.18,.28,.26,.25,dark(c,1.09));
for(let q of [-1,1]){ball(x+q*.105,y+.21,z+.39,.055,.073,.043,col.eye,7,4);ball(x+q*.22,.105,z+.16,.10,.10,.13,dark(c,.82),7,4);ball(x+q*.22,.105,z-.16,.10,.10,.13,dark(c,.82),7,4)}
if(i===0){box(x,y+.4,z,.04,.25,.04,col.leaf);ball(x-.13,y+.58,z,.16,.05,.09,col.leaf2);ball(x+.13,y+.58,z,.16,.05,.09,col.leaf2)}
if(i===1){ball(x,y+.42,z,.43,.16,.40,rgb("#cf6576"));for(let k=0;k<5;k++){let a=k*6.28/5;ball(x+Math.cos(a)*.24,y+.54,z+Math.sin(a)*.24,.06,.03,.06,col.white)}}
if(i===2)cylinder(x,y+.48,z,.16,0,.38,dark(c,1.17));
if(i===3){for(let q of [-1,1])ball(x+q*.17,y+.48,z+.04,.09,.23,.09,col.leaf2);for(let q of [-1,0,1])ball(x+q*.12,y+.17,z-.38,.10,.07,.24,col.leaf)}
if(i===4){for(let k=0;k<3;k++)cylinder(x,y+.34,z-.26+k*.2,.1,0,.28,col.gold)}
if(i===5){for(let k=0;k<4;k++)gem(x+(k%2-.5)*.3,y+.38,z-.25+k*.13,.13,.36,rgb("#a9e4ed"))}
if(i===6){for(let q of [-1,1])ball(x+q*.4,y+.14+Math.sin(time*4)*.07,z,.31,.07,.22,dark(c,.8))}
if(i===7){for(let q of [-1,1])cylinder(x+q*.14,y+.48,z+.1,.08,0,.34,col.white)}
if(i===8||i===9||i===10){for(let k=0;k<9;k++){let a=k*6.28/9;if(i===9&&k<3)continue;gem(x+Math.cos(a)*.36,y+.31+Math.sin(a)*.36,z-.22,.07,.14,i===8?col.gold:rgb("#d8c4fa"))}}
if(i===11){for(let k=0;k<3;k++)cylinder(x+(k-1)*.2,y+.49,z-.12,.16,0,.38,col.leaf2)}
}
const positions=Array.from({length:12},(_,i)=>[(i%4-1.5)*1.8,(Math.floor(i/4)-1)*1.75]);
let staticKey='',staticMesh=[];
function build(snapshot,t,selected,guests){const key=JSON.stringify([selected,snapshot.plots.map(p=>[p.slot,p.crop,p.ready>0,p.ready>0&&p.ready<=now()])]);if(key!==staticKey){vertices=[];box(0,-.64,0,12.8,.75,10.9,col.earth);box(0,-.19,0,12.7,.22,10.8,col.grass);
for(let i=0;i<11;i++)box(-5+i,0.015,3.15,.82,.045,.66,col.path);
for(let i=0;i<7;i++)box(-4.95,0.02,-3.2+i*.9,.66,.04,.72,col.path);
barn(-4.7,-3.6);box(4.7,.02,-3.35,2.2,.09,1.6,rgb("#cbd4b7"));ball(4.7,.085,-3.35,1.04,.055,.73,col.water,14,4);for(let i=0;i<4;i++){let a=i*1.55;ball(4.7+Math.cos(a)*.72,.14,-3.35+Math.sin(a)*.5,.18,.03,.13,col.leaf2,8,3)}
for(let i=0;i<6;i++){tree(-5.55+i*2.16,-4.65,.85+(i%3)*.12);if(i!==0&&i!==5)tree(-5.55+i*2.16,4.65,.68)}
for(let i=0;i<12;i++){let x=-5.5+(i%6)*2.18,z=i<6?-4.05:4.05;flower(x,z,rgb(i%2?"#f4bcce":"#f5d679"))}
for(let i=0;i<12;i++){let [x,z]=positions[i],p=snapshot.plots.find(q=>q.slot===i);
box(x,.04,z,1.56,.14,1.52,p?(p.ready>0?col.wet:col.soil):rgb("#a7b18b"));
for(let q of [-1,1]){box(x+q*.76,.15,z,.075,.18,1.56,i===selected?col.gold:col.wood);box(x,.15,z+q*.74,1.56,.18,.075,i===selected?col.gold:col.wood)}
if(!p)continue;if(p.crop<0){for(let j=0;j<3;j++)box(x,.13,z+(j-1)*.37,1.24,.035,.055,dark(col.soil,.82));continue}
let ripe=p.ready>0&&p.ready<=now(),height=ripe?.38:.16;for(let a of [-.34,.34])for(let b of [-.34,.34]){
box(x+a,.15+height/2,z+b,.045,height,.045,col.leaf);
ball(x+a-.08,.2+height*.45,z+b,.15,.065,.08,col.leaf2,7,3);
if(ripe){if(p.crop===5)gem(x+a,.27+height,z+b,.12,.3,plantCols[p.crop]);else if(p.crop===0||p.crop===2)cylinder(x+a,.26+height,z+b,.10,.06,.26,plantCols[p.crop],7);else ball(x+a,.24+height,z+b,.12,.14,.12,plantCols[p.crop],7,4)}
}}
staticKey=key;staticMesh=vertices.slice();}else vertices=staticMesh.slice();
let active=snapshot.pets.filter(p=>p.active).slice(0,8);active.forEach((p,i)=>pet(p,-2.5+i*1.18+Math.sin(t*.7+i)*.13,3.8+Math.cos(t*.8+i)*.12,t));
(guests||[]).slice(0,6).forEach((p,i)=>{let x=-4.1+i*1.25,z=2.75;ball(x,.64,z,.17,.17,.17,rgb("#edca9b"),8,4);box(x,.34,z,.28,.43,.19,p.id===state?.user?.id?rgb("#98d29a"):rgb("#779edb"));box(x-.09,.09,z,.10,.18,.12,col.eye);box(x+.09,.09,z,.10,.18,.12,col.eye)});
}
function shader(gl,kind,src){let s=gl.createShader(kind);gl.shaderSource(s,src);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s}
let world=null, yaw=.69, zoom=1, selected=0, presence=[], lastPresence=0, pollBusy=false, lastView=0, frame=0, renderAt=0;
function makeWorld(){let card=document.createElement("div");card.className="world-card";card.innerHTML='<canvas class="world-canvas" aria-label="Etkileşimli 3D çiftlik" tabindex="0"></canvas><div class="world-head"><strong></strong><span></span></div><div class="world-tools"><button data-world="left" aria-label="Kamerayı sola döndür">↶</button><button data-world="right" aria-label="Kamerayı sağa döndür">↷</button><button data-world="minus" aria-label="Uzaklaş">−</button><button data-world="plus" aria-label="Yakınlaş">+</button><span class="status"></span><button data-world="action">Ek</button></div><div class="world-note">Tarlaya dokun veya tıkla. Kamera düğmeleriyle çiftliğini döndür. Alttaki liste de her zaman kullanılabilir.</div>';
let canvas=card.querySelector("canvas"),gl=canvas.getContext("webgl",{antialias:true,alpha:false,depth:true,preserveDrawingBuffer:false});
if(!gl){card.innerHTML='<div class="world-fallback">WebGL kullanılamıyor. Alttaki erişilebilir tarla listesiyle oynamaya devam edebilirsin.</div>';return {card,canvas:null}}
let vs=shader(gl,gl.VERTEX_SHADER,'attribute vec3 pos;attribute vec3 color;uniform vec3 right;uniform vec3 up;uniform vec3 depth;uniform vec2 scale;varying vec3 tint;void main(){vec3 p=pos-vec3(0.0,0.4,0.0);gl_Position=vec4(dot(p,right)*scale.x,dot(p,up)*scale.y,dot(p,depth)/30.0,1.0);tint=color;}');
let fs=shader(gl,gl.FRAGMENT_SHADER,'precision mediump float;varying vec3 tint;void main(){gl_FragColor=vec4(tint,1.0);}');
let pr=gl.createProgram();gl.attachShader(pr,vs);gl.attachShader(pr,fs);gl.linkProgram(pr);if(!gl.getProgramParameter(pr,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(pr));
let buf=gl.createBuffer(),pos=gl.getAttribLocation(pr,"pos"),color=gl.getAttribLocation(pr,"color"),u={};for(let k of ["right","up","depth","scale"])u[k]=gl.getUniformLocation(pr,k);
gl.enable(gl.DEPTH_TEST);gl.clearColor(.65,.80,.77,1);gl.disable(gl.CULL_FACE);
let obj={card,canvas,gl,pr,buf,pos,color,u,view:null};
card.addEventListener("click",e=>{let b=e.target.closest("[data-world]");if(!b)return;let a=b.dataset.world;
if(a==="left")yaw-=Math.PI/4;if(a==="right")yaw+=Math.PI/4;if(a==="plus")zoom=Math.min(1.6,zoom+.15);if(a==="minus")zoom=Math.max(.65,zoom-.15);
if(a==="action"&&tab==="farm"){let p=state.plots.find(q=>q.slot===selected);if(!p)return;act(p.crop<0?"plant":p.ready===0?"water":"harvest",p.crop<0?{slot:selected,crop:selectedCrop}:p.ready===0?{slot:selected}:{slot:selected,keep})}
renderAt=0;updateWorld()});
canvas.addEventListener("pointerup",e=>{if(!obj.view)return;let rect=canvas.getBoundingClientRect(),px=(e.clientX-rect.left)/rect.width*2-1,py=1-(e.clientY-rect.top)/rect.height*2,best=-1,dist=Infinity;positions.forEach(([x,z],i)=>{let p=[x,-.25,z],sx=dot(p,obj.view.r)*obj.view.sx,sy=dot(p,obj.view.u)*obj.view.sy,dd=Math.hypot((sx-px)*rect.width,(sy-py)*rect.height);if(dd<dist){dist=dd;best=i}});if(dist<Math.max(38,rect.width*.09)){selected=best;updateWorld();renderAt=0}});
canvas.addEventListener("wheel",e=>{if(!e.ctrlKey)return;e.preventDefault();zoom=Math.max(.65,Math.min(1.6,zoom-e.deltaY*.001));renderAt=0},{passive:false});
return obj}
function snapshot(){return tab==="farm"?state:tab==="social"?visitor:null}
function mount(){let snap=snapshot();if(!snap||$("app").classList.contains("hidden")){if(world?.card.isConnected)world.card.remove();return}
let target=tab==="farm"?$("content"):$("visitor");if(!target)return;
if(!world){try{world=makeWorld()}catch(e){console.warn("WebGL unavailable",e);return}}
if(!world.card.isConnected||world.card.parentElement!==target){let before=target.querySelector(".farm");if(before&&before.parentElement===target)target.insertBefore(world.card,before);else target.prepend(world.card);renderAt=0}
updateWorld()
}
function updateWorld(){if(!world?.canvas||!world.card.isConnected||!snapshot())return;let snap=snapshot(),guest=presence.filter(x=>x.visiting===snap.user.id),p=snap.plots.find(q=>q.slot===selected),mine=tab==="farm";
world.card.querySelector(".world-head strong").textContent=mine?"Yeşil Vadi • "+snap.user.name:snap.user.name+" • ziyaret";
world.card.querySelector(".world-head span").textContent=guest.length+" çevrim içi ziyaretçi • "+snap.plots.length+" tarla";
let status=world.card.querySelector(".status");status.textContent=p?"Tarla "+(selected+1)+" • "+(p.crop<0?"Boş":C[p.crop]+(p.ready===0?" • Sulanmalı":p.ready<=now()?" • Hazır":" • "+Math.max(0,Math.ceil(p.ready-now()))+" sn")):"Kilitli tarla";
let b=world.card.querySelector('[data-world="action"]');b.hidden=!mine;b.disabled=!p||p.crop>=0&&p.ready>now();b.textContent=!p?"Kilitli":p.crop<0?"Ek":p.ready===0?"Sula":p.ready<=now()?"Hasat":"Büyüyor";
}
function draw(t){requestAnimationFrame(draw);if(!world?.canvas||!world.card.isConnected||!snapshot()||t-renderAt<(document.hidden?500:40))return;renderAt=t;
let {canvas,gl,pr,buf,pos,color,u}=world,rect=canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,1.25);let w=Math.max(1,Math.round(rect.width*dpr)),h=Math.max(1,Math.round(rect.height*dpr));if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h}
let r=[Math.cos(yaw),0,-Math.sin(yaw)],up=unit([-Math.sin(yaw)*.67,.74,-Math.cos(yaw)*.67]),depth=cross(r,up).map(v=>-v),aspect=w/h,extent=Math.max(6.4,9.4/aspect)/zoom,sx=1/(extent*aspect),sy=1/extent;
world.view={r,u:up,sx,sy};build(snapshot(),t/1000,selected,presence.filter(x=>x.visiting===snapshot().user.id));
gl.viewport(0,0,w,h);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.useProgram(pr);gl.bindBuffer(gl.ARRAY_BUFFER,buf);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(vertices),gl.DYNAMIC_DRAW);
gl.enableVertexAttribArray(pos);gl.vertexAttribPointer(pos,3,gl.FLOAT,false,24,0);gl.enableVertexAttribArray(color);gl.vertexAttribPointer(color,3,gl.FLOAT,false,24,12);
gl.uniform3fv(u.right,r);gl.uniform3fv(u.up,up);gl.uniform3fv(u.depth,depth);gl.uniform2f(u.scale,sx,sy);gl.drawArrays(gl.TRIANGLES,0,vertices.length/6);updateWorld();
}
let queued=false;new MutationObserver(()=>{if(!queued){queued=true;queueMicrotask(()=>{queued=false;mount()})}}).observe($("content"),{childList:true,subtree:false});
new MutationObserver(()=>mount()).observe($("app"),{attributes:true,attributeFilter:["class"]});
document.addEventListener("click",e=>{if(e.target.closest('[data-act="visit"]'))setTimeout(mount,350)});
setInterval(mount,1000);
let syncRev="",syncPlace=0,syncDelay=5000,syncTimer=0;
async function poll(){if(!token||!state||busy||pollBusy||document.hidden){syncTimer=setTimeout(poll,document.hidden?15000:1000);return}pollBusy=true;let began=performance.now();try{
let place=tab==="social"&&visitor?visitor.user.id:state.user.id;
if(syncPlace!==place){syncPlace=place;syncRev=""}
let result=await api("sync",{user:place,rev:syncRev});
if(!token||!state)return;
presence=result.guests;offset=result.now-Date.now()/1000;syncRev=result.rev;
let fresh=result.snapshot;
if(fresh&&tab==="social"&&visitor&&visitor.user.id===place){if(JSON.stringify(fresh)!==JSON.stringify(visitor)){visitor=fresh;drawVisitor();mount()}}
if(fresh&&tab==="farm"&&place===state.user.id&&!busy){fresh.now=result.now;if(JSON.stringify(fresh.plots)!==JSON.stringify(state.plots)||JSON.stringify(fresh.pets)!==JSON.stringify(state.pets)||JSON.stringify(fresh.user)!==JSON.stringify(state.user)){state=fresh;$("stats").textContent=state.user.name+" • L"+state.user.level+" • "+fmt(state.user.gold)+" G";render()}else state=fresh}
syncDelay=Math.min(14000,Math.max(5000,Math.round((performance.now()-began)*3)));updateWorld();
}catch(e){syncDelay=Math.min(15000,syncDelay+3000)}finally{pollBusy=false;syncTimer=setTimeout(poll,syncDelay)}}
syncTimer=setTimeout(poll,1000);
document.addEventListener("visibilitychange",()=>{if(!document.hidden&&!pollBusy){clearTimeout(syncTimer);syncTimer=setTimeout(poll,200)}});
requestAnimationFrame(draw);
window.sprout3d={mount,get ready(){return !!world?.gl},get guests(){return presence.length}};
})();
