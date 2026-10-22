# Tabby — il prodotto

## Mission

**Il nuovo spazio di lavoro d'avanguardia per l'era dell'AI e degli agenti.**
Tabby non è "una barra di schede": è il posto dove persone e agenti lavorano
insieme sullo stesso schermo. Per le persone: semplice ed efficiente con un solo
schermo (nomadi digitali, portatile): niente finestre sovrapposte, niente caccia
all'app giusta, una cosa alla volta a tutto spazio. Per gli agenti: ogni finestra,
sito, vista divisa e cartella è un oggetto con un **nome e una chiave stabile**,
che un agente può riconoscere e comandare ("metti il contratto a sinistra e Gmail
a destra", "prepara lo spazio per la call").

Conseguenza pratica: ogni funzione nuova va pensata **due volte**, per chi usa
Tabby con mouse e tastiera e per un agente che la userà come strumento (nomi
chiari, stato leggibile, azioni ripetibili).

Principi:
- **Una cosa alla volta**, a tutto spazio. Due o più solo quando lo scegli (vista divisa).
- **Zero attrito**: scorciatoie coerenti (tutte ⌃⌥), tutto a un clic, niente da configurare per partire.
- **Ordine, non chiusura**: le app restano aperte; Tabby decide solo cosa vedi.
- **Fatto bene o niente**: meglio una funzione in meno che una che peggiora l'uso.
- **Pensato per il portatile**: schermo piccolo, notch, batteria, trackpad.

## Cosa fa oggi (v9.3)

### Schede
- **Una scheda alla volta**: le altre app si nascondono e le altre finestre della stessa app
  (es. un'altra finestra di Chrome) si riducono a icona; tornano quando le scegli. Restano
  insieme le finestre di una vista divisa e il video in miniatura di Meet.
- Una scheda per ogni **finestra** (Finder, TextEdit, Word…): con più finestre ognuna prende
  il titolo (nome del documento o della cartella). ⚙︎ → Finestre separate: per app, si può
  tornare a una scheda sola. Ne vedi una alla volta (le altre app si nascondono).
- Le finestre si adattano allo spazio libero accanto a Tabby.
- Riordino trascinando; le **preferite** vanno in cima quando le apri.
- Tante app: schede che si stringono → solo icone (l'attiva resta larga) → menu **"+N"**.
- ✕ su una scheda: "Chiudi finestra" o "Chiudi <app>".
- Tasto **scrivania**: nasconde tutto; ripremuto, torna all'ultima scheda.

### Browser (Chrome, Brave, Edge, Safari, DuckDuckGo)
- **Ogni finestra è una scheda.**
- Finestra con **un solo sito** → **webapp** con nome e logo (Gmail, Notion, Proton Mail…).
- Altre finestre → "Chrome", o il titolo della finestra se più d'una.
- Chrome & co.: via AppleScript (la prima volta macOS chiede il permesso "Automazione").
  Le finestre si abbinano per titolo, inizio del titolo (Chrome con più profili aggiunge
  "- Profilo") o posizione. In console: `Tabby · Chrome «…»: abbinata per …`, e un
  avviso se il permesso Automazione manca.
- DuckDuckGo: senza AppleScript, letto via Accessibilità; webapp solo se la finestra ha
  **una sola scheda**; ricorda i siti anche quando è nascosto.

### Cartelle (dal menu ⚡︎) — spazi di lavoro salvati
- ⚡︎ → **Nuova cartella…** → nome → riquadro con già la scheda in cui sei; ci trascini (o
  clicchi) le altre schede; Invio/Fatto. La cartella ricorda **app e webapp** (non i numeri
  di finestra), quindi vale anche dopo un riavvio.
- **Attivarla** (menu ⚡︎ o ⌃⌥⇧ + numero): apre quello che manca senza portartelo davanti
  (webapp di Chrome/Safari in una finestra nuova; DuckDuckGo come scheda); quello già aperto
  entra. Se sei su una sua app → vista cartella; se sei altrove → la cartella diventa **una
  scheda sola** (3 icone, somma delle notifiche) e resti dove sei.
- Una **finestra di Chrome/Safari con più pagine** messa in una cartella si ricorda le sue
  pagine e, se non è aperta, si riapre con tutte. (DuckDuckGo: solo il browser.)
- **Vista cartella**: solo le sue schede, nome in cima (o a sinistra), «←» per tornare.
  ⌃⌥1…9 contano solo le schede visibili. Un'app aperta fuori cartella si vede nella vista generale.
- ⋯ sulla scheda-cartella: Apri · Esci dalla cartella · **Chiudi cartella** (chiude le sue app;
  per i browser solo le sue finestre) · Modifica · Rinomina. ⚙︎ → Comportamento → **Vista
  cartelle** spenta: attivare = solo aprire le app, schede normali.

### Vista divisa (tasto ⊞) — nel codice "gruppo"
- Schemi: 2 (50/50, 70/30), 3 (una sopra, due sotto), 4 (quarti).
- Si trascinano le schede nelle zone (o clic → prima zona libera); zone piene → nasce
  una **scheda unica** con le icone affiancate e tasto **Scomponi**.
- Più viste divise insieme, salvate; app chiusa → la vista si riduce; una sola → scheda normale.

### Notifiche e batteria
- Pallino rosso con il numero: dal Dock per le app, dal titolo per le webapp; somma sulle viste divise.
- Batteria: verde ≥80%, normale, rossa <35% se non in carica, ⚡︎ in carica.

### Azioni veloci (tasto ⚡︎)
- **Memo** (⌃⌥M): blocco note piccolo in alto a destra, si salva da solo in
  `~/Documents/Tabby Memo.txt`; Esc per chiudere. Voce "Mostra il file del Memo nel Finder".
- **Calcolatrice** (⌃⌥C) in alto a destra, Esc per chiudere. **Spotlight**.

### Scorciatoie (tutte ⌃⌥ = Ctrl + Option)
| Tasti | Azione |
|---|---|
| ⌃⌥1…9 | vai alla scheda 1…9 |
| ⌃⌥0 | scrivania (ripremi per tornare) |
| ⌃⌥← / → (↑ / ↓ se laterale) | scheda precedente / successiva |
| ⌃⌥Tab | scheda usata prima |
| ⌃⌥S | Scambia: ruota le app della vista divisa |
| ⌃⌥⇧1…9 | attiva la cartella 1…9 |
| ⌃⌥M · ⌃⌥C · ⌃⌥A | Memo · Calcolatrice · Calendario |
| Esc | chiude Memo / Calcolatrice; annulla la divisione |
| ⌘⌃⌥R | ricarica Tabby |

Funzionano anche in app che catturano la tastiera (Claude, Windows App), con doppio meccanismo.

### Aspetto e adattamento
- Posizione: in alto, in basso, a sinistra, a destra.
- "Nascondi Tabby": appare portando il mouse sul bordo.
- Pallino verde (schermo intero) → l'app riempie lo spazio **con Tabby visibile** (opzione).
- **Notch** (MacBook recenti): con barra dei menu nascosta Tabby occupa la fascia del
  notch e le schede ci saltano sopra; se il mouse va in cima, Tabby si fa da parte per la
  barra dei menu. Interruttore manuale "Usa la fascia del notch".
- Impostazioni (⚙︎): Posizione · App preferite · Comportamento (una app alla volta,
  adatta finestre, schermo intero con Tabby, nascondi Tabby, app senza finestre) ·
  Chiudi tutte le app · Ricarica · Console.

## Cosa si può migliorare in quello che c'è

**Esperienza**
- Avvio a vuoto poco accogliente (→ schermata di partenza, roadmap v1).
- Tabby non nasconde ancora da sola Dock e barra dei menu (→ configurazione guidata).
- Pallino verde: piccolo "rimbalzo" (macOS entra ed esce dallo schermo intero).
- Esc nella Calcolatrice non azzera più il conto (si usa il tasto C).
- La fascia del notch resta vuota se Tabby non è in alto (limite di macOS per le finestre).

**Funzioni**
- DuckDuckGo: webapp solo con finestra a scheda singola; non si possono aprire siti in
  finestre nuove via script (documentare: "funzione completa con Chrome/Safari").
- Viste divise con finestre di browser (`win:`) si perdono al riavvio delle app.
- Un solo monitor (Tabby usa lo schermo principale).
- Il Memo è un solo foglio.

**Da verificare sul Mac vero** (provato solo sul simulatore)
- Memo: apertura, scrittura, focus della tastiera.
- Riserva delle scorciatoie dentro Windows App.
- Rilevamento DuckDuckGo su siti diversi (righe `Tabby · DuckDuckGo` in console).

**Codice**
- ~~Un solo file: dividerlo in moduli~~ fatto in v9.22 (cartella `tabby/`).
- Rinominare "gruppo" → "vista divisa" (`split`) nel codice; prefisso impostazioni `tabbar.`.
- Polling ogni 3 s (AppleScript browser, notifiche Dock): valutare eventi o frequenze adattive.

## Futuro oltre la v1 (idee raccolte)

- **App vera in Swift**: si scarica, si installa, si aggiorna; impostazioni in una finestra.
- **Claude dentro Tabby**: (1) Claude tra le azioni veloci; (2) chat con contesto della
  finestra/selezione via API; (3) **agente** che usa le funzioni di Tabby come strumenti
  ("mettimi Gmail e Slack affiancati", "prepara lo spazio di lavoro").
- **Ricerca veloce** (⌃⌥Spazio): schede, app, web.
- **Modalità concentrazione**: timer che nasconde le app che distraggono.
- **Più monitor**.
- **Fascia del notch utile** anche con Tabby non in alto (batteria, tasti rapidi).
- **Sincronizzazione impostazioni** tra Mac via iCloud.
