"""v9.44 (feedback del 23/10/2026): più app veloci aperte insieme stanno in fila in alto a
destra; aprendone una nuova si sceglie dove (1 accanto, 2 sotto); chiudendone una le altre
si spostano a riempire il posto; il Memo entra nelle zone della vista divisa."""
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
CALC = ADDAPP("com.apple.calculator", "Calcolatrice")
TERM = ADDAPP("com.apple.Terminal", "Terminale")
CALC._hidden = true; TERM._hidden = true
CALC._wins[1]._frame = {x = 100, y = 100, w = 230, h = 330}
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
def fr(w): return ev(f'(function() local f = {w}; return f.x .. "," .. f.y .. "," .. f.w .. "," .. f.h end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)
right = ev('(function() local a = Tabby._env.appArea(); return a.x + a.w - 12 end)()')
top = ev('(function() local a = Tabby._env.appArea(); return a.y + 12 end)()')

run(f'CLICK("tab{idx("Slack")}")')
print("== ⌃⌥C: la Calcolatrice in alto a destra")
run('KEY("c", {"ctrl","alt"})')
check("Calcolatrice attaccata all'angolo in alto a destra", ev('CALC._wins[1]._frame.x + CALC._wins[1]._frame.w') == right and ev('CALC._wins[1]._frame.y') == top)

print("== ⌃⌥T con la Calcolatrice aperta: compaiono i due riquadri, scelgo 2 (sotto)")
run('KEY("t", {"ctrl","alt"})')
check("Tabby chiede dove metterlo (1 accanto, 2 sotto)", ev('Tabby.fchoose ~= nil') is True and ev('Tabby.fcCanvas._shown') is True)
check("il Terminale non è ancora aperto", ev('Tabby._env.floating("com.apple.Terminal")') is not True)
run('KEY("2")')
check("riquadri spariti", ev('Tabby.fchoose') is None and ev('Tabby.fcCanvas._shown') is False)
print("   Calcolatrice:", fr('CALC._wins[1]._frame'), "· Terminale:", fr('TERM._wins[1]._frame'))
check("Terminale sotto la Calcolatrice, allineato a destra", ev('TERM._wins[1]._frame.x + TERM._wins[1]._frame.w') == right
      and ev('TERM._wins[1]._frame.y') == ev('CALC._wins[1]._frame.y + CALC._wins[1]._frame.h') + 12)

print("== ⌃⌥M: il Memo, scelgo 1 (accanto)")
run('KEY("m", {"ctrl","alt"})')
check("di nuovo i riquadri", ev('Tabby.fchoose ~= nil') is True)
run('KEY("1")')
memo_right = ev('MEMO._frame.x + MEMO._frame.w')
col_left = ev('math.min(CALC._wins[1]._frame.x, TERM._wins[1]._frame.x)')
print("   Memo:", fr('MEMO._frame'))
check("Memo accanto, a sinistra della colonna", memo_right == col_left - 12 and ev('MEMO._frame.y') == top)

print("== Esc sulla Calcolatrice: le altre si spostano, niente buchi")
run('CALC:activate(); KEY("escape")')
print("   Terminale:", fr('TERM._wins[1]._frame'), "· Memo:", fr('MEMO._frame'))
check("il Terminale sale nell'angolo in alto a destra", ev('TERM._wins[1]._frame.y') == top and ev('TERM._wins[1]._frame.x + TERM._wins[1]._frame.w') == right)
check("il Memo si avvicina, accanto al Terminale", ev('MEMO._frame.x + MEMO._frame.w') == ev('TERM._wins[1]._frame.x') - 12)

print("== Esc nei riquadri: non apre niente")
run('KEY("c", {"ctrl","alt"})')
run('KEY("escape")')
check("Calcolatrice non aperta", ev('Tabby._env.floating("com.apple.calculator")') is not True and ev('Tabby.fchoose') is None)

print("== Vista divisa con il Memo aperto: entra già in una zona")
run('TERM:activate(); KEY("escape")')
run('HS_APP._wins = {}; FRONT = HS_APP')
run('CLICK("split"); MENU[1].fn()')
check("zona 1: Slack (la scheda di prima), zona 2: Memo", ev('Tabby.split.zones[1]') == "com.tinyspeck.slackmacgap" and ev('Tabby.split.zones[2]') == "memo")
run('KEY("return")')
check("vista divisa «Slack + Memo»", "Slack + Memo" in names())
check("il Memo occupa la metà di destra", ev('MEMO._frame.x') > 600 and ev('MEMO._frame.h') > 500)
run('KEY("m", {"ctrl","alt"}); Tabby.rebuildTimer:start()')
run('Tabby.rebuildTimer:start()')
check("chiuso il Memo, la vista si scioglie: torna Slack da solo", "Slack" in names() and "Slack + Memo" not in names())

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
