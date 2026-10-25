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

## 🧭 Decisione del 23/10/2026: finire in Hammerspoon, poi l'app Swift
Hammerspoon resta il "laboratorio" (correzioni in minuti, 21 gruppi di test). Si finiscono
qui le funzioni piccole o riusabili, si usa Tabby 1-2 settimane sui due Mac (soprattutto quello
di lavoro col notch), si scrive la **specifica completa del comportamento**, poi si rifà Tabby
come **app Swift** (installabile e condivisibile, senza Hammerspoon) con design, avvio,
configurazione guidata e Dock fatti direttamente lì.

**Ancora in Hammerspoon** (lista di Daniele):
- ✅ **Memo** con elenchi puntati, cose da fare (to do) e sezioni apribili (toggle): fatto in
  v9.50 (`tabby/memo.html`, pagina web riusabile tale e quale nell'app Swift).
- ✅ **Batteria senza percentuale** (la percentuale al passaggio del puntatore): v9.49.
- ✅ **Gatto intero** al posto della testa quando Tabby è a destra o a sinistra: v9.37.

**Piano accettato da Daniele il 23/10/2026**: 1-2 settimane di uso vero sui due Mac (con
correzioni qui), intanto la specifica completa — fatta: `docs/SPECIFICA.md` — poi l'app Swift
(prima il motore con lo stesso comportamento, poi design, avvio, configurazione guidata, Dock).
Come condividerla oggi e domani: `docs/CONDIVIDERE.md`.

**Direttamente nell'app Swift**: animazione d'avvio, icona di Tabby
nelle finestre (cartelle), redesign, colori a scelta, configurazione guidata, Dock.

**Lampi di Tabby** (deciso il 23/10/2026): nell'app Swift Tabby avrà **una decina di Lampi
suoi**, piccole "smart app" semplicissime fatte da Tabby (sempre davanti, stesso stile, in
fila nella colonna dei Lampi): per esempio Calcolatrice, Note/Memo, Timer e Pomodoro,
Cronometro, Convertitore (valute e unità), Appunti (ultime cose copiate), Agenda del giorno,
Traduttore rapido, Meteo, Lista veloce di cose da fare. *Perché:* macOS non permette di
tenere sopra le finestre di un'altra app (Calcolatrice, Calendario di Apple…); con Lampi
propri il problema sparisce (oggi in Hammerspoon c'è il ripiano dei Lampi coperti nella
barra, v9.47).

## ▶ Prossimi passi, in ordine

### 1. Stabilità e velocità *(adesso)*
- DuckDuckGo con più schede rallenta Tabby fino a ~0,7 s ("lento: ricostruzione schede",
  "controllo browser"); "cambio di scheda" fino a 1,1 s.
- Controllo generale dopo le tante novità del 21–22/10 (una scheda alla volta, finestrelle,
  cartelle), con l'aiuto della console.

### 2. Cartelle, seconda parte
- ✅ **Finestra di browser con più siti** dentro una cartella (v9.23): si ricordano le pagine
  (senza la parte dopo "?" e "#") e si riaprono come schede di una finestra nuova (Chrome,
  Safari). DuckDuckGo non dice gli indirizzi delle sue schede: una sua finestra resta
  "DuckDuckGo" (si riapre il browser, non le pagine).
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
- ✅ **Scrivania**: sul desktop Tabby diventa un **cerchio in basso a destra** col gatto;
  cliccato riapre l'ultima finestra o propone «+ Nuova app» e le cartelle (v9.51).
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
  tornare alla scheda di prima (come ⌃⌥→ / ⌃⌥←, ⌃⌥Tab). **Esplorato il 23/10**: Tabby vede i
  tocchi con 1-4 dita (eventi "gesture" con l'elenco dei tocchi), gli scorrimenti e il
  pizzico. Un gesto a 3-4 dita già usato da macOS lo farebbero entrambi: va tolto a macOS
  (Impostazioni → Trackpad → Altri gesti). Proposta da decidere con Daniele.
- ✅ **Chiudere la finestra senza chiudere l'app** (22/10): **⌃⌥W** (fatto in v9.25).

- **Icone della barra dei menu dentro Tabby** (22/10). **Esplorato il 23/10** sul Mac: le
  hanno Centro di Controllo (batteria, Wi-Fi, Bluetooth, audio/video, orologio), Spotlight,
  Claude, Proton VPN, Hammerspoon, Notion (solo quando l'app è aperta); tutte si possono
  "premere" (AXPress). Notion apre un menu leggibile con azioni e scorciatoie (Toggle Command
  Search ⌘⇧K, Toggle Notion AI ⌘⇧J); Claude apre qualcosa che non è un menu leggibile
  (chat rapida); Proton VPN apre un pannello. Due tipi di azioni in ⚡︎: (1) aprire l'icona
  di un'app (serve che l'icona resti nella barra di Apple, anche nascosta); (2) lanciare
  direttamente un'azione con scorciatoia (funziona anche togliendo l'icona). Testo originale: le icone in alto a destra di macOS
  (Notion, Claude, VPN, Bluetooth, Wi-Fi…) nel menu ⚡︎ con una scorciatoia ciascuna.
  Obiettivo di Daniele: *in Tabby tutto ciò che è possibile, nella barra dei menu di Apple
  solo il resto.* Tecnicamente: Tabby le legge e le "preme" con l'Accessibilità
  (AXExtrasMenuBar); da provare con la barra dei menu nascosta. Nasconderle da Apple
  (Impostazioni → Barra dei menu) potrebbe toglierle anche a Tabby: da verificare.

## 🔭 Dopo la v1

- **Schermo intero con Tabby visibile** (tolto il 23/10/2026): il tasto verde riempiva lo
  spazio accanto a Tabby invece dello schermo intero di macOS, ma non funzionava con tutte
  le app (rimbalzo). Da ripensare con calma.

### Automazione e agenti (secondo filone, deciso il 22/10/2026)
- **"Apri all'avvio"** delle cartelle e altre automazioni (spazi di lavoro che si preparano
  da soli), pensate anche come azioni che un agente può usare.

- **Colori di Tabby a scelta** (temi), insieme al design: i colori sono nella tabella `COL`.
- **Concentrazione**: fatta in v9.55 (SPECIFICA 16b).
- **Cerca nelle finestre** (⌃⌥F): fatta in v9.57 (SPECIFICA 16c), dopo la prova di misura
  del 25/10/2026 (0,1–0,2 s per finestra, testo letto anche dalle app nascoste).
- Dalla mission (`PRODOTTO.md`): Claude/agente dentro Tabby,
  più monitor, app vera in Swift, impostazioni sincronizzate.
