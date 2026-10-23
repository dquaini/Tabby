"""v9.43 (feedback del 23/10/2026): barra dei menu e Dock che si nascondono da soli: quando
compaiono dalla parte di Tabby, Tabby esce dallo schermo e rientra quando se ne vanno
(negli altri casi non cambia nulla); le notifiche di macOS non compaiono sopra Tabby (v9.41)."""
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
def tick(x, y): run(f'MOUSE = {{x = {x}, y = {y}}}; Tabby.mouseTimer.fn()')
def bar(): return ev('(function() local f = Tabby.bf; return f.x .. "," .. f.y .. "," .. f.w .. "," .. f.h end)()')

def slide():
    L.execute('for _ = 1, 20 do if not Tabby.slideTimer then break end Tabby.slideTimer.fn() end FLUSH()')

run('Tabby.menuHidden = true; Tabby.dockPrefs = {autohide = true, side = "right", size = 68}; Tabby._env.draw()')
check("barra dei menu nascosta e Tabby in alto: il controllo del puntatore è acceso", ev('Tabby.mouseTimer:running()') is True)
print("== Tabby in alto, scende la barra dei menu")
tick(700, 0); slide()
check("Tabby esce dallo schermo", ev('Tabby.edgeHidden') == "barra dei menu" and ev('Tabby.bar._shown') is False)
tick(700, 20); slide()
check("finché il puntatore è sulla barra dei menu resta fuori", ev('Tabby.bar._shown') is False)
tick(700, 300); slide()
check("la barra dei menu se ne va: Tabby rientra al suo posto", ev('Tabby.edgeHidden') is None and ev('Tabby.bar._shown') is True and ev('Tabby.bar:frame().y') == ev('Tabby.bf.y'))

print("== Tabby a destra, Dock a destra")
run('CLICK("settings"); MENU[1].menu[4].fn()')
tick(300, 0); slide()
check("la barra dei menu non tocca Tabby di lato: non cambia nulla", ev('Tabby.edgeHidden') is None and ev('Tabby.bar._shown') is True)
tick(1439, 400); slide()
check("il Dock arriva da destra: Tabby esce dallo schermo", ev('Tabby.edgeHidden') == "Dock" and ev('Tabby.bar._shown') is False)
tick(1400, 400); slide()
check("puntatore ancora sul Dock: resta fuori", ev('Tabby.bar._shown') is False)
tick(900, 400); slide()
check("il Dock se ne va: Tabby rientra", ev('Tabby.edgeHidden') is None and ev('Tabby.bar._shown') is True)

check("Tabby di lato con la barra dei menu nascosta: in cima una fascia nera alta come la barra",
      ev('Tabby.L.desk.y') == ev('Tabby._env.realMenuH()') and ev('Tabby.L.tabs[1].r.y') > ev('Tabby.L.desk.y + Tabby.L.desk.h'))
run('Tabby.menuHidden = false; Tabby._env.draw()')
check("barra dei menu sempre visibile: niente fascia (Tabby parte già sotto)", ev('Tabby.L.desk.y') == 0)
run('Tabby.menuHidden = true; Tabby._env.draw()')

print("== Dock in basso, Tabby a destra: non cambia nulla")
run('Tabby.dockPrefs = {autohide = true, side = "bottom", size = 68}; Tabby._env.draw()')
tick(700, 899); slide()
check("Tabby resta al suo posto", ev('Tabby.edgeHidden') is None and ev('Tabby.bar._shown') is True)
run('Tabby.dockPrefs = {autohide = false, side = "right", size = 68}')

print("== Notifiche di macOS")
L.execute('''
NC = {_bid = "com.apple.notificationcenterui", _wins = {}}
function NCWIN() local w = newWindow(NC, "Notification Center"); w._frame = {x = 0, y = 0, w = 1440, h = 900}; return w end''')
run('N1 = NCWIN(); NCFILTER.subs["created"](N1)')
check("Tabby a destra: la notifica va a sinistra di Tabby", ev('N1._axpos and N1._axpos.x') == -ev('Tabby.bf.w') and ev('N1._axpos.y') == 0)
run('CLICK("settings"); MENU[1].menu[1].fn()')
run('N2 = NCWIN(); NCFILTER.subs["visible"](N2)')
check("Tabby in alto: la notifica scende sotto Tabby", ev('N2._axpos and N2._axpos.y') == ev('Tabby.bf.y + Tabby.bf.h') and ev('N2._axpos.x') == 0)
run('CLICK("settings"); MENU[1].menu[2].fn()')
run('N3 = NCWIN(); NCFILTER.subs["created"](N3)')
check("Tabby in basso: la notifica resta dov'è", ev('N3._axpos') is None or (ev('N3._axpos.x') == 0 and ev('N3._axpos.y') == 0))
run('Tabby.fullscreen = true; N4 = NCWIN(); NCFILTER.subs["created"](N4); Tabby.fullscreen = false')
check("a schermo intero non si sposta", ev('N4._axpos') is None or ev('N4._axpos.y') == 0)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
