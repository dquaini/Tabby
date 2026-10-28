-- =====================================================================
--  Tabby · concentrazione.lua: la Concentrazione (24/10/2026, Daniele).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
--
--  ⚡︎ → «Concentrazione…»: lo sfondo si oscura (la barra no) e in centro una
--  finestra chiede quanti minuti e cosa tieni. Le schede si scelgono cliccandole
--  nella barra: diventano gialle. «Inizia» e:
--    · Non disturbare si accende (se ci sono i comandi rapidi, vedi FOCUS_DND_ON)
--    · al posto della batteria c'è il tempo che manca, con una barretta
--    · le altre app spariscono (nascoste, NON chiuse: niente «Vuoi salvare?», la
--      sessione di Windows App non cade) e le altre finestre si riducono; nella
--      barra restano solo le schede scelte (⌃⌥1, 2, 3 sono proprio loro)
--    · se apri un'altra app, Tabby chiede prima («Aprire Slack lo stesso?»);
--      i Lampi e il Memo si aprono senza chiedere
--  Alla fine: un suono, cosa è arrivato nel frattempo («Slack 4 · Gmail 2») e tre
--  scelte: Riapri tutto · Altri 10 minuti · Resta così (senza tempo).
--  Si ricorda anche se riavvii Hammerspoon o il Mac.
-- =====================================================================

FOCUS_YELLOW  = {hex = "#F4C443"}   -- il giallo di Tabby (il logo)
FOCUS_INK     = {hex = "#16130A"}   -- il testo sopra il giallo
FOCUS_DND_ON  = "Concentrazione on"   -- comandi rapidi (app Comandi) per Non disturbare
FOCUS_DND_OFF = "Concentrazione off"
FOCUS_W       = 64                    -- lo spazio del tempo, con Tabby in alto/in basso
FOCUS_VIEW_W, FOCUS_VIEW_H = 460, 560   -- (più grande della scheda: gli angoli tondi restano interi)

-- ---------------------------------------------------------------------
--  Insiemi (si salvano come elenchi)
-- ---------------------------------------------------------------------
function setOf(list)
  local s = {}
  for _, k in ipairs(list or {}) do s[k] = true end
  return s
end
function listOf(set)
  local l = {}
  for k in pairs(set or {}) do table.insert(l, k) end
  table.sort(l)
  return l
end

function focusSave()
  local f = T.focus
  if not f then hs.settings.set("tabbar.focus", nil); return end
  hs.settings.set("tabbar.focus", {
    startAt = f.startAt, endAt = f.endAt, minutes = f.minutes, ended = f.ended or nil,
    tabs = listOf(f.tabs), keys = listOf(f.keys), bids = listOf(f.bids),
    excluded = listOf(f.excluded), badges0 = f.badges0, dnd = f.dnd or nil,
  })
end

function focusLoad()
  local s = hs.settings.get("tabbar.focus")
  if type(s) ~= "table" or not s.startAt then return nil end
  return {startAt = s.startAt, endAt = s.endAt, minutes = s.minutes or 25, ended = s.ended,
          tabs = setOf(s.tabs), keys = setOf(s.keys), bids = setOf(s.bids),
          excluded = setOf(s.excluded), badges0 = s.badges0 or {}, dnd = s.dnd}
end

-- ---------------------------------------------------------------------
--  Cosa è permesso durante la concentrazione
-- ---------------------------------------------------------------------

-- Una scheda (chiave) resta? Quelle scelte sì; quelle che c'erano e non hai scelto no;
-- le finestre nuove di un'app scelta sì (le hai aperte tu, apposta)
function focusAllowsKey(k)
  local f = T.focus
  if not f then return true end
  if f.tabs[k] or f.keys[k] then return true end
  if f.excluded[k] then return false end
  local b = T.keyBid and T.keyBid[k]
  return (b and f.bids[b]) or k == "memo" or false
end

function focusAllowsTab(t)
  local f = T.focus
  if not f then return true end
  if f.tabs[t.key] then return true end
  if t.group then
    for _, k in ipairs(t.group.members) do
      if not focusAllowsKey(k) then return false end
    end
    return not f.excluded[t.key]
  end
  if t.folder then return false end
  return focusAllowsKey(t.key)
end

-- (rebuildTabs) nella barra solo le schede della concentrazione
function focusFilterTabs()
  if not T.focus then return end
  local keep = {}
  for _, t in ipairs(T.tabs) do
    if focusAllowsTab(t) then table.insert(keep, t) end
  end
  T.tabs = keep
end

-- Le chiavi "vere" (app, finestre) dietro una scheda: un gruppo → i suoi membri,
-- una cartella → le sue schede
function tabMemberKeys(t)
  local out = {}
  if t.group then
    for _, k in ipairs(t.group.members) do table.insert(out, k) end
  elseif t.folder then
    for _, x in ipairs(T.allTabs or {}) do
      if T.tabFolder[x.key] == t.folder then
        for _, k in ipairs(tabMemberKeys(x)) do table.insert(out, k) end
      end
    end
  else
    table.insert(out, t.key)
  end
  return out
end

-- ---------------------------------------------------------------------
--  Non disturbare (con due comandi rapidi dell'app Comandi: macOS non lascia
--  accenderlo direttamente alle altre app)
-- ---------------------------------------------------------------------
function checkDndShortcuts(done)
  local ok = pcall(function()
    runTask("/usr/bin/shortcuts", {"list"}, function(_, out)
      local have = {}
      for line in (out or ""):gmatch("[^\n]+") do have[line] = true end
      T.dndReady = have[FOCUS_DND_ON] and have[FOCUS_DND_OFF] or false
      if done then done() end
    end)
  end)
  if not ok then T.dndReady = false end
end

function setDnd(on)
  if not T.dndReady then return false end
  local name = on and FOCUS_DND_ON or FOCUS_DND_OFF
  pcall(function() runTask("/usr/bin/shortcuts", {"run", name}) end)
  print("Tabby · concentrazione: Non disturbare " .. (on and "acceso" or "spento"))
  return true
end

-- ---------------------------------------------------------------------
--  La finestra in centro (tabby/concentrazione.html) e lo sfondo scuro
-- ---------------------------------------------------------------------
function focusViewFrame()
  local A = appArea()
  return {x = math.floor(A.x + (A.w - FOCUS_VIEW_W) / 2), y = math.floor(A.y + (A.h - FOCUS_VIEW_H) / 2),
          w = FOCUS_VIEW_W, h = FOCUS_VIEW_H}
end

function ensureFocusView()
  if T.focusView then return T.focusView end
  T.focusUCC = hs.webview.usercontent.new("tabbyfocus")
  T.focusUCC:setCallback(function(msg)
    local b = msg and msg.body
    if type(b) == "table" then focusMessage(b) end
  end)
  local page = ""
  local f = io.open((T.dir or ".") .. "/tabby/concentrazione.html", "r")
  if f then page = f:read("a"); f:close() end
  T.focusView = hs.webview.new(focusViewFrame(), {developerExtrasEnabled = false}, T.focusUCC)
  T.focusView:windowStyle({"borderless", "nonactivating"})   -- non ruba la tastiera
  pcall(function() T.focusView:transparent(true) end)
  T.focusView:allowTextEntry(false)
  T.focusView:level(hs.canvas.windowLevels.modalPanel)
  T.focusView:behaviorAsLabels({"canJoinAllSpaces", "stationary"})
  T.focusView:html(page)
  return T.focusView
end

-- Lo sfondo si oscura, la barra no (resta sopra, per scegliere le schede)
function focusDim(on)
  if on then
    if not T.focusDimC then
      T.focusDimC = hs.canvas.new(screen():fullFrame())
      T.focusDimC:level(hs.canvas.windowLevels.floating)
      T.focusDimC:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
      T.focusDimC:replaceElements({{type = "rectangle", action = "fill",
        fillColor = {hex = "#06070A", alpha = 0.72}}})
      -- prende i clic, così non finiscono sulle app dietro
      T.focusDimC:canvasMouseEvents(true, true)
      T.focusDimC:mouseCallback(function() end)
    end
    T.focusDimC:frame(screen():fullFrame())
    T.focusDimC:show()
    if T.bar then T.bar:orderAbove(T.focusDimC) end
  elseif T.focusDimC then
    T.focusDimC:hide()
  end
end

function focusShow(js)
  local v = ensureFocusView()
  markViewUsed("focusView")
  v:frame(focusViewFrame())
  focusDim(true)
  v:show()
  if T.focusReady then v:evaluateJavaScript(js) else T.focusPendingJS = js end
end

function focusHide()
  if T.focusView then T.focusView:hide() end
  focusDim(false)
end

-- Messaggi dalla pagina
function focusMessage(b)
  if b.ready then
    T.focusReady = true
    if T.focusPendingJS then T.focusView:evaluateJavaScript(T.focusPendingJS); T.focusPendingJS = nil end
  end
  if b.minutes and T.fsel then
    T.fsel.minutes = math.max(5, math.min(240, math.floor(tonumber(b.minutes) or 25)))
    focusPushSetup()
  end
  if b.folder and T.fsel then focusToggleFolder(tonumber(b.folder)) end
  if b.start then startFocus() end
  if b.cancel then cancelFocusSetup() end
  if b.ask then answerFocusAsk(b.ask == "open") end
  if b.finish then answerFocusEnd(tostring(b.finish)) end
end

-- ---------------------------------------------------------------------
--  1. La scelta: minuti e schede
-- ---------------------------------------------------------------------
function openFocusSetup()
  if T.focus then openFocusMenu(); return end
  if T.split then exitSplit() end
  if T.fedit then FD.cancelFolderEdit() end
  local last = hs.settings.get("tabbar.focusLast") or {}
  T.fsel = {keys = {}, minutes = tonumber(last.minutes) or 25}
  -- già gialle: quelle dell'ultima volta (se ci sono ancora) e quella in cui sei
  local present = {}
  for _, t in ipairs(T.tabs) do present[t.key] = true end
  for _, k in ipairs(last.tabs or {}) do if present[k] then T.fsel.keys[k] = true end end
  local ai = activeIndex()
  if ai and T.tabs[ai] then T.fsel.keys[T.tabs[ai].key] = true end
  print("Tabby · concentrazione: scegli minuti e schede")
  checkDndShortcuts(function() if T.fsel then focusPushSetup() end end)
  focusPushSetup(true)
  draw()
end

function focusSelCount()
  local n = 0
  for _ in pairs(T.fsel and T.fsel.keys or {}) do n = n + 1 end
  return n
end

-- Le cartelle che hanno almeno una scheda aperta (un clic le sceglie tutte)
function focusFolderTabs(f)
  local byTab = FD.assign({f}, T.allTabs or {})
  local present, out = {}, {}
  for _, t in ipairs(T.tabs) do present[t.key] = true end
  if present["f:" .. f.id] then return {"f:" .. f.id} end
  for k in pairs(byTab) do
    local g = T.memberOf[k]
    local key = g and ("g:" .. g.id) or k
    if present[key] then out[key] = true end
  end
  return listOf(out)
end

function focusToggleFolder(id)
  local f = FD.folderById(id)
  if not (f and T.fsel) then return end
  local keys = focusFolderTabs(f)
  local all = #keys > 0
  for _, k in ipairs(keys) do if not T.fsel.keys[k] then all = false end end
  for _, k in ipairs(keys) do T.fsel.keys[k] = (not all) or nil end
  focusPushSetup()
  draw()
end

function focusToggleTab(i)
  local t = T.tabs[i]
  if not (t and T.fsel) then return end
  T.fsel.keys[t.key] = (not T.fsel.keys[t.key]) or nil
  focusPushSetup()
  draw()
end

function focusPushSetup(show)
  local s = T.fsel
  if not s then return end
  local folders = {}
  for _, f in ipairs(S.folders or {}) do
    local keys = focusFolderTabs(f)
    if #keys > 0 then
      local on = true
      for _, k in ipairs(keys) do if not s.keys[k] then on = false end end
      table.insert(folders, "{id:" .. f.id .. ",name:" .. jsString(f.name) .. ",on:" .. tostring(on) .. "}")
    end
  end
  local js = string.format("setup({minutes:%d,count:%d,folders:[%s],dnd:%s})", s.minutes, focusSelCount(),
    table.concat(folders, ","), T.dndReady == nil and "null" or tostring(T.dndReady))
  if show then focusShow(js) elseif T.focusView then
    if T.focusReady then T.focusView:evaluateJavaScript(js) else T.focusPendingJS = js end
  end
end

function cancelFocusSetup()
  if not T.fsel then return end
  T.fsel = nil
  focusHide()
  draw()
end

-- ---------------------------------------------------------------------
--  2. Inizia
-- ---------------------------------------------------------------------
function startFocus()
  local s = T.fsel
  if not s then return end
  if focusSelCount() == 0 then
    if T.focusView then T.focusView:evaluateJavaScript("hint()") end
    return
  end
  local now = hs.timer.secondsSinceEpoch()
  local f = {startAt = now, endAt = now + s.minutes * 60, minutes = s.minutes,
             tabs = {}, keys = {}, bids = {}, excluded = {}, badges0 = {}}
  for _, t in ipairs(T.tabs) do
    if s.keys[t.key] then
      f.tabs[t.key] = true
      for _, k in ipairs(tabMemberKeys(t)) do
        f.keys[k] = true
        local b = T.keyBid[k]
        if b and k ~= "memo" then f.bids[b] = true end
      end
    end
  end
  -- quelle che c'erano e non hai scelto restano fuori (anche se sono finestre di
  -- un'app scelta: un'altra finestra di DuckDuckGo, per esempio)
  for k in pairs(T.cand) do if not f.keys[k] then f.excluded[k] = true end end
  for _, t in ipairs(T.tabs) do if not f.tabs[t.key] then f.excluded[t.key] = true end end
  -- le notifiche di adesso, per dire alla fine cosa è arrivato nel frattempo
  for b, v in pairs(T.badges or {}) do f.badges0[b] = v end
  for k, e in pairs(T.cand) do if e.titleBadge then f.badges0[k] = e.titleBadge end end

  hs.settings.set("tabbar.focusLast", {minutes = s.minutes, tabs = listOf(f.tabs)})
  T.fsel = nil
  T.focus = f
  focusHide()
  f.dnd = setDnd(true)
  focusSave()
  local n = 0
  for _ in pairs(f.tabs) do n = n + 1 end
  print(string.format("Tabby · concentrazione: %d minuti, %d schede", f.minutes, n))

  -- via le altre: app nascoste (non chiuse), finestre ridotte
  local _, list = runningApps()
  for _, app in ipairs(list) do
    local b = app:bundleID()
    if b and not f.bids[b] and not floating(b) and not app:isHidden() then app:hide() end
  end
  for k in pairs(f.excluded) do
    local w = T.keyWin[k]
    local b = T.keyBid[k]
    if w and b and f.bids[b] and not w:isMinimized() then
      T.selfMin[w:id()] = now
      w:minimize()
    end
  end
  rebuildTabs()
  -- se eri su una scheda che non hai scelto, si va sulla prima scelta
  local cur = currentKey()
  if not (cur and (focusAllowsKey(cur) or f.tabs["g:" .. ((T.memberOf[cur] or {}).id or "")])) and #T.tabs > 0 then
    switchTo(1)
  end
  startFocusTick()
  draw()
end

-- ---------------------------------------------------------------------
--  3. Durante: il tempo al posto della batteria
-- ---------------------------------------------------------------------
function focusLeft()
  local f = T.focus
  if not (f and f.endAt) then return nil end
  return math.max(0, f.endAt - hs.timer.secondsSinceEpoch())
end

-- Il testo del tempo: «24 min», nell'ultimo minuto «0:45»; senza tempo «∞»
function focusLabel()
  local left = focusLeft()
  if not left then return "∞" end
  if left < 60 then return string.format("0:%02d", math.floor(left)) end
  return math.ceil(left / 60) .. " min"
end

function focusProgress()
  local f = T.focus
  if not (f and f.endAt) then return 1 end
  local tot = f.endAt - f.startAt
  if tot <= 0 then return 1 end
  return math.max(0, math.min(1, 1 - focusLeft() / tot))
end

function drawFocusTimer(els, r)
  local vertical = isVertical()
  local label, p = focusLabel(), focusProgress()
  local ty = r.y + r.h / 2 - (vertical and 10 or 11)
  table.insert(els, {type = "text", text = label, textSize = 12, textColor = COL.text,
    textAlignment = "center", frame = {x = r.x, y = ty, w = r.w, h = 16}})
  if T.focus and T.focus.endAt then
    local bw = math.min(r.w - 16, 44)
    local bx, by = r.x + (r.w - bw) / 2, ty + 18
    table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.14},
      roundedRectRadii = {xRadius = 1.5, yRadius = 1.5}, frame = {x = bx, y = by, w = bw, h = 3}})
    table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.accent,
      roundedRectRadii = {xRadius = 1.5, yRadius = 1.5}, frame = {x = bx, y = by, w = math.max(2, bw * p), h = 3}})
  end
  table.insert(els, hitArea("focustimer", r))
end

-- Ogni secondo: si ridisegna solo se cambia qualcosa di visibile
function startFocusTick()
  if T.focusTick then T.focusTick:stop() end
  T.focusTick = hs.timer.doEvery(1, focusTickFn)
end

function focusTickFn()
  local f = T.focus
  if not f or f.ended then return end
  if f.endAt and hs.timer.secondsSinceEpoch() >= f.endAt then endFocus(); return end
  local sig = focusLabel() .. "|" .. math.floor(focusProgress() * 100)
  if sig ~= T.focusSig then
    T.focusSig = sig
    if T.bar and T.visible then draw() end
    focusOrbRing()
  end
end

-- Col cerchio sulla scrivania, il tempo è un anello giallo intorno alla sfera
function focusOrbRing()
  if not T.orbView then return end
  local v = (T.focus and T.focus.endAt and not T.focus.ended) and focusProgress() or -1
  T.orbView:evaluateJavaScript(string.format("typeof setRing === 'function' && setRing(%.3f)", v))
end

-- Clic sul tempo: allunga o termina
function openFocusMenu()
  local f = T.focus
  if not f then return end
  local items = {{title = f.endAt and ("Concentrazione · mancano " .. focusLabel()) or "Concentrazione · senza tempo",
                  disabled = true}}
  table.insert(items, {title = "+5 minuti", fn = function() extendFocus(5) end})
  table.insert(items, {title = "+15 minuti", fn = function() extendFocus(15) end})
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Termina adesso", fn = function() endFocus(true) end})
  popup(items, T.L and T.L.battery and popPos(T.L.battery) or nil)
end

function extendFocus(min)
  local f = T.focus
  if not f then return end
  local now = hs.timer.secondsSinceEpoch()
  f.endAt = math.max(now, f.endAt or now) + min * 60
  f.minutes = (f.minutes or 0) + min
  f.ended = nil
  focusSave()
  print("Tabby · concentrazione: +" .. min .. " minuti")
  startFocusTick()
  T.focusSig = nil
  draw()
end

-- Un'app non scelta prova a venire davanti (Dock, Spotlight, ⌘Tab, un clic…):
-- torna via e Tabby chiede. Ritorna true se l'ha fermata.
function focusBlocks(app)
  local f = T.focus
  local b = app and app:bundleID()
  if not f or f.ended or not b or f.bids[b] or IGNORE[b] or floating(b) or b == FINDER then return false end
  if not isTabApp(app) then return false end
  if actionRecent and actionRecent(b) then return false end   -- (azioni rapide: chat di Claude…)
  if T.fask and T.fask.bid == b then app:hide(); return true end
  print("Tabby · concentrazione: «" .. tostring(app:name()) .. "» non è tra le schede scelte, chiedo")
  app:hide()
  -- si torna dove eri
  for _, k in ipairs(T.recent or {}) do
    if T.cand[k] and focusAllowsKey(k) then
      local g = T.memberOf[k]
      if g then showGroup(g) else focusKey(k) end
      break
    end
  end
  T.fask = {bid = b, name = app:name() or appName(b)}
  local js = string.format("ask({name:%s,left:%s,icon:%s})", jsString(T.fask.name), jsString(focusLabel()),
    jsString(imageDataURI(icon(b)) or ""))
  focusShow(js)
  return true
end

function answerFocusAsk(open)
  local a = T.fask
  T.fask = nil
  focusHide()
  if not (a and T.focus) then return end
  if open then
    print("Tabby · concentrazione: apro lo stesso «" .. a.name .. "»")
    T.focus.bids[a.bid] = true
    for k in pairs(T.focus.excluded) do
      if T.keyBid[k] == a.bid then T.focus.excluded[k] = nil end
    end
    focusSave()
    rebuildTabs()
    focusBid(a.bid)
  end
end

-- ---------------------------------------------------------------------
--  4. La fine
-- ---------------------------------------------------------------------

-- Cosa è arrivato nel frattempo, dalle app e dai siti rimasti fuori
function focusSummary()
  local f = T.focus
  local parts = {}
  local function add(name, before, now)
    if not now or now == "" then return end
    local n0, n1 = tonumber(before) or 0, tonumber(now)
    if n1 and n1 > n0 then table.insert(parts, name .. " " .. (n1 - n0))
    elseif not n1 and before ~= now then table.insert(parts, name .. " •") end
  end

  for b, v in pairs(T.badges or {}) do
    if not f.bids[b] then add(appName(b, appFor(b)), f.badges0[b], v) end
  end
  for k, e in pairs(T.cand or {}) do
    if e.site and e.titleBadge and not focusAllowsKey(k) then add(e.name or k, f.badges0[k], e.titleBadge) end
  end
  table.sort(parts)
  return table.concat(parts, " · ")
end

function endFocus(early)
  local f = T.focus
  if not f or f.ended then return end
  f.ended = true
  focusSave()
  if T.focusTick then T.focusTick:stop() end
  local mins = math.max(1, math.floor((hs.timer.secondsSinceEpoch() - f.startAt) / 60 + 0.5))
  print(string.format("Tabby · concentrazione finita%s: %d minuti", early and " (prima del tempo)" or "", mins))
  if not early then pcall(function()
    local snd = hs.sound.getByName("Glass")
    if snd then snd:play() end
  end) end
  T.fend = true
  focusOrbRing()
  focusShow(string.format("finish({minutes:%d,summary:%s,early:%s})", mins, jsString(focusSummary()), tostring(early == true)))
  draw()
end

function answerFocusEnd(choice)
  T.fend = nil
  focusHide()
  local f = T.focus
  if not f then return end
  if choice == "more" then
    f.ended = nil
    f.endAt = hs.timer.secondsSinceEpoch()
    extendFocus(10)
  elseif choice == "stay" then
    -- resta tutto com'è, senza tempo (clic su ∞ per terminare)
    f.ended = nil
    f.endAt = nil
    focusSave()
    print("Tabby · concentrazione: resta così, senza tempo")
    startFocusTick()
    T.focusSig = nil
    draw()
  else
    finishFocus()
  end
end

-- Tutto torna com'era: le schede tornano nella barra, Non disturbare si spegne
function finishFocus()
  local f = T.focus
  if not f then return end
  if f.dnd then setDnd(false) end
  T.focus = nil
  T.fend = nil
  focusSave()
  if T.focusTick then T.focusTick:stop(); T.focusTick = nil end
  print("Tabby · concentrazione: riapro tutto")
  focusOrbRing()
  rebuildTabs()
  draw()
end

-- All'avvio: una concentrazione in corso continua (o finisce, se il tempo è passato)
function restoreFocus()
  local f = focusLoad()
  if not f then return end
  T.focus = f
  print("Tabby · concentrazione in corso: riprendo")
  if f.dnd then checkDndShortcuts() end
  if f.ended or (f.endAt and hs.timer.secondsSinceEpoch() >= f.endAt) then
    f.ended = nil
    after(1, function() endFocus() end)
  else
    startFocusTick()
  end
end

-- Il pallino giallo accanto a «Concentrazione» nel menu ⚡︎
function focusMenuIcon()
  if T.focusIcon == nil then
    local ok, img = pcall(function()
      local c = hs.canvas.new({x = 0, y = 0, w = 16, h = 16})
      c:replaceElements({{type = "circle", action = "fill", fillColor = FOCUS_YELLOW,
                          center = {x = 8, y = 8}, radius = 5}})
      local i = c:imageFromCanvas()
      c:delete()
      return i
    end)
    T.focusIcon = ok and img or false
  end
  return T.focusIcon or nil
end
