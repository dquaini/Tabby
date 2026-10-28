"""v9.60 (feedback di Daniele del 28/10/2026):
1. riquadro della cartella con tante voci: tutte visibili (griglia che va a capo), ognuna con la ✕
2. tasto destro sulla scheda-cartella → il menu della cartella (Rinomina…)
3. diario su file di cosa chiude Tabby
4. lo stesso sito in due finestre → avviso (Vai a quella / Chiudi questa / Lascia)
5. aprendo una cartella con tante finestre: un velo con le icone che si accendono, poi sfuma"""
import os, tempfile
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Posta in arrivo - Gmail", {"https://mail.google.com/mail/u/0/"}},
  {"Ricerca", {"https://www.google.com/search?q=x", "https://it.wikipedia.org/wiki/Gatto"}},
})
GMAIL = CHROME._wins[1]
FRONT = SLACK
-- "open -g -b <app>": l'app si apre con una finestra
OPEN_HOOK = function(args)
  local bid = args[3]
  local a = ADDAPP(bid, bid)
  a._wins = {newWindow(a, bid)}
  APPWATCH(a._name, "launch", a)
end
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name:find("{name}", 1, true) then return i end end end)()')
def overlay(): return ev('Tabby.fOverlay')
def count_els(pred): return ev('(function() local n = 0 for _, e in ipairs(Tabby.fOverlay._els) do if ' + pred + ' then n = n + 1 end end return n end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== 1. Riquadro della cartella con 9 voci")
L.execute('''Tabby._env.T.fedit = nil
local items = {}
for i = 1, 9 do items[i] = {bid = "app.numero" .. i, name = "App " .. i} end
Tabby._env.icon = function() return {size = function() return {w = 32, h = 32} end} end
Tabby._env.T.fedit = {name = "Tante", items = items, hover = false}
Tabby._env.FD.drawFolderEdit()''')
check("si vedono tutte e 9 le icone (nessun «+N»)", count_els('e.type == "image"') == 9 and count_els('e.text and e.text:find("^%+%d")') == 0)
check("ognuna con la sua ✕ per toglierla", count_els('e.id and e.id:find("^fitem")') == 9)
check("…e i loro nomi", count_els('e.text and e.text:find("^App %d")') == 9)
check("nel titolo quante sono", count_els('e.text and e.text:find("9 voci")') == 1)
ys = sorted(set(ev('(function() local o = {} for _, e in ipairs(Tabby.fOverlay._els) do if e.type == "image" then o[#o+1] = e.frame.y end end return table.concat(o, ",") end)()').split(",")))
check("la griglia va a capo (due righe)", len(ys) == 2)
h9 = ev('Tabby.fOverlay._els[2].frame.h')
L.execute('table.remove(Tabby._env.T.fedit.items); table.remove(Tabby._env.T.fedit.items); table.remove(Tabby._env.T.fedit.items); Tabby._env.FD.drawFolderEdit()')
check("con meno voci il riquadro è più basso", ev('Tabby.fOverlay._els[2].frame.h') < h9)
run('OVERLAY_CLICK("fitem2")')
check("clic sulla ✕ della seconda: tolta", ev('#Tabby.fedit.items') == 5 and ev('Tabby.fedit.items[2].name') == "App 3")
run('Tabby._env.FD.cancelFolderEdit()')

print("== 2. Tasto destro sulla scheda-cartella")
L.execute('''Tabby._env.S.folders = {{id = 1, name = "Posta", items = {{site = "mail.google.com", bid = "com.google.Chrome", name = "Gmail"}, {bid = "com.tinyspeck.slackmacgap", name = "Slack"}}}}
Tabby._env.S.folderSeq = 1''')
run('Tabby._env.FD.activateFolder(Tabby._env.S.folders[1])')
run('Tabby._env.FD.leaveFolderView()')
run('CLICK("tab' + str(idx("Ricerca")) + '")')
fi = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.folder then return i end end end)()')
check("c'è la scheda-cartella «Posta»", fi is not None)
L.execute('MENU = nil')
run(f'Tabby._env.openTabContextMenu({fi}, {{x = 10, y = 10}})')
check("tasto destro: il menu della cartella, con «Rinomina…»", ev('(function() for _, it in ipairs(MENU or {}) do if it.title == "Rinomina…" then return true end end return false end)()') is True)
L.execute('PROMPT_TEXT = "Posta e chat"')
run('for _, it in ipairs(MENU) do if it.title == "Rinomina…" then it.fn() end end')
check("Rinomina → la cartella si chiama «Posta e chat»", ev('Tabby._env.S.folders[1].name') == "Posta e chat")
run('Tabby._env.FD.releaseFolder(Tabby._env.S.folders[1])')

print("== 3. Il diario su file")
tmp = tempfile.mktemp(suffix=".log")
L.execute(f'NO_DIARY = false; Tabby._env.DIARY_FILE = [[{tmp}]]')
L.execute('Tabby._env.diaryWrite("Tabby · prova del diario"); Tabby._env.diaryWrite("altro testo, non di Tabby")')
L.execute('NO_DIARY = true')
txt = open(tmp).read() if os.path.exists(tmp) else ""
check("le righe «Tabby ·» finiscono nel file, con data e ora", "Tabby · prova del diario" in txt and "altro testo" not in txt and txt[:2] == "20")
check("il diario sa delle finestre chiuse (✕, ⌃⌥W, chiusa da sola)",
      'finestra chiusa' in open(base + '/tabby/osservatori.lua').read() and 'Chiudi finestra «' in open(base + '/tabby/menu.lua').read())

print("== 4. Lo stesso sito in due finestre")
check("all'avvio niente avviso", ev('NOTICEVIEW == nil or not NOTICEVIEW._shown') is True)
L.execute('CLOCK = (CLOCK or 1000) + 60')   # un minuto dopo l'avvio
L.execute('HIDE = Tabby._env.hideNotice; Tabby._env.hideNotice = function() end')   # (nel simulatore i timer partono subito)
run('''local w = newWindow(CHROME, "Gmail", {"https://mail.google.com/mail/u/0/#inbox"}); w._frame = {x = 300, y = 90, w = 800, h = 600}
GMAIL2 = w; table.insert(CHROME._wins, w); WINFILTER.subs["created"](w); Tabby.rebuildTimer:start()''')
run('Tabby._env.refreshBrowsers(); Tabby._env.rebuildTabs()')
js = ev('NOTICEVIEW and table.concat(NOTICEVIEW._js, " | ") or ""')
print("  ", js[:160])
check("avviso: «Gmail è già aperto in un'altra finestra»", ev('NOTICEVIEW ~= nil and NOTICEVIEW._shown') is True and "Gmail è già aperto in un'altra finestra" in js)
check("con «Lascia», «Vai a quella», «Chiudi questa»", "Lascia" in js and "Vai a quella" in js and "Chiudi questa" in js)
run('Tabby._env.rebuildTabs()')
check("una volta sola", js.count("show(") == ev('NOTICEVIEW and table.concat(NOTICEVIEW._js, " | ") or ""').count("show("))
L.execute('Tabby._env.hideNotice = HIDE')
run('NOTICE_CB({body = {choose = "close"}})')
check("«Chiudi questa»: la finestra nuova si chiude, la prima resta", ev('(function() for _, w in ipairs(CHROME._wins) do if w == GMAIL2 then return false end end return true end)()') is True
      and ev('(function() for _, w in ipairs(CHROME._wins) do if w == GMAIL then return true end end return false end)()') is True)
check("…e l'avviso sparisce", ev('NOTICEVIEW._shown') is False)

print("== 5. Aprire una cartella con tante finestre")
L.execute('''Tabby._env.S.folders = {{id = 2, name = "Lavoro", items = {
  {bid = "com.uno.app", name = "Uno"}, {bid = "com.due.app", name = "Due"}, {bid = "com.tre.app", name = "Tre"}}}}
-- le app arrivano "dopo": l'apertura le mette in coda
QUEUED = {}
OPEN_HOOK = function(args) table.insert(QUEUED, args[3]) end''')
run('Tabby._env.FD.activateFolder(Tabby._env.S.folders[1])')
check("compare il velo «Apro «Lavoro»» con le 3 icone spente", ev('Tabby.openVeil ~= nil and Tabby.openVeil._shown') is True
      and ev('(function() for _, e in ipairs(Tabby.openVeil._els) do if e.text and e.text:find("Apro «Lavoro»") then return true end end return false end)()') is True
      and ev('(function() for _, e in ipairs(Tabby.openVeil._els) do if e.text == "0 di 3" then return true end end return false end)()') is True)
def fade(): L.execute('for _ = 1, 12 do if Tabby.openFadeT then Tabby.openFadeT.fn() end end')
def arrive(i):
    run(f'local b = QUEUED[{i}]; local a = ADDAPP(b, b); a._wins = {{newWindow(a, b)}}; APPWATCH(a._name, "launch", a); Tabby._env.rebuildTabs(); Tabby.openTimer.fn()')
arrive(1)
check("arriva la prima: «1 di 3», la sua icona si accende (✓)", ev('(function() for _, e in ipairs(Tabby.openVeil._els) do if e.text == "1 di 3" then return true end end return false end)()') is True
      and ev('(function() for _, e in ipairs(Tabby.openVeil._els) do if e.text == "✓" then return true end end return false end)()') is True)
arrive(2); arrive(3); fade()
check("arrivate tutte: il velo sfuma e sparisce", ev('Tabby.openVeil._shown') is False and ev('Tabby.openTimer') is None)
L.execute('''Tabby._env.S.folders[1].items = {{bid = "com.quattro.app", name = "Quattro"}, {bid = "com.cinque.app", name = "Cinque"}}''')
run('Tabby._env.FD.activateFolder(Tabby._env.S.folders[1])')
run('CLOCK = (CLOCK or 1000) + 9; Tabby.openTimer.fn()'); fade()
check("se un'app non arriva, dopo 6 secondi il velo si toglie comunque", ev('Tabby.openVeil._shown') is False)
run('Tabby._env.FD.activateFolder(Tabby._env.S.folders[1])')
check("(di nuovo il velo)", ev('Tabby.openVeil._shown') is True)
run('Tabby.openVeil._cb(Tabby.openVeil, "mouseUp", "x")'); fade()
check("un clic sul velo lo toglie subito", ev('Tabby.openVeil._shown') is False and ev('Tabby.openTimer') is None)
L.execute('Tabby._env.S.folders[1].items = {{bid = "com.sei.app", name = "Sei"}}')
run('Tabby._env.FD.activateFolder(Tabby._env.S.folders[1])')
check("una sola app da aprire: niente velo", ev('Tabby.openVeil._shown') is False)

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
