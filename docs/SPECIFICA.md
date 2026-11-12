# Tabby — specifica del comportamento

Versione di riferimento: **v9.37** (Hammerspoon), 23/10/2026.
Scopo: descrivere **tutto quello che Tabby fa oggi**, in modo che l'app Swift possa
rifarlo uguale (prima il motore, poi design, avvio, configurazione guidata e Dock).
È ricavata dal codice (`tabby/*.lua`) e dai test (`test/test_*.py`): quando il
comportamento cambia in Hammerspoon, va aggiornata anche questa pagina.

Come leggerla:
- ogni regola ha un codice (es. **S-3**) per citarla nei test e nelle discussioni;
- *perché* spiega le scelte nate dall'uso vero (spesso un difetto visto sul Mac);
- **[Swift]** segnala note per l'app nuova (cosa usare, cosa cambiare);
- i valori numerici (misure, tempi) sono quelli di oggi: si possono rivedere col design.

Indice: 1 Concetti · 2 Schede · 3 Browser · 4 Passare da una scheda all'altra ·
5 Una scheda alla volta e adattamento · 6 Chiudere · 7 Vista divisa · 8 Cartelle ·
9 Notifiche · 10 Barra: disegno e misure · 11 Posizione, notch, Nascondi Tabby ·
12 Schermo intero · 13 Scrivania · 14 Azioni veloci e Memo · 15 Azioni delle app ·
16 Velo · 17 Scorciatoie · 18 Gesti · 19 Trascinare · 20 Menu · 21 Impostazioni
salvate · 22 Osservatori, tempi e consumi · 23 Permessi · 24 Diagnosi · 25 Limiti
noti · 26 Mappa dei test.

---

## 1. Concetti

- **Scheda**: una cosa che puoi guardare a tutto spazio: un'app, una finestra, un
  sito (webapp), una vista divisa o una cartella. Tabby mostra una barra di schede;
  ne vedi una alla volta.
- **Chiave**: ogni scheda ha un nome stabile che non cambia mentre lavori. Serve a
  ricordare l'ordine, le viste divise, le cartelle, e in futuro agli agenti AI.

  | Chiave | Cosa è |
  |---|---|
  | `<bundle ID>` (es. `com.tinyspeck.slackmacgap`) | un'app, oppure la **prima** finestra (la più vecchia) di un'app o di un browser |
  | `win:<id finestra>` | un'altra finestra della stessa app/browser |
  | `site:<dominio>` (es. `site:mail.google.com`) | una finestra di browser con un solo sito (webapp) |
  | `g:<n>` | una vista divisa (nel codice "gruppo") |
  | `f:<n>` | una cartella attiva vista come scheda unica |

- **Vista divisa** (codice: *gruppo*): lo spazio delle app diviso in 2–4 zone, una
  scheda per zona. **Cartella**: uno spazio di lavoro salvato (una "ricetta" di app e
  siti). Sono due cose diverse. **[Swift]** chiamare `Split` e `Folder` nel codice.
- **Spazio delle app**: lo schermo principale meno la barra dei menu di macOS, il
  Dock e Tabby (vedi 11).
- **App veloci** (*floater*): Calcolatrice, Calendario, Terminale (e il Memo): si
  aprono piccole in alto a destra, sopra quello che fai, e non sono schede.
- App **ignorate**: Hammerspoon (mai una scheda). **[Swift]** ignorare Tabby stessa.

## 2. Schede: quali esistono e come si chiamano

**S-1 App considerate.** Solo le app "vere" (quelle che stanno nel Dock: tipo di
attivazione *regular*), escluse le ignorate e le app veloci. Per ogni bundle ID conta
una sola app.

**S-2 Una scheda per finestra.** Per ogni app si prendono le finestre *standard*
(non dialoghi, non pannelli), escluse quelle a **schermo intero** (vedi 12), ordinate
per id (la più vecchia prima).
- 1 finestra → una scheda con il nome dell'app.
- 2 o più → una scheda per finestra, nome = **titolo della finestra senza il nome
  dell'app in fondo** (`"Relazione — TextEdit"` → `"Relazione"`; separatori ` — `,
  ` – `, ` - `, ` | `). Titolo vuoto o uguale all'app → nome dell'app.
- Titoli uguali: `"Download"`, `"Download (2)"`, …
- La prima finestra ha come chiave il bundle ID (così resta al posto dell'app tra le
  preferite e prende le notifiche del Dock); le altre `win:<id>`.

**S-3 Finestre separate (per app).** ⚙︎ → Finestre separate: per ogni app (tranne
browser e app veloci) si può spegnere "una scheda per finestra": allora l'app è una
scheda sola (chiave = bundle ID). Salvato in `joinWins`. I browser sono **sempre** a
finestre separate.
*App Swift 0.9.5:* dal tasto destro sulla scheda: «Tutte le finestre in una scheda» / «Una scheda per finestra».

**S-4 App senza finestre.** Un'app aperta senza finestre standard è una scheda solo
se ⚙︎ → "Mostra anche app aperte senza finestre" è acceso, oppure se ha finestre
altrove (ridotte, nascoste, su un'altra scrivania: le ricorda il filtro di tutte le
finestre). Altrimenti non compare.

**S-5 Browser.** Vedi 3: una scheda per finestra, webapp quando la finestra ha un
solo sito.

**S-6 Chiave già presa.** Se due finestre producono la stessa chiave (es. Gmail
aperto in Chrome e in Safari), la seconda diventa `win:<id>`: sono due schede.

**S-7 Ordine (`order`).** Elenco delle chiavi nell'ordine scelto dall'utente
(trascinando). Alla ricostruzione:
1. le **preferite** (`pinned`) appena comparse vanno **in cima**, nell'ordine
   dell'elenco preferite;
2. una scheda nuova di un'app che ha già schede va **subito dopo l'ultima scheda
   della stessa app** (le finestre di Chrome stanno vicine);
3. il resto in fondo.
Pulizia: si tolgono le chiavi `g:` di viste divise che non esistono più, `f:` di
cartelle cancellate, `win:` di finestre chiuse, e se le chiavi ricordate sono più di
300 quelle non visibili. Preferite di partenza: Finder, Calendario, Note.
*App Swift 0.9.3:* se una finestra cambia chiave (una finestra di browser che passa a un sito solo, `win:` → `site:`, o il contrario) è la **stessa scheda**: resta al suo posto, resta attiva, tiene vista divisa e nome. Prima sembrava chiusa e si saltava su un'altra finestra.

**S-8 Ricostruzione (`rebuildTabs`).** Si rifà da zero l'elenco di tutte le schede
possibili (`cand`), con le mappe chiave→finestra, finestra→chiave, chiave→bundle ID.
Poi si aggiornano le viste divise (7), si applica l'ordine (S-7), si calcolano le
cartelle (8) e infine le schede **visibili** (`tabs`): su queste lavorano clic,
numeri e frecce. La ricostruzione è "ritardata" di 0,3 s: tanti eventi insieme →
una ricostruzione sola.

## 3. Browser

Browser conosciuti: Chrome, Brave, Edge (tipo *chrome*), Safari (tipo *safari*),
DuckDuckGo (tipo *ax*, senza AppleScript).

**B-1 Che cosa c'è nelle finestre (Chrome, Brave, Edge, Safari).** Tabby chiede al
browser con AppleScript, per ogni finestra: titolo, numero (id) della finestra per
il browser, posizione e misura, indirizzo di ogni scheda.
- La domanda parte **in parallelo** (processo `osascript`), con un limite di 2 s
  dentro lo script; Tabby non aspetta: usa l'ultima risposta e, quando ne arriva una
  diversa, ricostruisce. *Perché:* prima bloccava Tabby ~200 ms ogni 3 s.
- Una domanda senza risposta da più di 6 s si abbandona e se ne fa una nuova.
- Senza risposta (browser occupato, permesso tolto) si **tiene l'ultima buona**, così
  le webapp non spariscono e ricompaiono. Browser chiuso → si dimentica.
- Errore −1743 = manca il permesso Automazione → riga in console con la strada per
  darlo (vedi 23).
- Attenzione AppleScript: dentro `tell application` la parola `tab` è la scheda del
  browser; i separatori (tab, a capo) si preparano prima.
- **[Swift]** si può usare `NSAppleScript`/`OSAScript` in un thread, o Scripting
  Bridge; stessa regola: mai bloccare l'interfaccia.

**B-2 DuckDuckGo (Accessibilità).** Non ha AppleScript: Tabby guarda dentro la
finestra con l'Accessibilità (al massimo 800 elementi, profondità 14), **senza
leggere la pagina**: prende l'indirizzo della pagina (`AXURL` dell'area web, o il
campo dell'indirizzo) e conta le schede (gruppo di schede, pulsanti-scheda).
- Privacy: dell'indirizzo si tiene **solo il sito** (`https://dominio/`).
- Webapp **solo se la finestra ha una scheda sola**; altrimenti finestra normale.
- Con il browser nascosto macOS non lascia guardare: si usa l'ultima cosa vista per
  quella finestra.

**B-3 Abbinare le finestre.** Le finestre sullo schermo vanno abbinate a quelle
descritte dal browser, dal modo più sicuro al meno sicuro:
1. stesso titolo **e** stessa posizione/misura (tolleranza 4 punti);
2. titolo che **inizia** con quello del browser seguito da uno spazio, e stessa
   posizione (Chrome con più profili aggiunge "- Lavoro");
3. stesso titolo; 4. inizio del titolo — questi due **solo per finestre grandi**
   (la miniatura di Meet ha lo stesso titolo della pagina);
5. solo posizione, **solo se è unica** da entrambe le parti.
Prima di tutto (passaggio 0, v9.40) vale il **numero che il browser dà alla finestra**
(non cambia mai), ricordato dall'ultimo abbinamento sicuro (titolo che nessun'altra
finestra ha): così più finestre con lo stesso titolo e la stessa misura (due "Meet")
non si scambiano più nomi e siti. Una finestra nata stretta (presa per finestrella) che
poi allarghi torna una finestra normale.
*Perché:* Tabby adatta tutte le finestre allo stesso spazio, quindi la posizione da
sola di solito non distingue (v9.10 scambiava Sofascore e Google).
Memoria: se una finestra non si abbina ma era abbinata prima, si usa l'ultima
descrizione (Meet e Gmail cambiano titolo di continuo).

**B-4 Webapp.** Una finestra è una webapp se **tutte** le sue schede sono dello
stesso dominio (minuscolo, senza `www.`). Chiave `site:<dominio>`.
Nome (`siteName`): si toglie un "(3) " iniziale; si divide il titolo sui separatori
(` - `, ` — `, ` – `, ` | `, ` · `, ` • `, ` :: `); poi, in ordine:
1. il pezzo (≤ 24 lettere) che contiene il nome principale del dominio
   (`mail.proton.me` → "proton" → "Proton Mail");
2. un pezzo uguale a un'etichetta del dominio di almeno 3 lettere ("Meet");
3. l'ultimo pezzo, se i pezzi sono almeno 2 e l'ultimo è lungo 2–24 ("… - Gmail");
4. il nome del dominio con l'iniziale maiuscola ("Youtube").
Icona: il logo del sito (vedi B-6).

**B-8 Rinominare**: **tasto destro sulla scheda** (v9.42; prima era nel menu della ✕;
dalla v9.45 anche la scelta del sito è solo qui, non più col clic sull'icona) →
«Rinomina la scheda…»; vale per ogni scheda tranne viste divise e cartelle; il nome resta
finché la finestra (o l'app, se è in una scheda sola) è aperta, anche dopo un
ricaricamento di Tabby; «Torna al nome di prima». Nello stesso menu, per le finestre di
browser, i siti da mostrare. **Scegliere il sito**: clic sull'icona di una finestra di browser con più
siti → l'elenco dei siti aperti (con i loghi); scelto uno, la scheda prende nome e logo
di quel sito finché quel sito è aperto nella finestra, poi torna «Chrome». Con
DuckDuckGo (che dice solo il sito della scheda in vista) la scelta resta finché la
finestra è aperta.
*App Swift 0.9.5:* tasto destro → «Mostra come» con i siti della finestra, e «Il nome del browser» per tornare indietro.
*App Swift 0.13.2:* «Mostra la scheda come» (coi loghi e la spunta) compare con **un solo** sito conosciuto, come in Hammerspoon: con DuckDuckGo (che dice solo la scheda in vista) prima non compariva mai. Le voci (0.13.4, Daniele): i siti della finestra con le icone piccole e la spunta su quello mostrato — con DuckDuckGo, che dice solo la scheda in vista, quelli **visti** in quella finestra (dal più recente, fino a 10: un sito compare dopo che hai guardato la sua scheda); quando la scheda mostra un sito, **«Come il browser «DuckDuckGo»»** (nome e icona del browser, anche con un sito solo).

**B-5 Finestre di browser non webapp.** Come S-2, con il nome breve del browser
("Chrome") al posto del nome dell'app; il titolo usato è quello dato dal browser
(senza il nome del profilo).

**B-6 Loghi dei siti.** Scaricati una volta e ricordati, provando in ordine: servizio
loghi di DuckDuckGo per il dominio, poi per il dominio principale, Google
(`s2/favicons?sz=64`), infine `https://dominio/favicon.ico`. Un'immagine valida è
larga almeno 8 punti. Se falliscono tutte (es. Wi-Fi non ancora connesso) si
riprova dopo 60 s. Arrivato il logo → si ridisegna.

**B-7 Finestrelle.** Non sono schede, Tabby non le ingrandisce, non le riduce e non
le conta come finestre "vere":
- **miniatura video** (Meet "picture in picture", barra "stai condividendo"):
  finestra di browser piccola (meno di metà larghezza **e** meno del 60% dell'altezza
  dello spazio delle app) che il browser non elenca. Un browser con una miniatura
  aperta **non si nasconde** (sparirebbe anche lei).
- **popup di accesso/pagamento**: finestra di browser che nasce più stretta del 60%
  dello spazio delle app (es. "Accedi con Google").

**B-9 Siti doppi** (v9.60): quando una finestra di browser con un solo sito (webapp)
compare — o passa a quel sito — e lo stesso sito è già aperto da solo in un'altra
finestra (anche di un altro browser), in alto al centro dello spazio delle app compare
un **avviso** (stile notifiche di macOS, non prende la tastiera): «Gmail è già aperto in
un'altra finestra» con **Lascia** · **Vai a quella** · **Chiudi questa** (blu: chiude la
finestra nuova e ti porta all'altra). Una volta per finestra; sparisce da solo dopo
12 s. Solo per finestre "nuove" da meno di 2 minuti; quello che si vede nei primi 15 s
dopo l'avvio di Tabby c'era già e non conta.
*App Swift 0.9.3:* il sito conta come già aperto anche se è una delle schede di una finestra più vecchia (Chrome, Safari) o la scheda in vista di DuckDuckGo; l'avviso dice il nome della finestra nuova.

## 4. Passare da una scheda all'altra

**P-1 Clic o ⌃⌥+numero** (`switchTo`):
- scheda-cartella → apre la cartella (8);
- vista divisa → mostra tutta la vista (7);
- scheda-finestra → porta davanti quella finestra (P-2);
- app → come cliccarla nel Dock (apre l'app o le riapre una finestra).

**P-2 Portare davanti una finestra.** Si mostra l'app se era nascosta, si riapre la
finestra se era ridotta, le si dà l'attenzione. Poi Tabby **ricontrolla dopo 0,25 s
e 0,6 s** che la tastiera sia davvero su quella finestra (macOS a volte ignora la
prima richiesta mentre la finestra si riapre) e, se serve, la ridà. Una scelta nuova
annulla i controlli di quella precedente. La finestra scelta viene segnata come
"scelta da te" per 3 s (serve a P-5 di 5).

**P-3 Quando cambia l'app in primo piano** (`handleActive`, 0,1 s dopo l'avviso di
macOS):
1. app veloce → la si mette in alto a destra (14), niente altro;
2. finestra a schermo intero → solo aggiornare lo stato (12);
3. azione rapida appena partita per quell'app (3 s) → non nascondere niente (15);
4. modalità scrivania: il Finder va bene; se macOS "rimbalza" su un'altra app entro
   1,2 s, la si rinasconde; dopo, la scrivania finisce;
5. altrimenti si aggiornano "scheda attiva" e "scheda di prima" (per ⌃⌥Tab), e
   l'ultima scheda usata della cartella in cui è;
6. se la scheda è in una vista divisa → si dispone tutta la vista (e di nuovo dopo
   0,6 s); altrimenti si nascondono le altre app, **si ridisegna subito la barra**
   (prima di toccare le finestre: dopo l'app è occupata e risponde lenta), si
   riducono le altre finestre della stessa app (5), si adatta la finestra (e di
   nuovo dopo 0,6 s: alcune app creano le finestre in ritardo).
*App Swift 0.10.2:* un'app che non sta nel Dock («Informazioni su questo Mac», le finestre delle app della barra dei menu) non è una scheda e non nasconde le altre.

**P-4 Scheda attiva** (per evidenziarla): la scheda della finestra in primo piano;
se è in una vista divisa, la scheda della vista; nella vista normale, una scheda di
una cartella attiva = la scheda-cartella; altrimenti la prima scheda della stessa
app. Nessuna in modalità scrivania.

**P-5 ⌃⌥← / ⌃⌥→** (e ↑ / ↓ con Tabby laterale): scheda precedente / successiva tra
quelle visibili, **in tondo**. Senza scheda attiva: → va alla prima, ← all'ultima.

**P-6 ⌃⌥Tab**: torna alla scheda usata prima (se esiste ancora).
*App Swift 0.12 (fase 1, 12/11/2026):* ⌃⌥Tab è il **selettore con le anteprime**: tenendo ⌃⌥, Tab va avanti e ⇧Tab indietro fra le schede in ordine d'uso (le più recenti prima), Esc annulla, lasciando ⌃⌥ si va alla scelta; compare dopo 0,18 s, quindi un Tab veloce torna alla scheda di prima come prima. Miniature: foto della finestra 1,2 s dopo l'arrivo e all'apertura del selettore (in memoria, al massimo 480 punti), solo col permesso «Registrazione schermo» (Tabby non lo chiede da sola: una riga nel selettore); senza, l'icona dell'app.

**P-7 Cambio di finestra dentro la stessa app** (⌘`, clic su un'altra finestra):
0,15 s dopo, se l'app è un browser o ha finestre separate e la scheda è cambiata, si
rifà P-3; altrimenti si ridisegna solo.

## 5. Una scheda alla volta e adattamento delle finestre

**U-1 Nascondere le altre app** (⚙︎ → Una scheda alla volta, acceso di serie):
passando a una scheda si nascondono tutte le altre app, tranne: quelle della scheda
(o della vista divisa), le app con una finestra a schermo intero, i browser con una
miniatura video aperta. Le app restano aperte.

**[Swift, deciso da Daniele il 9/11/2026] U-2 non c'è più:** scegliendo una finestra, le
altre della stessa app **restano aperte dietro** (non si riducono nel Dock); Tabby adatta
tutte le finestre dell'app allo spazio delle app, così quella davanti copre le altre. In
corsivo/attenuate restano solo le finestre ridotte da te.
**U-2 (Hammerspoon) Ridurre le altre finestre della stessa app.** macOS nasconde solo app intere:
le altre finestre-scheda della stessa app si **riducono a icona** (tornano quando le
scegli). Solo se:
- la finestra in primo piano l'hai **scelta tu** (clic/scorciatoia su Tabby, o
  appena aperta con ⌘N) negli ultimi 3 s — *perché:* se l'attenzione la sposta macOS
  (mentre riduce una finestra) si innescava un ping-pong di finestre che comparivano
  e sparivano (22/10);
- è una finestra standard, non una finestrella;
- non è una finestra piccola di browser (potrebbe essere la miniatura).
Mai per le app veloci, mai per le app con finestre in una scheda sola.
Tabby ricorda l'**ordine d'uso** delle finestre di ogni app (serve a 6).

**U-3 Adattare** (⚙︎ → Adatta le finestre a Tabby, acceso di serie): la finestra
prende **esattamente lo spazio delle app**. Non si toccano: finestre non standard, a
schermo intero, finestrelle, app veloci, Hammerspoon, finestre su un altro schermo.
Se la misura è già giusta (±1 punto) non si chiede niente a macOS (*perché:* ogni
ridimensionamento è lento se l'app è impegnata, es. Chrome durante Meet). Una
finestra nuova dell'app in primo piano si adatta subito (tranne piccole di browser,
che si decidono quando il browser ha risposto).

## 6. Chiudere

**C-1 ✕ su una scheda** → menu: "Chiudi finestra «titolo»" (per una
scheda-finestra proprio quella finestra; titolo accorciato a 40 lettere) e "Chiudi
<app>" (l'app intera: "Chiudi Chrome", non "Chiudi Gmail"). Il Finder: "Il Finder non
si può chiudere" (disattivato).
*App Swift 0.9.8 (Daniele):* **doppio clic sulla ✕** chiude subito la finestra; il clic singolo apre il menu dopo un attimo (al massimo 0,3 s, il tempo di capire se arriva il secondo clic).
*App Swift 0.10.11:* il doppio clic segue la velocità del doppio clic del Mac (di serie 0,5 s; prima 0,3 s e un doppio clic lento apriva il menu). Se è la **sola finestra** dell'app chiude **l'app** (Discord, Slack, Spotify chiudendo la finestra restano in sottofondo); con altre finestre, il Finder e i browser solo la finestra. Dopo, come sempre (C-4), la scheda accanto.

**C-2 ⌃⌥W** chiude la finestra in primo piano, non l'app. In un browser chiude la
finestra intera (⌘W chiuderebbe solo la scheda del browser). Mai app veloci,
Hammerspoon, finestre non standard.

**C-3 Chiusa una finestrella** (accesso con Google, pagamento: non è una scheda):
se dell'app in primo piano restano solo finestre ridotte, 0,3 s dopo si riapre
**l'ultima usata** tra le ridotte, invece di lasciare il desktop vuoto.
*App Swift 0.9.5:* fatto (diario «finestrella chiusa: riapro …»).

**C-4 Chiusa o ridotta la scheda attiva → scheda accanto, sempre** (v9.38, Daniele:
"indipendentemente dal comportamento selezionato"). In qualsiasi modo: ✕ di Tabby,
⌃⌥W, pallino rosso, ⌘W, ⌘Q, pallino **giallo** / ⌘M. 0,35 s dopo, se nessuna finestra
della scheda è ancora aperta e non ridotta, si passa alla **scheda accanto**: quella a
sinistra, o a destra se era la prima (se non c'è più, quella nella stessa posizione).
Una scheda ridotta resta sulla barra: cliccandola la finestra torna. Non vale in
modalità scrivania, né per le riduzioni fatte da Tabby stessa (una scheda alla volta,
scrivania). A ogni disegno Tabby annota la scheda attiva (chiave, posizione, scheda
accanto, finestre, app) e tiene anche quella di prima per 1,5 s: macOS a volte attiva
un'altra app un istante prima di dire che la finestra è chiusa. Un'app che si chiude
(✕ → Chiudi app, ⌘Q) può metterci qualche secondo (Spotify, v9.42): le sue finestre non
contano più e Tabby riprova fino a 4 s; se nel frattempo scegli tu un'altra scheda, non
ti sposta.
*App Swift 0.10.1:* una scheda comparsa da sola da meno di 20 s, della cui app non resta niente (un'app che si apre e si chiude da sé), chiusa → si torna alla scheda usata prima, non a quella accanto. Utility Compressione non è mai una scheda. Un'app chiusa con ⌘Q che lascia il Finder senza finestre (la Scrivania vuota) → si torna all'ultima scheda.

**C-5 ⚙︎ → Chiudi tutte le app…** chiede conferma; chiude tutte le app (le app con
documenti non salvati chiedono loro); del Finder chiude solo le finestre.
*App Swift 0.11 (Daniele):* ⚙︎ → **Chiudi le app** → «Tutte le app» oppure «Solo quelle senza finestre» (le app aperte che non vedi in Tabby): si chiude solo un'app senza schede in Tabby **e** senza finestre per macOS (nemmeno nascoste o ridotte), con un avviso che dice quali. Anche nella ricerca.

## 7. Vista divisa (codice: gruppi)

**D-1 Schemi** (zone in frazioni dello spazio delle app, x, y, larghezza, altezza):

| Schema | Zone |
|---|---|
| 2 · metà e metà | (0,0,½,1) (½,0,½,1) |
| 2 · 70 / 30 | (0,0,0.7,1) (0.7,0,0.3,1) |
| 3 · una sopra, due sotto | (0,0,1,½) (0,½,½,½) (½,½,½,½) |
| 4 · quarti | (0,0,½,½) (½,0,½,½) (0,½,½,½) (½,½,½,½) |

Tra le finestre uno spazio di 3 punti per lato. Schema "di serie" per numero di app:
2 → metà e metà, 3 → tre, 4 → quarti.

**D-2 Creare** (tasto ⊞ → schema): compare un velo scuro sullo spazio delle app con
le zone (bordo tratteggiato se vuote) e un pannello in basso "Trascina le schede di
Tabby nelle zone" · Annulla (Esc) · Fatto (Invio). Si parte da quello che stai
guardando: la scheda attiva nella zona 1 (o le schede della vista divisa attiva).
- trascinare una scheda su una zona la mette lì (la zona si illumina);
- **clic** su una scheda = prima zona libera (comodo col trackpad);
- clic su una zona piena = svuotala;
- tutte le zone piene → 0,35 s dopo la vista nasce da sola;
- Fatto/Invio con zone vuote → vista con le app messe, schema adattato al numero;
  una sola app → nessuna vista, si va su quell'app; Esc/Annulla → niente.
Sopra il pannello in basso compare la **fila dei Lampi aperti** che non sono in una
zona (v9.45): si trascinano su una zona o si cliccano (prima zona libera); un Lampo tolto
da una zona per sbaglio torna nella fila. Il velo e le zone stanno **sopra tutte le finestre** (anche le app veloci e il Memo) e
Tabby sopra di loro, per trascinarci le schede (v9.42; stesso per il riquadro delle
cartelle). Le **app veloci aperte** (Terminale, Calcolatrice…) entrano già nelle zone libere (un
clic sulla zona le toglie); nella vista diventano app normali (v9.39). Anche il **Memo**
aperto entra in una zona (v9.44): nella vista sta nella sua zona; chiudendolo la vista si
scioglie. Se sei sul Memo o su un'app veloce, la zona 1 è la scheda in cui eri prima.
Una scheda entra in una vista sola (togliendola da un'altra vista). Le viste divise
e le cartelle non si mettono in una zona.
*App Swift 0.10.12 (Daniele, 12/11/2026):* il tasto ⊞ non è più nella barra: si divide da **⚡︎ → Strumenti → Dividi lo schermo** (gli schemi in un sottomenu; mentre dividi la voce diventa «Annulla la divisione»). Restano la ricerca («Dividi lo schermo») e ⌃⌥S per scambiare.

**D-3 La scheda della vista** prende il posto della prima app nell'ordine. Nome:
"Gmail + Slack". Icone affiancate (fino a 4). Tasti: **⇄ Scambia** e **Scomponi**.

**D-4 Mostrare una vista**: ogni app/finestra nella sua zona (si mostra, si riapre
se ridotta; si porta davanti alle altre finestre dello stesso browser **solo quando
scegli la vista**), le altre app si nascondono, le altre finestre delle stesse app si
riducono. Una finestra già al suo posto (±2 punti) non si tocca. *Perché:* portare
davanti una finestra la rende "attiva" per macOS, che lo annuncia, e Tabby ridisponeva
la vista: con due finestre dello stesso browser (due Tally) vibravano all'infinito. Attenzione sulla
scheda della vista usata per ultima. Ridisposta dopo 0,35 s (o 0,6 s se ci si
arriva da macOS). Una finestra nuova di un'app della vista (con finestre in una
scheda sola) va nella sua zona se la vista è attiva.

**D-5 Scambia** (⇄ o ⌃⌥S): le app ruotano di una zona (con due si scambiano).

**D-6 Scomponi**: le schede tornano singole, al posto della vista; si resta su
quella che guardavi.
*App Swift 0.9.3:* scomponendo si resta sulla scheda della vista usata per ultima (mai sulla «scheda accanto»), e **ogni** finestra della vista torna a tutto spazio, anche quelle dei browser.

**D-7 Una vista segue le sue finestre.** Una finestra di browser nella vista è
seguita per numero di finestra: se cambia chiave (Gmail apre un link di un altro
sito e non è più una webapp) resta nella vista con la chiave nuova; quando torna
webapp, torna la chiave del sito. Un'app chiusa esce dalla vista; con meno di 2 app
la vista si scioglie, altrimenti prende lo schema adatto al numero rimasto. Le viste
sono salvate (anche dopo un riavvio di Tabby).

**D-8 Notifiche** della vista = somma (9).

## 8. Cartelle

**F-1 Ricetta.** Una cartella ha nome e voci. Tipi di voce:
- **app** `{bid}`: l'app intera (per un browser: le sue finestre normali, non le webapp);
- **webapp** `{site, bid}`;
- **finestra con pagine** `{bid, pages}` (Chrome/Safari con più siti): elenco degli
  indirizzi, **senza la parte dopo `?` e `#`** (lì finiscono codici di accesso), solo
  http(s); nome "Titolo · 3 pagine";
- **finestra precisa** `{bid, win, title, host}`: una finestra di DuckDuckGo (che non
  dice gli indirizzi) o una delle più finestre di un'app (es. una finestra del
  Finder); si riconosce dal titolo e, per DuckDuckGo, dal sito in vista.
Ogni voce ha una chiave (`site:…`, `pagine:bid:primapagina`, `finestra:bid:titolo:host`,
o il bundle ID). **Una voce sta in una sola cartella**: salvandone una, le altre la
perdono (e una cartella rimasta vuota si cancella).

**F-2 Il motore: quale scheda va in quale voce.** Per ogni cartella attiva
(nell'ordine di attivazione), per ogni voce:
1. se la voce è **legata a una finestra** ancora aperta, prende la scheda di quella
   finestra (anche se ci hai navigato dentro);
2. altrimenti la prima scheda libera che corrisponde alla voce (webapp: stesso sito;
   pagine: almeno **metà** delle schede della finestra sono di siti della voce;
   finestra precisa: stesso titolo o stesso sito in vista; app: stessa app, non webapp);
3. ogni voce prende **al massimo una** scheda; ogni scheda va in una sola cartella;
   le altre finestre dello stesso browser o app restano fuori.
La scheda presa lega la voce alla sua finestra (`itemWins`, salvato: vale anche dopo
un ricaricamento). Una vista divisa corrisponde se uno dei suoi membri corrisponde.

**F-3 Creare** (⚙︎ → Cartelle → Nuova cartella…; fino alla v9.66 era in ⚡︎): si chiede il nome ("es. Lavoro, Studio"),
poi compare un riquadro con già **la scheda in cui sei**; ci si trascinano (o si
cliccano) le altre schede; "rinomina"; Esc annulla, Invio/Fatto salva. Le voci stanno
in una **griglia che va a capo** (v9.60; prima oltre 6 voci si vedeva solo «+N»): il
riquadro cresce con le righe, ognuna ha icona, nome e una **✕ tonda** in alto a destra
per toglierla; nel titolo quante sono. Con tantissime voci (più alte dello schermo) le
voci si rimpiccioliscono. La
voce si lega alla finestra scelta (es. quale delle due Gmail). Avviso: "Cartella
«Lavoro» salvata · dal gatto o ⌃⌥⇧2". Una vista divisa aggiunta = i suoi membri.

**F-4 Attivare** (clic sul gatto → nome della cartella, o ⌃⌥⇧ + numero nell'ordine delle cartelle):
1. apre le voci che mancano **senza portartele davanti**: webapp di Chrome/Safari in
   una finestra nuova; pagine in una finestra nuova con tutte le schede (altri
   browser: come schede); DuckDuckGo: il sito come scheda; un browser già aperto per
   una voce "app": una finestra nuova; un'app: aperta in secondo piano. La prossima
   finestra nuova di quell'app entro 8 s viene legata alla voce;
2. **ricetta fissa**: nella finestra con pagine già aperta, le pagine che mancano
   (nessuna scheda più di quel sito) si riaprono **in quella finestra** (tramite il
   suo numero per il browser);
3. se un'app appena aperta ti porta via, dopo 1,2 s e 2,5 s Tabby ti riporta alla
   finestra in cui eri;
4. la cartella diventa attiva (con "Vista cartelle" spenta: solo aprire, schede
   normali). Se sei su una sua scheda entri nella **vista cartella**; se sei altrove
   la cartella compare come **una scheda sola** e resti dove sei.
5. **due o più voci da aprire** (v9.65, al posto del velo della v9.60): **prima** si
   copre tutto lo schermo, barra di Tabby compresa, con una schermata piena, senza
   trasparenza (pagina `tabby/apertura.html`): lo sfondo della Scrivania rimpicciolito e
   sfocato, il nome della cartella, le icone delle voci (spente, che "respirano"; si
   accendono quando la loro finestra è arrivata) e una barretta. Le app partono solo
   quando la pagina dice che lo schermo è coperto (dopo la dissolvenza di 0,22 s; al
   massimo 0,8 s). La schermata sfuma (0,38 s) quando sono arrivate tutte **e** è passato
   1 s dall'ultima **e** almeno 2,9 s dall'inizio (dopo il ritorno alla finestra di prima,
   punto 3); al massimo 7 s. Un clic la toglie subito. *Perché:* le finestre che arrivano,
   vengono adattate e nascoste non si devono vedere ("sembra che qualcosa non vada").
⌃⌥⇧ + numero sulla cartella che stai già guardando → torni a tutte le schede.

**F-5 Scheda-cartella** (vista normale): sta dove l'hai messa (`f:<n>` nell'ordine)
o al posto della sua prima scheda. Prime 3 icone sovrapposte, nome, somma delle
notifiche, tasto **⋯**. Clic → menu con le sue schede (spuntata l'ultima usata):
scelta una, entri nella vista cartella su quella scheda; più "Altre azioni".
⋯ → Apri la cartella · Esci dalla cartella (le schede tornano libere) · Chiudi
cartella (chiude le sue N schede)… · Aggiorna con le schede di adesso · Modifica le
schede… · Rinomina…

**F-6 Vista cartella**: solo le schede della cartella; in cima (laterale) o a
sinistra (orizzontale) "← Tutte le schede" e "▾ Nome" (menu ⋯). ⌃⌥1…9 e le frecce
contano solo le schede visibili. Entrandoci si torna all'**ultima scheda usata**
della cartella (o alla prima). Un'app aperta fuori dalla cartella si vede nella vista
generale.

**F-7 Chiudi cartella** (con conferma): chiude le sue app; per i browser e il Finder
chiude **solo le sue finestre**. Poi la cartella si spegne.

**F-8 Aggiorna con le schede di adesso**: la ricetta diventa quello che c'è ora
nella cartella (finestre con le pagine di adesso, voci chiuse tolte). Una finestra
che era una voce "pagine" resta "pagine" anche se ora ha una pagina sola.

**F-9 Spegnimento automatico**: una cartella attiva senza più schede (app chiuse) si
spegne, ma non nei primi 20 s dopo l'attivazione (le app ci mettono a aprirsi).

**F-10** ⚙︎ → Cartelle → Modifica le cartelle → Modifica le schede / Rinomina / Elimina. Anche il
**tasto destro sulla scheda-cartella** apre il suo menu (con Rinomina…) (v9.60).
⚙︎ → Comportamento → Vista cartelle (acceso di serie).
*App Swift 0.9.3:* ⚡︎ → Cartelle → «Modifica o elimina…» per ogni cartella, anche spenta; nel foglio «Modifica la cartella» c'è «Elimina la cartella» (con Annulla nell'avviso).

## 9. Notifiche

**N-1 Dal Dock**: Tabby legge i numerini (o il pallino) che le app mostrano sul
Dock (`AXStatusLabel` di ogni icona del Dock), ogni 5 s; l'icona si abbina all'app
dal percorso dell'app (o dal nome). Vanno sulla **prima** scheda dell'app.
**[Swift]** da verificare con il Dock nascosto o sostituito (roadmap).

**N-2 Dal titolo delle webapp**: `"(3) WhatsApp"` o `"Posta (12) - …"`.

**N-3 Somma**: vista divisa e scheda-cartella mostrano la somma; se ci sono solo
pallini senza numero, un pallino "•".

**N-5 Notifiche di macOS** (v9.41): non compaiono sopra Tabby. macOS (26) le disegna in
una finestra trasparente grande come lo schermo, che si può spostare con
l'Accessibilità: con Tabby in alto la si abbassa di quanto è alta Tabby (anche quando è
scesa sotto la barra dei menu), con Tabby a destra la si sposta a sinistra della sua
larghezza; in basso, a sinistra, a schermo intero o con Nascondi Tabby resta dov'è.
*App Swift 0.9.4:* fatto, con un avviso dell'Accessibilità quando nasce la finestra delle notifiche (nessun controllo periodico); diario «notifiche spostate di …».

**N-4 Disegno**: pallino rosso col numero prima della ✕ (oltre 99: "99+"); sulle
schede compatte un puntino rosso.

## 10. La barra: disegno e misure

Sfondo con gli **angoli smussati** (raggio 12) dalla parte delle app e dritti contro il
bordo dello schermo (v9.38). Colori: barra **nero pieno** (`#000000`); scheda attiva `#2C2F36`; accento `#4C8DFF`;
divisori `#2A2D33`; testo `#E8E9EC` / medio `#B9BDC6` / tenue `#7D828C`; batteria
piena `#34C27A`, scarica `#FF6B57`; notifica `#FF453A`.

**L-1 Orizzontale** (in alto o in basso): altezza 38. Da sinistra: **scrivania**
(gatto, 44), [vista cartella: ← e nome, larga fino a 210], schede, scheda **+**
(36, apre Spotlight), … a destra: **batteria** (76), **⊞**, **⚡︎**, **⚙︎** (44
ciascuno), con divisori.
Schede: larghezza = spazio / numero, al massimo 210; se non ci stanno si stringono
fino a 120; sotto i 120 → **modalità compatta**: solo icona (44), l'attiva resta
larga (160) col nome; se non ci stanno neanche così, le ultime vanno nel menu
**"+N"** (la scheda attiva resta sempre visibile).

**L-2 Verticale** (a sinistra o a destra): larghezza 190. In cima la **scrivania**:
con le immagini del gatto intero alta 92, altrimenti 44; [vista cartella: "←  Tutte
le schede" e "▾ Nome"]; poi le schede (righe da 36, che si abbassano fino a 26), poi
"+N altre" se non ci stanno, poi **+**; in fondo la batteria (30) e la fila ⊞ ⚡︎ ⚙︎
(44, tre terzi).

**L-3 Una scheda**: icona (20; logo del sito per le webapp), nome (13, troncato con
"…"), notifica, ✕. Attiva: sfondo arrotondato e una lineetta d'accento (sotto in
orizzontale, a sinistra in verticale), testo chiaro. Vista divisa: icone affiancate,
⇄ e Scomponi al posto della ✕. Cartella: 3 icone sovrapposte, ⋯ al posto della ✕.
Compatta: solo l'icona, con puntino rosso (notifica) o un quadratino col numero di
membri (vista/cartella).
*App Swift 0.9.3:* i servizi comuni hanno il loro nome per dominio (mail.proton.me → «Proton Mail», mail.google.com → «Gmail»…) e un indirizzo email o web non è mai il nome. Un nome che non ci sta perde le ultime parole («Proton Mail» → «Proton»); i puntini solo se non basta la prima parola.

**L-4 Gatto (tasto scrivania)**: testa del gatto grigia a riposo, chiara con la
scrivania attiva (`assets/gatto-spento.png`, `gatto-acceso.png`). Con Tabby
laterale, il **gatto intero**: a destra guarda verso sinistra (verso le app), a
sinistra il contrario (`gatto-intero-<destra|sinistra>-<spento|acceso>.png`), il
più grande possibile nello spazio in cima (margini 14 ai lati, 8 sopra e sotto).
Senza immagini: un piccolo schermo disegnato.

**L-5 Batteria** (v9.49): **solo l'icona** (pila con riempimento proporzionale, verde da
80% in su, rossa sotto il 35% se non è in carica, normale altrimenti; ⚡︎ dentro se in
carica), in uno spazio di 44 punti. **Passandoci sopra col puntatore** compare un fumetto
con la percentuale («72%», «72% · in carica»), accanto alla batteria dalla parte delle app.
Solo sui Mac con batteria. Si rilegge solo quando macOS avvisa di un cambio.
*App Swift 0.13 (fase 1, 12/11/2026):* al posto della batteria il **cruscotto** (centro di
controllo): tasto `gauge.with.dots.needle.67percent`, puntino rosso con batteria sotto il 20% e non
in carica. Un clic apre il pannello attaccato al tasto, nello stile dei fogli (chiude: clic fuori,
Esc, di nuovo il tasto). **Tessere componibili** (`tabbar.ccTessere`; «modifica →» nel pannello o
Preferenze → Il cruscotto: togli, riordina trascinando, aggiungi): **Ora e data**; **Batteria**;
**Meteo** (Open-Meteo, gratis; città scritta la prima volta nella tessera, `tabbar.ccCitta`; oggi
+ 3 giorni, ← → per gli altri; al massimo ogni ora); **Musica** (Spotify e Musica: titolo,
artista, indietro/pausa/avanti con AppleScript; Tidal: tasti multimediali; app scelta in
`tabbar.ccMusica`); **Borsa** (Yahoo Finance non ufficiale, `tabbar.ccTitoli`, di serie STZ,
DSY.PA, XYZ; al massimo ogni 15 min; «Borsa non disponibile» se non risponde); **Mac** (processore
e memoria ogni 2 s solo a pannello aperto, GPU); **Tempo d'uso** di oggi (contato da Tabby al
cambio d'app, fermo con lo schermo spento, `tabbar.usoOggi`). Con la Concentrazione il suo
cerchio sta accanto al cruscotto. A pannello chiuso: nessun lavoro.

**L-6 Livello della finestra di Tabby**: sopra le finestre normali, sotto la barra
dei menu quando scende; su tutte le scrivanie; i clic non le danno l'attenzione (non
ruba la tastiera all'app). Se macOS la spinge sotto (fascia del notch), Tabby sale di
livello finché resta in cima (floating → dock → mainMenu → status → popUpMenu) e lo
scrive in console.

## 11. Posizione, notch, Nascondi Tabby

**A-1 Posizione** (⚙︎ → Posizione): in alto (di serie), in basso, a sinistra, a
destra. Cambiandola (e cambiando fascia del notch o Nascondi Tabby) si rimette a misura
quello che stai guardando: l'app in uso (anche se in primo piano c'è un Lampo o il Memo)
o la sua vista divisa, le altre app in vista, e i Lampi in fila nello spazio nuovo; poi si
ricontrolla dopo 0,4 s (v9.49). Lo spazio delle app è lo schermo utile (senza barra dei menu e Dock) meno la
barra di Tabby da quel lato.

**A-2 Notch.** Tabby chiede a macOS dove sono le parti di schermo ai lati della
tacca (aree ausiliarie in alto a sinistra e a destra). Se macOS non risponde, stima:
schermo interno con proporzioni più "alte" di 0,64 → notch largo 210 al centro.
**Fascia del notch** (solo con Tabby in alto): automatica se c'è il notch **e** la
barra dei menu è impostata su "nascondi sempre" (letto dalle preferenze di sistema,
ricontrollato ogni 30 s); oppure forzata accesa/spenta a mano (⚙︎ → Posizione → Usa
la fascia del notch; "torna automatico"). Con la fascia: Tabby sale in cima, nella
striscia accanto al notch, e **le schede saltano il notch** (nessuna scheda sotto la
tacca, margine 6); le app partono subito sotto Tabby. Quando scende la barra dei menu di
macOS, Tabby esce dallo schermo e poi rientra (A-6).

**A-3 Nascondi Tabby** (⚙︎ → Comportamento): Tabby è nascosta e le app usano tutto
lo schermo; appare portando il mouse sul **bordo** dalla sua parte (entro 2 punti) e
si nasconde quando il mouse esce (margine 12; in alto conta anche la barra dei menu
sopra Tabby). In alto con la barra dei menu che scende: Tabby si mette sotto di lei.
Durante trascinamenti, divisione o creazione di cartelle resta visibile.
*App Swift (0.9.2, decisione di Daniele del 10/11/2026):* **Nascondi Tabby non c'è più**:
«se usi Tabby la tieni sempre». Con la barra in alto, col menu di Apple che scendeva, dava
uno scatto. Un vecchio `autohide` salvato si cancella all'avvio.

**A-4 Controllo del mouse** (12 volte al secondo): **acceso solo** con Nascondi
Tabby o quando barra dei menu / Dock possono coprire Tabby (A-6); spento negli altri
casi (consumo).

**A-6 Barra dei menu e Dock che si nascondono da soli** (v9.43, al posto di "attaccata
sotto la barra dei menu" della v9.41): quando compaiono **dalla parte di Tabby** e la
coprirebbero, Tabby **scivola fuori dallo schermo** dal suo lato (6 passi in ~0,13 s) e
rientra quando se ne vanno. Coprono Tabby: la barra dei menu (su "nascondi sempre") se
Tabby è **in alto**; il Dock (che si nasconde da solo) se sta **dallo stesso lato** di
Tabby. Negli altri casi non cambia nulla (es. Tabby a destra e barra dei menu: copre solo
l'angolo del gatto). Tabby non vede direttamente barra e Dock: lo deduce dal puntatore
(tocca quel bordo dello schermo → compaiono; si allontana oltre l'altezza della barra dei
menu, 30 punti su macOS 26, o lo spessore del Dock + 10 → se ne vanno). Lato, "nascondi"
e dimensione del Dock si leggono dalle preferenze di macOS all'avvio e ogni 30 s.
Se Tabby non è in vista (cerchio sulla scrivania, chiusa, schermo intero, «Nascondi
Tabby» non rivelata) non scivola né rientra: resta nascosta (v9.59; prima ricompariva per
un istante).
*App Swift:* in alto con la barra dei menu nascosta (o nella fascia del notch) Tabby **si
toglie di mezzo** quando il mouse tocca la cima e torna quando scende sotto l'altezza della
barra dei menu (scelta di Daniele del 10/11/2026: non si mette sotto il menu).

**A-7 Fascia nera in cima con Tabby di lato** (v9.45): con Tabby a destra o a sinistra e la
barra dei menu su "nascondi sempre" (senza notch), in cima alla colonna resta una fascia
nera alta come la barra dei menu; gatto e schede partono sotto. Quando la barra scende
copre solo la fascia: niente sparisce e niente si sposta.
*App Swift 0.9.4:* fatto (fascia vuota in cima alla colonna, solo senza notch).

**A-5 Cambio di monitor o risoluzione**: si rileva di nuovo il notch e si ridisegna.
Tabby usa sempre lo **schermo principale**.

## 12. Schermo intero

**Z-1** Una finestra a schermo intero **esce dai radar di Tabby**: non è una
scheda, non si adatta, non conta. Mentre la guardi Tabby **non si vede**; quando
torna normale rientra come scheda.

**Z-2 Come lo sa**: chiede a macOS il tipo della scrivania in vista ("fullscreen":
risposta immediata) oppure se la finestra in primo piano è a schermo intero.
Controlla subito e di nuovo dopo 0,25, 0,6 e 1,1 s a ogni cambio di app, di
scrivania, di schermo intero.

**Z-3 Anticipo**: al **clic sul pallino verde** (letto con l'Accessibilità solo se
il clic è nei primi 120×60 punti della finestra attiva) o a **⌃⌘F**, Tabby sparisce
**subito**, senza aspettare l'animazione; se dopo 2 s lo schermo intero non c'è,
ricompare.
*App Swift 0.9.6:* fatto (si guardano solo i clic, mai i movimenti; ⌃⌘F dall'intercettatore).

**Z-4** Le app con una finestra a schermo intero non si nascondono (U-1) e non
vengono nascoste dalla scrivania.
*App Swift 0.9.5:* fatto. Z-1: la barra non va sulle scrivanie a schermo intero. Z-3 (anticipo al pallino verde) non ancora.

## 13. Scrivania

**[Swift, Daniele 9/11/2026]** Il **musetto del gatto è la scheda Scrivania** (anche ⌃⌥0; ripremuto torna all'ultima
scheda): le app si nascondono, la barra resta col riempimento sul gatto. **Chiudi Tabby** (⚙︎,
sotto «Metti in pausa») nasconde
le app: resta la Scrivania del Mac con la sfera, e Tabby ricorda dov'eri. **Clic sulla sfera**:
se c'erano schede, si riaprono come le avevi lasciate (niente domande); il ventaglio (Nuova
app, cartelle) solo se non c'è nessuna scheda. Nella ricerca, una scheda che sta in una
cartella attiva apre la vista di quella cartella. (Sotto, le regole della versione Hammerspoon.)

**W-0 Il gatto = «casa»** (v9.66, deciso da Daniele il 31/10/2026; prima nella barra apriva
subito il Finder e nella sfera tornava all'ultima finestra). Un clic sul muso del gatto,
**nella barra o nella sfera**, mostra sempre le stesse scelte, in quest'ordine:
1. **«Torna a X»**: l'ultima scheda che stavi guardando (non quella in cui sei; Tabby
   ricorda le ultime 20 e salta quelle che non esistono più; in concentrazione solo le
   permesse) — solo se c'è;
2. **«+ Nuova app…»** (apre Spotlight);
3. **«Scrivania»** (il Finder sulla cartella Scrivania; ⌃⌥0 resta la scrivania di Tabby);
4. le **cartelle** (clic = attivala; accanto ⌃⌥⇧ + numero).
Nella barra sono un **menu** accanto al gatto (con le icone; «Cartelle» come titolo).
Dalla sfera si aprono **a ventaglio** intorno a lei (v9.52; dalla v9.54 come **piccole
sfere dello stesso stile**, di vetro colorato, che si accendono al passaggio): da 44 punti
su giri di raggio 92, 150, 208 (3, 4, 5 posti), da sinistra verso l'alto, una dopo
l'altra; «Torna a» e «Scrivania» con l'icona dell'app, il «+» senza icona, una per
cartella con le icone delle sue prime due app; il nome compare passandoci sopra (a
sinistra, o sopra se a sinistra c'è un'altra sfera). Sono nella stessa pagina della
sfera: la finestrella si allarga (420 punti) mentre il ventaglio è aperto e torna piccola
quando si chiude (clic fuori, Esc, o di nuovo la sfera).
*App Swift 0.9.3 (Daniele):* il musetto apre anche una finestra del Finder sulla cartella **Scrivania**; quella finestra è la scheda del gatto (non compare in barra) e si chiude quando vai su un'altra scheda.
*App Swift 0.9.7:* più veloce: subito la finestra della Scrivania e via le altre app insieme; le finestre del Finder non si riducono più una per una.

**W-3 Il cerchio sulla scrivania** (v9.51): quando non c'è **nessuna finestra in vista**
(app tutte nascoste, ridotte o chiuse, o ⌃⌥0; Lampi, Memo e Hammerspoon non contano) per
0,4 s, la barra sparisce e Tabby diventa un **cerchio nero di 56 punti col muso del gatto**,
sempre **in basso a destra**, a 60 punti dai bordi (v9.53, un po' verso il centro).
Disegno (v9.53–v9.54, stile "orb" degli assistenti AI come ElevenLabs): una **sfera viva** di
60 punti, con macchie di colore sfumate (ambra, viola, blu, un tocco di rosa) che ruotano
lente dentro, un riflesso, bordo più scuro e un alone che respira; dentro, **il gatto di
Daniele** (`assets/gatto-sfera.png`, ricavato dal suo disegno: il bianco resta, i tratti
neri diventano trasparenti e lasciano vedere i colori). **Reagisce al puntatore**:
avvicinandosi (entro ~200 punti) colori, gatto e riflesso si spostano verso di lui, la
sfera si gonfia e l'alone si accende; sopra, i colori girano più veloci. (Tabby legge la
posizione del puntatore 20 volte al secondo solo mentre la sfera c'è.) È una pagina web
trasparente (`tabby/cerchio.html`) in una finestrella che non ruba la tastiera; fatta solo
di strati che ruotano e si spostano, consuma quasi niente (misurato: Hammerspoon ~0,7%).
(Una versione disegnata dalla scheda grafica costava ~10%: scartata.) Clic = W-0. Appena compare una finestra torna la
barra. Non a schermo intero, né durante la divisione o la creazione di una cartella.
*App Swift 0.9.7 (Daniele):* la sfera compare **solo** se Tabby è chiusa o in pausa **e** sei sulla Scrivania (nessuna finestra in vista, niente schermo intero). Mai altrimenti (prima compariva anche con una finestra a schermo intero).

**W-4 Chiudi Tabby** (v9.54): ⚙︎ → «Chiudi Tabby (resta solo il cerchio)». La barra
sparisce e resta **solo la sfera** (con i colori più spenti); Tabby si ferma del tutto: non
nasconde né ridimensiona app, le scorciatoie ⌃⌥ e i gesti passano alle app, niente
controlli di browser e notifiche, niente scheda accanto né notifiche spostate. Le app
restano come sono (diverso da «Chiudi tutte le app»). **Un clic sulla sfera** e Tabby
riparte. Si ricorda anche dopo un riavvio (`paused`).
*App Swift 0.9.3:* Chiudi Tabby nasconde tutte le app in un colpo solo (anche il Finder, senza ridurre le sue finestre); barra via e sfera subito.
*App Swift 0.10.10:* «Metti in pausa» toglie subito la barra anche con finestre in vista (lì la sfera non c'è: la si trova sulla Scrivania); togliendo la pausa la barra torna. Prima, dalla 0.9.7, la barra restava ferma con le scorciatoie spente.
*App Swift 0.11 (Daniele, 12/11/2026):* **la pausa non c'è più** (da nessuna parte: menu, ricerca, finestra di Tabby, sfera); «Chiudi Tabby» copre lo stesso bisogno. Un vecchio `paused` salvato si cancella all'avvio.

**W-1 Scrivania, ⌃⌥0**: nasconde tutte le app (tranne il Finder
e quelle a schermo intero); il Finder resta in primo piano (*perché:* nascondendolo
macOS riattiverebbe un'altra app) e le sue finestre si riducono. Il tasto si
accende. Ripremuto: torna all'ultima scheda.
**W-2** Se entro 1,2 s macOS "rimbalza" su un'altra app, la si rinasconde; un'app
scelta dopo fa finire la scrivania.
*App Swift 0.9.5:* fatto (diario «rimbalzo su X dopo la Scrivania»).


## 14. Azioni veloci e Memo (tasto ⚡︎)

**Q-1 Lampi** (nel codice "app veloci"; nome deciso il 23/10/2026): Memo (⌃⌥M),
Calcolatrice (⌃⌥C), Calendario (⌃⌥A, 680×520),
Terminale (⌃⌥T, 760×480). Calcolatrice, Calendario e Terminale sono "veloci" **solo se
aperte con la loro scorciatoia o dal menu ⚡︎** (v9.39); aperte in un altro modo
(Spotlight, Dock) sono app normali: una scheda, a tutto spazio. Da veloci: si aprono
**in alto a destra** dello spazio delle app (margine 12), sopra quello che fai, **senza
nasconderlo**; più finestre a cascata (26 punti); non sono schede; **restano in vista e
sopra** anche cambiando scheda (Tabby le riporta davanti a ogni cambio di scheda e dopo
ogni clic, solo se sono coperte) **finché non premi Esc** su di loro o di nuovo la
scorciatoia (allora si nascondono e tornano app normali). **Il ripiano dei Lampi** (v9.47; la colonna riservata della v9.46 è stata tolta: troppo
limitante): macOS non permette di tenere la finestra di un'altra app sopra quella che usi
(provato su macOS 26), quindi Calcolatrice, Calendario e Terminale possono finire sotto.
Quando un Lampo è **coperto** (una finestra che non è un Lampo gli sta sopra e lo
sovrappone), **il tasto ⚡︎ si allarga** (v9.48: un solo ⚡︎ in Tabby) e accanto al fulmine
mostra le icone dei Lampi coperti e, se sono due o più, **«Tutti»**, su uno sfondo
arancione chiaro. Clic sul fulmine → il menu ⚡︎ di sempre; su un'icona → quel Lampo torna
davanti; «Tutti» → tutti, uno dopo l'altro. Così si vede che non sono stati chiusi. Con
Tabby in alto o in basso il tasto si allarga verso sinistra; di lato il ⚡︎ diventa una
riga larga quanto Tabby sopra ⊞ e ⚙︎ (che si dividono la fila sotto). Cambiando la
posizione di Tabby i Lampi si rimettono in fila. Si
aggiorna a ogni cambio di app o di finestra e dopo ogni clic. Il Memo, che è di Tabby,
sta sempre sopra e non va sul ripiano. La scorciatoia su un'app veloce
in vista ma senza tastiera le dà la tastiera. Se un'app rifiuta la misura, si rilegge
quella vera e la si riporta dentro lo schermo. Riprova a sistemarle dopo 0,3, 0,8, 1,6 s.
Si ricordano anche dopo un ricaricamento (`floatMode`).

**Q-1b In fila** (v9.44, regole della v9.46): più Lampi aperti insieme (Memo compreso)
stanno in fila in alto a destra, a 12 punti l'uno dall'altro: in colonne da destra verso
sinistra, o uno sotto l'altro nella stessa colonna. "C'è posto" vuol dire: il Lampo sta
tutto dentro lo spazio delle app e non finisce sopra un altro Lampo. Aprendo un
Lampo con altri già aperti: **posto sia accanto sia sotto → due riquadri tratteggiati**
(1 accanto, 2 sotto; tasto o clic, Invio = 1, Esc annulla); **posto in un modo solo → va
lì**, senza domande; **nessun posto → non si apre** e al centro compare «Non c'è spazio per
mettere …». Chiudendone uno, **gli altri si spostano** a riempire il posto. I Lampi già al
loro posto non si spostano.
*App Swift 0.9.3:* Esc chiude **solo** il Lampo davanti; se ce ne sono altri aperti si passa all'ultimo (un altro Esc chiude il prossimo). Esc chiude anche il Memo. Un Lampo aperto ma senza finestre (Calendario) se ne fa una, come col Dock.
*App Swift 0.9.8:* un Lampo che non scende sotto una sua misura minima (il Calendario) viene spostato indietro: resta tutto dentro lo schermo.

**Q-1c Lampi personalizzati** (v9.68, 31/10/2026, Daniele: «così ognuno personalizza il suo
ambiente»): ⚡︎ → **Personalizza i Lampi ▸**. Per ogni Lampo: «Cambia la scorciatoia…» e
«Togli dai Lampi». **Aggiungi un Lampo ▸**: le app aperte (non Finder, browser, Hammerspoon,
né quelle già Lampi) oppure «Altra app…» (scelta nella cartella Applicazioni). La
scorciatoia è ⌃⌥ + una lettera: Tabby propone la prima libera del nome; una lettera già
usata (schede, Lampi, App, ⌃⌥W, F, S…) viene rifiutata con un avviso. Un Lampo aggiunto si
apre 560×480 (se l'app vuole di più, la sua misura minima). «Torna ai Lampi di serie»
cancella la scelta. Si salva in `tabbar.quick` (elenco `{memo | bid, name, key, w, h}`);
dopo ogni cambio Tabby si ricarica (0,8 s) per attivare le scorciatoie. **[Swift]** senza
ricaricare.

**Q-2 Memo**: blocco note 340×280 in alto a destra (in fila con gli altri Lampi), scuro,
testo 14. Il testo è un **file vero**: `~/Documents/Tabby Memo.txt` (si apre con
TextEdit, si trova con Spotlight). **Editor a righe** (v9.50, `tabby/memo.html`), con
convenzioni di testo semplice a inizio riga:
- `- testo` → **elenco puntato** (•); `[ ] testo` → **cosa da fare** con casella (clic, o
  ⌘Invio, la spunta: `[x] testo`, riga barrata); `> testo` → **sezione apribile** (▸/▾):
  contiene le righe **rientrate** sotto di lei (due spazi = un rientro); chiusa, le
  nasconde. La freccia ▸/▾ è bianca e grande quanto il testo (v9.51). Le sezioni chiuse
  si ricordano (`memoFold`).
- Scrivendo `- `, `* `, `[] `, `[ ] `, `[x] ` o `> ` a inizio riga, la riga si trasforma (il
  cursore resta dopo quello che hai scritto). Invio continua l'elenco o la lista di cose
  da fare; Invio su una voce vuota la fa tornare riga normale; Invio in fondo a una
  sezione crea una riga dentro di lei. Cancella a inizio riga: toglie pallino/casella,
  poi il rientro, poi unisce alla riga sopra. Tab / Maiusc+Tab: rientro (al massimo uno
  più della riga sopra). Frecce su/giù passano alla riga accanto. Incolla: solo testo.
- Si salva da solo 0,3 s dopo che smetti di scrivere e alla chiusura. Esc o ⌃⌥M lo
  chiudono e riportano all'app di prima.
- **Velocità** (v9.50): la pagina si prepara (nascosta) 2 s dopo l'avvio di Tabby e si
  carica una volta sola; aprendo il Memo il testo si ricarica dal file **solo se è
  cambiato** (es. modificato con TextEdit), così ritrovi il cursore dov'era. Misurato:
  prima apertura ~0,3 s (il tempo che macOS dà la tastiera a Tabby), poi ~0,05 s. La
  tastiera deve arrivare davvero al Memo: Tabby ricontrolla dopo 0,08, 0,25, 0,6 s.
- ⚡︎ → "Mostra il file del Memo nel Finder". Il Memo sta davanti alle finestre ma sotto i
  menu di Tabby.

**Q-3 Spotlight**: scheda **+** sulla barra (⌘Spazio).

## 15. Azioni delle app (⚡︎ → App)

**X-1 Speciali** (configurate): Claude · chat rapida (⌃⌥L, preme l'icona di Claude
nella barra dei menu); Notion · cerca (⌃⌥N) e Notion AI (⌃⌥I): premono la voce
"Toggle Command Search" / "Toggle Notion AI" del menu dell'icona di Notion
(cercata per 1,5 s); **riserva** se l'icona è spenta: Notion davanti e la sua
scorciatoia (⌘⇧K / ⌘⇧J), mandata **quando hai lasciato ⌃⌥** (se no macOS la legge
come ⌃⌥⌘⇧K). Se l'app non è aperta: si apre dietro e si riprova una volta.

**X-2 Scoperte**: Tabby trova da sola le app con un'icona nella barra dei menu
(all'avvio dopo 5 s, 3 s dopo ogni app aperta, ogni 10 minuti; anche app installate
dopo), escluse quelle di sistema di Apple (Wi-Fi, Bluetooth…), e le ricorda
(`menuApps`). Ognuna diventa "Apri <app>" in ⚡︎ → App (una riga sola anche con 100
app). **Gestisci**: mostra/nascondi in ⚡︎, scorciatoia ⌃⌥ + una lettera libera
(Tabby si ricarica per attivarla), togli la scorciatoia. Le app **"solo icona"**
(niente finestre né Dock, es. Proton VPN) sono segnalate "tieni l'icona accesa": si
aprono solo dalla loro icona.
*App Swift 0.11 (Daniele):* tolte: niente più ricerca automatica delle app con un'icona nella barra dei menu né «⚡︎ → Tutte le App». Restano le azioni configurate (X-1).

**X-3** Premere l'icona di un'app spenta in macOS (parcheggiata fuori schermo) non
apre niente: allora si apre l'app come dal Dock; per un'app solo icona, avviso.
*App Swift 0.9.6:* fatto (avviso «X è solo un'icona nella barra dei menu»).

**X-4 Durante un'azione** (3 s): il pannello che si apre non è una scheda, non si
ingrandisce, e l'app in cui sei non viene nascosta. Sotto il pannello c'è il velo
(16) finché torni alla finestra di prima o passi a una finestra "vera".
*App Swift 0.9.6:* il velo sotto il pannello dell'app finché c'è (al massimo 3 s per comparire); il resto lo fa già X-5.

**X-5 Pannelli** (v9.69, 5/11/2026: la finestrella di Notion «vuoi registrare il meeting?»):
se l'app che diventa attiva ha in primo piano una finestra **piccola** (meno di metà
larghezza e meno del 60% dell'altezza dello spazio delle app) che **non è una finestra
normale** (ruolo AXFloatingWindow, AXSystemFloatingWindow, AXDialog, AXSystemDialog o
sconosciuto; mai vista normale; non ridotta, non a schermo intero; non di un browser),
Tabby non nasconde le altre app, non la ingrandisce e non la conta come scheda. Prima
nascondeva tutto, anche il browser col meeting. Nel diario: «pannello di X … non
nascondo le altre app». Il diario scrive anche ogni cambio di app con titolo, ruolo e
misura della finestra in primo piano.
*App Swift 0.9.4:* fatto; diario «pannello di X (ruolo, misura) · non nascondo le altre app».

## 16. Velo

**V-1** Con Spotlight aperto (e con i pannelli delle azioni rapide) lo schermo,
**Tabby compresa**, si copre con un velo `#0B0D12` all'**85%**: il testo dietro non
si legge. Non prende i clic (un clic fuori chiude Spotlight come sempre). Compare
senza dissolvenza (*perché:* due dissolvenze ravvicinate lasciavano il velo
trasparente). Tabby controlla 20 volte al secondo se toglierlo (macOS avvisa con ~1 s
di ritardo): Spotlight è aperto finché la finestra attiva è sua. Dopo 10 minuti si
toglie comunque. ⚙︎ → Comportamento → "Oscura lo sfondo con Spotlight e le azioni
rapide" (acceso di serie).
*App Swift 0.9.5:* fatto, anche per **Raycast**; si accende con ⌘Spazio visto dall'intercettatore dei tasti; impostazione «Con Spotlight aperto lo sfondo si oscura / resta com'è».
*App Swift 0.10.2 (visto sul Mac):* Spotlight non diventa mai l'app in primo piano. Aperto ha una finestra ben visibile al livello 23; chiudendolo la finestra diventa **trasparente subito** e sparisce quasi un secondo dopo → conta solo una finestra con trasparenza > 0,5 (il velo va via appena chiudi). Raycast allo stesso modo. La chat rapida di Claude è una finestra trasparente grande come lo schermo al livello 1000: il velo sta appena sotto; si accorge quando Claude cambia la finestra con l'attenzione.
*App Swift 0.10.4 (Daniele):* il velo sta **sotto la barra di Tabby** (come il velo della vista divisa) e sopra le finestre delle app; anche con Raycast (una sua finestra ben visibile, non le Impostazioni) e Alfred.
*App Swift 0.10.6 (Daniele: «tutte le app, qualunque siano»):* il velo compare sotto **il pannello di qualunque app**: una sua finestra sopra quelle normali (livello > 0, non un menu), ben visibile, che **ha la tastiera** (è la finestra con l'attenzione dell'app davanti). Si guarda quando un'app diventa attiva e quando un'app cambia finestra con l'attenzione, per poco più di un secondo; poi solo finché il pannello c'è. Un'altra app non spegne il velo di Spotlight. Impostazione: «Con Spotlight e i pannelli delle app lo sfondo si oscura / resta com'è».
*App Swift 0.10.8 (visto sul Mac):* Raycast non diventa mai l'app davanti, la sua finestra resta «sullo schermo» anche da chiuso e per macOS resta «nascosto» anche aperto. L'unica cosa che cambia: aperto ha una finestra per l'Accessibilità, chiuso no. Tabby ascolta Raycast con l'Accessibilità (finestra creata, attenzione cambiata, mostrato/nascosto) e controlla le sue finestre solo finché il velo c'è.
*App Swift 0.10.9 (revisione):* Raycast resta **senza velo** (deciso con Daniele dopo tre tentativi: nessun segnale affidabile); tolti il codice per Raycast e quello per Alfred, mai provato. Il velo guarda le finestre per 0,6 s dopo un cambio d'app (1,5 s per Spotlight e le azioni di Tabby).

## 16b. Concentrazione (v9.55)

**H-1 Scelta.** ⚡︎ → «Concentrazione…» (in corso: «Concentrazione · mancano X» con
+5 / +15 / Termina). Lo schermo si oscura (`#06070A` al 72%, prende i clic), **la barra
no**: resta sopra. In centro una finestra (pagina `tabby/concentrazione.html`, non prende
la tastiera): minuti (− / + di 5, scelte rapide 25 · 50 · 90; da 5 a 240), quante
schede hai scelto, le cartelle con schede aperte (un clic le sceglie tutte), lo stato di
Non disturbare. Stile standard di macOS (foglio come Impostazioni: righe raggruppate,
controllo a segmenti, frecce su/giù, caselle, bottone blu; chiaro o scuro come il
sistema) — *perché:* niente stile proprio su un solo comando; lo stile di Tabby si
decide nell'app Swift per tutto insieme. Le schede si scelgono **cliccandole nella barra**: diventano gialle
(`#F4C443`, testo scuro); un clic su una scheda (anche sulla ✕) la sceglie o la toglie
e non ci si sposta. Già gialle: la scheda in cui sei e quelle dell'ultima volta.
Ricorda anche i minuti. Invio = Inizia, Esc = Annulla. Senza schede non parte (la
casella trema).

**H-2 Inizio.** Le app non scelte si **nascondono (non si chiudono**: niente «Vuoi
salvare?», le sessioni remote non cadono); le finestre non scelte di un'app scelta (es.
un'altra finestra del browser) si riducono. Nella barra **solo le schede scelte** (le
scorciatoie ⌃⌥ + numero lavorano su quelle) più le finestre nuove delle app scelte.
Se eri su una scheda non scelta si va sulla prima. Non disturbare si accende col
comando rapido «Concentrazione on» (app Comandi), se c'è. **[Swift]** usare l'API dei
Focus se disponibile.

**H-3 Durante.** Al posto della batteria il **tempo che manca** («24 min»; nell'ultimo
minuto «0:45») con una barretta blu (accento di Tabby) che si riempie; largo 64 punti in orizzontale,
alto 38 di lato. Clic: +5 minuti, +15 minuti, Termina adesso. Col cerchio sulla
scrivania, un **anello giallo** intorno alla sfera. Un'app non scelta che viene davanti
(Dock, Spotlight, ⌘Tab) torna nascosta, si torna all'ultima scheda permessa e Tabby
chiede «Aprire X?» (Invio/Esc = Resto concentrato; «Aprila lo stesso» la aggiunge alle
schede). Senza chiedere: Lampi, Memo, Finder, azioni rapide. Il clic sul gatto salta
le schede non permesse.
*App Swift 0.9.3 (Daniele):* al posto della batteria un **cerchio** che si riempie col tempo passato, come i limiti di Claude; clic → quanto manca, +5, +15, −5 minuti, Termina.

**H-4 Fine.** Suono «Glass»; finestra «Fatto! N minuti» con le notifiche arrivate nel
frattempo dalle app e dai siti rimasti fuori (differenza dei numerini rispetto
all'inizio, es. «Slack 4 · Gmail 2»). Scelte: **Riapri tutto** (Invio: tornano tutte le
schede, Non disturbare si spegne con «Concentrazione off»), **Altri 10 minuti**,
**Resta così** (senza tempo: ∞, si termina dal clic sul tempo; Esc). «Termina adesso»
porta alla stessa finestra, senza suono.

**H-5** Lo stato si salva in `tabbar.focus` (inizio, fine, schede, chiavi, app,
escluse, numerini dell'inizio): dopo un riavvio la concentrazione continua, o finisce
se il tempo è passato. Ultima scelta in `tabbar.focusLast`.

## 16c. Cerca nelle finestre (v9.57)

**E-1** ⌃⌥F (o ⚡︎ → «Cerca nelle finestre…») apre una barra in alto al centro dello spazio
delle app (640 di larghezza, stile Spotlight standard di macOS, chiaro/scuro). Lo sfondo
si oscura come nella Concentrazione (H-1), la barra di Tabby resta sopra e accesa. Non prende
la tastiera: i tasti li intercetta Tabby (lettere, Cancella, ⌘Cancella = svuota, ⌘V =
incolla, ↑↓, Invio, Esc; ⌃⌥F di nuovo = chiude) e non arrivano all'app sotto. Clic fuori
= chiude. *Perché:* niente problemi di "attenzione" con le altre app (Memo, Windows App).

**E-2 Il testo.** Tabby legge il testo delle finestre (ruoli AXStaticText, AXTextArea,
AXTextField, AXCell) con l'Accessibilità, una finestra alla volta, a pezzi di al massimo
110 ms ogni 0,12 s (Tabby resta reattiva); al massimo 5000 elementi e 60 000 caratteri
per finestra. Quando: 1,5 s dopo che lasci una finestra, e aprendo la ricerca (prima le
più usate) quelle lette da più di 30 s; i risultati si aggiornano man mano («Leggo N
finestre…»). Per le app Electron (Slack, Notion) che non danno testo, Tabby chiede una
volta `AXManualAccessibility`. Il testo resta **solo in memoria**. Limiti: del browser
solo la pagina in vista di ogni finestra; Slack/Notion il testo sullo schermo; Windows
App niente (solo il titolo). **[Swift]** stessa lettura, in un thread a parte.
*App Swift 0.9.3:* Spotify e Musica non fanno leggere la finestra: si cerca nel brano in ascolto (titolo, artista, album), chiesto a loro.

**E-3 Risultati** (max 8): le finestre in cui tutte le parole sono nel titolo (anche nome
della scheda e dell'app) o nel testo; minuscole e senza accenti («perche» trova
«perché»). Prima chi le ha nel titolo, poi per quante volte compaiono, poi le più usate.
Ogni riga: icona, titolo della finestra (senza « - nome app»), app, e un pezzetto di
testo intorno alla parola, evidenziata. Anche il Memo (il suo file). A barra vuota: le
finestre usate di recente.

**E-4 Scelta** (Invio o clic): la ricerca si chiude, la finestra viene davanti (come la
sua scheda; vista divisa intera se ne fa parte). Se le parole erano nel testo, dopo
0,45 s — e solo se è davvero lei davanti — Tabby fa ⌘F e scrive le parole. Memo: si apre.
In concentrazione vale la sua regola (un'app non scelta chiede).

**E-5 Sul web** (app Swift 0.10, deciso con Daniele il 10/11/2026: potenziare Spotlight, non
sostituirlo). In fondo ai risultati della barra di ricerca, il gruppo «Sul web»:
- **Apri X**: se il testo è un indirizzo («raycast.com») o il nome di un servizio conosciuto
  («proton» → Proton Mail; elenco `serviziDaAprire`). Se quel sito è già aperto non si propone
  (c'è la sua scheda) e, scelto, porta lì. Altrimenti apre **una finestra nuova con una scheda
  sola**, che diventa una scheda di Tabby; se eri in una cartella, il sito entra nella cartella.
- **Cerca «…» sul web**: sempre, per ultima: DuckDuckGo in una finestra nuova.
- ⌘↵: come scheda nella finestra del browser davanti.
- Ordine (0.10.4): «Apri X» è **il migliore** se fra le tue cose niente ha quel nome nel titolo (una finestra che contiene solo la parola non basta: prima Invio portava lì). Il diario scrive ogni passo («ricerca web: …»), anche quando il browser rifiuta.
- Browser (0.10.5): a destra nella barra il **cerchio col logo del browser**; un clic e lo scegli
  fra quelli installati (`tabbar.webBrowser`); di serie quello predefinito di macOS.
  Chrome/Brave/Edge: `--new-window` (più veloce di AppleScript). Safari: AppleScript. DuckDuckGo
  (senza AppleScript) e gli altri: il sito si apre come scheda nella finestra davanti, poi Tabby
  preme «Finestra → Sposta scheda in una nuova finestra» — **solo** quando la scheda in vista è
  proprio quel sito e le schede sono una in più di prima. (0.10.3: ⌘N e indirizzo incollato, che
  lasciava una scheda vuota nella finestra nuova.)
