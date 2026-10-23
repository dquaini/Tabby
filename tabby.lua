-- =====================================================================
--  TABBY  ·  v9.39
--  Una barra con una scheda per ogni app e finestra: ne vedi una alla
--  volta, clicchi (o premi Ctrl+Option+1…9) per passare all'altra.
--  Storia delle versioni: docs/STORIA.md · Roadmap: docs/ROADMAP-v1.md
-- =====================================================================

-- Tabby è divisa in più file, nella cartella tabby/, caricati in quest'ordine.
-- Tutti condividono uno spazio comune di nomi (E): una funzione definita in un
-- file si usa direttamente negli altri. (Fino alla v9.21 era un file unico, ma
-- Lua accetta al massimo 200 nomi "locali" per file e ne usavamo già 176.)
local DIR = (debug.getinfo(1, "S").source or ""):match("^@(.*)/[^/]*$") or "."
local FILES = {
  "impostazioni", "base", "browser", "notifiche", "schede", "finestre", "memo",
  "dividi", "cartelle", "trascina", "menu", "disegno", "osservatori",
  "scorciatoie", "avvio",
}
local E = setmetatable({TABBY_DIR = DIR}, {__index = _G})
for _, name in ipairs(FILES) do
  local path = DIR .. "/tabby/" .. name .. ".lua"
  local chunk, err = loadfile(path, "t", E)
  if not chunk then error("Tabby: non riesco a leggere " .. path .. ": " .. tostring(err)) end
  chunk()
end
Tabby._env = E   -- tiene in vita lo spazio comune (e serve alla diagnosi dal Terminale)

hs.alert.show("Tabby v9.39 attiva")
