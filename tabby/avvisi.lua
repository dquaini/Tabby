-- =====================================================================
--  Tabby · avvisi.lua: i piccoli avvisi di Tabby in alto (pagina tabby/avviso.html) e,
--  per ora, il primo avviso: lo stesso sito aperto in due finestre (28/10/2026, Daniele).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

NOTICE_W, NOTICE_H = 440, 132
NOTICE_SECONDS = 12   -- dopo quanto sparisce da solo

-- In alto al centro dello spazio delle app (sotto Tabby se Tabby è in alto)
function noticeFrame()
  local A = appArea()
  return {x = math.floor(A.x + (A.w - NOTICE_W) / 2), y = A.y + 6, w = NOTICE_W, h = NOTICE_H}
end

function ensureNoticeView()
  if T.noticeView then return T.noticeView end
  T.noticeUCC = hs.webview.usercontent.new("tabbynotice")
  T.noticeUCC:setCallback(function(msg)
    local b = msg and msg.body
    if type(b) ~= "table" then return end
    if b.ready then
      T.noticeReady = true
      if T.noticePending then T.noticeView:evaluateJavaScript(T.noticePending); T.noticePending = nil end
    end
    if b.choose then
      local fn = T.noticeActions and T.noticeActions[tostring(b.choose)]
      hideNotice()
      if fn then fn() end
    end
  end)
  local page = ""
  local f = io.open((T.dir or ".") .. "/tabby/avviso.html", "r")
  if f then page = f:read("a"); f:close() end
  T.noticeView = hs.webview.new(noticeFrame(), {developerExtrasEnabled = false}, T.noticeUCC)
  T.noticeView:windowStyle({"borderless", "nonactivating"})   -- non toglie la tastiera all'app
  pcall(function() T.noticeView:transparent(true) end)
  T.noticeView:allowTextEntry(false)
  T.noticeView:level(hs.canvas.windowLevels.floating)
  T.noticeView:behaviorAsLabels({"canJoinAllSpaces", "stationary"})
  T.noticeView:html(page)
  return T.noticeView
end

-- opts = {title, sub, icon (immagine), buttons = {{id, label, main, fn}}}
function showNotice(opts)
  local v = ensureNoticeView()
  markViewUsed("noticeView")
  T.noticeActions = {}
  local bs = {}
  for _, b in ipairs(opts.buttons or {}) do
    T.noticeActions[b.id] = b.fn
    table.insert(bs, string.format("{id:%s,label:%s,main:%s}", jsString(b.id), jsString(b.label), tostring(b.main == true)))
  end
  local js = string.format("show({title:%s,sub:%s,icon:%s,buttons:[%s]})", jsString(opts.title or ""),
    jsString(opts.sub or ""), jsString(imageDataURI(opts.icon) or ""), table.concat(bs, ","))
  v:frame(noticeFrame())
  v:show()
  if T.noticeReady then v:evaluateJavaScript(js) else T.noticePending = js end
  if T.noticeTimer then T.noticeTimer:stop() end
  T.noticeTimer = hs.timer.doAfter(NOTICE_SECONDS, hideNotice)
end

function hideNotice()
  if T.noticeTimer then T.noticeTimer:stop(); T.noticeTimer = nil end
  if T.noticeView then T.noticeView:hide() end
end

-- ---------------------------------------------------------------------
--  MEMORIA (28/10/2026): le pagine della Concentrazione, della ricerca e degli avvisi
--  tengono acceso ciascuna un piccolo motore web (~30 MB). Se non le usi da 5 minuti
--  si chiudono; la prossima volta si ricreano da sole (un attimo in più, la prima volta).
--  Il Memo e la sfera restano sempre pronti (devono aprirsi subito).
-- ---------------------------------------------------------------------
VIEW_IDLE_S = 300
T.viewUsed = T.viewUsed or {}
IDLE_VIEWS = {
  {view = "focusView", ready = "focusReady", busy = function() return T.fsel or T.fask or T.fend end},
  {view = "searchView", ready = "searchReady", busy = function() return T.searchOpen end},
  {view = "noticeView", ready = "noticeReady", busy = function() return false end},
  {view = "openView", ready = "openReady", busy = function() return T.opening ~= nil end},
}
function markViewUsed(name) T.viewUsed[name] = hs.timer.secondsSinceEpoch() end

function releaseIdleViews()
  local now = hs.timer.secondsSinceEpoch()
  for _, d in ipairs(IDLE_VIEWS) do
    local v = T[d.view]
    if v and not d.busy() and not v:isVisible() and now - (T.viewUsed[d.view] or 0) > VIEW_IDLE_S then
      pcall(function() v:delete() end)
      T[d.view], T[d.ready] = nil, nil
      print("Tabby · memoria: chiudo la pagina «" .. d.view .. "» (non usata da 5 minuti)")
    end
  end
end
T.viewGC = hs.timer.doEvery(120, releaseIdleViews)

-- ---------------------------------------------------------------------
--  SITI DOPPI: apri una finestra con un solo sito (es. Gmail) e quel sito è già aperto
--  da solo in un'altra finestra (anche di un altro browser) → Tabby avvisa, una volta:
--  «Vai a quella» · «Chiudi questa» · «Lascia».
--  Vale per le finestre appena aperte (o appena passate a quel sito): quelle che c'erano
--  già all'avvio di Tabby non contano.
-- ---------------------------------------------------------------------
DUP_RECENT_S = 120   -- avvisa solo se la finestra "doppia" è nuova da meno di così

function checkDuplicates()
  if T.paused or not T.cand then return end
  local now = hs.timer.secondsSinceEpoch()
  T.siteSeen = T.siteSeen or {}     -- [finestra] = {site, at} (quando è diventata di quel sito)
  T.dupWarned = T.dupWarned or {}
  -- all'avvio i siti delle finestre arrivano con qualche secondo di ritardo (il browser
  -- risponde dopo): quello che si vede nei primi 15 secondi c'era già, non è "nuovo"
  T.dupStart = T.dupStart or now
  local first = now - T.dupStart < 15
  local bySite = {}
  for _, e in pairs(T.cand) do
    if e.win and e.site then
      local id = e.win:id()
      local seen = T.siteSeen[id]
      if not seen or seen.site ~= e.site then
        T.siteSeen[id] = {site = e.site, at = first and 0 or now}
      end
      bySite[e.site] = bySite[e.site] or {}
      table.insert(bySite[e.site], e)
    end
  end
  for site, list in pairs(bySite) do
    if #list >= 2 then
      table.sort(list, function(x, y)
        local ax, ay = T.siteSeen[x.win:id()].at, T.siteSeen[y.win:id()].at
        if ax ~= ay then return ax < ay end
        return x.win:id() < y.win:id()   -- (a pari tempo: la finestra più nuova ha il numero più alto)
      end)
      local new, old = list[#list], list[1]
      local id = new.win:id()
      local at = T.siteSeen[id].at
      if at > 0 and now - at < DUP_RECENT_S and not T.dupWarned[id] then
        T.dupWarned[id] = true
        warnDuplicate(new, old)
      end
    end
  end
end

function warnDuplicate(new, old)
  local name = (old.name and old.name ~= "" and old.name) or siteName(nil, new.site)
  print(string.format("Tabby · sito doppio: «%s» è già aperto in un'altra finestra", name))
  local newKey, oldKey, newWin = new.key, old.key, new.win
  showNotice({
    title = name .. " è già aperto in un'altra finestra",
    sub = "Hai due finestre con lo stesso sito.",
    icon = favicon(new.site),
    buttons = {
      {id = "keep", label = "Lascia", fn = function() end},
      {id = "old", label = "Vai a quella", fn = function()
        if T.cand[oldKey] then focusKey(oldKey) end
      end},
      {id = "close", label = "Chiudi questa", main = true, fn = function()
        print("Tabby · sito doppio: chiudo la finestra nuova di «" .. name .. "»")
        pcall(function() newWin:close() end)
        scheduleRebuild()
        if T.cand[oldKey] then after(0.3, function() focusKey(oldKey) end) end
      end},
    },
  })
end
