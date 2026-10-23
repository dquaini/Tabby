"""v9.38 (feedback del 23/10/2026): chiudere o ridurre (pallino giallo) la scheda attiva
porta sempre alla scheda accanto, in qualsiasi modo; due finestre dello stesso browser in
una vista divisa non "vibrano"; angoli smussati verso le app; clic sul gatto = Finder
sulla Scrivania; il Memo si riprende la tastiera."""
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
TE = ADDAPP("com.apple.TextEdit", "TextEdit")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Iscrizione - Tally", {"https://tally.so/r/abc"}},
  {"Risposte - Tally", {"https://tally.so/forms/xyz"}},
  {"Notizie", {"https://www.repubblica.it/", "https://www.corriere.it/"}},
})
FRONT = FINDER
''')
L.execute(carica(base))
L.execute('FLUSH()')
def ev(code): return L.execute('return ' + code)
def run(code): L.execute(code); L.execute('FLUSH()')
def names(): return ev('TABNAMES()').split(" | ")
def idx(name): return ev(f'(function() for i, t in ipairs(Tabby.tabs) do if t.name == "{name}" then return i end end end)()')
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

def neighbor_of(name):
    n = names(); i = n.index(name)
    return n[i - 1] if i > 0 else n[i + 1]

print("== Schede:", names())

print("== Pallino giallo sulla scheda attiva: si passa alla scheda accanto")
run(f'CLICK("tab{idx("TextEdit")}")')
nb = neighbor_of("TextEdit")
run('local w = TE._wins[1]; w:minimize(); TE._focused = nil; WINFILTER.subs["minimized"](w)')
check(f"ridotto TextEdit: ora sei su «{nb}»", ev('FRONT and FRONT._name') in (nb,) or ev('FRONT._focused and FRONT._focused._title') == nb)
check("TextEdit resta una scheda (cliccandola torna)", "TextEdit" in names())
run(f'CLICK("tab{idx("TextEdit")}")')
check("cliccata: la finestra di TextEdit torna", ev('TE._wins[1]._min') is False and ev('FRONT == TE') is True)

print("== Le riduzioni fatte da Tabby (una scheda alla volta) non contano")
run(f'CLICK("tab{idx("Chrome")}")')
check("su «Notizie», le altre finestre di Chrome ridotte da Tabby", ev('CHROME._wins[1]._min') is True)
run('WINFILTER.subs["minimized"](CHROME._wins[1])')
check("resti su «Notizie»", ev('CHROME._focused == CHROME._wins[3]') is True and ev('FRONT == CHROME') is True)

print("== macOS attiva un'altra app un attimo PRIMA di dire che la finestra è chiusa")
run(f'CLICK("tab{idx("Slack")}")')
nb = neighbor_of("Slack")
run('FRONT = FINDER; FINDER._hidden = false; WINFILTER.subs["focused"](FINDER._wins[1]); APPWATCH(nil, "act", FINDER)')
run('local w = SLACK._wins[1]; w:close(); SLACK._focused = nil; WINFILTER.subs["destroyed"](w)')
check(f"chiusa Slack col pallino rosso: sei su «{nb}» (la scheda accanto)", ev('FRONT and FRONT._name') == nb or ev('FRONT._focused and FRONT._focused._title') == nb)

print("== ⌘Q sull'app attiva: scheda accanto")
run(f'CLICK("tab{idx("Note")}")')
nb = neighbor_of("Note")
run('NOTE:kill(); APPWATCH(nil, "term", NOTE)')
check(f"chiusa Note: sei su «{nb}»", ev('FRONT and FRONT._name') == nb or ev('FRONT._focused and FRONT._focused._title') == nb)

print("== Vista divisa con due finestre di Tally: niente vibrazione")
L.execute('for _, w in ipairs(CHROME._wins) do w._min = false end')
tally = [i + 1 for i, n in enumerate(names()) if n == "Tally"]
run(f'CLICK("tab{tally[0]}")')
run('CLICK("split"); MENU[1].fn()')
run(f'CLICK("tab{tally[1]}")')
check("vista divisa con le due finestre di Tally", ev('#hs.settings.get("tabbar.groups")') == 1)
L.execute('RAISE_FOCUS = true; RAISES = 0; SETFRAMES_ALL = 0')
run(f'CLICK("tab{idx("Chrome")}")')
L.execute('RAISES = 0; SETFRAMES_ALL = 0')
gi = ev('(function() for i, t in ipairs(Tabby.tabs) do if t.group then return i end end end)()')
L.execute(f'CLICK("tab{gi}")'); L.execute('FLUSH(60)')
print("   finestre portate davanti:", ev('RAISES'), "· ridimensionamenti:", ev('SETFRAMES_ALL'))
check("le finestre si portano davanti una volta sola (prima: all'infinito)", ev('RAISES') <= 2)
check("e non vengono ridimensionate di continuo", ev('SETFRAMES_ALL') <= 4)
L.execute('RAISE_FOCUS = false')

print("== Angoli smussati dalla parte delle app")
def bg(): return ev('BAR()._els[1].roundedRectRadii and BAR()._els[1].roundedRectRadii.xRadius or 0')
check("in alto: lo sfondo ha gli angoli arrotondati", bg() >= 8)
check("…e la metà verso il bordo dello schermo è dritta (in alto)", ev('BAR()._els[2].frame.y') == 0)
run('CLICK("settings"); MENU[1].menu[4].fn()')
check("a destra: metà dritta verso il bordo destro", ev('BAR()._els[2].frame.x') > 0 and ev('BAR()._els[2].frame.y') == 0)
run('CLICK("settings"); MENU[1].menu[1].fn()')

print("== Clic sul gatto: Finder sulla Scrivania (⌃⌥0 resta la scrivania)")
L.execute('OPENS = {}')
run('CLICK("desktop")')
check("si apre il Finder sulla cartella Scrivania", any('Desktop' in str(x) for x in ev('OPENS').values()))
check("…senza nascondere tutto", ev('Tabby.desktopMode') is not True)
run('KEY("0", {"ctrl","alt"})')
check("⌃⌥0 è ancora la scrivania", ev('Tabby.desktopMode') is True)
run('KEY("0", {"ctrl","alt"})')

print("== Memo: si riprende la tastiera se non ce l'ha")
run('KEY("m", {"ctrl","alt"})')
check("Memo aperto", ev('Tabby.memoOpen') is True)
check("ha chiesto la tastiera più di una volta (finché non arriva)", ev('#MEMO._js') >= 3)
run('KEY("m", {"ctrl","alt"})')

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
