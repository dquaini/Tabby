"""Cartelle, seconda parte: una finestra di browser con più pagine dentro una cartella.
La cartella si ricorda le pagine (senza la parte dopo "?"); attivandola, se la finestra
non c'è, Chrome ne apre una nuova con tutte le pagine; se c'è, entra nella cartella."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Ricerca progetto - Google Chrome", {"https://www.notion.so/azienda/Progetto-123?pvs=4",
     "https://docs.google.com/document/d/abc/edit#heading=h.1", "https://app.slack.com/client/T1/C2"}},
  {"Sofascore - Google Chrome", {"https://www.sofascore.com/"}},
})
CHROME._wins[1]._asName = "Ricerca progetto"; CHROME._wins[2]._asName = "Sofascore"
for i, w in ipairs(CHROME._wins) do w._frame = {x = 0, y = 38, w = 1440, h = 862} end
RICERCA = CHROME._wins[1]
FRONT = CHROME; CHROME._focused = RICERCA
-- Chrome apre una finestra nuova con le pagine indicate (come lo script vero)
MAKE_HOOK = function(src)
  local urls = {}
  for u in src:gmatch('URL of active tab of w to "([^"]+)"') do urls[#urls+1] = u end
  for u in src:gmatch('make new tab with properties {URL:"([^"]+)"}') do urls[#urls+1] = u end
  local w = newWindow(CHROME, #urls > 0 and "Ricerca progetto - Google Chrome" or "Nuova scheda - Google Chrome", urls)
  w._asName = #urls > 0 and "Ricerca progetto" or "Nuova scheda"
  w._frame = {x = 0, y = 38, w = 1440, h = 862}
  table.insert(CHROME._wins, 1, w)
  NEWWIN = w
  WINFILTER.subs["created"](w)
end
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
def quick_item(prefix):
    run('CLICK("quick")')
    return f'(function() for _, it in ipairs(MENU) do if it.title and it.title:sub(1, {len(prefix)}) == "{prefix}" then return it end end end)()'
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Schede:", names())
print("== Nuova cartella «Progetto» con Slack e la finestra di Chrome con 3 pagine")
run(f'FRONT = SLACK; PROMPT_TEXT = "Progetto"; {quick_item("Nuova cartella")}.fn()')
run(f'CLICK("tab{idx("Chrome")}"); KEY("return")')
item = 'hs.settings.get("tabbar.folders")[1].items[2]'
check("la voce della finestra ricorda le 3 pagine", ev(f'#({item}.pages or {{}})') == 3)
pages = ev(f'table.concat({item}.pages or {{}}, " ")')
print("   pagine salvate:", pages)
check("senza la parte dopo «?» o «#» (privacy)", "pvs=" not in pages and "heading" not in pages and "?" not in pages and "#" not in pages)
check("nome comprensibile: «Ricerca progetto · 3 pagine»", ev(f'{item}.name') == "Ricerca progetto · 3 pagine")
check("Sofascore (altra finestra di Chrome) NON è nella cartella",
      ev('(function() for _, it in ipairs(hs.settings.get("tabbar.folders")[1].items) do if it.site == "sofascore.com" or (it.bid == "com.google.Chrome" and not it.pages and not it.site) then return true end end return false end)()') is False)

print("== Attivo la cartella con la finestra già aperta: entra nella cartella")
run('FRONT = FINDER; KEY("1", {"ctrl","alt","shift"})')
check("nessuna finestra nuova aperta", ev('NEWWIN == nil') is True)
check("la scheda-cartella raccoglie Slack e la finestra di Chrome", "Progetto" in names() and "Chrome" not in names() and "Slack" not in names())
check("Sofascore resta una scheda libera", "Sofascore" in names())

print("== La finestra si chiude; riattivo la cartella: Chrome la riapre con le 3 pagine")
L.execute(f'CLICK("fmenu{idx("Progetto")}")')
run('for _, it in ipairs(MENU) do if it.title and it.title:find("^Esci dalla cartella") then it.fn() end end')
run('RICERCA:close(); Tabby.rebuildTimer:start()')
run('KEY("1", {"ctrl","alt","shift"})')
check("Chrome apre una finestra nuova", ev('NEWWIN ~= nil') is True)
check("con le 3 pagine come schede", ev('NEWWIN and #NEWWIN._urls') == 3)
run('Tabby.rebuildTimer:start()')
check("e la finestra nuova entra nella cartella", "Chrome" not in names() and "Progetto" in names())
check("console: nessun indirizzo completo", not any("notion.so/azienda" in p for p in ev('PRINTS').values()))

print("== DuckDuckGo: la finestra si ricorda come «DuckDuckGo» (non dà gli indirizzi)")
run('''DDG = ADDAPP("com.duckduckgo.macos.browser", "DuckDuckGo"); FRONT = DDG; Tabby.rebuildTimer:start()''')
run(f'PROMPT_TEXT = "Svago"; {quick_item("Nuova cartella")}.fn()')
run('KEY("return")')
check("voce DuckDuckGo senza pagine", ev('(function() for _, f in ipairs(hs.settings.get("tabbar.folders")) do if f.name == "Svago" then return f.items[1].bid == "com.duckduckgo.macos.browser" and f.items[1].pages == nil end end end)()') is True)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
