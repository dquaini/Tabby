# Tabby — storia delle versioni

Dalla più vecchia alla più recente. La versione attuale è in testa a `tabby.lua`.

```
TABBY  ·  v9.19
Una barra con una scheda per ogni app: ne vedi una alla volta,
clicchi (o premi Ctrl+Option+1…9) per passare all'altra.

v2: tasto impostazioni, schermo intero, barra che si nasconde.
v3: solo app con finestre, ✕ per chiudere, tasto scrivania, chiudi tutte.
v4: nome Tabby; Ctrl+1…9 in tutte le app; Ctrl+0 = scrivania;
    Tabby visibile anche a schermo intero; impostazioni raggruppate.
v5: ✕ = chiudi finestra / chiudi app; tasto ⚡︎ con app veloci.
v6: posizione di Tabby a scelta (alto, basso, sinistra, destra).
v7: batteria; ⌥Tab = app di prima; Ctrl+frecce; Esc chiude la
    Calcolatrice; gestione di tante app (icone compatte e "+N").
v8: DIVIDI LO SCHERMO (2, 3 o 4 app) trascinando le schede nelle
    zone → diventano un'unica scheda di gruppo con tasto "Scomponi";
    riordino delle schede trascinandole.
v8.x: Tabby nella fascia del notch dei MacBook.
v9: notifiche sulle schede; scorciatoie tutte su ⌃⌥ (Ctrl+Option);
    Memo veloce; browser: una scheda per finestra, "webapp" con nome
    e logo del sito, Chrome A / B / C; correzioni varie.
v9.1-9.3: DuckDuckGo (via Accessibilità, ricorda i siti anche da nascosto),
    loghi da più fonti, Memo salvato in ~/Documents/Tabby Memo.txt.
v9.4: revisione: le viste divise seguono le finestre dei browser (non si
    sciolgono se una webapp cambia sito); stesso sito in due browser = due
    schede; loghi ritentati senza internet; spia "Tabby · lento" in console.
v9.5 (v1 · A): una scheda per ogni finestra di qualsiasi app, col titolo
    della finestra (niente più "Chrome A / B"); ⚙︎ → Finestre separate per
    app; app cercate per bundle ID (via un blocco di ~200 ms ogni 3 s);
    privacy: di DuckDuckGo si tiene e si scrive solo il sito, non l'indirizzo.
v9.6: Chrome & co.: webapp riconosciute anche con più profili (titolo con
    il profilo in fondo) o titolo diverso (abbinate per posizione); logo
    anche dal sito stesso; diagnosi in console (abbinamento, permesso, logo).
v9.7: Chrome/Safari: corretto lo script (dentro il browser "tab" è la
    scheda, non la tabulazione: le webapp non venivano mai riconosciute);
    la domanda al browser parte in parallelo (via ~200 ms di blocco ogni 3 s).
v9.8 (v1 · B): CARTELLE, spazi di lavoro salvati (app e webapp). Si creano
    e attivano dal menu ⚡︎ (o ⌃⌥⇧ + numero); attivata = una scheda sola con
    le icone; cliccata = vista cartella (solo le sue schede, ← per tornare).
v9.9: Chrome: le webapp non "lampeggiano" più (memoria per finestra mentre
    la risposta del browser è in arrivo); diagnosi delle finestre nuove dei
    browser; diagnosi DuckDuckGo solo quando cambia sito o schede.
v9.10: Google Meet: il video in miniatura (finestrella del browser) non è
    una scheda, non si ridimensiona e resta visibile; abbinamento prima per
    posizione; webapp "Meet"; console: permesso negato ≠ browser occupato.
v9.11: giro di rifiniture: scheda + (Spotlight, che esce dal menu ⚡︎);
    Scambia nella vista divisa (⇄ e ⌃⌥S); il gatto di Tabby sul tasto
    scrivania; clic sulla cartella = scegli l'app; niente ridimensionamenti
    inutili; la spia di lentezza dice quale app è lenta.
v9.12: con Spotlight aperto lo sfondo si oscura (⚙︎ → Comportamento).
    (v9.12.1: il velo restava trasparente per due dissolvenze ravvicinate;
    v9.12.2: velo all'85%, il testo dietro non si legge più;
    v9.12.3: il velo sparisce subito quando Spotlight si chiude)
v9.13: Chrome con più finestre: niente più schede scambiate (la sola
    posizione non distingue finestre che Tabby adatta allo stesso spazio).
v9.14: "una app alla volta" diventa "una scheda alla volta": le altre
    finestre della stessa app (es. Chrome) si riducono a icona.
v9.15: le finestrelle di accesso (Google…) non riducono la pagina da cui
    parti; chiusa una finestra torna l'ultima usata, non il desktop.
v9.16: una scheda alla volta riduce le altre finestre solo quando scegli tu
    (scheda, scorciatoia, ⌘N), mai per i cambi di macOS: niente ping-pong.
v9.17: Calendario veloce (⌃⌥A, piccolo in alto a destra); barra nera piena.
v9.18: dopo il clic su una scheda la tastiera arriva davvero alla finestra (⌘F).
v9.19: cambio di scheda più veloce (barra disegnata prima di adattare le
    finestre); la spia "lento" dice in quale passaggio va il tempo.
v9.20: ottimizzazione: batteria letta solo quando cambia (prima ~30 ms a ogni
    disegno); controlli "finestrella" in due funzioni (T.isSmall, T.isFloating);
    storia delle versioni spostata in docs/STORIA.md.
v9.21: Calendario veloce non più tagliato (680x520, la misura minima che accetta;
    le app veloci che si allargano da sole vengono riportate dentro lo schermo).
v9.22: codice diviso in 15 file (cartella tabby/) con uno spazio comune di nomi:
    niente più limite dei 200 nomi locali; tabby.lua carica i file in ordine.
v9.23: cartelle: una finestra di Chrome/Safari con più pagine si ricorda con le sue
    pagine (senza ?/#) e, attivando la cartella, si riapre con tutte le pagine.
v9.24: cartelle, i casi della mappa: ogni voce prende una sola finestra, quella
    scelta, e ci resta legata; le altre finestre dello stesso browser/app restano
    fuori (DuckDuckGo, Finder); le schede chiuse si riaprono nella stessa finestra;
    "Aggiorna con le schede di adesso".
v9.25: ⌃⌥W chiude la finestra attiva (non l'app); le righe di diagnosi non possono
    più bloccare Tabby se il Terminale collegato si interrompe.
v9.26: chiusa l'ultima finestra della scheda attiva (⌃⌥W o ✕) si passa alla scheda a
    sinistra (a destra se era la prima), non al desktop vuoto.
v9.27: gesti: tre dita a sinistra/destra = scheda dopo/prima; azioni rapide delle app
    nel menu ⚡︎ (Claude chat rapida ⌃⌥L, Notion cerca ⌃⌥N, Notion AI ⌃⌥I).
v9.28: ⌃⌥N/⌃⌥I: la scorciatoia di Notion parte quando hai lasciato ⌃⌥.
v9.29: azioni rapide con lo sfondo oscurato come Spotlight; Notion dal menu della sua
    icona (le sue scorciatoie valgono solo dentro Notion).
v9.30: Notion: il menu dell'icona si cerca più a lungo (icona nascosta), con diagnosi;
    tolta l'opzione "Schermo intero con Tabby visibile" (tasto verde normale).
v9.31: le finestre a schermo intero escono dai radar di Tabby (e Tabby si fa da parte);
    Notion con l'icona spenta: Notion davanti con la sua scorciatoia.
v9.32: azioni delle app: Tabby scopre da sola le app con un'icona nella barra dei menu
    (anche quelle nuove), ⚡︎ → App ▸ (una riga anche con 100 app), Gestisci: mostra/
    nascondi e scorciatoia ⌃⌥ + lettera.
v9.33: consumi più bassi (mouse controllato solo se serve, browser in secondo piano ogni
    15 s, notifiche ogni 5 s); schermo intero senza ritardo; "Apri <app>" con l'icona
    spenta apre l'app.
v9.34: chiusa l'ultima finestra della scheda attiva in qualsiasi modo (anche col pallino
    rosso) si passa alla scheda accanto; Tabby non compare sopra le app a schermo intero
    (lo fa macOS, senza ritardo); Terminale veloce ⌃⌥T; avviso per le app solo icona.
v9.35: schermo intero: Tabby chiede a macOS il tipo di scrivania e sparisce subito (la
    v9.34 la lasciava visibile); in Gestisci le app "solo icona" sono segnalate.
v9.36: schermo intero: Tabby sparisce al gesto (clic sul pallino verde, ⌃⌘F), prima
    dell'animazione; console con l'ora al millesimo di ogni passaggio.
v9.37: con Tabby a destra o a sinistra, in cima il gatto intero (disegni di Daniele).
v9.38: chiusa o ridotta (anche col pallino giallo) la scheda attiva, in qualsiasi modo, si
    passa sempre alla scheda accanto; vista divisa con due finestre dello stesso browser
    senza vibrazioni; angoli smussati verso le app; clic sul gatto = Finder sulla
    Scrivania (⌃⌥0 resta la scrivania); il Memo si riprende la tastiera.
v9.39: Calcolatrice, Calendario e Terminale sono "veloci" solo se aperti con la scorciatoia
    o da ⚡︎ (da Spotlight/Dock: app normali a tutto spazio); restano sopra anche cambiando
    scheda finché non premi Esc; nella vista divisa entrano già nelle zone. Le estensioni di
    Hammerspoon si caricano all'avvio (un comando "hs" interrotto bloccava il menu ⚙︎).
v9.40: browser: più finestre con lo stesso titolo (due "Meet") non si scambiano più
    (Tabby ricorda il numero di ogni finestra); rinominare una scheda (✕ → Rinomina);
    clic sull'icona di una finestra con più siti = scegli quale sito mostrare.
v9.41: con la barra dei menu nascosta, quando scende Tabby le scende sotto (in alto e di
    lato) e risale quando il puntatore torna giù; le notifiche di macOS compaiono sotto
    Tabby (in alto) o alla sua sinistra (a destra), non più sopra.
v9.42: chiusa un'app lenta a chiudersi (Spotify) dalla ✕: si va alla scheda accanto, non
    sulla Scrivania; i menu di Tabby e i riquadri della vista divisa stanno sopra il Memo e
    le app veloci; rinominare una scheda col tasto destro.
v9.43: barra dei menu e Dock che si nascondono da soli: quando compaiono dalla parte di
    Tabby (barra dei menu con Tabby in alto, Dock dallo stesso lato) Tabby esce dallo
    schermo e rientra quando se ne vanno (al posto di "attaccata sotto" della v9.41).
v9.44: app veloci in fila: aprendone una con un'altra già aperta si sceglie dove (1 accanto,
    2 sotto); chiudendone una le altre si spostano; il Memo entra nelle zone della vista
    divisa.
v9.45: "Lampi" = le app del menu ⚡︎. Vista divisa: fila dei Lampi aperti da trascinare o
    cliccare nelle zone (anche dopo averne tolto uno per sbaglio); fila dei Lampi senza
    regole nascoste (posto senza spazio grigio con «non c'è spazio», «in parte sopra»,
    niente spostamenti inutili, mai fuori dallo schermo); il sito da mostrare solo col
    tasto destro; con Tabby di lato una fascia nera in cima sotto la barra dei menu.
v9.46: colonna riservata ai Lampi: finché ce n'è uno aperto l'app che usi si stringe e
    non li copre (macOS non permette di tenerli sopra); dove va un Lampo: posto in due modi →
    si sceglie, in uno → va lì, in nessuno → «Non c'è spazio per mettere …». In roadmap: una
    decina di Lampi propri di Tabby nell'app Swift.
v9.47: tolta la colonna riservata ai Lampi (troppo limitante): i Lampi stanno sopra e, se
    finiscono sotto la finestra che usi, compaiono sul ripiano nella barra di Tabby (icone
    + «Tutti»): un clic e tornano davanti. "C'è posto" = dentro lo schermo e non sopra un
    altro Lampo.
v9.48: niente ripiano a parte: è il tasto ⚡︎ che si allarga con le icone dei Lampi coperti e
    «Tutti» (di lato diventa una riga sopra ⊞ ⚙︎); cambiando posizione i Lampi si rimettono
    in fila.
v9.49: cambiando la posizione di Tabby si rimette a misura l'app in uso (anche con un Lampo
    davanti, anche una vista divisa di finestre del browser) e i Lampi; batteria solo icona,
    la percentuale in un fumetto passandoci sopra.
v9.50: Memo con elenchi puntati («- »), cose da fare («[ ] », casella che barra la riga) e
    sezioni apribili («> », ▸/▾, righe rientrate); il file resta testo semplice; più veloce
    (pagina preparata all'avvio, testo ricaricato solo se il file è cambiato).
v9.51: senza finestre in vista Tabby diventa un cerchio col muso del gatto in basso a
    destra; clic sul gatto (cerchio o barra) = l'ultima finestra guardata, o un menu con
    «+ Nuova app…» e le cartelle; freccia delle sezioni del Memo più grande e bianca.
v9.52: il cerchio diventa "Eclissi" (luce ambra sul bordo, scelta tra 4 prototipi) e senza
    finestre le scelte si aprono a ventaglio intorno al cerchio, attaccate a lui.
v9.53: il cerchio diventa una sfera viva in stile "orb" AI (colori che ruotano dentro,
    riflesso, alone che respira, quasi zero consumo), un po' più verso il centro; il clic
    sul gatto nella barra torna ad aprire il Finder sulla Scrivania.
v9.54: dentro la sfera il gatto di Daniele; la sfera reagisce al puntatore; il ventaglio
    diventa di piccole sfere dello stesso stile; ⚙︎ → «Chiudi Tabby»: resta solo la sfera e
    Tabby si ferma finché non la clicchi.
v9.55: Concentrazione (⚡︎ → Concentrazione…): sfondo scuro, in centro minuti e schede;
    le schede si scelgono cliccandole nella barra (gialle). Durante: Non disturbare (coi
    comandi rapidi «Concentrazione on/off»), il tempo al posto della batteria (anello
    giallo sulla sfera), le altre app nascoste (non chiuse), nella barra solo le schede
    scelte, un'altra app → Tabby chiede. Alla fine: suono, notifiche arrivate, Riapri
    tutto / Altri 10 minuti / Resta così. Sopravvive al riavvio.
v9.56: la finestra della Concentrazione in stile standard di macOS (come Impostazioni,
    chiara o scura come il sistema); il tempo nella barra nei colori normali di Tabby. Lo
    stile personalizzato si decide nell'app Swift, per tutto insieme (Daniele).
v9.57: Cerca nelle finestre (⌃⌥F, anche da ⚡︎): un ⌘F su tutte le finestre aperte. Tabby
    legge il testo delle finestre con l'Accessibilità (a piccoli passi, solo in memoria);
    la barra in stile Spotlight mostra le finestre con le parole e un pezzetto di testo;
    Invio = quella finestra davanti con ⌘F e la parola già scritta. Cerca anche nel Memo.
v9.58: con la ricerca aperta lo sfondo si oscura (la barra di Tabby no), come nella
    Concentrazione.
v9.59: col cerchio sulla scrivania (o Tabby chiusa) la barra dei menu che scende non fa
    più ricomparire Tabby per un istante.
v9.60: cartelle con tante voci: il riquadro diventa una griglia (tutte visibili, ognuna
    con la ✕); tasto destro sulla scheda-cartella = il suo menu (Rinomina…); avviso
    «sito già aperto in un'altra finestra» (Lascia / Vai a quella / Chiudi questa);
    aprendo una cartella con più app, un velo con le icone che si accendono e poi sfuma;
    diario su file (~/Library/Logs/Tabby.log) con tutte le chiusure.
v9.61: le finestre ridotte nel Dock (e quelle delle app nascoste) restano schede: su
    macOS 26 si dicono "dialogo" e Tabby le perdeva (Chrome e Anteprima "chiuse").
v9.62: robustezza: i timer «tra un attimo» (46 punti, compreso quello di ogni cambio di
    app) e i comandi esterni ora sono tenuti finché non scattano (Hammerspoon li buttava
    via: provato, 20 su 20 persi). Test che lo controlla.
v9.63: DuckDuckGo: si legge dentro una finestra solo se il titolo è cambiato o dopo 10 s
    (prima ogni 3 s tutte), e le finestre ridotte restano nell'elenco (macOS 26); le
    pagine di Concentrazione, ricerca e avvisi si chiudono dopo 5 minuti senza uso
    (memoria); tolte due funzioni non più usate.
v9.64: memoria: Hammerspoon arrivava oltre 1 GB in un giorno. Causa: la lettura delle dita
    sul trackpad (per il gesto a tre dita), fatta a ogni movimento anche scorrendo, lascia
    memoria che non si libera. Ora con due dita o una si rilegge dopo 150 ms; durante un
    gesto a tre dita si legge tutto. Il notch si chiede una volta per schermo.
v9.65: apertura delle cartelle: al posto del velo semitrasparente una schermata piena
    (sfondo della Scrivania sfocato, nome della cartella, icone che si accendono, barretta)
    che copre tutto PRIMA che le app partano e sfuma solo quando Tabby ha finito di
    sistemarle (almeno 2,9 s, al massimo 7, un clic la toglie).
v9.66: il gatto = «casa», uguale nella barra (menu) e nella sfera (ventaglio): Torna a…,
    Nuova app, Scrivania, cartelle. Foglio delle scorciatoie con ⌃⌥/ (anche da ⚙︎).
v9.67: menu ⚡︎ a sezioni (Lampi · Strumenti · App; proposta A): le App con scorciatoia
    subito, le altre in «Tutte le App». Cartelle: si aprono dal gatto, si creano e
    modificano in ⚙︎ → Cartelle; anche il file del Memo è in ⚙︎.
v9.68: Lampi personalizzati (⚡︎ → Personalizza i Lampi): togliere, aggiungere (app aperte o
    dalla cartella Applicazioni), cambiare scorciatoia, tornare a quelli di serie.
v9.69: i pannelli piccoli (es. Notion «vuoi registrare il meeting?») non nascondono più le
    altre app; la linea blu del trascinamento non resta più disegnata se il rilascio del
    clic si perde; il diario scrive ogni cambio di app con la sua finestra.
app 0.1 (9/11/2026): nasce l'app Swift in `app/` (da macOS 26): fondamenta — diario in
    ~/Library/Logs/Tabby.log, permesso Accessibilità, impostazioni importate da Hammerspoon,
    5 test. Sul Mac di casa Tabby-Hammerspoon va in pensione.
app 0.2 (9/11/2026): la barra, nello stile deciso (Notte · Tabby), con le schede delle app.
app 0.3 (9/11/2026): le finestre come schede, scheda accanto, ⌃⌥W, ⌃⌥Tab, riordino trascinando.
app 0.4 (9/11/2026): i browser (siti come schede, loghi, DuckDuckGo) e i numerini delle notifiche.
app 0.5 (9/11/2026): la vista divisa. Prima, le altre finestre della stessa app non si riducono più nel Dock.
app 0.6 (9/11/2026): le cartelle, con la schermata d'apertura; velo, fogli e avvisi.
app 0.8 (9/11/2026): Lampi e Memo, Concentrazione, la barra che cerca tutto, la finestra di Tabby
    con le animazioni e la guida, la sfera, la pausa, i temi. A riposo 0% di processore.
app 0.9 (10/11/2026): rinomina sul posto e tasto destro sulle schede, Nascondi Tabby, fascia del
    notch, avviso dei siti doppi, ⚡︎ → Tutte le App (quelle nascoste nella barra dei menu).
app 0.9.1 (10/11/2026): la rinomina si salva cambiando scheda; col menu di Apple che scende Tabby si
    toglie di mezzo; «Tabby si nasconde» fa far posto alla finestra e in alto si apre toccando la cima e
    scendendo; i menu tengono la barra in vista; nella ricerca le sezioni di Tabby e «Tabby sempre in
    vista»; la sfera consuma 6% invece di 37% (gatto caricato una volta, 10 immagini al secondo).
app 0.9.2 (10/11/2026): via del tutto «Nascondi Tabby» (scatto col menu di Apple): Tabby resta sempre in
    vista; si toglie di mezzo solo quando scende il menu di Apple.
app 0.9.3 (10/11/2026): 16 correzioni dalle prove di Daniele. Nomi lunghi accorciati per parole («Proton»);
    una finestra di browser che cambia sito resta la stessa scheda (prima sembrava chiusa e si saltava
    altrove); siti doppi anche fra le schede di un'altra finestra; Tabby che torna sempre dopo il menu di
    Apple; Scomponi resta sulla scheda giusta e riallarga tutte le finestre; eliminare le cartelle;
    apertura della cartella con le icone ferme; Lampi: Calendario che si apre, Esc che chiude solo quello
    davanti, Esc nel Memo; ricerca nel brano di Spotify; cerchio della Concentrazione; il musetto apre la
    Scrivania nel Finder; Chiudi Tabby immediata.
app 0.9.4 (10/11/2026): i quattro punti del Mac di lavoro: scorciatoie ⌃⌥ anche dentro Windows App
    (intercettatore dei tasti, K-1), fascia vuota in cima con Tabby di lato (A-7), notifiche di macOS sotto
    o accanto a Tabby (N-5), finestrelle tipo Notion che non nascondono le altre app (X-5). Nomi dei
    servizi conosciuti (Proton Mail, Gmail…), mai l'indirizzo email.
app 0.9.5 (10/11/2026): verso la parità con Hammerspoon: finestre separate per app e «Mostra come» (il sito
    da mostrare) dal tasto destro; velo con Spotlight o Raycast aperti; protezioni: rimbalzo dopo la
    Scrivania (W-2), rilascio del mouse perso (T-2), finestrella chiusa che riapre l'ultima ridotta (C-3),
    app a schermo intero mai nascoste (Z-4).
app 0.9.6 (10/11/2026): parità con Hammerspoon v9.69: gesto a tre dita (G-1), Tabby che sparisce subito
    al pallino verde o con ⌃⌘F (Z-3), icone della barra dei menu parcheggiate che aprono l'app (X-3), velo
    sotto i pannelli delle azioni rapide (X-4). Guida per il MacBook di lavoro e `app/crea-certificato.sh`.
app 0.9.7 (10/11/2026): velo anche con Raycast e via subito quando chiudi Spotlight; la sfera solo con Tabby
    chiusa o in pausa e sulla Scrivania (mai a schermo intero); il musetto apre la Scrivania più in fretta.
app 0.9.8 (10/11/2026): doppio clic sulla ✕ chiude subito la finestra; il Lampo Calendario resta tutto dentro lo schermo.
app 0.9.9 (10/11/2026): Lampi a 12 punti dai bordi anche quando sono più grandi del posto; la Calcolatrice aperta da zero non finisce al centro (Tabby la sistema fino a 3,8 s); un controllo in più per le app che si rimettono la loro misura (Spotify), con una riga nel diario se non si adattano.
app 0.10 (10/11/2026): la ricerca sul web nella barra di Tabby: «Apri Proton Mail» / «Apri raycast.com» in una finestra con una scheda sola (o la scheda già aperta), «Cerca … sul web» con DuckDuckGo; ⌘↵ come scheda nella finestra davanti.
app 0.10.1 (10/11/2026): aprendo uno zip non si salta più su un'app a caso (Utility Compressione non è una scheda; un'app che si chiude da sola riporta dov'eri); chiudendo un'app non si resta sulla Scrivania vuota.
app 0.10.2 (10/11/2026): clic sui risultati «Sul web» che funziona; velo di nuovo con Spotlight (e via appena lo chiudi) e sotto la chat rapida di Claude; «Informazioni su questo Mac» non nasconde più tutto.
app 0.10.3 (10/11/2026): la ricerca web apre davvero il sito anche con DuckDuckGo (aspetta la finestra nuova e incolla l'indirizzo); nella barra il cerchio per scegliere il browser.
app 0.10.4 (10/11/2026): «Apri Gmail» in cima quando nessuna tua scheda si chiama così (prima Invio portava su una finestra che conteneva la parola); velo sotto la barra di Tabby, anche con Raycast e Alfred.
app 0.10.5 (10/11/2026): ricerca web con DuckDuckGo in una finestra con una scheda sola (Sposta scheda in una nuova finestra), Chrome più veloce (--new-window).
app 0.10.6 (10/11/2026): il velo sotto il pannello di qualunque app (quello che ha la tastiera e sta sopra le finestre), Raycast compreso.
app 0.10.7 (10/11/2026): il velo con Raycast davvero (Raycast si mostra e si nasconde invece di passare davanti).
app 0.10.8 (10/11/2026): il velo con Raycast, ascoltando quando crea la sua finestra (per macOS resta «nascosto» anche aperto).
app 0.10.9 (10/11/2026): revisione del codice. Bug: l'attesa del permesso Accessibilità ne cancellava un'altra
    (al primo avvio, dato il permesso nella guida, la barra non partiva); la lettura dei browser con tante
    schede si bloccava fino a 6 s; numeri delle scorciatoie che potevano coincidere; gesti spenti che
    restavano in ascolto; ascolto delle app chiuse non staccato. Più leggero: ogni finestra si ascolta una
    volta sola (prima a ogni ricostruzione), il velo guarda meno a lungo. Pulizia: velo riscritto senza
    Raycast, risultati della ricerca calcolati in un posto solo, ascolto di macOS riunito, codice morto
    tolto, nessun avviso del compilatore.
app 0.10.10 (10/11/2026): revisione riga per riga delle parti rimaste. Bug: «Metti in pausa» con finestre in
    vista lasciava la barra ferma; numero di una vista divisa nuova che poteva coincidere con una importata;
    ⌃⌥Tab dopo aver creato una vista; velo della divisione che spariva se riaperto subito; indirizzi con
    virgolette che rompevano i comandi per i browser; ⌘↵ con ricerche lunghe troncate; «+N altre» senza i
    loghi dei siti. Più leggera: immagini del gatto lette una volta, Memo letto all'apertura della ricerca
    (non a ogni lettera), Concentrazione con un solo appuntamento alla fine (prima un controllo al secondo,
    infinito senza tempo); il video d'avvio smette di ascoltare. Tolti: opzioni mai usate dei componenti,
    il doppione del controllo della barra dei menu.
app 0.10.11 (12/11/2026): doppio clic sulla ✕ col tempo del Mac (non apre più il menu per sbaglio) e che chiude l'app quando è la sua sola finestra (Discord restava aperta in sottofondo).
app 0.10.12 (12/11/2026): «Dividi lo schermo» passa dal tasto ⊞ della barra al menu ⚡︎, sotto Strumenti.
app 0.11 (12/11/2026): inizio della fase 1 (roadmap nuova in tre fasi + Kat). Menu ⚡︎ e ⚙︎ riordinati, «Modifica o elimina» delle cartelle che funziona, «Chiudi le app senza finestre», pausa tolta, margine a destra della barra.
app 0.12 (12/11/2026): il selettore con le anteprime (⌃⌥Tab tenuti, stile AltTab), con le foto delle finestre se c'è il permesso «Registrazione schermo».
app 0.13 (12/11/2026): il cruscotto (centro di controllo) al posto della batteria, con tessere componibili: ora e data, batteria, meteo, musica, borsa, Mac, tempo d'uso; «Impostazioni» diventa «Preferenze», con la sezione del cruscotto.
app 0.13.1 (12/11/2026): le tessere del cruscotto al centro, come un quadrante (la borsa resta in colonna dentro il suo riquadro centrato; «modifica» a sinistra).
app 0.13.2 (12/11/2026): «Mostra la scheda come» (nome e logo di un sito per una finestra di browser con più schede) anche con DuckDuckGo.
app 0.13.3 (12/11/2026): «Mostra come «DuckDuckGo»» forza il nome del browser anche su una finestra con un sito solo (prima «come prima» la lasciava Ollama); «Automatico» per tornare alla scelta di Tabby.
app 0.13.4 (12/11/2026): «Mostra la scheda come» con icone piccole, i siti visti nella finestra di DuckDuckGo (fino a 10) e «Come il browser» quando la scheda mostra un sito.
app 0.14 (12/11/2026): l'audio sulle schede (🔊, 🎙, «Silenzia» col tasto destro); roadmap: accessi al centro con storico in Privacy, Tieni in vista, Tabby si prende cura del Mac.
app 0.15 (12/11/2026): gli accessi con Google, Apple, Microsoft al centro sopra lo sfondo nero, e lo storico nella sezione nuova Privacy.
app 0.16 (12/11/2026): Tieni in vista: la finestra di una scheda dal vivo in un riquadro a sinistra, sopra tutto.
app 0.16.1 (12/11/2026): un clic sull'altoparlante della scheda la zittisce (niente più tasto destro); il riquadro di «Tieni in vista» sparisce mentre sei su quella scheda.
app 0.16.2 (12/11/2026): revisione di fine sessione. Esc temporaneo con un proprietario (cruscotto, selettore e Dividi non si tolgono più il tasto a vicenda); il cruscotto riaperto dalle Preferenze non raddoppia gli ascolti; «Tieni in vista» ferma la copia dal vivo tolta mentre partiva e chiude il riquadro se la finestra non si trova; l'audio dimentica i processi finiti; il tempo d'uso non crea un formato data a ogni cambio d'app.
app 0.16.3 (13/11/2026): chiudendo tutte le app Tabby diventa la sfera (non solo con «Chiudi Tabby»); «Chiudi tutte le app» chiude anche Impostazioni di Sistema.
```
