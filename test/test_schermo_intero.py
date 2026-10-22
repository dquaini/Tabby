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
check("e Tabby si rivede", ev('BAR()._shown') is True)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
