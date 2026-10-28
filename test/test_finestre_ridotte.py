"""v9.61 (28/10/2026, Daniele: «Tabby mi ha chiuso delle finestre di Chrome e Anteprima»).
Non le chiudeva: «una scheda alla volta» le riduceva nel Dock, e poi sparivano dalla barra.
Causa: su macOS 26 una finestra ridotta, o di un'app nascosta, si dice "dialogo" e non
"finestra normale" (visto con TextEdit). Ora restano schede."""
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
PREVIEW = ADDAPP("com.apple.Preview", "Anteprima")
PREVIEW._wins = {newWindow(PREVIEW, "Contratto.pdf"), newWindow(PREVIEW, "Fattura.pdf"), newWindow(PREVIEW, "Biglietto.pdf")}
for _, w in ipairs(PREVIEW._wins) do w._macos26 = true end
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name:find("{name}", 1, true) then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("schede:", names())
check("all'inizio le tre finestre di Anteprima sono tre schede", all(n in names() for n in ("Contratto", "Fattura", "Biglietto")))
run(f'CLICK("tab{idx("Fattura")}")')
check("scelta «Fattura»: le altre due si riducono nel Dock (una scheda alla volta)", ev('PREVIEW._wins[1]._min') is True and ev('PREVIEW._wins[3]._min') is True)
run('Tabby._env.rebuildTabs()')
print("schede:", names())
check("…ma restano schede nella barra (prima sparivano)", all(n in names() for n in ("Contratto", "Fattura", "Biglietto")))
run(f'CLICK("tab{idx("Slack")}")')
run('Tabby._env.rebuildTabs()')
check("Anteprima nascosta (sei su Slack): sempre tre schede", ev('PREVIEW._hidden') is True and all(n in names() for n in ("Contratto", "Fattura", "Biglietto")))
run(f'CLICK("tab{idx("Contratto")}")')
check("clic su «Contratto» (ridotta): torna davanti", ev('PREVIEW._wins[1]._min') is False and ev('FRONT == PREVIEW') is True)

print("== Dopo un riavvio di Tabby (non si ricorda niente)")
L.execute('Tabby.stdSeen = {}; PREVIEW._hidden = true; PREVIEW._wins[2]._min = true')
run('Tabby._env.rebuildTabs()')
check("finestre ridotte e app nascosta: le riconosce lo stesso", all(n in names() for n in ("Contratto", "Fattura", "Biglietto")))
L.execute('PREVIEW._wins[3]._title = ""; Tabby.stdSeen = {}')
run('Tabby._env.rebuildTabs()')
check("un vero dialogo (senza titolo, non ridotto) di un'app nascosta non è una scheda", "Biglietto" not in names() and ev('#Tabby.tabs') >= 3)

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
