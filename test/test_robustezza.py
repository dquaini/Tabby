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

print("\n" + ("TUTTO OK" if not fails else f"FALLITI: {len(fails)}"))
