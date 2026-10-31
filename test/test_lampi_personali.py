"""v9.68 (31/10/2026, Daniele): Lampi personalizzati. ⚡︎ → Personalizza i Lampi: togliere un
Lampo, cambiargli la scorciatoia, aggiungerne uno (app aperta o dalla cartella
Applicazioni), tornare a quelli di serie. Si salva in "tabbar.quick"; Tabby si ricarica."""
import os
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

def nuovo(prima=""):
    L = l.LuaRuntime()
    L.execute(open(base + '/test/mock_hs.lua').read())
    L.execute('''print = function() end
FINDER = ADDAPP("com.apple.finder", "Finder")
SLACK = ADDAPP("com.tinyspeck.slackmacgap", "Slack")
PROMEMORIA = ADDAPP("com.apple.reminders", "Promemoria")
FRONT = SLACK
''' + prima)
    L.execute(carica(base))
    L.execute('FLUSH()')
    return L

L = nuovo()
def ev(c): return L.execute('return ' + c)
def run(c): L.execute(c); L.execute('FLUSH()')
def personalizza(): return 'for _, it in ipairs(MENU) do if it.title == "Personalizza i Lampi" then P = it.menu end end'

print("== ⚡︎ → Personalizza i Lampi")
run('CLICK("quick"); ' + personalizza())
names = ev('(function() local o = {} for _, it in ipairs(P) do o[#o+1] = tostring(it.title) end return table.concat(o, "|") end)()')
print("  ", names)
check("ci sono i Lampi di serie, «Aggiungi un Lampo» e «Torna ai Lampi di serie»",
      "Calendario   ⌃⌥A" in names and "Aggiungi un Lampo" in names and "Torna ai Lampi di serie" in names)
run('for _, it in ipairs(P) do if it.title:find("^Calendario") then it.menu[2].fn() end end')
saved = ev('(function() local o = {} for _, q in ipairs(hs.settings.get("tabbar.quick")) do o[#o+1] = q.name end return table.concat(o, ",") end)()')
check("«Togli dai Lampi» il Calendario: salvato senza Calendario, e Tabby si ricarica", saved == "Memo,Calcolatrice,Terminale" and (ev('RELOADS') or 0) >= 1)

print("== Aggiungi Promemoria (app aperta)")
run('CLICK("quick"); ' + personalizza() + '; for _, it in ipairs(P) do if it.title == "Aggiungi un Lampo" then ADD = it.menu end end')
addn = ev('(function() local o = {} for _, it in ipairs(ADD) do o[#o+1] = tostring(it.title) end return table.concat(o, "|") end)()')
check("tra le app aperte c'è Promemoria (non il Finder), e «Altra app…»", "Promemoria" in addn and "Altra app…" in addn and "Finder" not in addn)
run('PROMPT_TEXT = nil; for _, it in ipairs(ADD) do if it.title == "Promemoria" then it.fn() end end')
q = ev('(function() local q = hs.settings.get("tabbar.quick"); local x = q[#q]; return x.name .. "|" .. x.key .. "|" .. x.bid end)()')
check("Promemoria è un Lampo con la prima lettera libera del nome (⌃⌥P)", q == "Promemoria|p|com.apple.reminders")

print("== Cambia la scorciatoia: lettera già usata → rifiutata")
run('CLICK("quick"); ' + personalizza())
run('PROMPT_TEXT = "c"; for _, it in ipairs(P) do if it.title:find("^Terminale") then it.menu[1].fn() end end')
check("⌃⌥C è della Calcolatrice: il Terminale resta ⌃⌥T", ev('(function() for _, q in ipairs(hs.settings.get("tabbar.quick")) do if q.name == "Terminale" then return q.key end end end)()') == "t")

print("== Altra app… (dalla cartella Applicazioni)")
run('CLICK("quick"); ' + personalizza() + '; for _, it in ipairs(P) do if it.title == "Aggiungi un Lampo" then ADD = it.menu end end')
run('CHOOSE_FILE = {["1"] = "/Applications/com.apple.Stickies.app"}; PROMPT_TEXT = "k"; for _, it in ipairs(ADD) do if it.title == "Altra app…" then it.fn() end end')
check("scelta un'app dal Finder: aggiunta con ⌃⌥K", ev('(function() local q = hs.settings.get("tabbar.quick"); return q[#q].bid .. "|" .. q[#q].key end)()') == "com.apple.Stickies|k")

print("== Dopo il ricaricamento: valgono i Lampi scelti")
saved_quick = '{{memo = true, name = "Memo", key = "m"}, {bid = "com.apple.calculator", name = "Calcolatrice", key = "c"}, {bid = "com.apple.reminders", name = "Promemoria", key = "p", w = 560, h = 480}}'
L = nuovo('hs.settings.set("tabbar.quick", ' + saved_quick + ')')
names2 = ev('(function() local o = {} for _, q in ipairs(Tabby._env.QUICK) do o[#o+1] = q.name end return table.concat(o, ",") end)()')
check("i Lampi sono Memo, Calcolatrice, Promemoria (niente Calendario)", names2 == "Memo,Calcolatrice,Promemoria")
run('Tabby._env.toggleQuick(Tabby._env.QUICK[3])')
check("Promemoria si apre come Lampo, piccolo in alto a destra (560×480)", ev('FRONT == PROMEMORIA') is True and ev('Tabby._env.floating("com.apple.reminders")') is True
      and ev('PROMEMORIA._wins[1]._frame.w') == 560)
check("il Calendario non è più un Lampo", ev('Tabby._env.FLOATER["com.apple.iCal"]') is None)
check("il foglio delle scorciatoie mostra Promemoria ⌃⌥P", '"⌃ ⌥ P","Promemoria"' in ev('Tabby._env.keysJS()'))
run('CLICK("quick"); ' + personalizza())
run('for _, it in ipairs(P) do if it.title == "Torna ai Lampi di serie" then it.fn() end end')
check("«Torna ai Lampi di serie»: la scelta si cancella", ev('hs.settings.get("tabbar.quick")') is None)

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
