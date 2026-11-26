"""Two actual browser contexts, WebGL and live shared farm visit."""
import pathlib, socket, subprocess, sys, tempfile, time, urllib.request
from playwright.sync_api import sync_playwright, expect
import server as srv
def main():
    root=pathlib.Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory() as tmp:
        db=pathlib.Path(tmp)/"live.sqlite3"
        with socket.socket() as s: s.bind(("127.0.0.1",0)); port=s.getsockname()[1]
        url=f"http://127.0.0.1:{port}"
        child=subprocess.Popen([sys.executable,str(root/"server.py"),"--db",str(db),"--port",str(port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                try: urllib.request.urlopen(url+"/health",timeout=1).close(); break
                except OSError: time.sleep(.1)
            with sync_playwright() as pw:
                edge=pathlib.Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
                browser=pw.chromium.launch(executable_path=str(edge) if edge.exists() else None,headless=True,args=["--enable-webgl","--use-angle=swiftshader","--enable-unsafe-swiftshader"])
                errors=[]
                def login(name,mobile=False):
                    p=browser.new_page(viewport={"width":390,"height":844} if mobile else {"width":1440,"height":900},is_mobile=mobile,has_touch=mobile)
                    p.on("pageerror",lambda e:errors.append(str(e)))
                    p.goto(url)
                    p.locator("#name").fill(name)
                    p.locator("#password").fill("isolated-test-password")
                    p.locator("#registerBtn").click()
                    expect(p.locator("#stats")).to_contain_text(name)
                    p.wait_for_function("window.sprout3d?.ready === true")
                    expect(p.locator("canvas.world-canvas")).to_be_visible()
                    return p
                a=login("web3d_alpha")
                b=login("web3d_beta",True)
                expect(a.locator(".world-head")).to_contain_text("web3d_alpha")
                a.locator('[data-world="action"]').click()
                expect(a.locator('[data-act="water"][data-slot="0"]')).to_be_visible()
                a.locator('[data-world="action"]').click()
                expect(a.locator('[data-act="harvest"][data-slot="0"]')).to_be_disabled()
                a.locator('[data-world="right"]').click()
                a.locator('[data-world="plus"]').click()
                b.locator('[data-tab="social"]').click()
                b.locator('tr',has_text="web3d_alpha").locator('[data-act="visit"]').click()
                expect(b.locator("#visitor .world-head")).to_contain_text("web3d_alpha",timeout=10000)
                expect(a.locator(".world-head")).to_contain_text("2 çevrim içi ziyaretçi",timeout=15000)
                a.locator('[data-act="plant"][data-slot="1"]').click()
                expect(b.locator("#visitor .tile").nth(1)).to_contain_text("Buğday",timeout=15000)
                c=srv.connect(db); uid=c.execute("SELECT id FROM users WHERE name='web3d_alpha'").fetchone()[0]
                c.execute("UPDATE plots SET ready=? WHERE uid=? AND slot=0",(time.time()-1,uid)); c.close()
                a.locator('[data-act="refresh"]').click()
                expect(a.locator('[data-world="action"]')).to_have_text("Hasat")
                a.locator('[data-world="action"]').click()
                expect(a.locator("#stats")).to_contain_text("141 G")
                expect(b.locator("#visitor .tile").first).to_contain_text("Boş",timeout=15000)
                a.locator('[data-tab="pets"]').click()
                a.locator('[data-act="open"][data-tier="0"]').click()
                expect(a.locator(".pet")).to_have_count(1)
                a.locator('[data-act="activate"]').click()
                a.locator('[data-tab="farm"]').click()
                expect(a.locator("canvas.world-canvas")).to_be_visible()
                assert a.evaluate("document.querySelector('canvas').width > 300")
                assert b.evaluate("document.documentElement.scrollWidth <= innerWidth + 2")
                if errors: raise AssertionError(errors)
                browser.close()
                print("V2 PASS: WebGL, desktop/mobile, 3D planting/watering/harvest, camera, two live visitors, cross-client updates, creature activation",flush=True)
        finally:
            child.terminate(); child.wait(timeout=10)
if __name__=="__main__": main()
