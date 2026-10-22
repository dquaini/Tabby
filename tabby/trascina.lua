-- =====================================================================
--  Tabby · trascina.lua: trascinare le schede (riordino, zone della vista divisa, riquadro delle cartelle).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  TRASCINARE LE SCHEDE
--  Fuori dalla divisione: riordina le schede.
--  Durante la divisione: porta l'app nella zona dove la lasci.
-- ---------------------------------------------------------------------

function ghostStart(t, p)
  if not T.ghost then
    T.ghost = hs.canvas.new({x = 0, y = 0, w = 190, h = 34})
    T.ghost:level(hs.canvas.windowLevels.dragging)
    T.ghost:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
  end
  local img = keyIcon(t.group and t.group.members[1] or t.key)
  local els = {
    {type = "rectangle", action = "strokeAndFill", fillColor = {hex = "#2C2F36", alpha = 0.96},
     strokeColor = COL.accent, strokeWidth = 1, roundedRectRadii = {xRadius = 8, yRadius = 8},
     frame = {x = 0.5, y = 0.5, w = 189, h = 33}},
  }
  if img then table.insert(els, {type = "image", image = img, frame = {x = 8, y = 7, w = 20, h = 20}}) end
  table.insert(els, {type = "text", text = t.name, textSize = 13, textColor = COL.text,
    textLineBreak = "truncateTail", frame = {x = 34, y = 8, w = 148, h = 18}})
  T.ghost:replaceElements(els)
  T.ghost:topLeft({x = p.x + 12, y = p.y + 12})
  T.ghost:show()
end

-- Dove cadrebbe la scheda se la lasciassi qui (nil = fuori da Tabby)
function dropSlot(p)
  local bf, L = T.bf, T.L
  if not bf or not L or #L.tabs == 0 then return nil end
  local m = 24
  if p.x < bf.x - m or p.x > bf.x + bf.w + m or p.y < bf.y - m or p.y > bf.y + bf.h + m then
    return nil
  end
  local vertical = isVertical()
  local c = vertical and (p.y - bf.y) or (p.x - bf.x)
  for k, tv in ipairs(L.tabs) do
    local r = tv.r
    local mid = vertical and (r.y + r.h / 2) or (r.x + r.w / 2)
    if c < mid then
      return k, vertical and {x = r.x + 6, y = r.y - 1, w = r.w - 12, h = 2}
                          or {x = r.x - 1, y = r.y + 6, w = 2, h = r.h - 12}
    end
  end
  local r = L.tabs[#L.tabs].r
  return #L.tabs + 1, vertical and {x = r.x + 6, y = r.y + r.h - 1, w = r.w - 12, h = 2}
                                or {x = r.x + r.w - 1, y = r.y + 6, w = 2, h = r.h - 12}
end

function reorderTab(i, pos)
  local L, dragged = T.L, T.tabs[i]
  if not dragged then return end
  local target = L.tabs[pos] and T.tabs[L.tabs[pos].i]
  if target and target.key == dragged.key then draw(); return end

  local keys = {}
  for _, t in ipairs(T.tabs) do
    if t.key ~= dragged.key then table.insert(keys, t.key) end
  end
  local at = #keys + 1
  if target then
    for k, key in ipairs(keys) do if key == target.key then at = k; break end end
  else
    -- dopo l'ultima scheda visibile
    for n = #L.tabs, 1, -1 do
      local lastKey = T.tabs[L.tabs[n].i].key
      if lastKey ~= dragged.key then
        for k, key in ipairs(keys) do if key == lastKey then at = k + 1; break end end
        break
      end
    end
  end
  table.insert(keys, at, dragged.key)

  local seen = {}
  for _, k in ipairs(keys) do seen[k] = true end
  for _, k in ipairs(S.order) do
    if not seen[k] then table.insert(keys, k); seen[k] = true end
  end
  S.order = keys
  save("order")
  rebuildTabs()
  draw()
end

function startPress(i)
  local p = hs.mouse.absolutePosition()
  T.press = {i = i, x = p.x, y = p.y, dragging = false}
  T.dragTap:start()
end

function onDragMove(p)
  local pr = T.press
  if not pr then return end
  local t = T.tabs[pr.i]
  if not t then return end
  if not pr.dragging then
    if math.abs(p.x - pr.x) + math.abs(p.y - pr.y) < 8 then return end
    pr.dragging = true
    T.suppressClick = true
    ghostStart(t, p)
  end
  T.ghost:topLeft({x = p.x + 12, y = p.y + 12})

  if T.split then
    local k = zoneAt(p)
    if k ~= T.split.hover then T.split.hover = k; drawSplit() end
  elseif T.fedit then
    -- creazione di una cartella: illumina il riquadro quando ci sei sopra
    local z = T.fZoneAbs
    local hot = z ~= nil and p.x >= z.x and p.x <= z.x + z.w and p.y >= z.y and p.y <= z.y + z.h
    if hot ~= T.fedit.hover then T.fedit.hover = hot; FD.drawFolderEdit() end
  else
    local _, marker = dropSlot(p)
    local mk = marker and (marker.x .. ":" .. marker.y) or nil
    if mk ~= T.dropKey then
      T.dropKey, T.dropMarker = mk, marker
      draw()
    end
  end
end

function onDragEnd(p)
  T.dragTap:stop()
  local pr = T.press
  T.press = nil
  if T.ghost then T.ghost:hide() end
  if pr and pr.dragging then
    if T.split then
      local k = zoneAt(p)
      T.split.hover = nil
      if k then assignToZone(k, pr.i) else drawSplit() end
    elseif T.fedit then
      if T.fedit.hover then FD.feditAdd(T.tabs[pr.i]) else FD.drawFolderEdit() end
    else
      local pos = dropSlot(p)
      T.dropKey, T.dropMarker = nil, nil
      if pos then reorderTab(pr.i, pos) else draw() end
    end
  end
  hs.timer.doAfter(0.25, function() T.suppressClick = false end)
end

ET = hs.eventtap.event.types
T.dragTap = hs.eventtap.new({ET.leftMouseDragged, ET.leftMouseUp}, function(e)
  local p = hs.mouse.absolutePosition()
  if e:getType() == ET.leftMouseUp then
    later(function() onDragEnd(p) end)
  else
    onDragMove(p)
  end
  return false
end)
