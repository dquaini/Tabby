-- =====================================================================
--  Tabby · memo.lua: il Memo (⌃⌥M) e le app veloci.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  MEMO (⌃⌥M): un blocco note piccolo in alto a destra.
--  Si salva da solo mentre scrivi; Esc (o di nuovo ⌃⌥M) lo chiude.
-- ---------------------------------------------------------------------

MEMO_W, MEMO_H = 340, 280

function memoHTML(text)
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

function memoRect()
  local A = appArea()
  return {x = A.x + A.w - MEMO_W - 12, y = A.y + 12, w = MEMO_W, h = MEMO_H}
end

function backToPrev()
  local prev = T.memoPrev and appFor(T.memoPrev)
  if prev then prev:activate() end
end

-- Il testo del Memo sta in un file vero (MEMO_FILE, in Documenti)
function readMemo()
  local f = io.open(MEMO_FILE, "r")
  if f then
    local txt = f:read("a") or ""
    f:close()
    return txt
  end
  -- primo avvio: recupera quello scritto nel vecchio Memo (se c'è)
  return hs.settings.get("tabbar.memo") or ""
end

function writeMemo(txt)
  local f = io.open(MEMO_FILE, "w")
  if f then
    f:write(txt)
    f:close()
  else
    print("Tabby · Memo: impossibile salvare in " .. MEMO_FILE)
  end
end

-- (closeMemo: definita più sotto o in un altro file)

function ensureMemo()
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

function openMemo()
  local fb = frontBid()
  if fb and not IGNORE[fb] then T.memoPrev = fb end
  local m = ensureMemo()
  -- ricarica sempre dal file: così vedi anche le modifiche fatte con TextEdit
  m:html(memoHTML(readMemo()))
  m:frame(memoRect())
  m:show()
  T.memoOpen = true
  memoTakeKeyboard()
  -- La tastiera deve arrivare davvero al Memo: Hammerspoon diventa l'app attiva
  -- con un attimo di ritardo, e fino ad allora la finestra non riceve i tasti
  -- (23/10/2026: "devo cliccare più volte prima di scrivere"). Si ricontrolla
  -- tre volte e, se serve, si ridà l'attenzione.
  T.memoSeq = (T.memoSeq or 0) + 1
  local seq = T.memoSeq
  for _, d in ipairs({0.08, 0.25, 0.6}) do
    hs.timer.doAfter(d, function()
      if seq ~= T.memoSeq or not T.memoOpen then return end
      local f, mw = hs.window.focusedWindow(), m:hswindow()
      local ok, same = pcall(function() return f:id() == mw:id() end)
      if not (ok and same) then
        print("Tabby · Memo: la tastiera non era sul Memo, gliela ridò")
        memoTakeKeyboard()
      else
        m:evaluateJavaScript("typeof focusEnd === 'function' && focusEnd()")
      end
    end)
  end
end

function memoTakeKeyboard()
  local m = T.memo
  if not m then return end
  hs.focus()
  pcall(function() m:bringToFront(true) end)
  local w = m:hswindow()
  if w then w:focus() end
  m:evaluateJavaScript("typeof focusEnd === 'function' && focusEnd()")
end

closeMemo = function()
  if not T.memo or not T.memoOpen then return end
  T.memoOpen = false
  T.memo:evaluateJavaScript("send({text: t.value})")   -- salva l'ultima cosa scritta
  T.memo:hide()
  backToPrev()
end

function toggleMemo()
  if T.memoOpen then closeMemo() else openMemo() end
end

-- Apre / chiude un'azione veloce (stessa scorciatoia)
-- Azione rapida di un'app (vedi APP_ACTIONS). Per qualche secondo l'app non
-- nasconde la scheda in cui sei e il suo pannello non viene ingrandito.
-- Riserva: porta davanti l'app e manda la sua scorciatoia (che vale solo dentro
-- l'app), quando hai lasciato ⌃⌥
function actionFallback(a, app)
  if not a.fallbackKeys then return false end
  print("Tabby · azione «" .. a.name .. "»: icona nascosta, apro l'app con la sua scorciatoia")
  T.actionAt = nil
  app:activate()
  local function send(tries)
    local m = hs.eventtap.checkKeyboardModifiers() or {}
    if (m.ctrl or m.alt) and tries < 30 then
      hs.timer.doAfter(0.05, function() send(tries + 1) end)
    else
      hs.eventtap.keyStroke(a.fallbackKeys[1], a.fallbackKeys[2], 0)
    end
  end
  hs.timer.doAfter(0.4, function() send(0) end)
  return true
end

function runAppAction(a, retry)
  local app = appFor(a.bid)
  if not app then
    -- l'app non è aperta: si apre dietro e si riprova tra poco (una volta)
    if retry then return end
    FD.runTask("/usr/bin/open", {"-g", "-b", a.bid})
    hs.timer.doAfter(2.5, function() runAppAction(a, true) end)
    return
  end
  T.actionAt = {bid = a.bid, at = hs.timer.secondsSinceEpoch()}
  if a.keys then
    -- la scorciatoia dell'app si manda quando hai lasciato ⌃⌥: se no per macOS
    -- diventa ⌃⌥⌘⇧K, che non è quella di Notion (visto sul Mac il 22/10/2026)
    local function send(tries)
      local m = hs.eventtap.checkKeyboardModifiers() or {}
      if (m.ctrl or m.alt) and tries < 30 then
        hs.timer.doAfter(0.05, function() send(tries + 1) end)
      else
        T.actionAt.at = hs.timer.secondsSinceEpoch()
        hs.eventtap.keyStroke(a.keys[1], a.keys[2], 0)
      end
    end
    send(0)
  elseif a.menubar then
    local ok, item = pcall(function()
      local bar = hs.axuielement.applicationElement(app):attributeValue("AXExtrasMenuBar")
      return bar and (bar:attributeValue("AXChildren") or {})[1]
    end)
    -- icona spenta in "Consenti nella barra dei menu": macOS la parcheggia fuori
    -- dallo schermo (vista sul Mac: -1, 899) e un suo menu non si apre più
    local pos = ok and item and item:attributeValue("AXPosition")
    local hidden = pos and (pos.x < 0 or pos.y > screen():fullFrame().h - 2)
    if ok and item and a.menuItem and hidden and actionFallback(a, app) then
      return
    end
    if ok and item and a.generic and hidden then
      -- "Apri <app>" con l'icona spenta: premerla non apre niente (Proton VPN, 23/10):
      -- si apre direttamente l'app (come cliccarla nel Dock)
      print("Tabby · azione «" .. a.name .. "»: icona spenta in macOS, apro l'app")
      T.actionAt = nil
      FD.runTask("/usr/bin/open", {"-b", a.bid})
      return
    end
    if ok and item then
      actionVeil(a)
      local before = hs.window.focusedWindow()
      item:performAction("AXPress")
      -- "Apri <app>": se non si è aperto niente (l'icona apre un menu, ma è spenta
      -- in macOS e il menu non compare), si apre l'app
      if a.generic then
        hs.timer.doAfter(1.2, function()
          local now = hs.window.focusedWindow()
          local menuOpen = false
          pcall(function()
            for _, c in ipairs(item:attributeValue("AXChildren") or {}) do
              if c:attributeValue("AXRole") == "AXMenu" then menuOpen = true end
            end
          end)
          local same = (before == nil and now == nil) or (before and now and before:id() == now:id())
          if same and not menuOpen then
            T.veil(false)
            if (app:kind() or 1) == 0 then
              -- app "solo icona" (niente finestre né Dock, es. Proton VPN): senza la
              -- sua icona nella barra dei menu non c'è niente da aprire
              print("Tabby · azione «" .. a.name .. "»: app solo icona, icona spenta in macOS")
              hs.alert.show(appName(a.bid, app) .. " si apre solo dalla sua icona: riaccendila in\n" ..
                "Impostazioni di Sistema → Barra dei menu → Consenti nella barra dei menu", 5)
            else
              print("Tabby · azione «" .. a.name .. "»: non si è aperto niente, apro l'app")
              app:activate()
            end
          end
        end)
      end
      -- Notion: dal menu dell'icona si preme la voce giusta ("Toggle Command Search")
      if a.menuItem then
        -- il menu può metterci un po' ad aprirsi (con l'icona nascosta dalla barra
        -- di Apple): si cerca per un secondo e mezzo, nell'icona e nell'app
        local axApp = hs.axuielement.applicationElement(app)
        local t0 = hs.timer.secondsSinceEpoch()
        local tries = 0
        local function look()
          tries = tries + 1
          local mi = findMenuItem(item, a.menuItem) or findMenuItem(axApp, a.menuItem, true)
          if mi then
            print(string.format("Tabby · azione «%s»: voce trovata dopo %.1f s", a.name, hs.timer.secondsSinceEpoch() - t0))
            mi:performAction("AXPress")
          elseif tries < 15 then
            hs.timer.doAfter(0.1, look)
          else
            hs.eventtap.keyStroke({}, "escape", 0)
            T.veil(false)
            actionFallback(a, app)
            -- diagnosi: cosa c'è sotto l'icona e nell'app
            local seen = {}
            local function roles(el, depth)
              if depth > 3 then return end
              for _, c in ipairs(el:attributeValue("AXChildren") or {}) do
                table.insert(seen, string.rep(">", depth) .. tostring(c:attributeValue("AXRole")) ..
                  (c:attributeValue("AXTitle") and ("«" .. c:attributeValue("AXTitle") .. "»") or ""))
                if #seen < 25 then roles(c, depth + 1) end
              end
            end
            pcall(roles, item, 1)
            local p = item:attributeValue("AXPosition")
            print(string.format("Tabby · azione «%s»: voce «%s» non trovata (icona in %s,%s) · sotto l'icona: %s",
              a.name, a.menuItem, tostring(p and p.x), tostring(p and p.y), table.concat(seen, " ")))
          end
        end
        hs.timer.doAfter(0.1, look)
      end
    else
      print("Tabby · azione «" .. a.name .. "»: icona dell'app non trovata nella barra dei menu")
      hs.alert.show("Non trovo l'icona di " .. appName(a.bid, app) .. " nella barra dei menu")
    end
  end
end

-- Una voce nel menu (aperto) di un'icona della barra dei menu, dal titolo
function findMenuItem(el, title, onlyMenus)
  for _, c in ipairs(el:attributeValue("AXChildren") or {}) do
    local role = c:attributeValue("AXRole")
    if role == "AXMenuItem" and c:attributeValue("AXTitle") == title then return c end
    -- onlyMenus: nell'app si guarda solo dentro i menu aperti (non nelle finestre)
    if role == "AXMenu" or role == "AXMenuItem" or (not onlyMenus and role ~= "AXWindow") then
      local found = (role == "AXMenu" or role == "AXMenuItem" or not onlyMenus) and findMenuItem(c, title, onlyMenus)
      if found then return found end
    end
  end
  return nil
end

-- Il velo scuro sotto il pannello dell'azione (come per Spotlight). Si toglie
-- quando torni alla finestra di prima, o passi a una finestra "vera" (una
-- scheda grande: es. apri il risultato della ricerca in Notion).
function actionVeil(a)
  local before = hs.window.focusedWindow()
  T.veil(true, function()
    local f = hs.window.focusedWindow()
    if not f then return false end
    if before and f:id() == before:id() then return true end
    return T.winKey[f:id()] ~= nil and not T.isSmall(f)
  end)
end

-- ---------------------------------------------------------------------
--  AZIONI DELLE APP: tutte le app con un'icona nella barra dei menu.
--  Tabby le scopre da sola (all'avvio, a ogni app aperta, ogni 10 minuti),
--  anche quelle installate dopo, le aggiunge al menu ⚡︎ → App e se le ricorda
--  (S.menuApps). Per ognuna: mostra / nascondi e una scorciatoia ⌃⌥ + lettera.
--  Le app di sistema di Apple restano fuori (Wi-Fi, Bluetooth…).
-- ---------------------------------------------------------------------
MENUBAR_SKIP = {["org.hammerspoon.Hammerspoon"] = true}

function menuBarItemOf(app)
  local ok, item = pcall(function()
    local bar = hs.axuielement.applicationElement(app):attributeValue("AXExtrasMenuBar")
    return bar and (bar:attributeValue("AXChildren") or {})[1]
  end)
  return ok and item or nil
end

-- Cerca app nuove con un'icona nella barra dei menu (only = solo quell'app)
function scanMenuBarApps(only)
  local found = 0
  local changed = false
  for _, app in ipairs(only and {only} or hs.application.runningApplications()) do
    local b = app:bundleID()
    local kind = app:kind() or -1
    if b and not b:match("^com%.apple%.") and not MENUBAR_SKIP[b] and kind >= 0 then
      local m = S.menuApps[b]
      if not m and menuBarItemOf(app) then
        m = {name = app:name() or b, on = true}
        S.menuApps[b] = m
        found, changed = found + 1, true
        print("Tabby · nuova app con icona nella barra dei menu: " .. m.name .. " (aggiunta in ⚡︎ → App)")
      end
      -- app "solo icona" (niente finestre né Dock, es. Proton VPN): si apre solo
      -- dalla sua icona, che quindi va lasciata accesa in macOS
      if m and m.iconOnly ~= (kind == 0) then m.iconOnly = (kind == 0); changed = true end
    end
  end
  if changed then save("menuApps") end
  return found
end

-- Tutte le azioni del menu ⚡︎ → App: prima quelle speciali (APP_ACTIONS), poi
-- "Apri <app>" per le altre app scoperte e mostrate, in ordine alfabetico
function appActionsList()
  local list, special = {}, {}
  for _, a in ipairs(APP_ACTIONS) do
    if hs.application.pathForBundleID(a.bid) then table.insert(list, a) end
    special[a.bid] = true
  end
  local extra = {}
  for b, m in pairs(S.menuApps) do
    if m.on and not special[b] then
      table.insert(extra, {bid = b, name = "Apri " .. m.name, key = m.key, menubar = true, generic = true})
    end
  end
  table.sort(extra, function(x, y) return x.name:lower() < y.name:lower() end)
  for _, a in ipairs(extra) do table.insert(list, a) end
  return list
end

-- Lettere già usate dalle scorciatoie di Tabby (per non sceglierne una doppia)
function usedShortcutKeys()
  local used = {}
  for _, sc in ipairs(SHORTCUTS or {}) do if not sc.shift then used[sc.key] = true end end
  for _, a in ipairs(APP_ACTIONS) do used[a.key] = true end
  for _, m in pairs(S.menuApps) do if m.key then used[m.key] = true end end
  return used
end

-- Scegli la scorciatoia di un'app (⌃⌥ + una lettera libera). Tabby si ricarica
-- per attivarla.
function chooseAppShortcut(b)
  local m = S.menuApps[b]
  if not m then return end
  local btn, txt = FD.ask(function()
    return hs.dialog.textPrompt("Scorciatoia per " .. m.name, "Una lettera: si userà con ⌃⌥ (es. D → ⌃⌥D)",
      m.key and m.key:upper() or "", "OK", "Annulla")
  end)
  local k = txt and txt:lower():match("^%s*(%a)%s*$")
  if btn ~= "OK" or not k then return end
  local used = usedShortcutKeys()
  if used[k] and m.key ~= k then
    hs.alert.show("⌃⌥" .. k:upper() .. " è già usata: scegline un'altra")
    return
  end
  m.key = k
  save("menuApps")
  hs.alert.show(m.name .. ": ⌃⌥" .. k:upper())
  hs.timer.doAfter(0.8, function() hs.reload() end)
end

-- Un'azione rapida è appena partita per quest'app? (il suo pannello non è una scheda)
function actionRecent(bid)
  return T.actionAt ~= nil and T.actionAt.bid == bid and hs.timer.secondsSinceEpoch() - T.actionAt.at < 3
end

function toggleQuick(q)
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

function openSpotlight()
  hs.timer.doAfter(0.15, function() hs.eventtap.keyStroke({"cmd"}, "space", 0) end)
end

-- Clic sul gatto (23/10/2026, Daniele): si apre il Finder sulla cartella
-- Scrivania (se c'è già una sua finestra, macOS riusa quella) e diventa una
-- scheda come le altre. ⌃⌥0 resta la "scrivania" che nasconde tutto.
function openDesktopFolder()
  T.desktopMode = false
  T.focusSeq = (T.focusSeq or 0) + 1
  print("Tabby · clic sul gatto: apro il Finder sulla Scrivania")
  local t = hs.task.new("/usr/bin/open", nil, {os.getenv("HOME") .. "/Desktop"})
  if t then t:start() end
  afterFocus()
end

-- Scrivania (⌃⌥0): nasconde tutto. Ripremendo, torna all'ultima scheda.
function toggleDesktop()
  T.focusSeq = (T.focusSeq or 0) + 1
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
        if not w:isMinimized() then T.selfMin[w:id()] = hs.timer.secondsSinceEpoch(); w:minimize() end
      end
      draw()
    end)
  end
  draw()
end
