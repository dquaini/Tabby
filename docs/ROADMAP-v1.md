# Tabby v1 — roadmap

Aggiornata il 31/10/2026 con Daniele (versione attuale **v9.65**). Mission: lo spazio di
lavoro per persone e agenti AI (vedi `PRODOTTO.md`). Il comportamento di oggi, regola per
regola, è in `SPECIFICA.md`; la storia delle versioni in `STORIA.md`.

Nomi decisi: **Cartella** = spazio di lavoro salvato · **Vista divisa** = schermo diviso in
zone (nel codice "gruppo") · **Lampi** = le app piccole del menu ⚡︎ (nel codice "app veloci").

---

## ▶ Le fasi del prodotto (decise con Daniele il 12/11/2026)

L'app Swift ha raggiunto Hammerspoon (0.10, 10/11/2026). Da qui il vero sviluppo, in ordine:

### Fase 1 — Tabby (in corso)
L'app che mostra le finestre come schede su macOS, con gli strumenti che la completano. È
**finita** quando: funziona sul MacBook di lavoro (Windows App, notch, Tabby a destra, Notion,
riunioni) e passa una settimana d'uso vero su tutti e due i Mac senza bug nuovi.
1. ✅ (0.11) Menu ⚡︎: «Personalizza i Lampi» sotto i Lampi, via «Tutte le App», «Modifica o
   elimina…» delle cartelle che funziona. Menu ⚙︎: via «Tabby…» (c'è già la ricerca); «Chiudi le
   app» → Tutte / Solo quelle senza finestre. Pausa tolta da tutta l'app. Margine a destra.
2. **Il MacBook di lavoro** (guida in `CONDIVIDERE.md`).
3. **Centro di controllo** (bozza mostrata il 12/11/2026: tessere **componibili e scomponibili** — «modifica →» nel pannello: togli, riordina trascinando, aggiungi; un clic sulla parola sottolineata cambia città, app della musica, titoli della borsa; la **borsa è una tessera**) al posto della batteria: tasto col **cruscotto**
   (`gauge.with.dots.needle.67percent`; puntino rosso con batteria sotto il 20% e non in carica;
   niente ora, c'è già nella barra di Apple). Un clic apre un pannello: batteria; **meteo** coi
   giorni (Open-Meteo, gratis; **città scritta da Daniele** la prima volta, poi nelle Impostazioni);
   **musica** (Spotify e Musica con titolo e comandi; Tidal solo coi tasti multimediali; l'app si
   sceglie nelle Impostazioni fra quelle installate); **processore, memoria, GPU**; **tempo
   d'uso per app** contato da Tabby (quello di macOS non si legge). A pannello chiuso consumo zero.
4. 🧪 (0.12, in prova) **Selettore con le anteprime** (stile AltTab): ⌃⌥ tenuti + Tab ripetuto, con le miniature.
   Serve «Registrazione dello schermo»; le finestre nascoste non si fotografano, quindi la
   miniatura è l'ultima vista (foto presa quando lasci la scheda). Un Tab solo = scheda di prima.
5. **Borsa** nel centro di controllo: Yahoo Finance (non ufficiale, senza chiave; Apple non dà
   accesso); solo a pannello aperto, al massimo ogni 15 min; se smette: «borsa non disponibile».

### Fase 2 — Tabby Search
La barra che cerca tutto, con le sinergie di Tabby e le funzioni utili di Raycast (vedi la lista
«Tabby come alternativa a Raycast e AltTab» più sotto): appunti, calcoli e conversioni, file,
comandi del Mac, link rapidi, testi pronti, Claude, agenda…

### Fase 3 — Automazione
Le cartelle che si aprono da sole (all'ora giusta, all'accensione…), comandi dal Terminale.

### Fase 4 — Kat
Una cartella del Mac legata a Tabby (Memo, file, in futuro quelli degli agenti). Dopo l'Automazione.

---

## Il piano di prima (31/10/2026, aggiornato l'8/11/2026)

1. ✅ **Ordine nella UX** (v9.66–9.68).
2. ✅ **Due settimane di prova** sui due Mac (26/10–8/11/2026).
3. **Sistema di design, prima di costruire** (8/11/2026, Daniele: «stabilire prima un design
   system da memorizzare in Design, in modo che tutte le funzioni di Tabby abbiano lo stesso
   stile, e poi costruire in modo fluido»). In tre passi, decisi insieme:
   1. la **direzione** (carattere di Tabby) tra 3 proposte: `docs/design-direzioni.html`
      (A Notte · B Nativo · C Tabby);
   2. i **mattoni**: colori chiaro/scuro, accento, caratteri, angoli, spazi, ombre, veli,
      animazioni, icone;
   3. i **componenti**: scheda, tasti della barra, menu, finestre/fogli, ricerca, avvisi,
      veli, sfera, finestra delle sezioni.
   Si salva in `docs/DESIGN.md` (con i valori in un file che l'app legge): diventa la
   sezione **Design** di Tabby.
4. **App Swift** (in `app/` di questo progetto; firmata con un certificato «Tabby» del
   Mac), a tappe, ognuna usabile: fondamenta (permessi, diario, importazione delle
   impostazioni) → barra → finestre come schede → browser → vista divisa → cartelle →
   Lampi e strumenti → le cinque sezioni, avvio, configurazione guidata, Dock. **Regola:**
   tutto ciò che la Tabby di Hammerspoon non fa già (scelte nuove di design o di
   funzionamento) si propone e si decide insieme prima di costruirlo.
   **Principio dell'app (Daniele, 9/11/2026):** Tabby deve essere **estremamente integrata con
   macOS, semplice, velocissima e usare il minimo possibile di batteria**. Mentre si costruisce,
   a ogni tappa e alla fine, si fa un'**ottimizzazione e un debug generale** (memoria, processore,
   batteria, tempi di risposta, niente lavori inutili in sottofondo), misurando sul Mac vero.

### Decisioni per l'app (Daniele, 9/11/2026)
- **Da macOS 26 in poi.**
- **Mac di casa:** Tabby-Hammerspoon in pensione (in `~/.hammerspoon/init.lua` la riga `dofile`
  è commentata; per riaccenderla basta togliere i `--`). Qui si usa e si prova l'app nuova.
  **Mac di lavoro:** resta Tabby-Hammerspoon; i riscontri d'uso si riportano nell'app.
- **Condivisione:** in futuro con amici e colleghi e come **progetto open source su GitHub**.
  Per darla ad altri senza blocchi di macOS servirà l'iscrizione sviluppatore Apple (Developer
  ID, 99 $ l'anno, notarizzazione). L'App Store non è possibile (Tabby muove le finestre delle
  altre app). Prima di rendere pubblico il repository: scegliere la licenza e togliere i dati
  personali (diari, nomi di siti, ecc.).
- **Design e funzionamento**: il sistema di design è completo (`docs/DESIGN.md`); struttura,
  percorsi, parole e rifiniture li decide Claude costruendo, mostrandoli a ogni tappa;
  Automazione e Kat si decidono insieme quando ci si arriva.

### Tappe dell'app
1. **Fondamenta** ✅ (0.1, 9/11/2026): progetto in `app/`, `costruisci.sh`, diario, permesso
   Accessibilità (si accorge da sola quando arriva), importazione delle impostazioni di
   Hammerspoon (una volta, senza toccarle), test.
2. **Barra** ✅ (0.2, 9/11/2026): schede delle app nell'ordine di sempre, riempimento che
   scivola, clic, ⌃⌥1…9 / ← → / 0, una scheda alla volta, adatta, gatto (Torna a, Nuova app,
   Scrivania), +, batteria, ⚙︎ provvisorio (posizione, interruttori, Esci). Provata sul Mac:
   6 schede, ~68 MB, processore 0% a riposo. Da migliorare: la prima ricostruzione 181 ms.
3. **Finestre come schede** (0.3, 9/11/2026, in prova): una scheda per finestra (nomi senza
   il nome dell'app, doppioni numerati), finestre ridotte attenuate, altre finestre della
   stessa app ridotte quando ne scegli una, scheda accanto quando chiudi o riduci l'attiva,
   ⌃⌥W, ⌃⌥Tab, riordino trascinando con la lineetta; finestre delle app nascoste che macOS 26
   chiama «dialogo» tenute come prima. 25 test.
4. **Browser** (0.4, 9/11/2026, in prova): webapp `site:` con nome e logo del sito (loghi anche
   su disco), DuckDuckGo con l'Accessibilità (solo il sito, mai la pagina), Chrome/Brave/Edge/
   Safari con AppleScript in sottofondo e abbinamento delle finestre (B-3), finestrelle escluse,
   numerini dal Dock e dai titoli. Da fare dopo: rinomina e scelta del sito (tasto destro),
   avviso dei siti doppi (B-9), il browser con la miniatura video che non si nasconde.
5. **Vista divisa** (0.5, 9/11/2026, in prova): ⊞ con gli schemi (figurine), velo con le zone
   (tratteggiate, illuminate, «clic per togliere»), schede trascinate dalla barra o cliccate,
   Fatto/Invio · Annulla/Esc, vista che nasce da sola a zone piene, scheda «A + B» con icone
   affiancate, ⇄ (⌃⌥S) e Scomponi, finestre nelle zone, viste salvate. Da fare con i Lampi:
   la fila dei Lampi aperti sopra il pannello.
6. **Cartelle** (0.6, 9/11/2026, in prova): le cartelle di Hammerspoon importate; motore delle
   voci (legami alle finestre, una voce = una scheda, una voce in una cartella sola); attivare
   dal gatto o ⌃⌥⇧1…9 aprendo in sottofondo le voci che mancano, con la schermata d'apertura
   (Scrivania sfocata, icone che si accendono) se sono due o più; scheda-cartella con ⋯ (Apri,
   Modifica, Aggiorna, Esci, Chiudi con avviso «Riapri», Elimina con «Annulla»); vista cartella
   con «←»; foglio «Nuova cartella» (schede scelte con clic o trascinandole, poi il nome);
   componenti comuni: velo, foglio, avvisi.
7. **Lampi e strumenti** (0.7–0.8, 9/11/2026, in prova): Lampi aperti in fila in alto a destra
   (veloci solo se aperti da Tabby, Esc li chiude), Memo con la pagina di sempre, ripiano dei
   Lampi coperti (⚡︎ allargato), menu ⚡︎ con la riga dei Lampi, azioni nella barra dei menu
   (Claude, Notion), foglio «Personalizza i Lampi» (riordino, scorciatoia premendo la lettera,
   senza riavviare); Concentrazione (foglio, tempo al posto della batteria, «Aprire X?», foglio
   «Fatto!», continua dopo un riavvio); la barra che cerca tutto ⌃⌥Spazio (schede, testo nelle
   finestre letto in sottofondo e solo in memoria, cartelle, Lampi, azioni con secondo ↵,
   impostazioni; ⌘↵ apre e cerca dentro); ⚙︎ nuovo (Tabby…, Impostazioni, Scorciatoie, Posizione,
   Chiudi tutte le app col secondo clic, Metti in pausa / ⌥ Esci).
8. **Le cinque sezioni, avvio, primo avvio, Dock** (0.8, 9/11/2026, in prova): finestra di
   Tabby con le due animazioni a ogni avvio, riquadro di Spotlight al centro e cartelle ai lati,
   sezioni Impostazioni · Design · Documentazione (solo testo bianco su nero) · Automazione e Kat
   «presto»; guida del primo avvio (Accessibilità che si accorge da sola, browser, posizione e
   aspetto, barra dei menu e Dock, accensione); temi (Nativo e Notte × 6); la sfera (colori del
   tema, ventaglio, notifiche, anello della Concentrazione) e la pausa. Consumo a riposo: 0%.
9. **Rifiniture rimandate** (0.9, 10/11/2026, in prova): rinomina sul posto (doppio clic o
   tasto destro → Rinomina, Invio/Esc, «Torna al nome»), menu col tasto destro sulle schede;
   ~~Nascondi Tabby~~ (tolto in 0.9.2 per decisione di Daniele: Tabby resta sempre in vista); fascia del notch («Accanto al notch, Tabby sale da sola / sempre /
   non sale», con A-6: la barra si fa da parte quando il mouse va nella fascia, e le schede
   saltano la tacca); avviso dei siti doppi (Lascia · Vai a quella · Chiudi questa, solo per
   finestre nuove); ⚡︎ → Tutte le App (le app nascoste nella barra dei menu).
   **Ancora rimandati:** gesto a tre dita (macOS non lo dà alle app senza trucchi privati:
   fragile, da valutare con Daniele) e lingua inglese (tutte le parole da tradurre: meglio alla
   fine, quando le parole sono ferme).

### 1. Ordine nella UX — i punti da decidere
1. **Tre stili diversi**: barra, menu e riquadro delle cartelle scuri "nostri"; Concentrazione,
   ricerca e avvisi in stile Apple; domande (Rinomina…) con le finestre di Hammerspoon (col
   martello). → uno stile solo (lo decide il punto 2 del piano).
2. ✅ **Menu ⚡︎ a sezioni** (Lampi · Strumenti · App), proposta A scelta su 4
   (`docs/prototipo-menu.html`), v9.67. Cartelle nel gatto; crearle e modificarle in ⚙︎.
3. ✅ **✕ e tasto destro**: restano come sono (deciso il 31/10/2026).
4. ✅ **Il gatto = «casa»**, uguale nella barra e nella sfera (v9.66).
5. **Quattro veli scuri diversi** (Spotlight, Concentrazione, ricerca, apertura delle
   cartelle) → uno solo.
6. ✅ **Foglio delle scorciatoie** con ⌃⌥/ (v9.66).

---

## 🧩 Le sezioni di Tabby (visione di Daniele, 31/10/2026)

Nell'app Swift Tabby avrà cinque sezioni:
- **Impostazioni** — posizione, comportamento, finestre separate, gesti, permessi…
- **Design** — aspetto e colori (temi), gatto, sfera.
- **Documentazione** — guida in italiano, foglio delle scorciatoie (⌃⌥?), cosa funziona con
  ogni browser.
- **Automazione** — spazi di lavoro che si preparano da soli: **apertura delle cartelle**
  all'avvio del Mac, a un orario («Lavoro» alle 9), quando ti colleghi a una rete Wi-Fi
  (l'ufficio); pensate anche come azioni che un agente può usare. *(Deciso: non si fa in
  Hammerspoon, nasce qui.)* Ricerca di spunti su Berd, Goose e Buzz (Block):
  `docs/ricerca/block/NOTE.md`.
- **Kat** — una **cartella del Mac collegata a Tabby** dove stanno tutti i file di Tabby
  (il Memo e gli altri). Con Tabby ambiente multi-agente, è anche il posto dove finiscono
  tutti gli HTML e gli altri file generati dagli agenti con Tabby. (Oggi il Memo è in
  `~/Documents/Tabby Memo.txt`: in Swift si sposta in Kat.)

---

## 🛠 Direttamente nell'app Swift
- **Tabby come alternativa a Raycast e AltTab** (esplorazione del 10/11/2026 su manual.raycast.com/new-in-v2
  e alt-tab.app/it/features; scelte di Claude, da decidere una per una con Daniele prima di costruirle;
  dopo i punti del Mac di lavoro e la ricerca web). Tutto vive nella **barra che cerca tutto** (⌃⌥Spazio)
  o in un tasto ⌃⌥, locale sul Mac, zero consumo a riposo.
  *Da Raycast (le 10 più utili):*
  1. **Storico degli appunti** (⌃⌥V): cercabile, solo sul Mac, salta i gestori di password.
  2. **Calcolatrice e conversioni** nella ricerca: valute, unità, fusi orari («14:00 a New York»); ↵ copia.
  3. **File nella ricerca** con l'indice di Spotlight: ↵ apre, ⌘↵ mostra nel Finder.
  4. **Comandi del Mac**: blocca schermo, svuota Cestino, Non disturbare, stop, espelli dischi.
  5. **Link rapidi** con un pezzo variabile («gh tabby», «m Barcellona»), insieme alla ricerca web.
  6. **Testi pronti** (snippet): «;mail» → il testo salvato.
  7. **Disposizioni delle finestre**: metà/terzi/centro/«torna com'era» con un tasto, disposizioni salvate
     (anche una per cartella), accanto alla vista divisa.
  8. **Scorciatoie e sigle per qualunque cosa** (cartella, sito, azione, impostazione), col registratore
     dei tasti che avvisa dei conflitti.
  9. **Chiedi a Claude** dalla ricerca: Tab quando Tabby non trova niente; contesto a scelta (finestra in
     vista, testo selezionato); tramite l'app Claude, senza chiavi.
  10. **Agenda e «Entra nel meeting»**: i prossimi impegni, un tasto per il link di Meet/Teams.
  *Da AltTab:*
  1. **Selettore vero**: ⌃⌥ tenuti + Tab ripetuto scorre le finestre per uso recente, rilasci e vai.
  2. **Anteprime delle finestre** (miniatura al passaggio o nel selettore; serve «Registrazione schermo»:
     scelta da accendere).
  3. **Tutte le finestre** anche ridotte, nascoste, su altre Scrivanie, con l'etichetta di dove sono.
  4. **Azioni dal selettore**: chiudi, riduci, schermo intero, esci dall'app.
  5. **App escluse** dalla barra, scelte da te (macchine virtuali, app invadenti).
  6. **Comandi dal Terminale** (`tabby …`): elenca e apri schede e cartelle — base dell'Automazione.
  Lasciati fuori apposta: la dettatura (c'è quella di macOS) e le estensioni di terzi (progetto a sé).
- ✅ **Fatto in 0.10, in versione piccola** (vedi SPECIFICA E-5; via il cerchio del browser e i siti presi da internet). **Ricerca web dalla barra di Tabby** (idea di Daniele, 10/11/2026; da fare **dopo** i quattro
  punti del Mac di lavoro: tasti dentro Windows App, fascia nera con Tabby di lato, notifiche di
  macOS, finestrelle tipo Notion):
  - a destra nella barra di ricerca il **cerchio col logo del browser** (DuckDuckGo di serie): un
    clic e lo cambi, la scelta resta;
  - scrivi «raycast» → Tabby propone i **siti veri** (raycast.com col logo, dalle risposte rapide di
    DuckDuckGo, gratis) e in fondo sempre «Cerca "raycast" sul web». Da valutare se serve un servizio
    di ricerca vero (es. Brave Search: chiave gratuita, ricerche al mese limitate);
  - clic → una **finestra nuova con una scheda sola** sul sito, che diventa subito una scheda di
    Tabby col suo nome e logo. Chrome, Safari, Brave, Edge: con AppleScript, sicuro. DuckDuckGo non ha
    AppleScript: provare l'apertura diretta, altrimenti ⌘N e indirizzo;
  - **privacy, da decidere insieme**: oggi la ricerca non esce dal Mac. Al web si chiede solo quando
    sul Mac non c'è niente e dopo una pausa nello scrivere, oppure premendo Tab per i risultati web;
  - consumo: lavora solo a ricerca aperta, mentre scrivi.
- **Animazione d'avvio** (storia di Daniele del 22/10, rivista il 9/11 in
  `docs/design-finestra.html`): le due animazioni partono **ogni volta che l'app si apre da
  zero**, e intanto Tabby carica tutto dietro, così è subito pronta; poi il riquadro di
  Spotlight al centro con le cartelle ai lati. Video in `assets/avvio/` (marchio coperto).
- **Configurazione guidata** al primo avvio: permessi (Accessibilità, Automazione per i
  browser), barra dei menu e Dock nascosti (con consenso), avvio al login, posizione.
- **Tabby al posto del Dock** (confermato): lo nasconde da sola, ripristino dalle
  impostazioni; verificare che i numerini delle notifiche si leggano col Dock nascosto.
- **Icona di Tabby** (gatto bianco su quadrato nero) nelle finestre al posto del martello.
- **Lampi di Tabby** (23/10/2026): una decina di piccole app proprie, sempre davanti, stesso
  stile — Calcolatrice, Memo, Timer/Pomodoro, Cronometro, Convertitore, Appunti (ultime cose
  copiate), Agenda del giorno, Traduttore, Meteo, Lista veloce. *Perché:* macOS non lascia
  tenere davanti le finestre di altre app (oggi c'è il ripiano dei Lampi coperti).
- **Temi** (colori a scelta), dentro la sezione Design.
- Pulizia dei nomi nel codice: `group` → `split` (in Swift i nomi nascono già giusti).

## 🔭 Dopo la v1
- **Agenti dentro Tabby** (Claude…), che usano le cartelle e le automazioni e salvano in Kat.
- **Schermo intero con Tabby visibile** (tolto il 23/10/2026: non funzionava con tutte le app).
- Più monitor; impostazioni sincronizzate tra i Mac.
- Trascinare una scheda sopra la scheda-cartella per aggiungerla (da confermare).

---

## ✅ Fatto (v9.4 → v9.68), per area

- **Schede**: una per app o per finestra (v9.5), una alla volta anche tra finestre della
  stessa app; le finestre ridotte nel Dock restano schede (v9.61, macOS 26); rinomina col
  tasto destro (v9.42); scheda accanto quando chiudi o riduci (v9.38).
- **Browser**: webapp riconosciute (logo e nome del sito) con profili e titoli diversi,
  Meet, più finestre (v9.6–9.13, v9.40); avviso «sito già aperto in un'altra finestra»
  (v9.60); DuckDuckGo letto solo quando cambia (v9.63).
- **Vista divisa** con scambio delle zone (⌃⌥S) e Lampi nelle zone (v9.44–9.45).
- **Cartelle**: creare, attivare, vista cartella, chiudere, aggiornare (v9.8); pagine del
  browser (v9.23); riquadro a griglia, tasto destro (v9.60); schermata di apertura (v9.65).
- **Lampi**: Memo (con elenchi, cose da fare, sezioni — v9.50), Calcolatrice, Calendario,
  Terminale; fila, ripiano dei Lampi coperti (v9.39–9.48); **personalizzabili** (v9.68);
  ⚡︎ → App (icone della barra dei menu di macOS con scorciatoia).
- **Concentrazione** (v9.55–9.56) e **Cerca nelle finestre** ⌃⌥F (v9.57–9.58).
- **Scrivania**: sfera col gatto di Daniele, ventaglio, «Chiudi Tabby» (v9.51–9.54).
- **Barra**: nera con angoli smussati, notch, batteria a icona, barra dei menu e Dock che la
  fanno uscire (v9.43, v9.59), notifiche di macOS non sopra Tabby (v9.41), gesto a tre dita.
- **Stabilità**: timer e comandi esterni tenuti (v9.62), memoria (gesti e notch, v9.64:
  da oltre 1 GB a ~80 MB), diario `~/Library/Logs/Tabby.log` (v9.60), test di robustezza.
- **Specifica completa** per Swift (`SPECIFICA.md`), **GitHub** privato per i due Mac.
