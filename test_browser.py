"""Optional browser integration test (Playwright + installed Edge). Uses only a temporary database."""
import pathlib, socket, subprocess, sys, tempfile, time, urllib.request
import server as srv
from playwright.sync_api import sync_playwright, expect

def main():
    root=pathlib.Path(__file__).resolve().parent
    edge=pathlib.Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
    with tempfile.TemporaryDirectory() as tmp:
        db=pathlib.Path(tmp)/"ui.sqlite3"
        with socket.socket() as s: s.bind(("127.0.0.1",0)); port=s.getsockname()[1]
        url=f"http://127.0.0.1:{port}"
        child=subprocess.Popen([sys.executable,str(root/"server.py"),"--db",str(db),"--port",str(port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                try: urllib.request.urlopen(url+"/health",timeout=1).close(); break
                except OSError: time.sleep(.1)
            with sync_playwright() as pw:
                browser=pw.chromium.launch(executable_path=str(edge) if edge.exists() else None,headless=True)
                errors=[]
                def new_player(name):
                    page=browser.new_page(viewport={"width":1440,"height":900})
                    page.on("pageerror",lambda e: errors.append(str(e)))
                    page.on("dialog",lambda d: d.accept())
                    page.goto(url)
                    page.locator("#name").fill(name)
                    page.locator("#password").fill("isolated-test-password")
                    page.locator("#registerBtn").click()
                    expect(page.locator("#stats")).to_contain_text(name)
                    return page
                a=new_player("ui_farmer_a")
                b=new_player("ui_farmer_b")
                a.locator('[data-act="plant"][data-slot="0"]').click()
                expect(a.locator('[data-act="water"][data-slot="0"]')).to_be_visible()
                a.locator('[data-act="water"][data-slot="0"]').click()
                expect(a.locator('[data-act="harvest"][data-slot="0"]')).to_be_disabled()
                c=srv.connect(db)
                uid=c.execute("SELECT id FROM users WHERE name='ui_farmer_a'").fetchone()[0]
                c.execute("UPDATE plots SET ready=? WHERE uid=? AND slot=0",(time.time()-1,uid))
                c.close()
                a.locator('[data-act="refresh"]').click()
                expect(a.locator('[data-act="harvest"][data-slot="0"]')).to_be_enabled()
                a.locator('[data-act="harvest"][data-slot="0"]').click()
                expect(a.locator("#stats")).to_contain_text("143 G")
                a.locator('[data-tab="pets"]').click()
                a.locator('[data-act="open"][data-tier="0"]').click()
                expect(a.locator(".pet")).to_have_count(1)
                c=srv.connect(db)
                c.execute("UPDATE users SET level=5,gold=1000")
                c.execute("INSERT INTO stock VALUES(?,?,?)",(uid,0,3))
                c.close()
                a.locator('[data-tab="market"]').click()
                a.locator("#itemQty").fill("1")
                a.locator("#itemPrice").fill("10")
                a.locator('[data-act="listitem"]').click()
                expect(a.locator('[data-act="cancel_listing"]')).to_have_count(1)
                b.locator('[data-tab="market"]').click()
                b.locator('[data-act="buy"]').click()
                expect(b.locator("#stats")).to_contain_text("990 G")
                b.locator("#historyKind").select_option("item")
                b.locator('[data-act="history"]').click()
                expect(b.locator("#chart")).to_contain_text("1 işlem")
                expect(b.locator("#chart svg")).to_be_visible()
                b.locator('[data-tab="social"]').click()
                expect(b.locator("tbody tr")).to_have_count(2)
                b.locator('[data-act="visit"]').first.click()
                expect(b.locator("#visitor .farm")).to_be_visible()
                b.locator('[data-tab="quests"]').click()
                expect(b.locator("#content")).to_contain_text("Haftalık")
                if errors: raise AssertionError(errors)
                browser.close()
                print("BROWSER PASS: two accounts, plant/water/harvest, crate, market, purchase, price chart, leaderboard, visit and quests",flush=True)
        finally:
            child.terminate(); child.wait(timeout=10)
if __name__=="__main__": main()
