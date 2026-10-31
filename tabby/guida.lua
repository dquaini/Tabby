-- =====================================================================
--  Tabby · guida.lua: il foglio delle scorciatoie (⌃⌥/, anche da ⚙︎) (31/10/2026).
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
--
--  Un foglio in stile macOS (pagina tabby/scorciatoie.html) con tutte le scorciatoie,
--  compilato ogni volta dalle scorciatoie vere: anche quelle delle App (⚡︎ → App) e delle
--  cartelle, coi loro nomi. Lo sfondo si oscura (la barra no). Esc, ⌃⌥/ o un clic fuori
--  lo chiudono. Nell'app Swift finirà nella sezione Documentazione.
-- =====================================================================

KEYS_W, KEYS_H = 760, 560

function keysFrame()
  local A = appArea()
  local w, h = math.min(KEYS_W, A.w - 40), math.min(KEYS_H, A.h - 40)
  return {x = math.floor(A.x + (A.w - w) / 2), y = math.floor(A.y + (A.h - h) / 2), w = w, h = h}
end

-- I gruppi del foglio, dalle scorciatoie di adesso
function keysGroups()
  local tabs = {
    {"⌃ ⌥ 1…9", "Vai alla scheda 1–9"},
    {isVertical() and "⌃ ⌥ ↑ ↓" or "⌃ ⌥ ← →", "Scheda prima / dopo"},
    {"⌃ ⌥ Tab", "Torna alla scheda di prima"},
    {"⌃ ⌥ W", "Chiudi la finestra (l'app resta aperta)"},
    {"⌃ ⌥ 0", "Scrivania"},
  }
  if S.gestures then table.insert(tabs, {"3 dita ← →", "Scheda dopo / prima (trackpad)"}) end
  local groups = {{title = "Schede", rows = tabs}}
  table.insert(groups, {title = "Vista divisa", rows = {
    {"⌃ ⌥ S", "Scambia le zone"},
    {"↩", "Fatto (mentre dividi)"},
    {"esc", "Annulla (mentre dividi)"},
  }})
  local lamps = {}
  for _, q in ipairs(QUICK) do table.insert(lamps, {"⌃ ⌥ " .. q.key:upper(), q.name}) end
  table.insert(lamps, {"esc", "Chiudi il Lampo o il Memo in primo piano"})
  table.insert(groups, {title = "Lampi", rows = lamps})
  table.insert(groups, {title = "Strumenti", rows = {
    {"⌃ ⌥ F", "Cerca nelle finestre"},
    {"⌃ ⌥ /", "Questo foglio"},
  }})
  local apps = {}
  for _, a in ipairs(APP_ACTIONS) do
    if a.key then table.insert(apps, {"⌃ ⌥ " .. a.key:upper(), a.name}) end
  end
  for _, m in pairs(S.menuApps or {}) do
    if m.key and m.on then table.insert(apps, {"⌃ ⌥ " .. m.key:upper(), m.name}) end
  end
  if #apps > 0 then table.insert(groups, {title = "App", rows = apps}) end
  local folders = {}
  for i, f in ipairs(S.folders or {}) do
    if i <= 9 then table.insert(folders, {"⌃ ⌥ ⇧ " .. i, f.name}) end
  end
  if #folders > 0 then table.insert(groups, {title = "Cartelle", rows = folders}) end
  table.insert(groups, {title = "Tabby", rows = {{"⌃ ⌥ ⌘ R", "Ricarica Tabby"}}})
  return groups
end

function keysJS()
  local parts = {}
  for _, g in ipairs(keysGroups()) do
    local rows = {}
    for _, r in ipairs(g.rows) do table.insert(rows, "[" .. jsString(r[1]) .. "," .. jsString(r[2]) .. "]") end
    table.insert(parts, "{title:" .. jsString(g.title) .. ",rows:[" .. table.concat(rows, ",") .. "]}")
  end
  return "render([" .. table.concat(parts, ",") .. "])"
end

function ensureKeysView()
  if T.keysView then return T.keysView end
  T.keysUCC = hs.webview.usercontent.new("tabbykeys")
  T.keysUCC:setCallback(function(msg)
    local b = msg and msg.body
    if type(b) ~= "table" then return end
    if b.ready then
      T.keysReady = true
      if T.keysOpen then T.keysView:evaluateJavaScript(keysJS()) end
    end
    if b.close then closeKeys() end
  end)
  local page = ""
  local f = io.open((T.dir or ".") .. "/tabby/scorciatoie.html", "r")
  if f then page = f:read("a"); f:close() end
  T.keysView = hs.webview.new(keysFrame(), {developerExtrasEnabled = false}, T.keysUCC)
  T.keysView:windowStyle({"borderless", "nonactivating"})
  pcall(function() T.keysView:transparent(true) end)
  T.keysView:allowTextEntry(false)
  T.keysView:level(hs.canvas.windowLevels.modalPanel)
  T.keysView:behaviorAsLabels({"canJoinAllSpaces", "stationary"})
  T.keysView:html(page)
  return T.keysView
end

function openKeys()
  if T.keysOpen then closeKeys(); return end
  if T.searchOpen then closeSearch() end
  local v = ensureKeysView()
  markViewUsed("keysView")
  T.keysOpen = true
  v:frame(keysFrame())
  focusDim(true)
  v:show()
  if T.keysReady then v:evaluateJavaScript(keysJS()) end
  print("Tabby · foglio delle scorciatoie")
  -- un clic fuori lo chiude
  if not T.keysTap then
    T.keysTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(e)
      if not T.keysOpen then return false end
      local p, fr = e:location(), keysFrame()
      if not (p.x >= fr.x and p.x <= fr.x + fr.w and p.y >= fr.y and p.y <= fr.y + fr.h) then later(closeKeys) end
      return false
    end)
  end
  T.keysTap:start()
end

function closeKeys()
  if not T.keysOpen then return end
  T.keysOpen = false
  if T.keysTap then T.keysTap:stop() end
  focusDim(false)
  if T.keysView then T.keysView:hide() end
end
