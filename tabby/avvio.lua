-- =====================================================================
--  Tabby · avvio.lua: l'avvio: prime letture e primo disegno.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  AVVIO
-- ---------------------------------------------------------------------
menuBarH()
T.notch = detectNotch()
T.menuHidden = detectMenuHidden()
T.dockPrefs = readDockPrefs()
logDiagnostics()
updateFullscreen()
refreshBrowsers()
T.badges = readDockBadges()
T.badgeSig = badgeSig(T.badges)
rebuildTabs()
draw()
handleActive(hs.application.frontmostApplication())
if T.paused then pauseTabby() end   -- era stata chiusa: resta solo la sfera
-- app con un'icona nella barra dei menu: si cercano dopo l'avvio e ogni 10 minuti
hs.timer.doAfter(5, function() scanMenuBarApps() end)
-- il Memo si prepara (nascosto) subito: aprirlo con ⌃⌥M è immediato anche la prima volta
hs.timer.doAfter(2, function() ensureMemo() end)
T.menuAppsTimer = hs.timer.doEvery(600, function() scanMenuBarApps() end)
