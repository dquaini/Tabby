# Tabby v1 — roadmap

Aggiornata il 22/10/2026 con Daniele. Mission: lo spazio di lavoro per persone e agenti AI
(vedi `PRODOTTO.md`). Nomi: **Cartella** = spazio di lavoro salvato; **Vista divisa** =
schermo diviso in zone (nel codice "gruppo").

---

## ✅ Fatto (v9.4 → v9.18)

- **Revisione e velocità** (v9.4–9.7): viste divise che seguono le finestre, loghi ritentati,
  spia `Tabby · lento`, app cercate per bundle ID, domande ai browser in parallelo, privacy
  (DuckDuckGo: solo il sito, mai l'indirizzo completo).
- **A. Più schede per qualsiasi app** (v9.5): una scheda per finestra, nome = titolo;
  ⚙︎ → Finestre separate per app.
- **Chrome e browser** (v9.6–9.13): webapp riconosciute con profili e titoli diversi, niente
  icone che lampeggiano, niente schede scambiate con più finestre, Google Meet (la miniatura
  resta visibile).
- **B. Cartelle, prima parte** (v9.8, storia di Daniele del 21/10): si creano e attivano dal
  menu ⚡︎ (o ⌃⌥⇧ + numero); attivata = una scheda sola con 3 icone; clic = scegli l'app e si
  entra nella vista cartella; Esci / Chiudi / Modifica / Rinomina; ⚙︎ → Vista cartelle.
  Prototipo: `docs/prototipo-cartelle.html`.
- **Rifiniture** (v9.11–9.18): scheda **+** (Spotlight); **Scambia** nella vista divisa (⇄,
  ⌃⌥S); il **gatto** sul tasto scrivania; **velo scuro** con Spotlight (85%, reattivo);
  **una scheda alla volta** anche tra finestre della stessa app (senza ping-pong, finestre di
  accesso escluse, ⌘W torna alla finestra di prima); **Calendario veloce** (⌃⌥A); barra
  **nera**; ⌘F dopo il clic su una scheda.
- **GitHub** privato `dquaini/Tabby`: i due Mac aggiornati con un comando.

---

## ▶ Prossimi passi, in ordine

### 1. Stabilità e velocità *(adesso)*
- DuckDuckGo con più schede rallenta Tabby fino a ~0,7 s ("lento: ricostruzione schede",
  "controllo browser"); "cambio di scheda" fino a 1,1 s.
- Controllo generale dopo le tante novità del 21–22/10 (una scheda alla volta, finestrelle,
  cartelle), con l'aiuto della console.

### 2. Cartelle, seconda parte
- **Finestra di browser con più siti** dentro una cartella: si ricordano le pagine (indirizzo
  senza la parte dopo "?", dove possono finire codici di accesso) e si riaprono come schede di
  una finestra (Chrome/Safari; con DuckDuckGo come schede in una finestra esistente).
- Trascinare una scheda sopra la scheda-cartella per aggiungerla (da confermare con Daniele
  se serve: oggi si aggiunge da ⚡︎ → Modifica le cartelle).

### 3. Avvio e design *(un blocco unico: stessa identità, nero e gatto)*
**Avvio** (storia di Daniele, versione 2 del 22/10 — prototipo v1: `docs/prototipo-avvio.html`):
1. All'avvio di Tabby: schermo **nero**, al centro l'animazione `assets/avvio/1-logo.mp4`
   (10 s), **centrata e più piccola** (non a tutto schermo); intanto Tabby carica.
2. Finita, un clic fa partire `assets/avvio/2-gatto.mp4`; alla fine al centro resta **solo il
   riquadro tratteggiato** (nessun logo).
3. Clic sul riquadro: **primo accesso** → Spotlight; **dopo** → pannello con le cartelle, o un
   pulsante per Spotlight se non ce ne sono.
4. In alto a destra solo l'**icona bianca delle impostazioni**.
5. Scelta la prima app, Tabby parte con barra e scorciatoie.
6. Video **senza suono**; il marchio "KlingAI 4.0" in basso a destra **si ritaglia**.
7. Proposte da confermare: compare solo all'avvio (non ai ricaricamenti); Esc salta.

**Design**:
- **Scrivania**: sul desktop Tabby diventa un **pallino in basso a destra** col gatto; cliccato
  riapre l'ultima app.
- **Finestre di dialogo di Tabby** con l'icona del gatto (bianco su quadrato nero con angoli
  morbidi), al posto di quelle di Hammerspoon col martello. La stessa icona sarà l'icona
  dell'app.
- **Batteria compatta**: solo l'icona; la percentuale al passaggio del puntatore.
- **Revisione dell'aspetto** di tutta Tabby (schede, tasti, menu, riquadri, velo), con un
  prototipo cliccabile prima.

### 4. Configurazione guidata e Dock
- Al primo avvio: permessi (Accessibilità, Automazione per i browser), barra dei menu e Dock
  nascosti (con consenso), avvio di Hammerspoon al login, posizione di Tabby.
- **Tabby sostituisce il Dock** (confermato): lo nasconde da sola, con ripristino dalle
  impostazioni. Verificare che le notifiche (lette dal Dock) funzionino con il Dock nascosto.

### 5. Guida → **v1 chiusa**
- Foglio delle scorciatoie dentro Tabby (⌃⌥? e voce "Guida"), guida utente in italiano,
  tabella di cosa funziona con ogni browser.

---

## 📥 In attesa (da collocare)

- **Gesti del trackpad** (22/10): un gesto per passare alla scheda dopo/prima e uno per
  tornare alla scheda di prima (come ⌃⌥→ / ⌃⌥←, ⌃⌥Tab). Da verificare cosa si può: i gesti
  a 3-4 dita li usa già macOS (Mission Control, cambio scrivania); Hammerspoon vede alcuni
  gesti ma non tutti. Possibilità: scorrimento a due dita sopra la barra di Tabby, o gesti
  liberati togliendoli a macOS (Impostazioni → Trackpad).
- **Chiudere la finestra senza chiudere l'app** (22/10): scorciatoia per chiudere solo la
  finestra/scheda attiva (come ✕ → "Chiudi finestra"). Proposta **⌃⌥W**.

- **Icone della barra dei menu dentro Tabby** (22/10): le icone in alto a destra di macOS
  (Notion, Claude, VPN, Bluetooth, Wi-Fi…) nel menu ⚡︎ con una scorciatoia ciascuna.
  Obiettivo di Daniele: *in Tabby tutto ciò che è possibile, nella barra dei menu di Apple
  solo il resto.* Tecnicamente: Tabby le legge e le "preme" con l'Accessibilità
  (AXExtrasMenuBar); da provare con la barra dei menu nascosta. Nasconderle da Apple
  (Impostazioni → Barra dei menu) potrebbe toglierle anche a Tabby: da verificare.

## 🔭 Dopo la v1

### Automazione e agenti (secondo filone, deciso il 22/10/2026)
- **"Apri all'avvio"** delle cartelle e altre automazioni (spazi di lavoro che si preparano
  da soli), pensate anche come azioni che un agente può usare.

- **Colori di Tabby a scelta** (temi), insieme al design: i colori sono nella tabella `COL`.
- Dalla mission (`PRODOTTO.md`): Claude/agente dentro Tabby, ricerca veloce, concentrazione,
  più monitor, app vera in Swift, impostazioni sincronizzate.
