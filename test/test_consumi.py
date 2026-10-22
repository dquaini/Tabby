"""Consumi (23/10/2026): il controllo del mouse gira solo se serve (Nascondi Tabby o fascia
del notch); i browser in secondo piano si rileggono ogni 15 s invece di 3; "Apri <app>"
con l'icona spenta in macOS apre direttamente l'app."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder"); SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {{"Ricerca", {"https://www.google.com/search?q=x", "https://it.wikipedia.org/x"}}})
PROTON = ADDAPP("ch.protonvpn.mac", "Proton VPN"); PROTON._extras = true; PROTON._extrasPos = {x = -1, y = 899}
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

check("senza «Nascondi Tabby» né fascia del notch, il controllo del mouse è spento", ev('Tabby.mouseTimer:running()') is False)
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Nascondi Tabby") then it.fn() end end end end')
check("con «Nascondi Tabby» si accende", ev('Tabby.mouseTimer:running()') is True)
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Nascondi Tabby") then it.fn() end end end end')
check("tolto, si rispegne", ev('Tabby.mouseTimer:running()') is False)

print("== Browser in secondo piano: riletti ogni 15 s")
L.execute('TASKS = 0; CLOCK = 2000; Tabby.lastBrowserCheck = 2000')
for t in (2003, 2006, 2009, 2012):
    L.execute(f'CLOCK = {t}; Tabby.browserTimer.fn(); FLUSH()')
check("in 12 s nessuna domanda a Chrome (stai usando Slack)", ev('TASKS') == 0)
L.execute('CLOCK = 2016; Tabby.browserTimer.fn(); FLUSH()')
check("dopo 15 s sì", ev('TASKS') > 0)
L.execute('TASKS = 0; FRONT = CHROME; CLOCK = 2019; Tabby.browserTimer.fn(); FLUSH()')
check("se stai usando Chrome: ogni 3 s", ev('TASKS') > 0)

print("== Apri Proton VPN con l'icona spenta in macOS")
run('PRESSED = nil; OPENS = nil; CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "App" then for _, x in ipairs(it.menu) do if x.title == "Apri Proton VPN" then x.fn() end end end end')
check("non preme l'icona (non servirebbe)", ev('PRESSED') is None)
check("apre l'app (open -b)", any("-b ch.protonvpn.mac" in o for o in (ev('OPENS') or {}).values()) if ev('OPENS') else False)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
