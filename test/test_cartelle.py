"""v1 · B: Cartelle (spazi di lavoro salvati), la storia di Daniele del 21/10/2026.
Creare dal menu ⚡︎, attivare (caso A: sei su una sua app → vista cartella;
caso B: sei altrove → scheda unica e resti dove sei), app chiuse che si aprono,
vista cartella, ⌃⌥⇧ + numero, Vista cartelle spenta, Esci / Chiudi cartella.
"""
import os
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
ADDAPP("com.apple.finder", "Finder")
ADDAPP("com.anthropic.claudefordesktop", "Claude")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
ADDAPP("notion.id", "Notion")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Opportunità | Salesforce", {"https://azienda.lightning.force.com/lightning/o/Opportunity"}},
  {"Ricerca", {"https://www.google.com/search?q=x", "https://it.wikipedia.org/wiki/Gatto"}},
})
for i, w in ipairs(CHROME._wins) do w._frame = {x = 10 * i, y = 40 + i, w = 900 + i, h = 700} end
ADDAPP("com.microsoft.rdc.macos", "Windows App")
ADDAPP("com.spotify.client", "Spotify")
DOCK_BADGES = {["com.tinyspeck.slackmacgap"] = "3"}
FRONT = SLACK
NAMES = {["com.microsoft.rdc.macos"] = "Windows App"}
-- "open -g -b <app>": l'app si apre (dietro, senza rubare il primo piano)
OPEN_HOOK = function(args)
  local bid = args[3]
  local a = ADDAPP(bid, NAMES[bid] or bid)
  APPWATCH(a._name, "launch", a)
end
-- Chrome apre una finestra nuova col sito
MAKE_HOOK = function(src)
  local url = src:match('set URL of active tab of w to "([^"]+)"')
  local w = newWindow(CHROME, url and "Opportunità | Salesforce" or "Nuova scheda", url and {url} or {})
  w._frame = {x = 300, y = 90, w = 800, h = 600}
  table.insert(CHROME._wins, w)
  WINFILTER.subs["created"](w)
end
''')
L.execute(carica(base))
L.execute('FLUSH()')

def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def tabs():
    return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name .. " [" .. t.key .. "]" end return table.concat(o, "  |  ") end)()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
def quick_item(prefix):
    run('CLICK("quick")')
    return f'(function() for _, it in ipairs(MENU) do if it.title and it.title:sub(1, {len(prefix)}) == "{prefix}" then return it end end end)()'

fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Avvio:", tabs())

# ---------------------------------------------------------------- creare
print("\n== 1. ⚡︎ → Nuova cartella «Lavoro» (sei su Slack)")
run(f'PROMPT_TEXT = "Lavoro"; {quick_item("Nuova cartella")}.fn()')
check("si apre il riquadro della cartella", ev('Tabby.fedit ~= nil') is True)
check("con già dentro la scheda in cui sei (Slack)", ev('Tabby.fedit.items[1] and Tabby.fedit.items[1].bid') == "com.tinyspeck.slackmacgap")
run(f'CLICK("tab{idx("Notion")}")')
check("clic su Notion → aggiunta", ev('#Tabby.fedit.items') == 2)
L.execute(f'''
local i = {idx("Salesforce")}
local r
for _, tv in ipairs(Tabby.L.tabs) do if tv.i == i then r = tv.r end end
local bf, z = Tabby.bf, Tabby.fZoneAbs
DRAG("tab" .. i, {{x = bf.x + r.x + 20, y = bf.y + r.y + r.h / 2}}, {{x = z.x + z.w / 2, y = z.y + z.h / 2}})
''')
check("Salesforce trascinata dentro → aggiunta come webapp",
      ev('(function() for _, it in ipairs(Tabby.fedit.items) do if it.site == "lightning.force.com" or (it.site or ""):find("force") then return true end end return false end)()') is True)
run(f'CLICK("tab{idx("Windows App")}")')
run(f'CLICK("tab{idx("Notion")}")')
check("la stessa scheda due volte entra una volta sola", ev('#Tabby.fedit.items') == 4)
run('OVERLAY_CLICK("fitem2")')
check("clic su un'icona del riquadro → tolta", ev('#Tabby.fedit.items') == 3)
run(f'CLICK("tab{idx("Notion")}")')
run('KEY("return")')
check("Invio → cartella salvata", ev('#hs.settings.get("tabbar.folders")') == 1 and ev('Tabby.fedit') is None)
check("ricetta: Slack, Salesforce (sito), Windows App, Notion",
      ev('(function() local o = {} for _, it in ipairs(hs.settings.get("tabbar.folders")[1].items) do o[#o+1] = it.site or it.bid end return table.concat(o, ",") end)()')
      == "com.tinyspeck.slackmacgap,azienda.lightning.force.com,com.microsoft.rdc.macos,notion.id")
check("salvata non vuol dire attivata: le schede restano libere", "Slack" in names() and "Notion" in names())
check("nel menu ⚡︎: «Lavoro» con la sua scorciatoia ⌃⌥⇧1", ev(f'{quick_item("Lavoro")}.title') == "Lavoro   ⌃⌥⇧1")

# ---------------------------------------------------------------- caso B
print("\n== 2. Caso B: sei su Claude, attivi Lavoro (Windows App e Salesforce erano state chiuse)")
run('hs.application.get("com.microsoft.rdc.macos"):kill(); APPWATCH("Windows App", "term", nil)')
run('CHROME._wins[1]:close(); Tabby.rebuildTimer:start()')
check("prima: Windows App e Salesforce non ci sono", "Windows App" not in names() and "Salesforce" not in names())
run('FRONT = hs.application.get("com.anthropic.claudefordesktop"); APPWATCH("Claude", "act", FRONT)')
run('KEY("1", {"ctrl","alt","shift"})')
run('Tabby.rebuildTimer:start()')
print("  ", tabs())
check("Windows App aperta dietro (open -g)", any("-g -b com.microsoft.rdc.macos" in o for o in ev('OPENS or {}').values()))
check("Salesforce riaperta come finestra nuova di Chrome", any("lightning.force.com" in m for m in ev('MAKES or {}').values()))
check("resti su Claude", ev('FRONT._name') == "Claude")
check("non sei nella vista cartella", ev('Tabby.viewFolder') is None)
check("la cartella è una scheda sola «Lavoro»", "Lavoro" in names() and "Slack" not in names() and "Notion" not in names())
check("…e le altre schede restano (Claude, Finder, Spotify)", all(n in names() for n in ["Claude", "Finder", "Spotify"]))
check("la scheda-cartella somma le notifiche (Slack 3)",
      ev('(function() for _, e in ipairs(BAR()._els) do if e.text == "3" then return true end end return false end)()') is True)
check("la scheda-cartella ha il tasto ⋯", ev('(function() for _, e in ipairs(BAR()._els) do if e.text == "⋯" then return true end end return false end)()') is True)
check("console: riga di diagnosi", "Tabby · cartella «Lavoro» attivata: 4 voci, 2 da aprire" in ev('table.concat(PRINTS, "\\n")'))

# ---------------------------------------------------------------- vista cartella
print("\n== 3. Clic sulla scheda «Lavoro» → scegli l'app → vista cartella su quell'app")
run(f'CLICK("tab{idx("Lavoro")}")')
check("il clic mostra le app della cartella", ev('Tabby.viewFolder') is None and
      sorted(ev('(function() local o = {} for _, it in ipairs(MENU) do if it.fn and it.title ~= "-" then o[#o+1] = it.title end end return table.concat(o, "|") end)()').split("|"))
      == sorted(["Slack", "Salesforce", "Windows App", "Notion"]))
run('for _, it in ipairs(MENU) do if it.title == "Notion" then it.fn() end end')
check("scelta Notion: la cartella si apre su Notion", ev('FRONT._name') == "Notion")
print("  ", tabs())
check("vista cartella", ev('Tabby.viewFolder') == ev('hs.settings.get("tabbar.folders")[1].id'))
check("solo le sue schede", sorted(names()) == sorted(["Slack", "Salesforce", "Windows App", "Notion"]))
check("sei su una sua app", ev('FRONT._name') in ("Slack", "Google Chrome", "Windows App", "Notion"))
check("testata con il nome della cartella",
      ev('(function() for _, e in ipairs(BAR()._els) do if e.text == "▾  Lavoro" or e.text == "Lavoro" then return true end end return false end)()') is True)
run('KEY("1", {"ctrl","alt"})')
check("⌃⌥1 = la prima scheda della cartella", ev('FRONT._name') == ev('Tabby.tabs[1].app:name()'))
print("\n== 4. Dentro la cartella apri Spotify (non è nella cartella)")
run('FRONT = hs.application.get("com.spotify.client"); APPWATCH("Spotify", "act", FRONT)')
check("resti nella vista cartella, Spotify non compare", ev('Tabby.viewFolder') is not None and "Spotify" not in names())
run('CLICK("fback")')
check("← Tutte le schede: Spotify c'è, Lavoro è una scheda sola", "Spotify" in names() and "Lavoro" in names())

# ---------------------------------------------------------------- caso A
print("\n== 5. Caso A: esci dalla cartella, vai su Slack, riattiva")
L.execute(f'CLICK("fmenu{idx("Lavoro")}")')
run('for _, it in ipairs(MENU) do if it.title and it.title:find("^Esci dalla cartella") then it.fn() end end')
check("Esci dalla cartella: le schede tornano libere", "Slack" in names() and "Lavoro" not in names())
run(f'CLICK("tab{idx("Slack")}")')
run('KEY("1", {"ctrl","alt","shift"})')
check("entri subito nella vista cartella", ev('Tabby.viewFolder') is not None)
check("resti su Slack", ev('FRONT._name') == "Slack")
run('KEY("1", {"ctrl","alt","shift"})')
check("⌃⌥⇧1 di nuovo → torni a tutte le schede", ev('Tabby.viewFolder') is None and "Lavoro" in names())
check("scorciatoia anche dalla riserva di sistema", ev('HOTKEYS["1"] ~= nil') is True)

# ---------------------------------------------------------------- vista cartelle spenta
print("\n== 6. ⚙︎ → Comportamento → Vista cartelle spenta")
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Vista cartelle") then it.fn() end end end end')
check("tutte le schede sciolte", "Lavoro" not in names() and "Slack" in names() and "Notion" in names())
run('KEY("1", {"ctrl","alt","shift"})')
check("attivare = solo aprire, niente scheda-cartella", "Lavoro" not in names())
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Vista cartelle") then it.fn() end end end end')

# ---------------------------------------------------------------- chiudi cartella
print("\n== 7. Chiudi cartella")
run('KEY("1", {"ctrl","alt","shift"})')
check("sei su una sua app: entri nella vista cartella (caso A)", ev('Tabby.viewFolder') is not None)
L.execute('CLICK("fhead")')   # il menu della cartella dal suo nome, in cima
check("il menu dal nome della cartella offre «Torna a tutte le schede»", ev('MENU[1].title') == "Torna a tutte le schede")
run('for _, it in ipairs(MENU) do if it.title and it.title:find("^Chiudi cartella") then it.fn() end end; Tabby.rebuildTimer:start()')
print("  ", tabs())
check("Slack, Notion e Windows App chiuse", not any(n in names() for n in ["Slack", "Notion", "Windows App"]))
check("la finestra Salesforce chiusa, ma Chrome resta (Ricerca)", "Salesforce" not in names() and ev('hs.application.get("com.google.Chrome")._running') is True)
check("le altre app restano", all(n in names() for n in ["Claude", "Finder", "Spotify"]))
check("la cartella resta salvata", ev('#hs.settings.get("tabbar.folders")') == 1)

# ---------------------------------------------------------------- modificare
print("\n== 8. Modificare e una voce in una sola cartella")
run(f'{quick_item("Modifica le cartelle")}.menu[1].menu[1].fn()')
check("Modifica le schede: il riquadro ha le 4 voci", ev('#Tabby.fedit.items') == 4)
run('KEY("escape")')
check("Esc: niente cambia", ev('Tabby.fedit') is None and ev('#hs.settings.get("tabbar.folders")[1].items') == 4)
run(f'FRONT = hs.application.get("com.spotify.client"); APPWATCH("Spotify", "act", FRONT)')
run(f'PROMPT_TEXT = "Studio"; {quick_item("Nuova cartella")}.fn()')
run(f'CLICK("tab{idx("Claude")}")')
run('KEY("return")')
check("nuova cartella «Studio» con Spotify e Claude, scorciatoia ⌃⌥⇧2", ev(f'{quick_item("Studio")}.title') == "Studio   ⌃⌥⇧2")
L.execute('ADDAPP("com.tinyspeck.slackmacgap", "Slack"); Tabby.rebuildTimer:start(); FLUSH()')
run(f'FRONT = hs.application.get("com.spotify.client"); PROMPT_TEXT = "Musica"; {quick_item("Nuova cartella")}.fn()')
run('KEY("return")')
check("Spotify passa a «Musica» e lascia «Studio»",
      ev('(function() for _, f in ipairs(hs.settings.get("tabbar.folders")) do if f.name == "Studio" then return #f.items end end end)()') == 1)
run('PROMPT_TEXT = false')
run(f'{quick_item("Nuova cartella")}.fn()')
check("Annulla sul nome: nessuna cartella nuova", ev('Tabby.fedit') is None and ev('#hs.settings.get("tabbar.folders")') == 3)

# ---------------------------------------------------------------- disegno in tutte le posizioni
print("\n== 9. Tutte le posizioni, anche nella vista cartella")
run('FRONT = hs.application.get("com.anthropic.claudefordesktop"); KEY("2", {"ctrl","alt","shift"})')
for i, pos in [(2, "bottom"), (3, "left"), (4, "right"), (1, "top")]:
    run(f'CLICK("settings"); MENU[1].menu[{i}].fn()')
    check(f"posizione {pos}: disegnata, vista cartella attiva", ev('Tabby.viewFolder') is not None and ev('#Tabby.L.tabs') >= 1)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
