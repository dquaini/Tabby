"""Google Meet: la finestrella del video in miniatura (300x390, fuori dall'elenco di
Chrome) non è una scheda, non si ridimensiona e resta visibile quando cambi app."""
import os
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
FINDER = ADDAPP("com.apple.finder", "Finder")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Meet - wan-eyrd-qih - Google Chrome", {"https://meet.google.com/wan-eyrd-qih"}},
})
CHROME._wins[1]._asName = "Meet - wan-eyrd-qih"
FRONT = CHROME
''')
L.execute(open(base + '/tabby.lua').read())
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")

fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Avvio:", names())
check("Meet è una webapp chiamata «Meet» (non col codice della riunione)", "Meet" in names())

print("\n== Meet apre il video in miniatura (condivisione dello schermo)")
run('''
PIP = newWindow(CHROME, "Meet - wan-eyrd-qih", {})
PIP._noAS = true
PIP._frame = {x = 1100, y = 480, w = 300, h = 390}
table.insert(CHROME._wins, PIP)
CHROME._focused = PIP
WINFILTER.subs["created"](PIP)
''')
run('Tabby.rebuildTimer:start()')
print("  ", names())
check("la miniatura non diventa una scheda", len(names()) == 2)
check("Tabby non la ridimensiona", ev('PIP._frame.w') == 300 and ev('PIP._frame.h') == 390)

print("\n== Passi al Finder")
run('FINDER:activate(); APPWATCH("Finder", "act", FINDER)')
check("Chrome NON viene nascosto (la miniatura resta visibile)", ev('CHROME._hidden') is False)
check("la miniatura è ancora della stessa misura", ev('PIP._frame.w') == 300)
run('CLICK("tab%d")' % (names().index("Meet") + 1))
check("clic sulla scheda Meet: la finestra grande, non la miniatura", ev('CHROME._focused == CHROME._wins[1]') is True)

print("\n== Fine condivisione: la miniatura si chiude")
run('PIP:close(); WINFILTER.subs["destroyed"](PIP); Tabby.rebuildTimer:start()')
run('FINDER:activate(); APPWATCH("Finder", "act", FINDER)')
check("ora Chrome si nasconde di nuovo come sempre", ev('CHROME._hidden') is True)
check("console: riga di diagnosi della miniatura",
      any("miniatura" in p for p in ev('PRINTS').values()))

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
