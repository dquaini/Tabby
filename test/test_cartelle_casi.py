"""Cartelle: i casi della mappa decisa con Daniele il 22/10/2026.
A altra finestra dello stesso browser → fuori · B finestra legata alla voce anche se ci
navighi · D ricetta fissa: le schede chiuse si riaprono nella stessa finestra · F due
finestre di Gmail → ne entra una · G il Finder: solo la finestra scelta · "Aggiorna con
le schede di adesso"."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mock = open(base + '/test/mock_hs.lua').read()
# DuckDuckGo letto con l'Accessibilità (come nel test di DuckDuckGo)
mock = mock.replace("axuielement = {applicationElement = function()", '''axuielement = {
  windowElement = function(w)
    local function el(role, attrs, kids)
      return {attributeValue = function(_, k)
        if k == "AXRole" then return role end
        if k == "AXChildren" then return kids or {} end
        return attrs and attrs[k]
      end}
    end
    local tabs = {}
    for i = 1, (w._ntabs or 1) do tabs[i] = el("AXButton", {AXRoleDescription = "scheda"}) end
    return el("AXWindow", nil, {el("AXGroup", nil, tabs), el("AXWebArea", {AXURL = {url = w._page}}, {})})
  end,
  applicationElement = function()''')
L = l.LuaRuntime()
L.execute(mock)
L.execute('''
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
FINDER = ADDAPP("com.apple.finder", "Finder"); FINDER._wins = {}
PROGETTI = newWindow(FINDER, "Progetti"); DOWNLOAD = newWindow(FINDER, "Download")
FINDER._wins = {PROGETTI, DOWNLOAD}
CLAUDE = ADDAPP("com.anthropic.claudefordesktop", "Claude")
DDG = ADDAPP("com.duckduckgo.macos.browser", "DuckDuckGo"); DDG._wins = {}
SUPA = newWindow(DDG, "Supabase | Dashboard"); SUPA._page = "https://supabase.com/dashboard/project/x"; SUPA._ntabs = 2
WEBEX = newWindow(DDG, "Riunione · Webex"); WEBEX._page = "https://azienda.webex.com/meet/x"; WEBEX._ntabs = 2
DDG._wins = {SUPA, WEBEX}
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Posta in arrivo - Gmail - Google Chrome", {"https://mail.google.com/mail/u/0/"}},
  {"Posta (lavoro) - Gmail - Google Chrome", {"https://mail.google.com/mail/u/1/"}},
  {"Ricerca - Google Chrome", {"https://www.notion.so/a/Doc-1", "https://docs.google.com/document/d/1"}},
})
G1, G2, RIC = CHROME._wins[1], CHROME._wins[2], CHROME._wins[3]
G1._asName = "Posta in arrivo - Gmail"; G2._asName = "Posta (lavoro) - Gmail"; RIC._asName = "Ricerca"
for i, w in ipairs(CHROME._wins) do w._frame = {x = 0, y = 38, w = 1440, h = 862} end
FRONT = FINDER; FINDER._focused = PROGETTI
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def keys(): return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.key end return table.concat(o, ",") end)()')
def idx_key(k): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.key == "{k}" then return i end end end)()')
def idx_win(var): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.win == {var} then return i end end end)()')
def in_folder(var): return ev(f'(function() for _, t in ipairs(Tabby.allTabs) do if t.win == {var} then return Tabby.tabFolder[t.key] ~= nil end end return false end)()')
def quick_item(prefix):
    run('CLICK("quick")')
    return f'(function() for _, it in ipairs(MENU) do if it.title and it.title:sub(1, {len(prefix)}) == "{prefix}" then return it end end end)()'
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Schede:", names())
DDG_SHOWN = 'DDG._hidden = false'
run(DDG_SHOWN)
print("== Creo «Lavoro»: finestra Progetti del Finder, Claude, DuckDuckGo Supabase, Gmail, Chrome Ricerca")
run(f'PROMPT_TEXT = "Lavoro"; {quick_item("Nuova cartella")}.fn()')   # parte da Progetti (scheda attuale)
for var in ["CLAUDE._wins[1]", "SUPA", "G1", "RIC"]:
    run(f'CLICK("tab{idx_win(var)}")')
run('KEY("return")')
desc = ev('(function() local o = {} for _, it in ipairs(hs.settings.get("tabbar.folders")[1].items) do o[#o+1] = (it.win and "finestra " or it.pages and "pagine " or it.site and "webapp " or "app ") .. tostring(it.name) end return table.concat(o, " ; ") end)()')
print("   ricetta:", desc)
check("5 voci: Finder «Progetti» come finestra, Claude app, DuckDuckGo Supabase come finestra, Gmail webapp, Ricerca con pagine",
      desc.count(" ; ") == 4 and "finestra Progetti" in desc and "finestra DuckDuckGo · Supabase" in desc and "pagine Ricerca" in desc)

print("\\n== Attivo «Lavoro» (sono sul Finder, finestra Download)")
run('FINDER._focused = DOWNLOAD; KEY("1", {"ctrl","alt","shift"})')
run('Tabby.rebuildTimer:start()')
print("   schede:", names())
check("A · la finestra Webex di DuckDuckGo resta FUORI", in_folder("WEBEX") is False)
check("    e quella di Supabase entra", in_folder("SUPA") is True)
check("G · Finder: entra solo «Progetti», «Download» resta fuori", in_folder("PROGETTI") is True and in_folder("DOWNLOAD") is False)
check("F · Gmail: entra una sola finestra (la prima), l'altra resta fuori", in_folder("G1") is True and in_folder("G2") is False)
check("nessuna finestra aperta in più (c'era tutto)", ev('MAKES == nil and OPENS == nil') is True)

print("\\n== B · Navigo nella finestra Ricerca (altri siti): resta nella cartella")
run('RIC._urls = {"https://www.youtube.com/watch", "https://www.wikipedia.org/x"}; Tabby.rebuildTimer:start()')
run('Tabby.rebuildTimer:start()')
check("Ricerca è ancora nella cartella", in_folder("RIC") is True)

print("\\n== D · Ricetta fissa: chiudo la scheda di Google Docs e riattivo")
run('RIC._urls = {"https://www.notion.so/a/Doc-2"}; Tabby.rebuildTimer:start()')
run('Tabby.rebuildTimer:start()')
L.execute(f'CLICK("fmenu{idx_key("f:1")}")')
run('for _, it in ipairs(MENU) do if it.title and it.title:find("^Esci dalla cartella") then it.fn() end end')
run('MAKES = nil; KEY("1", {"ctrl","alt","shift"})')
mk = ev('MAKES and table.concat(MAKES, " ") or ""')
check("Tabby riapre Google Docs dentro la stessa finestra (window id)", f"window id {ev('RIC._id')}" in mk and "docs.google.com/document/d/1" in mk)
check("e non riapre Notion (c'è già una scheda di Notion)", "notion.so" not in mk)

print("\\n== «Aggiorna con le schede di adesso»")
L.execute(f'CLICK("fmenu{idx_key("f:1")}")')
run('for _, it in ipairs(MENU) do if it.title == "Aggiorna con le schede di adesso" then it.fn() end end')
pages = ev('(function() for _, it in ipairs(hs.settings.get("tabbar.folders")[1].items) do if it.pages then return table.concat(it.pages, " ") end end return "" end)()')
check("la ricetta di Ricerca ora ha solo la pagina di adesso (Notion Doc-2)", pages == "https://www.notion.so/a/Doc-2")
check("Ricerca resta nella cartella dopo l'aggiornamento", in_folder("RIC") is True)

print("\\n== I legami restano dopo un ricaricamento di Tabby")
check("salvati", ev('next(hs.settings.get("tabbar.itemWins") or {}) ~= nil') is True)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
