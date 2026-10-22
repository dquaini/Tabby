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

function toggleMemo()
  if T.memoOpen then closeMemo() else openMemo() end
end

-- Apre / chiude un'azione veloce (stessa scorciatoia)
-- Azione rapida di un'app (vedi APP_ACTIONS). Per qualche secondo l'app non
-- nasconde la scheda in cui sei e il suo pannello non viene ingrandito.
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
    if ok and item then
      item:performAction("AXPress")
    else
      print("Tabby · azione «" .. a.name .. "»: icona dell'app non trovata nella barra dei menu")
      hs.alert.show("Non trovo l'icona di " .. appName(a.bid, app) .. " nella barra dei menu")
    end
  end
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

-- Scrivania: nasconde tutto. Ripremendo, torna all'ultima scheda.
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
        if not w:isMinimized() then w:minimize() end
      end
      draw()
    end)
  end
  draw()
end
