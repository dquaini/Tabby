-- =====================================================================
--  Tabby · cerca.lua: «Cerca nelle finestre» (⌃⌥F, 25/10/2026, Daniele: «un ⌘F su
--  tutte le finestre aperte»).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
--
--  ⌃⌥F apre una barra di ricerca in alto al centro (lo sfondo si oscura, la barra di
--  Tabby no). Scrivi: compaiono le finestre che
--  contengono quelle parole (nel titolo o nel testo), con un pezzetto di testo intorno.
--  Invio (o clic): Tabby porta davanti quella finestra e ci fa ⌘F con la parola già
--  scritta, così la trovi evidenziata. A barra vuota: le ultime finestre usate.
--
--  Come fa a sapere il testo: lo legge con l'Accessibilità (come fa già per i siti di
--  DuckDuckGo), una finestra alla volta e a piccoli passi, così Tabby resta reattiva.
--  Legge la finestra che lasci (poco dopo) e, quando apri la ricerca, quelle non lette
--  da un po'. Il testo resta solo in memoria: non si salva da nessuna parte.
--  Limiti (di macOS, non di Tabby): del browser si legge solo la pagina in vista di
--  ogni finestra; di Slack e Notion il testo sullo schermo; Windows App è un'immagine
--  (si trova solo per titolo).
-- =====================================================================

SEARCH_W, SEARCH_H = 640, 470
SEARCH_MAX     = 8          -- risultati mostrati
TEXT_BUDGET_MS = 110        -- tempo massimo per leggere una finestra (a pezzi, poi riprende)
TEXT_MAX_CHARS = 60000      -- testo massimo tenuto per finestra
TEXT_MAX_NODES = 5000
TEXT_STALE_S   = 30         -- aprendo la ricerca, si rileggono le finestre lette da più di così
TEXT_ROLES = {AXStaticText = true, AXTextArea = true, AXTextField = true, AXCell = true}

T.textIdx = T.textIdx or {}   -- [numero finestra] = {raw, low, at, title, bid}

-- ---------------------------------------------------------------------
--  Testo "normalizzato": minuscolo e senza accenti (così «perche» trova «perché»)
-- ---------------------------------------------------------------------
ACCENTS = {
  ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ä"] = "a", ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
  ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i", ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["ö"] = "o",
  ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c", ["ñ"] = "n",
  ["À"] = "a", ["Á"] = "a", ["È"] = "e", ["É"] = "e", ["Ì"] = "i", ["Í"] = "i", ["Ò"] = "o", ["Ó"] = "o",
  ["Ù"] = "u", ["Ú"] = "u", ["Ç"] = "c", ["Ñ"] = "n", ["’"] = "'", ["‘"] = "'",
}
function normText(s)
  s = tostring(s or "")
  s = s:gsub("[\xC3\xE2][\x80-\xBF]+", function(c) return ACCENTS[c] end)
  return s:lower()
end

-- ---------------------------------------------------------------------
--  Leggere il testo di una finestra (a pezzi: se il tempo finisce, riprende dopo)
-- ---------------------------------------------------------------------
function textJob(w)
  return {id = w:id(), win = w, stack = {}, acc = {}, chars = 0, nodes = 0, started = false}
end

-- Ritorna true quando la finestra è finita
function textJobStep(job)
  local t0 = hs.timer.absoluteTime()
  if not job.started then
    job.started = true
    local ok, el = pcall(function() return hs.axuielement.windowElement(job.win) end)
    if not ok or not el then return true end
    job.stack = {el}
  end
  while #job.stack > 0 do
    if job.nodes >= TEXT_MAX_NODES or job.chars >= TEXT_MAX_CHARS then job.stack = {}; break end
    if (hs.timer.absoluteTime() - t0) / 1e6 > TEXT_BUDGET_MS then return false end
    local el = table.remove(job.stack)
    job.nodes = job.nodes + 1
    pcall(function()
      local role = el:attributeValue("AXRole")
      if TEXT_ROLES[role] then
        local v = el:attributeValue("AXValue")
        if type(v) == "string" and v:find("%S") then
          table.insert(job.acc, v)
          job.chars = job.chars + #v
        end
        if role == "AXTextArea" then return end   -- (il testo è già tutto lì)
      end
      local kids = el:attributeValue("AXChildren")
      if kids then
        -- al contrario: così si legge dall'alto in basso
        for i = #kids, 1, -1 do table.insert(job.stack, kids[i]) end
      end
    end)
  end
  local raw = table.concat(job.acc, "\n")
  if #raw > TEXT_MAX_CHARS then raw = raw:sub(1, TEXT_MAX_CHARS) end
  local w = job.win
  local a = w:application()
  T.textIdx[job.id] = {raw = raw, low = normText(raw), at = hs.timer.secondsSinceEpoch(),
                       title = w:title() or "", bid = a and a:bundleID()}
  -- le app fatte con Electron (Slack, Notion…) mostrano il loro testo all'Accessibilità
  -- solo se glielo si chiede: se non si è letto quasi niente, glielo chiediamo (una volta)
  if #raw < 40 and a then
    T.axAsked = T.axAsked or {}
    local pid = a:pid()
    if not T.axAsked[pid] then
      T.axAsked[pid] = true
      pcall(function() hs.axuielement.applicationElement(a):setAttributeValue("AXManualAccessibility", true) end)
      T.textIdx[job.id].at = 0   -- da rileggere
    end
  end
  return true
end

-- La coda: una finestra alla volta, un pezzetto ogni 0,12 s
function textQueue(w, front)
  if not w then return end
  local id = w:id()
  T.textJobs = T.textJobs or {}
  for _, j in ipairs(T.textJobs) do if j.id == id then return end end
  if front then table.insert(T.textJobs, 1, textJob(w)) else table.insert(T.textJobs, textJob(w)) end
  if not T.textTimer then
    T.textTimer = hs.timer.doEvery(0.12, textTick)
  elseif not T.textTimer:running() then
    T.textTimer:start()
  end
end

function textTick()
  local jobs = T.textJobs or {}
  if T.paused or #jobs == 0 then
    if T.textTimer then T.textTimer:stop() end
    return
  end
  local job = jobs[1]
  local ok, done = pcall(textJobStep, job)
  if not ok or done then
    table.remove(jobs, 1)
    if T.searchOpen then searchRefresh() end
  end
end

-- Le finestre dove cercare: quelle "normali" delle app aperte (non Hammerspoon)
function searchWindows()
  local out = {}
  local _, list = runningApps()
  for _, app in ipairs(list) do
    local b = app:bundleID()
    if b and not IGNORE[b] then
      for _, w in ipairs(standardWindows(app)) do table.insert(out, w) end
    end
  end
  return out
end

-- Quando lasci una finestra, poco dopo Tabby ne legge il testo (pronto per la ricerca)
function textOnLeave(key)
  local w = key and T.keyWin and T.keyWin[key]
  if not w and key and T.keyBid and T.keyBid[key] == key then
    local app = appFor(key)
    w = app and app:mainWindow()
  end
  if not w then return end
  hs.timer.doAfter(1.5, function() if not T.paused then textQueue(w) end end)
end

-- ---------------------------------------------------------------------
--  Cercare
-- ---------------------------------------------------------------------

-- Il pezzetto di testo intorno alla parola trovata (dal testo vero, con gli accenti)
function textSnippet(raw, qn)
  local low, map = {}, {}
  local pos = 1
  for _, c in utf8.codes(raw) do
    local ch = utf8.char(c)
    local n = normText(ch)
    for k = 1, #n do table.insert(low, n:sub(k, k)); table.insert(map, pos) end
    pos = pos + #ch
  end
  local s = table.concat(low)
  local i = s:find(qn, 1, true)
  if not i then return nil end
  local a, b = map[i], (map[i + #qn] or (#raw + 1)) - 1
  -- fino a ~40 caratteri prima e ~80 dopo, senza tagliare a metà una lettera
  local function back(p, n)
    while n > 0 and p > 1 do p = p - 1; while p > 1 and raw:byte(p) >= 0x80 and raw:byte(p) < 0xC0 do p = p - 1 end; n = n - 1 end
    return p
  end
  local function fwd(p, n)
    while n > 0 and p <= #raw do p = p + 1; while p <= #raw and raw:byte(p) >= 0x80 and raw:byte(p) < 0xC0 do p = p + 1 end; n = n - 1 end
    return p
  end
  local s0, s1 = back(a, 40), fwd(b + 1, 80)
  local function clean(x) return (x:gsub("%s+", " ")) end
  return {(s0 > 1 and "…" or "") .. clean(raw:sub(s0, a - 1)), raw:sub(a, b), clean(raw:sub(b + 1, s1 - 1)) .. (s1 <= #raw and "…" or "")}
end

-- La scheda (nome e chiave) di una finestra
function searchTabOf(w)
  local key = T.winKey and T.winKey[w:id()]
  local a = w:application()
  local b = a and a:bundleID()
  if not key and b and T.cand and T.cand[b] then key = b end
  local name = key and T.cand[key] and T.cand[key].name
  return key, name, b
end

-- Il titolo da mostrare: quello della finestra, senza « - Google Chrome» in fondo
function searchTitle(title, b, w)
  if not title or title == "" then return nil end
  local an = appName(b, w:application())
  local cut = title:gsub("%s[%-–—]%s" .. an:gsub("%p", "%%%0") .. "$", "")
  return cut
end

function searchResults(q)
  local qn = normText(q):gsub("^%s+", ""):gsub("%s+$", "")
  local words = {}
  for wd in qn:gmatch("%S+") do table.insert(words, wd) end
  local recentRank = {}
  for i, k in ipairs(T.recent or {}) do recentRank[k] = i end
  local items = {}
  for _, w in ipairs(searchWindows()) do
    local id = w:id()
    local key, tabName, b = searchTabOf(w)
    local title = w:title() or ""
    local tn = normText(title .. " " .. (tabName or "") .. " " .. appName(b, w:application()))
    local idx = T.textIdx[id]
    local body = idx and idx.low or ""
    local ok, score, inText = true, 0, false
    for _, wd in ipairs(words) do
      local inT = tn:find(wd, 1, true)
      local inB = body:find(wd, 1, true)
      if not inT and not inB then ok = false; break end
      if inT then score = score + 100 end
      if inB then
        inText = true
        local n = 0
        for _ in body:gmatch((wd:gsub("%p", "%%%0"))) do n = n + 1; if n >= 20 then break end end
        score = score + n
      end
    end
    if ok then
      if #words == 0 then score = 0 end
      local r = key and recentRank[key]
      score = score + (r and (30 - math.min(r, 30)) or 0)
      if #words > 0 or r then
        table.insert(items, {id = id, win = w, key = key, bid = b, score = score, inText = inText,
                             title = searchTitle(title, b, w) or tabName or appName(b, w:application()),
                             app = appName(b, w:application()), words = words, qn = qn})
      end
    end
  end
  -- il Memo (il suo file)
  if #words > 0 then
    local memo = readMemo and readMemo() or ""
    local ml = normText(memo)
    local all = true
    for _, wd in ipairs(words) do if not ml:find(wd, 1, true) then all = false end end
    if all then
      table.insert(items, {id = "memo", memo = true, title = "Memo", app = "Tabby", score = 50, inText = true, words = words, qn = qn, raw = memo})
    end
  end
  table.sort(items, function(x, y)
    if x.score ~= y.score then return x.score > y.score end
    return tostring(x.title) < tostring(y.title)
  end)
  while #items > SEARCH_MAX do table.remove(items) end
  -- il pezzetto di testo: con la frase intera, se no con la prima parola
  for _, it in ipairs(items) do
    if #words > 0 then
      local raw = it.raw or (T.textIdx[it.id] and T.textIdx[it.id].raw) or ""
      it.snippet = textSnippet(raw, qn) or (words[1] and textSnippet(raw, words[1]))
    end
  end
  return items
end

-- ---------------------------------------------------------------------
--  La barra di ricerca (pagina tabby/cerca.html). Non prende la tastiera: i tasti
--  li intercetta Tabby e li passa alla pagina (così niente problemi di "attenzione"
--  con le altre app, e funziona anche sopra Windows App)
-- ---------------------------------------------------------------------
function searchFrame()
  local A = appArea()
  return {x = math.floor(A.x + (A.w - SEARCH_W) / 2), y = math.floor(A.y + math.max(40, A.h * 0.14)),
          w = SEARCH_W, h = SEARCH_H}
end

function ensureSearchView()
  if T.searchView then return T.searchView end
  T.searchUCC = hs.webview.usercontent.new("tabbysearch")
  T.searchUCC:setCallback(function(msg)
    local b = msg and msg.body
    if type(b) ~= "table" then return end
    if b.ready then
      T.searchReady = true
      if T.searchOpen then searchRefresh() end
    end
    if b.choose then searchChoose(tonumber(b.choose)) end
    if b.hover then T.searchSel = tonumber(b.hover) or T.searchSel end
    if b.outside then closeSearch() end
  end)
  local page = ""
  local f = io.open((T.dir or ".") .. "/tabby/cerca.html", "r")
  if f then page = f:read("a"); f:close() end
  T.searchView = hs.webview.new(searchFrame(), {developerExtrasEnabled = false}, T.searchUCC)
  T.searchView:windowStyle({"borderless", "nonactivating"})
  pcall(function() T.searchView:transparent(true) end)
  T.searchView:allowTextEntry(false)
  T.searchView:level(hs.canvas.windowLevels.modalPanel)
  T.searchView:behaviorAsLabels({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
  T.searchView:html(page)
  return T.searchView
end

function openSearch()
  if T.searchOpen then closeSearch(); return end
  if T.fsel or T.fask or T.fend then return end
  T.searchOpen = true
  T.searchQ = ""
  T.searchSel = 1
  local v = ensureSearchView()
  v:frame(searchFrame())
  focusDim(true)   -- lo sfondo si oscura, la barra di Tabby no (come la Concentrazione)
  v:show()
  print("Tabby · cerca nelle finestre")
  -- si rileggono le finestre non lette da un po' (prima quelle usate di recente)
  local now = hs.timer.secondsSinceEpoch()
  local wins = searchWindows()
  local rank = {}
  for i, k in ipairs(T.recent or {}) do rank[k] = i end
  table.sort(wins, function(x, y)
    local rx, ry = rank[T.winKey[x:id()] or ""] or 99, rank[T.winKey[y:id()] or ""] or 99
    return rx < ry
  end)
  for _, w in ipairs(wins) do
    local idx = T.textIdx[w:id()]
    if not idx or now - idx.at > TEXT_STALE_S then textQueue(w) end
  end
  -- un clic fuori la chiude
  if not T.searchTap then
    T.searchTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(e)
      if not T.searchOpen then return false end
      local p, f = e:location(), searchFrame()
      if not (p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h) then later(closeSearch) end
      return false
    end)
  end
  T.searchTap:start()
  searchRefresh()
end

function closeSearch()
  if not T.searchOpen then return end
  T.searchOpen = false
  if T.searchTap then T.searchTap:stop() end
  focusDim(false)
  if T.searchView then
    T.searchView:evaluateJavaScript("typeof reset === 'function' && reset()")
    T.searchView:hide()
  end
end

function searchRefresh()
  if not (T.searchOpen and T.searchView) then return end
  T.searchItems = searchResults(T.searchQ or "")
  T.searchSel = math.max(1, math.min(T.searchSel or 1, #T.searchItems))
  local parts = {}
  for i, it in ipairs(T.searchItems) do
    local ic = it.memo and "" or (imageDataURI(icon(it.bid)) or "")
    local sn = it.snippet and ("[" .. jsString(it.snippet[1]) .. "," .. jsString(it.snippet[2]) .. "," .. jsString(it.snippet[3]) .. "]") or "null"
    table.insert(parts, string.format("{i:%d,title:%s,app:%s,icon:%s,snip:%s}", i, jsString(it.title),
      jsString(it.app), jsString(ic), sn))
  end
  local reading = #(T.textJobs or {})
  local js = string.format("render({q:%s,sel:%d,reading:%d,items:[%s]})", jsString(T.searchQ or ""),
    T.searchSel, reading, table.concat(parts, ","))
  if T.searchReady then T.searchView:evaluateJavaScript(js) end
end

-- I tasti mentre la ricerca è aperta (li chiama l'intercettatore di scorciatoie.lua)
function searchKey(e)
  local f = e:getFlags()
  local code = e:getKeyCode()
  -- ⌃⌥F di nuovo: chiude
  if f.ctrl and f.alt and K[code] == "f" then later(closeSearch); return true end
  if f.ctrl or f.alt then return false end
  if code == K.escape then later(closeSearch); return true end
  if code == K["return"] or code == K.padenter then later(function() searchChoose(T.searchSel) end); return true end
  if code == K.down then T.searchSel = math.min((T.searchSel or 1) + 1, #(T.searchItems or {})); later(searchRefresh); return true end
  if code == K.up then T.searchSel = math.max((T.searchSel or 1) - 1, 1); later(searchRefresh); return true end
  if code == K.delete then
    local q = T.searchQ or ""
    if f.cmd then q = "" else
      local last = utf8.offset(q, -1)
      q = last and q:sub(1, last - 1) or ""
    end
    T.searchQ = q
    T.searchSel = 1
    later(searchRefresh)
    return true
  end
  if f.cmd then
    if K[code] == "v" then
      local clip = (hs.pasteboard.getContents() or ""):gsub("[\r\n\t]+", " ")
      T.searchQ = (T.searchQ or "") .. clip:sub(1, 200)
      T.searchSel = 1
      later(searchRefresh)
    end
    return true   -- (le altre combinazioni con ⌘ non vanno all'app sotto)
  end
  local ch = e:getCharacters()
  if ch and ch ~= "" and not ch:find("%c") then
    T.searchQ = (T.searchQ or "") .. ch
    T.searchSel = 1
    later(searchRefresh)
  end
  return true
end

-- Invio o clic: la finestra davanti e, se la parola è nel testo, ⌘F con la parola
function searchChoose(i)
  local it = T.searchItems and T.searchItems[i]
  local q = T.searchQ or ""
  closeSearch()
  if not it then return end
  print("Tabby · cerca: «" .. q .. "» → " .. tostring(it.title))
  if it.memo then openMemo(); return end
  local w = it.win
  if it.key and (T.cand[it.key] or T.memberOf[it.key]) then
    T.pickedWin = {id = w:id(), at = hs.timer.secondsSinceEpoch()}
    local g = T.memberOf[it.key]
    if g then showGroup(g) else focusKey(it.key) end
  else
    if w:isMinimized() then w:unminimize() end
    w:focus()
    afterFocus()
  end
  if it.inText and q:find("%S") then
    hs.timer.doAfter(0.45, function()
      local fw = hs.window.focusedWindow()
      if not (fw and fw:id() == w:id()) then return end   -- (non è arrivata davanti, o è cambiata)
      hs.eventtap.keyStroke({"cmd"}, "f", 0)
      hs.timer.doAfter(0.15, function() hs.eventtap.keyStrokes(q) end)
    end)
  end
end
