"""v9.40 (feedback del 23/10/2026): più finestre di Chrome con lo stesso titolo e la stessa
misura (es. due "Meet") non si scambiano più; una scheda di browser si può rinominare;
cliccando l'icona di una finestra con più siti si sceglie quale sito mostrare (finché c'è)."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Meet - abc-defg-hij", {"https://meet.google.com/abc-defg-hij"}},
  {"Meet - xyz-uvwx-rst", {"https://meet.google.com/xyz-uvwx-rst"}},
  {"Notizie", {"https://www.repubblica.it/", "https://www.corriere.it/", "https://www.ansa.it/"}},
})
M1, M2, NEWS = CHROME._wins[1], CHROME._wins[2], CHROME._wins[3]
for _, w in ipairs(CHROME._wins) do w._frame = {x = 0, y = 63, w = 1440, h = 837} end
FRONT = CHROME; CHROME._focused = M1
''')
L.execute(carica(base))
L.execute('FLUSH(); Tabby.rebuildTimer:start(); FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
def url_of(win): return ev(f'(function() local k = Tabby.winKey[{win}:id()]; local e = k and Tabby.cand[k]; return e and e.urls and e.urls[1] end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Schede:", names())
check("all'inizio ogni finestra Meet ha la sua riunione", "abc" in (url_of("M1") or "") and "xyz" in (url_of("M2") or ""))

print("== Le due finestre prendono lo stesso titolo «Meet» e Chrome le elenca al contrario")
run('M1._title = "Meet"; M2._title = "Meet"; CHROME._wins = {M2, M1, NEWS}; Tabby.rebuildTimer:start()')
run('Tabby.rebuildTimer:start()')
check("la prima finestra ha ancora la riunione abc", "abc" in (url_of("M1") or ""))
check("la seconda ha ancora la riunione xyz", "xyz" in (url_of("M2") or ""))

def rclick(i):
    # tasto destro sul centro della scheda i
    run(f'''local tv; for _, x in ipairs(Tabby.L.tabs) do if x.i == {i} then tv = x end end
local p = {{x = Tabby.bf.x + tv.r.x + tv.r.w / 2, y = Tabby.bf.y + tv.r.y + tv.r.h / 2}}
MENU = nil
for _, t in ipairs(TAPS) do if t.types[1] == 3 and t.on then RIGHT_SWALLOWED = t.fn({{location = function() return p end}}) end end''')

print("== Rinominare una scheda (tasto destro)")
i = idx("Chrome")
run(f'CLICK("close{i}")')
check("il menu della ✕ non ha più «Rinomina»", ev('(function() for _, it in ipairs(MENU) do if it.title == "Rinomina la scheda…" then return true end end return false end)()') is False)
rclick(i)
check("tasto destro sulla scheda: menu con «Rinomina la scheda…»", ev('MENU ~= nil and (function() for _, it in ipairs(MENU) do if it.title == "Rinomina la scheda…" then return true end end return false end)()') is True)
check("…e il clic destro non arriva all'app sotto", ev('RIGHT_SWALLOWED') is True)
run('PROMPT_TEXT = "Rassegna stampa"; for _, it in ipairs(MENU) do if it.title == "Rinomina la scheda…" then it.fn() end end')
check("la scheda ora si chiama «Rassegna stampa»", "Rassegna stampa" in names())
run('Tabby.rebuildTimer:start()')
check("…e resta così anche dopo un aggiornamento", "Rassegna stampa" in names())
rclick(idx("Rassegna stampa"))
run('for _, it in ipairs(MENU) do if it.title == "Torna al nome di prima" then it.fn() end end')
print("== Anche un'app in una scheda sola si rinomina")
rclick(idx("Finder"))
run('PROMPT_TEXT = "File"; for _, it in ipairs(MENU) do if it.title == "Rinomina la scheda…" then it.fn() end end')
check("il Finder ora si chiama «File»", "File" in names())
check("«Torna al nome di prima»: di nuovo «Chrome»", "Chrome" in names())

print("== Tasto destro su una finestra con più siti: scegli quale mostrare")
i = idx("Chrome")
run(f'CLICK("ticon{i}")')
check("il clic sull'icona non apre più niente (tutto col tasto destro)", ev('MENU') is None or ev('(function() for _, it in ipairs(MENU) do if tostring(it.title):find("repubblica", 1, true) then return true end end return false end)()') is False)
rclick(i)
sites = ev('(function() local o = {} for _, it in ipairs(MENU) do o[#o+1] = it.title end return table.concat(o, " | ") end)()')
print("   menu:", sites)
check("il menu elenca i tre siti aperti", "repubblica.it" in sites and "corriere.it" in sites and "ansa.it" in sites)
run('for _, it in ipairs(MENU) do if it.title:find("repubblica.it", 1, true) then it.fn() end end')
check("la scheda ora si chiama «Repubblica»", "Repubblica" in names())
check("…con il logo del sito", "repubblica.it" in str(ev(f'(function() local img = Tabby._env.keyIcon(Tabby.tabs[{idx("Repubblica")}].key); return img and img._url end)()')))
run('NEWS._urls = {"https://www.corriere.it/", "https://www.ansa.it/"}; Tabby.rebuildTimer:start()')
run('Tabby.rebuildTimer:start()')
check("chiuso il sito di Repubblica: torna «Chrome»", "Chrome" in names() and "Repubblica" not in names())

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
