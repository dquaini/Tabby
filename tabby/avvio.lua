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
logDiagnostics()
updateFullscreen()
refreshBrowsers()
T.badges = readDockBadges()
T.badgeSig = badgeSig(T.badges)
rebuildTabs()
draw()
handleActive(hs.application.frontmostApplication())
