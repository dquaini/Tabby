-- =====================================================================
--  TABBY  ·  v9.3
--  Una barra con una scheda per ogni app: ne vedi una alla volta,
--  clicchi (o premi Ctrl+Option+1…9) per passare all'altra.
--
--  v2: tasto impostazioni, schermo intero, barra che si nasconde.
--  v3: solo app con finestre, ✕ per chiudere, tasto scrivania, chiudi tutte.
--  v4: nome Tabby; Ctrl+1…9 in tutte le app; Ctrl+0 = scrivania;
--      Tabby visibile anche a schermo intero; impostazioni raggruppate.
--  v5: ✕ = chiudi finestra / chiudi app; tasto ⚡︎ con app veloci.
--  v6: posizione di Tabby a scelta (alto, basso, sinistra, destra).
--  v7: batteria; ⌥Tab = app di prima; Ctrl+frecce; Esc chiude la
--      Calcolatrice; gestione di tante app (icone compatte e "+N").
--  v8: DIVIDI LO SCHERMO (2, 3 o 4 app) trascinando le schede nelle
--      zone → diventano un'unica scheda di gruppo con tasto "Scomponi";
--      riordino delle schede trascinandole.
--  v8.x: Tabby nella fascia del notch dei MacBook.
--  v9: notifiche sulle schede; scorciatoie tutte su ⌃⌥ (Ctrl+Option);
--      Memo veloce; browser: una scheda per finestra, "webapp" con nome
--      e logo del sito, Chrome A / B / C; correzioni varie.
--  v9.1-9.3: DuckDuckGo (via Accessibilità, ricorda i siti anche da nascosto),
--      loghi da più fonti, Memo salvato in ~/Documents/Tabby Memo.txt.
-- =====================================================================


-- ---------------------------------------------------------------------
--  IMPOSTAZIONI DI BASE
--  (preferite e opzioni si gestiscono dal tasto ⚙︎ di Tabby;
--  questi valori servono solo al primo avvio)
-- ---------------------------------------------------------------------

local DEFAULTS = {
  position        = "top",   -- dove sta Tabby: top / bottom / left / right
  pinned          = { "com.apple.finder", "com.apple.iCal", "com.apple.Notes" },
  oneAtATime      = true,    -- nasconde le altre app
  fit             = true,    -- adatta le finestre a Tabby
  autohide        = false,   -- Tabby nascosta, appare col mouse sul bordo
  showWindowless  = false,   -- mostra anche app aperte ma senza finestre
  tabbyFullscreen = true,    -- il tasto verde riempie lo spazio accanto a Tabby
  notchBand       = "auto",  -- Tabby nella fascia del notch: "auto" / "on" / "off"
  order           = {},      -- ordine delle schede (si aggiorna trascinandole)
  groups          = {},      -- gruppi di app con lo schermo diviso
  groupSeq        = 0,
}

-- App da non mostrare mai come scheda
local IGNORE = {
  ["org.hammerspoon.Hammerspoon"] = true,
}

-- Tutte le scorciatoie di Tabby usano questi tasti, più un altro tasto:
-- ⌃⌥1…9 schede, ⌃⌥0 scrivania, ⌃⌥← → scheda prima/dopo,
-- ⌃⌥Tab app di prima, ⌃⌥C calcolatrice, ⌃⌥M memo.
local MODS = {"ctrl", "alt"}

-- App "veloci" (tasto ⚡︎): si aprono piccole in alto a destra, sopra
-- l'app che stai usando, senza nasconderla. Stessa scorciatoia per
-- aprirle e chiuderle, Esc per chiuderle. "key" va premuto insieme a ⌃⌥.
-- (memo = true è il Memo di Tabby, non un'app)
local QUICK = {
  {memo = true, name = "Memo", key = "m"},
  {bid = "com.apple.calculator", name = "Calcolatrice", key = "c"},
}

-- Il Memo si salva da solo in questo file (lo trovi nel Finder e con Spotlight)
local MEMO_FILE = os.getenv("HOME") .. "/Documents/Tabby Memo.txt"

-- Browser: ogni finestra diventa una scheda. Una finestra con un solo sito
-- diventa una "webapp" (nome e logo del sito); più finestre normali si
-- chiamano A, B, C… (as = nome per AppleScript)
local BROWSERS = {
  ["com.google.Chrome"]     = {kind = "chrome", as = "Google Chrome",  short = "Chrome"},
  ["com.brave.Browser"]     = {kind = "chrome", as = "Brave Browser",  short = "Brave"},
  ["com.microsoft.edgemac"] = {kind = "chrome", as = "Microsoft Edge", short = "Edge"},
  ["com.apple.Safari"]      = {kind = "safari", as = "Safari",         short = "Safari"},
  -- DuckDuckGo non risponde ad AppleScript: l'indirizzo si legge dalla sua
  -- barra con l'Accessibilità (kind = "ax"); webapp solo se la finestra ha 1 scheda
  ["com.duckduckgo.macos.browser"] = {kind = "ax", short = "DuckDuckGo"},
}

-- Schemi per dividere lo schermo: ogni zona è {x, y, larghezza, altezza}
-- in frazioni dello spazio libero accanto a Tabby.
local LAYOUTS = {
  ["2-50"] = {name = "Due app · metà e metà",
              zones = {{0, 0, .5, 1}, {.5, 0, .5, 1}}},
  ["2-70"] = {name = "Due app · 70 / 30",
              zones = {{0, 0, .7, 1}, {.7, 0, .3, 1}}},
  ["3"]    = {name = "Tre app · una sopra, due sotto",
              zones = {{0, 0, 1, .5}, {0, .5, .5, .5}, {.5, .5, .5, .5}}},
  ["4"]    = {name = "Quattro app · un quarto ciascuna",
              zones = {{0, 0, .5, .5}, {.5, 0, .5, .5}, {0, .5, .5, .5}, {.5, .5, .5, .5}}},
}
local LAYOUT_ORDER     = {"2-50", "2-70", "3", "4"}
local LAYOUT_FOR_COUNT = {[2] = "2-50", [3] = "3", [4] = "4"}
local ZONE_GAP         = 3     -- spazio tra le finestre divise (per lato)

local BAR_H     = 38          -- altezza di Tabby (in alto / in basso)
local SIDE_W    = 190         -- larghezza di Tabby (a sinistra / a destra)
local ROW_H     = 36          -- altezza di una scheda quando Tabby è laterale
local TAB_MAX_W = 210         -- larghezza massima di una scheda
local BTN_W     = 44          -- dimensione dei tasti scrivania / ⊞ / ⚡︎ / ⚙︎
local BAT_W     = 76          -- spazio per l'indicatore della batteria
-- Con tante app aperte:
local COMPACT_BELOW = 120     -- sotto questa larghezza le schede diventano solo icona
local ICON_W    = 44          -- larghezza di una scheda "solo icona"
local ACTIVE_W  = 160         -- la scheda attiva resta larga, col nome
local MIN_ROW_H = 26          -- altezza minima di una scheda in verticale
local FINDER    = "com.apple.finder"

local COL = {
  bar     = {hex = "#15171B"},
  active  = {hex = "#2C2F36"},
  accent  = {hex = "#4C8DFF"},
  divider = {hex = "#2A2D33"},
  text    = {hex = "#E8E9EC"},
  textMid = {hex = "#B9BDC6"},
  textDim = {hex = "#7D828C"},
  batFull = {hex = "#34C27A"},
  batLow  = {hex = "#FF6B57"},
  badge   = {hex = "#FF453A"},
}


-- ---------------------------------------------------------------------
--  DA QUI IN GIÙ IL FUNZIONAMENTO
-- ---------------------------------------------------------------------

-- Tutto in una tabella globale: se fosse locale, Hammerspoon
-- "dimenticherebbe" watcher, timer e scorciatoie dopo un po'.
Tabby = { tabs = {}, icons = {}, hotkeys = {}, fsApps = {}, memberOf = {},
          closePos = {}, fullscreen = false, revealed = false,
          visible = nil, desktopMode = false, lastKey = nil,
          cand = {}, keyWin = {}, winKey = {}, keyBid = {},
          badges = {}, favicons = {}, binfo = {}, lastFire = {} }
local T = Tabby

hs.window.animationDuration = 0

-- Impostazioni salvate (restano anche dopo riavvio)
local S = {}
for k, v in pairs(DEFAULTS) do
  local saved = hs.settings.get("tabbar." .. k)
  if saved == nil then S[k] = v else S[k] = saved end
end
local function save(k) hs.settings.set("tabbar." .. k, S[k]) end

local FLOATER = {}
for _, q in ipairs(QUICK) do if q.bid then FLOATER[q.bid] = true end end

local function isPinned(bid)
  for _, p in ipairs(S.pinned) do if p == bid then return true end end
  return false
end

local function screen() return hs.screen.primaryScreen() end

local function later(fn) hs.timer.doAfter(0, fn) end

-- Altezza della barra dei menu di macOS
local function menuBarH()
  local s = screen()
  local d = s:frame().y - s:fullFrame().y
  if d > 0 and not T.fullscreen then
    hs.settings.set("tabbar.menuH", d)
    return d
  end
  local saved = hs.settings.get("tabbar.menuH")
  if saved then return saved end
  local ff = s:fullFrame()
  if (s:name() or ""):find("Built%-in") and ff.h / ff.w > 0.64 then return 37 end
  return 24
end

local function isVertical()
  return S.position == "left" or S.position == "right"
end

-- La barra dei menu di macOS è impostata su "nascondi sempre"?
local function detectMenuHidden()
  local ok, out = pcall(function()
    return (hs.execute("defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null") or "") ..
           (hs.execute("defaults -currentHost read NSGlobalDomain _HIHideMenuBar 2>/dev/null") or "")
  end)
  return ok and type(out) == "string" and out:match("1") ~= nil
end

-- Tabby deve stare nella fascia del notch? Automatico, o scelto a mano
-- (⚙︎ → Posizione di Tabby → Usa la fascia del notch).
local function useNotchBand()
  if S.position ~= "top" then return false end
  if S.notchBand == "on" then return true end
  if S.notchBand == "off" then return false end
  return (T.notch ~= nil) and T.menuHidden
end

-- Area utile dello schermo (senza barra dei menu e Dock; a schermo intero: tutto).
-- Sui Mac col notch e la barra dei menu nascosta, macOS lascia comunque
-- libera la fascia del notch: Tabby ci sale sopra e la usa.
local function baseRect()
  local s = screen()
  if T.fullscreen then return s:fullFrame() end
  local f = s:frame()
  if useNotchBand() then
    local ff = s:fullFrame()
    return {x = f.x, y = ff.y, w = f.w, h = f.y + f.h - ff.y}
  end
  return f
end

-- Dove sta Tabby in questo momento
local function barFrame()
  local R = baseRect()
  local p = S.position
  if p == "bottom" then return {x = R.x, y = R.y + R.h - BAR_H, w = R.w, h = BAR_H} end
  if p == "left"   then return {x = R.x, y = R.y, w = SIDE_W, h = R.h} end
  if p == "right"  then return {x = R.x + R.w - SIDE_W, y = R.y, w = SIDE_W, h = R.h} end
  local y = R.y
  -- se appare col mouse e la barra dei menu scende anche lei, mettiti sotto
  if S.autohide and y == screen():fullFrame().y then y = y + menuBarH() end
  return {x = R.x, y = y, w = R.w, h = BAR_H}
end

-- Spazio dove stanno le app (tutto lo schermo meno Tabby)
local function appArea()
  local f = screen():frame()
  if S.autohide then return f end
  local p = S.position
  if p == "bottom" then return hs.geometry.rect(f.x, f.y, f.w, f.h - BAR_H) end
  if p == "left"   then return hs.geometry.rect(f.x + SIDE_W, f.y, f.w - SIDE_W, f.h) end
  if p == "right"  then return hs.geometry.rect(f.x, f.y, f.w - SIDE_W, f.h) end
  -- in alto: le app partono subito sotto Tabby (anche se Tabby sta nella fascia del notch)
  local top = baseRect().y + BAR_H
  return hs.geometry.rect(f.x, top, f.w, f.y + f.h - top)
end

-- Il "notch" (la tacca della fotocamera dei MacBook recenti).
-- Lo chiediamo a macOS: dove inizia e finisce, in coordinate dello schermo.
local function detectNotch()
  local s  = screen()
  local ff = s:fullFrame()
  local ok, success, res = pcall(function(src) return hs.osascript.javascript(src) end, [[
    ObjC.import('AppKit');
    var out = '';
    try {
      var s = $.NSScreen.screens.objectAtIndex(0);
      var top = s.safeAreaInsets.top;
      if (top > 0) {
        out = s.auxiliaryTopLeftArea.size.width + ',' +
              s.auxiliaryTopRightArea.size.width + ',' + top;
      } else {
        out = 'none';
      }
    } catch (e) {}
    out;
  ]])
  T.notchInfo = "macOS: " .. tostring(ok and success and res or "nessuna risposta")
  if ok and success and res == "none" then
    return nil   -- macOS ha risposto: questo schermo non ha il notch
  end
  if ok and success and type(res) == "string" then
    local lw, rw = res:match("^([%d%.]+),([%d%.]+),")
    lw, rw = tonumber(lw), tonumber(rw)
    if lw and rw and lw + rw < ff.w then
      return {x1 = ff.x + lw, x2 = ff.x + ff.w - rw}
    end
  end
  -- macOS non ha dato misure: stima. I MacBook col notch hanno uno schermo
  -- più "alto" (circa 0,65) dei 16:10 senza notch (0,625).
  if (s:name() or ""):find("Built%-in") and ff.h / ff.w > 0.64 then
    T.notchInfo = T.notchInfo .. " → stimato"
    return {x1 = ff.x + ff.w / 2 - 105, x2 = ff.x + ff.w / 2 + 105}
  end
  return nil
end

-- Parte di Tabby (in coordinate della barra) coperta dal notch, se c'è
local function notchZone(bf)
  if isVertical() or not useNotchBand() then return nil end
  if bf.y > screen():fullFrame().y + 2 then return nil end   -- Tabby è sotto: nessun problema
  local n = T.notch
  if not n then   -- forzato a mano ma non rilevato: notch stimato al centro
    local ff = screen():fullFrame()
    n = {x1 = ff.x + ff.w / 2 - 105, x2 = ff.x + ff.w / 2 + 105}
  end
  return {x1 = n.x1 - bf.x - 6, x2 = n.x2 - bf.x + 6}
end

-- Scrive nella console di Hammerspoon cosa ha rilevato Tabby
local function logDiagnostics()
  local s = screen()
  print(string.format(
    "Tabby · schermo %s %.0fx%.0f · area utile da y=%.0f · notch: %s (%s) · barra menu nascosta: %s · fascia notch: %s (%s)",
    tostring(s:name()), s:fullFrame().w, s:fullFrame().h, s:frame().y,
    T.notch and string.format("%.0f-%.0f", T.notch.x1, T.notch.x2) or "no",
    tostring(T.notchInfo), tostring(T.menuHidden),
    tostring(useNotchBand()), tostring(S.notchBand)))
end

-- Rettangolo (in coordinate dello schermo) della zona k di uno schema
local function zoneRect(layoutId, k)
  local A = appArea()
  local z = LAYOUTS[layoutId].zones[k]
  local G = ZONE_GAP
  return hs.geometry.rect(A.x + z[1] * A.w + G, A.y + z[2] * A.h + G,
                          z[3] * A.w - 2 * G, z[4] * A.h - 2 * G)
end

local function icon(bid)
  if not bid then return nil end
  if T.icons[bid] == nil then
    T.icons[bid] = hs.image.imageFromAppBundle(bid) or false
  end
  return T.icons[bid] or nil
end

local function smallIcon(bid)
  local img = icon(bid)
  return img and img:setSize({w = 16, h = 16}) or nil
end

-- App aperte "vere" (quelle che compaiono nel Dock)
local function runningApps()
  local map, list = {}, {}
  for _, app in ipairs(hs.application.runningApplications()) do
    local bid = app:bundleID()
    if bid and app:kind() == 1 and not IGNORE[bid] and not map[bid] then
      map[bid] = app
      table.insert(list, app)
    end
  end
  return map, list
end

local function appName(bid, app)
  return (app and app:name()) or hs.application.nameForBundleID(bid) or bid
end

-- Quali app hanno almeno una finestra aperta (anche nascosta o ridotta).
-- Il filtro finestre ricorda anche quelle su altre scrivanie.
local function appsWithWindows()
  local set = {}
  if T.allWins then
    for _, w in ipairs(T.allWins:getWindows()) do
      local a = w:application()
      local b = a and a:bundleID()
      if b then set[b] = true end
    end
  end
  for b in pairs(T.fsApps) do set[b] = true end
  return set
end


local draw  -- definita più sotto

local function standardWindows(app)
  local out = {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then table.insert(out, w) end
  end
  return out
end


-- ---------------------------------------------------------------------
--  BROWSER: cosa c'è in ogni finestra (chiesto al browser con AppleScript)
--  La prima volta macOS chiede il permesso: "Hammerspoon vuole controllare
--  Google Chrome" → Consenti. Senza permesso le finestre restano schede
--  "Chrome A / B", ma senza nome e logo del sito.
-- ---------------------------------------------------------------------

local AS_WINDOWS = [[
with timeout of 2 seconds
  tell application "%s"
    set out to ""
    repeat with w in windows
      try
        set row to (name of w) & tab
        repeat with t in tabs of w
          try
            set row to row & (URL of t) & tab
          on error
            set row to row & "about:blank" & tab
          end try
        end repeat
        set out to out & row & linefeed
      end try
    end repeat
    return out
  end tell
end timeout
]]

-- Browser senza AppleScript (DuckDuckGo): guarda dentro la finestra con
-- l'Accessibilità, senza entrare nella pagina web, e cerca la barra degli
-- indirizzi e i pulsanti delle schede.
local function axScan(win)
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
  return res
end

local function axBrowserInfo(app, short)
  local wins, sigParts = {}, {}
  T.axCache = T.axCache or {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then
      -- quando il browser è nascosto macOS non lascia guardare dentro le
      -- finestre: si usa l'ultima cosa vista (ricordata per ogni finestra)
      local r = (not app:isHidden()) and axScan(w) or {roles = {}}
      local cached = T.axCache[w:id()]
      if r.url and r.tabs then
        T.axCache[w:id()] = {url = r.url, tabs = r.tabs}
      elseif cached then
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
      T.axDiag = T.axDiag or {}
      if T.axDiag[w:id()] ~= diag then T.axDiag[w:id()] = diag; print(diag) end
    end
  end
  return wins, table.concat(sigParts, ";")
end

-- Aggiorna T.binfo: per ogni browser aperto, l'elenco delle finestre
-- con titolo e indirizzi delle schede. Ritorna true se è cambiato qualcosa.
local function refreshBrowsers()
  local new, sig = {}, {}
  for bid, B in pairs(BROWSERS) do
    local app = hs.application.get(bid)
    if app and app:isRunning() and B.kind == "ax" then
      local wins, s = axBrowserInfo(app, B.short)
      new[bid] = wins
      table.insert(sig, bid .. "=" .. s)
    elseif app and app:isRunning() then
      local ok, success, res = pcall(function()
        return hs.osascript.applescript(string.format(AS_WINDOWS, B.as))
      end)
      if ok and success and type(res) == "string" then
        local wins = {}
        for row in res:gmatch("[^\r\n]+") do
          local fields = {}
          for f in (row .. "\t"):gmatch("([^\t]*)\t") do table.insert(fields, f) end
          local name = table.remove(fields, 1) or ""
          local urls = {}
          for _, u in ipairs(fields) do if u ~= "" then table.insert(urls, u) end end
          table.insert(wins, {name = name, urls = urls})
        end
        new[bid] = wins
        table.insert(sig, bid .. "=" .. res)
      end
    end
  end
  table.sort(sig)
  local s = table.concat(sig, "|")
  local changed = (s ~= T.binfoSig)
  T.binfo, T.binfoSig = new, s
  return changed
end

local function domainOf(u)
  local d = u and u:match("^https?://([^/:%?#]+)")
  if not d then return nil end
  return (d:lower():gsub("^www%.", ""))
end

-- Il sito della finestra, se TUTTE le sue schede sono dello stesso sito
local function siteOf(urls)
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
local function siteName(title, dom)
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
  -- 2) l'ultimo pezzo, se il titolo è fatto a pezzi ("Posta - io@x - Gmail")
  local last = parts[#parts]
  if #parts >= 2 and last and #last >= 2 and #last <= 24 then return last end
  -- 3) il nome del dominio
  return main:sub(1, 1):upper() .. main:sub(2)
end

-- Notifiche scritte nel titolo delle webapp: "(3) WhatsApp", "Posta (12) - …"
local function titleBadge(title)
  if not title then return nil end
  return title:match("^%((%d+)%)") or title:match("^[^%-|]-%((%d+)%)%s")
end

-- Logo del sito (scaricato una volta e ricordato). Prova più fonti:
-- servizio loghi di DuckDuckGo (dominio, poi dominio principale), poi Google.
local function favicon(domain)
  local c = T.favicons[domain]
  if c ~= nil then return c or nil end
  T.favicons[domain] = false
  local parent = domain:match("^[^%.]+%.(.+%..+)$")   -- mail.proton.me → proton.me
  local sources = {"https://icons.duckduckgo.com/ip3/" .. domain .. ".ico"}
  if parent then table.insert(sources, "https://icons.duckduckgo.com/ip3/" .. parent .. ".ico") end
  table.insert(sources, "https://www.google.com/s2/favicons?sz=64&domain=" .. domain)
  local function try(n)
    if not sources[n] then return end
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
local function keyIcon(key)
  local e = T.cand[key]
  if e and e.site then
    local f = favicon(e.site)
    if f then return f end
  end
  return icon((e and e.bid) or T.keyBid[key] or key)
end

local function keySmallIcon(key)
  local img = keyIcon(key)
  return img and img:setSize({w = 16, h = 16}) or nil
end

-- Le schede di un browser: una per finestra
local function browserTabs(app, b, B, wins, add)
  table.sort(wins, function(x, y) return x:id() < y:id() end)
  local info = T.binfo[b]
  local used = {}
  local entries = {}
  for _, w in ipairs(wins) do
    local title = w:title() or ""
    local found
    if info then
      for k, e in ipairs(info) do
        if not used[k] and e.name == title then used[k] = true; found = e; break end
      end
    end
    table.insert(entries, {w = w, title = title, site = found and siteOf(found.urls)})
  end

  local nPlain = 0
  for _, x in ipairs(entries) do if not x.site then nPlain = nPlain + 1 end end

  local letter, usedKeys = 0, {}
  for _, x in ipairs(entries) do
    if x.site then
      local key = "site:" .. x.site
      if usedKeys[key] then key = "win:" .. x.w:id() end
      usedKeys[key] = true
      add({key = key, bid = b, app = app, win = x.w, site = x.site,
           name = siteName(x.title, x.site), titleBadge = titleBadge(x.title)})
    else
      letter = letter + 1
      local name = B.short
      if nPlain > 1 then name = name .. " " .. string.char(64 + math.min(letter, 26)) end
      add({key = (letter == 1) and b or ("win:" .. x.w:id()), bid = b, app = app,
           win = x.w, name = name, primary = (letter == 1)})
    end
  end
end


-- ---------------------------------------------------------------------
--  NOTIFICHE: i numerini rossi che le app mostrano sul Dock
-- ---------------------------------------------------------------------

local function readDockBadges()
  local out = {}
  pcall(function()
    local dock = hs.application.get("com.apple.dock")
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

local function badgeOfKey(key)
  local e = T.cand[key]
  if not e then return nil end
  if e.site then return e.titleBadge end
  if e.primary then return T.badges[e.bid] end
  return nil
end

-- Notifica da mostrare su una scheda (per un gruppo: la somma)
local function badgeFor(t)
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


-- ---------------------------------------------------------------------
--  ORDINE DELLE SCHEDE E GRUPPI
--  Ogni scheda ha una "chiave": bundle ID (app, o prima finestra normale
--  di un browser), "site:<dominio>" (webapp), "win:<id finestra>" (altre
--  finestre di un browser), "g:<numero>" (gruppo = vista divisa).
--  S.order è l'ordine delle chiavi.
-- ---------------------------------------------------------------------

local function orderIndex(key)
  for i, k in ipairs(S.order) do if k == key then return i end end
  return nil
end

local function orderRemove(key)
  local i = orderIndex(key)
  if i then table.remove(S.order, i) end
end

local function saveGroups()
  save("groups"); save("order"); save("groupSeq")
end

local function groupIndex(g)
  for i, x in ipairs(S.groups) do if x == g then return i end end
  return nil
end

-- Scioglie un gruppo: le sue app tornano schede singole, al suo posto
local function dissolveGroup(g)
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
local function normalizeGroup(g)
  if #g.members < 2 then dissolveGroup(g); return end
  if #LAYOUTS[g.layout].zones ~= #g.members then
    g.layout = LAYOUT_FOR_COUNT[#g.members]
  end
end

local function removeFromGroups(bid)
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

-- Ricostruisce l'elenco delle schede.
-- Ogni scheda ha una "chiave": il bundle ID per un'app (e per la prima
-- finestra normale di un browser), "site:<dominio>" per una webapp,
-- "win:<numero>" per le altre finestre di un browser, "g:<numero>" per un gruppo.
local function rebuildTabs()
  local map, list = runningApps()
  local withWin = appsWithWindows()
  local changed = false

  -- 1. tutte le schede possibili, con la loro chiave
  local cand, keyWin, winKey, keyBid, candOrder = {}, {}, {}, {}, {}
  local function add(e)
    if cand[e.key] then return end
    cand[e.key] = e
    keyBid[e.key] = e.bid
    table.insert(candOrder, e.key)
    if e.win then keyWin[e.key] = e.win; winKey[e.win:id()] = e.key end
  end
  for _, app in ipairs(list) do
    local b = app:bundleID()
    if not FLOATER[b] then
      local B = BROWSERS[b]
      local wins = B and standardWindows(app)
      if B and #wins > 0 then
        browserTabs(app, b, B, wins, add)
      elseif S.showWindowless or withWin[b] then
        add({key = b, bid = b, app = app, name = appName(b, app), primary = true})
      end
    end
  end
  T.cand, T.keyWin, T.winKey, T.keyBid = cand, keyWin, winKey, keyBid

  -- 2. gruppi: togli le schede che non esistono più
  --    (un gruppo con meno di 2 schede si scioglie)
  local snapshot = {}
  for _, g in ipairs(S.groups) do table.insert(snapshot, g) end
  for _, g in ipairs(snapshot) do
    local keep = {}
    for _, k in ipairs(g.members) do if cand[k] then table.insert(keep, k) end end
    if #keep ~= #g.members then
      g.members = keep
      if not g.focus or not cand[g.focus] then g.focus = keep[1] end
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
               or (k:sub(1, 4) == "win:" and not cand[k])
               or (#S.order > 300 and not shown[k])
    if stale then table.remove(S.order, idx); changed = true end
  end

  T.tabs = {}
  for _, k in ipairs(S.order) do
    if shown[k] then table.insert(T.tabs, shown[k]) end
  end

  -- lettere delle finestre normali dei browser: A, B, C… da sinistra a destra
  local plain = {}
  for _, t in ipairs(T.tabs) do
    if t.win and not t.site then
      plain[t.bid] = plain[t.bid] or {}
      table.insert(plain[t.bid], t)
    end
  end
  for b, list in pairs(plain) do
    local short = BROWSERS[b] and BROWSERS[b].short or appName(b)
    for n, t in ipairs(list) do
      t.name = (#list > 1) and (short .. " " .. string.char(64 + math.min(n, 26))) or short
    end
  end

  if changed then saveGroups() end
end

-- ---------------------------------------------------------------------
--  FINESTRE
-- ---------------------------------------------------------------------

local function hasFullscreen(app)
  for _, w in ipairs(app:allWindows()) do
    if w:isFullScreen() then return true end
  end
  return false
end


local layoutGroup   -- definita più sotto

local function frontBid()
  local f = hs.application.frontmostApplication()
  return f and f:bundleID()
end

-- La scheda di quello che stai guardando: per un browser dipende
-- dalla finestra in primo piano, per le altre app è l'app stessa
local function currentKey()
  local bid = frontBid()
  if bid and BROWSERS[bid] then
    local w = hs.window.focusedWindow()
    local k = w and T.winKey[w:id()]
    if k then return k end
  end
  return bid
end

-- Adatta una finestra allo spazio accanto a Tabby
local function fitWindow(w, force)
  if not w or (not S.fit and not force) then return end
  if not w:isStandard() or w:isFullScreen() then return end
  local a = w:application()
  local b = a and a:bundleID()
  -- mai toccare app veloci e finestre di Hammerspoon (console, memo)
  if b and (FLOATER[b] or IGNORE[b]) then return end
  local s = w:screen()
  if not s or s:id() ~= screen():id() then return end
  w:setFrame(appArea())
end

local function fitApp(app)
  if not app then return end
  local front = hs.application.frontmostApplication()
  if front and front:pid() == app:pid() then
    -- in primo piano c'è una scheda di un gruppo: va nella sua zona
    local g = T.memberOf[currentKey()]
    if g then layoutGroup(g); return end
  end
  for _, w in ipairs(app:allWindows()) do fitWindow(w) end
end

-- Nasconde tutte le app tranne quelle in "keep"
local function hideOthers(keep)
  if not S.oneAtATime then return end
  local _, list = runningApps()
  for _, app in ipairs(list) do
    local b = app:bundleID()
    if not keep[b] and not app:isHidden() and not hasFullscreen(app) then
      app:hide()
    end
  end
end

-- Mette ogni scheda del gruppo nella sua zona e nasconde le altre app.
-- Una scheda può essere un'app intera o una singola finestra di un browser.
layoutGroup = function(g)
  local keep = {}
  for k, key in ipairs(g.members) do
    local bid = T.keyBid[key] or key
    keep[bid] = true
    local app = hs.application.get(bid)
    if app and LAYOUTS[g.layout].zones[k] then
      if app:isHidden() then app:unhide() end
      local r = zoneRect(g.layout, k)
      local w = T.keyWin[key]
      local wins = w and {w} or standardWindows(app)
      for _, x in ipairs(wins) do
        if not x:isFullScreen() and not x:isMinimized() then
          x:setFrame(r)
          if w then x:raise() end   -- davanti alle altre finestre dello stesso browser
        end
      end
    end
  end
  hideOthers(keep)
end


-- Ricostruzione "ritardata": se arrivano tanti eventi insieme, la fa una volta sola
T.rebuildTimer = hs.timer.delayed.new(0.3, function()
  refreshBrowsers()
  rebuildTabs()
  draw()
end)
local function scheduleRebuild() T.rebuildTimer:start() end

local function isTabApp(app)
  if not app then return false end
  local bid = app:bundleID()
  return bid and not IGNORE[bid] and app:kind() == 1
end

-- L'app in primo piano è a schermo intero?
local function updateFullscreen()
  local w = hs.window.focusedWindow()
  local fs = (w ~= nil) and w:isFullScreen() or false
  if fs then
    local a = w:application()
    if a and a:bundleID() then T.fsApps[a:bundleID()] = true end
  end
  if fs ~= T.fullscreen then
    T.fullscreen = fs
    draw()
  end
end

-- App veloci: piccole, in alto a destra
-- (con più finestre, es. più post-it, si dispongono a cascata)
local function placeFloater(app)
  if not app then return end
  local area = appArea()
  local wins = {}
  for _, w in ipairs(app:allWindows()) do
    if not w:isMinimized() and not w:isFullScreen() then table.insert(wins, w) end
  end
  table.sort(wins, function(a, b) return a:id() < b:id() end)
  for n, w in ipairs(wins) do
    local fr = w:frame()
    local off = (n - 1) * 26
    w:setTopLeft({x = area.x + area.w - fr.w - 12 - off, y = area.y + 12 + off})
  end
  local msg = string.format("Tabby · %s: %d finestre messe in alto a destra",
                            tostring(app:name()), #wins)
  if T.floaterDiag ~= msg then T.floaterDiag = msg; print(msg) end
end


-- ---------------------------------------------------------------------
--  PASSARE DA UNA SCHEDA ALL'ALTRA
-- ---------------------------------------------------------------------

-- Quando un'app passa in primo piano (o cambia finestra in primo piano)
local function handleActive(app)
  local bid = app and app:bundleID()
  if bid and FLOATER[bid] then
    -- app veloce: non nasconde niente, si mette in alto a destra
    placeFloater(app)
    draw()
    return
  end
  if T.desktopMode then
    -- sulla scrivania il Finder è in primo piano: va bene così
    if bid == FINDER or not isTabApp(app) then draw(); return end
    -- macOS a volte "rimbalza" su un'altra app subito dopo: la rimandiamo giù
    if T.desktopAt and hs.timer.secondsSinceEpoch() - T.desktopAt < 1.2 then
      app:hide()
      return
    end
    T.desktopMode = false
  end
  if isTabApp(app) then
    local key = currentKey()
    if key ~= T.lastKey then
      T.prevKey = T.lastKey   -- per ⌃⌥Tab (torna alla scheda di prima)
      T.lastKey = key
    end
    local g = T.memberOf[key]
    if g then
      -- scheda di un gruppo: si mostra tutto il gruppo, diviso come l'avevi messo
      g.focus = key
      layoutGroup(g)
      hs.timer.doAfter(0.6, function()
        if T.memberOf[currentKey()] == g then layoutGroup(g) end
      end)
    else
      hideOthers({[bid] = true})
      fitApp(app)
      -- alcune app creano le finestre con un attimo di ritardo
      hs.timer.doAfter(0.6, function() fitApp(app) end)
    end
  end
  draw()
end

local function afterFocus()
  hs.timer.doAfter(0.2, function()
    handleActive(hs.application.frontmostApplication())
  end)
end

local function focusBid(bid)
  T.desktopMode = false
  -- come cliccare l'icona nel Dock: apre l'app o riapre una finestra
  hs.application.launchOrFocusByBundleID(bid)
  afterFocus()
end

-- Porta davanti una finestra precisa (per le schede dei browser)
local function focusWin(e)
  T.desktopMode = false
  local app, w = e.app, e.win
  if app and app:isHidden() then app:unhide() end
  if w:isMinimized() then w:unminimize() end
  w:focus()
  afterFocus()
end

local function focusKey(key)
  local e = key and T.cand[key]
  if e and e.win then focusWin(e)
  elseif key then focusBid(T.keyBid[key] or key) end
end

local function showGroup(g)
  T.desktopMode = false
  layoutGroup(g)
  focusKey(g.focus or g.members[1])
  hs.timer.doAfter(0.35, function() layoutGroup(g); draw() end)
end

-- Passa alla scheda numero i
local function switchTo(i)
  local t = T.tabs[i]
  if not t then return end
  if t.group then showGroup(t.group)
  elseif t.win then focusWin(t)
  else focusBid(t.bid) end
end

-- Indice della scheda attiva (nil se nessuna)
local function activeIndex()
  if T.desktopMode then return nil end
  local key = currentKey()
  if not key then return nil end
  local g = T.memberOf[key]
  local bid = frontBid()
  local fallback
  for i, t in ipairs(T.tabs) do
    if g then
      if t.group == g then return i end
    elseif t.key == key then
      return i
    elseif not fallback and t.bid == bid then
      fallback = i
    end
  end
  return fallback
end

-- Scheda precedente / successiva (⌃⌥ frecce), gira in tondo
local function switchRelative(delta)
  local n = #T.tabs
  if n == 0 then return end
  local i = activeIndex() or (delta > 0 and 0 or 1)
  switchTo(((i - 1 + delta) % n) + 1)
end

-- Torna alla scheda usata prima (⌃⌥Tab)
local function toggleLastApp()
  local k = T.prevKey
  if not k then return end
  if T.cand[k] or hs.application.get(T.keyBid[k] or k) then focusKey(k) end
end


-- ---------------------------------------------------------------------
--  MEMO (⌃⌥M): un blocco note piccolo in alto a destra.
--  Si salva da solo mentre scrivi; Esc (o di nuovo ⌃⌥M) lo chiude.
-- ---------------------------------------------------------------------

local MEMO_W, MEMO_H = 340, 280

local function memoHTML(text)
  local esc = (text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return [[<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;height:100%;background:#1B1D22}
textarea{box-sizing:border-box;width:100%;height:100%;border:0;outline:0;resize:none;
padding:14px 16px;background:#1B1D22;color:#E8E9EC;font:14px/1.5 -apple-system,system-ui,sans-serif}
textarea::placeholder{color:#7D828C}
</style></head><body><textarea id="t" spellcheck="true"
placeholder="Scrivi qui… si salva da solo. Esc per chiudere.">]] .. esc .. [[</textarea>
<script>
var t = document.getElementById('t'), h;
function send(o) { try { window.webkit.messageHandlers.tabbymemo.postMessage(o) } catch (e) {} }
t.addEventListener('input', function () {
  clearTimeout(h); h = setTimeout(function () { send({text: t.value}) }, 300)
});
document.addEventListener('keydown', function (e) {
  if (e.key === 'Escape') { e.preventDefault(); send({text: t.value, close: true}) }
});
function focusEnd() { t.focus(); t.selectionStart = t.selectionEnd = t.value.length }
window.addEventListener('load', focusEnd);
</script></body></html>]]
end

local function memoRect()
  local A = appArea()
  return {x = A.x + A.w - MEMO_W - 12, y = A.y + 12, w = MEMO_W, h = MEMO_H}
end

local function backToPrev()
  local prev = T.memoPrev and hs.application.get(T.memoPrev)
  if prev then prev:activate() end
end

-- Il testo del Memo sta in un file vero (MEMO_FILE, in Documenti)
local function readMemo()
  local f = io.open(MEMO_FILE, "r")
  if f then
    local txt = f:read("a") or ""
    f:close()
    return txt
  end
  -- primo avvio: recupera quello scritto nel vecchio Memo (se c'è)
  return hs.settings.get("tabbar.memo") or ""
end

local function writeMemo(txt)
  local f = io.open(MEMO_FILE, "w")
  if f then
    f:write(txt)
    f:close()
  else
    print("Tabby · Memo: impossibile salvare in " .. MEMO_FILE)
  end
end

local closeMemo

local function ensureMemo()
  if T.memo then return T.memo end
  T.memoUCC = hs.webview.usercontent.new("tabbymemo")
  T.memoUCC:setCallback(function(msg)
    local b = msg and msg.body
    if type(b) == "table" then
      if b.text ~= nil then writeMemo(b.text) end
      if b.close then closeMemo() end
    end
  end)
  T.memo = hs.webview.new(memoRect(), {developerExtrasEnabled = false}, T.memoUCC)
  T.memo:windowStyle({"titled", "closable"})
  T.memo:windowTitle("Memo")
  T.memo:allowTextEntry(true)
  T.memo:deleteOnClose(false)
  T.memo:level(hs.canvas.windowLevels.floating)
  T.memo:behaviorAsLabels({"canJoinAllSpaces", "fullScreenAuxiliary"})
  T.memo:windowCallback(function(action)
    if action == "closing" and T.memoOpen then
      T.memoOpen = false
      backToPrev()
    end
  end)
  return T.memo
end

local function openMemo()
  local fb = frontBid()
  if fb and not IGNORE[fb] then T.memoPrev = fb end
  local m = ensureMemo()
  -- ricarica sempre dal file: così vedi anche le modifiche fatte con TextEdit
  m:html(memoHTML(readMemo()))
  m:frame(memoRect())
  m:show()
  hs.focus()
  local w = m:hswindow()
  if w then w:focus() end
  m:evaluateJavaScript("typeof focusEnd === 'function' && focusEnd()")
  T.memoOpen = true
end

closeMemo = function()
  if not T.memo or not T.memoOpen then return end
  T.memoOpen = false
  T.memo:evaluateJavaScript("send({text: t.value})")   -- salva l'ultima cosa scritta
  T.memo:hide()
  backToPrev()
end

local function toggleMemo()
  if T.memoOpen then closeMemo() else openMemo() end
end

-- Apre / chiude un'azione veloce (stessa scorciatoia)
local function toggleQuick(q)
  if q.memo then toggleMemo(); return end
  local bid = q.bid
  local app = hs.application.get(bid)
  if app and frontBid() == bid then
    app:hide()   -- torni all'app di prima
    return
  end
  hs.application.launchOrFocusByBundleID(bid)
  -- l'app può metterci un po' ad aprire le finestre: riprova più volte
  for _, delay in ipairs({0.3, 0.8, 1.6}) do
    hs.timer.doAfter(delay, function() placeFloater(hs.application.get(bid)) end)
  end
end

local function openSpotlight()
  hs.timer.doAfter(0.15, function() hs.eventtap.keyStroke({"cmd"}, "space", 0) end)
end

-- Scrivania: nasconde tutto. Ripremendo, torna all'ultima scheda.
local function toggleDesktop()
  if T.desktopMode then
    if T.lastKey then focusKey(T.lastKey) else T.desktopMode = false; draw() end
    return
  end
  T.desktopMode = true
  T.desktopAt = hs.timer.secondsSinceEpoch()
  local _, list = runningApps()
  for _, app in ipairs(list) do
    if app:bundleID() ~= FINDER and not hasFullscreen(app) then app:hide() end
  end
  -- Il Finder resta in primo piano (è lui la scrivania): NON lo nascondiamo,
  -- altrimenti macOS riattiva un'altra app. Riduciamo nel Dock le sue finestre.
  local f = hs.application.get(FINDER)
  if f then
    f:activate()
    hs.timer.doAfter(0.2, function()
      if not T.desktopMode then return end
      for _, w in ipairs(standardWindows(f)) do
        if not w:isMinimized() then w:minimize() end
      end
      draw()
    end)
  end
  draw()
end


-- ---------------------------------------------------------------------
--  GRUPPI: CREARE E SCOMPORRE
-- ---------------------------------------------------------------------

-- zones = {[numero zona] = chiave della scheda}, nz = quante zone ha lo schema
local function createGroup(layoutId, zones, nz)
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

-- "Scomponi": le schede tornano singole, ognuna a tutto spazio
local function ungroup(g)
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

local exitSplit, finishSplit, drawSplit

local function zoneCount(sp) return #LAYOUTS[sp.layout].zones end

local function zoneAt(p)
  local sp = T.split
  if not sp then return nil end
  for k = 1, zoneCount(sp) do
    local r = zoneRect(sp.layout, k)
    if p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h then return k end
  end
  return nil
end

local function onOverlayMouse(_, msg, id)
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

local function button(els, r, label, fill, id)
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
      table.insert(els, {type = "text", text = e and e.name or appName(bid, hs.application.get(bid)),
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

local function enterSplit(layoutId)
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

local function assignToZone(k, i)
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
local function assignFirstEmpty(i)
  local sp = T.split
  if not sp then return end
  for k = 1, zoneCount(sp) do
    if not sp.zones[k] then assignToZone(k, i); return end
  end
end

-- Piccola anteprima dello schema, per il menu
local function layoutImage(id)
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


-- ---------------------------------------------------------------------
--  TRASCINARE LE SCHEDE
--  Fuori dalla divisione: riordina le schede.
--  Durante la divisione: porta l'app nella zona dove la lasci.
-- ---------------------------------------------------------------------

local function ghostStart(t, p)
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
local function dropSlot(p)
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

local function reorderTab(i, pos)
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

local function startPress(i)
  local p = hs.mouse.absolutePosition()
  T.press = {i = i, x = p.x, y = p.y, dragging = false}
  T.dragTap:start()
end

local function onDragMove(p)
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
  else
    local _, marker = dropSlot(p)
    local mk = marker and (marker.x .. ":" .. marker.y) or nil
    if mk ~= T.dropKey then
      T.dropKey, T.dropMarker = mk, marker
      draw()
    end
  end
end

local function onDragEnd(p)
  T.dragTap:stop()
  local pr = T.press
  T.press = nil
  if T.ghost then T.ghost:hide() end
  if pr and pr.dragging then
    if T.split then
      local k = zoneAt(p)
      T.split.hover = nil
      if k then assignToZone(k, pr.i) else drawSplit() end
    else
      local pos = dropSlot(p)
      T.dropKey, T.dropMarker = nil, nil
      if pos then reorderTab(pr.i, pos) else draw() end
    end
  end
  hs.timer.doAfter(0.25, function() T.suppressClick = false end)
end

local ET = hs.eventtap.event.types
T.dragTap = hs.eventtap.new({ET.leftMouseDragged, ET.leftMouseUp}, function(e)
  local p = hs.mouse.absolutePosition()
  if e:getType() == ET.leftMouseUp then
    later(function() onDragEnd(p) end)
  else
    onDragMove(p)
  end
  return false
end)


-- ---------------------------------------------------------------------
--  MENU DELLA ✕  (chiudi finestra / chiudi app)
-- ---------------------------------------------------------------------

local function shorten(s, n)
  if not s or s == "" then return nil end
  -- conta le lettere, non i byte (così non spezza lettere accentate o emoji)
  local len = utf8.len(s)
  if len and len > n then return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…" end
  return s
end

local function popup(items, pos)
  if not T.menu then T.menu = hs.menubar.new(false) end
  T.menu:setMenu(items)
  T.menu:popupMenu(pos, true)
end

local function openCloseMenu(i)
  local t = T.tabs[i]
  if not t or not t.app then return end
  local app  = t.app
  local wins = standardWindows(app)
  -- per una scheda-finestra (browser) si chiude proprio quella finestra
  local main = t.win or app:mainWindow() or app:focusedWindow() or wins[1]

  local items = {}
  if main then
    local title = shorten(main:title(), 40)
    table.insert(items, {
      title = title and ("Chiudi finestra  “" .. title .. "”") or "Chiudi finestra",
      fn = function() main:close(); scheduleRebuild() end,
    })
  end
  if t.bid == FINDER then
    table.insert(items, {title = "Il Finder non si può chiudere", disabled = true})
  else
    table.insert(items, {
      title = "Chiudi " .. appName(t.bid, app),   -- l'app intera (es. Chrome, non Gmail)
      fn = function() app:kill(); scheduleRebuild() end,
    })
  end
  popup(items, T.closePos[i])
end


-- ---------------------------------------------------------------------
--  MENU IMPOSTAZIONI  (il tasto ⚙︎)
-- ---------------------------------------------------------------------

local function togglePinned(bid)
  local new, found = {}, false
  for _, b in ipairs(S.pinned) do
    if b == bid then found = true else table.insert(new, b) end
  end
  if not found then table.insert(new, bid) end
  S.pinned = new
  save("pinned")
  rebuildTabs()
  draw()
end

local function addAppDialog()
  hs.focus()
  local res = hs.dialog.chooseFileOrFolder("Scegli un'app da aggiungere ai preferiti",
    "/Applications", true, false, true, {"app"}, true)
  if not res then return end
  for _, path in pairs(res) do
    local info = hs.application.infoForBundlePath(path)
    local bid = info and info.CFBundleIdentifier
    if bid and not isPinned(bid) then togglePinned(bid) end
  end
end

local function closeAllApps()
  hs.focus()
  local btn = hs.dialog.blockAlert("Chiudere tutte le app?",
    "Le app con documenti non salvati ti chiederanno cosa fare.",
    "Chiudi tutte", "Annulla")
  if btn ~= "Chiudi tutte" then return end
  local _, list = runningApps()
  for _, app in ipairs(list) do
    if app:bundleID() == FINDER then
      for _, w in ipairs(standardWindows(app)) do w:close() end
    else
      app:kill()
    end
  end
  scheduleRebuild()
end

local function favoritesMenu()
  local items = {}
  local map, list = runningApps()
  local bids, seen = {}, {}
  for _, b in ipairs(S.pinned) do
    if not seen[b] then table.insert(bids, b); seen[b] = true end
  end
  for _, a in ipairs(list) do
    local b = a:bundleID()
    if not seen[b] then table.insert(bids, b); seen[b] = true end
  end
  for _, b in ipairs(bids) do
    table.insert(items, {
      title   = appName(b, map[b]),
      image   = smallIcon(b),
      checked = isPinned(b),
      fn      = function() togglePinned(b) end,
    })
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Aggiungi un'altra app…", fn = addAppDialog})
  return items
end

local function toggle(key, after)
  return function()
    S[key] = not S[key]
    save(key)
    if after then after() end
    draw()
  end
end

local function refit()
  local f = hs.application.frontmostApplication()
  local g = f and T.memberOf[f:bundleID()]
  if g then layoutGroup(g) else fitApp(f) end
end

local function behaviourMenu()
  return {
    {title = "Una app alla volta", checked = S.oneAtATime, fn = toggle("oneAtATime")},
    {title = "Adatta le finestre a Tabby", checked = S.fit, fn = toggle("fit", refit)},
    {title = "Schermo intero con Tabby visibile (tasto verde)", checked = S.tabbyFullscreen,
     fn = toggle("tabbyFullscreen")},
    {title = "Nascondi Tabby (appare col mouse sul bordo)", checked = S.autohide,
     fn = toggle("autohide", function() T.revealed = false; refit() end)},
    {title = "Mostra anche app aperte senza finestre", checked = S.showWindowless,
     fn = toggle("showWindowless", rebuildTabs)},
  }
end

local POSITIONS = {
  {"top", "In alto"}, {"bottom", "In basso"}, {"left", "A sinistra"}, {"right", "A destra"},
}

local function positionMenu()
  local items = {}
  for _, p in ipairs(POSITIONS) do
    table.insert(items, {
      title   = p[2],
      checked = (S.position == p[1]),
      fn      = function()
        S.position = p[1]
        save("position")
        T.revealed = false
        draw()
        refit()
      end,
    })
  end
  -- fascia del notch: scelta manuale, se il rilevamento automatico sbaglia
  table.insert(items, {title = "-"})
  table.insert(items, {
    title    = "Usa la fascia del notch (in alto)",
    checked  = useNotchBand(),
    disabled = (S.position ~= "top"),
    fn       = function()
      S.notchBand = useNotchBand() and "off" or "on"
      save("notchBand")
      draw(); refit(); logDiagnostics()
    end,
  })
  if S.notchBand ~= "auto" then
    table.insert(items, {title = "Fascia del notch: torna automatico", fn = function()
      S.notchBand = "auto"; save("notchBand"); draw(); refit(); logDiagnostics()
    end})
  end
  return items
end

-- Dove far comparire un menu aperto da un elemento di Tabby
local function popPos(r)
  local bf, p = T.bf, S.position
  if p == "bottom" then return {x = bf.x + r.x, y = bf.y + r.y - 4} end
  if p == "left"   then return {x = bf.x + r.x + r.w, y = bf.y + r.y} end
  if p == "right"  then return {x = bf.x + r.x - 240, y = bf.y + r.y} end
  return {x = bf.x + r.x, y = bf.y + r.y + r.h}
end

local function openSettings()
  popup({
    {title = "Posizione di Tabby", menu = positionMenu()},
    {title = "App preferite", menu = favoritesMenu()},
    {title = "Comportamento", menu = behaviourMenu()},
    {title = "-"},
    {title = "Chiudi tutte le app…", fn = closeAllApps},
    {title = "-"},
    {title = "Ricarica Tabby", fn = function() hs.reload() end},
    {title = "Apri la console di Hammerspoon", fn = function() hs.openConsole() end},
  }, popPos(T.L.settings))
end

-- Menu del tasto ⚡︎ (app veloci)
local function openQuick()
  local items = {}
  for _, q in ipairs(QUICK) do
    table.insert(items, {
      title = q.name .. "   ⌃⌥" .. q.key:upper(),
      image = smallIcon(q.bid or "com.apple.TextEdit"),
      checked = (q.memo and T.memoOpen) or nil,
      fn    = function() toggleQuick(q) end,
    })
  end
  table.insert(items, {title = "Spotlight   ⌘Spazio", fn = openSpotlight})
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Mostra il file del Memo nel Finder", fn = function()
    local f = io.open(MEMO_FILE, "r")
    if f then f:close() else writeMemo(readMemo()) end
    hs.execute('open -R "' .. MEMO_FILE .. '"')
  end})
  popup(items, popPos(T.L.quick))
end

-- Menu del tasto ⊞ (dividi lo schermo)
local function openSplitMenu()
  if T.split then exitSplit(); return end
  local items = {}
  for _, id in ipairs(LAYOUT_ORDER) do
    table.insert(items, {title = LAYOUTS[id].name, image = layoutImage(id),
                         fn = function() enterSplit(id) end})
  end
  local ai = activeIndex()
  local t = ai and T.tabs[ai]
  if t and t.group then
    table.insert(items, {title = "-"})
    table.insert(items, {title = "Scomponi il gruppo attuale", fn = function() ungroup(t.group) end})
  end
  popup(items, popPos(T.L.split))
end

-- Menu "+N": le schede che non ci stanno
local function openOverflow()
  if not T.L or not T.L.overflow then return end
  local items = {}
  for _, i in ipairs(T.L.overflow) do
    local t = T.tabs[i]
    if t then
      local b = badgeFor(t)
      table.insert(items, {
        title = t.name .. (b and ("   (" .. b .. ")") or ""),
        image = keySmallIcon(t.group and t.group.members[1] or t.key),
        fn    = function() switchTo(i) end,
      })
    end
  end
  popup(items, popPos(T.L.more))
end


-- ---------------------------------------------------------------------
--  DISEGNO DI TABBY
-- ---------------------------------------------------------------------

local function onMouse(_, msg, id)
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
  local c = tonumber(id:match("^close(%d+)$"))
  if c then openCloseMenu(c); return end
  local u = tonumber(id:match("^ungroup(%d+)$"))
  if u then
    local t = T.tabs[u]
    if t and t.group then ungroup(t.group) end
    return
  end
  if ti then
    if T.split then assignFirstEmpty(ti) else switchTo(ti) end
  end
end

local function setVisible(v)
  if v == T.visible then return end
  T.visible = v
  if v then T.bar:show(0.12) else T.bar:hide(0.12) end
end

local function hitArea(id, frame, withDown)
  return {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
          trackMouseUp = true, trackMouseDown = withDown or nil, id = id, frame = frame}
end

local function divider(r)
  return {type = "rectangle", action = "fill", fillColor = COL.divider, frame = r}
end

-- Le prime "cap" schede, assicurandosi che quella attiva ci sia sempre
local function pickVisible(n, cap, activeIdx)
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

local function hasBattery() return hs.battery.percentage() ~= nil end

-- Dove va ogni pezzo di Tabby (orizzontale o verticale).
-- Con tante app: prima le schede si stringono, poi diventano solo icona
-- (tranne quella attiva), infine le ultime finiscono nel menu "+N".
local function layout(bf, activeIdx)
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
    local availH = bottomY - batH - 6 - start
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
      if #over > 0 then
        L.more = {x = 0, y = start + #vis * rowH, w = w, h = MIN_ROW_H}
        L.overflow = over
      end
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
    local avail = w - BTN_W - rightW - 12
    -- notch: le schede ci saltano sopra
    local nz = notchZone(bf)
    if nz then avail = avail - (nz.x2 - nz.x1) end
    local function place(x, ww)
      if nz and x < nz.x2 and x + ww > nz.x1 then return nz.x2 end
      return x
    end
    L.notch = nz

    -- quante schede larghe "tw" ci stanno davvero (a sinistra e a destra del notch)
    local endX = w - rightW - 6
    local function fits(tw)
      if not nz then return math.floor((endX - start) / tw) end
      return math.max(0, math.floor((nz.x1 - start) / tw))
           + math.max(0, math.floor((endX - nz.x2) / tw))
    end

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
        end
      end
    end
  end
  return L
end

-- Indicatore batteria: verde da 80% in su, normale fino al 35%,
-- rosso sotto il 35% (se non è in carica). ⚡︎ = in carica.
local function drawBattery(els, r)
  local pct = hs.battery.percentage()
  if not pct then return end
  pct = math.floor(pct + 0.5)
  local charging = hs.battery.isCharging() or hs.battery.powerSource() == "AC Power"
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

local function centeredGlyph(text, size, r, color)
  return {type = "text", text = text, textSize = size, textColor = color or COL.textDim,
          textAlignment = "center",
          frame = {x = r.x, y = r.y + r.h / 2 - size * 0.65, w = r.w, h = size * 1.4}}
end

local function activeBg(els, r, vertical)
  table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.active,
    roundedRectRadii = {xRadius = 7, yRadius = 7},
    frame = vertical and {x = r.x + 6, y = r.y + 2, w = r.w - 12, h = r.h - 4}
                      or {x = r.x + 2, y = r.y + 4, w = r.w - 4, h = r.h - 8}})
end

-- Mette Tabby dove deve stare. Sui Mac col notch macOS spinge giù le finestre
-- "normali" dalla fascia del notch: se succede, Tabby sale di livello
-- finché macOS la lascia stare in cima (e controlla di esserci riuscita).
local LEVEL_STEPS = {"floating", "dock", "mainMenu", "status", "popUpMenu"}

local function placeBar(bf)
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

  -- tasto scrivania (icona di uno schermo)
  local r = L.desk
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  if T.desktopMode then
    table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.active,
      roundedRectRadii = {xRadius = 7, yRadius = 7},
      frame = {x = r.x + 4, y = r.y + 4, w = r.w - 8, h = r.h - 8}})
  end
  local deskCol = T.desktopMode and COL.text or COL.textDim
  table.insert(els, {type = "rectangle", action = "stroke", strokeColor = deskCol,
    strokeWidth = 1.5, roundedRectRadii = {xRadius = 2, yRadius = 2},
    frame = {x = cx - 9, y = cy - 8, w = 18, h = 12}})
  table.insert(els, {type = "rectangle", action = "fill", fillColor = deskCol,
    frame = {x = cx - 5, y = cy + 6, w = 10, h = 1.5}})
  table.insert(els, hitArea("desktop", r))

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
      local img = keyIcon(g and (g.focus or g.members[1]) or t.key)
      local cx = tr.x + tr.w / 2
      if img then
        table.insert(els, {type = "image", image = img,
          frame = {x = cx - 10, y = my - 10, w = 20, h = 20}})
      end
      if badge then
        table.insert(els, {type = "circle", action = "fill", fillColor = COL.badge,
          center = {x = cx + 10, y = my - 9}, radius = 4.5})
      elseif g then
        table.insert(els, {type = "rectangle", action = "fill", fillColor = COL.accent,
          roundedRectRadii = {xRadius = 6, yRadius = 6},
          frame = {x = cx + 4, y = my - 14, w = 12, h = 12}})
        table.insert(els, {type = "text", text = tostring(#g.members), textSize = 8,
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
      if g then
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
        frame = {x = textX, y = my - 9, w = closeX - badgeW - textX - 2, h = 18}})

      local btnR = {x = closeX - 2, y = my - 11, w = closeW + 4, h = 22}
      if g then
        -- tasto "Scomponi": due riquadri separati
        table.insert(els, {type = "rectangle", action = "stroke", strokeColor = COL.textMid,
          strokeWidth = 1.2, roundedRectRadii = {xRadius = 1.5, yRadius = 1.5},
          frame = {x = closeX + 4, y = my - 6, w = 6, h = 12}})
        table.insert(els, {type = "rectangle", action = "stroke", strokeColor = COL.textMid,
          strokeWidth = 1.2, roundedRectRadii = {xRadius = 1.5, yRadius = 1.5},
          frame = {x = closeX + 13, y = my - 6, w = 6, h = 12}})
        table.insert(els, hitArea("tab" .. i, tr, true))
        table.insert(els, hitArea("ungroup" .. i, btnR))
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


-- ---------------------------------------------------------------------
--  "NASCONDI TABBY": APPARE PORTANDO IL MOUSE SUL BORDO DELLO SCHERMO
-- ---------------------------------------------------------------------

T.mouseTimer = hs.timer.doEvery(0.08, function()
  if not T.bar then return end
  if T.press or T.split then return end   -- mentre trascini o dividi, resta visibile

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


-- ---------------------------------------------------------------------
--  OSSERVATORI
-- ---------------------------------------------------------------------

local W = hs.application.watcher
T.appWatcher = W.new(function(_, event, app)
  if event == W.activated then
    hs.timer.doAfter(0.1, function() handleActive(app) end)
    hs.timer.doAfter(0.9, updateFullscreen)
  elseif event == W.launched then
    scheduleRebuild()
  elseif event == W.terminated then
    local still = {}
    for b in pairs(T.fsApps) do
      if hs.application.get(b) then still[b] = true end
    end
    T.fsApps = still
    scheduleRebuild()
  end
end)
T.appWatcher:start()

-- Osserva tutte le finestre "normali" di tutte le app
local WF = hs.window.filter
T.allWins = WF.new(false):setDefaultFilter({})

T.allWins:subscribe(WF.windowCreated, function(w)
  local a = w and w:application()
  local b = a and a:bundleID()
  -- (per i browser ogni finestra nuova è una scheda nuova, non entra nel gruppo)
  local g = b and not BROWSERS[b] and T.memberOf[b]
  if b and FLOATER[b] then
    placeFloater(a)
  elseif g then
    -- nuova finestra di un'app in un gruppo: nella sua zona (se il gruppo è attivo)
    hs.timer.doAfter(0.2, function()
      if T.memberOf[currentKey()] == g then layoutGroup(g) end
    end)
  elseif a and b == frontBid() then
    fitWindow(w)
  end
  scheduleRebuild()
end)

T.allWins:subscribe(WF.windowDestroyed, function() scheduleRebuild() end)

-- Cambio di finestra dentro la stessa app (es. da Chrome A a Chrome B,
-- o da una webapp all'altra con ⌘`): aggiorna la scheda attiva
T.focusTimer = hs.timer.delayed.new(0.15, function()
  local f = hs.application.frontmostApplication()
  if f and BROWSERS[f:bundleID()] then handleActive(f) else draw() end
end)
T.allWins:subscribe(WF.windowFocused, function() T.focusTimer:start() end)

-- Browser: titoli e siti cambiano mentre navighi → ricontrolla ogni 3 secondi
T.browserTimer = hs.timer.doEvery(3, function()
  if T.press or T.split then return end
  if refreshBrowsers() then rebuildTabs(); draw() end
end)

-- Notifiche: ricontrolla i numerini del Dock ogni 3 secondi
local function badgeSig(b)
  local parts = {}
  for k, v in pairs(b) do table.insert(parts, k .. "=" .. v) end
  table.sort(parts)
  return table.concat(parts, ",")
end
T.badgeTimer = hs.timer.doEvery(3, function()
  local b = readDockBadges()
  local sig = badgeSig(b)
  if sig ~= T.badgeSig then
    T.badges, T.badgeSig = b, sig
    if T.bar then draw() end
  end
end)

T.allWins:subscribe(WF.windowFullscreened, function(w)
  if S.tabbyFullscreen and w then
    -- tasto verde: invece dello schermo intero di macOS, riempi lo
    -- spazio accanto a Tabby (o la zona, se l'app è in un gruppo)
    hs.timer.doAfter(0.3, function()
      w:setFullScreen(false)
      hs.timer.doAfter(0.9, function()
        local a = w:application()
        local g = a and T.memberOf[T.winKey[w:id()] or a:bundleID()]
        if g then layoutGroup(g) else fitWindow(w, true) end
        w:focus()
        updateFullscreen()
      end)
    end)
  else
    hs.timer.doAfter(0.8, updateFullscreen)
  end
end)

T.allWins:subscribe(WF.windowUnfullscreened, function(w)
  local a = w and w:application()
  if a and a:bundleID() then T.fsApps[a:bundleID()] = nil end
  hs.timer.doAfter(0.8, updateFullscreen)
end)

-- Cambio di scrivania (le app a schermo intero hanno la loro)
T.spaceWatcher = hs.spaces.watcher.new(function()
  hs.timer.doAfter(0.5, updateFullscreen)
end)
T.spaceWatcher:start()

-- Cambio di monitor o risoluzione
T.screenWatcher = hs.screen.watcher.new(function()
  T.notch = detectNotch()
  draw()
  if T.split then drawSplit() end
end)
T.screenWatcher:start()

-- Se cambi l'impostazione "nascondi la barra dei menu", Tabby si adegua
T.menuWatch = hs.timer.doEvery(10, function()
  local v = detectMenuHidden()
  if v ~= T.menuHidden then
    T.menuHidden = v
    draw()
    refit()
  end
end)

-- Batteria: ridisegna quando cambia carica o alimentazione
T.batWatcher = hs.battery.watcher.new(function() if T.bar then draw() end end)
T.batWatcher:start()


-- ---------------------------------------------------------------------
--  SCORCIATOIE  (tutte con ⌃⌥ = Ctrl + Option, vedi MODS in cima)
--  Doppio meccanismo, perché alcune app (es. Windows App, desktop remoto)
--  si "prendono" la tastiera:
--   1) un intercettatore che le vede prima dell'app in primo piano;
--   2) le scorciatoie di sistema di macOS, come riserva.
--  Se arrivano da entrambi, l'azione parte una volta sola.
-- ---------------------------------------------------------------------

local K = hs.keycodes.map

-- Se la stessa scorciatoia arriva quasi insieme dai DUE meccanismi, conta una volta
-- (due pressioni vere e veloci dallo stesso meccanismo invece valgono due)
local function fire(id, fn, src)
  local now, last = hs.timer.secondsSinceEpoch(), T.lastFire[id]
  if last and last.src ~= src and now - last.t < 0.3 then return end
  T.lastFire[id] = {t = now, src = src}
  fn()
end

-- Elenco delle scorciatoie: tasto (insieme a ⌃⌥) → azione
local SHORTCUTS = {}
local function shortcut(key, id, fn, onlyIf)
  table.insert(SHORTCUTS, {key = key, id = id, fn = fn, onlyIf = onlyIf})
end
for i = 1, 9 do shortcut(tostring(i), "tab" .. i, function() switchTo(i) end) end
shortcut("0", "desktop", toggleDesktop)
shortcut("left",  "prev", function() switchRelative(-1) end)
shortcut("right", "next", function() switchRelative(1) end)
shortcut("up",    "prev", function() switchRelative(-1) end, isVertical)
shortcut("down",  "next", function() switchRelative(1) end, isVertical)
shortcut("tab",   "last", toggleLastApp)
for _, q in ipairs(QUICK) do
  shortcut(q.key, "quick-" .. q.key, function() toggleQuick(q) end)
end

local WANT = {}
for _, m in ipairs(MODS) do WANT[m] = true end
local function modsMatch(f)
  for _, m in ipairs({"ctrl", "alt", "cmd", "shift"}) do
    if (f[m] and true or false) ~= (WANT[m] or false) then return false end
  end
  return true
end

T.keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(e)
  local f    = e:getFlags()
  local code = e:getKeyCode()
  local noMods = not (f.ctrl or f.alt or f.cmd or f.shift)

  -- Durante la divisione: Invio = fatto, Esc = annulla
  if T.split and noMods then
    if code == K.escape then later(exitSplit); return true end
    if code == K["return"] or code == K.padenter then later(finishSplit); return true end
  end

  -- Esc chiude il Memo o un'app veloce (es. la Calcolatrice) se è in primo piano
  if code == K.escape and noMods then
    local front = hs.application.frontmostApplication()
    local fb = front and front:bundleID()
    if T.memoOpen and fb == "org.hammerspoon.Hammerspoon" then
      later(closeMemo); return true
    end
    if fb and FLOATER[fb] then
      later(function() front:hide() end); return true
    end
  end

  -- ⌃⌥ + tasto = scorciatoie di Tabby
  if modsMatch(f) then
    local name = K[code]
    for _, sc in ipairs(SHORTCUTS) do
      if sc.key == name and (not sc.onlyIf or sc.onlyIf()) then
        later(function() fire(sc.id, sc.fn, "tap") end)
        return true   -- l'app in primo piano non riceve il tasto
      end
    end
  end
  return false
end)
T.keyTap:start()

-- macOS a volte spegne gli intercettatori di tasti: li riaccendiamo
T.keyTapGuard = hs.timer.doEvery(5, function()
  if not T.keyTap:isEnabled() then T.keyTap:start() end
end)

-- Riserva: le stesse scorciatoie registrate anche come scorciatoie di sistema
for _, sc in ipairs(SHORTCUTS) do
  if not sc.onlyIf then
    local ok, hk = pcall(hs.hotkey.bind, MODS, sc.key, function() fire(sc.id, sc.fn, "hotkey") end)
    if ok and hk then table.insert(T.hotkeys, hk) end
  end
end

-- Ctrl+Alt+Cmd+R: ricarica Tabby dopo una modifica
table.insert(T.hotkeys, hs.hotkey.bind({"ctrl", "alt", "cmd"}, "R", function() hs.reload() end))


-- ---------------------------------------------------------------------
--  AVVIO
-- ---------------------------------------------------------------------
menuBarH()
T.notch = detectNotch()
T.menuHidden = detectMenuHidden()
logDiagnostics()
updateFullscreen()
refreshBrowsers()
T.badges = readDockBadges()
T.badgeSig = badgeSig(T.badges)
rebuildTabs()
draw()
handleActive(hs.application.frontmostApplication())
hs.alert.show("Tabby v9.3 attiva")
