"""Test di base: schede, scorciatoie, viste divise (gruppi), riordino, tante app, posizioni."""
import sys
from aiuto import carica, codice
import lupa.lua54 as l

import os
base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = l.LuaRuntime()
L.execute(open(base + '/test/mock_hs.lua').read())
L.execute('''
ADDAPP("com.apple.finder", "Finder")
ADDAPP("com.apple.mail", "Mail")
ADDAPP("com.apple.Safari", "Safari")
ADDAPP("com.apple.Notes", "Note")
ADDAPP("com.tinyspeck.slackmacgap", "Slack")
FRONT = APPS[2]
''')

L.execute(carica(base))
L.execute('FLUSH()')

def ev(code):
    return L.execute('return ' + code)

def step(title, code=None):
    if code:
        L.execute(code)
        L.execute('FLUSH()')
    print(f"\n== {title}")
    print("  schede:", ev('TABNAMES()'))
    print("  in primo piano:", ev('FRONT and FRONT._bid'))

step("Avvio")

step("Clic sulla scheda 3", 'CLICK("tab3")')

step("⌃⌥→ (successiva)", 'KEY("right", {"ctrl","alt"})')
step("⌃⌥1", 'KEY("1", {"ctrl","alt"})')
step("⌃⌥Tab (torna a prima)", 'KEY("tab", {"ctrl","alt"})')

# --- dividi: schema a 3 ---
L.execute('CLICK("split")')
print("\n== Menu Dividi:", [ev(f'MENU[{i}].title') for i in range(1, 5)])
L.execute('MENU[3].fn()'); L.execute('FLUSH()')
print("  modalità dividi attiva:", ev('Tabby.split ~= nil'), "| zona 1 precompilata con:", ev('Tabby.split.zones[1]'))

# trascina la scheda Safari nella zona 2 (in basso a sinistra)
L.execute('''
local idx
for i, t in ipairs(Tabby.tabs) do if t.bid == "com.apple.Safari" then idx = i end end
local r
for _, tv in ipairs(Tabby.L.tabs) do if tv.i == idx then r = tv.r end end
local bf = Tabby.bf
SAF_FROM = {x = bf.x + r.x + r.w/2, y = bf.y + r.y + r.h/2}
SAF_ID = "tab" .. idx
''')
L.execute('DRAG(SAF_ID, SAF_FROM, {x = 300, y = 700})')
print("  dopo trascinamento Safari → zona 2:", ev('Tabby.split and Tabby.split.zones[2]'))

# clic (senza trascinare) su Note → prima zona libera (zona 3) → tutte piene → gruppo
L.execute('''
for i, t in ipairs(Tabby.tabs) do if t.bid == "com.apple.Notes" then CLICK("tab" .. i) end end
FLUSH()
''')
print("  dopo clic su Note: zone =", ev('Tabby.split and (tostring(Tabby.split.zones[1]).." / "..tostring(Tabby.split.zones[2]).." / "..tostring(Tabby.split.zones[3])) or "chiusa"'))
L.execute('''
for i, t in ipairs(Tabby.tabs) do if t.bid == "com.apple.mail" then CLICK("tab" .. i) end end
FLUSH()
''')
step("Gruppo creato (3 zone piene)")
print("  gruppi salvati:", ev('#Tabby and #(hs.settings.get("tabbar.groups") or {})'))
print("  schema gruppo:", ev('hs.settings.get("tabbar.groups")[1].layout'))
for b in ["com.apple.mail", "com.apple.Safari", "com.apple.Notes"]:
    print(f"  finestra {b}:", ev(f'(function() local a = hs.application.get("{b}"); local f = a._wins[1]._frame; return f.x..","..f.y.." "..f.w.."x"..f.h .. (a._hidden and " (nascosta)" or "") end)()'))
print("  Slack nascosta:", ev('hs.application.get("com.tinyspeck.slackmacgap")._hidden'))
print("  scheda attiva è il gruppo:", ev('(function() local i; for k,t in ipairs(Tabby.tabs) do if t.group then i = k end end; return i end)()'))

step("Ctrl+1 (Finder) poi clic sul gruppo", '''
KEY("1", {"ctrl","alt"}); FLUSH()
for i, t in ipairs(Tabby.tabs) do if t.group then CLICK("tab" .. i) end end
''')
print("  membri visibili:", ev('(function() local o = {} for _, b in ipairs({"com.apple.mail","com.apple.Safari","com.apple.Notes"}) do o[#o+1] = tostring(not hs.application.get(b)._hidden) end return table.concat(o, ",") end)()'))

# riordino: trascina la prima scheda in fondo
L.execute('''
local first = Tabby.L.tabs[1]
local last = Tabby.L.tabs[#Tabby.L.tabs]
local bf = Tabby.bf
DRAG("tab" .. first.i, {x = bf.x + first.r.x + 10, y = bf.y + 15}, {x = bf.x + last.r.x + last.r.w - 5, y = bf.y + 15})
''')
step("Riordino: prima scheda trascinata in fondo")

# chiudi Note: il gruppo passa a 2 app (schema 2-50)
step("Note viene chiusa", '''
hs.application.get("com.apple.Notes"):kill()
APPWATCH("Note", "term", nil); FLUSH()
''')
print("  schema gruppo ora:", ev('(hs.settings.get("tabbar.groups")[1] or {}).layout'))

# scomponi
step("Scomponi", '''
for i, t in ipairs(Tabby.tabs) do if t.group then CLICK("ungroup" .. i) end end
''')
print("  gruppi rimasti:", ev('#hs.settings.get("tabbar.groups")'))

# dividi e annulla con Esc
L.execute('CLICK("split")'); L.execute('MENU[1].fn()'); L.execute('FLUSH()')
L.execute('KEY("escape")'); L.execute('FLUSH()')
print("\n== Dividi + Esc → annullato:", ev('Tabby.split == nil'))

# tante app: 30 app finte
L.execute('''
for k = 1, 30 do ADDAPP("com.test.app" .. k, "App di prova " .. k) end
Tabby.rebuildTimer:start(); FLUSH()
''')
print("\n== 30 app in più: schede visibili", ev('#Tabby.L.tabs'), "| nel menu +N:", ev('Tabby.L.overflow and #Tabby.L.overflow or 0'),
      "| compatte:", ev('(function() local c = 0 for _, tv in ipairs(Tabby.L.tabs) do if tv.compact then c = c + 1 end end return c end)()'))

# tutte le posizioni disegnano senza errori
for pos in ["bottom", "left", "right", "top"]:
    L.execute(f'''
CLICK("settings")
for _, it in ipairs(MENU[1].menu) do if it.title then end end
''')
    idx = {"top": 1, "bottom": 2, "left": 3, "right": 4}[pos]
    L.execute(f'MENU[1].menu[{idx}].fn(); FLUSH()')
    print(f"  posizione {pos}: ok, barra {ev('Tabby.bf.w')}x{ev('Tabby.bf.h')}")

print("\nLOG (ultime righe):", list(L.eval('LOG').values())[-5:])
print("\nTUTTO OK")
