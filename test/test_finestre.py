"""v1 · A: più schede per qualsiasi app (una scheda per finestra, nome = titolo)."""
import os
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
FINDER = ADDAPP("com.apple.finder", "Finder")
FINDER._wins = {}
table.insert(FINDER._wins, newWindow(FINDER, "Download"))
table.insert(FINDER._wins, newWindow(FINDER, "Documenti"))
ADDAPP("com.tinyspeck.slackmacgap", "Slack")
TE = ADDAPP("com.apple.TextEdit", "TextEdit")
TE._wins = {}
table.insert(TE._wins, newWindow(TE, "Relazione — TextEdit"))
table.insert(TE._wins, newWindow(TE, "Senza titolo"))
FRONT = APPS[2]
''')
L.execute(carica(base))
L.execute('FLUSH()')

def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def rebuild(): run('Tabby.rebuildTimer:start()')
def tabs():
    return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name .. " [" .. t.key .. "]" end return table.concat(o, "  |  ") end)()')
def names(): return ev('TABNAMES()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')

fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Avvio:", tabs())
check("Finder con 2 finestre = 2 schede col nome della cartella",
      "Download" in names() and "Documenti" in names() and "Finder" not in names().split(" | "))
check("nome senza l'app in fondo: «Relazione — TextEdit» → «Relazione»", "Relazione" in names().split(" | "))
check("la prima finestra tiene la chiave dell'app (resta al suo posto)",
      ev('Tabby.tabs[%d].key' % idx("Download")) == "com.apple.finder")
check("le finestre stanno vicine (Download, Documenti)", idx("Documenti") == idx("Download") + 1)

# --- passare a una finestra precisa ---
print("\n== ⌃⌥ + numero sulla seconda finestra del Finder")
n = idx("Documenti")
run(f'KEY("{n}", {{"ctrl","alt"}})')
check("in primo piano la finestra «Documenti»", ev('FRONT._name == "Finder" and FRONT._focused._title') == "Documenti")
check("la scheda attiva è «Documenti»", ev('Tabby.lastKey') == ev('Tabby.tabs[%d].key' % n))
run('KEY("tab", {"ctrl","alt"})')
check("⌃⌥Tab torna a Slack", ev('FRONT._name') == "Slack")
run(f'KEY("{n}", {{"ctrl","alt"}})')

# --- titolo uguale ---
print("\n== Terza finestra del Finder, anche lei «Download»")
run('local w = newWindow(FINDER, "Download"); table.insert(FINDER._wins, w); WINFILTER.subs["created"](w)')
print("  ", names())
check("due «Download» distinguibili: «Download (2)»", "Download (2)" in names())

# --- il titolo cambia ---
run('FINDER._wins[3]._title = "Scrivania"; WINFILTER.subs["title"](FINDER._wins[3])')
check("titolo cambiato → nome della scheda aggiornato", "Scrivania" in names() and "Download (2)" not in names())

# --- interruttore per app ---
print("\n== ⚙︎ → Finestre separate → Finder spento")
run('CLICK("settings")')
L.execute('for _, it in ipairs(MENU) do if it.title == "Finestre separate" then SUB = it.menu end end')
check("c'è il menu «Finestre separate»", ev('SUB ~= nil'))
check("Finder spuntato (normale: una scheda per finestra)",
      ev('(function() for _, it in ipairs(SUB) do if it.title == "Finder" then return it.checked end end end)()') is True)
run('for _, it in ipairs(SUB) do if it.title == "Finder" then it.fn() end end')
print("  ", names())
check("Finder torna una scheda sola", names().split(" | ").count("Finder") == 1 and "Documenti" not in names())
check("scelta salvata", ev('hs.settings.get("tabbar.joinWins")["com.apple.finder"]') is True)
run('CLICK("settings"); for _, it in ipairs(MENU) do if it.title == "Finestre separate" then for _, x in ipairs(it.menu) do if x.title == "Finder" then x.fn() end end end end')
check("riacceso: di nuovo una scheda per finestra", "Documenti" in names())

# --- vista divisa con una finestra ---
print("\n== Vista divisa: «Documenti» + Slack")
run(f'CLICK("tab{idx("Documenti")}")')
run('CLICK("split"); MENU[1].fn()')
run(f'CLICK("tab{idx("Slack")}")')
print("  ", tabs())
check("vista divisa creata", ev('#hs.settings.get("tabbar.groups")') == 1)
check("«Documenti» è nella zona di sinistra", ev('FINDER._wins[2]._frame.x') < 100 and ev('FINDER._wins[2]._frame.w') < 800)
check("le altre finestre del Finder non sono state spostate", ev('FINDER._wins[1]._frame.w') != ev('FINDER._wins[2]._frame.w'))
check("«Download» resta una scheda a sé", "Download" in names())
run('local w = newWindow(FINDER, "Immagini"); table.insert(FINDER._wins, w); WINFILTER.subs["created"](w)')
check("una finestra nuova del Finder diventa una scheda nuova (non entra nella vista)",
      "Immagini" in names() and ev('#hs.settings.get("tabbar.groups")[1].members') == 2)

# --- chiudere finestre ---
print("\n== Chiudo le finestre del Finder tranne una")
run('''
for _, w in ipairs({FINDER._wins[1], FINDER._wins[3], FINDER._wins[4]}) do w:close() end
Tabby.rebuildTimer:start()''')
print("  ", names())
check("restano Documenti (nella vista) e niente altre schede del Finder", "Download" not in names() and "Immagini" not in names())

# le posizioni disegnano senza errori
for i, pos in [(2, "bottom"), (3, "left"), (4, "right"), (1, "top")]:
    run(f'CLICK("settings"); MENU[1].menu[{i}].fn()')
check("tutte le posizioni disegnano", ev('#Tabby.L.tabs') > 0)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
