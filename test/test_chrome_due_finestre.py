"""Chrome con due finestre della STESSA misura e posizione (Tabby le adatta tutte
allo stesso spazio) e Chrome che le elenca in un altro ordine (prima quella in
primo piano): ogni scheda deve restare con la sua finestra e il suo sito.
Difetto visto sul Mac vero il 22/10/2026 (Sofascore e Google scambiate)."""
import os
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
FINDER = ADDAPP("com.apple.finder", "Finder")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Calcio - risultati | Sofascore - Google Chrome", {"https://www.sofascore.com/"}},
})
CHROME._wins[1]._asName = "Calcio - risultati | Sofascore"
SOFA = CHROME._wins[1]
SOFA._frame = {x = 0, y = 38, w = 1440, h = 862}
FRONT = CHROME
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def tabs():
    return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name .. "=" .. tostring(t.win and t.win:title()) end return table.concat(o, "  |  ") end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

def coherent():
    # ogni webapp è legata alla finestra che mostra davvero quel sito
    return ev('''(function()
      for _, t in ipairs(Tabby.allTabs) do
        if t.site and t.win then
          local ok = false
          for _, u in ipairs(t.win._urls) do if u:find(t.site, 1, true) then ok = true end end
          if not ok then return false end
        end
      end
      return true end)()''')

print("== Una finestra:", tabs())
# nuova finestra (⌘N) con una ricerca Google, stessa misura e posizione;
# Chrome la elenca PER PRIMA (è in primo piano)
run('''
GOOG = newWindow(CHROME, "agi - Cerca con Google - Google Chrome", {"https://www.google.com/search?q=agi"})
GOOG._asName = "agi - Cerca con Google"
GOOG._frame = {x = 0, y = 38, w = 1440, h = 862}
table.insert(CHROME._wins, 1, GOOG)
CHROME._focused = GOOG
WINFILTER.subs["created"](GOOG)
Tabby.rebuildTimer:start()
''')
run('Tabby.rebuildTimer:start()')
print("== Due finestre:", tabs())
check("ogni webapp è legata alla sua finestra (niente scambi)", coherent() is True)
check("Sofascore → finestra di Sofascore", ev('Tabby.keyWin["site:sofascore.com"] == SOFA') is True)
check("Google → finestra di Google", ev('Tabby.keyWin["site:google.com"] == GOOG') is True)
i = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.site == "sofascore.com" then return i end end end)()')
run(f'CLICK("tab{i}")')
check("clic su Sofascore → si apre Sofascore", ev('CHROME._focused == SOFA') is True)

# anche dopo che le finestre cambiano titolo (la risposta di Chrome è vecchia)
run('''
SOFA._title = "Live | Sofascore - Google Chrome"; SOFA._asName = "Live | Sofascore"
WINFILTER.subs["title"](SOFA)''')
check("dopo un cambio di titolo: ancora tutto al suo posto", coherent() is True)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
