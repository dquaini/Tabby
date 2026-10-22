-- =====================================================================
--  Tabby · notifiche.lua: i numerini rossi delle notifiche (dal Dock e dai titoli delle webapp).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  NOTIFICHE: i numerini rossi che le app mostrano sul Dock
-- ---------------------------------------------------------------------

function readDockBadges()
  local out = {}
  pcall(function()
    local dock = appFor("com.apple.dock")
    if not dock then return end
    local ax = hs.axuielement.applicationElement(dock)
    for _, list in ipairs(ax:attributeValue("AXChildren") or {}) do
      for _, item in ipairs(list:attributeValue("AXChildren") or {}) do
        local label = item:attributeValue("AXStatusLabel")
        if label and label ~= "" then
          local bid
          local url = item:attributeValue("AXURL")
          local path = type(url) == "table" and url.url or url
          if type(path) == "string" then
            path = path:gsub("^file://", ""):gsub("%%(%x%x)", function(h)
              return string.char(tonumber(h, 16))
            end):gsub("/$", "")
            T.pathBid = T.pathBid or {}
            if T.pathBid[path] == nil then
              local info = hs.application.infoForBundlePath(path)
              T.pathBid[path] = info and info.CFBundleIdentifier or false
            end
            bid = T.pathBid[path] or nil
          end
          if not bid then
            local a = hs.application.get(item:attributeValue("AXTitle") or "")
            bid = a and a:bundleID()
          end
          if bid then out[bid] = label end
        end
      end
    end
  end)
  return out
end

function badgeOfKey(key)
  local e = T.cand[key]
  if not e then return nil end
  if e.site then return e.titleBadge end
  if e.primary then return T.badges[e.bid] end
  return nil
end

-- Notifica da mostrare su una scheda (per un gruppo: la somma)
-- (badgeFor: definita più sotto o in un altro file)
badgeFor = function(t)
  if t.folder then
    -- scheda-cartella: la somma delle sue schede
    local sum, dot = 0, false
    for _, x in ipairs(T.allTabs) do
      if T.tabFolder[x.key] == t.folder then
        local b = badgeFor(x)
        local n = tonumber(b)
        if n then sum = sum + n elseif b then dot = true end
      end
    end
    if sum > 0 then return tostring(sum) end
    return dot and "•" or nil
  end
  if t.group then
    local sum, dot = 0, false
    for _, k in ipairs(t.group.members) do
      local b = badgeOfKey(k)
      if b then
        local n = tonumber(b)
        if n then sum = sum + n else dot = true end
      end
    end
    if sum > 0 then return tostring(sum) end
    return dot and "•" or nil
  end
  return badgeOfKey(t.key)
end
