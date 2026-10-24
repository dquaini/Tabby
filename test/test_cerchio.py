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
def orb_shown(): return ev('ORBVIEW ~= nil and ORBVIEW._shown') is True

run(f'CLICK("tab{idx("Note")}")')
run(f'CLICK("tab{idx("Slack")}")')
check("con finestre in vista Tabby è la barra", ev('Tabby.collapsed') is not True and not orb_shown())

print("== ⌃⌥0: la scrivania → il cerchio")
run('KEY("0", {"ctrl","alt"})')
check("Tabby diventa il cerchio", ev('Tabby.collapsed') is True and orb_shown())
check("la barra non si vede", ev('Tabby.visible') is False)
o = ev('(function() local f = ORBVIEW._frame; return f.x .. "," .. f.y .. "," .. f.w end)()')
print("   cerchio:", o)
check("in basso a destra, un po' verso il centro (60 punti dai bordi)", ev('(function() local o, s = Tabby._env.orbFrame(), hs.screen.primaryScreen():frame(); return s.x + s.w - (o.x + o.w) == 60 and s.y + s.h - (o.y + o.h) == 60 end)()') is True)
run('ORB_CB({body = {click = true}})')
check("clic sul cerchio: torna Slack (l'ultima finestra)", ev('FRONT == SLACK') is True and ev('SLACK._hidden') is False)
check("e Tabby torna barra", ev('Tabby.collapsed') is not True and not orb_shown() and ev('Tabby.visible') is True)

print("== Tutte le app nascoste (es. ⌘H): il cerchio")
run('for _, a in ipairs(APPS) do a._hidden = true end; FRONT = FINDER; APPWATCH(nil, "hide", SLACK)')
check("nessuna finestra in vista: il cerchio", ev('Tabby.collapsed') is True and orb_shown())
run('SLACK._hidden = false; FRONT = SLACK; APPWATCH(nil, "unhide", SLACK); APPWATCH(nil, "act", SLACK)')
check("una finestra torna in vista: di nuovo la barra", ev('Tabby.collapsed') is not True and not orb_shown())

print("== Nessuna finestra aperta: clic sul cerchio → le scelte a ventaglio")
run('''for _, a in ipairs({SLACK, NOTE}) do a._wins = {} end
FINDER._wins = {}
for _, a in ipairs({SLACK, NOTE}) do a._running = false end
APPS = {FINDER}; FRONT = FINDER
APPWATCH(nil, "term", SLACK); APPWATCH(nil, "term", NOTE)''')
check("il cerchio", ev('Tabby.collapsed') is True)
def js(): return ev('table.concat(ORBVIEW._js, " | ")')
L.execute('ORBVIEW._js = {}')
run('ORB_CB({body = {click = true}})')
check("il ventaglio si apre con «+ Nuova app»", ev('Tabby.fanOpen') is True and 'openFan([{id:"new"' in js())
check("la finestrella si allarga per contenerlo", ev('ORBVIEW._frame.w') == ev('Tabby._env.FAN_W'))
run('ORB_CB({body = {click = true}})')
check("clic di nuovo sul cerchio: si chiude e torna piccola", ev('Tabby.fanOpen') is not True and ev('ORBVIEW._frame.w') == ev('Tabby._env.ORB_VIEW'))
run('hs.settings.set("tabbar.folders", {{id = 1, name = "Lavoro", items = {{bid = "com.tinyspeck.slackmacgap", name = "Slack"}}}, {id = 2, name = "Viaggio", items = {{bid = "com.apple.Notes", name = "Note"}}}}); Tabby._env.S.folders = hs.settings.get("tabbar.folders")')
L.execute('ORBVIEW._js = {}')
run('ORB_CB({body = {click = true}})')
check("…con una sfera per ogni cartella", 'name:"Lavoro"' in js() and 'name:"Viaggio"' in js())
L.execute('SPOT = 0; Tabby._env.openSpotlight = function() SPOT = SPOT + 1 end')
run('ORB_CB({body = {choose = "new"}})')
check("clic su «+»: si apre Spotlight e il ventaglio si chiude", ev('SPOT') == 1 and ev('Tabby.fanOpen') is not True)
run('ORB_CB({body = {click = true}})')
run('ORB_CB({body = {outside = true}})')
check("clic fuori dalle sfere: si chiude", ev('Tabby.fanOpen') is not True)
run('ORB_CB({body = {click = true}})')
run('KEY("escape")')
check("Esc chiude il ventaglio", ev('Tabby.fanOpen') is not True)

print("== La sfera reagisce al puntatore")
L.execute('ORBVIEW._js = {}')
run('local o = Tabby._env.orbFrame(); MOUSE = {x = o.x - 30, y = o.y - 20}; Tabby.orbPoll.fn()')
check("puntatore vicino: la sfera lo sa (verso dove e quanto vicino)", "pointer(-" in js() and ev('Tabby.orbPoll:running()') is True)
L.execute('ORBVIEW._js = {}')
run('MOUSE = {x = 100, y = 100}; Tabby.orbPoll.fn()')
check("puntatore lontano: torna calma", "pointer(0.000,0.000,0.000)" in js())

print("== ⚙︎ → Chiudi Tabby: resta solo la sfera, Tabby ferma")
run('APPS = {FINDER}; for _, a in ipairs({SLACK, NOTE}) do a._running = true; a._hidden = false; a._wins = {newWindow(a, a._name)}; table.insert(APPS, a) end; FRONT = SLACK; APPWATCH(nil, "act", SLACK)')
check("con finestre in vista Tabby è la barra", ev('Tabby.collapsed') is not True and ev('Tabby.visible') is True)
run('CLICK("settings"); for _, it in ipairs(MENU) do if it.title and it.title:find("^Chiudi Tabby") then it.fn() end end')
check("la barra sparisce, resta la sfera", ev('Tabby.visible') is False and orb_shown())
check("…e si ricorda (anche dopo un riavvio)", ev('hs.settings.get("tabbar.paused")') is True)
run('KEY("2", {"ctrl","alt"})')
check("le scorciatoie ⌃⌥ non fanno niente (il tasto va all'app)", ev('FRONT == SLACK') is True)
run('NOTE:activate(); APPWATCH(nil, "act", NOTE)')
check("cambiando app Tabby non nasconde niente", ev('SLACK._hidden') is False)
run('ORB_CB({body = {click = true}})')
check("clic sulla sfera: Tabby riparte", ev('Tabby.paused') is False and ev('Tabby.visible') is True and not orb_shown())
check("…e se lo ricorda", ev('hs.settings.get("tabbar.paused")') is False)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
