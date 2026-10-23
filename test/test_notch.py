"""Test notch (MacBook Air 13"): fascia del notch, macOS che spinge giù le finestre, schede che saltano il notch."""
import os
from aiuto import carica, codice
import lupa.lua54 as l

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = codice(base)

def make(menu_hidden, notch, fy, push_down=False, extra=3):
    mock = open(base + '/test/mock_hs.lua').read()
    mock = mock.replace('frame = function() return {x = 0, y = 25, w = 1440, h = 875} end',
                        f'frame = function() return {{x = 0, y = {fy}, w = 1470, h = {956 - fy}}} end')
    mock = mock.replace('fullFrame = function() return {x = 0, y = 0, w = 1440, h = 900} end',
                        'fullFrame = function() return {x = 0, y = 0, w = 1470, h = 956} end')
    js = '"646,645,32"' if notch else '"none"'
    mock = mock.replace('javascript = function() return true, "" end',
                        f'javascript = function() return true, {js} end')
    mock = mock.replace('focus = function() FRONT = HS_APP end, reload',
                        f'execute = function() return "{1 if menu_hidden else 0}\\n" end,\n  focus = function() FRONT = HS_APP end, reload')
    if push_down:  # come macOS: sotto il livello "status" non si entra nella fascia del notch
        mock = mock.replace('function c:level() return self end', 'function c:level(v) if v then self._level = v end return self end')
        mock = mock.replace('function c:frame(f) if f then self._frame = f; return self end return self._frame end',
            'function c:frame(f) if f then local y = f.y; if (self._level or 0) < 25 and y < 32 then y = 32 end; self._frame = {x=f.x, y=y, w=f.w, h=f.h}; return self end return self._frame end')
        mock = mock.replace('windowLevels = {floating = 3, modalPanel = 8, dragging = 500}',
                            'windowLevels = {floating = 3, modalPanel = 8, dock = 20, mainMenu = 24, status = 25, popUpMenu = 101, dragging = 500}')
    L = l.LuaRuntime(); L.execute(mock)
    L.execute('print = function() end')
    L.execute('ADDAPP("com.apple.finder","Finder"); ADDAPP("com.tinyspeck.slackmacgap","Slack"); '
              'for k = 1, %d do ADDAPP("com.test.app"..k, "App "..k) end; FRONT = APPS[2]' % extra)
    L.execute(carica(base)); L.execute('FLUSH()')
    return L

def under_notch(L):
    return L.execute('''local nz, bad = Tabby.L.notch, 0
if not nz then return -1 end
local limit = (Tabby.L.battery and Tabby.L.battery.x or Tabby.L.split.x)
local function chk(r) if (r.x < nz.x2 and r.x + r.w > nz.x1) or r.x + r.w > limit then bad = bad + 1 end end
for _, tv in ipairs(Tabby.L.tabs) do chk(tv.r) end
if Tabby.L.more then chk(Tabby.L.more) end
return bad''')

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  NO   ") + name)
    ok = ok and cond

L = make(True, True, 32)
check("notch + menu nascosto: Tabby in cima (y=0)", L.eval('Tabby.bf.y') == 0)
check("notch + menu nascosto: nessuna scheda sotto il notch", under_notch(L) == 0)
check("le app partono sotto Tabby (y=38)", L.execute('return hs.application.get("com.tinyspeck.slackmacgap")._wins[1]._frame.y') == 38)
L = make(False, True, 32)
check("notch + menu visibile: Tabby sotto la barra dei menu", L.eval('Tabby.bf.y') == 32)
L = make(True, False, 0)
check("senza notch: nessun salto", L.eval('Tabby.L.notch') is None)
L = make(True, True, 32, push_down=True)
check("macOS spinge giù: Tabby sale di livello e resta in cima", L.execute('return Tabby.bar:frame().y') == 0)
for extra in [0, 3, 8, 15, 40]:
    L = make(True, True, 32, extra=extra)
    check(f"{extra + 2} app: nessuna sovrapposizione col notch o coi tasti", under_notch(L) == 0)
print("TUTTO OK" if ok else "PROBLEMI")
raise SystemExit(0 if ok else 1)
