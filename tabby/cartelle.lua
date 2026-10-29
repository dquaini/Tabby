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
  runTask(path, args)
end

-- Apre una voce della ricetta che non è aperta, senza portarla davanti
function FD.openItem(it, bk)
  local B = it.bid and BROWSERS[it.bid]
  -- la prossima finestra nuova di quest'app (entro qualche secondo) è quella
  -- della voce: viene legata a lei (vedi T.allWins → windowCreated)
  if bk and it.bid then
    T.pendingBind = T.pendingBind or {}
    T.pendingBind[it.bid] = {bk = bk, at = hs.timer.secondsSinceEpoch()}
  end
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

-- Ricetta fissa: nella finestra della cartella mancano pagine (schede chiuse)?
-- Si riaprono lì. Una pagina "manca" solo se nessuna scheda è più di quel sito
-- (se dentro Notion sei passato a un altro documento, non si riapre).
function FD.reopenMissingPages(it, tab)
  local B = BROWSERS[it.bid]
  if not (B and tab.urls and tab.asId) then return 0 end
  local present = {}
  for _, u in ipairs(tab.urls) do
    local h = u:match("^https?://([^/:]+)")
    if h then present[h:lower():gsub("^www%.", "")] = true end
  end
  local missing = {}
  for _, p in ipairs(it.pages) do
    local c = FD.cleanUrl(p)
    local h = c and c:match("^https?://([^/:]+)")
    if h and not present[h:lower():gsub("^www%.", "")] then table.insert(missing, c) end
  end
  if #missing == 0 then return 0 end
  local src = {'tell application "' .. B.as .. '"', 'tell window id ' .. math.floor(tab.asId)}
  for _, u in ipairs(missing) do
    if B.kind == "safari" then
      table.insert(src, 'make new tab at end of tabs with properties {URL:"' .. u .. '"}')
    else
      table.insert(src, 'make new tab with properties {URL:"' .. u .. '"}')
    end
  end
  table.insert(src, 'end tell'); table.insert(src, 'end tell')
  FD.runTask("/usr/bin/osascript", {"-e", table.concat(src, "\n")})
  print(string.format("Tabby · cartella: riapro %d schede chiuse in «%s»", #missing, tostring(tab.title or tab.name)))
  return #missing
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
  -- 1. apri quello che manca (le altre voci, già aperte, entrano da sole). Chi
  --    c'è e chi manca lo decide il motore delle cartelle (FD.assign), tenendo
  --    conto delle cartelle già attive (una finestra sta in una cartella sola)
  local order = {}
  for _, x in ipairs(FD.activeList()) do if x ~= f then table.insert(order, x) end end
  table.insert(order, f)
  local _, byItem = FD.assign(order, T.allTabs)
  local toOpen, toCheck = {}, {}
  for _, it in ipairs(f.items) do
    local tab = byItem[FD.bindKey(f, it)]
    if not tab then table.insert(toOpen, it)
    elseif it.pages then table.insert(toCheck, {it = it, tab = tab}) end
  end
  local function openAll()
    local opened = 0
    for _, it in ipairs(toOpen) do FD.openItem(it, FD.bindKey(f, it)); opened = opened + 1 end
    for _, x in ipairs(toCheck) do opened = opened + FD.reopenMissingPages(x.it, x.tab) end   -- ricetta fissa: schede chiuse
    print(string.format("Tabby · cartella «%s» attivata: %d voci, %d da aprire", f.name, #f.items, opened))
    -- le app appena aperte non devono portarti via da dove sei
    if opened > 0 and before then
      for _, d in ipairs({1.2, 2.5}) do
        after(d, function()
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
  end
  -- più app da aprire: prima si copre lo schermo (schermata di apertura), poi partono
  -- le app, così non si vede il "ballo" delle finestre che arrivano e si sistemano
  if #toOpen >= 2 then FD.showOpening(f, order, openAll) else openAll() end
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

-- ---------------------------------------------------------------------
--  APERTURA DI UNA CARTELLA CON TANTE FINESTRE (28/10/2026, Daniele: «scatta lo
--  schermo… è brutto vedere scattare le finestre di prima mattina»). Le app arrivano
--  una alla volta, macOS le porta davanti, Tabby le adatta e le nasconde: visto da
--  fuori, un lampeggiare di finestre. Ora una schermata piena (tabby/apertura.html:
--  lo sfondo della Scrivania sfocato, il nome della cartella, le icone che si
--  accendono man mano) copre tutto PRIMA che le app partano, e sfuma via solo quando
--  le finestre sono arrivate e Tabby ha finito di sistemarle. Al massimo 7 s; un clic
--  la toglie subito. Copre anche la barra di Tabby (schermo pulito).
-- ---------------------------------------------------------------------
OPEN_MAX_S    = 7     -- al massimo (un clic la toglie subito)
OPEN_SETTLE_S = 1.0   -- dopo l'ultima finestra arrivata, il tempo per sistemarle
OPEN_MIN_S    = 2.9   -- almeno fino al ritorno alla finestra di prima (1,2 e 2,5 s)

-- Lo sfondo della Scrivania, piccolo (tanto è sfocato): come indirizzo "data:"
function FD.wallpaperURI()
  local ok, url = pcall(function() return screen():desktopImageURL() end)
  if not ok or not url then return nil end
  if T.wallURL == url and T.wallURI then return T.wallURI end
  local path = tostring(url):gsub("^file://", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
  local uri
  pcall(function()
    local img = hs.image.imageFromPath(path)
    if img then uri = img:setSize({w = 480, h = 300}, true):encodeAsURLString(false, "JPEG") end
  end)
  T.wallURL, T.wallURI = url, uri
  return uri
end

function FD.iconURI(it)
  local ok, uri = pcall(function()
    local img = FD.itemIcon(it)
    if not img then return nil end
    local c = img.copy and img:copy() or img
    return c:setSize({w = 128, h = 128}):encodeAsURLString()
  end)
  return ok and uri or nil
end

function FD.ensureOpenView()
  if T.openView then return T.openView end
  T.openUCC = hs.webview.usercontent.new("tabbyopen")
  T.openUCC:setCallback(function(msg)
    local b = msg and msg.body
    if type(b) ~= "table" then return end
    if b.ready then
      T.openReady = true
      if T.openPending then T.openView:evaluateJavaScript(T.openPending); T.openPending = nil end
    end
    if b.shown then FD.openingStart() end
    if b.skip and T.opening then FD.finishOpening("clic") end
  end)
  local page = ""
  local fh = io.open((T.dir or ".") .. "/tabby/apertura.html", "r")
  if fh then page = fh:read("a"); fh:close() end
  T.openView = hs.webview.new(screen():fullFrame(), {developerExtrasEnabled = false}, T.openUCC)
  T.openView:windowStyle({"borderless", "nonactivating"})
  pcall(function() T.openView:transparent(true) end)
  T.openView:allowTextEntry(false)
  T.openView:level(hs.canvas.windowLevels.floating)
  T.openView:behaviorAsLabels({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
  T.openView:html(page)
  return T.openView
end

-- go = la funzione che apre le app: parte quando lo schermo è coperto del tutto
function FD.showOpening(f, order, go)
  if T.opening then FD.finishOpening("nuova cartella") end
  local v = FD.ensureOpenView()
  markViewUsed("openView")
  local st = {f = f, order = order, go = go, here = {}, shownAt = hs.timer.secondsSinceEpoch()}
  T.opening = st
  local items = {}
  for _, it in ipairs(f.items) do table.insert(items, "{icon:" .. jsString(FD.iconURI(it) or "") .. "}") end
  local js = string.format("setup({name:%s,bg:%s,items:[%s]})", jsString(f.name), jsString(FD.wallpaperURI() or ""),
    table.concat(items, ","))
  v:frame(screen():fullFrame())
  v:show()
  pcall(function() v:bringToFront(false) end)   -- (sopra anche la barra di Tabby: schermo pulito)
  if T.openReady then v:evaluateJavaScript(js) else T.openPending = js end
  -- rete di sicurezza: se la pagina non dice «coperto» entro 0,8 s, le app partono lo stesso
  st.safety = after(0.8, function() if T.opening == st then FD.openingStart() end end)
end

-- Lo schermo è coperto: partono le app e Tabby guarda chi arriva
function FD.openingStart()
  local st = T.opening
  if not st or st.started then return end
  st.started = hs.timer.secondsSinceEpoch()
  if st.go then st.go() end
  if T.openTimer then T.openTimer:stop() end
  T.openTimer = hs.timer.doEvery(0.2, function()
    local now = hs.timer.secondsSinceEpoch()
    local _, byItem = FD.assign(st.order, T.allTabs)
    local all = true
    for k, it in ipairs(st.f.items) do
      if byItem[FD.bindKey(st.f, it)] then
        if not st.here[k] then
          st.here[k] = true
          if T.openView then T.openView:evaluateJavaScript("arrive(" .. k .. ")") end
        end
      else all = false end
    end
    if all and not st.allAt then st.allAt = now end
    local ready = st.allAt and now >= math.max(st.allAt + OPEN_SETTLE_S, st.started + OPEN_MIN_S)
    if ready or now - st.started > OPEN_MAX_S then
      FD.finishOpening(ready and "tutto a posto" or ("dopo " .. OPEN_MAX_S .. " s manca ancora qualcosa"))
    end
  end)
end

function FD.finishOpening(why)
  local st = T.opening
  if not st then return end
  T.opening = nil
  if T.openTimer then T.openTimer:stop(); T.openTimer = nil end
  if not st.started then st.started = true; if st.go then st.go() end end   -- (le app non erano ancora partite)
  print("Tabby · cartella «" .. st.f.name .. "»: tolgo la schermata di apertura (" .. tostring(why) .. ")")
  if T.openView then T.openView:evaluateJavaScript("done()") end
  T.openHide = hs.timer.doAfter(0.42, function()
    T.openHide = nil
    if not T.opening and T.openView then T.openView:hide() end
  end)
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
  print("Tabby · chiudo la cartella «" .. f.name .. "» (le sue app e finestre)")
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

-- "Aggiorna con le schede di adesso": la ricetta diventa quello che c'è ora
-- nella cartella (finestre con le loro pagine di adesso; voci chiuse tolte)
function FD.updateFromNow(f)
  local items, seen = {}, {}
  -- le finestre che erano voci "pagine" restano voci "pagine"
  local wasPages = {}
  for _, it in ipairs(f.items) do
    local wid = it.pages and T.itemWins[FD.bindKey(f, it)]
    if wid then wasPages[wid] = true end
  end
  local function addItem(e, win)
    local it = FD.itemOf(e, win and wasPages[win:id()])
    local k = FD.itemKey(it)
    if seen[k] then return end
    seen[k] = true
    table.insert(items, it)
    if win then T.itemWins[FD.bindKey(f, it)] = win:id(); T.itemWinsDirty = true end
  end
  for _, t in ipairs(T.allTabs) do
    if T.tabFolder[t.key] == f then
      if t.group then
        for _, k in ipairs(t.group.members) do
          if T.cand[k] then addItem(T.cand[k], T.keyWin[k]) end
        end
      else
        addItem(t, t.win)
      end
    end
  end
  if #items == 0 then return end
  f.items = items
  save("folders")
  hs.alert.show(string.format("Cartella «%s» aggiornata: %d voci", f.name, #items))
  rebuildTabs()
  draw()
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
  local list, wins = {}, {}
  if t.group then
    for _, k in ipairs(t.group.members) do
      if T.cand[k] then table.insert(list, FD.itemOf(T.cand[k])); wins[#list] = T.keyWin[k] end
    end
  elseif t.bid then
    table.insert(list, FD.itemOf(t)); wins[1] = t.win
  end
  fe.wins = fe.wins or {}
  for n, it in ipairs(list) do
    local dup = false
    for _, x in ipairs(fe.items) do if FD.itemKey(x) == FD.itemKey(it) then dup = true end end
    if not dup then
      table.insert(fe.items, it)
      -- la finestra scelta: al salvataggio la voce viene legata proprio a lei
      if wins[n] then fe.wins[FD.itemKey(it)] = wins[n]:id() end
    end
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
    T.fOverlay:level(hs.canvas.windowLevels.modalPanel or hs.canvas.windowLevels.floating)
    T.fOverlay:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.fOverlay:clickActivating(false)
    T.fOverlay:mouseCallback(FD.onFolderEditMouse)
  else
    T.fOverlay:frame(A)
  end
  -- le voci stanno in una griglia che va a capo (28/10/2026, Daniele: con più di 6 voci
  -- si vedeva solo «+3» sopra l'ultima icona): le vedi sempre tutte, ognuna con la sua ✕
  local pw = math.min(640, A.w - 40)
  local zw = pw - 40
  local cw, th = 84, 100                       -- larghezza e altezza di una voce
  local perRow = math.max(1, math.floor((zw - 16) / cw))
  local n = #fe.items
  local rows = math.max(1, math.ceil(n / perRow))
  local maxZoneH = A.h - 200
  if 16 + rows * th > maxZoneH then           -- tantissime voci: più piccole
    cw, th = 66, 82
    perRow = math.max(1, math.floor((zw - 16) / cw))
    rows = math.max(1, math.ceil(n / perRow))
  end
  local zh = math.min(maxZoneH, math.max(134, 16 + rows * th))
  local ph = 52 + zh + 76
  local px, py = (A.w - pw) / 2, math.max(10, (A.h - ph) / 2)
  local els = {
    {type = "rectangle", action = "fill", fillColor = {white = 0, alpha = 0.5},
     frame = {x = 0, y = 0, w = A.w, h = A.h}},
    {type = "rectangle", action = "strokeAndFill", fillColor = {hex = "#191B20", alpha = 0.98},
     strokeColor = COL.divider, strokeWidth = 1, roundedRectRadii = {xRadius = 14, yRadius = 14},
     frame = {x = px, y = py, w = pw, h = ph}},
    {type = "text", text = (fe.id and "Cartella «" or "Nuova cartella «") .. fe.name .. "»" ..
       (n > 0 and ("  ·  " .. n .. (n == 1 and " voce" or " voci")) or ""),
     textSize = 17, textColor = COL.text, textLineBreak = "truncateTail",
     frame = {x = px + 20, y = py + 16, w = pw - 130, h = 24}},
    {type = "text", text = "rinomina", textSize = 11, textColor = COL.accent, textAlignment = "right",
     frame = {x = px + pw - 110, y = py + 21, w = 90, h = 16}},
    {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01}, trackMouseUp = true,
     id = "fname", frame = {x = px + pw - 110, y = py + 16, w = 90, h = 24}},
  }
  -- il riquadro dove si lasciano le schede
  local zr = {x = px + 20, y = py + 52, w = zw, h = zh}
  T.fZoneAbs = {x = A.x + zr.x, y = A.y + zr.y, w = zr.w, h = zr.h}
  table.insert(els, {type = "rectangle", action = "strokeAndFill",
    fillColor = fe.hover and {hex = "#4C8DFF", alpha = 0.18} or {white = 1, alpha = 0.04},
    strokeColor = fe.hover and COL.accent or {white = 1, alpha = 0.35}, strokeWidth = 2,
    strokeDashPattern = {9, 6}, roundedRectRadii = {xRadius = 12, yRadius = 12}, frame = zr})
  local isz = (cw >= 84) and 40 or 32        -- lato dell'icona
  for k, it in ipairs(fe.items) do
    local col, row = (k - 1) % perRow, math.floor((k - 1) / perRow)
    local cx, cy = zr.x + 8 + col * cw, zr.y + 8 + row * th
    if cy + th > zr.y + zr.h then break end   -- (non succede: il riquadro cresce)
    local im = FD.itemIcon(it)
    if im then
      table.insert(els, {type = "image", image = im, frame = {x = cx + cw / 2 - isz / 2, y = cy + 10, w = isz, h = isz}})
    end
    table.insert(els, {type = "text", text = it.name or it.site or it.bid, textSize = 11.5,
      textColor = COL.text, textAlignment = "center", textLineBreak = "truncateTail",
      frame = {x = cx + 2, y = cy + 16 + isz, w = cw - 4, h = 16}})
    -- la ✕ per toglierla, in alto a destra dell'icona
    local bx, by = cx + cw / 2 + isz / 2 - 7, cy + 4
    table.insert(els, {type = "circle", action = "fill", fillColor = {hex = "#3A3D45"},
      center = {x = bx + 8, y = by + 8}, radius = 9})
    table.insert(els, {type = "text", text = "✕", textSize = 9.5, textColor = COL.text, textAlignment = "center",
      frame = {x = bx, y = by + 2, w = 16, h = 14}})
    table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
      trackMouseUp = true, id = "fitem" .. k, frame = {x = bx - 4, y = by - 4, w = 24, h = 24}})
  end
  if n < perRow and (zr.w - 8 - n * cw) > 190 then
    local hx = zr.x + 8 + n * cw
    table.insert(els, {type = "text", text = "Trascina qui le schede di Tabby (o cliccale)",
      textSize = 14, textColor = {white = 1, alpha = 0.75},
      frame = {x = hx + 10, y = zr.y + 48, w = zr.x + zr.w - hx - 20, h = 40}})
  end
  table.insert(els, {type = "text", text = "Esc annulla · Invio fatto", textSize = 11.5, textColor = COL.textDim,
    frame = {x = px + 20, y = py + ph - 44, w = 220, h = 18}})
  button(els, {x = px + pw - 228, y = py + ph - 52, w = 104, h = 34}, "Annulla  esc", COL.active, "fcancel")
  button(els, {x = px + pw - 116, y = py + ph - 52, w = 104, h = 34}, "Fatto  ↩", COL.accent, "fdone")
  T.fOverlay:replaceElements(els)
  T.fOverlay:show()
  barOverOverlays(true)
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
  barOverOverlays(T.split ~= nil)
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
  -- ogni voce si lega alla finestra che hai scelto (es. quale delle due Gmail)
  for _, it in ipairs(f.items) do
    local wid = fe.wins and fe.wins[FD.itemKey(it)]
    if wid then T.itemWins[FD.bindKey(f, it)] = wid; T.itemWinsDirty = true end
  end
  save("folders"); save("folderSeq")
  local n = 1
  for i, x in ipairs(S.folders) do if x == f then n = i end end
  hs.alert.show(string.format("Cartella «%s» salvata · menu ⚡︎ o ⌃⌥⇧%d", f.name, n))
  rebuildTabs()
  draw()
end
