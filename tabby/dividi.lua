-- =====================================================================
--  Tabby · dividi.lua: la vista divisa (nel codice: gruppi): creare, scomporre, scambiare, dividere lo schermo.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  GRUPPI: CREARE E SCOMPORRE
-- ---------------------------------------------------------------------

-- zones = {[numero zona] = chiave della scheda}, nz = quante zone ha lo schema
function createGroup(layoutId, zones, nz)
  local members = {}
  for k = 1, nz do if zones[k] then table.insert(members, zones[k]) end end
  if #members == 0 then return end
  for _, key in ipairs(members) do removeFromGroups(key) end
  if #members == 1 then
    saveGroups(); rebuildTabs(); focusKey(members[1])
    return
  end
  local lay = layoutId
  if #members < nz then lay = LAYOUT_FOR_COUNT[#members] end
  S.groupSeq = (S.groupSeq or 0) + 1
  local g = {id = S.groupSeq, layout = lay, members = members, focus = members[1]}
  table.insert(S.groups, g)
  -- la scheda del gruppo prende il posto della prima scheda
  local pos = orderIndex(members[1]) or (#S.order + 1)
  table.insert(S.order, pos, "g:" .. g.id)
  saveGroups()
  rebuildTabs()
  showGroup(g)
end

-- "Scambia" (tasto ⇄ e ⌃⌥S): le app della vista divisa ruotano di una zona
-- (con due app si scambiano); ripremendo continuano a ruotare
function rotateGroup(g)
  if not g or #g.members < 2 then return end
  table.insert(g.members, 1, table.remove(g.members))
  saveGroups()
  rebuildTabs()
  layoutGroup(g)
  draw()
end

-- La vista divisa che stai guardando (nil se nessuna)
function currentGroup()
  local key = currentKey()
  return key and T.memberOf[key] or nil
end

-- "Scomponi": le schede tornano singole, ognuna a tutto spazio
function ungroup(g)
  local focus = g.focus or g.members[1]
  dissolveGroup(g)
  saveGroups()
  rebuildTabs()
  focusKey(focus)
end

-- ---------------------------------------------------------------------
--  DIVIDI LO SCHERMO (tasto ⊞)
--  Si sceglie lo schema, compaiono le zone, si trascinano le schede
--  di Tabby dentro le zone. Zone tutte piene (o Invio / "Fatto") →
--  nasce il gruppo. Esc / "Annulla" → non succede niente.
-- ---------------------------------------------------------------------

-- (exitSplit, finishSplit, drawSplit: definita più sotto o in un altro file)

function zoneCount(sp) return #LAYOUTS[sp.layout].zones end

function zoneAt(p)
  local sp = T.split
  if not sp then return nil end
  for k = 1, zoneCount(sp) do
    local r = zoneRect(sp.layout, k)
    if p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h then return k end
  end
  return nil
end

function onOverlayMouse(_, msg, id)
  if msg ~= "mouseUp" then return end
  id = tostring(id)
  if id == "cancel" then exitSplit(); return end
  if id == "done" then finishSplit(); return end
  local k = tonumber(id:match("^zone(%d+)$"))
  if k and T.split and T.split.zones[k] then
    T.split.zones[k] = nil   -- clic su una zona piena = svuotala
    drawSplit()
  end
end

function button(els, r, label, fill, id)
  table.insert(els, {type = "rectangle", action = "fill", fillColor = fill,
    roundedRectRadii = {xRadius = 8, yRadius = 8}, frame = r})
  table.insert(els, {type = "text", text = label, textSize = 13, textColor = COL.text,
    textAlignment = "center", frame = {x = r.x, y = r.y + r.h / 2 - 9, w = r.w, h = 18}})
  table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
    trackMouseUp = true, id = id, frame = r})
end

drawSplit = function()
  local sp = T.split
  if not sp then return end
  local A = appArea()
  if not T.overlay then
    T.overlay = hs.canvas.new(A)
    T.overlay:level(hs.canvas.windowLevels.floating)
    T.overlay:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.overlay:clickActivating(false)
    T.overlay:mouseCallback(onOverlayMouse)
  else
    T.overlay:frame(A)
  end

  local els = {
    {type = "rectangle", action = "fill", fillColor = {white = 0, alpha = 0.5},
     frame = {x = 0, y = 0, w = A.w, h = A.h}},
  }

  for k = 1, zoneCount(sp) do
    local zr  = zoneRect(sp.layout, k)
    local r   = {x = zr.x - A.x + 4, y = zr.y - A.y + 4, w = zr.w - 8, h = zr.h - 8}
    local hot = (sp.hover == k)
    local bid = sp.zones[k]
    local box = {type = "rectangle", action = "strokeAndFill",
      fillColor   = hot and {hex = "#4C8DFF", alpha = 0.22} or {white = 1, alpha = 0.06},
      strokeColor = hot and COL.accent or {white = 1, alpha = 0.4},
      strokeWidth = 2, roundedRectRadii = {xRadius = 14, yRadius = 14}, frame = r}
    if not bid then box.strokeDashPattern = {10, 6} end
    table.insert(els, box)

    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    if bid then
      local img = keyIcon(bid)
      if img then
        table.insert(els, {type = "image", image = img,
          frame = {x = cx - 32, y = cy - 52, w = 64, h = 64}})
      end
      local e = T.cand[bid]
      table.insert(els, {type = "text", text = e and e.name or appName(bid, appFor(bid)),
        textSize = 16, textColor = COL.text, textAlignment = "center",
        frame = {x = r.x, y = cy + 18, w = r.w, h = 22}})
      table.insert(els, {type = "text", text = "clic per svuotare",
        textSize = 11, textColor = COL.textDim, textAlignment = "center",
        frame = {x = r.x, y = cy + 42, w = r.w, h = 16}})
    else
      table.insert(els, {type = "text", text = "Trascina qui un'app",
        textSize = 17, textColor = {white = 1, alpha = 0.8}, textAlignment = "center",
        frame = {x = r.x, y = cy - 12, w = r.w, h = 24}})
    end
    table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
      trackMouseUp = true, id = "zone" .. k, frame = r})
  end

  -- istruzioni e tasti, in basso al centro
  local pw, ph = 600, 52
  local px, py = (A.w - pw) / 2, A.h - ph - 28
  table.insert(els, {type = "rectangle", action = "strokeAndFill",
    fillColor = {hex = "#15171B", alpha = 0.97}, strokeColor = COL.divider, strokeWidth = 1,
    roundedRectRadii = {xRadius = 12, yRadius = 12}, frame = {x = px, y = py, w = pw, h = ph}})
  table.insert(els, {type = "text", text = "Trascina le schede di Tabby nelle zone",
    textSize = 14, textColor = COL.text, frame = {x = px + 20, y = py + 16, w = 340, h = 20}})
  button(els, {x = px + pw - 228, y = py + 9, w = 104, h = 34}, "Annulla  esc", COL.active, "cancel")
  button(els, {x = px + pw - 116, y = py + 9, w = 104, h = 34}, "Fatto  ↩", COL.accent, "done")

  T.overlay:replaceElements(els)
  T.overlay:show()
  if T.bar then T.bar:orderAbove(T.overlay) end
end

function enterSplit(layoutId)
  local sp = {layout = layoutId, zones = {}}
  local nz = zoneCount(sp)
  -- parti da quello che stai guardando: l'app attiva (o il gruppo attivo)
  local ai = activeIndex()
  local t = ai and T.tabs[ai]
  if t and t.group then
    for k, b in ipairs(t.group.members) do if k <= nz then sp.zones[k] = b end end
  elseif t then
    sp.zones[1] = t.key
  end
  T.split = sp
  T.revealed = true
  draw()
  drawSplit()
end

exitSplit = function()
  T.split = nil
  if T.overlay then T.overlay:hide() end
  draw()
end

finishSplit = function()
  local sp = T.split
  if not sp then return end
  exitSplit()
  createGroup(sp.layout, sp.zones, zoneCount(sp))
end

function assignToZone(k, i)
  local sp, t = T.split, T.tabs[i]
  if not sp or not t or t.group then return end
  for kk, b in pairs(sp.zones) do
    if b == t.key then sp.zones[kk] = nil end
  end
  sp.zones[k] = t.key
  sp.hover = nil
  drawSplit()
  -- tutte le zone piene: fatto, senza bisogno di altri clic
  for kk = 1, zoneCount(sp) do
    if not sp.zones[kk] then return end
  end
  hs.timer.doAfter(0.35, function() if T.split == sp then finishSplit() end end)
end

-- Clic (senza trascinare) su una scheda durante la divisione:
-- va nella prima zona libera. Comodo col trackpad.
function assignFirstEmpty(i)
  local sp = T.split
  if not sp then return end
  for k = 1, zoneCount(sp) do
    if not sp.zones[k] then assignToZone(k, i); return end
  end
end

-- Piccola anteprima dello schema, per il menu
function layoutImage(id)
  T.layoutImgs = T.layoutImgs or {}
  if T.layoutImgs[id] == nil then
    local ok, img = pcall(function()
      local W, H = 30, 20
      local c = hs.canvas.new({x = 0, y = 0, w = W, h = H})
      local els = {}
      for _, z in ipairs(LAYOUTS[id].zones) do
        table.insert(els, {type = "rectangle", action = "fill",
          fillColor = {white = 0.85, alpha = 0.95},
          roundedRectRadii = {xRadius = 1.5, yRadius = 1.5},
          frame = {x = z[1] * W + 1, y = z[2] * H + 1, w = z[3] * W - 2, h = z[4] * H - 2}})
      end
      c:replaceElements(els)
      local im = c:imageFromCanvas()
      c:delete()
      return im
    end)
    T.layoutImgs[id] = (ok and img) or false
  end
  return T.layoutImgs[id] or nil
end
