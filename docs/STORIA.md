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
```
