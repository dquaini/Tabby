"""v9.41 (feedback del 23/10/2026): con la barra dei menu di macOS nascosta, quando scende
(puntatore in cima) Tabby le scende sotto, in alto e di lato, e risale quando il puntatore
torna giù oltre Tabby; le notifiche di macOS non compaiono sopra Tabby."""
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

run('Tabby.menuHidden = true; Tabby._env.draw()')
check("con la barra dei menu nascosta il controllo del puntatore è acceso", ev('Tabby.mouseTimer:running()') is True)
y0 = ev('Tabby.bf.y'); mh = ev('Tabby._env.realMenuH()')
print("== Tabby in alto:", bar())
tick(700, 0)
check(f"puntatore in cima: Tabby scende sotto la barra dei menu (+{mh})", ev('Tabby.bf.y') == y0 + mh)
tick(700, y0 + mh + 20)
check("puntatore sopra Tabby: resta giù (le schede non scappano)", ev('Tabby.bf.y') == y0 + mh)
tick(700, 400)
check("puntatore giù nelle app: Tabby risale", ev('Tabby.bf.y') == y0)

print("== Tabby a destra")
run('CLICK("settings"); MENU[1].menu[4].fn()')
h0 = ev('Tabby.bf.h'); y0 = ev('Tabby.bf.y')
tick(300, 0)
check("puntatore in cima: la colonna di Tabby comincia sotto la barra dei menu", ev('Tabby.bf.y') == y0 + mh and ev('Tabby.bf.h') == h0 - mh)
tick(1350, 300)
check("puntatore su Tabby: resta giù", ev('Tabby.bf.y') == y0 + mh)
tick(600, 300)
check("puntatore nelle app: torna su", ev('Tabby.bf.y') == y0)

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
