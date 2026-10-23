"""v9.39 (feedback del 23/10/2026): Calcolatrice, Calendario e Terminale sono "app veloci"
(piccole in alto a destra, sopra tutto finché non premi Esc) solo se le apri con la
scorciatoia o dal menu ⚡︎; da Spotlight o dal Dock sono app normali a tutto spazio; nella
vista divisa le app veloci aperte entrano già nelle zone."""
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
CALC = ADDAPP("com.apple.calculator", "Calcolatrice")
TERM = ADDAPP("com.apple.Terminal", "Terminale")
CALC._hidden = true; TERM._hidden = true
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

A = ev('(function() local a = Tabby._env.appArea(); return a.x + a.w end)()')

print("== ⌃⌥C: Calcolatrice piccola in alto a destra, non è una scheda")
run(f'CLICK("tab{idx("Slack")}")')
run('KEY("c", {"ctrl","alt"})')
check("è un'app veloce", ev('Tabby._env.floating("com.apple.calculator")') is True)
check("in alto a destra", ev('CALC._wins[1]._frame.x + CALC._wins[1]._frame.w') > A - 40)
check("non è una scheda", "Calcolatrice" not in names())

print("== Cambio scheda: la Calcolatrice resta in vista, sopra")
L.execute('RAISES = 0')
run(f'CLICK("tab{idx("Note")}")')
check("non viene nascosta", ev('CALC._hidden') is False)
check("e viene riportata sopra", ev('RAISES') >= 1)
L.execute('RAISES = 0')
run('MOUSE = {x = 400, y = 400}; for _, t in ipairs(TAPS) do if t.types[1] == 2 and t.on and t ~= DRAGTAP() then t.fn({}) end end')
check("anche dopo un clic su un'altra finestra", ev('RAISES') >= 1)

print("== Esc sulla Calcolatrice: si chiude e torna un'app normale")
run('CALC:activate(); KEY("escape")')
check("nascosta", ev('CALC._hidden') is True)
check("non più app veloce", ev('Tabby._env.floating("com.apple.calculator")') is not True)

print("== Terminale da Spotlight: app normale, a tutto spazio, con la sua scheda")
run('TERM:activate(); APPWATCH(nil, "act", TERM)')
check("è una scheda", "Terminale" in names())
fr = ev('TERM._wins[1]._frame')
check("adattato a tutto lo spazio", ev('(function() local a = Tabby._env.appArea(); local f = TERM._wins[1]._frame; return math.abs(f.w - a.w) < 2 and math.abs(f.h - a.h) < 2 end)()') is True)
check("le altre app nascoste (una scheda alla volta)", ev('SLACK._hidden') is True)

print("== ⌃⌥T sul Terminale normale: diventa piccolo in alto a destra")
run('KEY("t", {"ctrl","alt"})')
check("app veloce, 760 di larghezza", ev('Tabby._env.floating("com.apple.Terminal")') is True and ev('TERM._wins[1]._frame.w') == 760)
check("non è più una scheda", "Terminale" not in names())

print("== Vista divisa con il Terminale aperto: entra già in una zona")
run(f'CLICK("tab{idx("Slack")}")')
run('CLICK("split"); MENU[1].fn()')
check("zona 1: Slack, zona 2: Terminale", ev('Tabby.split.zones[1]') == "com.tinyspeck.slackmacgap" and ev('Tabby.split.zones[2]') == "com.apple.Terminal")
run('KEY("return")')
check("vista divisa creata con il Terminale", ev('(function() local g = hs.settings.get("tabbar.groups")[1]; return g and g.members[2] end)()') == "com.apple.Terminal")
check("il Terminale ora è un'app normale della vista", ev('Tabby._env.floating("com.apple.Terminal")') is not True)
check("…e sta nella metà di destra", ev('TERM._wins[1]._frame.x') > 600)

print("== Un clic sulla zona la svuota")
run('CLICK("split"); MENU[1].fn()')
L.execute('Tabby._env.exitSplit(); FLUSH()')

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
