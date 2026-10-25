"""v9.57 (25/10/2026, Daniele): «Cerca nelle finestre» (⌃⌥F), un ⌘F su tutte le finestre
aperte. Tabby legge il testo delle finestre con l'Accessibilità (a piccoli passi), la barra
mostra le finestre che contengono le parole con un pezzetto di testo; Invio = quella
finestra davanti e ⌘F con la parola già scritta."""
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
NOTE = ADDAPP("com.apple.Notes", "Note")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Contratto - Google Docs - Google Chrome", {"https://docs.google.com/document/d/1"}},
  {"Calcio | Sofascore - Google Chrome", {"https://www.sofascore.com/"}},
})
CHROME._wins[1]._asName = "Contratto - Google Docs"; CHROME._wins[2]._asName = "Calcio | Sofascore"
DOCS, SOFA = CHROME._wins[1], CHROME._wins[2]
DOCS._texts = {"Contratto di locazione", "Il canone mensile è di 900 euro, da versare entro il giorno 5.", "Firmato: Mario Rossi"}
SOFA._texts = {"Serie A", "Inter - Milan 2-1", "Classifica aggiornata"}
NOTE._wins = {newWindow(NOTE, "Spesa e cose da fare")}
NOTE._wins[1]._texts = {"Comprare latte", "Chiamare Marco per il preventivo", "Perché il canone è aumentato?"}
SLACK._wins = {newWindow(SLACK, "Slack | generale")}
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name:find("{name}", 1, true) then return i end end end)()')
def last(): return ev('SEARCHVIEW and SEARCHVIEW._js[#SEARCHVIEW._js] or ""')
def read_all(): L.execute('for _ = 1, 40 do if Tabby.textTimer and Tabby.textTimer:running() then Tabby.textTimer.fn() end end; FLUSH()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

run(f'CLICK("tab{idx("Note")}")'); run(f'CLICK("tab{idx("Google Docs")}")'); run(f'CLICK("tab{idx("Slack")}")')

print("== Tabby legge il testo delle finestre che lasci")
read_all()
check("letto il testo di Note e del Contratto (lasciate)", ev('Tabby.textIdx[NOTE._wins[1]:id()] ~= nil') is True and ev('Tabby.textIdx[DOCS:id()] ~= nil') is True)

print("== ⌃⌥F: la barra di ricerca")
run('KEY("f", {"ctrl","alt"})')
check("si apre, senza prendere la tastiera all'app", ev('Tabby.searchOpen') is True and ev('SEARCHVIEW._shown') is True and ev('FRONT == SLACK') is True)
check("a barra vuota: le finestre usate di recente", 'render({q:"",' in last() and 'Contratto' in last())
read_all()
check("aprendo, legge anche le finestre non lette (Sofascore)", ev('Tabby.textIdx[SOFA:id()] ~= nil') is True)

TYPE_ = 'TYPE("canone")'
run(TYPE_)
print("  ", last()[:300])
check("«canone»: trovato nel Contratto e nelle Note", 'q:"canone"' in last() and 'Contratto' in last() and 'Spesa' in last())
check("…con il pezzetto di testo intorno alla parola", '"canone"' in last() and 'mensile è di 900 euro' in last())
check("Sofascore no", 'Sofascore' not in last())
run('TYPE(" 900")')
check("più parole: tutte devono esserci (solo il Contratto)", 'Contratto' in last() and 'Spesa' not in last())
run('KEY("delete"); KEY("delete"); KEY("delete"); KEY("delete")')
check("Cancella toglie le lettere", 'q:"canone"' in last())
run('KEY("delete", {"cmd"}); TYPE("perche")')
check("senza accenti trova anche «Perché»", 'Spesa' in last() and 'Perché' in last())
run('KEY("delete", {"cmd"}); TYPE("inter")')
check("trova Sofascore (Inter - Milan)", 'Sofascore' in last())
run('KEY("delete", {"cmd"}); TYPE("zzqq")')
check("niente: lo dice", 'items:[]' in last())

print("== Invio: la finestra davanti e ⌘F con la parola")
run('KEY("delete", {"cmd"}); TYPE("canone")')
L.execute('KEYSTROKES = {}; TYPED = nil')
run('KEY("return")')
check("la ricerca si chiude", ev('Tabby.searchOpen') is False and ev('SEARCHVIEW._shown') is False)
check("davanti la finestra del Contratto", ev('FRONT == CHROME and CHROME._focused == DOCS') is True)
check("⌘F e la parola scritta", ev('KEYSTROKES[1]') == "cmd+f" and ev('TYPED') == "canone")

print("== Frecce, clic, Esc")
run('KEY("f", {"ctrl","alt"})'); run('TYPE("canone"); KEY("down")')
check("freccia giù: seleziona il secondo", 'sel:2' in last())
run('SEARCH_CB({body = {choose = 2}})')
check("clic sul secondo (Note): davanti", ev('FRONT == NOTE') is True)
run('KEY("f", {"ctrl","alt"})'); run('KEY("escape")')
check("Esc chiude", ev('Tabby.searchOpen') is False)
run('KEY("f", {"ctrl","alt"})'); run('KEY("f", {"ctrl","alt"})')
check("⌃⌥F di nuovo chiude", ev('Tabby.searchOpen') is False)

print("== Trovato solo nel titolo: niente ⌘F")
run('KEY("f", {"ctrl","alt"})'); run('TYPE("generale")')
L.execute('KEYSTROKES = {}')
run('KEY("return")')
check("Slack davanti, senza ⌘F", ev('FRONT == SLACK') is True and ev('#KEYSTROKES') == 0)

print("== Anche il Memo")
L.execute('Tabby._env.readMemo = function() return "idee: canone da rinegoziare" end')
run('KEY("f", {"ctrl","alt"})'); run('TYPE("rinegoziare")')
check("il Memo tra i risultati", 'title:"Memo"' in last())
run('KEY("escape")')

print("== Incolla (⌘V)")
L.execute('CLIPBOARD = "Mario Rossi"')
run('KEY("f", {"ctrl","alt"})'); run('KEY("v", {"cmd"})')
check("incolla il testo copiato e cerca", 'q:"Mario Rossi"' in last() and 'Contratto' in last())
run('KEY("escape")')

print("== Mentre è aperta, i tasti non arrivano all'app")
run('KEY("f", {"ctrl","alt"})')
check("una lettera è assorbita dalla ricerca", ev('KEY("x")') is True)
run('KEY("escape")')

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
