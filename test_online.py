"""Real HTTP integration tests with an isolated temporary database."""
import concurrent.futures, json, pathlib, secrets, socket, subprocess, sys, tempfile, time, urllib.request, urllib.error
import server as srv

def port():
    with socket.socket() as s:
        s.bind(("127.0.0.1",0)); return s.getsockname()[1]
def check(ok, text):
    if not ok: raise AssertionError(text)
    print("PASS:",text,flush=True)
def main():
    with tempfile.TemporaryDirectory() as tmp:
        db=pathlib.Path(tmp)/"test.sqlite3"
        p=port(); base=f"http://127.0.0.1:{p}"
        child=subprocess.Popen([sys.executable,str(pathlib.Path(__file__).with_name("server.py")),"--db",str(db),"--port",str(p)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                try:
                    urllib.request.urlopen(base+"/health",timeout=1).close(); break
                except OSError: time.sleep(.1)
            def call(a,token="",ok=True,nonce=None,**data):
                req=urllib.request.Request(base+"/api",data=json.dumps(dict(action=a,nonce=nonce or secrets.token_hex(16),**data)).encode(),headers={"Content-Type":"application/json","Authorization":"Bearer "+token},method="POST")
                try:
                    response=urllib.request.urlopen(req,timeout=10); j=json.load(response)
                except urllib.error.HTTPError as e: j=json.load(e)
                if j["ok"]!=ok: raise AssertionError((a,j,ok))
                return j.get("data",j.get("error"))
            check("SPROUTLINGS" in urllib.request.urlopen(base).read().decode(),"web dashboard served")
            a=call("register",name="farmer_alpha",password="test-secret-alpha")["token"]
            b=call("register",name="farmer_beta",password="test-secret-beta")["token"]
            call("login",ok=False,name="farmer_alpha",password="incorrect-password")
            check(call("login",name="farmer_alpha",password="test-secret-alpha")["token"]!=a,"accounts and password verification")
            call("state",ok=False); check(call("state",a)["user"]["gold"]==100,"authentication and starter balance")
            call("plant",a,slot=0,crop=0); call("water",a,slot=0)
            call("harvest",a,ok=False,slot=0)
            uid=call("state",a)["user"]["id"]; bid=call("state",b)["user"]["id"]
            c=srv.connect(db); c.execute("UPDATE plots SET ready=? WHERE uid=? AND slot=0",(time.time()-1,uid)); c.close()
            nonce=secrets.token_hex(16)
            call("harvest",a,slot=0,nonce=nonce); call("harvest",a,slot=0,nonce=nonce)
            st=call("state",a); check(st["user"]["gold"]==143 and st["user"]["harvests"]==1 and st["crates"][0]["qty"]==1,"plant/water, timer enforcement, first reward and retry idempotency")
            c=srv.connect(db); c.execute("UPDATE crates SET r=9 WHERE uid=? AND tier=0",(uid,)); c.close()
            p1=call("open",a,tier=0); check(p1["species"]//2>=2,"rare pity on server")
            call("open",a,ok=False,tier=0); call("feed",b,ok=False,pet=p1["pet"])
            c=srv.connect(db); c.execute("UPDATE users SET level=5,gold=1000 WHERE id IN (?,?)",(uid,bid))
            c.execute("UPDATE crates SET qty=1,r=0 WHERE uid=? AND tier=0",(bid,))
            c.execute("UPDATE crates SET qty=1,r=0 WHERE uid=? AND tier=0",(uid,))
            c.close()
            p2=call("open",b,tier=0); p3=call("open",a,tier=0)
            call("feed",a,pet=p1["pet"]); call("activate",a,pet=p1["pet"])
            call("list",a,ok=False,kind="pet",asset=p1["pet"],price=100)
            call("activate",a,pet=p1["pet"])
            call("list",a,kind="pet",asset=p1["pet"],price=100)
            listing=call("market",b)[0]
            call("feed",a,ok=False,pet=p1["pet"])
            before=call("state",a)["user"]["gold"]
            call("buy",b,listing=listing["id"])
            call("buy",b,ok=False,listing=listing["id"])
            check(call("state",a)["user"]["gold"]==before+95 and any(x["id"]==p1["pet"] for x in call("state",b)["pets"]),"market escrow, tax, ownership and double-buy protection")
            hist=call("history",a,kind="pet",asset=p1["species"],days=7)
            check(hist["count"]==1 and hist["average"]==100,"real price history")
            call("offer",a,target=bid,give=p3["pet"],ask=p2["pet"])
            tid=call("trades",b)[0]["id"]
            call("accept",a,ok=False,trade=tid)
            call("accept",b,trade=tid)
            check(any(x["id"]==p2["pet"] for x in call("state",a)["pets"]) and any(x["id"]==p3["pet"] for x in call("state",b)["pets"]),"two-party atomic trade")
            call("accept",b,ok=False,trade=tid)
            call("offer",a,target=bid,give=p2["pet"],ask=p3["pet"])
            tid=call("trades",b)[0]["id"]; call("cancel_trade",b,trade=tid)
            check(not next(x for x in call("state",a)["pets"] if x["id"]==p2["pet"])["lock"],"trade cancellation unlocks pet")
            c=srv.connect(db); c.execute("INSERT INTO stock VALUES(?,?,?)",(uid,0,12)); c.close()
            call("craft",a,rarity=0)
            call("list",a,kind="item",asset=0,qty=3,price=30)
            l=next(x for x in call("market",b) if x["kind"]=="item")
            call("cancel_listing",a,listing=l["id"])
            check(call("state",a)["stock"][0]==11 and call("state",a)["stock"][7]==1,"crafting and item escrow cancellation")
            call("list",a,kind="item",asset=0,qty=1,price=10)
            l=next(x for x in call("market",b) if x["kind"]=="item")
            def attempt():
                try: call("buy",b,listing=l["id"]); return True
                except AssertionError: return False
            with concurrent.futures.ThreadPoolExecutor(2) as ex: outcomes=list(ex.map(lambda _:attempt(),range(2)))
            check(sum(outcomes)==1,"concurrent purchases settle exactly once")
            c=srv.connect(db); c.executemany("INSERT INTO activity VALUES(?,?,?)",[(uid,"harvest",time.time())]*30); c.close()
            q=call("state",a)["quests"]
            for x in q: call("claim",a,key=x["key"])
            call("claim",a,ok=False,key=q[0]["key"])
            check(all(x["claimed"] for x in call("state",a)["quests"]),"daily/weekly/festival and claim protection")
            check(len(call("leaderboard",a))==2 and call("visit",a,user=bid)["user"]["name"]=="farmer_beta","leaderboard and read-only visit")
            c=srv.connect(db); check(c.execute("PRAGMA integrity_check").fetchone()[0]=="ok","database integrity"); c.close()
            call("logout",a); call("state",a,ok=False)
            check(True,"session logout")
            print("ALL ONLINE INTEGRATION TESTS PASSED",flush=True)
        finally:
            child.terminate(); child.wait(timeout=10)
if __name__=="__main__": main()
