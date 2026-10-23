-- =====================================================================
--  Tabby · finestre.lua: adattare e nascondere le finestre, passare da una scheda all'altra.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  FINESTRE
-- ---------------------------------------------------------------------

function hasFullscreen(app)
  for _, w in ipairs(app:allWindows()) do
    if w:isFullScreen() then return true end
  end
  return false
end


-- (layoutGroup: definita più sotto o in un altro file)

function frontBid()
  local f = hs.application.frontmostApplication()
  return f and f:bundleID()
end

-- La scheda di quello che stai guardando: la finestra in primo piano, se è
-- una scheda a sé; altrimenti l'app (app con le finestre in una scheda sola)
function currentKey()
  local bid = frontBid()
  if bid then
    local w = hs.window.focusedWindow()
    local k = w and T.winKey[w:id()]
    if k then return k end
  end
  return bid
end

-- Adatta una finestra allo spazio accanto a Tabby
function fitWindow(w, force)
  if not w or (not S.fit and not force) then return end
  if not w:isStandard() or w:isFullScreen() then return end
  if T.isFloating(w) then return end   -- finestrella (video in miniatura, accesso…)
  local a = w:application()
  local b = a and a:bundleID()
  -- mai toccare app veloci e finestre di Hammerspoon (console, memo)
  if b and (floating(b) or IGNORE[b]) then return end
  local s = w:screen()
  if not s or s:id() ~= screen():id() then return end
  -- già della misura giusta? Allora niente: ogni ridimensionamento è una
  -- richiesta a macOS, lenta se l'app è impegnata (Chrome durante Meet)
  local f, A = w:frame(), appArea()
  if math.abs(f.x - A.x) < 1 and math.abs(f.y - A.y) < 1
     and math.abs(f.w - A.w) < 1 and math.abs(f.h - A.h) < 1 then return end
  w:setFrame(A)
end

function fitApp(app)
  if not app then return end
  local front = hs.application.frontmostApplication()
  if front and front:pid() == app:pid() then
    -- in primo piano c'è una scheda di un gruppo: va nella sua zona
    local g = T.memberOf[currentKey()]
    if g then layoutGroup(g); return end
  end
  for _, w in ipairs(app:allWindows()) do fitWindow(w) end
end

-- Nasconde tutte le app tranne quelle in "keep"
function hideOthers(keep)
  if not S.oneAtATime then return end
  local _, list = runningApps()
  for _, app in ipairs(list) do
    local b = app:bundleID()
    -- un browser con una finestrella aperta (video in miniatura di Meet) non si
    -- nasconde, se no sparirebbe anche lei
    -- (le app veloci aperte restano in vista, sopra, finché non premi Esc)
    if not keep[b] and not app:isHidden() and not hasFullscreen(app)
       and not (T.minisOf and T.minisOf[b]) and not floating(b) then
      app:hide()
    end
  end
end

-- Una scheda alla volta, anche dentro la stessa app: macOS nasconde solo app
-- intere, quindi le altre finestre-scheda delle app in "apps" si riducono a
-- icona (tornano quando le scegli). keepIds = finestre da lasciare in vista.
-- Mai la miniatura di Meet, mai le app con le finestre in una scheda sola.
function minimizeSiblings(apps, keepIds)
  if not S.oneAtATime then return end
  for bid in pairs(apps) do
    if not floating(bid) and (BROWSERS[bid] or perWindow(bid)) then
      local app = appFor(bid)
      if app then
        for _, w in ipairs(standardWindows(app)) do
          if not keepIds[w:id()] and not w:isMinimized()
             and not T.isFloating(w) then
            print(string.format("Tabby · una scheda alla volta: riduco «%s» di %s",
              tostring(w:title()), tostring(app:name())))
            T.selfMin[w:id()] = hs.timer.secondsSinceEpoch()   -- (non è il pallino giallo)
            w:minimize()
          end
        end
      end
    end
  end
end

-- Mette ogni scheda del gruppo nella sua zona e nasconde le altre app.
-- Una scheda può essere un'app intera o una singola finestra di un browser.
-- bring = porta davanti le finestre (solo quando scegli la vista divisa: farlo
-- a ogni cambio di finestra innescava un ping-pong con due finestre dello stesso
-- browser, che "vibravano" — 23/10/2026, due finestre di Tally)
-- Ritorna true se ha dovuto spostare qualcosa.
function sameFrame(a, b)
  return math.abs(a.x - b.x) < 2 and math.abs(a.y - b.y) < 2 and math.abs(a.w - b.w) < 2 and math.abs(a.h - b.h) < 2
end
layoutGroup = function(g, bring)
  local keep, winApps, keepIds = {}, {}, {}
  local moved = false
  for k, key in ipairs(g.members) do
    local bid = T.keyBid[key] or key
    keep[bid] = true
    local app = appFor(bid)
    if app and LAYOUTS[g.layout].zones[k] then
      if app:isHidden() then app:unhide() end
      local r = zoneRect(g.layout, k)
      local w = T.keyWin[key]
      if w then
        winApps[bid] = true
        keepIds[w:id()] = true
        if w:isMinimized() then w:unminimize() end
      end
      local wins = w and {w} or standardWindows(app)
      for _, x in ipairs(wins) do
        if not x:isFullScreen() and not x:isMinimized() then
          -- già al suo posto? Niente richieste a macOS
          if not sameFrame(x:frame(), r) then x:setFrame(r); moved = true end
          if w and bring then x:raise() end   -- davanti alle altre finestre dello stesso browser
        end
      end
    end
  end
  hideOthers(keep)
  -- le altre finestre delle stesse app (es. le altre finestre di Chrome) si riducono
  minimizeSiblings(winApps, keepIds)
  if moved then
    T.layoutCount = (T.layoutCount or 0) + 1   -- (per i test: quante volte ha spostato)
  end
  return moved
end


-- Ricostruzione "ritardata": se arrivano tanti eventi insieme, la fa una volta sola
T.rebuildTimer = hs.timer.delayed.new(0.3, timed("ricostruzione schede", function()
  refreshBrowsers(); T.step("browser")
  rebuildTabs();     T.step("schede")
  draw();            T.step("disegno")
end))
function scheduleRebuild() T.rebuildTimer:start() end

-- È arrivata la risposta di un browser (vedi askBrowser): ricostruisci
-- senza fare un'altra domanda
onBrowserAnswer = function()
  if refreshBrowsers(false) then rebuildTabs(); draw() end
end

function isTabApp(app)
  if not app then return false end
  local bid = app:bundleID()
  return bid and not IGNORE[bid] and app:kind() == 1
end

-- L'app in primo piano è a schermo intero?
-- Schermo intero (23/10/2026, idea di Daniele): una finestra a schermo intero
-- esce dai radar di Tabby (non è una scheda) e, mentre la guardi, Tabby non si
-- vede; quando torna normale rientra come scheda.
-- Anticipo: hai appena chiesto lo schermo intero (pallino verde o ⌃⌘F): Tabby
-- sparisce subito, senza aspettare la fine dell'animazione di macOS. Se dopo 2 s
-- lo schermo intero non c'è, ricompare.
function anticipateFullscreen(how)
  if T.fullscreen then return end
  T.fsHintUntil = hs.timer.secondsSinceEpoch() + 2
  print("Tabby · schermo intero chiesto (" .. how .. ") alle " .. clockMs() .. ": Tabby si fa da parte")
  draw()
  hs.timer.doAfter(2.1, function()
    T.fsHintUntil = nil
    updateFullscreen()
    draw()
  end)
end

function updateFullscreen()
  -- prima si chiede a macOS che scrivania stai guardando: se è quella di
  -- un'app a schermo intero lo sa subito (0,4 ms), senza aspettare l'avviso
  -- sulla finestra, che arriva ~1 s dopo la fine dell'animazione
  local okS, kind = pcall(function() return hs.spaces.spaceType(hs.spaces.focusedSpace()) end)
  local w = hs.window.focusedWindow()
  local fs = (okS and kind == "fullscreen") or ((w ~= nil) and w:isFullScreen()) or false
  if fs ~= T.fullscreen then
    T.fullscreen = fs
    print("Tabby · schermo intero " .. (fs and "acceso" or "spento") .. " alle " .. clockMs() ..
          (fs and ": Tabby si fa da parte" or ": Tabby torna"))
    scheduleRebuild()
    draw()
  end
end

-- Le app veloci aperte stanno sopra le altre finestre (macOS non lo permette a
-- un'app di un altro: Tabby le riporta davanti a ogni cambio di scheda e a ogni
-- clic). Solo se sono davvero coperte, così macOS non annuncia cambi di finestra
-- a vuoto.
function floaterCovered(w)
  local ok, res = pcall(function()
    local fw = hs.window.focusedWindow()
    for _, x in ipairs(hs.window.orderedWindows()) do
      if x:id() == w:id() then return false end      -- viene prima: è sopra
      if fw and x:id() == fw:id() then return true end
    end
    return true
  end)
  return not ok or res
end
function raiseFloaters()
  local fb = frontBid()
  for bid in pairs(T.floatMode) do
    local app = appFor(bid)
    if app and not app:isHidden() and bid ~= fb then
      for _, w in ipairs(app:allWindows()) do
        if not w:isMinimized() and floaterCovered(w) then w:raise() end
      end
    end
  end
end
function raiseFloatersSoon()
  if next(T.floatMode) then hs.timer.doAfter(0.15, raiseFloaters) end
end

-- App veloci: piccole, in alto a destra
-- (con più finestre, es. più post-it, si dispongono a cascata)
function placeFloater(app)
  if not app then return end
  local area = appArea()
  local wins = {}
  for _, w in ipairs(app:allWindows()) do
    if not w:isMinimized() and not w:isFullScreen() then table.insert(wins, w) end
  end
  table.sort(wins, function(a, b) return a:id() < b:id() end)
  -- misura fissa per le app veloci che ce l'hanno (es. il Calendario)
  local size
  for _, q in ipairs(QUICK) do if q.bid == app:bundleID() and q.w then size = q end end
  for n, w in ipairs(wins) do
    local fr = w:frame()
    local off = (n - 1) * 26
    if size then
      w:setFrame({x = area.x + area.w - size.w - 12 - off, y = area.y + 12 + off, w = size.w, h = size.h})
      -- l'app può rifiutare una misura troppo piccola e allargarsi da sola: si
      -- rilegge la misura vera e si riporta la finestra dentro lo schermo
      local got = w:frame()
      if math.abs(got.w - size.w) > 1 or math.abs(got.h - size.h) > 1 then
        w:setTopLeft({x = area.x + area.w - got.w - 12 - off, y = area.y + 12 + off})
      end
    else
      w:setTopLeft({x = area.x + area.w - fr.w - 12 - off, y = area.y + 12 + off})
    end
  end
  local msg = string.format("Tabby · %s: %d finestre messe in alto a destra",
                            tostring(app:name()), #wins)
  if T.floaterDiag ~= msg then T.floaterDiag = msg; print(msg) end
end


-- ---------------------------------------------------------------------
--  PASSARE DA UNA SCHEDA ALL'ALTRA
-- ---------------------------------------------------------------------

-- Quando un'app passa in primo piano (o cambia finestra in primo piano)
handleActive = timed("cambio di scheda", function(app)
  local bid = app and app:bundleID()
  local drawn = false
  if bid and floating(bid) then
    -- app veloce: non nasconde niente, si mette in alto a destra
    placeFloater(app)
    draw()
    return
  end
  local fsw = hs.window.focusedWindow()
  if fsw and fsw:isFullScreen() then
    updateFullscreen()   -- finestra a schermo intero: Tabby si fa da parte
    return
  end
  if bid and actionRecent(bid) then
    -- azione rapida (chat di Claude, ricerca di Notion): il pannello si apre
    -- sopra quello che stai facendo, che non va nascosto
    draw()
    return
  end
  if T.desktopMode then
    -- sulla scrivania il Finder è in primo piano: va bene così
    if bid == FINDER or not isTabApp(app) then draw(); return end
    -- macOS a volte "rimbalza" su un'altra app subito dopo: la rimandiamo giù
    if T.desktopAt and hs.timer.secondsSinceEpoch() - T.desktopAt < 1.2 then
      app:hide()
      return
    end
    T.desktopMode = false
  end
  if isTabApp(app) then
    local key = currentKey()
    if key ~= T.lastKey then
      T.prevKey = T.lastKey   -- per ⌃⌥Tab (torna alla scheda di prima)
      T.lastKey = key
    end
    -- per ogni cartella, l'ultima scheda usata (ci si torna entrando)
    local gk = T.memberOf[key]
    local cf = T.tabFolder[key] or (gk and T.tabFolder["g:" .. gk.id])
    if cf then T.folderLast[cf.id] = key end
    local g = T.memberOf[key]
    T.step("preparazione")
    if g then
      -- scheda di un gruppo: si mostra tutto il gruppo, diviso come l'avevi messo
      g.focus = key
      layoutGroup(g)
      T.step("vista divisa")
      hs.timer.doAfter(0.6, function()
        if T.memberOf[currentKey()] == g then layoutGroup(g) end
      end)
    else
      hideOthers({[bid] = true})
      T.step("nascondi altre app")
      -- La barra si ridisegna SUBITO, prima di toccare le finestre: dopo averle
      -- ridimensionate l'app è occupata e ogni domanda a lei (es. "qual è la
      -- finestra attiva?") aspetta in coda. Era ~600 ms a ogni cambio di scheda.
      draw()
      T.step("disegno")
      drawn = true
      -- una scheda alla volta: le altre finestre della stessa app si riducono
      -- (solo se la finestra attiva è una finestra "vera", non un dialogo o una
      -- finestrella appena aperta che potrebbe essere il video di Meet)
      local fw = hs.window.focusedWindow()
      local fa = fw and fw:application()
      -- …ma solo se quella finestra l'hai scelta tu (scheda di Tabby, scorciatoia)
      -- o l'hai appena aperta (⌘N). Se l'attenzione la sposta macOS (es. mentre
      -- riduce una finestra) niente: si innescava un ping-pong di finestre che
      -- comparivano e sparivano (22/10/2026)
      local pk = T.pickedWin
      local picked = fw and pk and pk.id == fw:id() and hs.timer.secondsSinceEpoch() - pk.at < 3
      if picked and fa and fa:bundleID() == bid and fw:isStandard() and not T.isFloating(fw) then
        T.pickedWin = nil
        -- (ricorda l'ordine d'uso delle finestre: serve se poi ne chiudi una)
        T.winHist = T.winHist or {}
        local h = T.winHist[bid] or {}
        for i = #h, 1, -1 do if h[i] == fw:id() then table.remove(h, i) end end
        table.insert(h, fw:id())
        T.winHist[bid] = h
        if not (BROWSERS[bid] and T.isSmall(fw)) then
          minimizeSiblings({[bid] = true}, {[fw:id()] = true})
        end
      end
      T.step("riduci finestre")
      fitApp(app)
      T.step("adatta finestre")
      -- alcune app creano le finestre con un attimo di ritardo
      hs.timer.doAfter(0.6, function() fitApp(app); raiseFloaters() end)
      raiseFloatersSoon()
    end
  end
  if not drawn then
    draw()
    T.step("disegno")
  end
end)

function afterFocus()
  hs.timer.doAfter(0.2, function()
    handleActive(hs.application.frontmostApplication())
  end)
end

function focusBid(bid)
  T.desktopMode = false
  T.focusSeq = (T.focusSeq or 0) + 1   -- annulla i controlli di una scelta precedente
  -- come cliccare l'icona nel Dock: apre l'app o riapre una finestra
  hs.application.launchOrFocusByBundleID(bid)
  afterFocus()
end

-- Porta davanti una finestra precisa (per le schede dei browser)
function focusWin(e)
  T.desktopMode = false
  local app, w = e.app, e.win
  -- l'hai scelta tu: le altre finestre della stessa app si possono ridurre
  if w then T.pickedWin = {id = w:id(), at = hs.timer.secondsSinceEpoch()} end
  if app and app:isHidden() then app:unhide() end
  if w:isMinimized() then w:unminimize() end
  w:focus()
  afterFocus()
  -- La tastiera deve arrivare davvero a questa finestra (⌘F, scrivere…): se la
  -- finestra si stava riaprendo dall'icona, macOS può ignorare la prima
  -- richiesta. Si ricontrolla due volte e, se serve, si ridà l'attenzione.
  local wid = w:id()
  T.focusSeq = (T.focusSeq or 0) + 1
  local seq = T.focusSeq
  for _, d in ipairs({0.25, 0.6}) do
    hs.timer.doAfter(d, function()
      if T.focusSeq ~= seq then return end   -- nel frattempo hai scelto altro
      local f = hs.window.focusedWindow()
      if (not f or f:id() ~= wid) and w:application() and not w:isMinimized() then
        print(string.format("Tabby · la tastiera non era su «%s»: gliela ridò", tostring(w:title())))
        w:focus()
      end
    end)
  end
end

function focusKey(key)
  local e = key and T.cand[key]
  if e and e.win then focusWin(e)
  elseif key then focusBid(T.keyBid[key] or key) end
end

function showGroup(g)
  T.desktopMode = false
  layoutGroup(g, true)
  focusKey(g.focus or g.members[1])
  hs.timer.doAfter(0.35, function() layoutGroup(g); draw() end)
end

-- Passa alla scheda numero i
function switchTo(i)
  local t = T.tabs[i]
  if not t then return end
  if t.folder then FD.enterFolder(t.folder)
  elseif t.group then showGroup(t.group)
  elseif t.win then focusWin(t)
  else focusBid(t.bid) end
end

-- Indice della scheda attiva (nil se nessuna)
function activeIndex()
  if T.desktopMode then return nil end
  local key = currentKey()
  if not key then return nil end
  local g = T.memberOf[key]
  local bid = frontBid()
  -- nella vista normale, una scheda di una cartella attiva = la scheda-cartella
  local f = not T.viewFolder and (T.tabFolder[key] or (g and T.tabFolder["g:" .. g.id]))
  local fallback
  for i, t in ipairs(T.tabs) do
    if f then
      if t.folder == f then return i end
    elseif g then
      if t.group == g then return i end
    elseif t.key == key then
      return i
    elseif not fallback and t.bid == bid then
      fallback = i
    end
  end
  return fallback
end

-- Scheda precedente / successiva (⌃⌥ frecce), gira in tondo
function switchRelative(delta)
  local n = #T.tabs
  if n == 0 then return end
  local i = activeIndex() or (delta > 0 and 0 or 1)
  switchTo(((i - 1 + delta) % n) + 1)
end

-- Torna alla scheda usata prima (⌃⌥Tab)
function toggleLastApp()
  local k = T.prevKey
  if not k then return end
  if T.cand[k] or appFor(T.keyBid[k] or k) then focusKey(k) end
end
