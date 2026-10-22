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
NOTION = ADDAPP("notion.id", "Notion")
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
titles = ev('(function() local o = {} for _, it in ipairs(MENU) do o[#o+1] = it.title end return table.concat(o, "|") end)()').split("|")
check("menu ⚡︎: sezione «App» con le tre azioni", "App" in titles and "Claude · chat rapida   ⌃⌥L" in titles
      and "Notion · cerca   ⌃⌥N" in titles and "Notion AI   ⌃⌥I" in titles)

run('KEY("n", {"ctrl","alt"})')
check("⌃⌥N → la scorciatoia di Notion ⌘⇧K", "cmd+shift+k" in ev('table.concat(KEYS, ",")'))
run('KEY("i", {"ctrl","alt"})')
check("⌃⌥I → Notion AI ⌘⇧J", "cmd+shift+j" in ev('table.concat(KEYS, ",")'))
run('KEY("l", {"ctrl","alt"})')
check("⌃⌥L → Tabby preme l'icona di Claude", ev('PRESSED') == "com.anthropic.claudefordesktop:AXPress;")

print("== Il pannello che si apre non nasconde la scheda in cui sei")
run('FRONT = SLACK; SLACK._hidden = false; KEY("n", {"ctrl","alt"})')
run('NOTION:activate(); APPWATCH("Notion", "act", NOTION)')
check("Slack resta visibile sotto la ricerca di Notion", ev('SLACK._hidden') is False)

print("== Icona non trovata (tolta dalla barra dei menu)")
run('CLAUDE._extras = nil; PRESSED = nil; KEY("l", {"ctrl","alt"})')
check("avviso chiaro, niente errori", ev('PRESSED') is None and any("icona dell'app non trovata" in p for p in ev('PRINTS').values()))

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
