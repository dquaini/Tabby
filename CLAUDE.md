# Tabby — memoria di progetto per Claude Code

Tabby è una barra a schede per macOS: **ogni app (o finestra) è una scheda**, ne vedi
una alla volta, passi dall'una all'altra con un clic o con ⌃⌥ + numero. Pensata per
**nomadi digitali e chiunque lavori con un solo schermo**: semplice, ordinata, veloce.

Prima di lavorare leggi:
- `docs/PRODOTTO.md` — mission, cosa fa oggi, scelte prese, cosa migliorare
- `docs/ROADMAP-v1.md` — le funzioni decise per la v1, con specifiche e ordine
- `docs/SPECIFICA.md` — tutto il comportamento di oggi, regola per regola (base per l'app
  Swift): se cambi un comportamento, aggiornala
- `docs/CONDIVIDERE.md` — come installare Tabby su un altro Mac / darla ad altri

## Chi è l'utente (e come parlarci)

- Daniele, italiano. **Scrivi sempre in italiano**, semplice e concreto: non è uno
  sviluppatore. Niente gergo senza spiegarlo; spiega *cosa cambia per lui*.
- Usa Tabby tutto il giorno su due Mac: uno di casa e un **MacBook Air 13" 2025 col
  notch** (lavoro). Tiene **Tabby a destra** (posizione laterale), barra dei menu e
  Dock nascosti. Browser: **DuckDuckGo**. Al lavoro usa anche **Windows App** (desktop
  remoto), Slack, Notion, Claude.
- Itera veloce e dà feedback dall'uso reale. Quando una richiesta è ambigua, proponi
  un'interpretazione chiara e dilla esplicitamente (o chiedi, se cambia molto).
- Tiene molto alla qualità: "o fatto bene o meglio non averlo".
- **Come ci intendiamo** (nomi decisi con Daniele): **Lampi** = le app del menu ⚡︎ (Memo,
  Calcolatrice, Calendario, Terminale), piccole in alto a destra; nel codice "app veloci"
  (`QUICK`, `FLOATER`, `floating()`, `T.floatStack`). **Vista divisa** = schermo diviso in
  zone (nel codice "gruppo"). **Cartella** = spazio di lavoro salvato.

## Come è fatto il progetto

- `tabby.lua` — il punto di partenza (lo carica Hammerspoon): numero di versione e
  caricamento, in ordine, dei file della cartella **`tabby/`** (commenti in italiano):
  `impostazioni` (config: app veloci, browser, schemi, misure, colori) · `base` (stato T,
  impostazioni S, schermo, notch, utilità) · `browser` · `notifiche` · `schede` (ordine,
  ricette delle cartelle, `rebuildTabs`) · `finestre` (adattare, nascondere, passare da una
  scheda all'altra) · `memo` · `dividi` (vista divisa) · `cartelle` · `trascina` · `menu` ·
  `disegno` · `osservatori` · `scorciatoie` · `avvio`.
- **Come si scrive codice nei file di `tabby/`**: tutti condividono uno **spazio comune di
  nomi** (tabella `E`, `Tabby._env`). A livello del file si scrive `function nome()` /
  `nome = …` **senza `local`**: così il nome si usa direttamente negli altri file e non c'è
  il limite di Lua dei 200 nomi locali (che il file unico aveva quasi raggiunto). `local`
  solo dentro le funzioni, o per cose davvero private del file. L'ordine di `FILES` in
  `tabby.lua` conta: una funzione si può *chiamare* solo dopo che il suo file è caricato.
  Diagnosi dal Terminale: `hs -c "Tabby._env.nomeFunzione(...)"` o `Tabby.diag`.
- `test/` — il **Mac simulato**: `mock_hs.lua` è un finto Hammerspoon (app, finestre,
  canvas, timer, tastiera, AppleScript, Accessibilità, webview) in cui gira il vero
  `tabby.lua`; i `test_*.py` simulano l'uso (clic, trascinamenti, scorciatoie…).
  Eseguili con `test/run_all.sh` (serve `pip3 install lupa`). I test caricano Tabby con
  `test/aiuto.py` (`carica`, e `codice` per i controlli sul testo).
- Installazione sul Mac: `~/.hammerspoon/init.lua` deve caricare `tabby.lua` di questa
  cartella (vedi "Messa in funzione" sotto).

### Concetti chiave nel codice

- Stato globale in `Tabby` (alias `T`, globale perché Hammerspoon non "dimentichi"
  watcher e timer). Impostazioni salvate in `S`, persistite con `hs.settings` con
  prefisso storico `tabbar.`.
- Ogni scheda ha una **chiave**: bundle ID (app, o prima finestra normale di un
  browser) · `site:<dominio>` (webapp) · `win:<id>` (altre finestre di browser) ·
  `g:<n>` (gruppo = **vista divisa**) · `f:<n>` (scheda-cartella). `S.order` = ordine delle chiavi.
  `T.cand` (tutte le schede possibili), `T.keyWin`, `T.winKey`, `T.keyBid`, `T.memberOf`.
- `rebuildTabs()` ricostruisce le schede; `draw()` ridisegna la barra (un `hs.canvas`);
  `layout()` calcola le posizioni (orizzontale/verticale, compatto, "+N", notch).
- **Cartelle** (v9.8): funzioni nella tabella `FD`. `S.folders` = ricette
  (`items` = `{bid}` o `{site, bid}`), `S.activeFolders`, `T.viewFolder` (vista cartella),
  `T.allTabs` (tutte le schede) vs `T.tabs` (quelle visibili: su queste lavorano
  scorciatoie e clic), `T.tabFolder[chiave]`.
- **Nel codice "gruppo" = Vista divisa** (schermo diviso in zone). Il nuovo concetto
  "Cartella" della v1 è un'altra cosa: vedi roadmap. Rinominare `group` → `split` è
  una pulizia consigliata.
- Scorciatoie su `MODS = {"ctrl","alt"}` con doppio meccanismo (eventtap + hs.hotkey)
  e deduplica (`fire`), per app che catturano la tastiera (Windows App).
- Notch: `detectNotch()` (JXA → NSScreen), `useNotchBand()`, `placeBar()` alza il
  livello della finestra di Tabby se macOS la spinge sotto la fascia del notch.
- Browser: AppleScript **in parallelo** con `hs.task` + osascript (Chrome/Brave/Edge/Safari;
  attenzione: dentro `tell application` la parola `tab` è la scheda, usare `TB`) o Accessibilità (DuckDuckGo, che non
  ha AppleScript) per sapere i siti di ogni finestra; loghi da icons.duckduckgo.com →
  Google; notifiche dal Dock (AXStatusLabel) e dai titoli delle webapp.

## Regole di lavoro

1. **Ogni modifica si prova sul Mac simulato** (`test/run_all.sh`) prima di dire che
   è fatta. Se aggiungi una funzione, aggiungi o estendi un test. Se il simulatore non
   sa fare qualcosa, estendi `mock_hs.lua`.
2. Poi **verifica sul Mac vero**: ricarica Hammerspoon e leggi la console (vedi sotto).
   Il simulatore non sostituisce il Mac: comportamenti di macOS (notch, livelli delle
   finestre, permessi, app che "rimbalzano") si vedono solo lì.
3. Codice e commenti **in italiano**, chiari per un non sviluppatore che li legge.
4. Le righe di diagnosi in console iniziano con `Tabby ·` (es. notch, DuckDuckGo,
   app veloci, `Tabby · lento:` per i lavori sopra i 150 ms): usale per capire problemi reali invece di tirare a indovinare.
5. Non cambiare scorciatoie o comportamenti a cui l'utente è abituato senza dirlo.
6. Usa git: un commit per ogni versione funzionante, messaggio in italiano. A ogni
   versione: numero in `tabby.lua` (in testa e nell'avviso `hs.alert` in fondo), riga in
   `docs/STORIA.md`, "Versione attuale" qui sotto.
7. **GitHub** (privato: `git@github.com:dquaini/Tabby.git`, ramo `main`): all'inizio di
   ogni sessione `git pull` (l'altro Mac può aver aggiunto versioni); dopo ogni commit
   `git push`, così i due Mac hanno sempre la stessa Tabby. Ogni Mac ha la sua chiave SSH
   (`~/.ssh/id_ed25519`, aggiunta su github.com/settings/keys).

## Messa in funzione (prima volta in Claude Code)

1. Metti questa cartella dove l'utente preferisce (es. `~/Progetti/Tabby`) e fai
   `git init` + primo commit.
2. Fai caricare Tabby da Hammerspoon: `~/.hammerspoon/init.lua` diventa
   ```lua
   require("hs.ipc")                       -- permette di comandare Hammerspoon dal Terminale
   dofile(os.getenv("HOME") .. "/Progetti/Tabby/tabby.lua")
   ```
   (adatta il percorso). Prima salva una copia del vecchio `init.lua`.
3. Installa il comando `hs` (una volta, dalla console di Hammerspoon:
   `hs.ipc.cliInstall()`), così puoi:
   - ricaricare Tabby: `hs -c "hs.reload()"`
   - leggere la console: `hs -c "hs.console.getConsole()"` (cerca le righe `Tabby ·`)
   - interrogare lo stato: es. `hs -c "hs.inspect(Tabby.bf)"`
4. Esegui `test/run_all.sh` per controllare che tutto sia verde.

**Stato (20/10/2026, Mac di casa, 1440×900 senza notch):** fatto. La cartella è
`~/Desktop/pErsoNal/Projects/Tabby/Tabby 2` (spostata lì il 23/10/2026); `init.lua` la carica (vecchio in `~/.hammerspoon/init.lua.backup-2026-10-20`).
Il comando `hs` è in `~/.local/bin` (in `PATH` da `~/.zshrc`); se non si trova, usa
`/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs`. A volte la prima chiamata
dà "receive timeout": ripeterla. Collegato a GitHub il 22/10/2026 (chiave "Mac di casa").
Sul MacBook col notch la messa in funzione va rifatta: chiave SSH nuova da aggiungere su
GitHub, poi `git clone git@github.com:dquaini/Tabby.git` e `init.lua` che punta lì.

## Versione attuale

**v9.49** (storia in `docs/STORIA.md`). Prossimo obiettivo: **Tabby v1** (A fatta; B Cartelle: base fatta in v9.8, restano "Apri all'avvio" e rifiniture)
(`docs/ROADMAP-v1.md`).
