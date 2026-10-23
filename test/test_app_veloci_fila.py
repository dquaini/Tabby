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
CAL = ADDAPP("com.apple.iCal", "Calendario")
CALC._hidden = true; TERM._hidden = true; CAL._hidden = true
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

print("== Rimettere in fila")
L.execute('SETFRAMES_ALL = 0'); run('Tabby._env.layoutFloaters()')
check("rimettere in fila Lampi già al loro posto non sposta niente", ev('SETFRAMES_ALL') == 0)

print("== Vista divisa: i Lampi aperti si trascinano o si cliccano nelle zone")
run(f'CLICK("tab{idx("Slack")}")')
run('CLICK("split"); MENU[1].fn()')
z = [ev('Tabby.split.zones[1]'), ev('Tabby.split.zones[2]')]
print("   zone:", z, "· Lampi nella fila:", list(ev('Tabby._env.splitLamps()').values()))
run('OVERLAY_CLICK("zone2")')
check("tolto per sbaglio il Lampo dalla zona 2: torna nella fila", ev('Tabby.split.zones[2]') is None and len(list(ev('Tabby._env.splitLamps()').values())) >= 1)
lamp = list(ev('Tabby._env.splitLamps()').values())[-1]
L.execute(f'''MOUSE = {{x = 700, y = 800}}
for _, c in ipairs(CANVASES) do if c == Tabby.overlay then c._cb(c, "mouseDown", "lamp:{lamp}") end end
local tap = DRAGTAP()
for s = 1, 5 do MOUSE = {{x = 700 + s * 80, y = 800 - s * 80}}; tap.fn({{getType = function() return 6 end}}) end
tap.fn({{getType = function() return 2 end}})
FLUSH()''')
check(f"trascinato «{lamp}» sulla zona di destra: nasce la vista con lui", ev('(function() for _, g in ipairs(hs.settings.get("tabbar.groups")) do for _, m in ipairs(g.members) do if m == "' + lamp + '" then return true end end end return false end)()') is True)
gi = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.group then return i end end end)()')
run(f'CLICK("ungroup{gi}")')
run(f'CLICK("tab{idx("Slack")}")')
run('CLICK("split"); MENU[1].fn(); OVERLAY_CLICK("zone2")')
lamp = list(ev('Tabby._env.splitLamps()').values())[0]
run(f'for _, c in ipairs(CANVASES) do if c == Tabby.overlay then c._cb(c, "mouseUp", "lamp:{lamp}") end end')
check(f"cliccato «{lamp}» nella fila: va nella zona libera (e la vista nasce)", ev('(function() for _, g in ipairs(hs.settings.get("tabbar.groups")) do for _, m in ipairs(g.members) do if m == "' + lamp + '" then return true end end end return false end)()') is True)
gi = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.group then return i end end end)()')
run(f'CLICK("ungroup{gi}")')

print("== Sotto non c'è spazio: il riquadro 2 si vede, grigio")
run('Tabby._env.hideFloater("com.apple.calculator"); Tabby._env.hideFloater("com.apple.Terminal"); if Tabby.memoOpen then Tabby._env.closeMemo() end')
run('KEY("t", {"ctrl","alt"})')
run('KEY("a", {"ctrl","alt"})')
fits = ev('Tabby.fchoose and Tabby.fchoose.fits')
print("   Calendario dopo il Terminale: nessun posto libero → si può scegliere, in parte sopra:", ev('Tabby.fchoose and Tabby.fchoose.overlap'))
check("nessun posto libero: Tabby lo dice («in parte sopra») e lascia scegliere", ev('Tabby.fchoose.overlap') is True and ev('(function() for _, e in ipairs(Tabby.fcCanvas._els) do if tostring(e.text):find("in parte sopra", 1, true) then return true end end return false end)()') is True)
run('KEY("2")')
check("premuto 2: il Calendario va sotto il Terminale (in parte sopra), dentro lo schermo",
      ev('CAL._wins[1]._frame.x + CAL._wins[1]._frame.w') == ev('TERM._wins[1]._frame.x + TERM._wins[1]._frame.w')
      and ev('CAL._wins[1]._frame.y + CAL._wins[1]._frame.h') <= ev('(function() local a = Tabby._env.appArea(); return a.y + a.h end)()'))
run('Tabby._env.hideFloater("com.apple.iCal")')
run('CALC._wins[1]._frame.h = 408; KEY("c", {"ctrl","alt"})')
check("Calcolatrice (alta 408, come sul Mac) dopo il Terminale: sotto non ci sta, accanto sì", ev('Tabby.fchoose and Tabby.fchoose.fits[2]') is False and ev('Tabby.fchoose.fits[1]') is True)
check("il riquadro «sotto: non c'è spazio» è disegnato, grigio", ev('(function() for _, e in ipairs(Tabby.fcCanvas._els) do if tostring(e.text):find("non c\'è spazio") then return true end end return false end)()') is True)
run('KEY("escape")')
run('Tabby._env.hideFloater("com.apple.Terminal")')
run('KEY("c", {"ctrl","alt"})')
run('KEY("m", {"ctrl","alt"})')
check("con spazio (Calcolatrice + Memo) tutti e due i riquadri sono validi", ev('Tabby.fchoose and Tabby.fchoose.fits[2]') is True)
run('KEY("escape")')
run('Tabby._env.hideFloater("com.apple.calculator")')

print("== Esc nei riquadri: non apre niente")
run('KEY("c", {"ctrl","alt"})')
run('KEY("escape")')
check("Calcolatrice non aperta", ev('Tabby._env.floating("com.apple.calculator")') is not True and ev('Tabby.fchoose') is None)

print("== Vista divisa con il Memo aperto: entra già in una zona")
run(f'CLICK("tab{idx("Slack")}")')
run('KEY("m", {"ctrl","alt"})')
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
