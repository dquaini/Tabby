-- =====================================================================
--  Tabby · osservatori.lua: cosa Tabby ascolta da macOS: app, finestre, Spotlight, schermo, batteria.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  OSSERVATORI
-- ---------------------------------------------------------------------

-- Schermo intero: Tabby controlla subito e poi ancora durante l'animazione di
-- macOS (prima aspettava ~1 s: Tabby restava visibile, o tornava in ritardo)
function checkFullscreenSoon()
  updateFullscreen()
  for _, d in ipairs({0.25, 0.6, 1.1}) do hs.timer.doAfter(d, updateFullscreen) end
end

W = hs.application.watcher
T.appWatcher = W.new(function(_, event, app)
  if event == W.activated then
    hs.timer.doAfter(0.1, function() handleActive(app) end)
    checkFullscreenSoon()
  elseif event == W.launched then
    scheduleRebuild()
    -- un'app appena aperta (anche appena installata) ha un'icona nella barra dei menu?
    if app then hs.timer.doAfter(3, function() scanMenuBarApps(app) end) end
  elseif event == W.terminated then
    scheduleRebuild()
    if app and app:bundleID() and floating(app:bundleID()) then
      setFloatMode(app:bundleID(), false)
      hs.timer.doAfter(0, layoutFloaters)
    end
    -- chiusa l'app della scheda attiva (⌘Q, ✕ → Chiudi app): scheda accanto
    local b = app and app:bundleID()
    local snap = b and snapForApp(b)
    if snap then goNeighborSoon(snap, "chiusa l'app") end
  end
end)
T.appWatcher:start()

-- Osserva tutte le finestre "normali" di tutte le app
WF = hs.window.filter
T.allWins = WF.new(false):setDefaultFilter({})

T.allWins:subscribe(WF.windowCreated, function(w)
  local a = w and w:application()
  local b = a and a:bundleID()
  -- una cartella aspettava una finestra di quest'app (l'ha appena aperta lei)?
  local pb = b and T.pendingBind and T.pendingBind[b]
  if pb and w:isStandard() and hs.timer.secondsSinceEpoch() - pb.at < 8 then
    T.pendingBind[b] = nil
    T.itemWins[pb.bk] = w:id()
    T.itemWinsDirty = true
  end
  -- diagnosi: che finestra ha aperto un browser (es. le finestrelle di Meet)
  if b and BROWSERS[b] then
    local f, A = w:frame(), appArea()
    -- una finestra di browser che nasce stretta è una finestrella aperta dal sito
    -- (accesso con Google, pagamento…): non riduce le altre e non si ingrandisce
    local popup = f.w < A.w * 0.6
    if popup then T.popups = T.popups or {}; T.popups[w:id()] = true end
    if not popup and w:isStandard() then T.pickedWin = {id = w:id(), at = hs.timer.secondsSinceEpoch()} end
    print(string.format("Tabby · finestra nuova di %s «%s»: tipo=%s · normale=%s · %.0fx%.0f%s",
      BROWSERS[b].short, tostring(w:title()), tostring(w:subrole()), tostring(w:isStandard()), f.w, f.h,
      popup and " → finestrella (accesso/popup)" or ""))
  end
  -- (con le finestre separate ogni finestra nuova è una scheda nuova:
  -- non entra nel gruppo)
  local g = b and not BROWSERS[b] and not perWindow(b) and T.memberOf[b]
  if b and floating(b) then
    placeFloater(a)
  elseif g then
    -- nuova finestra di un'app in un gruppo: nella sua zona (se il gruppo è attivo)
    hs.timer.doAfter(0.2, function()
      if T.memberOf[currentKey()] == g then layoutGroup(g) end
    end)
  elseif a and b == frontBid() and not actionRecent(b) then
    if not BROWSERS[b] and w:isStandard() then T.pickedWin = {id = w:id(), at = hs.timer.secondsSinceEpoch()} end
    -- una finestra piccola di un browser può essere una finestrella (video in
    -- miniatura): si decide dopo, quando il browser ha risposto
    if not (BROWSERS[b] and T.isSmall(w)) and not T.isFloating(w) then fitWindow(w) end
  end
  scheduleRebuild()
end)

-- Chiusa una finestrella (accesso con Google, pagamento…: non è una scheda): se
-- dell'app in primo piano restano solo finestre ridotte a icona (una scheda alla
-- volta), riapri l'ultima usata invece di lasciare il desktop
function T.restoreAfterClose()
  if not S.oneAtATime then return end
  local app = hs.application.frontmostApplication()
  local bid = app and app:bundleID()
  if not bid or not (BROWSERS[bid] or perWindow(bid)) or floating(bid) then return end
  local wins = standardWindows(app)
  if #wins == 0 then return end
  for _, w in ipairs(wins) do
    -- c'è ancora una finestra vera in vista (miniature e finestrelle non contano)
    if not w:isMinimized() and not T.isFloating(w) then return end
  end
  -- l'ultima usata tra quelle ridotte (se non si sa, la prima)
  local pick
  local h = (T.winHist or {})[bid] or {}
  for i = #h, 1, -1 do
    for _, w in ipairs(wins) do
      if not pick and w:id() == h[i] and w:isMinimized() then pick = w end
    end
  end
  if not pick then
    for _, w in ipairs(wins) do if not pick and w:isMinimized() then pick = w end end
  end
  if not pick then return end
  print("Tabby · chiusa una finestrella di " .. tostring(app:name()) .. ": riapro «" .. tostring(pick:title()) .. "»")
  pick:unminimize()
  pick:focus()
end

-- Chiusa una finestra: se era della scheda attiva → scheda accanto (in qualsiasi
-- modo l'hai chiusa: pallino rosso, ⌘W, ✕, ⌃⌥W); se era una finestrella → si
-- torna alla finestra di prima
T.allWins:subscribe(WF.windowDestroyed, function(w)
  local ok, id = pcall(function() return w:id() end)
  -- una finestrella (accesso con Google…) non conta come scheda: si torna a quella di prima
  local popup = ok and id and T.popups and T.popups[id]
  local snap = ok and id and not popup and snapForWin(id)
  if popup then T.popups[id] = nil end
  scheduleRebuild()
  if snap then goNeighborSoon(snap, "chiusa la finestra")
  else hs.timer.doAfter(0.3, T.restoreAfterClose) end
end)

-- Ridotta a icona col pallino giallo (o ⌘M): come chiuderla, si passa alla scheda
-- accanto; la scheda resta sulla barra e cliccandola la finestra torna. Le
-- riduzioni fatte da Tabby stessa (una scheda alla volta, scrivania) non contano.
T.allWins:subscribe(WF.windowMinimized, function(w)
  local ok, id = pcall(function() return w:id() end)
  if not ok or not id then return end
  local mine = T.selfMin[id]
  T.selfMin[id] = nil
  if mine and hs.timer.secondsSinceEpoch() - mine < 3 then return end
  local snap = snapForWin(id)
  if snap then goNeighborSoon(snap, "ridotta col giallo") end
end)

-- Cambio di finestra dentro la stessa app (es. da un documento all'altro,
-- o da una webapp all'altra con ⌘`): aggiorna la scheda attiva
T.focusTimer = hs.timer.delayed.new(0.15, function()
  local f = hs.application.frontmostApplication()
  local b = f and f:bundleID()
  if b and (BROWSERS[b] or (perWindow(b) and currentKey() ~= T.lastKey)) then
    handleActive(f)
  else
    draw()
  end
end)
T.allWins:subscribe(WF.windowFocused, function() T.focusTimer:start() end)

-- Il nome di una finestra-scheda è il suo titolo: se cambia, ridisegna
T.allWins:subscribe(WF.windowTitleChanged, function() scheduleRebuild() end)

-- Browser: titoli e siti cambiano mentre navighi → ricontrolla ogni 3 secondi
-- se ne stai usando uno, ogni 15 se sono in secondo piano (consumo: era la voce
-- più pesante di Tabby da ferma, misurato il 23/10/2026)
T.browserTimer = hs.timer.doEvery(3, timed("controllo browser", function()
  if T.press or T.split or T.fedit then return end
  local now = hs.timer.secondsSinceEpoch()
  if not BROWSERS[frontBid() or ""] and now - (T.lastBrowserCheck or 0) < 15 then return end
  T.lastBrowserCheck = now
  local changed = refreshBrowsers(); T.step("browser")
  if changed then rebuildTabs(); T.step("schede"); draw(); T.step("disegno") end
end))

-- Notifiche: ricontrolla i numerini del Dock ogni 3 secondi
function badgeSig(b)
  local parts = {}
  for k, v in pairs(b) do table.insert(parts, k .. "=" .. v) end
  table.sort(parts)
  return table.concat(parts, ",")
end
T.badgeTimer = hs.timer.doEvery(5, timed("notifiche del Dock", function()
  local b = readDockBadges()
  local sig = badgeSig(b)
  if sig ~= T.badgeSig then
    T.badges, T.badgeSig = b, sig
    if T.bar then draw() end
  end
end))

-- Tasto verde: lo schermo intero normale di macOS (l'opzione "Schermo intero con
-- Tabby visibile" è stata tolta il 23/10/2026: non funzionava con tutte le app;
-- da riprendere più avanti, vedi roadmap)
T.allWins:subscribe(WF.windowFullscreened, function() checkFullscreenSoon() end)
T.allWins:subscribe(WF.windowUnfullscreened, function() checkFullscreenSoon() end)

-- Cambio di scrivania (le app a schermo intero hanno la loro)
T.spaceWatcher = hs.spaces.watcher.new(function()
  print("Tabby · scrivania cambiata alle " .. clockMs())
  checkFullscreenSoon()
end)

-- Clic sul pallino verde di una finestra = schermo intero in arrivo: Tabby si fa
-- da parte subito (vedi anticipateFullscreen). Il controllo costa poco: si
-- guarda il pallino solo se il clic è nell'angolo in alto a sinistra della
-- finestra attiva.
T.fsClickTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(e)
  if T.fullscreen then return false end
  local p = e:location()
  pcall(function()
    local w = hs.window.focusedWindow()
    local f = w and w:frame()
    if not f or p.x < f.x or p.x > f.x + 120 or p.y < f.y or p.y > f.y + 60 then return end
    local btn = hs.axuielement.windowElement(w):attributeValue("AXFullScreenButton")
    local bp, bs = btn and btn:attributeValue("AXPosition"), btn and btn:attributeValue("AXSize")
    if bp and bs and p.x >= bp.x and p.x <= bp.x + bs.w and p.y >= bp.y and p.y <= bp.y + bs.h then
      anticipateFullscreen("pallino verde")
    end
  end)
  return false
end)
T.fsClickTap:start()

-- Tasto destro su una scheda di Tabby: menu con «Rinomina la scheda…»
T.rightTap = hs.eventtap.new({hs.eventtap.event.types.rightMouseDown}, function(e)
  local ok, p = pcall(function() return e:location() end)
  if not ok or not p then p = hs.mouse.absolutePosition() end
  local i = tabAtPoint(p)
  if not i then return false end
  later(function() openTabContextMenu(i, {x = p.x, y = p.y}) end)
  return true   -- l'app sotto non riceve il clic
end)
T.rightTap:start()

-- Un clic può portare una finestra sopra un'app veloce: Tabby la rimette sopra
T.floatTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function()
  if next(T.floatMode) then hs.timer.doAfter(0.08, raiseFloaters) end
  return false
end)
T.floatTap:start()
T.spaceWatcher:start()

-- Notifiche di macOS (23/10/2026, Daniele): non sopra Tabby. macOS le disegna in una
-- finestra trasparente grande come lo schermo (visto su macOS 26), che si può spostare:
-- con Tabby in alto scende sotto Tabby, con Tabby a destra va alla sua sinistra.
function notificationOffset()
  if T.fullscreen or S.autohide or T.visible == false then return 0, 0 end
  local bf, ff = barFrame(), screen():fullFrame()
  if S.position == "top" then return 0, math.max(0, bf.y + bf.h - ff.y) end
  if S.position == "right" then return -bf.w, 0 end
  return 0, 0
end
function placeNotifications(w)
  pcall(function()
    local ff = screen():fullFrame()
    local f = w:frame()
    if f.w < ff.w * 0.9 then return end   -- solo la finestra grande delle notifiche
    local dx, dy = notificationOffset()
    local el = hs.axuielement.windowElement(w)
    local want = {x = ff.x + dx, y = ff.y + dy}
    local p = el:attributeValue("AXPosition")
    if p and math.abs(p.x - want.x) < 1 and math.abs(p.y - want.y) < 1 then return end
    el:setAttributeValue("AXPosition", want)
    local msg = string.format("Tabby · notifiche spostate di %d, %d (accanto a Tabby)", dx, dy)
    if T.ncDiag ~= msg then T.ncDiag = msg; print(msg) end
  end)
end
T.ncFilter = WF.new(false):setAppFilter("Notification Center", {}):setAppFilter("Centro Notifiche", {})
T.ncFilter:subscribe({WF.windowCreated, WF.windowVisible}, placeNotifications)

-- Cambio di monitor o risoluzione
T.screenWatcher = hs.screen.watcher.new(function()
  T.notch = detectNotch()
  draw()
  if T.split then drawSplit() end
end)
T.screenWatcher:start()

-- Se cambi l'impostazione "nascondi la barra dei menu", Tabby si adegua
T.menuWatch = hs.timer.doEvery(30, function()
  local v = detectMenuHidden()
  if v ~= T.menuHidden then
    T.menuHidden = v
    draw()
    refit()
  end
  local d = readDockPrefs()
  if T.dockPrefs == nil or d.autohide ~= T.dockPrefs.autohide or d.side ~= T.dockPrefs.side then
    T.dockPrefs = d
    T.updateMouseTimer()
  end
  T.dockPrefs = d
end)

-- Batteria: ridisegna quando cambia carica o alimentazione
T.batWatcher = hs.battery.watcher.new(function()
  T.readBattery()
  if T.bar then draw() end
end)
T.batWatcher:start()

-- Spotlight: quando si apre, lo sfondo (app e Tabby) si oscura con un velo blu
-- scuro; quando si chiude, il velo sparisce. Il velo non prende i clic: un clic
-- fuori da Spotlight lo chiude come sempre.
-- Il velo scuro sotto Spotlight e sotto i pannelli delle azioni rapide (chat
-- di Claude, ricerca di Notion). isOver() dice quando toglierlo: Tabby lo
-- controlla da sé 20 volte al secondo (macOS avvisa con ~1 s di ritardo).
function T.veil(on, isOver)
  if on and S.spotlightDim then
    if not T.dim then
      T.dim = hs.canvas.new(screen():fullFrame())
      T.dim:level(hs.canvas.windowLevels.floating)
      T.dim:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
      T.dim:replaceElements({{type = "rectangle", action = "fill",
        fillColor = {hex = "#0B0D12", alpha = 0.85}}})   -- abbastanza da non leggere il testo dietro
    end
    if T.dimOn then return end   -- Spotlight manda due segnali ("creata", "visibile")
    -- niente dissolvenza: due dissolvenze ravvicinate lasciavano il velo
    -- trasparente (alpha 0, visto sul Mac vero)
    T.dim:frame(screen():fullFrame())
    T.dim:alpha(1)
    T.dim:show()
    if T.bar then T.dim:orderAbove(T.bar) end
    T.dimOn = true
    T.veilOver = isOver
    T.dimSince = hs.timer.secondsSinceEpoch()
    if T.dimPoll then T.dimPoll:stop() end
    T.dimPoll = hs.timer.doEvery(0.05, function()
      local age = hs.timer.secondsSinceEpoch() - T.dimSince
      if age < 0.15 then return end
      -- (dopo 10 minuti si toglie comunque: rete di sicurezza)
      if age > 600 or (T.veilOver and T.veilOver()) then T.veil(false) end
    end)
  elseif T.dim and T.dimOn then
    T.dim:hide()
    T.dimOn = false
    if T.dimPoll then T.dimPoll:stop(); T.dimPoll = nil end
  end
end

-- Spotlight: velo finché Spotlight è aperto
function T.spotlightDim(on)
  T.veil(on, function() return not T.spotlightOpen() end)
end

-- Spotlight è aperto? Lo si capisce dalla finestra attiva: mentre è aperto è
-- la sua; appena si chiude torna subito a quella della tua app. (Contare le sue
-- finestre non basta: da chiuso ne tiene una ancora per circa un secondo.)
function T.spotlightOpen()
  local ok, open = pcall(function()
    local w = hs.window.focusedWindow()
    local a = w and w:application()
    return a ~= nil and a:bundleID() == "com.apple.Spotlight"
  end)
  return ok and open
end
T.spotFilter = WF.new("Spotlight")
T.spotFilter:subscribe({WF.windowCreated, WF.windowVisible}, function() T.spotlightDim(true) end)
T.spotFilter:subscribe({WF.windowDestroyed, WF.windowNotVisible}, function() T.spotlightDim(false) end)


-- ---------------------------------------------------------------------
--  GESTI DEL TRACKPAD: tre dita verso sinistra = scheda dopo, verso destra =
--  scheda prima (come le scrivanie di macOS). Tabby legge i tocchi dagli eventi
--  "gesture" (esplorato sul Mac il 23/10/2026: arrivano con 1-4 dita). Il gesto
--  va tolto a macOS (Impostazioni → Trackpad → Altri gesti), se no lo fanno
--  entrambi. Un solo cambio di scheda per gesto.
-- ---------------------------------------------------------------------
GESTURE_MOVE = 0.15   -- spostamento delle dita (frazione della larghezza del trackpad)

-- La posizione media orizzontale delle dita appoggiate (nil, 0 se nessuna)
function touchesX(touches)
  local sum, n = 0, 0
  for _, t in ipairs(touches or {}) do
    local p = t.normalizedPosition
    local ph = tostring(t.phase or "")
    if p and p.x and ph ~= "ended" and ph ~= "cancelled" then sum, n = sum + p.x, n + 1 end
  end
  return n > 0 and sum / n or nil, n
end

T.gestureTap = hs.eventtap.new({hs.eventtap.event.types.gesture}, function(e)
  if not S.gestures then return false end
  local ok, touches = pcall(function() return e:getTouches() end)
  if not ok or type(touches) ~= "table" then return false end
  local x, n = touchesX(touches)
  if n ~= 3 then T.swipe = nil; return false end   -- finito, o un gesto con altre dita
  if not T.swipe then
    T.swipe = {x0 = x, done = false}
    if not T.gestureDiag then   -- la prima volta: cosa c'è in un tocco (per la diagnosi)
      T.gestureDiag = true
      local keys = {}
      for k in pairs(touches[1] or {}) do table.insert(keys, tostring(k)) end
      table.sort(keys)
      print("Tabby · gesti: tre dita viste (un tocco ha: " .. table.concat(keys, ", ") .. ")")
    end
    return false
  end
  if not T.swipe.done and math.abs(x - T.swipe.x0) > GESTURE_MOVE then
    T.swipe.done = true
    local delta = (x < T.swipe.x0) and 1 or -1   -- dita verso sinistra → scheda dopo
    later(function() switchRelative(delta) end)
  end
  return false
end)
T.gestureTap:start()
