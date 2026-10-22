"""Azioni rapide delle app (menu ⚡︎ → App): Claude chat rapida (preme l'icona nella barra
dei menu), Notion cerca / Notion AI (le loro scorciatoie ⌘⇧K / ⌘⇧J). Il pannello che si
apre non nasconde la scheda in cui sei."""
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
CLAUDE = ADDAPP("com.anthropic.claudefordesktop", "Claude"); CLAUDE._extras = true
NOTION = ADDAPP("notion.id", "Notion"); NOTION._extras = true
NOTION._menu = {"Toggle Command Search", "Toggle Notion AI", "Edit Shortcuts", "Quit Notion"}
KEYS = {}
hs.eventtap.keyStroke = function(m, k) KEYS[#KEYS+1] = table.concat(m, "+") .. "+" .. k end
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

run('CLICK("quick")')
titles = ev('(function() local o = {} for _, it in ipairs(MENU) do if it.title == "App" then for _, x in ipairs(it.menu) do o[#o+1] = x.title end end end return table.concat(o, "|") end)()').split("|")
check("menu ⚡︎ → «App ▸» con le tre azioni", "Claude · chat rapida   ⌃⌥L" in titles
      and "Notion · cerca   ⌃⌥N" in titles and "Notion AI   ⌃⌥I" in titles)

run('PRESSED = nil; KEY("n", {"ctrl","alt"})')
check("⌃⌥N → apre il menu dell'icona di Notion e preme «Toggle Command Search»",
      ev('PRESSED') == "notion.id:AXPress;Toggle Command Search:AXPress;")
run('PRESSED = nil; KEY("i", {"ctrl","alt"})')
check("⌃⌥I → «Toggle Notion AI»", ev('PRESSED') == "notion.id:AXPress;Toggle Notion AI:AXPress;")
run('KEY("l", {"ctrl","alt"})')
check("⌃⌥L → Tabby preme l'icona di Claude", (ev('PRESSED') or "").endswith("com.anthropic.claudefordesktop:AXPress;"))

print("== Icona di Notion spenta in macOS (parcheggiata fuori schermo): riserva")
run('NOTION._extrasPos = {x = -1, y = 899}; PRESSED = nil; KEYS = {}; FRONT = SLACK; KEY("n", {"ctrl","alt"})')
check("Tabby non preme l'icona nascosta", (ev('PRESSED') or "") == "")
check("porta davanti Notion e manda ⌘⇧K", ev('FRONT == NOTION') is True and "cmd+shift+k" in ev('table.concat(KEYS, ",")'))
run('NOTION._extrasPos = nil')

print("== Velo scuro sotto il pannello, come Spotlight")
run('FRONT = SLACK; SLACK._focused = SLACK._wins[1]; Tabby.veil(false); KEY("l", {"ctrl","alt"})')
check("con il pannello aperto lo sfondo è oscurato", ev('Tabby.dimOn') is True)
L.execute('PANEL = {id = function() return 999 end, application = function() return CLAUDE end, frame = function() return {x=500,y=200,w=600,h=120} end}')
L.execute('SAVED = hs.window.focusedWindow; hs.window.focusedWindow = function() return PANEL end; CLOCK = (CLOCK or 1000) + 1; Tabby.dimPoll.fn()')
check("mentre scrivi nel pannello il velo resta", ev('Tabby.dimOn') is True)
L.execute('hs.window.focusedWindow = SAVED; Tabby.dimPoll.fn()')
check("chiuso il pannello (torni alla tua finestra) il velo sparisce", ev('Tabby.dimOn') is False)

print("== Il pannello che si apre non nasconde la scheda in cui sei")
run('FRONT = SLACK; SLACK._hidden = false; KEY("n", {"ctrl","alt"})')
run('NOTION:activate(); APPWATCH("Notion", "act", NOTION)')
check("Slack resta visibile sotto la ricerca di Notion", ev('SLACK._hidden') is False)

print("== Icona non trovata (tolta dalla barra dei menu)")
run('CLAUDE._extras = nil; PRESSED = nil; KEY("l", {"ctrl","alt"})')
check("avviso chiaro, niente errori", (ev('PRESSED') or "") == "" and any("icona dell'app non trovata" in p for p in ev('PRINTS').values()))

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
