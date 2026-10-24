"""v9.55 (24/10/2026, Daniele): la Concentrazione. ⚡︎ → «Concentrazione…»: sfondo scuro
(la barra no), in centro minuti e schede; le schede si scelgono cliccandole nella barra
(diventano gialle). Inizia: Non disturbare, il tempo al posto della batteria, le altre app
nascoste e le altre finestre ridotte, nella barra solo le schede scelte; un'altra app →
Tabby chiede. Alla fine: suono, cosa è arrivato, Riapri tutto / Altri 10 minuti / Resta così."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
NOTION = ADDAPP("notion.id", "Notion")
NOTE = ADDAPP("com.apple.Notes", "Note")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Contratto - Google Docs - Google Chrome", {"https://docs.google.com/document/d/1"}},
  {"Calcio | Sofascore - Google Chrome", {"https://www.sofascore.com/"}},
})
CHROME._wins[1]._asName = "Contratto - Google Docs"; CHROME._wins[2]._asName = "Calcio | Sofascore"
DOCS, SOFA = CHROME._wins[1], CHROME._wins[2]
SHORTCUTS_LIST = "Concentrazione on\\nConcentrazione off\\nAltro"
FRONT = NOTION
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name:find("{name}", 1, true) then return i end end end)()')
def names(): return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do table.insert(o, t.name) end return table.concat(o, ",") end)()')
def js(): return ev('table.concat(FOCUSVIEW and FOCUSVIEW._js or {}, " | ")')
def els_with(pred_lua): return ev('(function() for _, e in ipairs(BAR()._els) do if ' + pred_lua + ' then return true end end return false end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

run(f'CLICK("tab{idx("Notion")}")')
print("schede:", names())

print("== ⚡︎ → Concentrazione…")
run('CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "Concentrazione…" then it.fn() end end')
check("si apre la finestra in centro", ev('FOCUSVIEW ~= nil and FOCUSVIEW._shown') is True and ev('Tabby.fsel ~= nil') is True)
check("…sopra uno sfondo scuro (che prende i clic)", ev('Tabby.focusDimC ~= nil and Tabby.focusDimC._shown') is True)
check("chiede i minuti (25 la prima volta)", 'minutes:25' in js())
check("la scheda in cui sei è già gialla (Notion)", ev(f'Tabby.fsel.keys["notion.id"]') is True and 'count:1' in js())
check("Non disturbare: i comandi rapidi ci sono", 'dnd:true' in js())
check("nella barra Notion è gialla", els_with('e.fillColor and e.fillColor.hex == "#F4C443"'))

run(f'CLICK("tab{idx("Google Docs")}")')
check("clic su «Contratto» nella barra: diventa gialla, non ci si sposta", ev('Tabby.fsel.keys[Tabby.tabs[' + str(idx("Google Docs")) + '].key]') is True and ev('FRONT == NOTION') is True)
run(f'CLICK("tab{idx("Note")}")'); run(f'CLICK("close{idx("Note")}")')
check("clic due volte (anche sulla ✕): tolta, e la ✕ non chiude niente", ev('NOTE._running') is True and 'count:2' in js().split(' | ')[-1])
run('FOCUS_CB({body = {minutes = 50}})')
check("50 minuti", ev('Tabby.fsel.minutes') == 50 and 'minutes:50' in js().split(' | ')[-1])

print("== Invio: inizia")
L.execute('SLACK._hidden = false; SOFA._min = false')
run('KEY("return")')
check("la finestra si chiude", ev('FOCUSVIEW._shown') is False and ev('Tabby.focusDimC._shown') is False and ev('Tabby.fsel') is None)
check("Non disturbare acceso", ev('SHORTCUTS_RUN and SHORTCUTS_RUN[1]') == "Concentrazione on")
check("le altre app sono nascoste (non chiuse)", ev('SLACK._hidden') is True and ev('SLACK._running') is True)
check("l'altra finestra di Chrome (Sofascore) è ridotta, il Contratto no", ev('SOFA._min') is True and ev('DOCS._min') is False)
print("schede:", names())
check("nella barra solo le schede scelte", names() in ("Notion,Google Docs", "Google Docs,Notion"))
check("al posto della batteria il tempo: «50 min»", els_with('e.text == "50 min"') and els_with('e.id == "focustimer"'))
check("…e si ricorda (anche dopo un riavvio)", ev('hs.settings.get("tabbar.focus").endAt') == 1000 + 50 * 60)

print("== Il tempo passa")
run('CLOCK = 1000 + 49 * 60 + 15; Tabby.focusTick.fn()')
check("nell'ultimo minuto si vedono i secondi (0:45)", els_with('e.text == "0:45"'))
run('CLOCK = 1000 + 20 * 60; Tabby.focusTick.fn()')

print("== Un'altra app vuole venire davanti")
run('SLACK._hidden = false; FRONT = SLACK; APPWATCH(nil, "act", SLACK)')
check("Slack torna via", ev('SLACK._hidden') is True)
check("Tabby chiede: «Aprire Slack?» con quanto manca", ev('FOCUSVIEW._shown') is True and 'ask({name:"Slack",left:"30 min"' in js())
run('KEY("return")')
check("Invio = resto concentrato: Slack resta fuori", ev('FOCUSVIEW._shown') is False and ev('SLACK._hidden') is True and "Slack" not in names())
run('SLACK._hidden = false; FRONT = SLACK; APPWATCH(nil, "act", SLACK)')
run('FOCUS_CB({body = {ask = "open"}})')
check("«Aprila lo stesso»: Slack si apre ed entra nella barra", ev('FRONT == SLACK') is True and "Slack" in names())
check("le app non scelte ma «Lampi» si aprono senza chiedere", ev('Tabby._env.focusBlocks(FINDER)') is False)

print("== Clic sul tempo: +5 minuti")
run('CLICK("focustimer"); for _, it in ipairs(MENU) do if it.title == "+5 minuti" then it.fn() end end')
check("mancano 35 minuti", ev('Tabby.focus.endAt') == 1000 + 55 * 60)

print("== La fine")
L.execute('Tabby.badges["com.apple.Notes"] = "3"')
run('CLOCK = 1000 + 55 * 60; Tabby.focusTick.fn()')
check("un suono", (ev('SOUNDS') or 0) >= 1)
check("«Fatto! 55 minuti» e cosa è arrivato (Note 3)", ev('FOCUSVIEW._shown') is True and 'finish({minutes:55' in js() and 'Note 3' in js())
run('FOCUS_CB({body = {finish = "more"}})')
check("«Altri 10 minuti»: si riparte", ev('Tabby.focus.endAt') == 1000 + 65 * 60 and ev('Tabby.focus.ended') is None and ev('FOCUSVIEW._shown') is False)
run('CLOCK = 1000 + 65 * 60; Tabby.focusTick.fn()')
run('FOCUS_CB({body = {finish = "stay"}})')
check("«Resta così»: senza tempo (∞), sempre solo le schede scelte", els_with('e.text == "∞"') and "Note" not in names())
run('CLICK("focustimer"); for _, it in ipairs(MENU) do if it.title == "Termina adesso" then it.fn() end end')
run('KEY("return")')
check("Termina → Riapri tutto: tornano tutte le schede", "Note" in names() and "Sofascore" in names() and ev('Tabby.focus') is None)
check("Non disturbare spento", ev('SHORTCUTS_RUN[#SHORTCUTS_RUN]') == "Concentrazione off")
check("torna la batteria", not els_with('e.id == "focustimer"'))
check("e non si ricorda più", ev('hs.settings.get("tabbar.focus")') is None)

print("== La volta dopo ricorda minuti e schede")
run('CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "Concentrazione…" then it.fn() end end')
check("di nuovo 50 minuti, Contratto già gialla", 'minutes:50' in js().split(' | ')[-1] and ev('Tabby.fsel.keys[Tabby.tabs[' + str(idx("Google Docs")) + '].key]') is True)
run('KEY("escape")')
check("Esc: annulla, niente concentrazione", ev('Tabby.fsel') is None and ev('Tabby.focus') is None and ev('FOCUSVIEW._shown') is False)

print("== Senza schede scelte non parte")
run('CLICK("quick"); for _, it in ipairs(MENU) do if it.title == "Concentrazione…" then it.fn() end end')
L.execute('Tabby.fsel.keys = {}')
run('FOCUS_CB({body = {start = true}})')
check("avvisa (la casella trema)", ev('Tabby.focus') is None and 'hint()' in js())
run('FOCUS_CB({body = {cancel = true}})')

print("== Riavvio a metà: continua")
L.execute('''hs.settings.set("tabbar.focus", {startAt = CLOCK, endAt = CLOCK + 600, minutes = 10,
  tabs = {"notion.id"}, keys = {"notion.id"}, bids = {"notion.id"}, excluded = {"com.apple.Notes"}, badges0 = {}})''')
run('Tabby._env.restoreFocus(); Tabby._env.rebuildTabs(); Tabby._env.draw()')
check("dopo il riavvio: di nuovo in concentrazione, Note fuori dalla barra", ev('Tabby.focus ~= nil') is True and "Note" not in names() and els_with('e.text == "10 min"'))

print("== Col cerchio sulla scrivania: l'anello giallo")
L.execute('ORBVIEW = nil')
run('Tabby._env.showOrb(true)')
check("la sfera riceve il tempo (anello)", any('setRing(' in j for j in list(ev('ORBVIEW._js').values())) if ev('ORBVIEW') else False)

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
