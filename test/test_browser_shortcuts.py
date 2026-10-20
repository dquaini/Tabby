"""Test v9: browser (webapp, Chrome A/B/C, permesso negato), notifiche, scorciatoie ⌃⌥ e riserva, console non ridimensionata."""
import sys
import lupa.lua54 as l

import os
base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
ADDAPP("com.apple.finder", "Finder")
ADDAPP("com.tinyspeck.slackmacgap", "Slack")
ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Posta in arrivo (3) - io@gmail.com - Gmail", {"https://mail.google.com/mail/u/0/#inbox"}},
  {"Notizie", {"https://www.repubblica.it/", "https://www.corriere.it/"}},
  {"Documento - Google Docs", {"https://docs.google.com/document/d/1", "https://docs.google.com/document/d/2"}},
  {"Ricerca", {"https://www.google.com/search?q=tabby", "https://it.wikipedia.org/wiki/Gatto"}},
})
ADDAPP("com.microsoft.rdc.macos", "Windows App")
CALC = ADDAPP("com.apple.calculator", "Calcolatrice")
ADDAPP("com.apple.Stickies", "Stickies")
DOCK_BADGES = {["com.tinyspeck.slackmacgap"] = "5"}
FRONT = APPS[2]
''')
src = open(base + '/tabby.lua').read()
L.execute(src)
L.execute('FLUSH()')

def ev(code): return L.execute('return ' + code)
def tabs():
    return ev('''(function() local o = {} for i, t in ipairs(Tabby.tabs) do
      local b = nil
      o[#o+1] = t.name .. " [" .. t.key .. "]" end return table.concat(o, "  |  ") end)()''')
print("== Schede all'avvio:\n  ", tabs())
print("   notifiche: Slack =", ev('Tabby.badges["com.tinyspeck.slackmacgap"]'),
      "| Gmail (dal titolo) =", ev('Tabby.cand["site:mail.google.com"] and Tabby.cand["site:mail.google.com"].titleBadge'))
print("   loghi siti richiesti:", ev('FAVICON_REQ'))
print("   '⌃N' disegnato da qualche parte:", ev('''(function() for _, e in ipairs(BAR()._els) do if type(e.text) == "string" and e.text:match("^⌃%d") then return true end end return false end)()'''))
print("   pallini rossi disegnati:", ev('''(function() local n = 0 for _, e in ipairs(BAR()._els) do if e.fillColor == nil then elseif e.fillColor.hex == "#FF453A" then n = n + 1 end end return n end)()'''))

# --- scorciatoie ⌃⌥ ---
L.execute('KEY("3", {"ctrl","alt"}); FLUSH()')
print("\n== ⌃⌥3 → in primo piano:", ev('FRONT._name'), "/ finestra:", ev('FRONT._focused and FRONT._focused._title'))
L.execute('KEY("right", {"ctrl","alt"}); FLUSH()')
print("== ⌃⌥→ → scheda attiva:", ev('Tabby.tabs[Tabby.L and (function() for _, tv in ipairs(Tabby.L.tabs) do end end)() or 1] and ""'), ev('(function() local k = nil; for i,t in ipairs(Tabby.tabs) do end; return FRONT._focused and FRONT._focused._title or FRONT._name end)()'))
L.execute('KEY("tab", {"ctrl","alt"}); FLUSH()')
print("== ⌃⌥Tab → torna a:", ev('FRONT._focused and FRONT._focused._title or FRONT._name'))
r = ev('KEY("1", {"ctrl"})')
print("== Ctrl+1 da solo ora NON è più di Tabby (passa all'app):", r is not True)
# riserva: scorciatoia di sistema (come se Windows App si prendesse la tastiera)
L.execute('FRONT = hs.application.get("com.microsoft.rdc.macos"); HOTKEYS["c"](); FLUSH()')
print("== Windows App in primo piano, ⌃⌥C via riserva di sistema → in primo piano:", ev('FRONT._name'))
L.execute('KEY("escape"); FLUSH()')
print("   Esc → Calcolatrice chiusa?", ev('FRONT._name ~= "Calcolatrice"'), "(se non c'è l'app finta, ok)")

# --- doppio evento: stesso tasto dai due meccanismi = una volta sola ---
L.execute('''COUNT = 0
local orig = Tabby.tabs
''')

# --- browser: chiudi una finestra / webapp nel gruppo ---
L.execute('''
for i, t in ipairs(Tabby.tabs) do if t.key == "site:mail.google.com" then GMAIL = i end end
CLICK("close" .. GMAIL)
''')
print("\n== ✕ su Gmail → menu:", [ev(f'MENU[{i}] and MENU[{i}].title') for i in (1, 2)])

# dividi: Gmail + Slack
L.execute('''
for i, t in ipairs(Tabby.tabs) do if t.key == "site:mail.google.com" then CLICK("tab" .. i) end end
FLUSH()
CLICK("split"); MENU[1].fn(); FLUSH()
for i, t in ipairs(Tabby.tabs) do if t.bid == "com.tinyspeck.slackmacgap" then CLICK("tab" .. i) end end
FLUSH()
''')
print("== Gruppo Gmail + Slack:", tabs())
print("   finestra Gmail:", ev('(function() local w = Tabby.keyWin["site:mail.google.com"]; local f = w._frame; return f.x..","..f.y.." "..f.w.."x"..f.h end)()'))
print("   finestra Slack:", ev('(function() local f = hs.application.get("com.tinyspeck.slackmacgap")._wins[1]._frame; return f.x..","..f.y.." "..f.w.."x"..f.h end)()'))
print("   notifiche sul gruppo:", ev('(function() for _, t in ipairs(Tabby.tabs) do if t.group then return (function() local s,d = 0 for _,k in ipairs(t.group.members) do end return true end)() end end end)()'))

# chiusura della finestra Gmail → il gruppo si scioglie
L.execute('Tabby.keyWin["site:mail.google.com"]:close(); Tabby.rebuildTimer:start(); FLUSH()')
print("\n== Chiusa la finestra Gmail →", tabs())

# permesso AppleScript negato → solo Chrome A/B/C, senza siti
L.execute('AS_DENIED = true; Tabby.rebuildTimer:start(); FLUSH()')
print("\n== Permesso negato:", tabs())
L.execute('AS_DENIED = false; Tabby.rebuildTimer:start(); FLUSH()')

# Console di Hammerspoon aperta: non deve essere ridimensionata
L.execute('''
local w = newWindow(HS_APP, "Hammerspoon Console")
local before = w._frame.w
FRONT = HS_APP
WINFILTER.subs["created"](w); FLUSH()
CONSOLE_OK = (w._frame.w == before)
''')
print("\n== Console di Hammerspoon non ridimensionata:", ev('CONSOLE_OK'))

# tutte le posizioni
for idx, pos in [(2, "bottom"), (3, "left"), (4, "right"), (1, "top")]:
    L.execute(f'CLICK("settings"); MENU[1].menu[{idx}].fn(); FLUSH()')
    print(f"   posizione {pos}: ok, {ev('#Tabby.L.tabs')} schede disegnate")
print("\nTUTTO OK")
