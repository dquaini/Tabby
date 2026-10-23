-- =====================================================================
--  Tabby · base.lua: lo stato di Tabby (T), le impostazioni salvate (S), schermo, notch, utilità.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  DA QUI IN GIÙ IL FUNZIONAMENTO
-- ---------------------------------------------------------------------

-- Tutto in una tabella globale: se fosse locale, Hammerspoon
-- "dimenticherebbe" watcher, timer e scorciatoie dopo un po'.
_G.Tabby = { tabs = {}, icons = {}, hotkeys = {}, fsApps = {}, memberOf = {},
          closePos = {}, fullscreen = false, revealed = false,
          visible = nil, desktopMode = false, lastKey = nil,
          cand = {}, keyWin = {}, winKey = {}, keyBid = {},
          badges = {}, favicons = {}, binfo = {}, lastFire = {},
          tabFolder = {}, allTabs = {}, folderStart = {}, folderLast = {}, selfMin = {} }
T = Tabby

-- Le righe di diagnosi ("Tabby · …") non devono mai bloccare Tabby: se il
-- Terminale collegato a Hammerspoon (comando hs) si è interrotto, la print di
-- Hammerspoon va in errore e fermava il lavoro in corso (visto il 22/10/2026).
-- Questa print vale per tutti i file di Tabby (spazio comune).
print = function(...)
  local ok = pcall(_G.print, ...)
  if not ok then pcall(hs.console.printStyledtext, table.concat({...}, " ")) end
end

hs.window.animationDuration = 0

-- Le estensioni di Hammerspoon si caricano al primo uso e lo scrivono in console
-- ("-- Loading extension"). Se succede durante un clic mentre un comando "hs" dal
-- Terminale è stato interrotto, la scrittura va in errore e il clic si perde (visto
-- il 23/10/2026: il menu ⚙︎ non si apriva). Si caricano tutte subito, all'avvio.
for _, m in ipairs({"menubar", "dialog", "webview", "axuielement", "osascript", "task",
                    "image", "eventtap", "mouse", "spaces", "battery", "keycodes",
                    "geometry", "canvas", "window", "application", "alert", "settings",
                    "timer", "screen", "hotkey", "execute", "host", "console"}) do
  pcall(function() local _ = hs[m] end)
end
pcall(function() local _ = hs.webview.usercontent end)

-- La cartella di Tabby (per le immagini in assets/) e l'icona del gatto del
-- tasto scrivania: grigia a riposo, chiara quando la scrivania è attiva
T.dir = TABBY_DIR   -- la cartella di Tabby (la passa tabby.lua)
if T.dir and hs.image.imageFromPath then
  T.catOff = hs.image.imageFromPath(T.dir .. "/assets/gatto-spento.png")
  T.catOn  = hs.image.imageFromPath(T.dir .. "/assets/gatto-acceso.png")
  -- con Tabby a destra o a sinistra c'è spazio per il gatto intero (disegni di
  -- Daniele): a destra guarda verso sinistra (verso le app), a sinistra il contrario
  T.catFull = {}
  for _, side in ipairs({"destra", "sinistra"}) do
    T.catFull[side] = {
      off = hs.image.imageFromPath(T.dir .. "/assets/gatto-intero-" .. side .. "-spento.png"),
      on  = hs.image.imageFromPath(T.dir .. "/assets/gatto-intero-" .. side .. "-acceso.png"),
    }
  end
end

-- Impostazioni salvate (restano anche dopo riavvio)
S = {}
for k, v in pairs(DEFAULTS) do
  local saved = hs.settings.get("tabbar." .. k)
  if saved == nil then S[k] = v else S[k] = saved end
end
function save(k) hs.settings.set("tabbar." .. k, S[k]) end

-- App che possono essere "app veloci" (Calcolatrice, Calendario, Terminale)
FLOATER = {}
for _, q in ipairs(QUICK) do if q.bid then FLOATER[q.bid] = true end end

-- …ma lo sono solo quando le apri con la loro scorciatoia o dal menu ⚡︎ (23/10/2026):
-- allora stanno piccole in alto a destra, sopra tutto, finché non premi Esc. Aperte in
-- un altro modo (Spotlight, Dock) sono app normali, con la loro scheda, a tutto spazio.
T.floatMode = hs.settings.get("tabbar.floatMode") or {}
function floating(bid)
  return bid ~= nil and FLOATER[bid] == true and T.floatMode[bid] == true
end
function setFloatMode(bid, on)
  if not FLOATER[bid] then return end
  T.floatMode[bid] = on and true or nil
  hs.settings.set("tabbar.floatMode", T.floatMode)
end

function isPinned(bid)
  for _, p in ipairs(S.pinned) do if p == bid then return true end end
  return false
end

-- Ogni finestra dell'app è una scheda? Sì, salvo le app scelte in
-- ⚙︎ → Finestre separate (i browser sono sempre a finestre separate)
function perWindow(bid)
  return not S.joinWins[bid] and not floating(bid)
end

-- L'app aperta con questo bundle ID (nil se non è aperta). Molto più veloce
-- di hs.application.get, che per un'app chiusa la cerca anche per nome
-- (30-50 ms ogni volta: misurato sul Mac vero).
function appFor(bid)
  if not bid then return nil end
  return hs.application.applicationsForBundleID(bid)[1]
end

function screen() return hs.screen.primaryScreen() end

function later(fn) hs.timer.doAfter(0, fn) end

-- Spia di lentezza: Tabby fa tutto su un solo "filo", quindi un lavoro lento
-- fa scattare anche la tastiera. Se un lavoro supera SLOW_MS lo scrive in
-- console ("Tabby · lento: …"), al massimo una volta al minuto per lavoro.
SLOW_MS = 150
-- L'ora con i millesimi, per le righe di diagnosi sui tempi (es. schermo intero)
function clockMs()
  local t = hs.timer.secondsSinceEpoch()
  return os.date("%H:%M:%S", math.floor(t)) .. string.format(".%03d", math.floor((t % 1) * 1000))
end

-- segna la fine di un passaggio (per il dettaglio di "Tabby · lento")
function Tabby.step(name)
  local now = hs.timer.absoluteTime()
  if Tabby.steps then
    table.insert(Tabby.steps, {name = name, ms = (now - (Tabby.stepAt or now)) / 1e6})
  end
  Tabby.stepAt = now
end
function timed(name, fn)
  return function(...)
    T.appMs = {}   -- tempo speso a chiedere le finestre a ogni app (vedi standardWindows)
    local t0 = hs.timer.absoluteTime()
    T.steps, T.stepAt = {}, t0   -- passaggi segnati con T.step("nome")
    fn(...)
    local ms = (hs.timer.absoluteTime() - t0) / 1e6
    if ms > SLOW_MS then
      T.slowAt = T.slowAt or {}
      local now = hs.timer.secondsSinceEpoch()
      if not T.slowAt[name] or now - T.slowAt[name] > 60 then
        T.slowAt[name] = now
        -- l'app più lenta a rispondere, se ha pesato
        local worst, wms = nil, 0
        for b, v in pairs(T.appMs) do if v > wms then worst, wms = b, v end end
        local who = (worst and wms > 40) and string.format(" (più lenta a rispondere: %s %.0f ms)", worst, wms) or ""
        -- dove è andato il tempo: i passaggi segnati, dal più lungo
        local parts = {}
        for _, st in ipairs(T.steps or {}) do
          if st.ms >= 10 then table.insert(parts, string.format("%s %.0f", st.name, st.ms)) end
        end
        local detail = #parts > 0 and (" · passaggi (ms): " .. table.concat(parts, ", ")) or ""
        print(string.format("Tabby · lento: %s %.0f ms%s%s", name, ms, who, detail))
      end
    end
  end
end

-- Altezza della barra dei menu di macOS
function menuBarH()
  local s = screen()
  local d = s:frame().y - s:fullFrame().y
  if d > 0 and not T.fullscreen then
    hs.settings.set("tabbar.menuH", d)
    return d
  end
  local saved = hs.settings.get("tabbar.menuH")
  if saved then return saved end
  local ff = s:fullFrame()
  if (s:name() or ""):find("Built%-in") and ff.h / ff.w > 0.64 then return 37 end
  return 24
end

function isVertical()
  return S.position == "left" or S.position == "right"
end

-- La barra dei menu di macOS è impostata su "nascondi sempre"?
function detectMenuHidden()
  local ok, out = pcall(function()
    return (hs.execute("defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null") or "") ..
           (hs.execute("defaults -currentHost read NSGlobalDomain _HIHideMenuBar 2>/dev/null") or "")
  end)
  return ok and type(out) == "string" and out:match("1") ~= nil
end

-- Tabby deve stare nella fascia del notch? Automatico, o scelto a mano
-- (⚙︎ → Posizione di Tabby → Usa la fascia del notch).
function useNotchBand()
  if S.position ~= "top" then return false end
  if S.notchBand == "on" then return true end
  if S.notchBand == "off" then return false end
  return (T.notch ~= nil) and T.menuHidden
end

-- Area utile dello schermo (senza barra dei menu e Dock; a schermo intero: tutto).
-- Sui Mac col notch e la barra dei menu nascosta, macOS lascia comunque
-- libera la fascia del notch: Tabby ci sale sopra e la usa.
function baseRect()
  local s = screen()
  if T.fullscreen then return s:fullFrame() end
  local f = s:frame()
  if useNotchBand() then
    local ff = s:fullFrame()
    return {x = f.x, y = ff.y, w = f.w, h = f.y + f.h - ff.y}
  end
  return f
end

-- Dove sta Tabby in questo momento
-- Barra dei menu di macOS nascosta ("nascondi sempre"): quando scende (puntatore in
-- cima allo schermo) Tabby scende sotto di lei, come attaccata (23/10/2026, Daniele).
-- Vale con Tabby in alto e di lato; in basso non serve.
function menuFollow()
  return T.menuHidden == true and S.position ~= "bottom" and not S.autohide
end
-- L'altezza vera della barra dei menu (chiesta a macOS una volta)
function realMenuH()
  if T.realMenuH then return T.realMenuH end
  local h
  pcall(function()
    local a = hs.application.frontmostApplication()
    local mb = a and hs.axuielement.applicationElement(a):attributeValue("AXMenuBar")
    local s = mb and mb:attributeValue("AXSize")
    h = s and s.h
  end)
  if h and h > 10 and h < 60 then T.realMenuH = h; return h end
  return menuBarH()
end
function menuDownOffset()
  if T.menuDown and menuFollow() and not T.fullscreen then return realMenuH() end
  return 0
end

function barFrame()
  local R = baseRect()
  local p = S.position
  local off = menuDownOffset()
  if p == "bottom" then return {x = R.x, y = R.y + R.h - BAR_H, w = R.w, h = BAR_H} end
  if p == "left"   then return {x = R.x, y = R.y + off, w = SIDE_W, h = R.h - off} end
  if p == "right"  then return {x = R.x + R.w - SIDE_W, y = R.y + off, w = SIDE_W, h = R.h - off} end
  local y = R.y + off
  -- se appare col mouse e la barra dei menu scende anche lei, mettiti sotto
  if S.autohide and y == screen():fullFrame().y then y = y + menuBarH() end
  return {x = R.x, y = y, w = R.w, h = BAR_H}
end

-- Spazio dove stanno le app (tutto lo schermo meno Tabby)
function appArea()
  local f = screen():frame()
  if S.autohide then return f end
  local p = S.position
  if p == "bottom" then return hs.geometry.rect(f.x, f.y, f.w, f.h - BAR_H) end
  if p == "left"   then return hs.geometry.rect(f.x + SIDE_W, f.y, f.w - SIDE_W, f.h) end
  if p == "right"  then return hs.geometry.rect(f.x, f.y, f.w - SIDE_W, f.h) end
  -- in alto: le app partono subito sotto Tabby (anche se Tabby sta nella fascia del notch)
  local top = baseRect().y + BAR_H
  return hs.geometry.rect(f.x, top, f.w, f.y + f.h - top)
end

-- Finestra piccola: meno di metà larghezza e del 60% dell'altezza dello spazio
-- delle app. Per un browser è quasi sempre una finestrella (video in miniatura).
function T.isSmall(w)
  local f, A = w:frame(), appArea()
  return f.w < A.w * 0.5 and f.h < A.h * 0.6
end

-- Finestrella già riconosciuta: video in miniatura (T.minis) o finestra aperta
-- da un sito, come l'accesso con Google (T.popups). Non è una scheda, Tabby non
-- la ingrandisce, non la riduce e non la conta come finestra "vera".
function T.isFloating(w)
  local id = w:id()
  return (T.minis ~= nil and T.minis[id] ~= nil) or (T.popups ~= nil and T.popups[id] ~= nil)
end

-- Il "notch" (la tacca della fotocamera dei MacBook recenti).
-- Lo chiediamo a macOS: dove inizia e finisce, in coordinate dello schermo.
function detectNotch()
  local s  = screen()
  local ff = s:fullFrame()
  local ok, success, res = pcall(function(src) return hs.osascript.javascript(src) end, [[
    ObjC.import('AppKit');
    var out = '';
    try {
      var s = $.NSScreen.screens.objectAtIndex(0);
      var top = s.safeAreaInsets.top;
      if (top > 0) {
        out = s.auxiliaryTopLeftArea.size.width + ',' +
              s.auxiliaryTopRightArea.size.width + ',' + top;
      } else {
        out = 'none';
      }
    } catch (e) {}
    out;
  ]])
  T.notchInfo = "macOS: " .. tostring(ok and success and res or "nessuna risposta")
  if ok and success and res == "none" then
    return nil   -- macOS ha risposto: questo schermo non ha il notch
  end
  if ok and success and type(res) == "string" then
    local lw, rw = res:match("^([%d%.]+),([%d%.]+),")
    lw, rw = tonumber(lw), tonumber(rw)
    if lw and rw and lw + rw < ff.w then
      return {x1 = ff.x + lw, x2 = ff.x + ff.w - rw}
    end
  end
  -- macOS non ha dato misure: stima. I MacBook col notch hanno uno schermo
  -- più "alto" (circa 0,65) dei 16:10 senza notch (0,625).
  if (s:name() or ""):find("Built%-in") and ff.h / ff.w > 0.64 then
    T.notchInfo = T.notchInfo .. " → stimato"
    return {x1 = ff.x + ff.w / 2 - 105, x2 = ff.x + ff.w / 2 + 105}
  end
  return nil
end

-- Parte di Tabby (in coordinate della barra) coperta dal notch, se c'è
function notchZone(bf)
  if isVertical() or not useNotchBand() then return nil end
  if bf.y > screen():fullFrame().y + 2 then return nil end   -- Tabby è sotto: nessun problema
  local n = T.notch
  if not n then   -- forzato a mano ma non rilevato: notch stimato al centro
    local ff = screen():fullFrame()
    n = {x1 = ff.x + ff.w / 2 - 105, x2 = ff.x + ff.w / 2 + 105}
  end
  return {x1 = n.x1 - bf.x - 6, x2 = n.x2 - bf.x + 6}
end

-- Scrive nella console di Hammerspoon cosa ha rilevato Tabby
function logDiagnostics()
  local s = screen()
  print(string.format(
    "Tabby · schermo %s %.0fx%.0f · area utile da y=%.0f · notch: %s (%s) · barra menu nascosta: %s · fascia notch: %s (%s)",
    tostring(s:name()), s:fullFrame().w, s:fullFrame().h, s:frame().y,
    T.notch and string.format("%.0f-%.0f", T.notch.x1, T.notch.x2) or "no",
    tostring(T.notchInfo), tostring(T.menuHidden),
    tostring(useNotchBand()), tostring(S.notchBand)))
end

-- Rettangolo (in coordinate dello schermo) della zona k di uno schema
function zoneRect(layoutId, k)
  local A = appArea()
  local z = LAYOUTS[layoutId].zones[k]
  local G = ZONE_GAP
  return hs.geometry.rect(A.x + z[1] * A.w + G, A.y + z[2] * A.h + G,
                          z[3] * A.w - 2 * G, z[4] * A.h - 2 * G)
end

function icon(bid)
  if not bid then return nil end
  if T.icons[bid] == nil then
    T.icons[bid] = hs.image.imageFromAppBundle(bid) or false
  end
  return T.icons[bid] or nil
end

function smallIcon(bid)
  local img = icon(bid)
  return img and img:setSize({w = 16, h = 16}) or nil
end

-- App aperte "vere" (quelle che compaiono nel Dock)
function runningApps()
  local map, list = {}, {}
  for _, app in ipairs(hs.application.runningApplications()) do
    local bid = app:bundleID()
    if bid and app:kind() == 1 and not IGNORE[bid] and not map[bid] then
      map[bid] = app
      table.insert(list, app)
    end
  end
  return map, list
end

function appName(bid, app)
  return (app and app:name()) or hs.application.nameForBundleID(bid) or bid
end

-- Quali app hanno almeno una finestra aperta (anche nascosta o ridotta).
-- Il filtro finestre ricorda anche quelle su altre scrivanie.
function appsWithWindows()
  local set = {}
  if T.allWins then
    for _, w in ipairs(T.allWins:getWindows()) do
      local a = w:application()
      local b = a and a:bundleID()
      -- una finestra a schermo intero non conta: è fuori dai radar di Tabby
      if b and not w:isFullScreen() then set[b] = true end
    end
  end
  return set
end


-- (draw: definita più sotto o in un altro file)

function standardWindows(app)
  local t0 = hs.timer.absoluteTime()
  local out = {}
  for _, w in ipairs(app:allWindows()) do
    -- (a schermo intero no: è fuori dai radar di Tabby finché non torna normale)
    if w:isStandard() and not w:isFullScreen() then table.insert(out, w) end
  end
  if T.appMs then
    local b = app:bundleID() or "?"
    T.appMs[b] = (T.appMs[b] or 0) + (hs.timer.absoluteTime() - t0) / 1e6
  end
  return out
end
