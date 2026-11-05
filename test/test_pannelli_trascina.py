"""v9.69 (5/11/2026, Daniele):
1. «Quando arriva la notifica di Notion che inizia un meeting e vuole registrare, spacca
   tutto»: Notion diventa attiva per mostrare una finestrella (pannello) e Tabby nascondeva
   tutte le altre app, anche il browser col meeting. Ora un pannello piccolo che non è una
   finestra normale non nasconde niente.
2. «Ogni tanto la linea blu compare in mezzo tra due icone»: era la linea di "dove cadrà"
   di un trascinamento il cui rilascio del clic non era arrivato."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
NOTION = ADDAPP("notion.id", "Notion")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {{"Meet - riunione", {"https://meet.google.com/abc-defg-hij"}}})
MEET = CHROME._wins[1]
FRONT = CHROME
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(c): return L.execute('return ' + c)
def run(c): L.execute(c); L.execute('FLUSH()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name:find("{name}", 1, true) then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== 1. Notion mostra la finestrella «vuoi registrare il meeting?»")
run(f'CLICK("tab{idx("Meet")}")')
check("sei sul meeting in Chrome", ev('FRONT == CHROME') is True and ev('CHROME._hidden') is False)
run('''PANEL = newWindow(NOTION, "Notion AI Meeting Notes"); PANEL._subrole = "AXFloatingWindow"
PANEL._frame = {x = 1050, y = 60, w = 360, h = 140}
table.insert(NOTION._wins, PANEL); NOTION._focused = PANEL
NOTION._hidden = false; FRONT = NOTION; APPWATCH(nil, "act", NOTION)''')
check("Chrome (il meeting) NON viene nascosto", ev('CHROME._hidden') is False)
check("la finestrella non viene ingrandita", ev('PANEL._frame.w') == 360)
check("nel diario: «pannello di Notion … non nascondo le altre app»", any("pannello di Notion" in p for p in ev('PRINTS').values()))
check("nel diario: ogni cambio di app con tipo e misura della finestra", any("attiva: Notion" in p and "AXFloatingWindow" in p for p in ev('PRINTS').values()))
print("== …ma passare davvero a Notion funziona come sempre")
run('''NOTION._wins = {newWindow(NOTION, "Appunti - Notion")}; NOTION._focused = NOTION._wins[1]''')
run(f'Tabby._env.rebuildTabs(); CLICK("tab{idx("Notion")}")')
check("su una finestra normale di Notion: Chrome si nasconde (una scheda alla volta)", ev('FRONT == NOTION') is True and ev('CHROME._hidden') is True)

print("== 2. La linea blu del trascinamento")
run(f'CLICK("tab{idx("Slack")}")')
def marker(): return ev('Tabby.dropMarker ~= nil')
L.execute(f'''local r = Tabby.L.tabs[1].r; MOUSE = {{x = Tabby.bf.x + r.x + 10, y = Tabby.bf.y + 10}}; MOUSE_DOWN = true
BAR()._cb(BAR(), "mouseDown", "tab1")
local tap = DRAGTAP()
for s = 1, 5 do MOUSE = {{x = MOUSE.x + 40, y = MOUSE.y}}; tap.fn({{getType = function() return 6 end}}) end''')
check("mentre trascini c'è la linea di «dove cadrà»", marker() is True)
L.execute('MOUSE_DOWN = false')   # hai lasciato il tasto… ma il rilascio non arriva a Tabby
L.execute('Tabby.pressGuard.fn(); FLUSH()')
check("il rilascio non arriva: entro 0,3 s Tabby chiude da sé, la linea sparisce", marker() is False and ev('Tabby.press') is None)
check("…e il clic dopo sulla barra funziona (non viene ignorato)", ev('Tabby.suppressClick') is False)
check("…e il diario lo dice", any("rilascio del clic non è arrivato" in p for p in ev('PRINTS').values()))
run(f'CLICK("tab{idx("Notion")}")')
check("clic su una scheda: ci si va", ev('FRONT == NOTION') is True)
print("== Trascinamento normale: la linea sparisce al rilascio")
L.execute('''MOUSE_DOWN = true; local r = Tabby.L.tabs[1].r; MOUSE = {x = Tabby.bf.x + r.x + 10, y = Tabby.bf.y + 10}
BAR()._cb(BAR(), "mouseDown", "tab1")
local tap = DRAGTAP()
for s = 1, 5 do MOUSE = {x = MOUSE.x + 40, y = MOUSE.y}; tap.fn({getType = function() return 6 end}) end
MOUSE_DOWN = false; tap.fn({getType = function() return 2 end}); FLUSH()''')
check("rilasciato: niente linea, niente trascinamento in corso", marker() is False and ev('Tabby.press') is None and ev('Tabby.pressGuard') is None)

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
