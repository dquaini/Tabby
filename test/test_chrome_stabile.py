"""Chrome: le webapp non devono "lampeggiare" (icona del sito che va e viene) quando
il titolo cambia e la finestra si sposta prima che Chrome risponda di nuovo."""
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
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Meet - abc-defg-hij - Google Chrome", {"https://meet.google.com/abc-defg-hij"}},
  {"(3) Posta in arrivo - Gmail - Google Chrome", {"https://mail.google.com/mail/u/0/"}},
})
CHROME._wins[1]._asName = "Meet - abc-defg-hij"
CHROME._wins[2]._asName = "(3) Posta in arrivo - Gmail"
FRONT = APPS[1]
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def keys(): return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.key end return table.concat(o, ",") end)()')

fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

start = keys()
print("== Avvio:", start)
check("Meet e Gmail sono webapp", "site:meet.google.com" in start and "site:mail.google.com" in start)

# Il titolo cambia e la finestra viene spostata (es. Tabby la adatta): Tabby
# ridisegna SUBITO, con la risposta di Chrome ancora vecchia (FLUSH(1) = solo
# il primo giro: la nuova risposta di Chrome non è ancora arrivata)
L.execute('''
local w = CHROME._wins[1]
w._title, w._asName = "Meet - abc-defg-hij (2 persone) - Google Chrome", "Meet - abc-defg-hij (2 persone)"
w._frame = {x = 0, y = 38, w = 1440, h = 862}
local g = CHROME._wins[2]
g._title, g._asName = "(4) Posta in arrivo - Gmail - Google Chrome", "(4) Posta in arrivo - Gmail"
g._frame = {x = 0, y = 38, w = 1440, h = 862}
WINFILTER.subs["title"](w)
FLUSH(1)
''')
mid = keys()
print("   subito dopo:", mid)
check("nel frattempo restano webapp (niente icona di Chrome)", mid == start)
L.execute('FLUSH()')
check("arrivata la risposta nuova: sempre webapp", keys() == start)
check("Gmail aggiorna le notifiche dal titolo nuovo (4)",
      ev('Tabby.cand["site:mail.google.com"].titleBadge') == "4")

# se la finestra cambia davvero (due siti), la risposta nuova lo dice
L.execute('''
local w = CHROME._wins[1]
w._urls = {"https://meet.google.com/abc-defg-hij", "https://docs.google.com/document/d/1"}
WINFILTER.subs["title"](w); FLUSH()
''')
check("con due siti diversi diventa una finestra normale", "site:meet.google.com" not in keys())

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
