-- =====================================================================
--  Tabby · schede.lua: l'ordine delle schede, cosa contiene una cartella, la ricostruzione delle schede.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  ORDINE DELLE SCHEDE E GRUPPI
--  Ogni scheda ha una "chiave": bundle ID (app, o prima finestra normale
--  di un browser), "site:<dominio>" (webapp), "win:<id finestra>" (altre
--  finestre di un browser), "g:<numero>" (gruppo = vista divisa).
--  S.order è l'ordine delle chiavi.
-- ---------------------------------------------------------------------

function orderIndex(key)
  for i, k in ipairs(S.order) do if k == key then return i end end
  return nil
end

function orderRemove(key)
  local i = orderIndex(key)
  if i then table.remove(S.order, i) end
end

function saveGroups()
  save("groups"); save("order"); save("groupSeq")
end

function groupIndex(g)
  for i, x in ipairs(S.groups) do if x == g then return i end end
  return nil
end

-- Scioglie un gruppo: le sue app tornano schede singole, al suo posto
function dissolveGroup(g)
  local gi = groupIndex(g)
  if gi then table.remove(S.groups, gi) end
  for _, b in ipairs(g.members) do orderRemove(b) end
  local key = "g:" .. g.id
  local pos = orderIndex(key)
  if pos then table.remove(S.order, pos) else pos = #S.order + 1 end
  for k, b in ipairs(g.members) do table.insert(S.order, pos + k - 1, b) end
end

-- Dopo che un gruppo ha perso app: sotto le 2 si scioglie,
-- altrimenti passa allo schema adatto al numero di app rimaste
function normalizeGroup(g)
  if #g.members < 2 then dissolveGroup(g); return end
  if #LAYOUTS[g.layout].zones ~= #g.members then
    g.layout = LAYOUT_FOR_COUNT[#g.members]
  end
end

function removeFromGroups(bid)
  local snapshot = {}
  for _, g in ipairs(S.groups) do table.insert(snapshot, g) end
  for _, g in ipairs(snapshot) do
    for k, b in ipairs(g.members) do
      if b == bid then
        table.remove(g.members, k)
        if g.focus == bid then g.focus = g.members[1] end
        normalizeGroup(g)
        break
      end
    end
  end
end

-- Tutte le funzioni delle cartelle stanno nella tabella FD (Lua accetta al
-- massimo 200 nomi "locali" per file: così ne usiamo uno solo)
FD = {}

-- ---------------------------------------------------------------------
--  CARTELLE: che cosa contiene una cartella
--  Una cartella è uno spazio di lavoro salvato (la sua "ricetta"): un
--  elenco di app (bundle ID) e di webapp (sito). Così si ricorda anche dopo
--  il riavvio delle app. Una scheda è nella cartella se corrisponde a una
--  voce della ricetta; una voce sta in una sola cartella.
-- ---------------------------------------------------------------------

function FD.folderById(id)
  for _, f in ipairs(S.folders) do if f.id == id then return f end end
  return nil
end

function FD.isFolderActive(id)
  for _, x in ipairs(S.activeFolders) do if x == id then return true end end
  return false
end

-- Indirizzo di una pagina da ricordare in una cartella: solo http(s), senza
-- la parte dopo "?" o "#" (lì a volte finiscono codici di accesso) e senza
-- caratteri che potrebbero rompere lo script del browser
function FD.cleanUrl(u)
  local base = type(u) == "string" and u:match("^(https?://[^?#%s\"]+)")
  return base
end

local function hostOf(u) return (u:match("^https?://([^/:]+)") or ""):lower():gsub("^www%.", "") end

-- La voce di ricetta di una scheda:
--  · webapp (site) · finestra di Chrome/Safari con le sue pagine (pages)
--  · finestra precisa (win): DuckDuckGo (che non dice gli indirizzi) o un'app
--    con più finestre (es. una finestra del Finder): si riconosce dal titolo e,
--    per DuckDuckGo, dal sito della pagina in vista (host)
--  · app intera (solo bid): app con una finestra sola (Slack, Claude…)
function FD.itemOf(e, asPages)
  -- asPages: la finestra era una voce "pagine" (Aggiorna): resta tale anche se
  -- ora ha una pagina sola (così si riapre quella pagina, non la home del sito)
  if e.site and not asPages then return {site = e.site, bid = e.bid, name = e.name} end
  local B = BROWSERS[e.bid]
  if B and e.win and e.urls then
    local pages, seen = {}, {}
    for _, u in ipairs(e.urls) do
      local c = FD.cleanUrl(u)
      if c and not seen[c] then seen[c] = true; table.insert(pages, c) end
    end
    if #pages > 0 then
      -- nome: il titolo della finestra (la pagina che si vede), o quello del browser
      local title = e.title or ((e.name and e.name ~= B.short) and e.name) or B.short
      return {bid = e.bid, pages = pages,
              name = title .. " · " .. #pages .. (#pages == 1 and " pagina" or " pagine")}
    end
  end
  -- finestra precisa: di un browser senza indirizzi, o di un'app con più finestre
  local several = false
  if e.win and not B then
    for _, x in pairs(T.cand) do
      if x ~= e and x.bid == e.bid and x.win then several = true end
    end
  end
  if e.win and (B or several) then
    local host = e.active and e.active:match("^https?://([^/:]+)")
    local title = e.title or e.name
    return {bid = e.bid, win = true, title = title, host = host and host:lower():gsub("^www%.", ""),
            name = (B and (B.short .. " · ") or "") .. (title or appName(e.bid, e.app))}
  end
  return {bid = e.bid, name = appName(e.bid, e.app)}
end

function FD.itemKey(it)
  if it.pages then return "pagine:" .. it.bid .. ":" .. it.pages[1] end
  if it.win then return "finestra:" .. it.bid .. ":" .. tostring(it.title) .. ":" .. tostring(it.host) end
  return it.site and ("site:" .. it.site) or it.bid
end

-- Una finestra di browser corrisponde a una voce "pagine" se almeno metà delle
-- sue schede sono di siti della voce (le pagine dentro cambiano mentre lavori)
local function pagesMatch(it, e)
  if not e.urls then return false end
  local hosts = {}
  for _, p in ipairs(it.pages) do hosts[hostOf(p)] = true end
  local total, inside = 0, 0
  for _, u in ipairs(e.urls) do
    if u:match("^https?://") then
      total = total + 1
      if hosts[hostOf(u)] then inside = inside + 1 end
    end
  end
  return total > 0 and inside * 2 >= total
end

-- La scheda e corrisponde alla voce? (per un browser, la voce "app" sono le
-- sue finestre normali, non le webapp)
function FD.itemMatches(it, e)
  if it.site then return e.site == it.site end
  if it.pages then return e.bid == it.bid and not e.site and e.win ~= nil and pagesMatch(it, e) end
  if it.win then
    if e.bid ~= it.bid or e.site or not e.win then return false end
    if it.title and e.title == it.title then return true end
    local h = e.active and e.active:match("^https?://([^/:]+)")
    return it.host ~= nil and h ~= nil and h:lower():gsub("^www%.", "") == it.host
  end
  return e.bid == it.bid and not e.site
end

-- ---- Quale scheda appartiene a quale voce (il "motore" delle cartelle) ----
-- 1. ogni voce prende al massimo UNA scheda (due finestre di Gmail: ne entra una)
-- 2. una finestra entrata in una cartella resta legata alla sua voce finché è
--    aperta, anche se ci navighi dentro (T.itemWins, ricordato anche dopo un
--    ricaricamento di Tabby)
-- 3. le altre finestre dello stesso browser o app restano fuori
function FD.bindKey(f, it) return f.id .. "|" .. FD.itemKey(it) end
T.itemWins = T.itemWins or hs.settings.get("tabbar.itemWins") or {}

local function entryMatches(it, t)
  if t.group then
    for _, k in ipairs(t.group.members) do
      local e = T.cand[k]
      if e and FD.itemMatches(it, e) then return true end
    end
    return false
  end
  return FD.itemMatches(it, t)
end

local function entryWinIds(t)
  local ids = {}
  if t.win then ids[t.win:id()] = true end
  if t.group then
    for _, k in ipairs(t.group.members) do
      local w = T.keyWin[k]
      if w then ids[w:id()] = true end
    end
  end
  return ids
end

-- Assegna le schede (tabs) alle voci delle cartelle (folders, in ordine).
-- Ritorna byTab[chiave scheda] = cartella e byItem[bindKey] = scheda.
function FD.assign(folders, tabs)
  local byTab, byItem = {}, {}
  for _, f in ipairs(folders) do
    for _, it in ipairs(f.items) do
      local bk = FD.bindKey(f, it)
      local tab
      local wid = T.itemWins[bk]
      if wid then   -- la finestra legata a questa voce, se c'è ancora
        for _, t in ipairs(tabs) do
          if not byTab[t.key] and entryWinIds(t)[wid] then tab = t; break end
        end
      end
      if not tab then
        for _, t in ipairs(tabs) do
          if not byTab[t.key] and entryMatches(it, t) then tab = t; break end
        end
      end
      if tab then
        byTab[tab.key], byItem[bk] = f, tab
        local first = next(entryWinIds(tab))
        if first and T.itemWins[bk] ~= first then
          T.itemWins[bk] = first
          T.itemWinsDirty = true
        end
      end
    end
  end
  return byTab, byItem
end

-- Le cartelle attive, nell'ordine in cui sono state attivate
function FD.activeList()
  local list = {}
  for _, id in ipairs(S.activeFolders) do
    local f = FD.folderById(id)
    if f then table.insert(list, f) end
  end
  return list
end

-- Ricostruisce l'elenco delle schede.
-- Ogni scheda ha una "chiave": il bundle ID per un'app (e per la prima
-- finestra normale di un browser), "site:<dominio>" per una webapp,
-- "win:<numero>" per le altre finestre di un browser, "g:<numero>" per un gruppo.
function rebuildTabs()
  local map, list = runningApps()
  local withWin = appsWithWindows()
  local changed = false

  -- 1. tutte le schede possibili, con la loro chiave
  local cand, keyWin, winKey, keyBid, candOrder = {}, {}, {}, {}, {}
  T.minisOf = {}   -- finestrelle dei browser (le ricalcola browserTabs)
  local function add(e)
    if cand[e.key] then return false end   -- chiave già presa
    cand[e.key] = e
    keyBid[e.key] = e.bid
    table.insert(candOrder, e.key)
    if e.win then keyWin[e.key] = e.win; winKey[e.win:id()] = e.key end
    return true
  end
  for _, app in ipairs(list) do
    local b = app:bundleID()
    if not floating(b) then
      local B = BROWSERS[b]
      local wins = (B or perWindow(b)) and standardWindows(app) or {}
      if B and #wins > 0 then
        browserTabs(app, b, B, wins, add)
      elseif #wins > 0 then
        table.sort(wins, function(x, y) return x:id() < y:id() end)
        windowTabs(app, b, wins, add, appName(b, app))
      elseif S.showWindowless or withWin[b] then
        add({key = b, bid = b, app = app, name = appName(b, app), primary = true})
      end
    end
  end
  -- il Memo può stare in una vista divisa (23/10/2026): è una "scheda" solo lì dentro
  if T.memoOpen then
    for _, g in ipairs(S.groups) do
      for _, k in ipairs(g.members) do
        if k == "memo" then add({key = "memo", bid = "org.hammerspoon.Hammerspoon", name = "Memo", memo = true}) end
      end
    end
  end
  local oldWinKey = T.winKey or {}
  applyTabNames(cand)   -- nomi scelti da te, sito scelto per le finestre con più siti
  T.cand, T.keyWin, T.winKey, T.keyBid = cand, keyWin, winKey, keyBid

  -- 2. gruppi: togli le schede che non esistono più
  --    (un gruppo con meno di 2 schede si scioglie).
  --    Una finestra di browser nel gruppo è seguita per numero di finestra
  --    (g.winOf): se cambia chiave (es. Gmail apre un link di un altro sito e
  --    non è più una webapp) resta nel gruppo con la chiave nuova.
  local snapshot, taken = {}, {}
  for _, g in ipairs(S.groups) do table.insert(snapshot, g) end
  for _, g in ipairs(snapshot) do
    local winOf, keep, newWinOf, focus = g.winOf or {}, {}, {}, nil
    for _, k in ipairs(g.members) do
      local wid, nk = winOf[k], nil
      if wid and winKey[wid] then
        nk = winKey[wid]   -- la finestra c'è ancora: la seguiamo
      elseif cand[k] and not (wid and keyWin[k] and oldWinKey[keyWin[k]:id()]) then
        -- app intera, oppure finestra appena aperta con la stessa chiave
        -- (es. dopo il riavvio del browser); non una finestra che c'era già
        nk = k
      end
      if nk and not taken[nk] then
        taken[nk] = true
        table.insert(keep, nk)
        if keyWin[nk] then newWinOf[nk] = keyWin[nk]:id() end
        if g.focus == k then focus = nk end
      end
    end
    local before = table.concat(g.members, ",")
    local function sig(m)
      local p = {}
      for k, v in pairs(m) do table.insert(p, k .. "=" .. tostring(v)) end
      table.sort(p)
      return table.concat(p, ",")
    end
    if sig(newWinOf) ~= sig(winOf) then changed = true end
    g.winOf = newWinOf
    if table.concat(keep, ",") ~= before then
      g.members = keep
      g.focus = focus or keep[1]
      normalizeGroup(g)
      changed = true
    end
  end
  T.memberOf = {}
  for _, g in ipairs(S.groups) do
    for _, k in ipairs(g.members) do T.memberOf[k] = g end
  end

  -- 3. le schede da mostrare
  local shown = {}
  for k, e in pairs(cand) do
    if not T.memberOf[k] then shown[k] = e end
  end
  for _, g in ipairs(S.groups) do
    local names = {}
    for _, k in ipairs(g.members) do table.insert(names, cand[k] and cand[k].name or k) end
    local key = "g:" .. g.id
    shown[key] = {key = key, group = g, name = table.concat(names, " + ")}
  end

  -- 4. ordine: le preferite appena aperte vanno in cima; le nuove finestre di
  --    un browser accanto alle altre dello stesso browser; il resto in fondo
  local present = {}
  for _, k in ipairs(S.order) do present[k] = true end
  for idx = #S.pinned, 1, -1 do
    local b = S.pinned[idx]
    if shown[b] and not present[b] then
      table.insert(S.order, 1, b); present[b] = true; changed = true
    end
  end
  for _, k in ipairs(candOrder) do
    if shown[k] and not present[k] then
      local at = #S.order + 1
      for i = #S.order, 1, -1 do
        if keyBid[S.order[i]] == keyBid[k] then at = i + 1; break end
      end
      table.insert(S.order, at, k); present[k] = true; changed = true
    end
  end
  for k in pairs(shown) do
    if not present[k] then table.insert(S.order, k); present[k] = true; changed = true end
  end

  -- pulizia: gruppi e finestre che non esistono più, max 300 voci ricordate
  local valid = {}
  for _, g in ipairs(S.groups) do valid["g:" .. g.id] = true end
  for idx = #S.order, 1, -1 do
    local k = S.order[idx]
    local stale = (k:sub(1, 2) == "g:" and not valid[k])
               or (k:sub(1, 2) == "f:" and not FD.folderById(tonumber(k:sub(3))))
               or (k:sub(1, 4) == "win:" and not cand[k])
               or (#S.order > 300 and not shown[k])
    if stale then table.remove(S.order, idx); changed = true end
  end

  -- 5. cartelle: nella vista normale le schede di una cartella attiva
  --    diventano una scheda sola; nella vista cartella si vedono solo le sue
  local all = {}
  for _, k in ipairs(S.order) do if shown[k] then table.insert(all, shown[k]) end end
  T.allTabs, T.tabFolder = all, {}
  local count = {}
  if S.folderView then
    T.tabFolder = FD.assign(FD.activeList(), all)
    for _, f in pairs(T.tabFolder) do count[f.id] = (count[f.id] or 0) + 1 end
  end
  if T.itemWinsDirty then
    T.itemWinsDirty = false
    hs.settings.set("tabbar.itemWins", T.itemWins)
  end
  -- una cartella attiva rimasta senza schede (app chiuse) si spegne; non
  -- subito dopo l'attivazione, perché le app ci mettono un po' ad aprirsi
  local now = hs.timer.secondsSinceEpoch()
  for idx = #S.activeFolders, 1, -1 do
    local id = S.activeFolders[idx]
    if not FD.folderById(id) or (not count[id] and now - (T.folderStart[id] or 0) > 20) then
      table.remove(S.activeFolders, idx)
      save("activeFolders")
    end
  end
  if T.viewFolder and not (S.folderView and FD.isFolderActive(T.viewFolder)) then T.viewFolder = nil end

  T.tabs = {}
  if T.viewFolder then
    for _, t in ipairs(all) do
      local f = T.tabFolder[t.key]
      if f and f.id == T.viewFolder then table.insert(T.tabs, t) end
    end
  else
    -- la scheda-cartella va dove l'hai messa tu ("f:<numero>" in S.order),
    -- altrimenti al posto della sua prima scheda
    local placed = {}
    local function placeFolder(f)
      if f and not placed[f.id] and count[f.id] then
        placed[f.id] = true
        table.insert(T.tabs, {key = "f:" .. f.id, folder = f, name = f.name})
      end
    end
    for _, k in ipairs(S.order) do
      if k:sub(1, 2) == "f:" then
        local f = FD.folderById(tonumber(k:sub(3)))
        if f and S.folderView and FD.isFolderActive(f.id) then placeFolder(f) end
      elseif shown[k] then
        local f = T.tabFolder[k]
        if f then placeFolder(f) else table.insert(T.tabs, shown[k]) end
      end
    end
  end

  focusFilterTabs()   -- in concentrazione: solo le schede scelte
  checkDuplicates()   -- lo stesso sito in due finestre: avviso
  if changed then saveGroups() end
end
