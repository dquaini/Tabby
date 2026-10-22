-- =====================================================================
--  Tabby · osservatori.lua: cosa Tabby ascolta da macOS: app, finestre, Spotlight, schermo, batteria.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  OSSERVATORI
-- ---------------------------------------------------------------------

W = hs.application.watcher
T.appWatcher = W.new(function(_, event, app)
  if event == W.activated then
    hs.timer.doAfter(0.1, function() handleActive(app) end)
    hs.timer.doAfter(0.9, updateFullscreen)
  elseif event == W.launched then
    scheduleRebuild()
  elseif event == W.terminated then
    local still = {}
    for b in pairs(T.fsApps) do
      if appFor(b) then still[b] = true end
    end
    T.fsApps = still
    scheduleRebuild()
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
  if b and FLOATER[b] then
    placeFloater(a)
  elseif g then
    -- nuova finestra di un'app in un gruppo: nella sua zona (se il gruppo è attivo)
    hs.timer.doAfter(0.2, function()
      if T.memberOf[currentKey()] == g then layoutGroup(g) end
    end)
  elseif a and b == frontBid() then
    if not BROWSERS[b] and w:isStandard() then T.pickedWin = {id = w:id(), at = hs.timer.secondsSinceEpoch()} end
    -- una finestra piccola di un browser può essere una finestrella (video in
    -- miniatura): si decide dopo, quando il browser ha risposto
    if not (BROWSERS[b] and T.isSmall(w)) and not T.isFloating(w) then fitWindow(w) end
  end
  scheduleRebuild()
end)

-- Chiusa una finestra: se dell'app in primo piano restano solo finestre ridotte
-- a icona (una scheda alla volta), riapri l'ultima usata invece di lasciare il
-- desktop (es. finita una finestrella di accesso, o ⌘W su una finestra)
function T.restoreAfterClose()
  if not S.oneAtATime then return end
  local app = hs.application.frontmostApplication()
  local bid = app and app:bundleID()
  if not bid or not (BROWSERS[bid] or perWindow(bid)) or FLOATER[bid] then return end
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
  print("Tabby · chiusa una finestra di " .. tostring(app:name()) .. ": riapro «" .. tostring(pick:title()) .. "»")
  pick:unminimize()
  pick:focus()
end
T.allWins:subscribe(WF.windowDestroyed, function()
  scheduleRebuild()
  hs.timer.doAfter(0.3, T.restoreAfterClose)
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
T.browserTimer = hs.timer.doEvery(3, timed("controllo browser", function()
  if T.press or T.split or T.fedit then return end
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
T.badgeTimer = hs.timer.doEvery(3, timed("notifiche del Dock", function()
  local b = readDockBadges()
  local sig = badgeSig(b)
  if sig ~= T.badgeSig then
    T.badges, T.badgeSig = b, sig
    if T.bar then draw() end
  end
end))

T.allWins:subscribe(WF.windowFullscreened, function(w)
  if S.tabbyFullscreen and w then
    -- tasto verde: invece dello schermo intero di macOS, riempi lo
    -- spazio accanto a Tabby (o la zona, se l'app è in un gruppo)
    hs.timer.doAfter(0.3, function()
      w:setFullScreen(false)
      hs.timer.doAfter(0.9, function()
        local a = w:application()
        local g = a and T.memberOf[T.winKey[w:id()] or a:bundleID()]
        if g then layoutGroup(g) else fitWindow(w, true) end
        w:focus()
        updateFullscreen()
      end)
    end)
  else
    hs.timer.doAfter(0.8, updateFullscreen)
  end
end)

T.allWins:subscribe(WF.windowUnfullscreened, function(w)
  local a = w and w:application()
  if a and a:bundleID() then T.fsApps[a:bundleID()] = nil end
  hs.timer.doAfter(0.8, updateFullscreen)
end)

-- Cambio di scrivania (le app a schermo intero hanno la loro)
T.spaceWatcher = hs.spaces.watcher.new(function()
  hs.timer.doAfter(0.5, updateFullscreen)
end)
T.spaceWatcher:start()

-- Cambio di monitor o risoluzione
T.screenWatcher = hs.screen.watcher.new(function()
  T.notch = detectNotch()
  draw()
  if T.split then drawSplit() end
end)
T.screenWatcher:start()

-- Se cambi l'impostazione "nascondi la barra dei menu", Tabby si adegua
T.menuWatch = hs.timer.doEvery(10, function()
  local v = detectMenuHidden()
  if v ~= T.menuHidden then
    T.menuHidden = v
    draw()
    refit()
  end
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
function T.spotlightDim(on)
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
    -- macOS avvisa della chiusura di Spotlight con ~1 secondo di ritardo: finché
    -- il velo è acceso, Tabby controlla da sé 20 volte al secondo se Spotlight
    -- c'è ancora (costa 0,06 ms, misurato sul Mac vero)
    T.dimSince = hs.timer.secondsSinceEpoch()
    if T.dimPoll then T.dimPoll:stop() end
    T.dimPoll = hs.timer.doEvery(0.05, function()
      if hs.timer.secondsSinceEpoch() - T.dimSince < 0.15 then return end
      if not T.spotlightOpen() then T.spotlightDim(false) end
    end)
  elseif T.dim and T.dimOn then
    T.dim:hide()
    T.dimOn = false
    if T.dimPoll then T.dimPoll:stop(); T.dimPoll = nil end
  end
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
