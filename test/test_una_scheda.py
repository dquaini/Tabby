"""Una scheda alla volta: con più finestre della stessa app (Chrome, Finder…) si
vede solo quella scelta; le altre si riducono a icona e tornano quando le scegli.
Restano insieme le finestre di una vista divisa e il video in miniatura di Meet."""
import os
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Calcio | Sofascore - Google Chrome", {"https://www.sofascore.com/"}},
  {"Posta in arrivo - Gmail - Google Chrome", {"https://mail.google.com/mail/u/0/"}},
})
CHROME._wins[1]._asName = "Calcio | Sofascore"; CHROME._wins[2]._asName = "Posta in arrivo - Gmail"
SOFA, GMAIL = CHROME._wins[1], CHROME._wins[2]
FRONT = FINDER
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

run(f'CLICK("tab{idx("Sofascore")}")')
check("su Sofascore: Gmail (stessa app) è ridotta a icona", ev('GMAIL._min') is True and ev('SOFA._min') is False)
run(f'CLICK("tab{idx("Gmail")}")')
check("su Gmail: torna Gmail, Sofascore ridotta", ev('GMAIL._min') is False and ev('SOFA._min') is True)
check("in primo piano Gmail", ev('CHROME._focused == GMAIL') is True)

print("== Cambio di finestra fatto da macOS (non da te): nessuna riduzione")
run('MINS = 0; for _, w in ipairs(CHROME._wins) do local o = w.minimize; w.minimize = function(self) MINS = MINS + 1; o(self) end end')
run('SOFA:unminimize(); CHROME._focused = SOFA; WINFILTER.subs["focused"](SOFA)')
run('CHROME._focused = GMAIL; WINFILTER.subs["focused"](GMAIL)')
run('CHROME._focused = SOFA; WINFILTER.subs["focused"](SOFA)')
check("macOS sposta l'attenzione avanti e indietro: Tabby non riduce niente (niente ping-pong)", ev('MINS') == 0)
run(f'CLICK("tab{idx("Gmail")}")')
check("ma quando scegli tu una scheda, le altre si riducono", ev('SOFA._min') is True and ev('GMAIL._min') is False)

print("== La tastiera arriva alla finestra scelta (⌘F)")
run(f'CLICK("tab{idx("Sofascore")}")')
# clic su Gmail (ridotta): macOS la riapre ma la tastiera resta su Sofascore
L.execute(f'''ORIG_FOCUS = GMAIL.focus
GMAIL.focus = function(self) if self._min then return end FRONT = CHROME; CHROME._focused = self end
CLICK("tab{idx("Gmail")}")''')
L.execute('CHROME._focused = SOFA')   # la prima richiesta è stata ignorata
L.execute('FLUSH()')
check("dopo il clic la tastiera è su Gmail", ev('CHROME._focused == GMAIL') is True)
L.execute('GMAIL.focus = ORIG_FOCUS')
run(f'CLICK("tab{idx("Sofascore")}"); CLICK("tab{idx("Finder")}")')
check("clic veloci su due schede: vince l'ultima (il controllo non si riprende Sofascore)", ev('FRONT == FINDER') is True)

run(f'CLICK("tab{idx("Gmail")}")')
print("== ⌘N: nuova finestra di Chrome")
run('''
NEW = newWindow(CHROME, "Nuova scheda - Google Chrome", {"chrome://newtab/"})
NEW._asName = "Nuova scheda"
NEW._frame = {x = 0, y = 25, w = 1440, h = 837}   -- come sul Mac: grande come la finestra di prima
table.insert(CHROME._wins, 1, NEW)
FRONT = CHROME   -- ⌘N si preme dentro Chrome
CHROME._focused = NEW
WINFILTER.subs["created"](NEW); WINFILTER.subs["focused"](NEW)
Tabby.rebuildTimer:start()''')
check("la finestra di prima (Gmail) si riduce a icona", ev('GMAIL._min') is True and ev('NEW._min') is False)

print("== Vista divisa Gmail + Slack")
run(f'CLICK("tab{idx("Gmail")}")')
run('CLICK("split"); MENU[1].fn()')
run(f'CLICK("tab{idx("Slack")}")')
check("Gmail visibile nella vista divisa, le altre di Chrome ridotte",
      ev('GMAIL._min') is False and ev('SOFA._min') is True and ev('NEW._min') is True)

print("== Video in miniatura di Meet")
run(f'CLICK("ungroup{idx("Gmail + Slack")}")')
run('''
PIP = newWindow(CHROME, "Gmail", {}); PIP._noAS = true
PIP._frame = {x = 1100, y = 480, w = 300, h = 390}
table.insert(CHROME._wins, PIP); WINFILTER.subs["created"](PIP); Tabby.rebuildTimer:start()''')
run(f'CLICK("tab{idx("Sofascore")}")')
check("la miniatura non si riduce mai", ev('PIP._min') is False)

print("== App con le finestre in una scheda sola (⚙︎ → Finestre separate spento)")
run('''local w = newWindow(FINDER, "Download"); table.insert(FINDER._wins, w); FINDER2 = w
WINFILTER.subs["created"](w); Tabby.rebuildTimer:start()''')
run(f'CLICK("tab{idx("Download")}")')
check("Finder: la finestra non scelta si riduce", ev('FINDER._wins[1]._min') is True)
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Finestre separate" then for _, it in ipairs(m.menu) do if it.title == "Finder" then it.fn() end end end end')
run(f'FINDER._wins[1]:unminimize(); CLICK("tab{idx("Finder")}")')
check("Finder in una scheda sola: nessuna finestra ridotta", ev('FINDER._wins[1]._min') is False and ev('FINDER2._min') is False)

print("== Interruttore spento (⚙︎ → Comportamento → Una scheda alla volta)")
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Una scheda alla volta") then it.fn() end end end end')
run(f'SOFA:unminimize(); GMAIL:unminimize(); CLICK("tab{idx("Gmail")}")')
check("spento: le altre finestre restano come sono", ev('SOFA._min') is False)

print("== Accesso con Google in una finestrella (22/10: si tornava al desktop)")
run('CLICK("settings"); for _, m in ipairs(MENU) do if m.title == "Comportamento" then for _, it in ipairs(m.menu) do if it.title:find("^Una scheda alla volta") then it.fn() end end end end')
run(f'CLICK("tab{idx("Sofascore")}")')
check("di nuovo acceso: su Sofascore", ev('CHROME._focused == SOFA') is True and ev('SOFA._min') is False)
run('''
POP = newWindow(CHROME, "Accedi - Account Google - Google Chrome", {"https://accounts.google.com/"})
POP._asName = "Accedi - Account Google"
POP._frame = {x = 420, y = 60, w = 590, h = 830}
table.insert(CHROME._wins, 1, POP)
WINFILTER.subs["created"](POP)
CHROME._focused = POP; WINFILTER.subs["focused"](POP)
Tabby.rebuildTimer:start()''')
check("la finestra di accesso non riduce Sofascore", ev('SOFA._min') is False)
check("e Tabby non la ingrandisce", ev('POP._frame.w') == 590)
run('''POP:close(); CHROME._focused = nil
WINFILTER.subs["destroyed"](POP); Tabby.rebuildTimer:start()''')
check("accesso finito: resti su Sofascore", ev('SOFA._min') is False)

print("== ⌘W su una finestra: torna quella di prima, non il desktop")
run(f'CLICK("tab{idx("Sofascore")}")')
run(f'CLICK("tab{idx("Gmail")}")')
check("su Gmail, Sofascore ridotta", ev('SOFA._min') is True)
run('''local all_min = true
for _, w in ipairs(CHROME._wins) do if w ~= GMAIL and w ~= PIP and not w._min then w:minimize() end end
GMAIL:close(); CHROME._focused = nil
WINFILTER.subs["destroyed"](GMAIL); Tabby.rebuildTimer:start()''')
check("chiusa Gmail: torna Sofascore (l'ultima usata)", ev('SOFA._min') is False and ev('CHROME._focused == SOFA') is True)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
