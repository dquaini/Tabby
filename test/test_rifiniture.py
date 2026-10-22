"""Giro di rifiniture del 21/10: scheda +, Scambia nella vista divisa (⇄ e ⌃⌥S),
Spotlight fuori dal menu ⚡︎, ⌃⌥ + numero sulla scheda-cartella, niente
ridimensionamenti inutili."""
import os
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
ADDAPP("com.apple.finder", "Finder")
NOTION = ADDAPP("notion.id", "Notion")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
ADDAPP("com.apple.Notes", "Note")
FRONT = NOTION
KEYSTROKES = {}
hs.eventtap.keyStroke = function(m, k) KEYSTROKES[#KEYSTROKES+1] = table.concat(m, "+") .. "+" .. k end
''')
L.execute(open(base + '/tabby.lua').read())
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Scheda +")
check("c'è la scheda + in fondo alle schede", ev('Tabby.L.plus ~= nil') is True and
      ev('(function() local last = Tabby.L.tabs[#Tabby.L.tabs].r; return Tabby.L.plus.x >= last.x + last.w end)()') is True)
run('CLICK("plus")')
check("clic sul + → Spotlight (⌘Spazio)", "cmd+space" in ev('table.concat(KEYSTROKES, ",")'))
run('CLICK("quick")')
check("Spotlight non è più nel menu ⚡︎", not any("Spotlight" in (it or "") for it in
      ev('(function() local o = {} for _, it in ipairs(MENU) do o[#o+1] = it.title end return table.concat(o, "|") end)()').split("|")))
for i, pos in [(3, "left"), (4, "right"), (2, "bottom"), (1, "top")]:
    run(f'CLICK("settings"); MENU[1].menu[{i}].fn()')
    check(f"posizione {pos}: + presente e dentro la barra", ev('Tabby.L.plus ~= nil') is True and
          ev('Tabby.L.plus.x + Tabby.L.plus.w <= Tabby.bf.w and Tabby.L.plus.y + Tabby.L.plus.h <= Tabby.bf.h') is True)

print("\\n== Scambia nella vista divisa")
run('CLICK("split"); MENU[1].fn()')          # due app metà e metà, zona 1 = Notion
run(f'CLICK("tab{idx("Slack")}")')
check("vista divisa Notion + Slack", "Notion + Slack" in names())
left_before = ev('NOTION._wins[1]._frame.x'); right_before = ev('SLACK._wins[1]._frame.x')
check("Notion a sinistra, Slack a destra", left_before < right_before)
run(f'CLICK("rotate{idx("Notion + Slack")}")')
check("⇄: ora Slack a sinistra e Notion a destra", ev('SLACK._wins[1]._frame.x') < ev('NOTION._wins[1]._frame.x'))
check("il nome segue l'ordine (Slack + Notion)", "Slack + Notion" in names())
run('KEY("s", {"ctrl","alt"})')
check("⌃⌥S: di nuovo Notion a sinistra", ev('NOTION._wins[1]._frame.x') < ev('SLACK._wins[1]._frame.x'))
check("scelta salvata", ev('hs.settings.get("tabbar.groups")[1].members[1]') == "notion.id")
run(f'CLICK("ungroup{idx("Notion + Slack")}")')

print("\\n== Niente ridimensionamenti inutili")
L.execute('''
SETFRAMES = 0
for _, w in ipairs(hs.application.get("com.apple.Notes")._wins) do
  local orig = w.setFrame
  w.setFrame = function(self, r) SETFRAMES = SETFRAMES + 1; orig(self, r) end
end''')
run(f'CLICK("tab{idx("Note")}")')
first = ev('SETFRAMES')
run(f'CLICK("tab{idx("Finder")}")'); run(f'CLICK("tab{idx("Note")}")')
check("tornando su Note (già della misura giusta) nessun ridimensionamento", ev('SETFRAMES') == first)

print("\\n== ⌃⌥ + numero sulla scheda-cartella: entra subito, senza menu")
run('FRONT = hs.application.get("com.apple.finder")')
L.execute('hs.settings.set("tabbar.folders", nil)')
run('''PROMPT_TEXT = "Lavoro"
CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "Nuova cartella…" then it.fn() end end''')
run(f'CLICK("tab{idx("Slack")}"); KEY("return")')
run('KEY("1", {"ctrl","alt","shift"})')
n = idx("Lavoro")
run(f'MENU = nil; KEY("{n}", {{"ctrl","alt"}})')
check("vista cartella aperta senza menu", ev('Tabby.viewFolder') is not None and ev('MENU') is None)

print("\n== Spotlight: sfondo oscurato")
run('SPOTFILTER.subs["visible"]()')
run('SPOTFILTER.subs["created"]()')   # Spotlight manda anche "creata": nessun problema
check("Spotlight aperto → velo visibile e non trasparente", ev('Tabby.dimOn') is True and ev('Tabby.dim._shown') is True
      and ev('Tabby.dim:alpha()') == 1)
check("il velo non prende i clic (nessun mouseCallback)", ev('Tabby.dim._cb') is None)
L.execute('''
SAVED_FW = hs.window.focusedWindow
SPOTAPP = {bundleID = function() return "com.apple.Spotlight" end}
hs.window.focusedWindow = function() return {application = function() return SPOTAPP end} end
CLOCK = 2000; Tabby.dimPoll.fn()''')
check("Spotlight ancora aperto: il controllo lascia il velo", ev('Tabby.dim._shown') is True)
L.execute('hs.window.focusedWindow = SAVED_FW; Tabby.dimPoll.fn()')
check("Spotlight chiuso: il controllo toglie il velo subito (senza aspettare macOS)", ev('Tabby.dim._shown') is False)
run('SPOTFILTER.subs["notvisible"]()')
check("e il segnale di macOS che arriva dopo non fa danni", ev('Tabby.dim._shown') is False)
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Oscura") then it.fn() end end end end')
run('SPOTFILTER.subs["visible"]()')
check("interruttore spento → niente velo", ev('Tabby.dim._shown') is False)

print("\n== Calendario veloce (⌃⌥A)")
run('''CAL = ADDAPP("com.apple.iCal", "Calendario"); CAL._wins[1]._frame = {x = 100, y = 100, w = 1200, h = 800}
Tabby.rebuildTimer:start()''')
check("il Calendario non è una scheda (è un'app veloce)", "Calendario" not in names())
L.execute('''   -- come sul Mac: il Calendario non accetta meno di 680 di larghezza
local w = CAL._wins[1]; local orig = w.setFrame
w.setFrame = function(self, r) orig(self, {x = r.x, y = r.y, w = math.max(r.w, 680), h = r.h}) end''')
run('KEY("a", {"ctrl","alt"})')
check("⌃⌥A apre il Calendario", ev('FRONT == CAL') is True)
check("tutto dentro lo schermo (non tagliato a destra)",
      ev('CAL._wins[1]._frame.x + CAL._wins[1]._frame.w') <= ev('hs.screen.primaryScreen():frame().x + hs.screen.primaryScreen():frame().w'))
check("piccolo (680x520), in alto a destra", ev('CAL._wins[1]._frame.w') == 680 and ev('CAL._wins[1]._frame.h') == 520
      and ev('CAL._wins[1]._frame.x') > 600)
run('KEY("escape")')
check("Esc lo chiude", ev('CAL._hidden') is True)
run('CLICK("quick")')
check("nel menu ⚡︎ c'è «Calendario ⌃⌥A»", any("Calendario   ⌃⌥A" == (it or "") for it in
      ev('(function() local o = {} for _, it in ipairs(MENU) do o[#o+1] = it.title end return table.concat(o, "|") end)()').split("|")))

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
