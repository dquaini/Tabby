"""Correzioni dopo la revisione del codice (v9.4):
1. vista divisa con una webapp: non si scioglie se la finestra cambia sito per un attimo
2. lo stesso sito aperto in due browser diversi: due schede, non una che sparisce
3. loghi dei siti: se manca internet si riprova più tardi (non mai più)
"""
import os
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
FAVICON_FAIL = ""   -- all'avvio niente internet: tutti i loghi falliscono
ADDAPP("com.apple.finder", "Finder")
ADDAPP("com.tinyspeck.slackmacgap", "Slack")
CHROME = ADDBROWSER("com.google.Chrome", "Google Chrome", {
  {"Posta in arrivo - io@gmail.com - Gmail", {"https://mail.google.com/mail/u/0/#inbox"}},
  {"Notizie", {"https://www.repubblica.it/", "https://www.corriere.it/"}},
})
SAFARI = ADDBROWSER("com.apple.Safari", "Safari", {
  {"Posta in arrivo - lavoro@gmail.com - Gmail", {"https://mail.google.com/mail/u/1/#inbox"}},
})
FRONT = APPS[2]
''')
L.execute(carica(base))
L.execute('FLUSH()')

def ev(code): return L.execute('return ' + code)
def rebuild(): L.execute('Tabby.rebuildTimer:start(); FLUSH()')
def tabs():
    return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name .. " [" .. t.key .. "]" end return table.concat(o, "  |  ") end)()')

fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Schede:", tabs())

# --- 2. stesso sito in due browser ---
print("\n== 2. Gmail aperto sia in Chrome sia in Safari")
n_gmail = ev('(function() local n = 0 for _, t in ipairs(Tabby.tabs) do if t.site == "mail.google.com" then n = n + 1 end end return n end)()')
check("ci sono due schede Gmail (una per browser): %s" % n_gmail, n_gmail == 2)
check("la scheda Gmail di Safari porta alla finestra di Safari",
      ev('(function() for _, t in ipairs(Tabby.tabs) do if t.site == "mail.google.com" and t.bid == "com.apple.Safari" then return t.win == SAFARI._wins[1] end end return false end)()') is True)

# --- 3. loghi ritentati ---
print("\n== 3. Loghi dei siti senza internet, poi con internet")
check("all'avvio il logo di Gmail non c'è (niente internet)", ev('Tabby.favicons["mail.google.com"]') is False)
L.execute('FAVICON_FAIL = nil; CLOCK = 1030; Tabby.rebuildTimer:start(); FLUSH()')
check("dopo 30 s non si riprova ancora", ev('Tabby.favicons["mail.google.com"]') is False)
L.execute('CLOCK = 1100; Tabby.rebuildTimer:start(); FLUSH()')
check("dopo 100 s, tornato internet, il logo arriva", ev('type(Tabby.favicons["mail.google.com"]) == "table"') is True)

# --- 1. vista divisa Gmail + Slack, poi Gmail apre un'altra scheda di un altro sito ---
print("\n== 1. Vista divisa Gmail + Slack")
L.execute('''
for i, t in ipairs(Tabby.tabs) do if t.key == "site:mail.google.com" then CLICK("tab" .. i) end end
FLUSH()
CLICK("split"); MENU[1].fn(); FLUSH()
for i, t in ipairs(Tabby.tabs) do if t.bid == "com.tinyspeck.slackmacgap" then CLICK("tab" .. i) end end
FLUSH()
''')
print("  ", tabs())
check("la vista divisa esiste", ev('#hs.settings.get("tabbar.groups")') == 1)
# da Gmail apri un link: la finestra ora ha due siti diversi (non è più una webapp)
L.execute('CHROME._wins[1]._urls = {"https://mail.google.com/mail/u/0/#inbox", "https://drive.google.com/file/1"}')
rebuild()
print("   dopo il link:", tabs())
check("la vista divisa è ancora lì", ev('#hs.settings.get("tabbar.groups")') == 1)
check("contiene ancora la finestra di Gmail",
      ev('(function() local g = hs.settings.get("tabbar.groups")[1]; for _, k in ipairs(g.members) do if Tabby.keyWin[k] == CHROME._wins[1] then return true end end return false end)()') is True)
# chiusa la scheda in più: torna webapp, sempre nella vista divisa
L.execute('CHROME._wins[1]._urls = {"https://mail.google.com/mail/u/0/#inbox"}')
rebuild()
print("   scheda chiusa:", tabs())
check("di nuovo Gmail dentro la vista divisa",
      ev('(function() local g = hs.settings.get("tabbar.groups")[1]; return g and (g.members[1] == "site:mail.google.com" or g.members[2] == "site:mail.google.com") end)()') is True)
# la finestra di Gmail si chiude davvero: la vista divisa si scioglie (come prima)
L.execute('CHROME._wins[1]:close()')
rebuild()
check("finestra chiusa → vista divisa sciolta", ev('#hs.settings.get("tabbar.groups")') == 0)

print()
if fails:
    print("FALLITI:", len(fails))
else:
    print("TUTTO OK")
