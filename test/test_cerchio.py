"""v9.51 (24/10/2026, Daniele): quando non c'è nessuna finestra in vista Tabby si ritira in
un cerchio col muso del gatto, in basso a destra; appena compare una finestra torna la
barra. Clic sul gatto (cerchio o barra): l'ultima finestra che stavi guardando; se non ce
n'è nessuna, un menu con «+ Nuova app…» e le cartelle."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
NOTE = ADDAPP("com.apple.Notes", "Note")
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)
def orb_shown(): return ev('Tabby.orb ~= nil and Tabby.orb._shown') is True

run(f'CLICK("tab{idx("Note")}")')
run(f'CLICK("tab{idx("Slack")}")')
check("con finestre in vista Tabby è la barra", ev('Tabby.collapsed') is not True and not orb_shown())

print("== ⌃⌥0: la scrivania → il cerchio")
run('KEY("0", {"ctrl","alt"})')
check("Tabby diventa il cerchio", ev('Tabby.collapsed') is True and orb_shown())
check("la barra non si vede", ev('Tabby.visible') is False)
o = ev('(function() local f = Tabby.orb:frame(); return f.x .. "," .. f.y .. "," .. f.w end)()')
print("   cerchio:", o)
check("in basso a destra", ev('(function() local f, s = Tabby.orb:frame(), hs.screen.primaryScreen():frame(); return f.x + f.w > s.x + s.w - 40 and f.y + f.h > s.y + s.h - 40 end)()') is True)
run('Tabby.orb._cb(Tabby.orb, "mouseUp", "orb")')
check("clic sul cerchio: torna Slack (l'ultima finestra)", ev('FRONT == SLACK') is True and ev('SLACK._hidden') is False)
check("e Tabby torna barra", ev('Tabby.collapsed') is not True and not orb_shown() and ev('Tabby.visible') is True)

print("== Tutte le app nascoste (es. ⌘H): il cerchio")
run('for _, a in ipairs(APPS) do a._hidden = true end; FRONT = FINDER; APPWATCH(nil, "hide", SLACK)')
check("nessuna finestra in vista: il cerchio", ev('Tabby.collapsed') is True and orb_shown())
run('SLACK._hidden = false; FRONT = SLACK; APPWATCH(nil, "unhide", SLACK); APPWATCH(nil, "act", SLACK)')
check("una finestra torna in vista: di nuovo la barra", ev('Tabby.collapsed') is not True and not orb_shown())

print("== Nessuna finestra aperta: clic sul cerchio → menu")
run('''for _, a in ipairs({SLACK, NOTE}) do a._wins = {} end
FINDER._wins = {}
for _, a in ipairs({SLACK, NOTE}) do a._running = false end
APPS = {FINDER}; FRONT = FINDER
APPWATCH(nil, "term", SLACK); APPWATCH(nil, "term", NOTE)''')
check("il cerchio", ev('Tabby.collapsed') is True)
L.execute('MENU = nil')
run('Tabby.orb._cb(Tabby.orb, "mouseUp", "orb")')
titles = ev('(function() local o = {} for _, it in ipairs(MENU or {}) do o[#o+1] = it.title end return table.concat(o, " | ") end)()')
print("   menu:", titles)
check("menu con «+ Nuova app…»", "Nuova app" in titles)
run('hs.settings.set("tabbar.folders", {{id = 1, name = "Lavoro", items = {{bid = "com.tinyspeck.slackmacgap", name = "Slack"}}}}); Tabby._env.S.folders = hs.settings.get("tabbar.folders")')
L.execute('MENU = nil')
run('Tabby.orb._cb(Tabby.orb, "mouseUp", "orb")')
titles = ev('(function() local o = {} for _, it in ipairs(MENU or {}) do o[#o+1] = it.title end return table.concat(o, " | ") end)()')
print("   menu:", titles)
check("…e le cartelle, se ci sono", "Cartelle" in titles and "Lavoro" in titles)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
