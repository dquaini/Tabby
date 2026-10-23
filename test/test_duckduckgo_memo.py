"""Test DuckDuckGo (Accessibilità, ricordo da nascosto, loghi di riserva), nomi delle webapp, Memo su file."""
import os, tempfile
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
home = tempfile.mkdtemp()
os.makedirs(os.path.join(home, "Documents"))
os.environ["HOME"] = home
SRC = codice(base)

mock = open(base + '/test/mock_hs.lua').read()
# (la lettura delle finestre di DuckDuckGo è nel Mac simulato: mock_hs.lua)
L = l.LuaRuntime(); L.execute(mock)
L.execute('''
DDG = ADDAPP("com.duckduckgo.macos.browser", "DuckDuckGo"); DDG._wins = {}
local w1 = newWindow(DDG, "Proton Mail"); w1._page = "https://mail.proton.me/u/0/inbox"; w1._ntabs = 1
local w2 = newWindow(DDG, "Wikipedia"); w2._page = "https://it.wikipedia.org/wiki/Gatto"; w2._ntabs = 3
DDG._wins = {w1, w2}
ADDAPP("com.tinyspeck.slackmacgap", "Slack"); FRONT = APPS[1]
FAVICON_FAIL = "ip3/mail.proton.me"
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end PRINTS[#PRINTS+1] = table.concat(t, " ") end
''')
L.execute(carica(base)); L.execute('FLUSH()')
names = lambda: L.execute('local o = {} for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name end return table.concat(o, "|")')

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  NO   ") + name)
    ok = ok and cond

check("DuckDuckGo: finestra con 1 scheda = webapp 'Proton Mail'", "Proton Mail" in names())
check("DuckDuckGo: finestra con 3 schede = 'DuckDuckGo'", "DuckDuckGo" in names().split("|"))
check("logo preso dalla fonte di riserva (proton.me)", "proton.me" in L.execute('local i = Tabby.favicons["mail.proton.me"]; return i and i._url or ""'))
L.execute('DDG._hidden = true; FRONT = APPS[3]; Tabby.rebuildTimer:start(); FLUSH()')
check("DuckDuckGo nascosto: ricorda ancora il sito", "Proton Mail" in names())
leak = L.execute('''local out = table.concat(PRINTS, "\\n")
for _, c in pairs(Tabby.axCache or {}) do out = out .. "\\n" .. tostring(c.url) end
return out''')
check("privacy: in console e in memoria solo il sito, non l'indirizzo completo",
      "/u/0/inbox" not in leak and "wiki/Gatto" not in leak and "https://mail.proton.me/" in leak)

a = SRC.index("function siteName(title, dom)"); b = SRC.index("\nend", a) + 4
N = l.LuaRuntime(); N.execute(SRC[a:b] + "\nSN = siteName")
for title, dom, want in [("Proton Mail", "mail.proton.me", "Proton Mail"), ("Inbox (3) - io@gmail.com - Gmail", "mail.google.com", "Gmail"),
                         ("Notion – La mia pagina", "notion.so", "Notion"), ("(2) WhatsApp", "web.whatsapp.com", "WhatsApp"),
                         ("Documento - Google Docs", "docs.google.com", "Google Docs"), ("Inbox", "mail.google.com", "Google")]:
    check(f"nome webapp: {title!r} → {want}", N.eval('SN')(title, dom) == want)

L.execute('KEY("m", {"ctrl","alt"}); FLUSH()')
check("⌃⌥M apre il Memo", L.eval('Tabby.memoOpen'))
L.execute('MEMO_CB({body = {text = "Chiamare Marco"}})')
path = os.path.join(home, "Documents", "Tabby Memo.txt")
check("il Memo salva in ~/Documents/Tabby Memo.txt", os.path.exists(path) and open(path).read() == "Chiamare Marco")
L.execute('KEY("escape"); FLUSH()')
check("Esc chiude il Memo", L.execute('return not Tabby.memoOpen'))
open(path, "w").write("Modificato con TextEdit")
L.execute('KEY("m", {"ctrl","alt"}); FLUSH()')
check("riaprendo, il Memo rilegge il file", "Modificato con TextEdit" in L.execute('return table.concat(MEMO._js, " ")'))
print("TUTTO OK" if ok else "PROBLEMI")
raise SystemExit(0 if ok else 1)
