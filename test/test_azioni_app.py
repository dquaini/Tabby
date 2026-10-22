"""Azioni delle app: Tabby scopre da sola le app con un'icona nella barra dei menu (anche
quelle aperte dopo), le mette in ⚡︎ → App ▸ (una riga sola anche con tante app), si possono
nascondere e avere una scorciatoia ⌃⌥ + lettera."""
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
DISCORD = ADDAPP("com.hnc.Discord", "Discord"); DISCORD._extras = true
CC = ADDAPP("com.apple.controlcenter", "Centro di Controllo"); CC._extras = true
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def app_menu():
    run('CLICK("quick")')
    return ev('(function() local o = {} for _, it in ipairs(MENU) do if it.title == "App" then for _, x in ipairs(it.menu) do o[#o+1] = x.title end end end return table.concat(o, "|") end)()').split("|")
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== All'avvio Tabby scopre le app con l'icona")
check("Discord trovata e ricordata", ev('hs.settings.get("tabbar.menuApps")["com.hnc.Discord"].name') == "Discord")
check("le app di sistema di Apple restano fuori", ev('hs.settings.get("tabbar.menuApps")["com.apple.controlcenter"]') is None)
check("le app senza icona restano fuori (Slack)", ev('hs.settings.get("tabbar.menuApps")["com.tinyspeck.slackmacgap"]') is None)
m = app_menu()
check("⚡︎ → App ▸ «Apri Discord»", "Apri Discord" in m)
check("in fondo «Gestisci» e «Cerca app nuove adesso»", "Gestisci" in m and "Cerca app nuove adesso" in m)

print("== Apri Discord: Tabby preme la sua icona")
L.execute('''DISCORD._focused = nil
for _, it in ipairs(MENU) do if it.title == "App" then for _, x in ipairs(it.menu) do if x.title == "Apri Discord" then x.fn() end end end end''')
check("icona premuta", "com.hnc.Discord:AXPress" in (ev('PRESSED') or ""))
run('')
check("non si è aperto niente (icona spenta con menu): si apre l'app", ev('FRONT == DISCORD') is True)

print("== Un'app installata dopo, appena si apre, viene scoperta")
run('NORD = ADDAPP("com.nordvpn.macos", "NordVPN"); NORD._extras = true; APPWATCH("NordVPN", "launch", NORD)')
check("NordVPN aggiunta in automatico", "Apri NordVPN" in app_menu())
check("console: riga di avviso", any("nuova app con icona nella barra dei menu: NordVPN" in p for p in ev('PRINTS').values()))

print("== Gestisci: nascondere e scorciatoia")
L.execute('CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "App" then for _, x in ipairs(it.menu) do if x.title == "Gestisci" then MAN = x.menu end end end end')
run('for _, x in ipairs(MAN) do if x.title == "NordVPN" then x.menu[1].fn() end end')
check("NordVPN nascosta da ⚡︎ → App", "Apri NordVPN" not in app_menu())
L.execute('CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "App" then for _, x in ipairs(it.menu) do if x.title == "Gestisci" then MAN = x.menu end end end end')
run('PROMPT_TEXT = "m"; for _, x in ipairs(MAN) do if x.title == "Discord" then x.menu[2].fn() end end')
check("⌃⌥M è già del Memo: rifiutata", ev('hs.settings.get("tabbar.menuApps")["com.hnc.Discord"].key') is None)
run('PROMPT_TEXT = "d"; for _, x in ipairs(MAN) do if x.title == "Discord" then x.menu[2].fn() end end')
check("⌃⌥D salvata per Discord", ev('hs.settings.get("tabbar.menuApps")["com.hnc.Discord"].key') == "d")
check("e compare nel menu: «Apri Discord   ⌃⌥D»", "Apri Discord   ⌃⌥D" in app_menu())

print("== Tante app: ⚡︎ resta corto (una riga «App»)")
run('for k = 1, 100 do local a = ADDAPP("com.prova.app" .. k, "Prova " .. k); a._extras = true end; Tabby._env.scanMenuBarApps()')
run('CLICK("quick")')
check("100 app in più: il menu ⚡︎ ha comunque meno di 20 righe", ev('#MENU') < 20)
check("e sono tutte dentro App ▸", len(app_menu()) > 100)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
