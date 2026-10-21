-- =====================================================================
--  TABBY  ·  v9.10
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
--  v9.4: revisione: le viste divise seguono le finestre dei browser (non si
--      sciolgono se una webapp cambia sito); stesso sito in due browser = due
--      schede; loghi ritentati senza internet; spia "Tabby · lento" in console.
--  v9.5 (v1 · A): una scheda per ogni finestra di qualsiasi app, col titolo
--      della finestra (niente più "Chrome A / B"); ⚙︎ → Finestre separate per
--      app; app cercate per bundle ID (via un blocco di ~200 ms ogni 3 s);
--      privacy: di DuckDuckGo si tiene e si scrive solo il sito, non l'indirizzo.
--  v9.6: Chrome & co.: webapp riconosciute anche con più profili (titolo con
--      il profilo in fondo) o titolo diverso (abbinate per posizione); logo
--      anche dal sito stesso; diagnosi in console (abbinamento, permesso, logo).
--  v9.7: Chrome/Safari: corretto lo script (dentro il browser "tab" è la
--      scheda, non la tabulazione: le webapp non venivano mai riconosciute);
--      la domanda al browser parte in parallelo (via ~200 ms di blocco ogni 3 s).
--  v9.8 (v1 · B): CARTELLE, spazi di lavoro salvati (app e webapp). Si creano
--      e attivano dal menu ⚡︎ (o ⌃⌥⇧ + numero); attivata = una scheda sola con
--      le icone; cliccata = vista cartella (solo le sue schede, ← per tornare).
--  v9.9: Chrome: le webapp non "lampeggiano" più (memoria per finestra mentre
--      la risposta del browser è in arrivo); diagnosi delle finestre nuove dei
--      browser; diagnosi DuckDuckGo solo quando cambia sito o schede.
--  v9.10: Google Meet: il video in miniatura (finestrella del browser) non è
--      una scheda, non si ridimensiona e resta visibile; abbinamento prima per
--      posizione; webapp "Meet"; console: permesso negato ≠ browser occupato.
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
  joinWins        = {},      -- app con tutte le finestre in una sola scheda
  folders         = {},      -- cartelle: {id, name, items = {{bid, site, name}}}
  folderSeq       = 0,
  activeFolders   = {},      -- cartelle attivate (sulla barra come scheda unica)
  folderView      = true,    -- ⚙︎ → Comportamento → Vista cartelle
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
          badges = {}, favicons = {}, binfo = {}, lastFire = {},
          tabFolder = {}, allTabs = {}, folderStart = {}, folderLast = {} }
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

-- Ogni finestra dell'app è una scheda? Sì, salvo le app scelte in
-- ⚙︎ → Finestre separate (i browser sono sempre a finestre separate)
local function perWindow(bid)
  return not S.joinWins[bid] and not FLOATER[bid]
end

-- L'app aperta con questo bundle ID (nil se non è aperta). Molto più veloce
-- di hs.application.get, che per un'app chiusa la cerca anche per nome
-- (30-50 ms ogni volta: misurato sul Mac vero).
local function appFor(bid)
  if not bid then return nil end
  return hs.application.applicationsForBundleID(bid)[1]
end

local function screen() return hs.screen.primaryScreen() end

local function later(fn) hs.timer.doAfter(0, fn) end

-- Spia di lentezza: Tabby fa tutto su un solo "filo", quindi un lavoro lento
-- fa scattare anche la tastiera. Se un lavoro supera SLOW_MS lo scrive in
-- console ("Tabby · lento: …"), al massimo una volta al minuto per lavoro.
local SLOW_MS = 150
local function timed(name, fn)
  return function(...)
    local t0 = hs.timer.absoluteTime()
    fn(...)
    local ms = (hs.timer.absoluteTime() - t0) / 1e6
    if ms > SLOW_MS then
      T.slowAt = T.slowAt or {}
      local now = hs.timer.secondsSinceEpoch()
      if not T.slowAt[name] or now - T.slowAt[name] > 60 then
        T.slowAt[name] = now
        print(string.format("Tabby · lento: %s %.0f ms", name, ms))
      end
    end
  end
end

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

-- Attenzione: dentro "tell application" la parola tab è la SCHEDA del
-- browser, non il carattere di tabulazione ("a" & tab & "b" dà "atabb").
-- Per questo i separatori si preparano prima, fuori dal tell (TB e NL).
local AS_WINDOWS = [[
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
local function domainsOf(urls)
  local out = {}
  for _, u in ipairs(urls or {}) do
    table.insert(out, u:match("^%a+://([^/:%?#]+)") or u:match("^(%a+:)") or "?")
  end
  return table.concat(out, ",")
end

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
  -- privacy: dell'indirizzo teniamo solo il sito (https://dominio/). Il resto
  -- può contenere dati personali o "gettoni" di accesso (es. dopo un login).
  if res.url then
    local origin = res.url:match("^(%a+://[^/%?#]+)")
    res.url = origin and (origin .. "/") or nil
  end
  return res
end

local function axBrowserInfo(app, short)
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
local onBrowserAnswer   -- definita più sotto
T.asJobs, T.asOut = {}, {}
local function askBrowser(bid, B)
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
local function refreshBrowsers(ask)
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
local function titleBadge(title)
  if not title then return nil end
  return title:match("^%((%d+)%)") or title:match("^[^%-|]-%((%d+)%)%s")
end

-- Logo del sito (scaricato una volta e ricordato). Prova più fonti:
-- servizio loghi di DuckDuckGo (dominio, poi dominio principale), poi Google.
-- Se falliscono tutte (es. Wi-Fi non ancora connesso) si riprova dopo un minuto.
local FAVICON_RETRY = 60
local function favicon(domain)
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

-- Nome di una finestra-scheda: il suo titolo (nome del documento, della
-- cartella del Finder, della pagina…), senza il nome dell'app in fondo
-- ("Relazione — TextEdit" → "Relazione").
local function windowName(title, appTitle)
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
local function windowTabs(app, b, wins, add, appTitle, titles)
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

-- Abbina le finestre sullo schermo a quelle descritte dal browser, in tre
-- passaggi: 1) stessa posizione e misura (la più sicura, se la risposta è
-- fresca); 2) stesso titolo; 3) il titolo sullo schermo inizia con quello del
-- browser (Chrome con più profili aggiunge il nome del profilo: "Gmail - Lavoro").
-- Una finestra piccola si abbina solo per posizione: il video in miniatura di
-- Meet ha lo stesso titolo della pagina e "ruberebbe" l'abbinamento.
local function matchBrowserWindows(wins, info)
  local found, how, used = {}, {}, {}
  local A = appArea()
  local function small(w)
    local f = w:frame()
    return f.w < A.w * 0.5 and f.h < A.h * 0.6
  end
  local function pass(label, test, bigOnly)
    for i, w in ipairs(wins) do
      if not found[i] and not (bigOnly and small(w)) then
        for k, e in ipairs(info or {}) do
          if not used[k] and test(w, e) then
            used[k], found[i], how[i] = true, e, label
            break
          end
        end
      end
    end
  end
  pass("posizione", function(w, e)
    local f, r = w:frame(), e.bounds
    return r ~= nil and math.abs(f.x - r.x) < 4 and math.abs(f.y - r.y) < 4
       and math.abs(f.w - r.w) < 4 and math.abs(f.h - r.h) < 4
  end)
  pass("titolo", function(w, e) return e.name == (w:title() or "") end, true)
  pass("inizio del titolo", function(w, e)
    local t = w:title() or ""
    return e.name ~= "" and #t > #e.name and t:sub(1, #e.name) == e.name
       and t:sub(#e.name + 1, #e.name + 1) == " "
  end, true)
  return found, how
end

-- Le schede di un browser: una per finestra; una finestra con un solo
-- sito è una "webapp" (nome e logo del sito)
local function browserTabs(app, b, B, wins, add)
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
    local A = appArea()
    local mini = info and B.kind ~= "ax" and not found and f.w < A.w * 0.5 and f.h < A.h * 0.6
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


-- ---------------------------------------------------------------------
--  NOTIFICHE: i numerini rossi che le app mostrano sul Dock
-- ---------------------------------------------------------------------

local function readDockBadges()
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

local function badgeOfKey(key)
  local e = T.cand[key]
  if not e then return nil end
  if e.site then return e.titleBadge end
  if e.primary then return T.badges[e.bid] end
  return nil
end

-- Notifica da mostrare su una scheda (per un gruppo: la somma)
local badgeFor
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

-- Tutte le funzioni delle cartelle stanno nella tabella FD (Lua accetta al
-- massimo 200 nomi "locali" per file: così ne usiamo uno solo)
local FD = {}

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

-- La voce di ricetta di una scheda (app intera, oppure webapp)
function FD.itemOf(e)
  if e.site then return {site = e.site, bid = e.bid, name = e.name} end
  return {bid = e.bid, name = appName(e.bid, e.app)}
end

function FD.itemKey(it) return it.site and ("site:" .. it.site) or it.bid end

-- La scheda e corrisponde alla voce? (per un browser, la voce "app" sono le
-- sue finestre normali, non le webapp)
function FD.itemMatches(it, e)
  if it.site then return e.site == it.site end
  return e.bid == it.bid and not e.site
end

-- La cartella attiva a cui appartiene una scheda (per una vista divisa basta
-- un suo membro). nil se Vista cartelle è spenta.
function FD.folderOfEntry(e)
  if not S.folderView then return nil end
  local list = {}
  if e.group then
    for _, k in ipairs(e.group.members) do if T.cand[k] then table.insert(list, T.cand[k]) end end
  else
    list = {e}
  end
  for _, id in ipairs(S.activeFolders) do
    local f = FD.folderById(id)
    if f then
      for _, x in ipairs(list) do
        for _, it in ipairs(f.items) do if FD.itemMatches(it, x) then return f end end
      end
    end
  end
  return nil
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
    if not FLOATER[b] then
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
  local oldWinKey = T.winKey or {}
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
  for _, t in ipairs(all) do
    local f = FD.folderOfEntry(t)
    if f then T.tabFolder[t.key] = f; count[f.id] = (count[f.id] or 0) + 1 end
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

-- La scheda di quello che stai guardando: la finestra in primo piano, se è
-- una scheda a sé; altrimenti l'app (app con le finestre in una scheda sola)
local function currentKey()
  local bid = frontBid()
  if bid then
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
  if T.minis and T.minis[w:id()] then return end   -- finestrella (video in miniatura)
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
    -- un browser con una finestrella aperta (video in miniatura di Meet) non si
    -- nasconde, se no sparirebbe anche lei
    if not keep[b] and not app:isHidden() and not hasFullscreen(app)
       and not (T.minisOf and T.minisOf[b]) then
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
    local app = appFor(bid)
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
T.rebuildTimer = hs.timer.delayed.new(0.3, timed("ricostruzione schede", function()
  refreshBrowsers()
  rebuildTabs()
  draw()
end))
local function scheduleRebuild() T.rebuildTimer:start() end

-- È arrivata la risposta di un browser (vedi askBrowser): ricostruisci
-- senza fare un'altra domanda
onBrowserAnswer = function()
  if refreshBrowsers(false) then rebuildTabs(); draw() end
end

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
local handleActive = timed("cambio di scheda", function(app)
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
    -- per ogni cartella, l'ultima scheda usata (ci si torna entrando)
    local gk = T.memberOf[key]
    local cf = T.tabFolder[key] or (gk and T.tabFolder["g:" .. gk.id])
    if cf then T.folderLast[cf.id] = key end
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
end)

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
  if t.folder then FD.enterFolder(t.folder)
  elseif t.group then showGroup(t.group)
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
  -- nella vista normale, una scheda di una cartella attiva = la scheda-cartella
  local f = not T.viewFolder and (T.tabFolder[key] or (g and T.tabFolder["g:" .. g.id]))
  local fallback
  for i, t in ipairs(T.tabs) do
    if f then
      if t.folder == f then return i end
    elseif g then
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
  if T.cand[k] or appFor(T.keyBid[k] or k) then focusKey(k) end
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
  local prev = T.memoPrev and appFor(T.memoPrev)
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
  local app = appFor(bid)
  if app and frontBid() == bid then
    app:hide()   -- torni all'app di prima
    return
  end
  hs.application.launchOrFocusByBundleID(bid)
  -- l'app può metterci un po' ad aprire le finestre: riprova più volte
  for _, delay in ipairs({0.3, 0.8, 1.6}) do
    hs.timer.doAfter(delay, function() placeFloater(appFor(bid)) end)
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
  local f = appFor(FINDER)
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
--  CARTELLE: ATTIVARE, VISTA CARTELLA, CHIUDERE
--  Attivare una cartella (menu ⚡︎ o ⌃⌥⇧ + numero) apre quello che manca e
--  non ti sposta: se sei su una sua scheda entri nella vista cartella (solo
--  le sue schede, nome a sinistra / in alto); se sei altrove la cartella
--  compare come una scheda sola e tu resti dove sei.
-- ---------------------------------------------------------------------

-- Comandi per aprire una finestra nuova di un browser (sito o finestra vuota)
FD.OPEN_SITE = {
  chrome = 'tell application "%s"\nset w to make new window\nset URL of active tab of w to "%s"\nend tell',
  safari = 'tell application "%s"\nmake new document with properties {URL:"%s"}\nend tell',
}
FD.OPEN_WIN = {
  chrome = 'tell application "%s" to make new window',
  safari = 'tell application "%s" to make new document',
}

function FD.runTask(path, args)
  local t = hs.task.new(path, nil, args)
  if t then t:start() end
end

-- Apre una voce della ricetta che non è aperta, senza portarla davanti
function FD.openItem(it)
  local B = it.bid and BROWSERS[it.bid]
  if it.site then
    if not it.site:match("^[%w%.%-]+$") then return end
    local url = "https://" .. it.site .. "/"
    if B and FD.OPEN_SITE[B.kind] then
      FD.runTask("/usr/bin/osascript", {"-e", string.format(FD.OPEN_SITE[B.kind], B.as, url)})
    else
      -- DuckDuckGo non accetta comandi: il sito si apre come scheda del browser
      FD.runTask("/usr/bin/open", {"-g", "-b", it.bid or "com.apple.Safari", url})
    end
  elseif B and FD.OPEN_WIN[B.kind] and appFor(it.bid) then
    FD.runTask("/usr/bin/osascript", {"-e", string.format(FD.OPEN_WIN[B.kind], B.as)})
  elseif it.bid then
    FD.runTask("/usr/bin/open", {"-g", "-b", it.bid})
  end
end

-- La scheda in cui sei appartiene alla cartella f?
function FD.currentInFolder(f)
  local key = currentKey()
  if not key then return false end
  local g = T.memberOf[key]
  local cf = T.tabFolder[key] or (g and T.tabFolder["g:" .. g.id])
  return cf ~= nil and cf.id == f.id
end

-- Vista cartella: si vedono solo le schede della cartella
FD.enterFolder = function(f)
  if not f or not S.folderView then return end
  T.viewFolder = f.id
  rebuildTabs()
  if not FD.currentInFolder(f) then
    -- torna all'ultima scheda usata della cartella (o alla prima)
    local idx = 1
    for i, t in ipairs(T.tabs) do if t.key == T.folderLast[f.id] then idx = i end end
    if T.tabs[idx] then switchTo(idx) end
  end
  draw()
end

function FD.leaveFolderView()
  T.viewFolder = nil
  rebuildTabs()
  draw()
end

function FD.activateFolder(f)
  if not f then return end
  T.folderStart[f.id] = hs.timer.secondsSinceEpoch()
  local before = hs.window.focusedWindow()
  -- 1. apri quello che manca (le altre voci, già aperte, entrano da sole)
  local opened = 0
  for _, it in ipairs(f.items) do
    local present = false
    for _, e in pairs(T.cand) do if FD.itemMatches(it, e) then present = true; break end end
    if not present then FD.openItem(it); opened = opened + 1 end
  end
  print(string.format("Tabby · cartella «%s» attivata: %d voci, %d da aprire", f.name, #f.items, opened))
  -- le app appena aperte non devono portarti via da dove sei
  if opened > 0 and before then
    for _, d in ipairs({1.2, 2.5}) do
      hs.timer.doAfter(d, function()
        local now = hs.window.focusedWindow()
        if now and before:id() and now:id() ~= before:id() and before:application() then
          local nb = now:application() and now:application():bundleID()
          for _, it in ipairs(f.items) do
            if it.bid == nb then before:focus(); break end
          end
        end
      end)
    end
  end
  if not S.folderView then return end   -- Vista cartelle spenta: solo aprire
  if not FD.isFolderActive(f.id) then
    table.insert(S.activeFolders, f.id)
    save("activeFolders")
  end
  rebuildTabs()
  -- 2. sei su una sua scheda? entri nella vista cartella, restando lì
  if FD.currentInFolder(f) then T.viewFolder = f.id; rebuildTabs() end
  draw()
end

-- ⌃⌥⇧ + numero: attiva la cartella; se la stai già guardando, torni a tutte
function FD.folderShortcut(n)
  local f = S.folders[n]
  if not f then return end
  if T.viewFolder == f.id then FD.leaveFolderView() else FD.activateFolder(f) end
end

-- "Esci dalla cartella": le sue schede tornano libere
function FD.releaseFolder(f)
  for i = #S.activeFolders, 1, -1 do
    if S.activeFolders[i] == f.id then table.remove(S.activeFolders, i) end
  end
  save("activeFolders")
  if T.viewFolder == f.id then T.viewFolder = nil end
  rebuildTabs()
  draw()
end

-- "Chiudi cartella": chiude le sue app (per le webapp e le finestre di un
-- browser, solo quelle finestre: il browser resta aperto per il resto)
function FD.closeFolder(f)
  local btn = FD.ask(function()
    return hs.dialog.blockAlert("Chiudere la cartella «" .. f.name .. "»?",
      "Si chiudono le sue app e le sue finestre. Le app con documenti non salvati ti chiederanno cosa fare.",
      "Chiudi", "Annulla")
  end)
  if btn ~= "Chiudi" then return end
  local killed = {}
  for _, t in ipairs(T.allTabs) do
    if T.tabFolder[t.key] == f then
      local list = t.group and t.group.members or {t.key}
      for _, k in ipairs(list) do
        local e = T.cand[k]
        if e and (BROWSERS[e.bid] or e.bid == FINDER) then
          if e.win then e.win:close() end
        elseif e and e.app and not killed[e.bid] then
          killed[e.bid] = true
          e.app:kill()
        end
      end
    end
  end
  FD.releaseFolder(f)
  scheduleRebuild()
end

function FD.deleteFolder(f)
  FD.releaseFolder(f)
  for i = #S.folders, 1, -1 do if S.folders[i] == f then table.remove(S.folders, i) end end
  save("folders")
  rebuildTabs()
  draw()
end

-- Fa una domanda con una finestra di Tabby (Hammerspoon), poi ti riporta
-- alla finestra in cui eri
function FD.ask(fn)
  local prev = hs.window.focusedWindow()
  hs.focus()
  local a, b = fn()
  if prev and prev:application() then prev:focus() end
  return a, b
end

function FD.renameFolder(f)
  local btn, txt = FD.ask(function()
    return hs.dialog.textPrompt("Rinomina la cartella", "Nuovo nome:", f.name, "Rinomina", "Annulla")
  end)
  txt = txt and txt:match("^%s*(.-)%s*$")
  if btn ~= "Rinomina" or not txt or txt == "" then return end
  f.name = txt
  save("folders")
  rebuildTabs()
  draw()
end

-- Icona di una voce della ricetta (logo del sito o icona dell'app)
function FD.itemIcon(it)
  return (it.site and favicon(it.site)) or icon(it.bid)
end

-- Piccola immagine con le prime tre icone della cartella, per i menu
function FD.folderImage(f)
  local ok, img = pcall(function()
    local n = math.min(#f.items, 3)
    if n == 0 then return nil end
    local W, H = 16 + (n - 1) * 10, 16
    local c = hs.canvas.new({x = 0, y = 0, w = W, h = H})
    local els = {}
    for k = n, 1, -1 do
      local im = FD.itemIcon(f.items[k])
      if im then table.insert(els, {type = "image", image = im, frame = {x = (k - 1) * 10, y = 0, w = 16, h = 16}}) end
    end
    c:replaceElements(els)
    local im = c:imageFromCanvas()
    c:delete()
    return im
  end)
  return ok and img or nil
end


-- ---------------------------------------------------------------------
--  CARTELLE: CREARE E MODIFICARE (menu ⚡︎ → Nuova cartella…)
--  Si sceglie il nome, poi compare un riquadro con già la scheda in cui
--  sei; ci trascini (o clicchi) le altre schede di Tabby. Fatto = salvata.
-- ---------------------------------------------------------------------

-- Aggiunge al riquadro una scheda di Tabby (una vista divisa = i suoi membri)
function FD.feditAdd(t)
  local fe = T.fedit
  if not fe or not t or t.folder then return end
  local list = {}
  if t.group then
    for _, k in ipairs(t.group.members) do if T.cand[k] then table.insert(list, FD.itemOf(T.cand[k])) end end
  elseif t.bid then
    table.insert(list, FD.itemOf(t))
  end
  for _, it in ipairs(list) do
    local dup = false
    for _, x in ipairs(fe.items) do if FD.itemKey(x) == FD.itemKey(it) then dup = true end end
    if not dup then table.insert(fe.items, it) end
  end
  fe.hover = false
  FD.drawFolderEdit()
end

function FD.onFolderEditMouse(_, msg, id)
  if msg ~= "mouseUp" then return end
  id = tostring(id)
  if id == "fcancel" then FD.cancelFolderEdit(); return end
  if id == "fdone" then FD.finishFolderEdit(); return end
  if id == "fname" then
    local btn, txt = FD.ask(function()
      return hs.dialog.textPrompt("Nome della cartella", "", T.fedit.name, "OK", "Annulla")
    end)
    txt = txt and txt:match("^%s*(.-)%s*$")
    if btn == "OK" and txt and txt ~= "" then T.fedit.name = txt end
    FD.drawFolderEdit()
    return
  end
  local k = tonumber(id:match("^fitem(%d+)$"))
  if k and T.fedit then table.remove(T.fedit.items, k); FD.drawFolderEdit() end
end

FD.drawFolderEdit = function()
  local fe = T.fedit
  if not fe then return end
  local A = appArea()
  if not T.fOverlay then
    T.fOverlay = hs.canvas.new(A)
    T.fOverlay:level(hs.canvas.windowLevels.floating)
    T.fOverlay:behavior({"canJoinAllSpaces", "stationary", "fullScreenAuxiliary"})
    T.fOverlay:clickActivating(false)
    T.fOverlay:mouseCallback(FD.onFolderEditMouse)
  else
    T.fOverlay:frame(A)
  end
  local pw = math.min(600, A.w - 40)
  local ph = 262
  local px, py = (A.w - pw) / 2, (A.h - ph) / 2
  local els = {
    {type = "rectangle", action = "fill", fillColor = {white = 0, alpha = 0.5},
     frame = {x = 0, y = 0, w = A.w, h = A.h}},
    {type = "rectangle", action = "strokeAndFill", fillColor = {hex = "#191B20", alpha = 0.98},
     strokeColor = COL.divider, strokeWidth = 1, roundedRectRadii = {xRadius = 14, yRadius = 14},
     frame = {x = px, y = py, w = pw, h = ph}},
    {type = "text", text = (fe.id and "Cartella «" or "Nuova cartella «") .. fe.name .. "»",
     textSize = 17, textColor = COL.text, textLineBreak = "truncateTail",
     frame = {x = px + 20, y = py + 16, w = pw - 130, h = 24}},
    {type = "text", text = "rinomina", textSize = 11, textColor = COL.accent, textAlignment = "right",
     frame = {x = px + pw - 110, y = py + 21, w = 90, h = 16}},
    {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01}, trackMouseUp = true,
     id = "fname", frame = {x = px + pw - 110, y = py + 16, w = 90, h = 24}},
  }
  -- il riquadro dove si lasciano le schede
  local zr = {x = px + 20, y = py + 52, w = pw - 40, h = 134}
  T.fZoneAbs = {x = A.x + zr.x, y = A.y + zr.y, w = zr.w, h = zr.h}
  table.insert(els, {type = "rectangle", action = "strokeAndFill",
    fillColor = fe.hover and {hex = "#4C8DFF", alpha = 0.18} or {white = 1, alpha = 0.04},
    strokeColor = fe.hover and COL.accent or {white = 1, alpha = 0.35}, strokeWidth = 2,
    strokeDashPattern = {9, 6}, roundedRectRadii = {xRadius = 12, yRadius = 12}, frame = zr})
  local cw = 84
  local perRow = math.max(1, math.floor((zr.w - 16) / cw))
  for k, it in ipairs(fe.items) do
    if k > perRow then
      table.insert(els, {type = "text", text = "+" .. (#fe.items - perRow + 1), textSize = 14,
        textColor = COL.textMid, textAlignment = "center",
        frame = {x = zr.x + 8 + (perRow - 1) * cw, y = zr.y + 40, w = cw, h = 20}})
      break
    end
    local cx = zr.x + 8 + (k - 1) * cw
    local im = FD.itemIcon(it)
    if im then
      table.insert(els, {type = "image", image = im, frame = {x = cx + cw / 2 - 20, y = zr.y + 18, w = 40, h = 40}})
    end
    table.insert(els, {type = "text", text = it.name or it.site or it.bid, textSize = 11.5,
      textColor = COL.text, textAlignment = "center", textLineBreak = "truncateTail",
      frame = {x = cx + 2, y = zr.y + 64, w = cw - 4, h = 16}})
    table.insert(els, {type = "text", text = "✕ togli", textSize = 10, textColor = COL.textDim,
      textAlignment = "center", frame = {x = cx, y = zr.y + 82, w = cw, h = 14}})
    table.insert(els, {type = "rectangle", action = "fill", fillColor = {white = 1, alpha = 0.01},
      trackMouseUp = true, id = "fitem" .. k, frame = {x = cx, y = zr.y + 10, w = cw, h = 92}})
  end
  if #fe.items < 2 then
    local hx = zr.x + 8 + #fe.items * cw
    table.insert(els, {type = "text", text = "Trascina qui le schede di Tabby (o cliccale)",
      textSize = 14, textColor = {white = 1, alpha = 0.75},
      frame = {x = hx + 10, y = zr.y + zr.h / 2 - 10, w = zr.x + zr.w - hx - 20, h = 20}})
  end
  table.insert(els, {type = "text", text = "Esc annulla · Invio fatto", textSize = 11.5, textColor = COL.textDim,
    frame = {x = px + 20, y = py + ph - 44, w = 220, h = 18}})
  button(els, {x = px + pw - 228, y = py + ph - 52, w = 104, h = 34}, "Annulla  esc", COL.active, "fcancel")
  button(els, {x = px + pw - 116, y = py + ph - 52, w = 104, h = 34}, "Fatto  ↩", COL.accent, "fdone")
  T.fOverlay:replaceElements(els)
  T.fOverlay:show()
  if T.bar then T.bar:orderAbove(T.fOverlay) end
end

-- f = cartella da modificare; nil = cartella nuova (chiede il nome)
function FD.openFolderEditor(f)
  if T.split then exitSplit() end
  local fe = {id = f and f.id, name = f and f.name, items = {}, hover = false}
  -- la scheda in cui sei (presa prima della domanda, che porta davanti Tabby)
  local ai = activeIndex()
  local cur = ai and T.tabs[ai]
  if f then
    for _, it in ipairs(f.items) do table.insert(fe.items, it) end
  else
    local btn, txt = FD.ask(function()
      return hs.dialog.textPrompt("Nuova cartella", "Come si chiama? (es. Lavoro, Studio)", "", "Avanti", "Annulla")
    end)
    txt = txt and txt:match("^%s*(.-)%s*$")
    if btn ~= "Avanti" or not txt or txt == "" then return end
    fe.name = txt
  end
  T.fedit = fe
  -- si parte dalla scheda in cui sei
  if not f and cur then FD.feditAdd(cur) end
  T.revealed = true
  FD.drawFolderEdit()
  draw()
end

FD.cancelFolderEdit = function()
  T.fedit = nil
  if T.fOverlay then T.fOverlay:hide() end
  draw()
end

FD.finishFolderEdit = function()
  local fe = T.fedit
  if not fe then return end
  FD.cancelFolderEdit()
  if #fe.items == 0 then return end
  local f = fe.id and FD.folderById(fe.id)
  if not f then
    S.folderSeq = (S.folderSeq or 0) + 1
    f = {id = S.folderSeq}
    table.insert(S.folders, f)
  end
  f.name, f.items = fe.name, fe.items
  -- una voce sta in una sola cartella: le altre cartelle la lasciano
  local mine = {}
  for _, it in ipairs(f.items) do mine[FD.itemKey(it)] = true end
  for i = #S.folders, 1, -1 do
    local o = S.folders[i]
    if o ~= f then
      for j = #o.items, 1, -1 do if mine[FD.itemKey(o.items[j])] then table.remove(o.items, j) end end
      if #o.items == 0 then table.remove(S.folders, i) end
    end
  end
  save("folders"); save("folderSeq")
  local n = 1
  for i, x in ipairs(S.folders) do if x == f then n = i end end
  hs.alert.show(string.format("Cartella «%s» salvata · menu ⚡︎ o ⌃⌥⇧%d", f.name, n))
  rebuildTabs()
  draw()
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

-- ⚙︎ → Finestre separate: per ogni app aperta, una scheda per finestra
-- (spuntata, normale) oppure tutte le finestre in una scheda sola
local function windowsMenu()
  local items = {{title = "Una scheda per ogni finestra:", disabled = true}}
  local map, list = runningApps()
  local rows = {}
  for _, a in ipairs(list) do
    local b = a:bundleID()
    if not BROWSERS[b] and not FLOATER[b] then
      table.insert(rows, {b = b, name = appName(b, map[b])})
    end
  end
  table.sort(rows, function(x, y) return x.name:lower() < y.name:lower() end)
  for _, r in ipairs(rows) do
    table.insert(items, {
      title   = r.name,
      image   = smallIcon(r.b),
      checked = perWindow(r.b),
      fn      = function()
        S.joinWins[r.b] = perWindow(r.b) or nil
        save("joinWins")
        rebuildTabs()
        draw()
      end,
    })
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "I browser hanno sempre una scheda per finestra", disabled = true})
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
    {title = "Vista cartelle (una cartella attiva = una scheda sola)", checked = S.folderView,
     fn = toggle("folderView", function() T.viewFolder = nil; rebuildTabs() end)},
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
    {title = "Finestre separate", menu = windowsMenu()},
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
  -- cartelle: clic = attiva; si creano e si modificano da qui
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Cartelle", disabled = true})
  for i, f in ipairs(S.folders) do
    table.insert(items, {
      title   = f.name .. (i <= 9 and ("   ⌃⌥⇧" .. i) or ""),
      image   = FD.folderImage(f),
      checked = (S.folderView and FD.isFolderActive(f.id)) or nil,
      fn      = function() FD.activateFolder(f) end,
    })
  end
  table.insert(items, {title = "Nuova cartella…", fn = function() FD.openFolderEditor(nil) end})
  if #S.folders > 0 then
    local edit = {}
    for _, f in ipairs(S.folders) do
      table.insert(edit, {title = f.name, image = FD.folderImage(f), menu = {
        {title = "Modifica le schede…", fn = function() FD.openFolderEditor(f) end},
        {title = "Rinomina…", fn = function() FD.renameFolder(f) end},
        {title = "-"},
        {title = "Elimina la cartella", fn = function() FD.deleteFolder(f) end},
      }})
    end
    table.insert(items, {title = "Modifica le cartelle", menu = edit})
  end
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Mostra il file del Memo nel Finder", fn = function()
    local f = io.open(MEMO_FILE, "r")
    if f then f:close() else writeMemo(readMemo()) end
    hs.execute('open -R "' .. MEMO_FILE .. '"')
  end})
  popup(items, popPos(T.L.quick))
end

-- Menu ⋯ di una scheda-cartella (o del nome, nella vista cartella)
function FD.openFolderMenu(f, pos)
  local n = 0
  for _, x in ipairs(T.allTabs) do if T.tabFolder[x.key] == f then n = n + 1 end end
  local items = {}
  if T.viewFolder == f.id then
    table.insert(items, {title = "Torna a tutte le schede", fn = FD.leaveFolderView})
  else
    table.insert(items, {title = "Apri la cartella", fn = function() FD.enterFolder(f) end})
  end
  table.insert(items, {title = "Esci dalla cartella (le schede tornano libere)", fn = function() FD.releaseFolder(f) end})
  table.insert(items, {title = "Chiudi cartella (chiude le sue " .. n .. " schede)…", fn = function() FD.closeFolder(f) end})
  table.insert(items, {title = "-"})
  table.insert(items, {title = "Modifica le schede…", fn = function() FD.openFolderEditor(f) end})
  table.insert(items, {title = "Rinomina…", fn = function() FD.renameFolder(f) end})
  popup(items, pos)
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
  local u = tonumber(id:match("^ungroup(%d+)$"))
  if u then
    local t = T.tabs[u]
    if t and t.group then ungroup(t.group) end
    return
  end
  if ti then
    if T.split then assignFirstEmpty(ti)
    elseif T.fedit then FD.feditAdd(T.tabs[ti])
    else switchTo(ti) end
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
    -- vista cartella: in cima "← Tutte le schede" e il nome della cartella
    if T.viewFolder and FD.folderById(T.viewFolder) then
      L.fback = {x = 0, y = BTN_W + 2, w = w, h = 26}
      L.fhead = {x = 0, y = BTN_W + 28, w = w, h = 30}
      table.insert(L.dividers, {x = 8, y = BTN_W + 60, w = w - 16, h = 1})
      start = BTN_W + 66
    end
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
        frame = {x = textX, y = my - 9, w = closeX - badgeW - textX - 2, h = 18}})

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
      if appFor(b) then still[b] = true end
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
  -- diagnosi: che finestra ha aperto un browser (es. le finestrelle di Meet)
  if b and BROWSERS[b] then
    local f = w:frame()
    print(string.format("Tabby · finestra nuova di %s «%s»: tipo=%s · normale=%s · %.0fx%.0f",
      BROWSERS[b].short, tostring(w:title()), tostring(w:subrole()), tostring(w:isStandard()), f.w, f.h))
  end
  -- (con le finestre separate ogni finestra nuova è una scheda nuova:
  -- non entra nel gruppo)
  local g = b and not BROWSERS[b] and not perWindow(b) and T.memberOf[b]
  if b and FLOATER[b] then
    placeFloater(a)
  elseif g then
    -- nuova finestra di un'app in un gruppo: nella sua zona (se il gruppo è attivo)
    hs.timer.doAfter(0.2, function()
      if T.memberOf[currentKey()] == g then layoutGroup(g) end
    end)
  elseif a and b == frontBid() then
    -- una finestra piccola di un browser può essere una finestrella (video in
    -- miniatura): si decide dopo, quando il browser ha risposto
    local f, A = w:frame(), appArea()
    if not (BROWSERS[b] and f.w < A.w * 0.5 and f.h < A.h * 0.6) then fitWindow(w) end
  end
  scheduleRebuild()
end)

T.allWins:subscribe(WF.windowDestroyed, function() scheduleRebuild() end)

-- Cambio di finestra dentro la stessa app (es. da un documento all'altro,
-- o da una webapp all'altra con ⌘`): aggiorna la scheda attiva
T.focusTimer = hs.timer.delayed.new(0.15, function()
  local f = hs.application.frontmostApplication()
  local b = f and f:bundleID()
  if b and (BROWSERS[b] or (perWindow(b) and currentKey() ~= T.lastKey)) then
    handleActive(f)
  else
    draw()
  end
end)
T.allWins:subscribe(WF.windowFocused, function() T.focusTimer:start() end)

-- Il nome di una finestra-scheda è il suo titolo: se cambia, ridisegna
T.allWins:subscribe(WF.windowTitleChanged, function() scheduleRebuild() end)

-- Browser: titoli e siti cambiano mentre navighi → ricontrolla ogni 3 secondi
T.browserTimer = hs.timer.doEvery(3, timed("controllo browser", function()
  if T.press or T.split or T.fedit then return end
  if refreshBrowsers() then rebuildTabs(); draw() end
end))

-- Notifiche: ricontrolla i numerini del Dock ogni 3 secondi
local function badgeSig(b)
  local parts = {}
  for k, v in pairs(b) do table.insert(parts, k .. "=" .. v) end
  table.sort(parts)
  return table.concat(parts, ",")
end
T.badgeTimer = hs.timer.doEvery(3, timed("notifiche del Dock", function()
  local b = readDockBadges()
  local sig = badgeSig(b)
  if sig ~= T.badgeSig then
    T.badges, T.badgeSig = b, sig
    if T.bar then draw() end
  end
end))

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
local function shortcut(key, id, fn, onlyIf, shift)
  table.insert(SHORTCUTS, {key = key, id = id, fn = fn, onlyIf = onlyIf, shift = shift})
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
-- ⌃⌥⇧ + numero = cartella numero 1…9 (nell'ordine del menu ⚡︎)
for i = 1, 9 do
  shortcut(tostring(i), "folder" .. i, function() FD.folderShortcut(i) end, nil, true)
end

local WANT = {}
for _, m in ipairs(MODS) do WANT[m] = true end
local function modsMatch(f, shift)
  for _, m in ipairs({"ctrl", "alt", "cmd", "shift"}) do
    local want = WANT[m] or (m == "shift" and shift) or false
    if (f[m] and true or false) ~= want then return false end
  end
  return true
end

T.keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(e)
  local f    = e:getFlags()
  local code = e:getKeyCode()
  local noMods = not (f.ctrl or f.alt or f.cmd or f.shift)

  -- Creazione di una cartella: Invio = fatto, Esc = annulla
  if T.fedit and noMods then
    if code == K.escape then later(FD.cancelFolderEdit); return true end
    if code == K["return"] or code == K.padenter then later(FD.finishFolderEdit); return true end
  end

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

  -- ⌃⌥ + tasto (o ⌃⌥⇧ + numero per le cartelle) = scorciatoie di Tabby
  local plain, shifted = modsMatch(f), modsMatch(f, true)
  if plain or shifted then
    local name = K[code]
    for _, sc in ipairs(SHORTCUTS) do
      if sc.key == name and ((sc.shift and shifted) or (not sc.shift and plain))
         and (not sc.onlyIf or sc.onlyIf()) then
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
    local mods = sc.shift and {"ctrl", "alt", "shift"} or MODS
    local ok, hk = pcall(hs.hotkey.bind, mods, sc.key, function() fire(sc.id, sc.fn, "hotkey") end)
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
hs.alert.show("Tabby v9.10 attiva")
