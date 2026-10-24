-- =====================================================================
--  Tabby · disegno.lua: il disegno della barra e "Nascondi Tabby".
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  DISEGNO DI TABBY
-- ---------------------------------------------------------------------

function onMouse(_, msg, id)
  id = tostring(id)
  if id == "battery" then
    if msg == "mouseEnter" then showBatteryTip(true) elseif msg == "mouseExit" then showBatteryTip(false) end
    return
  end
  local ti = tonumber(id:match("^tab(%d+)$"))
  if msg == "mouseDown" then
    if ti then startPress(ti) end
    return
  end
  if msg ~= "mouseUp" then return end
  if T.suppressClick then T.suppressClick = false; return end   -- era un trascinamento

  if id == "settings" then openSettings(); return end
  -- ripiano dei Lampi coperti: uno o tutti davanti
  local lk = id:match("^lampshelf:(.+)$")
  if lk then bringLamps({lk}); return end
  if id == "lampshelfall" then
    local all = {}
    for _, k in ipairs(T.coveredLamps) do table.insert(all, k) end
    bringLamps(all); return
  end
  if id == "quick" then openQuick(); return end
  if id == "split" then openSplitMenu(); return end
  if id == "more" then openOverflow(); return end
  if id == "desktop" then catClick(false); return end
  if id == "plus" then openSpotlight(); return end
  if id == "fback" then FD.leaveFolderView(); return end
  if id == "fhead" then
    local f = FD.folderById(T.viewFolder)
    if f then FD.openFolderMenu(f, popPos(T.L.fhead)) end
    return
  end
  local fm = tonumber(id:match("^fmenu(%d+)$"))
  if fm then
    local t = T.tabs[fm]
    if t and t.folder then FD.openFolderMenu(t.folder, T.closePos[fm]) end
    return
  end
  local c = tonumber(id:match("^close(%d+)$"))
  if c then openCloseMenu(c); return end
  local ro = tonumber(id:match("^rotate(%d+)$"))
  if ro then
    local t = T.tabs[ro]
    if t and t.group then rotateGroup(t.group) end
    return
  end
  local u = tonumber(id:match("^ungroup(%d+)$"))
  if u then
    local t = T.tabs[u]
    if t and t.group then ungroup(t.group) end
    return
  end
  if ti then
    if T.split then assignFirstEmpty(ti)
    elseif T.fedit then FD.feditAdd(T.tabs[ti])
    elseif T.tabs[ti] and T.tabs[ti].folder then
      -- clic sulla scheda-cartella: scegli su quale app aprirla
      local r
      for _, tv in ipairs(T.L.tabs) do if tv.i == ti then r = tv.r end end
      FD.openFolderChooser(T.tabs[ti].folder, r and popPos(r) or nil)
    else switchTo(ti) end
  end
end

function setVisible(v)
  if v == T.visible then return end
  T.visible = v
  if v then T.bar:show(0.12) else T.bar:hide(0.12) end
end

function hitArea(id, frame, withDown)
  return {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
          trackMouseUp = true, trackMouseDown = withDown or nil, id = id, frame = frame}
end

function divider(r)
  return {type = "rectangle", action = "fill", fillColor = COL.divider, frame = r}
end

-- Le prime "cap" schede, assicurandosi che quella attiva ci sia sempre
function pickVisible(n, cap, activeIdx)
  local vis, set = {}, {}
  for i = 1, n do
    if #vis < cap then table.insert(vis, i); set[i] = true end
  end
  if activeIdx and not set[activeIdx] and #vis > 0 then
    set[vis[#vis]] = nil
    vis[#vis] = activeIdx
    set[activeIdx] = true
    table.sort(vis)
  end
  local over = {}
  for i = 1, n do if not set[i] then table.insert(over, i) end end
  return vis, over
end

-- Batteria: chiedere a macOS costa ~16 ms (misurato), e prima succedeva due
-- volte a ogni disegno. Ora Tabby se la ricorda (T.bat) e la rilegge solo
-- quando macOS avvisa di un cambio (T.batWatcher) e all'avvio.
function T.readBattery()
  local pct = hs.battery.percentage()
  T.bat = pct and {
    pct = math.floor(pct + 0.5),
    charging = hs.battery.isCharging() or hs.battery.powerSource() == "AC Power",
  } or false
end
function hasBattery()
  if T.bat == nil then T.readBattery() end
  return T.bat ~= false
end

-- Dove va ogni pezzo di Tabby (orizzontale o verticale).
-- Con tante app: prima le schede si stringono, poi diventano solo icona
-- (tranne quella attiva), infine le ultime finiscono nel menu "+N".
-- Il gatto intero per Tabby laterale (nil se Tabby è in alto/in basso o se
-- manca l'immagine). on = scrivania attiva (gatto chiaro)
function catFullImage(on)
  if not isVertical() or not T.catFull then return nil end
  local side = T.catFull[S.position == "left" and "sinistra" or "destra"]
  return side and (on and side.on or side.off) or nil
end

function layout(bf, activeIdx)
  local L = {tabs = {}, dividers = {}}
  local n = #T.tabs
  local w, h = bf.w, bf.h
  local bat = hasBattery()

  if isVertical() then
    -- in cima la scrivania; in fondo batteria e poi ⊞ ⚡︎ ⚙︎; in mezzo le schede
    local bottomY = h - BTN_W
    local batH    = bat and 30 or 0
    local third   = w / 3
    -- in cima il gatto intero (se c'è l'immagine): un po' più di spazio
    local deskH   = catFullImage(false) and 92 or BTN_W
    local top     = menuPad()   -- fascia nera sotto la barra dei menu, se scende
    L.desk     = {x = 0, y = top, w = w, h = deskH}
    -- Lampi coperti: il tasto ⚡︎ diventa una riga intera sopra ⊞ ⚙︎, con le icone dei
    -- Lampi da riportare davanti e «Tutti» (un solo ⚡︎ in Tabby, 23/10/2026)
    local lampH = (#T.coveredLamps > 0) and 36 or 0
    if lampH > 0 then
      L.split    = {x = 0, y = bottomY, w = w / 2, h = BTN_W}
      L.settings = {x = w / 2, y = bottomY, w = w / 2, h = BTN_W}
      L.quick    = {x = 0, y = bottomY - lampH, w = w, h = lampH}
      L.quickWide = true
      table.insert(L.dividers, {x = w / 2, y = bottomY + 8, w = 1, h = BTN_W - 16})
    else
      L.split    = {x = 0, y = bottomY, w = third, h = BTN_W}
      L.quick    = {x = third, y = bottomY, w = third, h = BTN_W}
      L.quickWide = false
      L.settings = {x = third * 2, y = bottomY, w = third, h = BTN_W}
      table.insert(L.dividers, {x = third, y = bottomY + 8, w = 1, h = BTN_W - 16})
      table.insert(L.dividers, {x = third * 2, y = bottomY + 8, w = 1, h = BTN_W - 16})
    end
    if bat then L.battery = {x = 0, y = bottomY - lampH - batH, w = w, h = batH} end
    table.insert(L.dividers, {x = 8, y = top + deskH, w = w - 16, h = 1})
    if bat then table.insert(L.dividers, {x = 8, y = bottomY - lampH - batH, w = w - 16, h = 1}) end
    if lampH > 0 then table.insert(L.dividers, {x = 8, y = bottomY - lampH, w = w - 16, h = 1}) end
    table.insert(L.dividers, {x = 8, y = bottomY, w = w - 16, h = 1})
    batH = batH + lampH   -- (per lo spazio delle schede qui sotto)

    local start  = top + deskH + 6
    -- vista cartella: in cima "← Tutte le schede" e il nome della cartella
    if T.viewFolder and FD.folderById(T.viewFolder) then
      L.fback = {x = 0, y = top + deskH + 2, w = w, h = 26}
      L.fhead = {x = 0, y = top + deskH + 28, w = w, h = 30}
      table.insert(L.dividers, {x = 8, y = top + deskH + 60, w = w - 16, h = 1})
      start = top + deskH + 66
    end
    -- in fondo alle schede, la scheda "+" (apre Spotlight)
    local availH = bottomY - batH - 6 - start - MIN_ROW_H
    L.plus = {x = 0, y = start, w = w, h = MIN_ROW_H}
    if n > 0 then
      local rowH = math.floor(math.min(ROW_H, availH / n))
      local vis, over
      if rowH >= MIN_ROW_H then
        vis, over = pickVisible(n, n, activeIdx)
      else
        rowH = MIN_ROW_H
        local cap = math.max(1, math.floor((availH - MIN_ROW_H) / MIN_ROW_H))
        vis, over = pickVisible(n, cap, activeIdx)
      end
      for k, i in ipairs(vis) do
        table.insert(L.tabs, {i = i, r = {x = 0, y = start + (k - 1) * rowH, w = w, h = rowH}})
      end
      local y = start + #vis * rowH
      if #over > 0 then
        L.more = {x = 0, y = y, w = w, h = MIN_ROW_H}
        L.overflow = over
        y = y + MIN_ROW_H
      end
      L.plus = {x = 0, y = y, w = w, h = MIN_ROW_H}
    end
  else
    -- a sinistra la scrivania; a destra batteria, ⊞ ⚡︎ ⚙︎; in mezzo le schede
    local batW   = bat and BAT_W or 0
    -- Lampi coperti: il tasto ⚡︎ si allarga e accanto al fulmine mostra le loro icone
    -- e «Tutti» (un solo ⚡︎ in Tabby, 23/10/2026)
    local nl     = #T.coveredLamps
    local quickW = BTN_W + ((nl > 0) and (nl * 26 + (nl >= 2 and 44 or 0) + 6) or 0)
    local rightW = BTN_W * 2 + quickW + batW
    L.desk     = {x = 0, y = 0, w = BTN_W, h = h}
    L.settings = {x = w - BTN_W, y = 0, w = BTN_W, h = h}
    L.quick    = {x = w - BTN_W - quickW, y = 0, w = quickW, h = h}
    L.quickWide = nl > 0
    L.split    = {x = w - BTN_W * 2 - quickW, y = 0, w = BTN_W, h = h}
    if bat then L.battery = {x = w - rightW, y = 0, w = batW, h = h} end
    table.insert(L.dividers, {x = BTN_W, y = 8, w = 1, h = h - 16})
    if bat then table.insert(L.dividers, {x = w - rightW, y = 8, w = 1, h = h - 16}) end
    table.insert(L.dividers, {x = L.split.x, y = 8, w = 1, h = h - 16})
    table.insert(L.dividers, {x = L.quick.x, y = 8, w = 1, h = h - 16})
    table.insert(L.dividers, {x = L.settings.x, y = 8, w = 1, h = h - 16})

    local start = BTN_W + 6
    local PLUS_W = 36   -- la scheda "+" in fondo alle schede
    local avail = w - BTN_W - rightW - 12 - PLUS_W
    -- vista cartella: a sinistra "←" e il nome della cartella
    local vf = T.viewFolder and FD.folderById(T.viewFolder)
    if vf then
      local fw = math.floor(math.min(210, 62 + (utf8.len(vf.name) or 6) * 7.5))
      L.fback = {x = BTN_W, y = 0, w = 30, h = h}
      L.fhead = {x = BTN_W + 30, y = 0, w = fw - 30, h = h}
      table.insert(L.dividers, {x = BTN_W + fw, y = 8, w = 1, h = h - 16})
      start = BTN_W + fw + 6
      avail = avail - fw
    end
    -- notch: le schede ci saltano sopra
    local nz = notchZone(bf)
    if nz then avail = avail - (nz.x2 - nz.x1) end
    local function place(x, ww)
      if nz and x < nz.x2 and x + ww > nz.x1 then return nz.x2 end
      return x
    end
    L.notch = nz

    -- quante schede larghe "tw" ci stanno davvero (a sinistra e a destra del notch)
    local endX = w - rightW - 6 - PLUS_W
    local function fits(tw)
      if not nz then return math.floor((endX - start) / tw) end
      return math.max(0, math.floor((nz.x1 - start) / tw))
           + math.max(0, math.floor((endX - nz.x2) / tw))
    end

    L.plus = {x = place(start, PLUS_W), y = 0, w = PLUS_W, h = h}
    if n > 0 then
      local tabW = math.floor(math.min(TAB_MAX_W, avail / n))
      while tabW >= COMPACT_BELOW and fits(tabW) < n do tabW = tabW - 2 end
      if tabW >= COMPACT_BELOW then
        local x = start
        for i = 1, n do
          x = place(x, tabW)
          table.insert(L.tabs, {i = i, r = {x = x, y = 0, w = tabW, h = h}})
          x = x + tabW
        end
        L.plus = {x = place(x, PLUS_W), y = 0, w = PLUS_W, h = h}
      else
        -- modalità compatta: solo icone, l'attiva resta larga col nome
        local big = activeIdx and ACTIVE_W or 0
        local smalls = n - (activeIdx and 1 or 0)
        -- col notch, il salto può sprecare fino a una scheda larga: teniamone conto
        if nz then avail = avail - ACTIVE_W end
        local vis, over
        if smalls * ICON_W + big <= avail then
          vis, over = pickVisible(n, n, activeIdx)
        else
          local cap = math.floor((avail - ICON_W - big) / ICON_W) + (activeIdx and 1 or 0)
          vis, over = pickVisible(n, math.max(1, cap), activeIdx)
        end
        local x = start
        for _, i in ipairs(vis) do
          local ww = (i == activeIdx) and ACTIVE_W or ICON_W
          x = place(x, ww)
          table.insert(L.tabs, {i = i, compact = (i ~= activeIdx),
                                r = {x = x, y = 0, w = ww, h = h}})
          x = x + ww
        end
        if #over > 0 then
          L.more = {x = place(x, ICON_W), y = 0, w = ICON_W, h = h}
          L.overflow = over
          x = L.more.x + ICON_W
        end
        L.plus = {x = place(x, PLUS_W), y = 0, w = PLUS_W, h = h}
      end
    end
  end
  return L
end

-- Indicatore batteria: verde da 80% in su, normale fino al 35%,
-- rosso sotto il 35% (se non è in carica). ⚡︎ = in carica.
function drawBattery(els, r)
  if not hasBattery() then return end
  local pct, charging = T.bat.pct, T.bat.charging
  local col
  if pct >= 80 then col = COL.batFull
  elseif pct < 35 and not charging then col = COL.batLow
  else col = COL.textMid end

  -- solo l'icona (v9.49): la percentuale compare passandoci sopra col puntatore
  local groupW = 26
  local bx = r.x + (r.w - groupW) / 2
  local by = r.y + r.h / 2 - 6
  table.insert(els, {type = "rectangle", action = "stroke", strokeColor = COL.textDim,
    strokeWidth = 1, roundedRectRadii = {xRadius = 3, yRadius = 3},
    frame = {x = bx, y = by, w = 22, h = 12}})
  table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.textDim,
    roundedRectRadii = {xRadius = 1, yRadius = 1},
    frame = {x = bx + 23, y = by + 3.5, w = 2, h = 5}})
  table.insert(els, {type = "rectangle", action = "fill", fillColor = col,
    roundedRectRadii = {xRadius = 1.5, yRadius = 1.5},
    frame = {x = bx + 2, y = by + 2, w = math.max(1.5, 18 * pct / 100), h = 8}})
  if charging then
    table.insert(els, {type = "text", text = "⚡︎", textSize = 9, textColor = COL.text,
      textAlignment = "center", frame = {x = bx, y = by - 0.5, w = 22, h = 12}})
  end
  table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
    trackMouseEnterExit = true, id = "battery", frame = r})
end

-- Il fumetto con la percentuale, accanto alla batteria (dalla parte delle app)
function showBatteryTip(on)
  if not on or not hasBattery() or not T.L or not T.L.battery then
    if T.batTip then T.batTip:hide() end
    return
  end
  local r, bf = T.L.battery, T.bf
  local txt = T.bat.pct .. "%" .. (T.bat.charging and "  ·  in carica" or "")
  local tw, th = (T.bat.charging and 118 or 52), 26
  local p, x, y = S.position
  if p == "top" then x, y = bf.x + r.x + r.w / 2 - tw / 2, bf.y + bf.h + 6
  elseif p == "bottom" then x, y = bf.x + r.x + r.w / 2 - tw / 2, bf.y - th - 6
  elseif p == "right" then x, y = bf.x - tw - 6, bf.y + r.y + r.h / 2 - th / 2
  else x, y = bf.x + bf.w + 6, bf.y + r.y + r.h / 2 - th / 2 end
  local sf = screen():fullFrame()
  x = math.max(sf.x + 4, math.min(x, sf.x + sf.w - tw - 4))
  if not T.batTip then
    T.batTip = hs.canvas.new({x = x, y = y, w = tw, h = th})
    T.batTip:level(hs.canvas.windowLevels.floating)
    T.batTip:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.batTip:clickActivating(false)
  end
  T.batTip:frame({x = x, y = y, w = tw, h = th})
  T.batTip:replaceElements({
    {type = "rectangle", action = "fill", fillColor = {hex = "#2C2F36", alpha = 0.98},
     roundedRectRadii = {xRadius = 7, yRadius = 7}, frame = {x = 0, y = 0, w = tw, h = th}},
    {type = "text", text = txt, textSize = 12.5, textColor = COL.text, textAlignment = "center",
     frame = {x = 0, y = th / 2 - 8, w = tw, h = 17}},
  })
  T.batTip:show()
end

-- Lo sfondo nero di Tabby, con gli angoli smussati dalla parte delle app (verso lo
-- schermo) e dritti contro il bordo dello schermo (idea di Daniele, 23/10/2026)
BAR_RADIUS = 12
function barBackground(bf)
  local w, h, R = bf.w, bf.h, BAR_RADIUS
  local els = {{type = "rectangle", action = "fill", fillColor = COL.bar,
                roundedRectRadii = {xRadius = R, yRadius = R}, frame = {x = 0, y = 0, w = w, h = h}}}
  -- metà verso il bordo dello schermo: angoli dritti
  local p, sq = S.position
  if p == "bottom" then sq = {x = 0, y = h / 2, w = w, h = h / 2}
  elseif p == "left" then sq = {x = 0, y = 0, w = w / 2, h = h}
  elseif p == "right" then sq = {x = w / 2, y = 0, w = w / 2, h = h}
  else sq = {x = 0, y = 0, w = w, h = h / 2} end
  table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.bar, frame = sq})
  return els
end

-- Il tasto ⚡︎ allargato quando ci sono Lampi coperti: il fulmine (clic = menu, come
-- sempre), le icone dei Lampi coperti (clic = davanti) e «Tutti»
function drawQuickWide(els, r)
  local list = T.coveredLamps
  local n = #list
  local cy = r.y + r.h / 2
  local tw = BTN_W + n * 26 + (n >= 2 and 44 or 0)
  local x0 = r.x + (r.w - tw) / 2
  table.insert(els, {type = "rectangle", action = "fill", fillColor = {hex = "#F2A541", alpha = 0.16},
    roundedRectRadii = {xRadius = 8, yRadius = 8}, frame = {x = x0 + 3, y = cy - 14, w = tw - 6, h = 28}})
  local g = {x = x0, y = r.y, w = BTN_W, h = r.h}
  table.insert(els, centeredGlyph("⚡︎", 16, g, {hex = "#F2A541"}))
  table.insert(els, hitArea("quick", g))
  for k, key in ipairs(list) do
    local ix = x0 + BTN_W - 4 + (k - 1) * 26
    local img = keyIcon(key)
    if img then table.insert(els, {type = "image", image = img, frame = {x = ix, y = cy - 10, w = 20, h = 20}}) end
    table.insert(els, hitArea("lampshelf:" .. key, {x = ix - 3, y = cy - 13, w = 26, h = 26}))
  end
  if n >= 2 then
    local ax = x0 + BTN_W - 4 + n * 26
    table.insert(els, {type = "text", text = "Tutti", textSize = 11.5, textColor = COL.text,
      textAlignment = "center", frame = {x = ax, y = cy - 8, w = 40, h = 16}})
    table.insert(els, hitArea("lampshelfall", {x = ax, y = cy - 13, w = 40, h = 26}))
  end
end

function centeredGlyph(text, size, r, color)
  return {type = "text", text = text, textSize = size, textColor = color or COL.textDim,
          textAlignment = "center",
          frame = {x = r.x, y = r.y + r.h / 2 - size * 0.65, w = r.w, h = size * 1.4}}
end

function activeBg(els, r, vertical)
  table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.active,
    roundedRectRadii = {xRadius = 7, yRadius = 7},
    frame = vertical and {x = r.x + 6, y = r.y + 2, w = r.w - 12, h = r.h - 4}
                      or {x = r.x + 2, y = r.y + 4, w = r.w - 4, h = r.h - 8}})
end

-- Mette Tabby dove deve stare. Sui Mac col notch macOS spinge giù le finestre
-- "normali" dalla fascia del notch: se succede, Tabby sale di livello
-- finché macOS la lascia stare in cima (e controlla di esserci riuscita).
LEVEL_STEPS = {"floating", "dock", "mainMenu", "status", "popUpMenu"}

function placeBar(bf)
  T.bar:frame(bf)
  local got = T.bar:frame()
  if math.abs(got.y - bf.y) < 1 then return end
  for _, name in ipairs(LEVEL_STEPS) do
    local v = hs.canvas.windowLevels[name]
    if v and v > (T.barLevel or 0) then
      T.bar:level(v)
      T.barLevel = v
      T.bar:frame(bf)
      got = T.bar:frame()
      if math.abs(got.y - bf.y) < 1 then
        print("Tabby · livello " .. name .. ": ora sta in cima")
        return
      end
    end
  end
  print("Tabby · macOS non lascia salire Tabby oltre y=" .. tostring(got.y))
end

draw = function()
  local bf = barFrame()
  if not T.bar then
    T.bar = hs.canvas.new(bf)
    -- sopra le finestre, ma sotto la barra dei menu di macOS quando scende
    T.barLevel = hs.canvas.windowLevels.floating
    T.bar:level(T.barLevel)
    -- visibile su tutte le scrivanie, anche sopra le app a schermo intero
    -- visibile su tutte le scrivanie (sopra le app a schermo intero si nasconde
    -- da sola: vedi updateFullscreen)
    T.bar:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.bar:clickActivating(false)
    T.bar:mouseCallback(onMouse)
  end
  placeBar(bf)

  local vertical  = isVertical()
  local activeIdx = activeIndex()
  -- la scheda attiva, le sue finestre e quella accanto (a sinistra, o a destra se
  -- è la prima): se chiudi o riduci la scheda attiva, in qualsiasi modo, si va lì
  snapActive(activeIdx)
  local L = layout(bf, activeIdx)
  T.bf, T.L = bf, L

  local els = barBackground(bf)
  for _, d in ipairs(L.dividers) do table.insert(els, divider(d)) end

  -- tasto scrivania: il gatto di Tabby (se manca l'immagine, uno schermo)
  local r = L.desk
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  if T.desktopMode then
    table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.active,
      roundedRectRadii = {xRadius = 7, yRadius = 7},
      frame = {x = r.x + 4, y = r.y + 4, w = r.w - 8, h = r.h - 8}})
  end
  local cat = T.desktopMode and T.catOn or T.catOff
  local full = catFullImage(T.desktopMode)
  if full then
    -- il gatto intero, il più grande possibile nello spazio in cima
    local sz = full:size()
    local maxW, maxH = r.w - 28, r.h - 16
    local k = math.min(maxW / sz.w, maxH / sz.h)
    local iw, ih = sz.w * k, sz.h * k
    table.insert(els, {type = "image", image = full, imageScaling = "scaleProportionally",
      frame = {x = cx - iw / 2, y = cy - ih / 2, w = iw, h = ih}})
  elseif cat then
    local sz = vertical and 26 or 24
    table.insert(els, {type = "image", image = cat, imageScaling = "scaleProportionally",
      frame = {x = cx - sz / 2, y = cy - sz / 2, w = sz, h = sz}})
  else
    local deskCol = T.desktopMode and COL.text or COL.textDim
    table.insert(els, {type = "rectangle", action = "stroke", strokeColor = deskCol,
      strokeWidth = 1.5, roundedRectRadii = {xRadius = 2, yRadius = 2},
      frame = {x = cx - 9, y = cy - 8, w = 18, h = 12}})
    table.insert(els, {type = "rectangle", action = "fill", fillColor = deskCol,
      frame = {x = cx - 5, y = cy + 6, w = 10, h = 1.5}})
  end
  table.insert(els, hitArea("desktop", r))

  -- vista cartella: "← Tutte le schede" e il nome della cartella
  if L.fhead then
    local vf = FD.folderById(T.viewFolder)
    local b, hd = L.fback, L.fhead
    if vertical then
      table.insert(els, {type = "text", text = "←  Tutte le schede", textSize = 11.5, textColor = COL.textMid,
        frame = {x = b.x + 14, y = b.y + b.h / 2 - 8, w = b.w - 20, h = 16}})
      table.insert(els, {type = "text", text = "▾", textSize = 12, textColor = COL.accent,
        frame = {x = hd.x + 14, y = hd.y + hd.h / 2 - 8, w = 14, h = 16}})
      table.insert(els, {type = "text", text = vf.name, textSize = 14, textColor = COL.text,
        textLineBreak = "truncateTail", frame = {x = hd.x + 30, y = hd.y + hd.h / 2 - 9, w = hd.w - 40, h = 19}})
    else
      table.insert(els, centeredGlyph("←", 15, b, COL.textMid))
      table.insert(els, {type = "text", text = "▾  " .. vf.name, textSize = 13.5, textColor = COL.text,
        textLineBreak = "truncateTail", frame = {x = hd.x + 4, y = hd.y + hd.h / 2 - 9, w = hd.w - 8, h = 19}})
    end
    table.insert(els, hitArea("fback", b))
    table.insert(els, hitArea("fhead", hd))
  end

  -- schede
  T.closePos = {}
  for _, tv in ipairs(L.tabs) do
    local i, tr  = tv.i, tv.r
    local t      = T.tabs[i]
    local my     = tr.y + tr.h / 2
    local active = (i == activeIdx)
    local g      = t.group
    local badge  = badgeFor(t)

    if tv.compact then
      -- scheda compatta: solo l'icona (per un gruppo, con il numero di schede)
      local img = t.folder and FD.itemIcon(t.folder.items[1])
               or keyIcon(g and (g.focus or g.members[1]) or t.key)
      local cx = tr.x + tr.w / 2
      if img then
        table.insert(els, {type = "image", image = img,
          frame = {x = cx - 10, y = my - 10, w = 20, h = 20}})
      end
      if badge then
        table.insert(els, {type = "circle", action = "fill", fillColor = COL.badge,
          center = {x = cx + 10, y = my - 9}, radius = 4.5})
      elseif g or t.folder then
        table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.accent,
          roundedRectRadii = {xRadius = 6, yRadius = 6},
          frame = {x = cx + 4, y = my - 14, w = 12, h = 12}})
        table.insert(els, {type = "text", text = tostring(g and #g.members or #t.folder.items), textSize = 8,
          textColor = COL.text, textAlignment = "center",
          frame = {x = cx + 4, y = my - 13, w = 12, h = 11}})
      end
      table.insert(els, hitArea("tab" .. i, tr, true))
      goto continue
    end

    do
      local closeW = 22
      local ix     = tr.x + (vertical and 14 or 10)
      local closeX = tr.x + tr.w - closeW - (vertical and 8 or 4)

      if active then
        activeBg(els, tr, vertical)
        table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.accent,
          roundedRectRadii = {xRadius = 1, yRadius = 1},
          frame = vertical and {x = tr.x + 6, y = tr.y + 9, w = 2, h = tr.h - 18}
                            or {x = tr.x + 12, y = tr.y + tr.h - 6, w = tr.w - 24, h = 2}})
      end

      -- icone: una per una scheda (logo del sito per le webapp),
      -- affiancate (max 4) per un gruppo
      local textX
      if t.folder then
        local items = t.folder.items
        local nIcons = math.min(#items, 3)
        for k = nIcons, 1, -1 do
          local img = FD.itemIcon(items[k])
          if img then
            table.insert(els, {type = "image", image = img,
              frame = {x = ix + (k - 1) * 11, y = my - 9, w = 18, h = 18}})
          end
        end
        textX = ix + 18 + (nIcons - 1) * 11 + 8
      elseif g then
        local nIcons = math.min(#g.members, 4)
        for k = 1, nIcons do
          local img = keyIcon(g.members[k])
          if img then
            table.insert(els, {type = "image", image = img,
              frame = {x = ix + (k - 1) * 12, y = my - 9, w = 18, h = 18}})
          end
        end
        textX = ix + 18 + (nIcons - 1) * 12 + 8
      else
        local img = keyIcon(t.key)
        if img then
          table.insert(els, {type = "image", image = img,
            frame = {x = ix, y = my - 10, w = 20, h = 20}})
        end
        textX = ix + 26
      end

      -- notifiche: pallino rosso col numero, prima della ✕
      local badgeW = 0
      if badge then
        local txt = badge
        local n = tonumber(badge)
        if n and n > 99 then txt = "99+" end
        badgeW = math.max(18, 8 + utf8.len(txt) * 6.5)
        local bx = closeX - badgeW - 2
        table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.badge,
          roundedRectRadii = {xRadius = 8, yRadius = 8},
          frame = {x = bx, y = my - 8, w = badgeW, h = 16}})
        table.insert(els, {type = "text", text = txt, textSize = 10,
          textColor = {white = 1}, textAlignment = "center",
          frame = {x = bx, y = my - 7, w = badgeW, h = 14}})
        badgeW = badgeW + 6
      end

      table.insert(els, {type = "text", text = t.name,
        textSize = 13, textLineBreak = "truncateTail",
        textColor = active and COL.text or COL.textMid,
        frame = {x = textX, y = my - 9, w = closeX - badgeW - textX - 2 - (g and 26 or 0), h = 18}})

      local btnR = {x = closeX - 2, y = my - 11, w = closeW + 4, h = 22}
      if t.folder then
        -- ⋯ : apri, esci dalla cartella, chiudi cartella, modifica
        table.insert(els, {type = "text", text = "⋯", textSize = 13,
          textColor = COL.textMid, textAlignment = "center",
          frame = {x = closeX, y = my - 9, w = closeW, h = 18}})
        T.closePos[i] = popPos(btnR)
        table.insert(els, hitArea("tab" .. i, tr, true))
        table.insert(els, hitArea("fmenu" .. i, btnR))
      elseif g then
        -- tasto "Scomponi": due riquadri separati
        table.insert(els, {type = "rectangle", action = "stroke", strokeColor = COL.textMid,
          strokeWidth = 1.2, roundedRectRadii = {xRadius = 1.5, yRadius = 1.5},
          frame = {x = closeX + 4, y = my - 6, w = 6, h = 12}})
        table.insert(els, {type = "rectangle", action = "stroke", strokeColor = COL.textMid,
          strokeWidth = 1.2, roundedRectRadii = {xRadius = 1.5, yRadius = 1.5},
          frame = {x = closeX + 13, y = my - 6, w = 6, h = 12}})
        -- tasto "Scambia" ⇄, a sinistra di Scomponi
        local rotR = {x = closeX - 26, y = my - 11, w = 24, h = 22}
        table.insert(els, {type = "text", text = "⇄", textSize = 12, textColor = COL.textMid,
          textAlignment = "center", frame = {x = rotR.x, y = my - 8, w = rotR.w, h = 16}})
        table.insert(els, hitArea("tab" .. i, tr, true))
        table.insert(els, hitArea("ungroup" .. i, btnR))
        table.insert(els, hitArea("rotate" .. i, rotR))
      else
        -- ✕ per chiudere
        table.insert(els, {type = "text", text = "✕", textSize = 10,
          textColor = COL.textDim, textAlignment = "center",
          frame = {x = closeX, y = my - 7, w = closeW, h = 14}})
        T.closePos[i] = popPos(btnR)
        table.insert(els, hitArea("tab" .. i, tr, true))
        table.insert(els, hitArea("close" .. i, btnR))
      end
    end
    ::continue::
  end

  -- dove cadrà la scheda che stai trascinando
  if T.dropMarker then
    table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.accent,
      roundedRectRadii = {xRadius = 1, yRadius = 1}, frame = T.dropMarker})
  end

  -- "+N": le schede che non ci stanno
  if L.more then
    local label = "+" .. #L.overflow
    if vertical then label = label .. " altre" end
    table.insert(els, {type = "text", text = label, textSize = 12, textColor = COL.textMid,
      textAlignment = "center",
      frame = {x = L.more.x, y = L.more.y + L.more.h / 2 - 8, w = L.more.w, h = 16}})
    table.insert(els, hitArea("more", L.more))
  end

  -- scheda "+": apre Spotlight per aprire un'altra app
  if L.plus then
    table.insert(els, centeredGlyph("+", 18, L.plus, COL.textDim))
    table.insert(els, hitArea("plus", L.plus))
  end

  -- batteria
  if L.battery then drawBattery(els, L.battery) end

  -- tasti ⊞ (dividi), ⚡︎ (app veloci) e ⚙︎ (impostazioni)
  if T.split then
    table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.active,
      roundedRectRadii = {xRadius = 7, yRadius = 7},
      frame = {x = L.split.x + 4, y = L.split.y + 4, w = L.split.w - 8, h = L.split.h - 8}})
  end
  table.insert(els, centeredGlyph("⊞", 18, L.split, T.split and COL.accent or nil))
  table.insert(els, hitArea("split", L.split))
  if L.quickWide then drawQuickWide(els, L.quick)
  else
    table.insert(els, centeredGlyph("⚡︎", 16, L.quick))
    table.insert(els, hitArea("quick", L.quick))
  end
  table.insert(els, centeredGlyph("⚙︎", 17, L.settings))
  table.insert(els, hitArea("settings", L.settings))

  T.bar:replaceElements(els)

  T.updateMouseTimer()
  local fsHint = T.fsHintUntil and hs.timer.secondsSinceEpoch() < T.fsHintUntil
  updateCollapse(fsHint)
  if T.fullscreen or fsHint or T.collapsed then setVisible(false)   -- a schermo intero (o col cerchio) la barra non c'è
  elseif T.edgeHidden or T.slideTimer then -- (fuori dallo schermo o mentre scivola)
  elseif S.autohide then setVisible(T.revealed) else setVisible(true) end
end


-- Per la diagnosi dal Terminale (hs -c): le funzioni del disegno
T.diag = {draw = draw, layout = layout, activeIndex = activeIndex, badgeFor = badgeFor,
          keyIcon = keyIcon, barFrame = barFrame, rebuildTabs = rebuildTabs}

-- ---------------------------------------------------------------------
--  "NASCONDI TABBY": APPARE PORTANDO IL MOUSE SUL BORDO DELLO SCHERMO
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
--  IL CERCHIO SULLA SCRIVANIA (24/10/2026, Daniele)
--  Quando non c'è nessuna finestra in vista (tutto nascosto, ridotto o chiuso,
--  o ⌃⌥0), la barra di Tabby si ritira in un cerchio nero col muso del gatto, in
--  basso a destra. Appena compare una finestra torna la barra.
--  Clic sul gatto (nel cerchio o nella barra): si torna all'ultima finestra che
--  stavi guardando; se non ce n'è nessuna, un menu: «+ Nuova app…» e le cartelle.
-- ---------------------------------------------------------------------
ORB_SIZE, ORB_MARGIN = 56, 22

-- C'è almeno una finestra in vista? (i Lampi, il Memo e Hammerspoon non contano)
function anyWindowShown()
  if T.desktopMode then return false end
  if not T.allWins then return true end
  for _, w in ipairs(T.allWins:getWindows()) do
    local a = w:application()
    local b = a and a:bundleID()
    if b and not IGNORE[b] and not floating(b) and not a:isHidden() and w:isStandard()
       and not w:isMinimized() and not w:isFullScreen() then
      return true
    end
  end
  return false
end

-- Si ritira solo se la scrivania resta vuota per un attimo (mentre passi da un'app
-- all'altra può esserci un istante senza finestre); torna barra subito
function updateCollapse(fsHint)
  local want = not T.fullscreen and not fsHint and not T.split and not T.fedit and not anyWindowShown()
  if want and not T.collapsed then
    if not T.collapseTimer then
      T.collapseTimer = hs.timer.doAfter(0.4, function()
        T.collapseTimer = nil
        if not T.fullscreen and not anyWindowShown() and not T.collapsed then
          T.collapsed = true
          print("Tabby · nessuna finestra in vista: Tabby diventa il cerchio")
          showOrb(true)
          draw()
        end
      end)
    end
  elseif not want then
    if T.collapseTimer then T.collapseTimer:stop(); T.collapseTimer = nil end
    if T.collapsed then
      T.collapsed = false
      showOrb(false)
    end
  end
end

function orbFrame()
  local f = screen():frame()
  return {x = f.x + f.w - ORB_SIZE - ORB_MARGIN, y = f.y + f.h - ORB_SIZE - ORB_MARGIN, w = ORB_SIZE, h = ORB_SIZE}
end

-- Il cerchio "Eclissi" (scelto da Daniele il 24/10/2026, prototipo D in
-- docs/prototipo-cerchio.html): nero, con una luce ambra sul bordo in alto a sinistra
-- che si accende passandoci sopra
ORB_PAD = 16   -- spazio intorno al cerchio per la luce
function drawOrb(hot)
  local s, p = ORB_SIZE, ORB_PAD
  local cx, cy, r = p + s / 2, p + s / 2, s / 2 - 1
  local els = {
    -- l'alone ambra dietro, spostato verso l'alto a sinistra
    {type = "circle", action = "fill", fillColor = {hex = "#F2A541", alpha = hot and 0.55 or 0.32},
     center = {x = cx - 3, y = cy - 3}, radius = r,
     withShadow = true, shadow = {blurRadius = hot and 18 or 11, color = {hex = "#F2A541", alpha = hot and 0.9 or 0.6}, offset = {h = 0, v = 0}}},
    -- il bordo acceso (una falce ambra) e il disco nero sopra
    {type = "circle", action = "fill", fillColor = {hex = "#F2A541", alpha = hot and 0.95 or 0.75},
     center = {x = cx - 1.2, y = cy - 1.2}, radius = r},
    {type = "circle", action = "fill", fillColor = {hex = "#000000"},
     center = {x = cx + 0.8, y = cy + 0.8}, radius = r - 0.6},
    {type = "circle", action = "stroke", strokeColor = {white = 1, alpha = 0.06}, strokeWidth = 1,
     center = {x = cx, y = cy}, radius = r},
  }
  local cat = T.catOn
  if cat then
    local c = hot and 33 or 30
    table.insert(els, {type = "image", image = cat, imageScaling = "scaleProportionally",
      frame = {x = cx - c / 2, y = cy - c / 2, w = c, h = c}})
  end
  table.insert(els, {type = "circle", action = "fill", fillColor = {white = 1, alpha = 0.01},
    trackMouseUp = true, trackMouseEnterExit = true, id = "orb", center = {x = cx, y = cy}, radius = s / 2})
  T.orb:replaceElements(els)
end

function orbCanvasFrame()
  local o = orbFrame()
  return {x = o.x - ORB_PAD, y = o.y - ORB_PAD, w = o.w + 2 * ORB_PAD, h = o.h + 2 * ORB_PAD}
end

function showOrb(on)
  if not on then
    closeFan()
    if T.orb then T.orb:hide(0.12) end
    return
  end
  if not T.orb then
    T.orb = hs.canvas.new(orbCanvasFrame())
    T.orb:level(hs.canvas.windowLevels.floating)
    T.orb:behavior({"canJoinAllSpaces", "stationary"})
    T.orb:clickActivating(false)
    T.orb:mouseCallback(function(_, msg, id)
      if tostring(id) ~= "orb" then return end
      if msg == "mouseEnter" then drawOrb(true)
      elseif msg == "mouseExit" then drawOrb(false)
      elseif msg == "mouseUp" then
        if T.fanOpen then closeFan() else catClick(true) end
      end
    end)
  end
  T.orb:frame(orbCanvasFrame())
  drawOrb(false)
  T.orb:show(0.15)
end

-- Clic sul muso del gatto: l'ultima finestra che stavi guardando (dal cerchio: quella
-- di prima di finire sulla scrivania; dalla barra: quella prima della scheda in cui sei,
-- come ⌃⌥Tab); se non c'è nessuna finestra a cui tornare, le scelte (dal cerchio: a
-- ventaglio intorno a lui; dalla barra: un menu accanto al gatto)
function catClick(fromOrb)
  local cur = (not fromOrb) and currentKey() or nil
  for _, k in ipairs(T.recent or {}) do
    if k ~= cur and (T.cand[k] or T.memberOf[k]) then
      print("Tabby · clic sul gatto: torno a «" .. tostring((T.cand[k] or {}).name or k) .. "»")
      if T.desktopMode then T.desktopMode = false end
      local g = T.memberOf[k]
      if g then showGroup(g) else focusKey(k) end
      return
    end
  end
  if fromOrb then openFan() else openCatMenu() end
end

-- Le scelte quando non c'è nessuna finestra: «+ Nuova app…» e le cartelle
function catChoices()
  local list = {{id = "new", name = "Nuova app", fn = function() openSpotlight() end}}
  for i, f in ipairs(S.folders) do
    table.insert(list, {id = "f" .. i, name = f.name, folder = f, fn = function() FD.activateFolder(f) end})
  end
  return list
end

function openCatMenu()
  local items = {{title = "+  Nuova app…", fn = openSpotlight}}
  if #S.folders > 0 then
    table.insert(items, {title = "-"})
    table.insert(items, {title = "Cartelle", disabled = true})
    for _, f in ipairs(S.folders) do
      table.insert(items, {title = f.name, image = FD.folderImage(f), fn = function() FD.activateFolder(f) end})
    end
  end
  popup(items, popPos(T.L.desk))
end

-- ---- Il ventaglio intorno al cerchio ----
FAN_PETAL, FAN_RINGS = 44, {{r = 92, n = 3}, {r = 150, n = 4}, {r = 208, n = 5}}

-- Dove va ogni scelta: giri intorno al cerchio, da sinistra verso l'alto (l'angolo è in
-- basso a destra), il primo giro vicino al cerchio
function fanSpots(count)
  local spots = {}
  for _, ring in ipairs(FAN_RINGS) do
    for k = 0, ring.n - 1 do
      local a = math.rad(180 - 90 * k / (ring.n - 1))   -- 180° = a sinistra, 90° = sopra
      table.insert(spots, {dx = math.cos(a) * ring.r, dy = -math.sin(a) * ring.r})
      if #spots >= count then return spots end
    end
  end
  return spots
end

FAN_W = 400   -- la tela del ventaglio (quadrata, nell'angolo in basso a destra)
function drawFan(progress, hover)
  local W = FAN_W
  local o = orbFrame()
  local ocx, ocy = W - (o.w / 2), W - (o.h / 2)   -- centro del cerchio dentro la tela
  local els, labelEls = {}, nil
  local choices = T.fanChoices or {}
  local spots = fanSpots(#choices)
  for i, ch in ipairs(choices) do
    local sp = spots[i]
    local x, y = ocx + sp.dx * progress, ocy + sp.dy * progress
    local hot = hover == ch.id
    local P = FAN_PETAL
    if ch.id == "new" then
      table.insert(els, {type = "circle", action = "fill", fillColor = {hex = "#F2A541"},
        center = {x = x, y = y}, radius = P / 2,
        withShadow = true, shadow = {blurRadius = 10, color = {white = 0, alpha = 0.5}, offset = {h = 0, v = -3}}})
      table.insert(els, {type = "text", text = "+", textSize = 24, textColor = {hex = "#1A1206"},
        textAlignment = "center", frame = {x = x - P / 2, y = y - 16, w = P, h = 30}})
    else
      table.insert(els, {type = "circle", action = "strokeAndFill", fillColor = {hex = "#0B0C10"},
        strokeColor = hot and {hex = "#F2A541"} or {white = 1, alpha = 0.16}, strokeWidth = 1,
        center = {x = x, y = y}, radius = P / 2,
        withShadow = true, shadow = {blurRadius = 10, color = {white = 0, alpha = 0.5}, offset = {h = 0, v = -3}}})
      local items = ch.folder and ch.folder.items or {}
      local n = math.min(#items, 2)
      for k = n, 1, -1 do
        local im = FD.itemIcon(items[k])
        if im then
          local ix = x - 8 - (n - 1) * 5 + (k - 1) * 10
          table.insert(els, {type = "image", image = im, frame = {x = ix, y = y - 8, w = 16, h = 16}})
        end
      end
    end
    table.insert(els, {type = "circle", action = "fill", fillColor = {white = 1, alpha = 0.01},
      trackMouseUp = true, trackMouseEnterExit = true, id = "fan:" .. ch.id, center = {x = x, y = y}, radius = P / 2})
    -- il nome, accanto alla scelta su cui sei
    if hot and progress >= 1 then
      local label = (ch.id == "new") and "Nuova app" or ch.name
      local lw = math.min(200, 24 + (utf8.len(label) or 8) * 7.2)
      -- a sinistra della bolla (lì non c'è niente); per quella più in alto, sopra
      -- a sinistra se lì non c'è un'altra bolla; altrimenti sopra
      local leftBusy = false
      for j, o in ipairs(spots) do
        if j ~= i and j <= #choices and math.abs(o.dy - sp.dy) < 30 and o.dx < sp.dx then leftBusy = true end
      end
      local lx, ly
      if sp.dx < -30 and not leftBusy then lx, ly = x - P / 2 - 8 - lw, y - 12
      else lx, ly = x - lw / 2, y - P / 2 - 32 end
      -- sempre dentro la tela (se no si taglia)
      lx = math.max(4, math.min(lx, W - lw - 4))
      ly = math.max(4, ly)
      labelEls = {
        {type = "rectangle", action = "fill", fillColor = {white = 0, alpha = 0.85},
         roundedRectRadii = {xRadius = 7, yRadius = 7}, frame = {x = lx, y = ly, w = lw, h = 24}},
        {type = "text", text = label, textSize = 12.5, textColor = COL.text, textAlignment = "center",
         frame = {x = lx, y = ly + 4, w = lw, h = 18}},
      }
    end
  end
  -- il nome si disegna per ultimo: sta sopra alle bolle
  for _, e in ipairs(labelEls or {}) do table.insert(els, e) end
  T.fan:replaceElements(els)
end

function openFan()
  local o = orbFrame()
  local W = FAN_W
  T.fanChoices = catChoices()
  if not T.fan then
    T.fan = hs.canvas.new({x = o.x + o.w - W, y = o.y + o.h - W, w = W, h = W})
    T.fan:level(hs.canvas.windowLevels.floating)
    T.fan:behavior({"canJoinAllSpaces", "stationary"})
    T.fan:clickActivating(false)
    T.fan:mouseCallback(function(_, msg, id)
      local cid = tostring(id):match("^fan:(.+)$")
      if not cid then return end
      if msg == "mouseEnter" then T.fanHover = cid; drawFan(1, cid)
      elseif msg == "mouseExit" then T.fanHover = nil; drawFan(1, nil)
      elseif msg == "mouseUp" then
        for _, ch in ipairs(T.fanChoices or {}) do
          if ch.id == cid then closeFan(); ch.fn(); return end
        end
      end
    end)
  end
  T.fan:frame({x = o.x + o.w - W, y = o.y + o.h - W, w = W, h = W})
  T.fanOpen = true
  print("Tabby · nessuna finestra: le scelte a ventaglio intorno al cerchio")
  -- si apre a ventaglio, in pochi passi
  if T.fanTimer then T.fanTimer:stop() end
  local step = 0
  drawFan(0.2, nil)
  T.fan:show()
  if T.orb then T.orb:orderAbove(T.fan) end
  T.fanTimer = hs.timer.doEvery(0.02, function()
    step = step + 1
    drawFan(math.min(1, 0.2 + step * 0.16), nil)
    if step >= 5 and T.fanTimer then T.fanTimer:stop(); T.fanTimer = nil end
  end)
  -- un clic fuori dal ventaglio lo chiude
  if not T.fanTap then
    T.fanTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(e)
      if not T.fanOpen then return false end
      local p = e:location()
      local f = T.fan:frame()
      local inside = p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h
      if not inside then later(closeFan) end
      return false
    end)
  end
  T.fanTap:start()
end

function closeFan()
  if not T.fanOpen then return end
  T.fanOpen = false
  T.fanHover = nil
  if T.fanTimer then T.fanTimer:stop(); T.fanTimer = nil end
  if T.fan then T.fan:hide(0.1) end
  if T.fanTap then T.fanTap:stop() end
end

-- Tabby scivola fuori dallo schermo dal suo lato (out = true) o rientra
function slideBar(out)
  if not T.bar then return end
  if T.slideTimer then T.slideTimer:stop(); T.slideTimer = nil end
  local bf = barFrame()
  local function at(frac)   -- 0 = al suo posto, 1 = fuori dallo schermo
    local f, p = {x = bf.x, y = bf.y, w = bf.w, h = bf.h}, S.position
    if p == "top" then f.y = bf.y - (bf.h + 4) * frac
    elseif p == "bottom" then f.y = bf.y + (bf.h + 4) * frac
    elseif p == "left" then f.x = bf.x - (bf.w + 4) * frac
    else f.x = bf.x + (bf.w + 4) * frac end
    return f
  end
  print("Tabby · " .. (out and ("esce dallo schermo (" .. tostring(T.edgeHidden) .. ")") or "rientra"))
  if not out then T.bar:frame(at(1)); T.bar:show(); T.visible = true end
  local steps, k = 6, 0
  T.slideTimer = hs.timer.doEvery(0.022, function()
    k = k + 1
    T.bar:frame(at(out and k / steps or 1 - k / steps))
    if k >= steps then
      if T.slideTimer then T.slideTimer:stop() end
      T.slideTimer = nil
      if out then T.bar:hide(); T.visible = false; T.bar:frame(bf) else draw() end
    end
  end)
end

-- Il controllo del mouse (12 volte al secondo) serve solo con "Nascondi Tabby" o
-- con la barra dei menu / il Dock che si nascondono dallo stesso lato di Tabby:
-- altrimenti è spento (consumo, 23/10/2026)
function T.updateMouseTimer()
  if not T.mouseTimer then return end
  local need = S.autohide or edgeWatch() ~= nil
  if need and not T.mouseTimer:running() then
    T.mouseTimer:start()
  elseif not need and T.mouseTimer:running() then
    T.mouseTimer:stop()
  end
  if not need and T.edgeHidden then T.edgeHidden = nil; slideBar(false) end
end

T.mouseTimer = hs.timer.doEvery(0.08, function()
  if not T.bar then return end
  if T.press or T.split or T.fedit then return end   -- mentre trascini, dividi o crei una cartella, resta visibile

  -- Barra dei menu o Dock che si nascondono da soli: quando arrivano dalla parte di
  -- Tabby (il puntatore tocca quel bordo dello schermo) Tabby esce dallo schermo; quando
  -- se ne vanno (il puntatore si allontana dal bordo) rientra.
  local ew = (not T.fullscreen) and edgeWatch() or nil
  if ew then
    local ff = screen():fullFrame()
    local p  = hs.mouse.absolutePosition()
    local d  = T.dockPrefs or {}
    if not T.edgeHidden then
      local hit
      if ew.menu and p.y <= ff.y + 1 then hit = "barra dei menu" end
      if ew.dock and ((d.side == "bottom" and p.y >= ff.y + ff.h - 2)
                   or (d.side == "left" and p.x <= ff.x + 1)
                   or (d.side == "right" and p.x >= ff.x + ff.w - 2)) then hit = "Dock" end
      if hit then T.edgeHidden = hit; slideBar(true) end
    else
      local away
      if T.edgeHidden == "barra dei menu" then
        away = p.y > ff.y + realMenuH() + 10
      else
        local dist = (d.side == "bottom" and (ff.y + ff.h - p.y)) or (d.side == "left" and (p.x - ff.x)) or (ff.x + ff.w - p.x)
        away = dist > (d.size or 68) + 10
      end
      if away then T.edgeHidden = nil; slideBar(false) end
    end
    return
  elseif T.edgeHidden then
    T.edgeHidden = nil
    slideBar(false)
  end

  if not S.autohide or T.fullscreen then return end
  local R  = baseRect()
  local p  = hs.mouse.absolutePosition()
  local bf = barFrame()
  local pos = S.position

  if not T.revealed then
    local inX = p.x >= R.x and p.x <= R.x + R.w
    local inY = p.y >= R.y and p.y <= R.y + R.h
    local hit
    if pos == "bottom" then hit = inX and p.y >= R.y + R.h - 2
    elseif pos == "left" then hit = inY and p.x <= R.x + 2
    elseif pos == "right" then hit = inY and p.x >= R.x + R.w - 2
    else hit = inX and p.y <= R.y + 2 end
    if hit then
      T.revealed = true
      draw()
    end
  else
    local m = 12
    local inside = p.x >= bf.x - m and p.x <= bf.x + bf.w + m
               and p.y >= bf.y - m and p.y <= bf.y + bf.h + m
    -- in alto: anche la barra dei menu sopra Tabby conta come "dentro"
    if pos == "top" and p.y < bf.y and p.x >= bf.x and p.x <= bf.x + bf.w then
      inside = true
    end
    if not inside then
      T.revealed = false
      setVisible(false)
    end
  end
end)
