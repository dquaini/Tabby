-- =====================================================================
--  Tabby · browser.lua: cosa c'è in ogni finestra dei browser (Chrome, Safari… con AppleScript; DuckDuckGo con l'Accessibilità).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  BROWSER: cosa c'è in ogni finestra (chiesto al browser con AppleScript)
--  La prima volta macOS chiede il permesso: "Hammerspoon vuole controllare
--  Google Chrome" → Consenti. Senza permesso le finestre restano schede
--  "Chrome A / B", ma senza nome e logo del sito.
-- ---------------------------------------------------------------------

-- Attenzione: dentro "tell application" la parola tab è la SCHEDA del
-- browser, non il carattere di tabulazione ("a" & tab & "b" dà "atabb").
-- Per questo i separatori si preparano prima, fuori dal tell (TB e NL).
AS_WINDOWS = [[
set TB to (ASCII character 9)
set NL to (ASCII character 10)
with timeout of 2 seconds
  tell application "%s"
    set out to ""
    repeat with w in windows
      try
        set row to (name of w) & TB
        try
          set b to bounds of w
          set row to row & ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text) & TB
        on error
          set row to row & "-" & TB
        end try
        repeat with t in tabs of w
          try
            set row to row & (URL of t) & TB
          on error
            set row to row & "about:blank" & TB
          end try
        end repeat
        set out to out & row & NL
      end try
    end repeat
    return out
  end tell
end timeout
]]

-- Il nome del sito per la diagnosi in console (mai l'indirizzo completo: privacy)
function domainsOf(urls)
  local out = {}
  for _, u in ipairs(urls or {}) do
    table.insert(out, u:match("^%a+://([^/:%?#]+)") or u:match("^(%a+:)") or "?")
  end
  return table.concat(out, ",")
end

-- Browser senza AppleScript (DuckDuckGo): guarda dentro la finestra con
-- l'Accessibilità, senza entrare nella pagina web, e cerca la barra degli
-- indirizzi e i pulsanti delle schede.
function axScan(win)
  local res = {roles = {}}
  pcall(function()
    local root = hs.axuielement.windowElement(win)
    local visited, tabButtons = 0, 0
    local radios, tabDesc = 0, 0
    local function walk(e, depth)
      if visited > 800 or depth > 14 then return end
      visited = visited + 1
      local role = e:attributeValue("AXRole") or "?"
      local sub  = e:attributeValue("AXSubrole")
      res.roles[role] = (res.roles[role] or 0) + 1
      if role == "AXWebArea" then
        -- la pagina web: non la leggiamo, ma il suo indirizzo è la fonte più sicura
        local u = e:attributeValue("AXURL")
        u = type(u) == "table" and u.url or u
        if type(u) == "string" and u:match("^https?://") then res.pageUrl = u end
        return
      end
      if (role == "AXTextField" or role == "AXComboBox") and not res.url then
        local v = e:attributeValue("AXValue")
        if type(v) == "string" and not v:find("%s") and v:match("^[%w%-]+[%.:]") then
          res.url = v
        end
      end
      if role == "AXTabGroup" then
        local tabs = e:attributeValue("AXTabs")
        if type(tabs) == "table" and #tabs > 0 then res.tabs = #tabs end
      end
      if sub == "AXTabButton" or role == "AXTab" then tabButtons = tabButtons + 1 end
      if role == "AXRadioButton" then radios = radios + 1 end
      local desc = (e:attributeValue("AXRoleDescription") or ""):lower()
      if desc == "tab" or desc == "scheda" then tabDesc = tabDesc + 1 end
      for _, c in ipairs(e:attributeValue("AXChildren") or {}) do walk(c, depth + 1) end
    end
    walk(root, 0)
    res.tabs = res.tabs or (tabButtons > 0 and tabButtons)
                        or (tabDesc > 0 and tabDesc)
                        or (radios > 0 and radios) or nil
    if res.pageUrl then res.url = res.pageUrl end
  end)
  if res.url and not res.url:match("^%a+://") then res.url = "https://" .. res.url end
  -- privacy: dell'indirizzo teniamo solo il sito (https://dominio/). Il resto
  -- può contenere dati personali o "gettoni" di accesso (es. dopo un login).
  if res.url then
    local origin = res.url:match("^(%a+://[^/%?#]+)")
    res.url = origin and (origin .. "/") or nil
  end
  return res
end

function axBrowserInfo(app, short)
  local wins, sigParts = {}, {}
  -- memoria per finestra: si tengono solo le finestre ancora aperte
  local oldCache, oldDiag = T.axCache or {}, T.axDiag or {}
  T.axCache, T.axDiag = {}, {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then
      -- quando il browser è nascosto macOS non lascia guardare dentro le
      -- finestre: si usa l'ultima cosa vista (ricordata per ogni finestra)
      local r = (not app:isHidden()) and axScan(w) or {roles = {}}
      local cached = oldCache[w:id()]
      if r.url and r.tabs then
        T.axCache[w:id()] = {url = r.url, tabs = r.tabs}
      elseif cached then
        T.axCache[w:id()] = cached
        r.url, r.tabs = cached.url, cached.tabs
      end
      -- webapp solo se sappiamo che c'è una sola scheda; altrimenti finestra normale
      local urls = (r.url and r.tabs == 1) and {r.url} or {"about:mixed"}
      table.insert(wins, {name = w:title() or "", urls = urls})
      table.insert(sigParts, (w:title() or "") .. "|" .. tostring(r.url) .. "|" .. tostring(r.tabs))
      -- per la diagnosi: cosa ha trovato Tabby (scritto in console solo se cambia)
      local roles = {}
      for k, v in pairs(r.roles) do table.insert(roles, k .. "=" .. v) end
      table.sort(roles)
      local diag = string.format("Tabby · %s «%s»: indirizzo=%s · schede=%s · [%s]",
        short, tostring(w:title()), tostring(r.url), tostring(r.tabs), table.concat(roles, " "))
      -- si scrive solo se cambiano sito o schede (non a ogni cambio della pagina)
      local result = tostring(r.url) .. "|" .. tostring(r.tabs)
      if oldDiag[w:id()] ~= result then print(diag) end
      T.axDiag[w:id()] = result
    end
  end
  return wins, table.concat(sigParts, ";")
end

-- La domanda ad AppleScript si fa "in parallelo" (con osascript): Tabby non
-- resta ferma ad aspettare il browser (prima ~200 ms ogni 3 s, misurati sul
-- Mac di lavoro, e intanto anche la tastiera aspettava). Quando arriva la
-- risposta, se è cambiato qualcosa, le schede si aggiornano.
-- (onBrowserAnswer: definita più sotto o in un altro file)
T.asJobs, T.asOut = {}, {}
function askBrowser(bid, B)
  local job = T.asJobs[bid]
  if job then
    -- una domanda ancora senza risposta dopo 6 s: la si lascia perdere
    if hs.timer.secondsSinceEpoch() - job.at < 6 then return end
    pcall(function() job.task:terminate() end)
  end
  local task
  task = hs.task.new("/usr/bin/osascript", function(code, out, err)
    if T.asJobs[bid] and T.asJobs[bid].task ~= task then return end   -- risposta vecchia
    T.asJobs[bid] = nil
    local prev = T.asOut[bid]
    -- senza risposta (browser occupato, permesso tolto) si tiene l'ultima buona,
    -- così le webapp non spariscono e ricompaiono
    local now = {answered = (code == 0), res = (code == 0) and (out or "") or (prev and prev.res),
                 denied = (code ~= 0) and tostring(err or ""):find("%-1743") ~= nil}
    T.asOut[bid] = now
    if not prev or prev.answered ~= now.answered or prev.res ~= now.res then
      onBrowserAnswer()
    end
  end, {"-e", string.format(AS_WINDOWS, B.as)})
  if task and task:start() then
    T.asJobs[bid] = {task = task, at = hs.timer.secondsSinceEpoch()}
  end
end

-- Aggiorna T.binfo: per ogni browser aperto, l'elenco delle finestre
-- con titolo e indirizzi delle schede. Ritorna true se è cambiato qualcosa.
-- Per i browser con AppleScript usa l'ultima risposta arrivata e (se ask)
-- fa partire una domanda nuova.
function refreshBrowsers(ask)
  local new, sig = {}, {}
  for bid, B in pairs(BROWSERS) do
    local app = appFor(bid)
    if app and app:isRunning() and B.kind == "ax" then
      local wins, s = axBrowserInfo(app, B.short)
      new[bid] = wins
      table.insert(sig, bid .. "=" .. s)
    elseif app and app:isRunning() then
      if ask ~= false then askBrowser(bid, B) end
      local last = T.asOut[bid]
      local res = last and last.res
      local answered = (last == nil) or last.answered   -- nessuna risposta ancora: aspettiamo
      if res then
        local wins = {}
        for row in res:gmatch("[^\r\n]+") do
          local fields = {}
          for f in (row .. "\t"):gmatch("([^\t]*)\t") do table.insert(fields, f) end
          local name = table.remove(fields, 1) or ""
          -- posizione della finestra (sinistra,alto,destra,basso): serve ad
          -- abbinarla anche quando i titoli non coincidono
          local bounds
          local x1, y1, x2, y2 = (fields[1] or ""):match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
          if x1 then
            bounds = {x = tonumber(x1), y = tonumber(y1), w = x2 - x1, h = y2 - y1}
            table.remove(fields, 1)
          elseif fields[1] == "-" then
            table.remove(fields, 1)
          end
          local urls = {}
          for _, u in ipairs(fields) do if u ~= "" then table.insert(urls, u) end end
          table.insert(wins, {name = name, urls = urls, bounds = bounds})
        end
        new[bid] = wins
        table.insert(sig, bid .. "=" .. res)
      end
      -- diagnosi: AppleScript non risponde (di solito manca il permesso)
      T.asDiag = T.asDiag or {}
      if last and T.asDiag[bid] ~= answered then
        T.asDiag[bid] = answered
        if not answered and last.denied then
          print(string.format("Tabby · %s: manca il permesso, niente nomi e loghi dei siti. " ..
            "Impostazioni di Sistema → Privacy e sicurezza → Automazione → " ..
            "Hammerspoon → %s (deve essere acceso)", B.short, B.as))
        elseif not answered then
          print(string.format("Tabby · %s non ha risposto in tempo (occupato o in chiusura): " ..
            "uso l'ultima risposta buona", B.short))
        end
      end
    else
      T.asOut[bid] = nil   -- browser chiuso: si dimentica l'ultima risposta
    end
  end
  table.sort(sig)
  local s = table.concat(sig, "|")
  local changed = (s ~= T.binfoSig)
  T.binfo, T.binfoSig = new, s
  return changed
end

function domainOf(u)
  local d = u and u:match("^https?://([^/:%?#]+)")
  if not d then return nil end
  return (d:lower():gsub("^www%.", ""))
end

-- Il sito della finestra, se TUTTE le sue schede sono dello stesso sito
function siteOf(urls)
  if not urls or #urls == 0 then return nil end
  local dom
  for _, u in ipairs(urls) do
    local d = domainOf(u)
    if not d or (dom and d ~= dom) then return nil end
    dom = d
  end
  return dom
end

-- Nome della "webapp": l'ultimo pezzo del titolo ("Posta - io@x - Gmail" → Gmail),
-- altrimenti dal dominio ("youtube.com" → Youtube)
function siteName(title, dom)
  local tt = (title or ""):gsub("^%(%d+%)%s*", "")
  for _, sep in ipairs({" — ", " – ", " | ", " · ", " • ", " :: "}) do
    tt = tt:gsub((sep:gsub("%p", "%%%0")), " - ")
  end
  local parts = {}
  for p in (tt .. " - "):gmatch("(.-) %- ") do
    p = p:match("^%s*(.-)%s*$")
    if p ~= "" then table.insert(parts, p) end
  end
  -- nome principale del dominio: mail.proton.me → proton, youtube.com → youtube
  local labels = {}
  for p in dom:gmatch("[^%.]+") do table.insert(labels, p) end
  local main = labels[#labels - 1] or labels[1] or dom
  -- 1) il pezzo del titolo che contiene il nome del sito ("Notion", "Google Docs", "Proton Mail")
  for i = #parts, 1, -1 do
    if #parts[i] <= 24 and parts[i]:lower():find(main:lower(), 1, true) then return parts[i] end
  end
  -- 1b) un pezzo del titolo uguale a un pezzo del dominio ("Meet - abc-defg" su meet.google.com)
  for i = #parts, 1, -1 do
    for _, lab in ipairs(labels) do
      if #lab >= 3 and parts[i]:lower() == lab:lower() then return parts[i] end
    end
  end
  -- 2) l'ultimo pezzo, se il titolo è fatto a pezzi ("Posta - io@x - Gmail")
  local last = parts[#parts]
  if #parts >= 2 and last and #last >= 2 and #last <= 24 then return last end
  -- 3) il nome del dominio
  return main:sub(1, 1):upper() .. main:sub(2)
end

-- Notifiche scritte nel titolo delle webapp: "(3) WhatsApp", "Posta (12) - …"
function titleBadge(title)
  if not title then return nil end
  return title:match("^%((%d+)%)") or title:match("^[^%-|]-%((%d+)%)%s")
end

-- Logo del sito (scaricato una volta e ricordato). Prova più fonti:
-- servizio loghi di DuckDuckGo (dominio, poi dominio principale), poi Google.
-- Se falliscono tutte (es. Wi-Fi non ancora connesso) si riprova dopo un minuto.
FAVICON_RETRY = 60
function favicon(domain)
  local c = T.favicons[domain]
  if c then return c end
  T.faviconFail = T.faviconFail or {}
  if c == false then
    local at = T.faviconFail[domain]   -- nil = download in corso
    if not at or hs.timer.secondsSinceEpoch() - at < FAVICON_RETRY then return nil end
  end
  T.favicons[domain] = false
  T.faviconFail[domain] = nil
  local parent = domain:match("^[^%.]+%.(.+%..+)$")   -- mail.proton.me → proton.me
  local sources = {"https://icons.duckduckgo.com/ip3/" .. domain .. ".ico"}
  if parent then table.insert(sources, "https://icons.duckduckgo.com/ip3/" .. parent .. ".ico") end
  table.insert(sources, "https://www.google.com/s2/favicons?sz=64&domain=" .. domain)
  -- ultima riserva: il logo direttamente dal sito (se una rete aziendale
  -- blocca i servizi di loghi, il sito che stai usando di sicuro risponde)
  table.insert(sources, "https://" .. domain .. "/favicon.ico")
  local function try(n)
    if not sources[n] then
      T.faviconFail[domain] = hs.timer.secondsSinceEpoch()
      print("Tabby · logo di " .. domain .. " non trovato (riprovo tra un minuto)")
      return
    end
    pcall(function()
      hs.image.imageFromURL(sources[n], function(img)
        local ok = img and img:size() and img:size().w >= 8
        if ok then
          T.favicons[domain] = img
          if draw then draw() end
        else
          try(n + 1)
        end
      end)
    end)
  end
  try(1)
  return nil
end

-- Icona di una scheda: logo del sito per le webapp, altrimenti icona dell'app
function keyIcon(key)
  local e = T.cand[key]
  if e and e.site then
    local f = favicon(e.site)
    if f then return f end
  end
  return icon((e and e.bid) or T.keyBid[key] or key)
end

function keySmallIcon(key)
  local img = keyIcon(key)
  return img and img:setSize({w = 16, h = 16}) or nil
end

-- Nome di una finestra-scheda: il suo titolo (nome del documento, della
-- cartella del Finder, della pagina…), senza il nome dell'app in fondo
-- ("Relazione — TextEdit" → "Relazione").
function windowName(title, appTitle)
  local t = (title or ""):match("^%s*(.-)%s*$")
  if appTitle and appTitle ~= "" then
    for _, sep in ipairs({" — ", " – ", " - ", " | "}) do
      local tail = sep .. appTitle
      if #t > #tail and t:sub(-#tail) == tail then t = t:sub(1, -#tail - 1) end
    end
  end
  if t == "" or t == appTitle then return nil end
  return t
end

-- Le finestre "normali" di un'app diventano schede (titles: titoli da usare
-- al posto di quelli sullo schermo, per i browser). Con una sola finestra la
-- scheda si chiama come l'app; con due o più ognuna prende il titolo della sua
-- finestra (titoli uguali: "Download", "Download (2)"). La prima finestra (la
-- più vecchia) ha come chiave il bundle ID dell'app, così resta al posto
-- dell'app (preferite, notifiche del Dock); le altre "win:<numero>".
function windowTabs(app, b, wins, add, appTitle, titles)
  local seen = {}
  for n, w in ipairs(wins) do
    local name = appTitle
    if #wins > 1 then
      local base = windowName(titles and titles[w:id()] or w:title(), appTitle) or appTitle
      seen[base] = (seen[base] or 0) + 1
      name = seen[base] > 1 and (base .. " (" .. seen[base] .. ")") or base
    end
    add({key = (n == 1) and b or ("win:" .. w:id()), bid = b, app = app,
         win = w, name = name, primary = (n == 1)})
  end
end

-- Abbina le finestre sullo schermo a quelle descritte dal browser, dal modo
-- più sicuro al meno sicuro:
--  1) stesso titolo E stessa posizione/misura
--  2) titolo che inizia con quello del browser E stessa posizione (Chrome con
--     più profili, o col nome "Google Chrome", allunga il titolo: "Gmail - Lavoro")
--  3) stesso titolo  ·  4) titolo che inizia uguale  (solo finestre grandi: il
--     video in miniatura di Meet ha lo stesso titolo della pagina)
--  5) solo posizione, ma solo se è unica: Tabby adatta le finestre tutte allo
--     stesso spazio, quindi di solito la posizione da sola NON le distingue
--     (difetto della v9.10: Sofascore e Google scambiate)
function matchBrowserWindows(wins, info)
  local found, how, used = {}, {}, {}
  info = info or {}
  local small = T.isSmall
  local function samePlace(w, e)
    local f, r = w:frame(), e.bounds
    return r ~= nil and math.abs(f.x - r.x) < 4 and math.abs(f.y - r.y) < 4
       and math.abs(f.w - r.w) < 4 and math.abs(f.h - r.h) < 4
  end
  local function sameTitle(w, e) return e.name == (w:title() or "") end
  local function startsTitle(w, e)
    local t = w:title() or ""
    return e.name ~= "" and #t > #e.name and t:sub(1, #e.name) == e.name
       and t:sub(#e.name + 1, #e.name + 1) == " "
  end
  local function pass(label, test, bigOnly)
    for i, w in ipairs(wins) do
      if not found[i] and not (bigOnly and small(w)) then
        for k, e in ipairs(info) do
          if not used[k] and test(w, e, i, k) then
            used[k], found[i], how[i] = true, e, label
            break
          end
        end
      end
    end
  end
  pass("titolo e posizione", function(w, e) return sameTitle(w, e) and samePlace(w, e) end)
  pass("inizio del titolo e posizione", function(w, e) return startsTitle(w, e) and samePlace(w, e) end)
  pass("titolo", sameTitle, true)
  pass("inizio del titolo", startsTitle, true)
  pass("posizione (unica)", function(w, e, i, k)
    if not samePlace(w, e) then return false end
    for i2, w2 in ipairs(wins) do
      if i2 ~= i and not found[i2] and samePlace(w2, e) then return false end
    end
    for k2, e2 in ipairs(info) do
      if k2 ~= k and not used[k2] and samePlace(w, e2) then return false end
    end
    return true
  end)
  return found, how
end

-- Le schede di un browser: una per finestra; una finestra con un solo
-- sito è una "webapp" (nome e logo del sito)
function browserTabs(app, b, B, wins, add)
  table.sort(wins, function(x, y) return x:id() < y:id() end)
  local info = T.binfo[b]
  local matched, how = matchBrowserWindows(wins, info)
  local plain, names = {}, {}
  -- Memoria per finestra: l'ultima descrizione riconosciuta. La risposta del
  -- browser arriva in parallelo e può essere vecchia di qualche secondo: se nel
  -- frattempo titolo e posizione sono cambiati (Meet e Gmail cambiano titolo di
  -- continuo) la finestra non va "persa" (icona del sito che va e viene).
  T.bwKnown = T.bwKnown or {}
  local oldKnown, known = T.bwKnown[b] or {}, {}
  T.bwDiag = T.bwDiag or {}
  local minis = {}
  for i, w in ipairs(wins) do
    local found = matched[i]
    if not found and oldKnown[w:id()] then found, how[i] = oldKnown[w:id()], "memoria" end
    if found then known[w:id()] = found end
    -- Finestrella (video in miniatura di Meet, barra "stai condividendo"):
    -- piccola e assente dall'elenco del browser. Non è una scheda.
    local f = w:frame()
    local mini = info and B.kind ~= "ax" and not found and T.isSmall(w)
    if mini then
      minis[w:id()] = w
      if not (T.minis and T.minis[w:id()]) then
        print(string.format("Tabby · %s: finestrella «%s» %.0fx%.0f (video in miniatura?): non è una scheda, resta visibile",
          B.short, tostring(w:title()), f.w, f.h))
      end
      goto nextwin
    end
    -- il titolo come lo dà il browser (senza il nome del profilo)
    local title = found and found.name or w:title() or ""
    names[w:id()] = title
    local site = found and siteOf(found.urls)
    -- diagnosi (solo se il browser risponde ad AppleScript, e solo se il
    -- risultato cambia)
    if info and B.kind ~= "ax" then
      local result = (site and ("webapp " .. site) or "finestra normale") ..
                     " · schede=" .. tostring(found and #found.urls or "?")
      if T.bwDiag[w:id()] ~= result then
        T.bwDiag[w:id()] = result
        print(string.format("Tabby · %s «%s»: abbinata per %s · siti=%s → %s",
          B.short, tostring(w:title()), how[i] or "NIENTE",
          found and domainsOf(found.urls) or "?", result))
      end
    end
    if site then
      -- stesso sito già preso (da un'altra finestra, anche di un altro browser):
      -- questa finestra diventa una scheda a sé. Le notifiche si leggono dal
      -- titolo attuale della finestra (quello del browser può essere vecchio).
      local e = {key = "site:" .. site, bid = b, app = app, win = w, site = site,
                 name = siteName(title, site), titleBadge = titleBadge(w:title()) or titleBadge(title)}
      if not add(e) then e.key = "win:" .. w:id(); add(e) end
    else
      table.insert(plain, w)
    end
    ::nextwin::
  end
  T.bwKnown[b] = known   -- solo le finestre ancora aperte
  T.minisOf = T.minisOf or {}
  T.minisOf[b] = next(minis) and minis or nil
  T.minis = {}
  for _, m in pairs(T.minisOf) do for id, w in pairs(m) do T.minis[id] = w end end
  windowTabs(app, b, plain, add, B.short, names)
end
