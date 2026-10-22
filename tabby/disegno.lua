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
  local ti = tonumber(id:match("^tab(%d+)$"))
  if msg == "mouseDown" then
    if ti then startPress(ti) end
    return
  end
  if msg ~= "mouseUp" then return end
  if T.suppressClick then T.suppressClick = false; return end   -- era un trascinamento

  if id == "settings" then openSettings(); return end
  if id == "quick" then openQuick(); return end
  if id == "split" then openSplitMenu(); return end
  if id == "more" then openOverflow(); return end
  if id == "desktop" then toggleDesktop(); return end
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
    L.desk     = {x = 0, y = 0, w = w, h = BTN_W}
    L.split    = {x = 0, y = bottomY, w = third, h = BTN_W}
    L.quick    = {x = third, y = bottomY, w = third, h = BTN_W}
    L.settings = {x = third * 2, y = bottomY, w = third, h = BTN_W}
    if bat then L.battery = {x = 0, y = bottomY - batH, w = w, h = batH} end
    table.insert(L.dividers, {x = 8, y = BTN_W, w = w - 16, h = 1})
    table.insert(L.dividers, {x = 8, y = bottomY - batH, w = w - 16, h = 1})
    table.insert(L.dividers, {x = 8, y = bottomY, w = w - 16, h = 1})
    table.insert(L.dividers, {x = third, y = bottomY + 8, w = 1, h = BTN_W - 16})
    table.insert(L.dividers, {x = third * 2, y = bottomY + 8, w = 1, h = BTN_W - 16})

    local start  = BTN_W + 6
    -- vista cartella: in cima "← Tutte le schede" e il nome della cartella
    if T.viewFolder and FD.folderById(T.viewFolder) then
      L.fback = {x = 0, y = BTN_W + 2, w = w, h = 26}
      L.fhead = {x = 0, y = BTN_W + 28, w = w, h = 30}
      table.insert(L.dividers, {x = 8, y = BTN_W + 60, w = w - 16, h = 1})
      start = BTN_W + 66
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
    local rightW = BTN_W * 3 + batW
    L.desk     = {x = 0, y = 0, w = BTN_W, h = h}
    L.split    = {x = w - BTN_W * 3, y = 0, w = BTN_W, h = h}
    L.quick    = {x = w - BTN_W * 2, y = 0, w = BTN_W, h = h}
    L.settings = {x = w - BTN_W, y = 0, w = BTN_W, h = h}
    if bat then L.battery = {x = w - rightW, y = 0, w = batW, h = h} end
    table.insert(L.dividers, {x = BTN_W, y = 8, w = 1, h = h - 16})
    if bat then table.insert(L.dividers, {x = w - rightW, y = 8, w = 1, h = h - 16}) end
    table.insert(L.dividers, {x = w - BTN_W * 3, y = 8, w = 1, h = h - 16})
    table.insert(L.dividers, {x = w - BTN_W * 2, y = 8, w = 1, h = h - 16})
    table.insert(L.dividers, {x = w - BTN_W, y = 8, w = 1, h = h - 16})

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

  local groupW = 26 + 4 + 34
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
  table.insert(els, {type = "text", text = pct .. "%", textSize = 11,
    textColor = col, frame = {x = bx + 30, y = by - 1, w = 34, h = 14}})
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
    T.bar:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.bar:clickActivating(false)
    T.bar:mouseCallback(onMouse)
  end
  placeBar(bf)

  local vertical  = isVertical()
  local activeIdx = activeIndex()
  local L = layout(bf, activeIdx)
  T.bf, T.L = bf, L

  local els = {
    {type = "rectangle", action = "fill", fillColor = COL.bar,
     frame = {x = 0, y = 0, w = bf.w, h = bf.h}},
  }
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
  if cat then
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
  table.insert(els, centeredGlyph("⚡︎", 16, L.quick))
  table.insert(els, hitArea("quick", L.quick))
  table.insert(els, centeredGlyph("⚙︎", 17, L.settings))
  table.insert(els, hitArea("settings", L.settings))

  T.bar:replaceElements(els)

  if S.autohide then setVisible(T.revealed) else setVisible(not T.menuPeek) end
end


-- Per la diagnosi dal Terminale (hs -c): le funzioni del disegno
T.diag = {draw = draw, layout = layout, activeIndex = activeIndex, badgeFor = badgeFor,
          keyIcon = keyIcon, barFrame = barFrame, rebuildTabs = rebuildTabs}

-- ---------------------------------------------------------------------
--  "NASCONDI TABBY": APPARE PORTANDO IL MOUSE SUL BORDO DELLO SCHERMO
-- ---------------------------------------------------------------------

T.mouseTimer = hs.timer.doEvery(0.08, function()
  if not T.bar then return end
  if T.press or T.split or T.fedit then return end   -- mentre trascini, dividi o crei una cartella, resta visibile

  -- Tabby nella fascia del notch: quando porti il mouse in cima scende la
  -- barra dei menu di macOS, e Tabby si fa da parte per non coprirla.
  if not S.autohide and useNotchBand() and not T.fullscreen then
    local ff = screen():fullFrame()
    local p  = hs.mouse.absolutePosition()
    if not T.menuPeek and p.y <= ff.y + 1 then
      T.menuPeek = true
      setVisible(false)
    elseif T.menuPeek and p.y > ff.y + BAR_H + 8 then
      T.menuPeek = false
      setVisible(true)
    end
    return
  elseif T.menuPeek then
    T.menuPeek = false
    setVisible(true)
  end

  if not S.autohide then return end
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
