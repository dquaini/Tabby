-- =====================================================================
--  Tabby · menu.lua: i menu: ✕ (chiudi), ⚙︎ (impostazioni), ⚡︎ (azioni veloci e cartelle), ⊞, +N.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  MENU DELLA ✕  (chiudi finestra / chiudi app)
-- ---------------------------------------------------------------------

function shorten(s, n)
  if not s or s == "" then return nil end
  -- conta le lettere, non i byte (così non spezza lettere accentate o emoji)
  local len = utf8.len(s)
  if len and len > n then return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…" end
  return s
end

function popup(items, pos)
  if not T.menu then T.menu = hs.menubar.new(false) end
  T.menu:setMenu(items)
  T.menu:popupMenu(pos, true)
end

function openCloseMenu(i)
  local t = T.tabs[i]
  if not t or not t.app then return end
  local app  = t.app
  local wins = standardWindows(app)
  -- per una scheda-finestra (browser) si chiude proprio quella finestra
  local main = t.win or app:mainWindow() or app:focusedWindow() or wins[1]

  local items = {}
  -- se è la scheda attiva, dopo la chiusura si passa a quella accanto
  local snap = (activeIndex() == i) and T.activeSnap or nil
  if main then
    local title = shorten(main:title(), 40)
    table.insert(items, {
      title = title and ("Chiudi finestra  “" .. title .. "”") or "Chiudi finestra",
      fn = function() main:close(); scheduleRebuild(); goNeighborSoon(snap, "chiusa la finestra") end,
    })
  end
  if t.win then
    local id = tostring(t.win:id())
    table.insert(items, {title = "Rinomina la scheda…", fn = function() renameTab(t) end})
    if T.tabNames[id] then
      table.insert(items, {title = "Torna al nome di prima", fn = function()
        T.tabNames[id] = nil; hs.settings.set("tabbar.tabNames", T.tabNames); rebuildTabs(); draw()
      end})
    end
    table.insert(items, {title = "-"})
  end
  if t.bid == FINDER then
    table.insert(items, {title = "Il Finder non si può chiudere", disabled = true})
  else
    table.insert(items, {
      title = "Chiudi " .. appName(t.bid, app),   -- l'app intera (es. Chrome, non Gmail)
      fn = function() app:kill(); scheduleRebuild(); goNeighborSoon(snap, "chiusa l'app") end,
    })
  end
  popup(items, T.closePos[i])
end


-- Rinomina una scheda (una finestra): il nome resta finché la finestra è aperta
function renameTab(t)
  if not t or not t.win then return end
  local id = tostring(t.win:id())
  local btn, txt = FD.ask(function()
    return hs.dialog.textPrompt("Rinomina la scheda", "Nuovo nome (vuoto = quello di prima):", t.name or "", "Rinomina", "Annulla")
  end)
  if btn ~= "Rinomina" then return end
  txt = txt and txt:match("^%s*(.-)%s*$") or ""
  T.tabNames[id] = (txt ~= "") and txt or nil
  hs.settings.set("tabbar.tabNames", T.tabNames)
  rebuildTabs(); draw()
end

-- Clic sull'icona di una finestra di browser con più siti: l'elenco dei siti
-- aperti; scelto uno, la scheda prende nome e logo di quel sito (finché c'è)
function openSiteChooser(i)
  local t = T.tabs[i]
  local e = t and T.cand[t.key]
  if not e or not e.win then switchTo(i); return end
  local id = e.win:id()
  local items = {{title = "Mostra la scheda come:", disabled = true}}
  for _, d in ipairs(windowDomains(e)) do
    local img = favicon(d)
    table.insert(items, {title = siteName(nil, d) .. "   " .. d, image = img and img:setSize({w = 16, h = 16}) or nil,
      checked = (T.showSite[id] == d) or nil,
      fn = function() T.showSite[id] = d; rebuildTabs(); switchTo(i); draw() end})
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = BROWSERS[e.bid].short .. " (come prima)", checked = (T.showSite[id] == nil) or nil,
    fn = function() T.showSite[id] = nil; rebuildTabs(); draw() end})
  table.insert(items, {title = "Rinomina la scheda…", fn = function() renameTab(t) end})
  popup(items, T.closePos[i])
end

-- ⌃⌥W: chiude la finestra che stai guardando senza chiudere l'app (come ✕ →
-- "Chiudi finestra"). In un browser chiude la finestra intera (⌘W chiude solo
-- la scheda del browser). Mai le app veloci né Hammerspoon.
function closeActiveWindow()
  local w = hs.window.focusedWindow()
  local a = w and w:application()
  local b = a and a:bundleID()
  if not w or not b or IGNORE[b] or floating(b) or not w:isStandard() then return end
  print(string.format("Tabby · ⌃⌥W: chiudo la finestra «%s» di %s", tostring(w:title()), tostring(a:name())))
  local snap = T.activeSnap
  w:close()
  scheduleRebuild()
  goNeighborSoon(snap, "⌃⌥W")
end

-- ---------------------------------------------------------------------
--  CHIUDERE O RIDURRE LA SCHEDA ATTIVA → SI PASSA ALLA SCHEDA ACCANTO
--  (23/10/2026, Daniele: "sempre, indipendentemente dal comportamento").
--  Vale per ogni modo: ✕ di Tabby, ⌃⌥W, pallino rosso, ⌘W, ⌘Q, pallino giallo
--  (ridurre a icona). La scheda accanto è quella a sinistra, o a destra se era
--  la prima. Non vale per le finestrelle (accesso con Google, miniatura di Meet),
--  che non sono schede: lì si torna alla finestra di prima (T.restoreAfterClose).
-- ---------------------------------------------------------------------

-- Le finestre della scheda attiva (per riconoscerle quando si chiudono)
function tabWins(t)
  local out = {}
  local function addApp(app)
    if app then for _, w in ipairs(standardWindows(app)) do out[w:id()] = w end end
  end
  local function addKey(k)
    local w = T.keyWin[k]
    if w then out[w:id()] = w else addApp(appFor(T.keyBid[k] or k)) end
  end
  if t.group then
    for _, k in ipairs(t.group.members) do addKey(k) end
  elseif t.folder then
    local k = currentKey()
    if k then addKey(k) end
  elseif t.win then
    out[t.win:id()] = t.win
  else
    addApp(t.app or appFor(t.bid))
  end
  return out
end

-- Si ricorda la scheda attiva a ogni disegno: chiave, posizione, scheda accanto,
-- le sue finestre e le sue app. Si tiene anche quella di prima per un attimo:
-- macOS a volte attiva un'altra app un istante PRIMA di dire che la finestra è chiusa.
function snapActive(activeIdx)
  local t = activeIdx and T.tabs[activeIdx]
  local snap
  if t then
    local nb = T.tabs[activeIdx - 1] or T.tabs[activeIdx + 1]
    local wins, bids = tabWins(t), {}
    for _, w in pairs(wins) do
      local a = w:application()
      if a and a:bundleID() then bids[a:bundleID()] = true end
    end
    if t.bid then bids[t.bid] = true end
    snap = {key = t.key, idx = activeIdx, neighbor = nb and nb.key, wins = wins, bids = bids, name = t.name}
  end
  local cur = T.activeSnap
  if cur and (not snap or cur.key ~= snap.key) then
    T.prevSnap, T.prevSnapAt = cur, hs.timer.secondsSinceEpoch()
  end
  T.activeSnap = snap
  T.activeNeighborKey = snap and snap.neighbor or nil
end

-- La scheda attiva (o quella di un attimo fa) a cui apparteneva questa finestra / app
function snapForWin(id)
  local s = T.activeSnap
  if s and s.wins[id] then return s end
  local p = T.prevSnap
  if p and p.wins[id] and hs.timer.secondsSinceEpoch() - (T.prevSnapAt or 0) < 1.5 then return p end
  return nil
end
function snapForApp(bid)
  local s = T.activeSnap
  if s and s.bids[bid] then return s end
  local p = T.prevSnap
  if p and p.bids[bid] and hs.timer.secondsSinceEpoch() - (T.prevSnapAt or 0) < 1.5 then return p end
  return nil
end

-- Una delle finestre della scheda è ancora aperta e non ridotta?
function snapStillVisible(snap)
  local open = {}
  if T.allWins then
    for _, w in ipairs(T.allWins:getWindows()) do
      if not w:isMinimized() and not w:isFullScreen() then open[w:id()] = true end
    end
  end
  for id in pairs(snap.wins) do if open[id] then return true end end
  return false
end

-- Dopo un attimo (le app ci mettono un po' a chiudere), se della scheda non resta
-- niente in vista, passa alla scheda accanto
function goNeighborSoon(snap, why)
  if not snap then return end
  T.neighborSeq = (T.neighborSeq or 0) + 1
  local seq = T.neighborSeq
  hs.timer.doAfter(0.35, function()
    if seq ~= T.neighborSeq or T.desktopMode then return end
    rebuildTabs()
    if snapStillVisible(snap) then draw(); return end
    local target
    for i, t in ipairs(T.tabs) do if t.key == snap.neighbor then target = i end end
    if not target and #T.tabs > 0 then target = math.max(1, math.min(snap.idx - 1, #T.tabs)) end
    if not target then draw(); return end
    print(string.format("Tabby · %s «%s»: passo alla scheda accanto «%s»",
      tostring(why), tostring(snap.name), tostring(T.tabs[target].name)))
    switchTo(target)
  end)
end


-- ---------------------------------------------------------------------
--  MENU IMPOSTAZIONI  (il tasto ⚙︎)
-- ---------------------------------------------------------------------

function togglePinned(bid)
  local new, found = {}, false
  for _, b in ipairs(S.pinned) do
    if b == bid then found = true else table.insert(new, b) end
  end
  if not found then table.insert(new, bid) end
  S.pinned = new
  save("pinned")
  rebuildTabs()
  draw()
end

function addAppDialog()
  hs.focus()
  local res = hs.dialog.chooseFileOrFolder("Scegli un'app da aggiungere ai preferiti",
    "/Applications", true, false, true, {"app"}, true)
  if not res then return end
  for _, path in pairs(res) do
    local info = hs.application.infoForBundlePath(path)
    local bid = info and info.CFBundleIdentifier
    if bid and not isPinned(bid) then togglePinned(bid) end
  end
end

function closeAllApps()
  hs.focus()
  local btn = hs.dialog.blockAlert("Chiudere tutte le app?",
    "Le app con documenti non salvati ti chiederanno cosa fare.",
    "Chiudi tutte", "Annulla")
  if btn ~= "Chiudi tutte" then return end
  local _, list = runningApps()
  for _, app in ipairs(list) do
    if app:bundleID() == FINDER then
      for _, w in ipairs(standardWindows(app)) do w:close() end
    else
      app:kill()
    end
  end
  scheduleRebuild()
end

function favoritesMenu()
  local items = {}
  local map, list = runningApps()
  local bids, seen = {}, {}
  for _, b in ipairs(S.pinned) do
    if not seen[b] then table.insert(bids, b); seen[b] = true end
  end
  for _, a in ipairs(list) do
    local b = a:bundleID()
    if not seen[b] then table.insert(bids, b); seen[b] = true end
  end
  for _, b in ipairs(bids) do
    table.insert(items, {
      title   = appName(b, map[b]),
      image   = smallIcon(b),
      checked = isPinned(b),
      fn      = function() togglePinned(b) end,
    })
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Aggiungi un'altra app…", fn = addAppDialog})
  return items
end

-- ⚙︎ → Finestre separate: per ogni app aperta, una scheda per finestra
-- (spuntata, normale) oppure tutte le finestre in una scheda sola
function windowsMenu()
  local items = {{title = "Una scheda per ogni finestra:", disabled = true}}
  local map, list = runningApps()
  local rows = {}
  for _, a in ipairs(list) do
    local b = a:bundleID()
    if not BROWSERS[b] and not FLOATER[b] then
      table.insert(rows, {b = b, name = appName(b, map[b])})
    end
  end
  table.sort(rows, function(x, y) return x.name:lower() < y.name:lower() end)
  for _, r in ipairs(rows) do
    table.insert(items, {
      title   = r.name,
      image   = smallIcon(r.b),
      checked = perWindow(r.b),
      fn      = function()
        S.joinWins[r.b] = perWindow(r.b) or nil
        save("joinWins")
        rebuildTabs()
        draw()
      end,
    })
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "I browser hanno sempre una scheda per finestra", disabled = true})
  return items
end

function toggle(key, after)
  return function()
    S[key] = not S[key]
    save(key)
    if after then after() end
    draw()
  end
end

function refit()
  local f = hs.application.frontmostApplication()
  local g = f and T.memberOf[f:bundleID()]
  if g then layoutGroup(g) else fitApp(f) end
end

function behaviourMenu()
  return {
    {title = "Una scheda alla volta (nasconde le altre app e finestre)", checked = S.oneAtATime, fn = toggle("oneAtATime")},
    {title = "Adatta le finestre a Tabby", checked = S.fit, fn = toggle("fit", refit)},
    {title = "Nascondi Tabby (appare col mouse sul bordo)", checked = S.autohide,
     fn = toggle("autohide", function() T.revealed = false; refit() end)},
    {title = "Mostra anche app aperte senza finestre", checked = S.showWindowless,
     fn = toggle("showWindowless", rebuildTabs)},
    {title = "Tre dita a sinistra / destra: scheda dopo / prima", checked = S.gestures,
     fn = toggle("gestures")},
    {title = "Oscura lo sfondo con Spotlight e le azioni rapide", checked = S.spotlightDim,
     fn = toggle("spotlightDim", function() T.spotlightDim(false) end)},
    {title = "Vista cartelle (una cartella attiva = una scheda sola)", checked = S.folderView,
     fn = toggle("folderView", function() T.viewFolder = nil; rebuildTabs() end)},
  }
end

POSITIONS = {
  {"top", "In alto"}, {"bottom", "In basso"}, {"left", "A sinistra"}, {"right", "A destra"},
}

function positionMenu()
  local items = {}
  for _, p in ipairs(POSITIONS) do
    table.insert(items, {
      title   = p[2],
      checked = (S.position == p[1]),
      fn      = function()
        S.position = p[1]
        save("position")
        T.revealed = false
        draw()
        refit()
      end,
    })
  end
  -- fascia del notch: scelta manuale, se il rilevamento automatico sbaglia
  table.insert(items, {title = "-"})
  table.insert(items, {
    title    = "Usa la fascia del notch (in alto)",
    checked  = useNotchBand(),
    disabled = (S.position ~= "top"),
    fn       = function()
      S.notchBand = useNotchBand() and "off" or "on"
      save("notchBand")
      draw(); refit(); logDiagnostics()
    end,
  })
  if S.notchBand ~= "auto" then
    table.insert(items, {title = "Fascia del notch: torna automatico", fn = function()
      S.notchBand = "auto"; save("notchBand"); draw(); refit(); logDiagnostics()
    end})
  end
  return items
end

-- Dove far comparire un menu aperto da un elemento di Tabby
function popPos(r)
  local bf, p = T.bf, S.position
  if p == "bottom" then return {x = bf.x + r.x, y = bf.y + r.y - 4} end
  if p == "left"   then return {x = bf.x + r.x + r.w, y = bf.y + r.y} end
  if p == "right"  then return {x = bf.x + r.x - 240, y = bf.y + r.y} end
  return {x = bf.x + r.x, y = bf.y + r.y + r.h}
end

function openSettings()
  popup({
    {title = "Posizione di Tabby", menu = positionMenu()},
    {title = "App preferite", menu = favoritesMenu()},
    {title = "Finestre separate", menu = windowsMenu()},
    {title = "Comportamento", menu = behaviourMenu()},
    {title = "-"},
    {title = "Chiudi tutte le app…", fn = closeAllApps},
    {title = "-"},
    {title = "Ricarica Tabby", fn = function() hs.reload() end},
    {title = "Apri la console di Hammerspoon", fn = function() hs.openConsole() end},
  }, popPos(T.L.settings))
end

-- Menu del tasto ⚡︎ (app veloci)
function openQuick()
  local items = {}
  for _, q in ipairs(QUICK) do
    table.insert(items, {
      title = q.name .. "   ⌃⌥" .. q.key:upper(),
      image = smallIcon(q.bid or "com.apple.TextEdit"),
      checked = (q.memo and T.memoOpen) or nil,
      fn    = function() toggleQuick(q) end,
    })
  end
  -- cartelle: clic = attiva; si creano e si modificano da qui
  table.insert(items, {title = "-"})
  -- azioni delle app (icone della barra dei menu di macOS): una riga sola,
  -- "App ▸", anche con tante app; dentro, "Gestisci ▸" per mostrarle e scegliere
  -- la scorciatoia
  local actions = appActionsList()
  local sub = {}
  for _, a in ipairs(actions) do
    table.insert(sub, {title = a.name .. (a.key and ("   ⌃⌥" .. a.key:upper()) or ""),
                       image = smallIcon(a.bid), fn = function() runAppAction(a) end})
  end
  local manage = {}
  local known = {}
  for b, m in pairs(S.menuApps) do table.insert(known, {b = b, m = m}) end
  table.sort(known, function(x, y) return x.m.name:lower() < y.m.name:lower() end)
  for _, x in ipairs(known) do
    local b, m = x.b, x.m
    table.insert(manage, {title = m.name .. (m.iconOnly and "  · tieni l'icona accesa" or "") ..
                                  (m.key and ("   ⌃⌥" .. m.key:upper()) or ""), image = smallIcon(b),
      checked = m.on or nil, menu = {
        {title = "Mostra in ⚡︎ → App", checked = m.on or nil,
         fn = function() m.on = not m.on; save("menuApps") end},
        {title = "Scorciatoia ⌃⌥ + lettera…", fn = function() chooseAppShortcut(b) end},
        {title = "Togli la scorciatoia", disabled = (m.key == nil),
         fn = function() m.key = nil; save("menuApps"); hs.timer.doAfter(0.5, function() hs.reload() end) end},
      }})
  end
  if #manage == 0 then table.insert(manage, {title = "Nessuna app trovata (si aggiungono da sole)", disabled = true}) end
  if #sub > 0 then table.insert(sub, {title = "-"}) end
  table.insert(sub, {title = "Gestisci", menu = manage})
  table.insert(sub, {title = "Cerca app nuove adesso", fn = function()
    local n = scanMenuBarApps()
    hs.alert.show(n > 0 and (n .. " app nuove in ⚡︎ → App") or "Nessuna app nuova")
  end})
  table.insert(items, {title = "-"})
  table.insert(items, {title = "App", menu = sub})
  table.insert(items, {title = "Cartelle", disabled = true})
  for i, f in ipairs(S.folders) do
    table.insert(items, {
      title   = f.name .. (i <= 9 and ("   ⌃⌥⇧" .. i) or ""),
      image   = FD.folderImage(f),
      checked = (S.folderView and FD.isFolderActive(f.id)) or nil,
      fn      = function() FD.activateFolder(f) end,
    })
  end
  table.insert(items, {title = "Nuova cartella…", fn = function() FD.openFolderEditor(nil) end})
  if #S.folders > 0 then
    local edit = {}
    for _, f in ipairs(S.folders) do
      table.insert(edit, {title = f.name, image = FD.folderImage(f), menu = {
        {title = "Modifica le schede…", fn = function() FD.openFolderEditor(f) end},
        {title = "Rinomina…", fn = function() FD.renameFolder(f) end},
        {title = "-"},
        {title = "Elimina la cartella", fn = function() FD.deleteFolder(f) end},
      }})
    end
    table.insert(items, {title = "Modifica le cartelle", menu = edit})
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Mostra il file del Memo nel Finder", fn = function()
    local f = io.open(MEMO_FILE, "r")
    if f then f:close() else writeMemo(readMemo()) end
    hs.execute('open -R "' .. MEMO_FILE .. '"')
  end})
  popup(items, popPos(T.L.quick))
end

-- Clic sulla scheda-cartella: le sue app; scelta una, la cartella si apre lì
-- (con la scorciatoia ⌃⌥ + numero si entra subito nell'ultima usata)
function FD.openFolderChooser(f, pos)
  local items = {}
  for _, t in ipairs(T.allTabs) do
    if T.tabFolder[t.key] == f then
      local key = t.key
      table.insert(items, {
        title   = t.name,
        image   = keySmallIcon(t.group and t.group.members[1] or t.key),
        checked = (T.folderLast[f.id] == key) or nil,
        fn      = function()
          T.viewFolder = f.id
          rebuildTabs()
          for i, x in ipairs(T.tabs) do if x.key == key then switchTo(i) end end
          draw()
        end,
      })
    end
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Altre azioni", menu = {
    {title = "Esci dalla cartella (le schede tornano libere)", fn = function() FD.releaseFolder(f) end},
    {title = "Chiudi cartella…", fn = function() FD.closeFolder(f) end},
    {title = "Aggiorna con le schede di adesso", fn = function() FD.updateFromNow(f) end},
    {title = "Modifica le schede…", fn = function() FD.openFolderEditor(f) end},
    {title = "Rinomina…", fn = function() FD.renameFolder(f) end},
  }})
  popup(items, pos)
end

-- Menu ⋯ di una scheda-cartella (o del nome, nella vista cartella)
function FD.openFolderMenu(f, pos)
  local n = 0
  for _, x in ipairs(T.allTabs) do if T.tabFolder[x.key] == f then n = n + 1 end end
  local items = {}
  if T.viewFolder == f.id then
    table.insert(items, {title = "Torna a tutte le schede", fn = FD.leaveFolderView})
  else
    table.insert(items, {title = "Apri la cartella", fn = function() FD.enterFolder(f) end})
  end
  table.insert(items, {title = "Esci dalla cartella (le schede tornano libere)", fn = function() FD.releaseFolder(f) end})
  table.insert(items, {title = "Chiudi cartella (chiude le sue " .. n .. " schede)…", fn = function() FD.closeFolder(f) end})
  table.insert(items, {title = "Aggiorna con le schede di adesso", fn = function() FD.updateFromNow(f) end})
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Modifica le schede…", fn = function() FD.openFolderEditor(f) end})
  table.insert(items, {title = "Rinomina…", fn = function() FD.renameFolder(f) end})
  popup(items, pos)
end

-- Menu del tasto ⊞ (dividi lo schermo)
function openSplitMenu()
  if T.split then exitSplit(); return end
  local items = {}
  for _, id in ipairs(LAYOUT_ORDER) do
    table.insert(items, {title = LAYOUTS[id].name, image = layoutImage(id),
                         fn = function() enterSplit(id) end})
  end
  local ai = activeIndex()
  local t = ai and T.tabs[ai]
  if t and t.group then
    table.insert(items, {title = "-"})
    table.insert(items, {title = "Scambia le app   ⌃⌥S", fn = function() rotateGroup(t.group) end})
    table.insert(items, {title = "Scomponi il gruppo attuale", fn = function() ungroup(t.group) end})
  end
  popup(items, popPos(T.L.split))
end

-- Menu "+N": le schede che non ci stanno
function openOverflow()
  if not T.L or not T.L.overflow then return end
  local items = {}
  for _, i in ipairs(T.L.overflow) do
    local t = T.tabs[i]
    if t then
      local b = badgeFor(t)
      table.insert(items, {
        title = t.name .. (b and ("   (" .. b .. ")") or ""),
        image = keySmallIcon(t.group and t.group.members[1] or t.key),
        fn    = function() switchTo(i) end,
      })
    end
  end
  popup(items, popPos(T.L.more))
end
