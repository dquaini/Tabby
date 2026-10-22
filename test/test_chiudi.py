"""Chiudere la scheda attiva (⌃⌥W o ✕ → Chiudi finestra): se dell'app non resta nessuna
finestra in vista, si passa alla scheda a sinistra (a destra se era la prima); se resta
un'altra finestra della stessa app, resta lei."""
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
FRONT = FINDER
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

print("== Schede:", names())
run(f'CLICK("tab{idx("Note")}")')
left = names()[names().index("Note") - 1]
# ⌃⌥W sull'unica finestra di Note: Note resta aperta ma senza finestre
run('local w = NOTE._wins[1]; KEY("w", {"ctrl","alt"}); NOTE._focused = nil; WINFILTER.subs["destroyed"](w); Tabby.rebuildTimer:start()')
check(f"⌃⌥W: si passa alla scheda a sinistra ({left})", ev('FRONT._name') == left)
check("Note non è più una scheda (non ha finestre)", "Note" not in names())

print("== ✕ → Chiudi finestra sulla prima scheda: si passa a quella a destra")
run(f'CLICK("tab{idx("Finder")}")')
first = names()[0]; right = names()[1]
run(f'CLICK("close{idx(first)}")')
run(f'local w = hs.application.get("com.apple.finder")._wins[1]; MENU[1].fn(); FINDER._focused = nil; WINFILTER.subs["destroyed"](w); Tabby.rebuildTimer:start()')
check(f"chiusa «{first}»: ora sei su «{right}»", ev('FRONT._name') == right)

print("== Con «Mostra anche app aperte senza finestre» acceso, non si cambia scheda")
L.execute('NOTE2 = ADDAPP("com.apple.TextEdit", "TextEdit")')
run('Tabby.rebuildTimer:start()')
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Mostra anche app") then it.fn() end end end end')
run(f'CLICK("tab{idx("TextEdit")}")')
run('local w = NOTE2._wins[1]; KEY("w", {"ctrl","alt"}); NOTE2._focused = nil; WINFILTER.subs["destroyed"](w); Tabby.rebuildTimer:start()')
check("resti su TextEdit (senza finestre)", ev('FRONT._name') == "TextEdit")

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
