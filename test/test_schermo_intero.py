"""Schermo intero (idea di Daniele, 23/10/2026): una finestra a schermo intero esce dai
radar di Tabby (non è una scheda) e Tabby non si vede; tornata normale, rientra."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder"); SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

check("all'inizio: Slack è una scheda e Tabby si vede", "Slack" in names() and ev('BAR()._shown') is True)
run('SLACK._wins[1]._fs = true; WINFILTER.subs["fs"](SLACK._wins[1])')
check("Slack a schermo intero: non è più una scheda", "Slack" not in names())
check("e Tabby non si vede", ev('BAR()._shown') is False)
check("la finestra non è stata toccata (resta a schermo intero)", ev('SLACK._wins[1]._fs') is True)
run('SLACK._wins[1]._fs = false; WINFILTER.subs["unfs"](SLACK._wins[1])')
check("tornata normale: Slack rientra come scheda", "Slack" in names())
print("== Scrivania a schermo intero riconosciuta subito (senza aspettare la finestra)")
run('SPACE_KIND = "fullscreen"; Tabby._env.updateFullscreen()')
check("macOS dice «scrivania a schermo intero»: Tabby sparisce subito", ev('BAR()._shown') is False)
run('SPACE_KIND = "user"; Tabby._env.updateFullscreen()')
check("e Tabby si vede", ev('BAR()._shown') is True)

print("== Anticipo: clic sul pallino verde o ⌃⌘F → Tabby sparisce subito")
run('FRONT = SLACK; SLACK._focused = SLACK._wins[1]; Tabby._env.draw()')
L.execute('''local f = SLACK._wins[1]._frame
local tap; for _, t in ipairs(TAPS) do if t.types[1] == 1 then tap = t end end
tap.fn({getType = function() return 1 end, location = function() return {x = f.x + 55, y = f.y + 12} end})''')
check("clic sul pallino verde: Tabby sparisce subito (prima dell'animazione)", ev('BAR()._shown') is False)
run('CLOCK = (CLOCK or 1000) + 3')
check("lo schermo intero non è partito: dopo 2 s Tabby ricompare", ev('BAR()._shown') is True)
L.execute('''local f = SLACK._wins[1]._frame
local tap; for _, t in ipairs(TAPS) do if t.types[1] == 1 then tap = t end end
tap.fn({getType = function() return 1 end, location = function() return {x = f.x + 300, y = f.y + 12} end})''')
check("un clic altrove nella barra del titolo non fa niente", ev('BAR()._shown') is True)
L.execute('KEY("f", {"cmd","ctrl"}); FLUSH(1)')   # solo il primo passo (non i 2 s dopo)
check("⌃⌘F: Tabby sparisce subito", ev('BAR()._shown') is False)
run('CLOCK = (CLOCK or 1000) + 3')

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
