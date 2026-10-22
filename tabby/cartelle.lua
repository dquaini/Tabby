-- =====================================================================
--  Tabby · cartelle.lua: le cartelle: attivare, vista cartella, chiudere, creare e modificare.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  CARTELLE: ATTIVARE, VISTA CARTELLA, CHIUDERE
--  Attivare una cartella (menu ⚡︎ o ⌃⌥⇧ + numero) apre quello che manca e
--  non ti sposta: se sei su una sua scheda entri nella vista cartella (solo
--  le sue schede, nome a sinistra / in alto); se sei altrove la cartella
--  compare come una scheda sola e tu resti dove sei.
-- ---------------------------------------------------------------------

-- Comandi per aprire una finestra nuova di un browser (sito o finestra vuota)
FD.OPEN_SITE = {
  chrome = 'tell application "%s"\nset w to make new window\nset URL of active tab of w to "%s"\nend tell',
  safari = 'tell application "%s"\nmake new document with properties {URL:"%s"}\nend tell',
}
FD.OPEN_WIN = {
  chrome = 'tell application "%s" to make new window',
  safari = 'tell application "%s" to make new document',
}

function FD.runTask(path, args)
  local t = hs.task.new(path, nil, args)
  if t then t:start() end
end

-- Apre una voce della ricetta che non è aperta, senza portarla davanti
function FD.openItem(it)
  local B = it.bid and BROWSERS[it.bid]
  if it.pages then
    -- finestra con più pagine: Chrome/Safari ne aprono una nuova con tutte le
    -- pagine come schede; gli altri browser le aprono come schede
    local pages = {}
    for _, p in ipairs(it.pages) do local c = FD.cleanUrl(p); if c then table.insert(pages, c) end end
    if #pages == 0 then return end
    if B and B.kind == "chrome" then
      local src = {'tell application "' .. B.as .. '"', 'set w to make new window',
                   'set URL of active tab of w to "' .. pages[1] .. '"'}
      for i = 2, #pages do
        table.insert(src, 'tell w to make new tab with properties {URL:"' .. pages[i] .. '"}')
      end
      table.insert(src, 'end tell')
      FD.runTask("/usr/bin/osascript", {"-e", table.concat(src, "\n")})
    elseif B and B.kind == "safari" then
      local src = {'tell application "' .. B.as .. '"',
                   'make new document with properties {URL:"' .. pages[1] .. '"}'}
      for i = 2, #pages do
        table.insert(src, 'tell front window to make new tab at end of tabs with properties {URL:"' .. pages[i] .. '"}')
      end
      table.insert(src, 'end tell')
      FD.runTask("/usr/bin/osascript", {"-e", table.concat(src, "\n")})
    else
      local args = {"-g", "-b", it.bid}
      for _, p in ipairs(pages) do table.insert(args, p) end
      FD.runTask("/usr/bin/open", args)
    end
  elseif it.site then
    if not it.site:match("^[%w%.%-]+$") then return end
    local url = "https://" .. it.site .. "/"
    if B and FD.OPEN_SITE[B.kind] then
      FD.runTask("/usr/bin/osascript", {"-e", string.format(FD.OPEN_SITE[B.kind], B.as, url)})
    else
      -- DuckDuckGo non accetta comandi: il sito si apre come scheda del browser
      FD.runTask("/usr/bin/open", {"-g", "-b", it.bid or "com.apple.Safari", url})
    end
  elseif B and FD.OPEN_WIN[B.kind] and appFor(it.bid) then
    FD.runTask("/usr/bin/osascript", {"-e", string.format(FD.OPEN_WIN[B.kind], B.as)})
  elseif it.bid then
    FD.runTask("/usr/bin/open", {"-g", "-b", it.bid})
  end
end

-- La scheda in cui sei appartiene alla cartella f?
function FD.currentInFolder(f)
  local key = currentKey()
  if not key then return false end
  local g = T.memberOf[key]
  local cf = T.tabFolder[key] or (g and T.tabFolder["g:" .. g.id])
  return cf ~= nil and cf.id == f.id
end

-- Vista cartella: si vedono solo le schede della cartella
FD.enterFolder = function(f)
  if not f or not S.folderView then return end
  T.viewFolder = f.id
  rebuildTabs()
  if not FD.currentInFolder(f) then
    -- torna all'ultima scheda usata della cartella (o alla prima)
    local idx = 1
    for i, t in ipairs(T.tabs) do if t.key == T.folderLast[f.id] then idx = i end end
    if T.tabs[idx] then switchTo(idx) end
  end
  draw()
end

function FD.leaveFolderView()
  T.viewFolder = nil
  rebuildTabs()
  draw()
end

function FD.activateFolder(f)
  if not f then return end
  T.folderStart[f.id] = hs.timer.secondsSinceEpoch()
  local before = hs.window.focusedWindow()
  -- 1. apri quello che manca (le altre voci, già aperte, entrano da sole)
  local opened = 0
  for _, it in ipairs(f.items) do
    local present = false
    for _, e in pairs(T.cand) do if FD.itemMatches(it, e) then present = true; break end end
    if not present then FD.openItem(it); opened = opened + 1 end
  end
  print(string.format("Tabby · cartella «%s» attivata: %d voci, %d da aprire", f.name, #f.items, opened))
  -- le app appena aperte non devono portarti via da dove sei
  if opened > 0 and before then
    for _, d in ipairs({1.2, 2.5}) do
      hs.timer.doAfter(d, function()
        local now = hs.window.focusedWindow()
        if now and before:id() and now:id() ~= before:id() and before:application() then
          local nb = now:application() and now:application():bundleID()
          for _, it in ipairs(f.items) do
            if it.bid == nb then before:focus(); break end
          end
        end
      end)
    end
  end
  if not S.folderView then return end   -- Vista cartelle spenta: solo aprire
  if not FD.isFolderActive(f.id) then
    table.insert(S.activeFolders, f.id)
    save("activeFolders")
  end
  rebuildTabs()
  -- 2. sei su una sua scheda? entri nella vista cartella, restando lì
  if FD.currentInFolder(f) then T.viewFolder = f.id; rebuildTabs() end
  draw()
end

-- ⌃⌥⇧ + numero: attiva la cartella; se la stai già guardando, torni a tutte
function FD.folderShortcut(n)
  local f = S.folders[n]
  if not f then return end
  if T.viewFolder == f.id then FD.leaveFolderView() else FD.activateFolder(f) end
end

-- "Esci dalla cartella": le sue schede tornano libere
function FD.releaseFolder(f)
  for i = #S.activeFolders, 1, -1 do
    if S.activeFolders[i] == f.id then table.remove(S.activeFolders, i) end
  end
  save("activeFolders")
  if T.viewFolder == f.id then T.viewFolder = nil end
  rebuildTabs()
  draw()
end

-- "Chiudi cartella": chiude le sue app (per le webapp e le finestre di un
-- browser, solo quelle finestre: il browser resta aperto per il resto)
function FD.closeFolder(f)
  local btn = FD.ask(function()
    return hs.dialog.blockAlert("Chiudere la cartella «" .. f.name .. "»?",
      "Si chiudono le sue app e le sue finestre. Le app con documenti non salvati ti chiederanno cosa fare.",
      "Chiudi", "Annulla")
  end)
  if btn ~= "Chiudi" then return end
  local killed = {}
  for _, t in ipairs(T.allTabs) do
    if T.tabFolder[t.key] == f then
      local list = t.group and t.group.members or {t.key}
      for _, k in ipairs(list) do
        local e = T.cand[k]
        if e and (BROWSERS[e.bid] or e.bid == FINDER) then
          if e.win then e.win:close() end
        elseif e and e.app and not killed[e.bid] then
          killed[e.bid] = true
          e.app:kill()
        end
      end
    end
  end
  FD.releaseFolder(f)
  scheduleRebuild()
end

function FD.deleteFolder(f)
  FD.releaseFolder(f)
  for i = #S.folders, 1, -1 do if S.folders[i] == f then table.remove(S.folders, i) end end
  save("folders")
  rebuildTabs()
  draw()
end

-- Fa una domanda con una finestra di Tabby (Hammerspoon), poi ti riporta
-- alla finestra in cui eri
function FD.ask(fn)
  local prev = hs.window.focusedWindow()
  hs.focus()
  local a, b = fn()
  if prev and prev:application() then prev:focus() end
  return a, b
end

function FD.renameFolder(f)
  local btn, txt = FD.ask(function()
    return hs.dialog.textPrompt("Rinomina la cartella", "Nuovo nome:", f.name, "Rinomina", "Annulla")
  end)
  txt = txt and txt:match("^%s*(.-)%s*$")
  if btn ~= "Rinomina" or not txt or txt == "" then return end
  f.name = txt
  save("folders")
  rebuildTabs()
  draw()
end

-- Icona di una voce della ricetta (logo del sito o icona dell'app)
function FD.itemIcon(it)
  return (it.site and favicon(it.site)) or icon(it.bid)
end

-- Piccola immagine con le prime tre icone della cartella, per i menu
function FD.folderImage(f)
  local ok, img = pcall(function()
    local n = math.min(#f.items, 3)
    if n == 0 then return nil end
    local W, H = 16 + (n - 1) * 10, 16
    local c = hs.canvas.new({x = 0, y = 0, w = W, h = H})
    local els = {}
    for k = n, 1, -1 do
      local im = FD.itemIcon(f.items[k])
      if im then table.insert(els, {type = "image", image = im, frame = {x = (k - 1) * 10, y = 0, w = 16, h = 16}}) end
    end
    c:replaceElements(els)
    local im = c:imageFromCanvas()
    c:delete()
    return im
  end)
  return ok and img or nil
end


-- ---------------------------------------------------------------------
--  CARTELLE: CREARE E MODIFICARE (menu ⚡︎ → Nuova cartella…)
--  Si sceglie il nome, poi compare un riquadro con già la scheda in cui
--  sei; ci trascini (o clicchi) le altre schede di Tabby. Fatto = salvata.
-- ---------------------------------------------------------------------

-- Aggiunge al riquadro una scheda di Tabby (una vista divisa = i suoi membri)
function FD.feditAdd(t)
  local fe = T.fedit
  if not fe or not t or t.folder then return end
  local list = {}
  if t.group then
    for _, k in ipairs(t.group.members) do if T.cand[k] then table.insert(list, FD.itemOf(T.cand[k])) end end
  elseif t.bid then
    table.insert(list, FD.itemOf(t))
  end
  for _, it in ipairs(list) do
    local dup = false
    for _, x in ipairs(fe.items) do if FD.itemKey(x) == FD.itemKey(it) then dup = true end end
    if not dup then table.insert(fe.items, it) end
  end
  fe.hover = false
  FD.drawFolderEdit()
end

function FD.onFolderEditMouse(_, msg, id)
  if msg ~= "mouseUp" then return end
  id = tostring(id)
  if id == "fcancel" then FD.cancelFolderEdit(); return end
  if id == "fdone" then FD.finishFolderEdit(); return end
  if id == "fname" then
    local btn, txt = FD.ask(function()
      return hs.dialog.textPrompt("Nome della cartella", "", T.fedit.name, "OK", "Annulla")
    end)
    txt = txt and txt:match("^%s*(.-)%s*$")
    if btn == "OK" and txt and txt ~= "" then T.fedit.name = txt end
    FD.drawFolderEdit()
    return
  end
  local k = tonumber(id:match("^fitem(%d+)$"))
  if k and T.fedit then table.remove(T.fedit.items, k); FD.drawFolderEdit() end
end

FD.drawFolderEdit = function()
  local fe = T.fedit
  if not fe then return end
  local A = appArea()
  if not T.fOverlay then
    T.fOverlay = hs.canvas.new(A)
    T.fOverlay:level(hs.canvas.windowLevels.floating)
    T.fOverlay:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.fOverlay:clickActivating(false)
    T.fOverlay:mouseCallback(FD.onFolderEditMouse)
  else
    T.fOverlay:frame(A)
  end
  local pw = math.min(600, A.w - 40)
  local ph = 262
  local px, py = (A.w - pw) / 2, (A.h - ph) / 2
  local els = {
    {type = "rectangle", action = "fill", fillColor = {white = 0, alpha = 0.5},
     frame = {x = 0, y = 0, w = A.w, h = A.h}},
    {type = "rectangle", action = "strokeAndFill", fillColor = {hex = "#191B20", alpha = 0.98},
     strokeColor = COL.divider, strokeWidth = 1, roundedRectRadii = {xRadius = 14, yRadius = 14},
     frame = {x = px, y = py, w = pw, h = ph}},
    {type = "text", text = (fe.id and "Cartella «" or "Nuova cartella «") .. fe.name .. "»",
     textSize = 17, textColor = COL.text, textLineBreak = "truncateTail",
     frame = {x = px + 20, y = py + 16, w = pw - 130, h = 24}},
    {type = "text", text = "rinomina", textSize = 11, textColor = COL.accent, textAlignment = "right",
     frame = {x = px + pw - 110, y = py + 21, w = 90, h = 16}},
    {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01}, trackMouseUp = true,
     id = "fname", frame = {x = px + pw - 110, y = py + 16, w = 90, h = 24}},
  }
  -- il riquadro dove si lasciano le schede
  local zr = {x = px + 20, y = py + 52, w = pw - 40, h = 134}
  T.fZoneAbs = {x = A.x + zr.x, y = A.y + zr.y, w = zr.w, h = zr.h}
  table.insert(els, {type = "rectangle", action = "strokeAndFill",
    fillColor = fe.hover and {hex = "#4C8DFF", alpha = 0.18} or {white = 1, alpha = 0.04},
    strokeColor = fe.hover and COL.accent or {white = 1, alpha = 0.35}, strokeWidth = 2,
    strokeDashPattern = {9, 6}, roundedRectRadii = {xRadius = 12, yRadius = 12}, frame = zr})
  local cw = 84
  local perRow = math.max(1, math.floor((zr.w - 16) / cw))
  for k, it in ipairs(fe.items) do
    if k > perRow then
      table.insert(els, {type = "text", text = "+" .. (#fe.items - perRow + 1), textSize = 14,
        textColor = COL.textMid, textAlignment = "center",
        frame = {x = zr.x + 8 + (perRow - 1) * cw, y = zr.y + 40, w = cw, h = 20}})
      break
    end
    local cx = zr.x + 8 + (k - 1) * cw
    local im = FD.itemIcon(it)
    if im then
      table.insert(els, {type = "image", image = im, frame = {x = cx + cw / 2 - 20, y = zr.y + 18, w = 40, h = 40}})
    end
    table.insert(els, {type = "text", text = it.name or it.site or it.bid, textSize = 11.5,
      textColor = COL.text, textAlignment = "center", textLineBreak = "truncateTail",
      frame = {x = cx + 2, y = zr.y + 64, w = cw - 4, h = 16}})
    table.insert(els, {type = "text", text = "✕ togli", textSize = 10, textColor = COL.textDim,
      textAlignment = "center", frame = {x = cx, y = zr.y + 82, w = cw, h = 14}})
    table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
      trackMouseUp = true, id = "fitem" .. k, frame = {x = cx, y = zr.y + 10, w = cw, h = 92}})
  end
  if #fe.items < 2 then
    local hx = zr.x + 8 + #fe.items * cw
    table.insert(els, {type = "text", text = "Trascina qui le schede di Tabby (o cliccale)",
      textSize = 14, textColor = {white = 1, alpha = 0.75},
      frame = {x = hx + 10, y = zr.y + zr.h / 2 - 10, w = zr.x + zr.w - hx - 20, h = 20}})
  end
  table.insert(els, {type = "text", text = "Esc annulla · Invio fatto", textSize = 11.5, textColor = COL.textDim,
    frame = {x = px + 20, y = py + ph - 44, w = 220, h = 18}})
  button(els, {x = px + pw - 228, y = py + ph - 52, w = 104, h = 34}, "Annulla  esc", COL.active, "fcancel")
  button(els, {x = px + pw - 116, y = py + ph - 52, w = 104, h = 34}, "Fatto  ↩", COL.accent, "fdone")
  T.fOverlay:replaceElements(els)
  T.fOverlay:show()
  if T.bar then T.bar:orderAbove(T.fOverlay) end
end

-- f = cartella da modificare; nil = cartella nuova (chiede il nome)
function FD.openFolderEditor(f)
  if T.split then exitSplit() end
  local fe = {id = f and f.id, name = f and f.name, items = {}, hover = false}
  -- la scheda in cui sei (presa prima della domanda, che porta davanti Tabby)
  local ai = activeIndex()
  local cur = ai and T.tabs[ai]
  if f then
    for _, it in ipairs(f.items) do table.insert(fe.items, it) end
  else
    local btn, txt = FD.ask(function()
      return hs.dialog.textPrompt("Nuova cartella", "Come si chiama? (es. Lavoro, Studio)", "", "Avanti", "Annulla")
    end)
    txt = txt and txt:match("^%s*(.-)%s*$")
    if btn ~= "Avanti" or not txt or txt == "" then return end
    fe.name = txt
  end
  T.fedit = fe
  -- si parte dalla scheda in cui sei
  if not f and cur then FD.feditAdd(cur) end
  T.revealed = true
  FD.drawFolderEdit()
  draw()
end

FD.cancelFolderEdit = function()
  T.fedit = nil
  if T.fOverlay then T.fOverlay:hide() end
  draw()
end

FD.finishFolderEdit = function()
  local fe = T.fedit
  if not fe then return end
  FD.cancelFolderEdit()
  if #fe.items == 0 then return end
  local f = fe.id and FD.folderById(fe.id)
  if not f then
    S.folderSeq = (S.folderSeq or 0) + 1
    f = {id = S.folderSeq}
    table.insert(S.folders, f)
  end
  f.name, f.items = fe.name, fe.items
  -- una voce sta in una sola cartella: le altre cartelle la lasciano
  local mine = {}
  for _, it in ipairs(f.items) do mine[FD.itemKey(it)] = true end
  for i = #S.folders, 1, -1 do
    local o = S.folders[i]
    if o ~= f then
      for j = #o.items, 1, -1 do if mine[FD.itemKey(o.items[j])] then table.remove(o.items, j) end end
      if #o.items == 0 then table.remove(S.folders, i) end
    end
  end
  save("folders"); save("folderSeq")
  local n = 1
  for i, x in ipairs(S.folders) do if x == f then n = i end end
  hs.alert.show(string.format("Cartella «%s» salvata · menu ⚡︎ o ⌃⌥⇧%d", f.name, n))
  rebuildTabs()
  draw()
end
