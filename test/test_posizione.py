"""v9.49 (feedback del 23/10/2026): cambiando la posizione di Tabby (in alto, in basso, a
sinistra, a destra) la finestra aperta si rimette a misura nello spazio nuovo, anche se in
primo piano c'è un Lampo, anche in una vista divisa di finestre del browser; e i Lampi si
rimettono in fila."""
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
CALC = ADDAPP("com.apple.calculator", "Calcolatrice")
CALC._hidden = true
CALC._wins[1]._frame = {x = 100, y = 100, w = 230, h = 330}
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Posta - Gmail", {"https://mail.google.com/mail/u/0/"}},
  {"Notion", {"https://www.notion.so/abc"}},
})
FRONT = SLACK
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)
def fits(w): return ev(f'(function() local a = Tabby._env.appArea(); local f = {w}._frame; return math.abs(f.x - a.x) < 2 and math.abs(f.y - a.y) < 2 and math.abs(f.w - a.w) < 2 and math.abs(f.h - a.h) < 2 end)()')
POS = {1: "in alto", 2: "in basso", 3: "a sinistra", 4: "a destra"}
def position(n): run(f'CLICK("settings"); MENU[1].menu[{n}].fn()')

run(f'CLICK("tab{idx("Slack")}")')
run('KEY("c", {"ctrl","alt"})')   # un Lampo in primo piano
print("== Slack aperto, la Calcolatrice (Lampo) in primo piano")
for n in (4, 2, 3, 1):
    position(n)
    check(f"Tabby {POS[n]}: Slack si rimette a misura", fits('SLACK._wins[1]') is True)
    check(f"Tabby {POS[n]}: la Calcolatrice nell'angolo in alto a destra dello spazio", ev('(function() local a = Tabby._env.appArea(); local f = CALC._wins[1]._frame; return f.x + f.w == a.x + a.w - 12 and f.y == a.y + 12 end)()') is True)

print("== Vista divisa con due finestre di Chrome")
run('CALC:activate(); KEY("escape")')
run(f'CLICK("tab{idx("Gmail")}")')
run('CLICK("split"); MENU[1].fn()')
run(f'CLICK("tab{idx("Notion")}")')
check("vista divisa creata", ev('#hs.settings.get("tabbar.groups")') == 1)
position(4)
half = ev('Tabby._env.appArea().w / 2')
check("Tabby a destra: le due finestre restano divise (non a tutto spazio)", ev('CHROME._wins[1]._frame.w') < half + 2 and ev('CHROME._wins[2]._frame.w') < half + 2)
check("…e stanno nello spazio nuovo", ev('(function() local a = Tabby._env.appArea(); local f1, f2 = CHROME._wins[1]._frame, CHROME._wins[2]._frame; return math.max(f1.x + f1.w, f2.x + f2.w) <= a.x + a.w end)()') is True)
position(1)

print("== Batteria: solo l'icona, la percentuale passandoci sopra")
texts = ev('(function() local o = {} for _, e in ipairs(BAR()._els) do if e.text then o[#o+1] = e.text end end return table.concat(o, "|") end)()')
check("nella barra non c'è più la percentuale", "72%" not in texts)
run('BAR()._cb(BAR(), "mouseEnter", "battery")')
check("puntatore sulla batteria: fumetto «72%»", ev('Tabby.batTip and Tabby.batTip._shown') is True and ev('Tabby.batTip._els[2].text') == "72%")
run('BAR()._cb(BAR(), "mouseExit", "battery")')
check("puntatore via: il fumetto sparisce", ev('Tabby.batTip._shown') is False)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
