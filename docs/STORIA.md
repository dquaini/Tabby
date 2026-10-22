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
```
