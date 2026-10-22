-- =====================================================================
--  Tabby · impostazioni.lua: le impostazioni di base: app veloci, browser, schemi della vista divisa, misure e colori.
--  Fa parte di Tabby: lo carica tabby.lua e condivide con gli altri file
--  tutti i nomi (una funzione definita qui si usa direttamente altrove).
-- =====================================================================

-- ---------------------------------------------------------------------
--  IMPOSTAZIONI DI BASE
--  (preferite e opzioni si gestiscono dal tasto ⚙︎ di Tabby;
--  questi valori servono solo al primo avvio)
-- ---------------------------------------------------------------------

DEFAULTS = {
  position        = "top",   -- dove sta Tabby: top / bottom / left / right
  pinned          = { "com.apple.finder", "com.apple.iCal", "com.apple.Notes" },
  oneAtATime      = true,    -- una scheda alla volta: nasconde le altre app e finestre
  fit             = true,    -- adatta le finestre a Tabby
  autohide        = false,   -- Tabby nascosta, appare col mouse sul bordo
  showWindowless  = false,   -- mostra anche app aperte ma senza finestre
  notchBand       = "auto",  -- Tabby nella fascia del notch: "auto" / "on" / "off"
  order           = {},      -- ordine delle schede (si aggiorna trascinandole)
  groups          = {},      -- gruppi di app con lo schermo diviso
  groupSeq        = 0,
  joinWins        = {},      -- app con tutte le finestre in una sola scheda
  folders         = {},      -- cartelle: {id, name, items = {{bid, site, name}}}
  folderSeq       = 0,
  activeFolders   = {},      -- cartelle attivate (sulla barra come scheda unica)
  folderView      = true,    -- ⚙︎ → Comportamento → Vista cartelle
  spotlightDim    = true,    -- con Spotlight aperto lo sfondo si oscura
  gestures        = true,    -- tre dita a destra / sinistra cambiano scheda
}

-- App da non mostrare mai come scheda
IGNORE = {
  ["org.hammerspoon.Hammerspoon"] = true,
}

-- Tutte le scorciatoie di Tabby usano questi tasti, più un altro tasto:
-- ⌃⌥1…9 schede, ⌃⌥0 scrivania, ⌃⌥← → scheda prima/dopo,
-- ⌃⌥Tab app di prima, ⌃⌥C calcolatrice, ⌃⌥M memo.
MODS = {"ctrl", "alt"}

-- App "veloci" (tasto ⚡︎): si aprono piccole in alto a destra, sopra
-- l'app che stai usando, senza nasconderla. Stessa scorciatoia per
-- aprirle e chiuderle, Esc per chiuderle. "key" va premuto insieme a ⌃⌥.
-- (memo = true è il Memo di Tabby, non un'app)
QUICK = {
  {memo = true, name = "Memo", key = "m"},
  {bid = "com.apple.calculator", name = "Calcolatrice", key = "c"},
  -- il Calendario si apre piccolo (w × h: la misura minima che accetta, vista
  -- sul Mac); A come "Agenda" (C è della Calcolatrice)
  {bid = "com.apple.iCal", name = "Calendario", key = "a", w = 680, h = 520},
}

-- Azioni rapide delle app (menu ⚡︎ → App): quelle che alcune app offrono con la
-- loro icona nella barra dei menu di macOS, portate in Tabby (idea di Daniele:
-- averle solo in Tabby). "keys" = la scorciatoia dell'app: funziona anche
-- togliendo la sua icona dalla barra di Apple. "menubar" = Tabby preme l'icona
-- dell'app nella barra dei menu. "key" va premuto insieme a ⌃⌥.
APP_ACTIONS = {
  {bid = "com.anthropic.claudefordesktop", name = "Claude · chat rapida", key = "l", menubar = true},
  -- Notion: le sue scorciatoie (⌘⇧K, ⌘⇧J) valgono solo dentro Notion; da fuori
  -- si usa la voce del menu della sua icona (menuItem)
  -- (se l'icona è spenta in macOS il menu non si apre: riserva = Notion davanti
  -- con la sua scorciatoia, "fallbackKeys")
  {bid = "notion.id", name = "Notion · cerca", key = "n", menubar = true, menuItem = "Toggle Command Search",
   fallbackKeys = {{"cmd", "shift"}, "k"}},
  {bid = "notion.id", name = "Notion AI", key = "i", menubar = true, menuItem = "Toggle Notion AI",
   fallbackKeys = {{"cmd", "shift"}, "j"}},
}

-- Il Memo si salva da solo in questo file (lo trovi nel Finder e con Spotlight)
MEMO_FILE = os.getenv("HOME") .. "/Documents/Tabby Memo.txt"

-- Browser: ogni finestra diventa una scheda. Una finestra con un solo sito
-- diventa una "webapp" (nome e logo del sito); più finestre normali si
-- chiamano A, B, C… (as = nome per AppleScript)
BROWSERS = {
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
LAYOUTS = {
  ["2-50"] = {name = "Due app · metà e metà",
              zones = {{0, 0, .5, 1}, {.5, 0, .5, 1}}},
  ["2-70"] = {name = "Due app · 70 / 30",
              zones = {{0, 0, .7, 1}, {.7, 0, .3, 1}}},
  ["3"]    = {name = "Tre app · una sopra, due sotto",
              zones = {{0, 0, 1, .5}, {0, .5, .5, .5}, {.5, .5, .5, .5}}},
  ["4"]    = {name = "Quattro app · un quarto ciascuna",
              zones = {{0, 0, .5, .5}, {.5, 0, .5, .5}, {0, .5, .5, .5}, {.5, .5, .5, .5}}},
}
LAYOUT_ORDER = {"2-50", "2-70", "3", "4"}
LAYOUT_FOR_COUNT = {[2] = "2-50", [3] = "3", [4] = "4"}
ZONE_GAP = 3     -- spazio tra le finestre divise (per lato)

BAR_H = 38          -- altezza di Tabby (in alto / in basso)
SIDE_W = 190         -- larghezza di Tabby (a sinistra / a destra)
ROW_H = 36          -- altezza di una scheda quando Tabby è laterale
TAB_MAX_W = 210         -- larghezza massima di una scheda
BTN_W = 44          -- dimensione dei tasti scrivania / ⊞ / ⚡︎ / ⚙︎
BAT_W = 76          -- spazio per l'indicatore della batteria
-- Con tante app aperte:
COMPACT_BELOW = 120     -- sotto questa larghezza le schede diventano solo icona
ICON_W = 44          -- larghezza di una scheda "solo icona"
ACTIVE_W = 160         -- la scheda attiva resta larga, col nome
MIN_ROW_H = 26          -- altezza minima di una scheda in verticale
FINDER = "com.apple.finder"

COL = {
  bar     = {hex = "#000000"},   -- nero pieno (richiesta di Daniele, 22/10/2026)
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
