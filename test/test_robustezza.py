"""v9.62 (28/10/2026): controlli sul codice che evitano errori subdoli.
1. Nessun timer «fai tra un attimo» lasciato senza riferimento: Hammerspoon lo butta via
   (provato sul Mac: 20 timer su 20 persi) → si usa after() (o si tiene il timer in T).
2. Nessun comando esterno (hs.task) lasciato senza riferimento → runTask().
3. Nessuna funzione definita due volte in file diversi (lo spazio dei nomi è comune: la
   seconda cancella la prima, com'era successo con openQuick)."""
import os, re, glob
import lupa.lua54 as l
from aiuto import carica

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = []
def check(what, ok, extra=""):
    print(("  ok   " if ok else "  NO   ") + what + (("  " + extra) if extra and not ok else ""))
    if not ok: fails.append(what)

loose_timers, loose_tasks, defs = [], [], {}
for p in sorted(glob.glob(base + '/tabby/*.lua')):
    name = os.path.basename(p)
    for n, ln in enumerate(open(p).read().split('\n'), 1):
        code = ln.split('--')[0]
        if 'hs.timer.doAfter(' in code and not re.search(r'=\s*hs\.timer\.doAfter\(', code):
            loose_timers.append(f"{name}:{n}")
        if 'hs.task.new(' in code and not re.search(r'=\s*hs\.task\.new\(', code):
            loose_tasks.append(f"{name}:{n}")
        m = re.match(r'^(?:function\s+([A-Za-z_][\w.]*)|([A-Za-z_][\w.]*)\s*=\s*function)', ln)
        if m:
            fn = m.group(1) or m.group(2)
            defs.setdefault(fn, []).append(f"{name}:{n}")
check("nessun timer senza riferimento (si usa after)", not loose_timers, ", ".join(loose_timers))
check("nessun comando esterno senza riferimento (si usa runTask)", not loose_tasks, ", ".join(loose_tasks))
dups = {k: v for k, v in defs.items() if len(v) > 1}
check("nessuna funzione definita due volte", not dups, str(dups))

print("== after() tiene il timer finché non scatta")
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('print = function() end; ADDAPP("com.apple.finder", "Finder"); FRONT = nil')
L.execute(carica(base))
L.execute('FLUSH()')
L.execute('N = 0; Tabby._env.after(1, function() N = N + 1 end)')
check("in attesa: tenuto in T.pending", L.execute('return next(Tabby.pending) ~= nil') is True)
L.execute('FLUSH()')
check("scattato: fatto e lasciato andare", L.execute('return N') == 1 and L.execute('return next(Tabby.pending) == nil') is True)

print("== Memoria: le pagine non usate da 5 minuti si chiudono, e si ricreano")
L.execute('Tabby._env.openSearch(); FLUSH(); Tabby._env.closeSearch(); SV1 = Tabby.searchView')
L.execute('CLOCK = (CLOCK or 1000) + 100; Tabby._env.releaseIdleViews()')
check("dopo 100 secondi resta", L.execute('return Tabby.searchView ~= nil') is True)
L.execute('CLOCK = CLOCK + 250; Tabby._env.releaseIdleViews()')
check("dopo 5 minuti non usata: chiusa", L.execute('return Tabby.searchView == nil and SV1._deleted == true') is True)
L.execute('Tabby._env.openSearch(); FLUSH()')
check("riaprendo la ricerca si ricrea e funziona", L.execute('return Tabby.searchView ~= nil and Tabby.searchView._shown and Tabby.searchReady') is True)
L.execute('Tabby._env.closeSearch()')

print("== DuckDuckGo: si legge dentro le finestre solo quando serve")
L2 = l.LuaRuntime()
L2.execute(open(base + '/test/mock_hs.lua').read())
L2.execute('''print = function() end
ADDAPP("com.apple.finder", "Finder")
DDG = ADDAPP("com.duckduckgo.macos.browser", "DuckDuckGo")
W1 = newWindow(DDG, "Proton Mail"); W1._page = "https://mail.proton.me/u/0/inbox"; W1._ntabs = 1
W2 = newWindow(DDG, "Wikipedia"); W2._page = "https://it.wikipedia.org/wiki/Gatto"; W2._ntabs = 3
W1._macos26 = true; W2._macos26 = true
DDG._wins = {W1, W2}
FRONT = DDG''')
L2.execute(carica(base))
L2.execute('FLUSH()')
def e2(c): return L2.execute('return ' + c)
L2.execute('Tabby.axCache = {}; AXREADS = 0; Tabby._env.axBrowserInfo(DDG, "DDG")')
check("la prima volta legge le finestre", e2('AXREADS') >= 2)
L2.execute('AXREADS = 0; for i = 1, 3 do Tabby._env.axBrowserInfo(DDG, "DDG") end')
check("subito dopo, niente è cambiato: non rilegge (prima: ogni 3 secondi)", e2('AXREADS') == 0)
L2.execute('W2._title = "Cane - Wikipedia"; AXREADS = 0; Tabby._env.axBrowserInfo(DDG, "DDG")')
check("cambia il titolo (hai navigato): rilegge solo quella", e2('AXREADS') == 1)
L2.execute('CLOCK = (CLOCK or 1000) + 11; W1._min = true; AXREADS = 0; local wins = Tabby._env.axBrowserInfo(DDG, "DDG"); NW = #wins')
check("finestra ridotta: resta nell'elenco (macOS 26) ma non si rilegge", e2('NW') == 2 and e2('AXREADS') == 1)

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
