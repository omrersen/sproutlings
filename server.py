"""Sproutlings V1 local authoritative economy. Python stdlib, SQLite."""
import argparse, datetime as dt, hashlib, hmac, json, os, re, secrets, sqlite3, time, threading
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT=Path(__file__).resolve().parent
DB=ROOT/"online.sqlite3"
RNG=secrets.SystemRandom()
SPECIES=["Filizburun","Pofmantar","Damlaç","Yaprakuyruk","Kıvılkın","Kristip","Gecekanat","Gökboynuz","Solvaris","Lunareth","Aetherion","Verdalux"]
RARITY=["Common","Uncommon","Rare","Epic","Legendary","Mythic"]
CROPS=[("Buğday",2,5,12,1),("Havuç",3,10,25,2),("Mısır",5,13,35,4),("Orman meyvesi",8,20,48,5),("Ejder biberi",14,35,65,8),("Kristal meyve",22,55,85,12),("Ay balı",20,60,100,16)]
FEED=[8,15,32,55,95,115]
FOOD=["Tahıl","Meyve yemi","Baharatlı yem","Kristal karışım","Göksel ziyafet","Yıldız nektarı"]
ITEMS=[x[0] for x in CROPS]+FOOD
TIERS=["Ahşap","Demir","Altın","Kristal","Efsanevi","Etkinlik"]
ODDS=[[70,25,5,0,0,0],[45,35,17,3,0,0],[20,35,33,11,1,0],[5,20,40,29,6,0],[0,5,30,50,15,0],[15,30,35,15,4.5,.5]]
PR=[10,7,5,3,2,3]; PL=[0,0,20,12,8,20]; LEVELS=[1,5,12,25,40,5]
SCHEMA="""
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY,name TEXT UNIQUE COLLATE NOCASE,salt BLOB NOT NULL,pw BLOB NOT NULL,gold INTEGER NOT NULL DEFAULT 100 CHECK(gold>=0),xp INTEGER NOT NULL DEFAULT 0,level INTEGER NOT NULL DEFAULT 1,harvests INTEGER NOT NULL DEFAULT 0,land INTEGER NOT NULL DEFAULT 4);
CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,uid INTEGER REFERENCES users(id),expires REAL);
CREATE TABLE IF NOT EXISTS plots(uid INTEGER REFERENCES users(id),slot INTEGER,crop INTEGER NOT NULL DEFAULT -1,ready REAL NOT NULL DEFAULT 0,PRIMARY KEY(uid,slot));
CREATE TABLE IF NOT EXISTS stock(uid INTEGER REFERENCES users(id),item INTEGER,qty INTEGER NOT NULL CHECK(qty>=0),PRIMARY KEY(uid,item));
CREATE TABLE IF NOT EXISTS crates(uid INTEGER REFERENCES users(id),tier INTEGER,qty INTEGER NOT NULL DEFAULT 0 CHECK(qty>=0),r INTEGER DEFAULT 0,l INTEGER DEFAULT 0,m INTEGER DEFAULT 0,PRIMARY KEY(uid,tier));
CREATE TABLE IF NOT EXISTS pets(id INTEGER PRIMARY KEY,owner INTEGER REFERENCES users(id),species INTEGER NOT NULL,shiny INTEGER NOT NULL,active INTEGER DEFAULT 0,fed REAL DEFAULT 0,lock TEXT DEFAULT '',growth INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS listings(id INTEGER PRIMARY KEY,seller INTEGER REFERENCES users(id),kind TEXT NOT NULL,asset INTEGER NOT NULL,qty INTEGER NOT NULL,price INTEGER NOT NULL,status TEXT DEFAULT 'open',created REAL,expires REAL);
CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY,kind TEXT,asset INTEGER,price INTEGER,qty INTEGER,ts REAL,seller INTEGER,buyer INTEGER);
CREATE TABLE IF NOT EXISTS trades(id INTEGER PRIMARY KEY,maker INTEGER REFERENCES users(id),target INTEGER REFERENCES users(id),give INTEGER,ask INTEGER,status TEXT DEFAULT 'pending',created REAL,expires REAL);
CREATE TABLE IF NOT EXISTS activity(uid INTEGER,kind TEXT,ts REAL);
CREATE TABLE IF NOT EXISTS claims(uid INTEGER,key TEXT,PRIMARY KEY(uid,key));
CREATE TABLE IF NOT EXISTS receipts(uid INTEGER,nonce TEXT,result TEXT,PRIMARY KEY(uid,nonce));
CREATE TABLE IF NOT EXISTS presence(uid INTEGER PRIMARY KEY REFERENCES users(id),visiting INTEGER REFERENCES users(id),last_seen REAL NOT NULL);
CREATE TABLE IF NOT EXISTS audit(id INTEGER PRIMARY KEY,uid INTEGER,action TEXT,ts REAL,detail TEXT);
CREATE INDEX IF NOT EXISTS sales_time ON sales(ts);
CREATE INDEX IF NOT EXISTS activity_user ON activity(uid,ts);
"""
def connect(path=None):
    c=sqlite3.connect(str(path or DB),timeout=12,isolation_level=None)
    c.row_factory=sqlite3.Row
    c.execute("PRAGMA foreign_keys=ON")
    return c
def init(path=None):
    c=connect(path); c.execute("PRAGMA journal_mode=WAL"); c.executescript(SCHEMA); c.close()
class Error(Exception): pass
def require(ok,msg):
    if not ok: raise Error(msg)
def one(c,q,args=()):
    return c.execute(q,args).fetchone()
def rows(c,q,args=()):
    return [dict(x) for x in c.execute(q,args)]
def num(data,key,lo,hi):
    v=data.get(key)
    require(type(v) is int and lo<=v<=hi,"Geçersiz "+key)
    return v
def hashpw(pw,salt): return hashlib.pbkdf2_hmac("sha256",pw.encode(),salt,300000)
def auth(c,data,register):
    name=data.get("name",""); pw=data.get("password","")
    require(isinstance(name,str) and re.fullmatch(r"[A-Za-z0-9_]{3,20}",name),"Kullanıcı adı: 3-20 ASCII harf/rakam/_")
    require(isinstance(pw,str) and 10<=len(pw)<=128,"Şifre 10-128 karakter olmalı")
    u=one(c,"SELECT * FROM users WHERE name=?",(name,))
    if register:
        require(not u,"Kullanıcı adı kullanımda")
        salt=secrets.token_bytes(16)
        uid=c.execute("INSERT INTO users(name,salt,pw) VALUES(?,?,?)",(name,salt,hashpw(pw,salt))).lastrowid
        c.executemany("INSERT INTO plots(uid,slot) VALUES(?,?)",[(uid,i) for i in range(4)])
        c.executemany("INSERT INTO crates(uid,tier) VALUES(?,?)",[(uid,i) for i in range(6)])
    else:
        require(u is not None and hmac.compare_digest(u["pw"],hashpw(pw,u["salt"])),"Giriş başarısız")
        uid=u["id"]
    token=secrets.token_urlsafe(32)
    c.execute("INSERT INTO sessions VALUES(?,?,?)",(hashlib.sha256(token.encode()).hexdigest(),uid,time.time()+43200))
    return {"token":token,"name":name}
def getuid(c,token):
    require(bool(token),"Önce giriş yap")
    s=one(c,"SELECT uid FROM sessions WHERE token=? AND expires>?",(hashlib.sha256(token.encode()).hexdigest(),time.time()))
    require(s is not None,"Oturum süresi doldu")
    return s["uid"]
def money(c,u,delta):
    n=c.execute("UPDATE users SET gold=gold+? WHERE id=? AND gold+?>=0",(delta,u,delta)).rowcount
    require(n==1,"Altın yetersiz")
def qty(c,u,i):
    r=one(c,"SELECT qty FROM stock WHERE uid=? AND item=?",(u,i)); return r["qty"] if r else 0
def item(c,u,i,n):
    require(qty(c,u,i)+n>=0,"Malzeme yetersiz")
    c.execute("INSERT INTO stock VALUES(?,?,?) ON CONFLICT(uid,item) DO UPDATE SET qty=qty+excluded.qty",(u,i,max(n,0))) if n>=0 else c.execute("UPDATE stock SET qty=qty+? WHERE uid=? AND item=?",(n,u,i))
def crate(c,u,t,n=1):
    c.execute("UPDATE crates SET qty=qty+? WHERE uid=? AND tier=?",(n,u,t))
def pet(c,u,pid,free=True):
    p=one(c,"SELECT * FROM pets WHERE id=? AND owner=?",(pid,u))
    require(p is not None and (not free or not p["lock"]),"Yaratık mevcut değil veya kilitli")
    return p
def expiry(c,now):
    for l in rows(c,"SELECT * FROM listings WHERE status='open' AND expires<=?",(now,)):
        if l["kind"]=="pet": c.execute("UPDATE pets SET lock='' WHERE id=? AND lock=?",(l["asset"],"L"+str(l["id"])))
        else: item(c,l["seller"],l["asset"],l["qty"])
        c.execute("UPDATE listings SET status='expired' WHERE id=?",(l["id"],))
    for t in rows(c,"SELECT * FROM trades WHERE status='pending' AND expires<=?",(now,)):
        c.execute("UPDATE pets SET lock='' WHERE id=? AND lock=?",(t["give"],"T"+str(t["id"])))
        c.execute("UPDATE trades SET status='expired' WHERE id=?",(t["id"],))
def periods(now):
    d=dt.datetime.fromtimestamp(now,dt.timezone.utc)
    day=d.replace(hour=0,minute=0,second=0,microsecond=0)
    week=day-dt.timedelta(days=day.weekday())
    return day,week
def quests(c,u,now):
    day,week=periods(now)
    epoch=dt.date(2026,1,1)
    cycle=max(0,(day.date()-epoch).days)//42
    theme=["Filiz festivali","Yaz hasadı","Kristal festivali","Ay ışığı şenliği"][cycle%4]
    out=[]
    for key,title,start,goal,reward,tier in [
      ("day:"+day.date().isoformat(),"Günlük: 6 hasat",day,6,30,0),
      ("week:"+week.date().isoformat(),"Haftalık: 30 hasat",week,30,120,1),
      ("festival:"+str(cycle)+":"+day.date().isoformat(),theme+": 10 hasat (L5)",day,10,40,5)]:
        count=one(c,"SELECT count(*) n FROM activity WHERE uid=? AND kind='harvest' AND ts>=?",(u,start.timestamp()))["n"]
        claimed=one(c,"SELECT 1 FROM claims WHERE uid=? AND key=?",(u,key)) is not None
        out.append(dict(key=key,title=title,count=count,goal=goal,reward=reward,tier=tier,claimed=claimed))
    return out
def state(c,u,now):
    user=dict(one(c,"SELECT id,name,gold,xp,level,harvests,land FROM users WHERE id=?",(u,)))
    return dict(user=user,plots=rows(c,"SELECT slot,crop,ready FROM plots WHERE uid=? ORDER BY slot",(u,)),pets=rows(c,"SELECT id,species,shiny,active,fed,lock,growth FROM pets WHERE owner=? ORDER BY id",(u,)),stock=[qty(c,u,i) for i in range(len(ITEMS))],crates=rows(c,"SELECT tier,qty,r,l,m FROM crates WHERE uid=? ORDER BY tier",(u,)),quests=quests(c,u,now),now=now)
def odds(t,r,l,m):
    low=5 if t==5 and m>=39 else 4 if PL[t] and l>=PL[t]-1 else 2 if r>=PR[t]-1 else 0
    return [v if i>=low else 0 for i,v in enumerate(ODDS[t])]
def action(c,u,a,d,now):
    user=one(c,"SELECT * FROM users WHERE id=?",(u,))
    if a=="plant":
        s=num(d,"slot",0,11); i=num(d,"crop",0,6)
        p=one(c,"SELECT * FROM plots WHERE uid=? AND slot=?",(u,s))
        require(p and p["crop"]==-1,"Tarla yok veya dolu")
        name,cost,sale,seconds,lv=CROPS[i]; require(user["level"]>=lv,"Ürün kilitli")
        money(c,u,-cost); c.execute("UPDATE plots SET crop=?,ready=0 WHERE uid=? AND slot=?",(i,u,s))
    elif a=="water":
        s=num(d,"slot",0,11); p=one(c,"SELECT * FROM plots WHERE uid=? AND slot=?",(u,s))
        require(p and p["crop"]>=0 and p["ready"]==0,"Sulama uygun değil")
        speed=0
        for q in rows(c,"SELECT species,growth FROM pets WHERE owner=? AND active=1 AND fed>? AND lock=''",(u,now)):
            if q["species"] in [0,4,7,10]: speed+=[.05,.08,.12,.16,.20,.24][q["species"]//2]*(.5 if q["growth"]<100 else .75 if q["growth"]<300 else 1)
        c.execute("UPDATE plots SET ready=? WHERE uid=? AND slot=?",(now+CROPS[p["crop"]][3]/(1+min(.4,speed)),u,s))
    elif a=="harvest":
        s=num(d,"slot",0,11); p=one(c,"SELECT * FROM plots WHERE uid=? AND slot=?",(u,s))
        require(p and p["crop"]>=0 and 0<p["ready"]<=now,"Hasat hazır değil")
        i=p["crop"]; keep=d.get("keep",False) is True
        if keep: item(c,u,i,1)
        else: money(c,u,CROPS[i][2])
        c.execute("UPDATE plots SET crop=-1,ready=0 WHERE uid=? AND slot=?",(u,s))
        c.execute("INSERT INTO activity VALUES(?,?,?)",(u,"harvest",now))
        h=user["harvests"]+1; xp=user["xp"]+25; lv=user["level"]
        if h==1: money(c,u,40); crate(c,u,0)
        elif h==4: money(c,u,25); crate(c,u,0)
        elif h%10==0: crate(c,u,0)
        while xp>=100+30*(lv-1) and lv<50:
            xp-=100+30*(lv-1); lv+=1
            for t in range(1,5):
                if lv==LEVELS[t]: crate(c,u,t)
        c.execute("UPDATE users SET xp=?,level=?,harvests=? WHERE id=?",(xp,lv,h,u))
    elif a=="expand":
        land=user["land"]; require(land<12,"Tarla kapasitesi dolu")
        money(c,u,-(60 if land==4 else 140))
        c.executemany("INSERT INTO plots(uid,slot) VALUES(?,?)",[(u,i) for i in range(land,land+4)])
        c.execute("UPDATE users SET land=land+4 WHERE id=?",(u,))
    elif a=="open":
        t=num(d,"tier",0,5); q=one(c,"SELECT * FROM crates WHERE uid=? AND tier=?",(u,t))
        require(q["qty"]>0 and user["level"]>=LEVELS[t],"Kasa yok veya kilitli")
        r=RNG.choices(range(6),weights=odds(t,q["r"],q["l"],q["m"]))[0]
        species=r*2+RNG.randrange(2); shiny=RNG.random()<.01
        c.execute("UPDATE crates SET qty=qty-1,r=?,l=?,m=? WHERE uid=? AND tier=?",(0 if r>=2 else q["r"]+1,0 if r>=4 else q["l"]+1,0 if r==5 else q["m"]+1,u,t))
        pid=c.execute("INSERT INTO pets(owner,species,shiny) VALUES(?,?,?)",(u,species,int(shiny))).lastrowid
        return dict(message="Yeni yaratık: "+SPECIES[species],pet=pid,species=species,shiny=shiny)
    elif a=="feed":
        pid=num(d,"pet",1,2147483647); p=pet(c,u,pid); require(p["fed"]<=now,"Zaten tok")
        r=p["species"]//2
        if qty(c,u,7+r): item(c,u,7+r,-1)
        else: money(c,u,-FEED[r])
        c.execute("UPDATE pets SET fed=?,growth=growth+25 WHERE id=?",(now+1800,pid))
    elif a=="activate":
        pid=num(d,"pet",1,2147483647); p=pet(c,u,pid)
        require(p["active"] or one(c,"SELECT count(*) n FROM pets WHERE owner=? AND active=1",(u,))["n"]<2,"İki aktif yuva dolu")
        c.execute("UPDATE pets SET active=1-active WHERE id=?",(pid,))
    elif a=="npc_sell":
        i=num(d,"item",0,6); n=num(d,"qty",1,1000); item(c,u,i,-n); money(c,u,CROPS[i][2]*n)
    elif a=="craft":
        r=num(d,"rarity",0,5); rec=[{0:1},{1:1},{2:1,1:1},{4:1},{5:1},{6:1,5:1}][r]
        require(user["level"]>=3,"Yem üretimi L3")
        for i,n in rec.items(): item(c,u,i,-n)
        money(c,u,-[1,2,2,3,5,8][r]); item(c,u,7+r,1)
    elif a=="claim":
        key=d.get("key"); q=next((x for x in quests(c,u,now) if x["key"]==key),None)
        require(q and not q["claimed"] and q["count"]>=q["goal"] and user["level"]>=LEVELS[q["tier"]],"Ödül hazır değil")
        c.execute("INSERT INTO claims VALUES(?,?)",(u,key)); money(c,u,q["reward"]); crate(c,u,q["tier"])
    elif a=="list":
        require(user["level"]>=5,"Pazar L5")
        require(one(c,"SELECT count(*) n FROM listings WHERE seller=? AND status='open'",(u,))["n"]<5,"En fazla 5 ilan")
        kind=d.get("kind"); require(kind in ["pet","item"],"Geçersiz ilan")
        price=num(d,"price",1,1000000); asset=num(d,"asset",0,2147483647); n=1
        if kind=="pet":
            p=pet(c,u,asset); require(not p["active"],"Önce görevden al")
        else:
            require(asset<len(ITEMS),"Malzeme yok"); n=num(d,"qty",1,1000); item(c,u,asset,-n)
        lid=c.execute("INSERT INTO listings(seller,kind,asset,qty,price,created,expires) VALUES(?,?,?,?,?,?,?)",(u,kind,asset,n,price,now,now+172800)).lastrowid
        if kind=="pet": c.execute("UPDATE pets SET lock=? WHERE id=?",("L"+str(lid),asset))
    elif a in ["buy","cancel_listing"]:
        lid=num(d,"listing",1,2147483647); l=one(c,"SELECT * FROM listings WHERE id=? AND status='open'",(lid,))
        require(l is not None,"İlan artık açık değil")
        if a=="cancel_listing":
            require(l["seller"]==u,"İlan sana ait değil")
            if l["kind"]=="item": item(c,u,l["asset"],l["qty"])
            else: c.execute("UPDATE pets SET lock='' WHERE id=? AND lock=?",(l["asset"],"L"+str(lid)))
            c.execute("UPDATE listings SET status='cancelled' WHERE id=?",(lid,))
        else:
            require(user["level"]>=5 and l["seller"]!=u,"Satın alma geçersiz")
            money(c,u,-l["price"]); tax=max(1,(l["price"]*5+99)//100); money(c,l["seller"],l["price"]-tax)
            asset=l["asset"]
            if l["kind"]=="pet":
                p=one(c,"SELECT * FROM pets WHERE id=? AND owner=? AND lock=?",(asset,l["seller"],"L"+str(lid))); require(p is not None,"Emanet tutarsız")
                c.execute("UPDATE pets SET owner=?,lock='',active=0 WHERE id=?",(u,asset)); asset=p["species"]
            else: item(c,u,asset,l["qty"])
            c.execute("UPDATE listings SET status='sold' WHERE id=?",(lid,))
            c.execute("INSERT INTO sales(kind,asset,price,qty,ts,seller,buyer) VALUES(?,?,?,?,?,?,?)",(l["kind"],asset,l["price"],l["qty"],now,l["seller"],u))
    elif a=="offer":
        require(user["level"]>=5,"Takas L5")
        target=num(d,"target",1,2147483647); give=num(d,"give",1,2147483647); ask=num(d,"ask",1,2147483647)
        require(target!=u and one(c,"SELECT 1 FROM users WHERE id=? AND level>=5",(target,)),"Hedef geçersiz")
        p=pet(c,u,give); q=pet(c,target,ask)
        require(not p["active"] and not q["active"],"Aktif yaratık takas edilemez")
        require(one(c,"SELECT count(*) n FROM trades WHERE maker=? AND status='pending'",(u,))["n"]<5,"En fazla 5 teklif")
        tid=c.execute("INSERT INTO trades(maker,target,give,ask,created,expires) VALUES(?,?,?,?,?,?)",(u,target,give,ask,now,now+86400)).lastrowid
        c.execute("UPDATE pets SET lock=? WHERE id=?",("T"+str(tid),give))
    elif a in ["accept","cancel_trade"]:
        tid=num(d,"trade",1,2147483647); t=one(c,"SELECT * FROM trades WHERE id=? AND status='pending'",(tid,))
        require(t and u in [t["maker"],t["target"]],"Teklif yok")
        if a=="accept":
            require(u==t["target"],"Yalnız alıcı onaylayabilir")
            p=one(c,"SELECT * FROM pets WHERE id=? AND owner=? AND lock=?",(t["give"],t["maker"],"T"+str(tid)))
            q=pet(c,u,t["ask"]); require(p and not q["active"],"Teklif artık geçerli değil")
            c.execute("UPDATE pets SET owner=?,lock='',active=0 WHERE id=?",(u,t["give"]))
            c.execute("UPDATE pets SET owner=?,lock='',active=0 WHERE id=?",(t["maker"],t["ask"]))
            c.execute("UPDATE trades SET status='accepted' WHERE id=?",(tid,))
        else:
            c.execute("UPDATE pets SET lock='' WHERE id=? AND lock=?",(t["give"],"T"+str(tid)))
            c.execute("UPDATE trades SET status='cancelled' WHERE id=?",(tid,))
    else: raise Error("Bilinmeyen işlem")
    return {"message":"İşlem başarılı"}
def market(c):
    return rows(c,"SELECT l.*,u.name seller_name,p.species,p.shiny FROM listings l JOIN users u ON u.id=l.seller LEFT JOIN pets p ON l.kind='pet' AND p.id=l.asset WHERE l.status='open' ORDER BY l.id DESC LIMIT 200")
def trades(c,u):
    return rows(c,"SELECT t.*,m.name maker_name,n.name target_name,p.species give_species,q.species ask_species,p.shiny give_shiny,q.shiny ask_shiny FROM trades t JOIN users m ON m.id=t.maker JOIN users n ON n.id=t.target JOIN pets p ON p.id=t.give JOIN pets q ON q.id=t.ask WHERE (t.maker=? OR t.target=?) AND t.status='pending' ORDER BY t.id DESC",(u,u))
def history(c,kind,asset,days,now):
    data=rows(c,"SELECT price,qty,ts FROM sales WHERE kind=? AND asset=? AND ts>=? ORDER BY ts LIMIT 1000",(kind,asset,now-days*86400))
    vals=sorted(x["price"]/x["qty"] for x in data); n=len(vals)
    return dict(sales=data,count=n,average=sum(vals)/n if n else None,median=(vals[(n-1)//2]+vals[n//2])/2 if n else None)
def visit(c,uid):
    v=one(c,"SELECT id,name,level,harvests,land FROM users WHERE id=?",(uid,)); require(v is not None,"Çiftlik bulunamadı")
    return dict(user=dict(v),plots=rows(c,"SELECT slot,crop,ready FROM plots WHERE uid=? ORDER BY slot",(uid,)),pets=rows(c,"SELECT id,species,shiny,active,lock,growth FROM pets WHERE owner=? ORDER BY id",(uid,)))
RATE={}; RATE_LOCK=threading.Lock()
def rate_limit(ip,auth_request):
    now=time.monotonic(); key=(ip,auth_request)
    with RATE_LOCK:
        entries=[x for x in RATE.get(key,[]) if now-x<60]
        require(len(entries)<(10 if auth_request else 600),"Çok fazla istek")
        entries.append(now); RATE[key]=entries
class Handler(BaseHTTPRequestHandler):
    server_version="Sproutlings/2.0"
    def log_message(self,fmt,*args): pass
    def send_json(self,obj,status=200):
        raw=json.dumps(obj,ensure_ascii=False).encode(); self.send_response(status); self.send_header("Content-Type","application/json; charset=utf-8"); self.send_header("Cache-Control","no-store"); self.send_header("Content-Length",str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def do_GET(self):
        if urlparse(self.path).path=="/":
            raw=(ROOT/"online.html").read_bytes(); self.send_response(200); self.send_header("Content-Type","text/html; charset=utf-8"); self.send_header("Content-Security-Policy","default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'"); self.send_header("X-Content-Type-Options","nosniff"); self.send_header("Content-Length",str(len(raw))); self.end_headers(); self.wfile.write(raw)
        elif self.path=="/farm3d.js":
            raw=(ROOT/"farm3d.js").read_bytes()
            self.send_response(200); self.send_header("Content-Type","application/javascript; charset=utf-8"); self.send_header("X-Content-Type-Options","nosniff"); self.send_header("Cache-Control","no-cache"); self.send_header("Content-Length",str(len(raw))); self.end_headers(); self.wfile.write(raw)
        elif self.path=="/health": self.send_json({"ok":True,"version":"2.0"})
        else: self.send_json({"error":"Bulunamadı"},404)
    def do_POST(self):
        c=None
        try:
            require(self.path=="/api","Geçersiz yol")
            require(self.headers.get("Content-Type","").startswith("application/json"),"JSON gerekli")
            origin=self.headers.get("Origin")
            host=self.headers.get("Host","")
            require(not origin or origin in ("http://"+host,"https://"+host),"Köken geçersiz")
            n=int(self.headers.get("Content-Length","0")); require(0<n<=16384,"İstek boyutu")
            d=json.loads(self.rfile.read(n)); require(isinstance(d,dict),"Geçersiz JSON")
            a=d.get("action"); require(isinstance(a,str),"İşlem eksik")
            ip=self.client_address[0]
            # The HTTP listener is loopback only. Cloudflare overwrites this header.
            forwarded=self.headers.get("CF-Connecting-IP","")
            if forwarded and ip in ("127.0.0.1","::1") and os.getenv("SPROUT_TUNNEL")=="1":
                import ipaddress
                try: ip=str(ipaddress.ip_address(forwarded))
                except ValueError: pass
            rate_limit(ip,a in ["login","register"])
            now=time.time(); c=connect(); c.execute("BEGIN IMMEDIATE"); expiry(c,now)
            if a in ["login","register"]: result=auth(c,d,a=="register")
            else:
                token=self.headers.get("Authorization","").removeprefix("Bearer "); u=getuid(c,token)
                if a=="state": result=state(c,u,now)
                elif a=="presence":
                    target=num(d,"user",1,2147483647)
                    require(one(c,"SELECT 1 FROM users WHERE id=?",(target,)),"Çiftlik bulunamadı")
                    c.execute("INSERT INTO presence VALUES(?,?,?) ON CONFLICT(uid) DO UPDATE SET visiting=excluded.visiting,last_seen=excluded.last_seen",(u,target,now))
                    c.execute("DELETE FROM presence WHERE last_seen<?",(now-25,))
                    result=rows(c,"SELECT p.uid id,p.visiting,u.name FROM presence p JOIN users u ON p.uid=u.id WHERE p.visiting=? ORDER BY p.uid LIMIT 24",(target,))
                elif a=="market": result=market(c)
                elif a=="trades": result=trades(c,u)
                elif a=="leaderboard": result=rows(c,"SELECT id,name,level,harvests FROM users ORDER BY level DESC,harvests DESC,id LIMIT 50")
                elif a=="visit": result=visit(c,num(d,"user",1,2147483647))
                elif a=="history":
                    kind=d.get("kind"); require(kind in ["pet","item"],"Tür")
                    result=history(c,kind,num(d,"asset",0,11 if kind=="pet" else len(ITEMS)-1),num(d,"days",7,30),now)
                elif a=="logout":
                    c.execute("DELETE FROM sessions WHERE token=?",(hashlib.sha256(token.encode()).hexdigest(),)); c.execute("DELETE FROM presence WHERE uid=?",(u,)); result={"message":"Çıkış"}
                else:
                    nonce=d.get("nonce"); require(isinstance(nonce,str) and re.fullmatch(r"[A-Za-z0-9_-]{12,80}",nonce),"İşlem kimliği gerekli")
                    receipt=one(c,"SELECT result FROM receipts WHERE uid=? AND nonce=?",(u,nonce))
                    if receipt: result=json.loads(receipt["result"])
                    else:
                        result=action(c,u,a,d,now)
                        c.execute("INSERT INTO receipts VALUES(?,?,?)",(u,nonce,json.dumps(result,ensure_ascii=False)))
                        c.execute("INSERT INTO audit(uid,action,ts,detail) VALUES(?,?,?,?)",(u,a,now,json.dumps({k:v for k,v in d.items() if k not in ["password","nonce"]},ensure_ascii=False)))
            c.execute("COMMIT"); self.send_json({"ok":True,"data":result})
        except (Error,ValueError,TypeError,KeyError,json.JSONDecodeError) as e:
            if c and c.in_transaction: c.execute("ROLLBACK")
            self.send_json({"ok":False,"error":str(e)},400)
        except Exception as e:
            if c and c.in_transaction: c.execute("ROLLBACK")
            print("server error:",repr(e),flush=True)
            self.send_json({"ok":False,"error":"Sunucu hatası"},500)
        finally:
            if c: c.close()
def main():
    global DB
    p=argparse.ArgumentParser(); p.add_argument("--port",type=int,default=8769); p.add_argument("--db",type=Path,default=DB); p.add_argument("--host",default="127.0.0.1",choices=["127.0.0.1"]); args=p.parse_args(); DB=args.db; init()
    print("Sproutlings server http://"+args.host+":"+str(args.port),flush=True)
    ThreadingHTTPServer((args.host,args.port),Handler).serve_forever()
if __name__=="__main__": main()
