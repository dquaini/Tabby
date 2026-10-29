"""Gesti del trackpad: tre dita verso sinistra = scheda dopo, verso destra = scheda prima.
Un solo cambio per gesto; due o quattro dita non fanno niente; interruttore in ⚙︎."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
ADDAPP("com.apple.finder", "Finder"); ADDAPP("com.tinyspeck.slackmacgap", "Slack"); ADDAPP("com.apple.Notes", "Note")
FRONT = APPS[2]
-- un evento "gesture" finto con n dita alla posizione x (0..1 sul trackpad)
function GESTO(n, x, phase)
  local touches = {}
  for i = 1, n do touches[i] = {normalizedPosition = {x = x + i * 0.01, y = 0.5}, phase = phase or "moved", identity = i} end
  local tap
  for _, t in ipairs(TAPS) do if t.types[1] == 29 then tap = t end end
  CLOCK = (CLOCK or 1000) + 0.02   -- un evento ogni 20 ms, come il trackpad
  READS = (READS or 0) + 1
  tap.fn({getType = function() return 29 end, getTouches = function() READ = (READ or 0) + 1; return touches end})
end
function SCORRI(n, da, a)
  for s = 0, 6 do GESTO(n, da + (a - da) * s / 6) end
  GESTO(n, a, "ended"); GESTO(0, a, "ended")
end
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def front(): return ev('FRONT._name')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

order = ev('TABNAMES()').split(" | ")
print("== Schede:", order, "· sei su", front())
start = order.index(front())
run('SCORRI(3, 0.7, 0.3)')
check("tre dita verso sinistra → scheda dopo", front() == order[(start + 1) % len(order)])
run('SCORRI(3, 0.3, 0.7)')
check("tre dita verso destra → scheda prima", front() == order[start])
run('SCORRI(3, 0.9, 0.1)')
check("un gesto lungo cambia una scheda sola", front() == order[(start + 1) % len(order)])
here = front()
run('SCORRI(2, 0.8, 0.2)')
check("due dita: niente", front() == here)
run('SCORRI(4, 0.8, 0.2)')
check("quattro dita: niente (sono di macOS)", front() == here)
run('SCORRI(3, 0.5, 0.45)')
check("movimento piccolo: niente", front() == here)
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Tre dita") then it.fn() end end end end')
run('SCORRI(3, 0.8, 0.2)')
check("interruttore spento: niente", front() == here)

run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Tre dita") then it.fn() end end end end')
print("== Memoria: le dita non si leggono a ogni evento")
L.execute('READ = 0; READS = 0; for s = 1, 100 do GESTO(2, 0.5 + s * 0.001) end')
print("   scorrimento con due dita: %d eventi, %d letture" % (ev('READS'), ev('READ')))
check("scorrendo con due dita si legge meno di un evento su 5", ev('READ') * 5 < ev('READS'))
L.execute('GESTO(0, 0.5, "ended")')
here = front()
run('SCORRI(3, 0.7, 0.3)')
check("…e il gesto a tre dita funziona ancora", front() != here)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
