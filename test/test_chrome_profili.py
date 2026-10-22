"""Chrome sul Mac di lavoro: finestra con un solo sito = webapp col logo del sito,
anche quando il titolo sullo schermo non coincide con quello di AppleScript
(più profili: "Gmail - Lavoro"), e diagnosi in console se AppleScript non risponde."""
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
  -- profilo "Lavoro": sullo schermo il titolo ha il profilo in fondo
  {"Posta in arrivo (2) - daniele@azienda.it - Gmail - Lavoro", {"https://mail.google.com/mail/u/0/#inbox"}},
  {"Notion – Home - Lavoro", {"https://www.notion.so/azienda/Home-123"}},
  {"Ricerca - Lavoro", {"https://www.google.com/search?q=x", "https://it.wikipedia.org/wiki/Gatto"}},
  -- titolo cambiato tra le due letture: si abbina per posizione
  {"Caricamento…", {"https://app.slack.com/client/T1"}},
})
CHROME._wins[1]._asName = "Posta in arrivo (2) - daniele@azienda.it - Gmail"
CHROME._wins[2]._asName = "Notion – Home"
CHROME._wins[3]._asName = "Ricerca"
CHROME._wins[4]._asName = "Slack | generale | Azienda"
for i, w in ipairs(CHROME._wins) do w._frame = {x = 10 * i, y = 40 + i, w = 900 + i, h = 700} end
FRONT = APPS[1]
''')
L.execute(carica(base))
L.execute('FLUSH()')

def ev(code): return L.execute('return ' + code)
def tabs():
    return ev('(function() local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name .. " [" .. t.key .. "]" end return table.concat(o, "  |  ") end)()')
def icon_url(key): return ev(f'(function() local i = Tabby.cand["{key}"] and Tabby.favicons[Tabby.cand["{key}"].site]; return type(i) == "table" and i._url or nil end)()')
def prints(): return ev('table.concat(PRINTS, "\\n")')

fails = []
def check(what, ok):
    print(("  ok   " if ok else "  NO   ") + what)
    if not ok: fails.append(what)

print("== Schede:", tabs())
check("Gmail (profilo Lavoro) è una webapp", ev('Tabby.cand["site:mail.google.com"] ~= nil') is True)
check("…col nome «Gmail» (non «Lavoro»)", ev('Tabby.cand["site:mail.google.com"].name') == "Gmail")
check("…col numero di notifiche dal titolo (2)", ev('Tabby.cand["site:mail.google.com"].titleBadge') == "2")
check("…e col logo del sito, non di Chrome", "mail.google.com" in (icon_url("site:mail.google.com") or ""))
check("Notion è una webapp col suo logo", ev('Tabby.cand["site:notion.so"] ~= nil') is True and icon_url("site:notion.so") is not None)
check("Slack (titolo diverso, stessa posizione) è una webapp", ev('Tabby.cand["site:app.slack.com"] ~= nil') is True)
check("la finestra con due siti resta una finestra normale «Chrome»",
      ev('(function() for _, t in ipairs(Tabby.tabs) do if t.name == "Chrome" and not t.site then return true end end return false end)()') is True)
out = prints()
check("diagnosi in console: come è stata abbinata ogni finestra",
      "abbinata per posizione" in out and "abbinata per NIENTE" not in out)
# senza la posizione (es. Safari vecchio) vale l'inizio del titolo
L.execute('NO_BOUNDS = true; Tabby.rebuildTimer:start(); FLUSH()')   # arriva la risposta senza posizione
L.execute('Tabby.bwKnown = {}; Tabby.bwDiag = {}; PRINTS = {}; Tabby.rebuildTimer:start(); FLUSH()')
check("senza posizione: Gmail riconosciuta per inizio del titolo (profilo)",
      ev('Tabby.cand["site:mail.google.com"] ~= nil') is True and "abbinata per inizio del titolo" in prints())
L.execute('NO_BOUNDS = nil; Tabby.rebuildTimer:start(); FLUSH()')
check("diagnosi senza indirizzi completi (privacy)", "/mail/u/0" not in out and "search?q" not in out)

print("\n== Loghi bloccati dalla rete aziendale")
L.execute('FAVICON_FAIL = "icons.duckduckgo.com"; Tabby.favicons = {}; Tabby.rebuildTimer:start(); FLUSH()')
L.execute('FAVICON_FAIL = nil')
check("logo preso da un'altra fonte", icon_url("site:mail.google.com") is not None)
L.execute('''FAVICON_FAIL = "/"; Tabby.favicons = {}; Tabby.faviconFail = {}; PRINTS = {}; Tabby.rebuildTimer:start(); FLUSH()''')
check("prova anche il sito stesso (/favicon.ico)", ev('(function() for _, u in ipairs(FAVICON_URLS) do if u == "https://mail.google.com/favicon.ico" then return true end end return false end)()') is True)
check("se falliscono tutte, lo dice in console", "logo di mail.google.com non trovato" in prints())
L.execute('FAVICON_FAIL = nil')

print("\n== Permesso Automazione negato")
L.execute('AS_DENIED = true; PRINTS = {}; Tabby.rebuildTimer:start(); FLUSH()')
check("la console spiega cosa fare", "Automazione" in prints() and "Google Chrome" in prints())
L.execute('AS_DENIED = false; Tabby.rebuildTimer:start(); FLUSH()')
L.execute('AS_DENIED = true; AS_TIMEOUT = true; PRINTS = {}; Tabby.rebuildTimer:start(); FLUSH()')
check("Chrome occupato (non il permesso): la console non parla di Automazione",
      "non ha risposto in tempo" in prints() and "Automazione" not in prints())
check("…e le webapp restano (ultima risposta buona)", ev('Tabby.cand["site:mail.google.com"] ~= nil') is True)
L.execute('AS_DENIED = false; AS_TIMEOUT = nil; Tabby.rebuildTimer:start(); FLUSH()')
check("permesso dato: tornano le webapp", ev('Tabby.cand["site:mail.google.com"] ~= nil') is True)

print("\n== Velocità e script")
src = codice(base)
check("la domanda a Chrome parte in parallelo (Tabby non resta ferma ad aspettare)",
      "hs.osascript.applescript(" not in src and ev('(TASKS or 0) > 0') is True)
script = src[src.index("AS_WINDOWS = [["):]
script = script[:script.index("]]")]
check("lo script non usa la parola «tab» come separatore (dentro Chrome è la scheda)",
      "& TB" in script and "& tab" not in script)

print()
print("FALLITI: %d" % len(fails) if fails else "TUTTO OK")
