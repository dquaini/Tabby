-- =====================================================================
--  Tabby · scorciatoie.lua: le scorciatoie (⌃⌥ + tasto) con il doppio meccanismo.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  SCORCIATOIE  (tutte con ⌃⌥ = Ctrl + Option, vedi MODS in cima)
--  Doppio meccanismo, perché alcune app (es. Windows App, desktop remoto)
--  si "prendono" la tastiera:
--   1) un intercettatore che le vede prima dell'app in primo piano;
--   2) le scorciatoie di sistema di macOS, come riserva.
--  Se arrivano da entrambi, l'azione parte una volta sola.
-- ---------------------------------------------------------------------

K = hs.keycodes.map

-- Se la stessa scorciatoia arriva quasi insieme dai DUE meccanismi, conta una volta
-- (due pressioni vere e veloci dallo stesso meccanismo invece valgono due)
function fire(id, fn, src)
  local now, last = hs.timer.secondsSinceEpoch(), T.lastFire[id]
  if last and last.src ~= src and now - last.t < 0.3 then return end
  T.lastFire[id] = {t = now, src = src}
  fn()
end

-- Elenco delle scorciatoie: tasto (insieme a ⌃⌥) → azione
SHORTCUTS = {}
function shortcut(key, id, fn, onlyIf, shift)
  table.insert(SHORTCUTS, {key = key, id = id, fn = fn, onlyIf = onlyIf, shift = shift})
end
for i = 1, 9 do shortcut(tostring(i), "tab" .. i, function() switchTo(i) end) end
shortcut("0", "desktop", toggleDesktop)
shortcut("left",  "prev", function() switchRelative(-1) end)
shortcut("right", "next", function() switchRelative(1) end)
shortcut("up",    "prev", function() switchRelative(-1) end, isVertical)
shortcut("down",  "next", function() switchRelative(1) end, isVertical)
shortcut("tab",   "last", toggleLastApp)
shortcut("s",     "rotate", function() rotateGroup(currentGroup()) end)
shortcut("w",     "closewin", function() closeActiveWindow() end)
for _, q in ipairs(QUICK) do
  shortcut(q.key, "quick-" .. q.key, function() toggleQuick(q) end)
end
-- ⌃⌥⇧ + numero = cartella numero 1…9 (nell'ordine del menu ⚡︎)
for i = 1, 9 do
  shortcut(tostring(i), "folder" .. i, function() FD.folderShortcut(i) end, nil, true)
end

WANT = {}
for _, m in ipairs(MODS) do WANT[m] = true end
function modsMatch(f, shift)
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
