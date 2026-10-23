"""Lampi in fila (v9.44 → v9.46, feedback del 23/10/2026): più Lampi aperti stanno in fila in
alto a destra; aprendone uno nuovo: posto in tutti e due i modi → si sceglie (1 accanto, 2
sotto); in un modo solo → va lì; da nessuna parte → non si apre e lo dice. Finché ci sono
Lampi aperti la loro colonna è riservata: l'app che usi si stringe e non li copre.
Chiudendone uno gli altri riempiono il posto; il Memo e i Lampi entrano nella vista divisa."""
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
def alerts(): return ev('(function() local o = {} for _, l in ipairs(LOG) do if l:find("^alert") then o[#o+1] = l end end return table.concat(o, " / ") end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)
B = ev('(function() local a = Tabby._env.baseAppArea(); return a.x .. "," .. a.w end)()').split(",")
right = ev('(function() local a = Tabby._env.baseAppArea(); return a.x + a.w - 12 end)()')
top = ev('(function() local a = Tabby._env.baseAppArea(); return a.y + 12 end)()')
full_w = ev('Tabby._env.baseAppArea().w')
def slack_w(): return ev('SLACK._wins[1]._frame.w')

run(f'CLICK("tab{idx("Slack")}")')
check("senza Lampi Slack usa tutto lo spazio", slack_w() == full_w)

print("== ⌃⌥C: la Calcolatrice in alto a destra, e Slack si stringe")
run('KEY("c", {"ctrl","alt"})')
check("Calcolatrice attaccata all'angolo in alto a destra", ev('CALC._wins[1]._frame.x + CALC._wins[1]._frame.w') == right and ev('CALC._wins[1]._frame.y') == top)
print("   Slack:", fr('SLACK._wins[1]._frame'))
check("Slack finisce prima della Calcolatrice (la colonna dei Lampi è riservata)", ev('SLACK._wins[1]._frame.x + SLACK._wins[1]._frame.w') <= ev('CALC._wins[1]._frame.x') - 12 + 1)

print("== ⌃⌥M: posto sia accanto sia sotto → i due riquadri, scelgo 2")
run('KEY("m", {"ctrl","alt"})')
check("Tabby chiede dove metterlo", ev('Tabby.fchoose ~= nil') is True and ev('Tabby.fcCanvas._shown') is True)
run('KEY("2")')
print("   Memo:", fr('MEMO._frame'))
check("Memo sotto la Calcolatrice, allineato a destra", ev('MEMO._frame.x + MEMO._frame.w') == right and ev('MEMO._frame.y') == ev('CALC._wins[1]._frame.y + CALC._wins[1]._frame.h') + 12)
check("Slack si stringe ancora (il Memo è più largo della Calcolatrice)", ev('SLACK._wins[1]._frame.x + SLACK._wins[1]._frame.w') <= ev('MEMO._frame.x') - 12 + 1)

print("== ⌃⌥T: niente posto né accanto né sotto → non si apre e lo dice")
L.execute('LOG = {}')
run('KEY("t", {"ctrl","alt"})')
check("nessun riquadro", ev('Tabby.fchoose') is None)
check("il Terminale non si apre", ev('Tabby._env.floating("com.apple.Terminal")') is not True)
check("al centro: «Non c'è spazio per mettere Terminale»", "Non c'è spazio per mettere Terminale" in alerts())

print("== Chiuso il Memo, ⌃⌥T: posto solo sotto → ci va diretto, senza riquadri")
run('KEY("m", {"ctrl","alt"})')
run('KEY("t", {"ctrl","alt"})')
check("nessun riquadro", ev('Tabby.fchoose') is None)
print("   Calcolatrice:", fr('CALC._wins[1]._frame'), "· Terminale:", fr('TERM._wins[1]._frame'))
check("il Terminale è sotto la Calcolatrice", ev('Tabby._env.floating("com.apple.Terminal")') is True and ev('TERM._wins[1]._frame.y') == ev('CALC._wins[1]._frame.y + CALC._wins[1]._frame.h') + 12)

print("== Esc sulla Calcolatrice: il Terminale sale, Slack si allarga di nuovo")
run('CALC:activate(); KEY("escape")')
check("il Terminale sale nell'angolo in alto a destra", ev('TERM._wins[1]._frame.y') == top and ev('TERM._wins[1]._frame.x + TERM._wins[1]._frame.w') == right)
L.execute('SETFRAMES_ALL = 0'); run('Tabby._env.layoutFloaters()')
check("rimettere in fila Lampi già al loro posto non sposta niente", ev('SETFRAMES_ALL') == 0)
run(f'CLICK("tab{idx("Slack")}")')
check("Slack arriva fino al Terminale", ev('SLACK._wins[1]._frame.x + SLACK._wins[1]._frame.w') == ev('TERM._wins[1]._frame.x') - 12)
run('TERM:activate(); KEY("escape")')
run(f'CLICK("tab{idx("Slack")}")')
check("Lampi tutti chiusi: Slack di nuovo a tutto spazio", slack_w() == full_w and ev('Tabby.lampReserve or 0') == 0)

print("== Vista divisa: i Lampi aperti si trascinano o si cliccano nelle zone")
run('KEY("c", {"ctrl","alt"})')
run('KEY("m", {"ctrl","alt"})')
run('KEY("1")')
run(f'CLICK("tab{idx("Slack")}")')
run('CLICK("split"); MENU[1].fn()')
print("   zone:", ev('Tabby.split.zones[1]'), ev('Tabby.split.zones[2]'), "· fila:", list(ev('Tabby._env.splitLamps()').values()))
run('OVERLAY_CLICK("zone2")')
check("tolto per sbaglio il Lampo dalla zona 2: torna nella fila", ev('Tabby.split.zones[2]') is None and len(list(ev('Tabby._env.splitLamps()').values())) == 2)
lamp = list(ev('Tabby._env.splitLamps()').values())[-1]
zx = ev('(function() local r = Tabby._env.zoneRect(Tabby.split.layout, 2); return r.x + r.w / 2 end)()')
L.execute(f'''MOUSE = {{x = 700, y = 800}}
for _, c in ipairs(CANVASES) do if c == Tabby.overlay then c._cb(c, "mouseDown", "lamp:{lamp}") end end
local tap = DRAGTAP()
for s = 1, 5 do MOUSE = {{x = 700 + ({zx} - 700) * s / 5, y = 800 - s * 80}}; tap.fn({{getType = function() return 6 end}}) end
tap.fn({{getType = function() return 2 end}})
FLUSH()''')
def in_group(k): return ev('(function() for _, g in ipairs(hs.settings.get("tabbar.groups")) do for _, m in ipairs(g.members) do if m == "' + k + '" then return true end end end return false end)()')
check(f"trascinato «{lamp}» sulla zona di destra: nasce la vista con lui", in_group(lamp) is True)
gi = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.group then return i end end end)()')
run(f'CLICK("ungroup{gi}")')
run(f'CLICK("tab{idx("Slack")}")')
run('CLICK("split"); MENU[1].fn(); OVERLAY_CLICK("zone2")')
lamp = list(ev('Tabby._env.splitLamps()').values())[0]
run(f'for _, c in ipairs(CANVASES) do if c == Tabby.overlay then c._cb(c, "mouseUp", "lamp:{lamp}") end end')
check(f"cliccato «{lamp}» nella fila: va nella zona libera (e la vista nasce)", in_group(lamp) is True)
gi = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.group then return i end end end)()')
run(f'CLICK("ungroup{gi}")')

print("== Vista divisa con il Memo aperto: entra già in una zona")
run('Tabby._env.hideFloater("com.apple.calculator"); if Tabby.memoOpen then Tabby._env.closeMemo() end')
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
