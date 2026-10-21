# Tabby v1 — roadmap

Obiettivo: chiudere una **v1 solida** con questi cinque filoni, decisi insieme a Daniele
il 20/10/2026. Ordine consigliato: **A → B → C → D → E** (ognuno prepara il successivo).

Nomi decisi:
- **Cartella** = insieme di schede con toggle aperta/chiusa (Lavoro, Studio…).
- **Vista divisa** = schermo diviso in zone (oggi nel codice "gruppo").

---

## A. Più schede per qualsiasi app — ✅ fatta (v9.5)

Come è stata fatta: ogni finestra standard di ogni app è una scheda (anche con
una sola finestra la scheda è legata a quella finestra); con 2+ finestre il nome è
il titolo (senza il nome dell'app in fondo; doppioni → "(2)"); vale anche per le
finestre normali dei browser (via le lettere A/B/C). Interruttore per app in
⚙︎ → Finestre separate (spento = tutte le finestre in una scheda, come prima).
Chiavi: la finestra più vecchia ha il bundle ID dell'app, le altre `win:<id>`; le
viste divise seguono la finestra (`g.winOf`). Restano da fare per B: chiavi che
sopravvivano al riavvio dell'app (oggi `win:<id>` si perde).

Specifica originale:

Oggi solo i browser hanno una scheda per finestra. Estendere a tutte le app
(Finder, Word, Excel, Anteprima…).

- Nome della scheda = **titolo della finestra** (nome del documento, della cartella del
  Finder…), non lettere A/B/C. *(confermato)*
- Evitare l'"esplosione" di schede: solo finestre standard; regola automatica (un'app
  diventa "a finestre" quando ha ≥2 finestre standard) + **interruttore per app** in
  impostazioni (es. "Finestre separate per: Finder ✓, Word ✓").
- Chiavi stabili per finestra (oggi `win:<id>`): valutare come farle sopravvivere al
  riavvio (titolo del documento?), servirà alle Cartelle.
- Va bene con viste divise (una finestra di Word a sinistra, Chrome a destra).

## B. Cartelle (il cuore della v1)

### Rivista il 21/10/2026 con Daniele — questa versione prevale su quella sotto
**Stato: base fatta in v9.8** (test `test/test_cartelle.py`). Correzioni di Daniele applicate:
attivare non sposta (caso A: sei su una sua app → vista cartella, resti lì; caso B: sei
altrove → scheda unica, resti lì); almeno 3 icone; un'app aperta fuori cartella si vede solo
nella vista generale; creazione e attivazione tutte dal menu ⚡︎; ⌃⌥⇧+numero; Chiudi cartella.
Da fare: "Apri all'avvio", trascinare una scheda sopra la scheda-cartella per aggiungerla.

Una cartella è uno **spazio di lavoro salvato**: una scheda è in una cartella solo se
ce l'hai messa tu. Prototipo cliccabile: `docs/prototipo-cartelle.html`.
1. ⚙︎ → Cartelle → Nuova cartella → nome; sotto, un riquadro con già l'icona della
   scheda attuale; ci si trascinano (o cliccano) altre schede; Fatto = salvata.
2. Nel menu ⚡︎: iconcine + nome + scorciatoia della cartella.
3. Attivarla (clic o scorciatoia): apre le app che mancano; quelle già aperte
   entrano; le altre finestre si nascondono.
4. Vista cartella: nome della cartella a sinistra (in alto se laterale), solo le sue
   schede, tasto per tornare alla vista di prima.
5. Fuori dalla vista, la cartella è **una scheda sola** con le iconcine (troppe →
   solo la prima).
6. ⚙︎ → Comportamento → **Vista cartelle** (confermato): spenta = le app della
   cartella si aprono come schede normali.
7. Le scorciatoie valgono solo su ciò che si vede in Tabby.
Domande aperte (proposte nel prototipo): app aperta fuori cartella durante la vista;
più cartelle insieme; scorciatoia ⌃⌥⇧+numero; cosa ricorda la cartella; "Chiudi cartella".

### Prima versione (20/10)

Idea di Daniele: come i gruppi di schede di Arc/Safari. "Lavoro" è una riga con toggle
▸/▾: aperta mostra le sue schede (Notion, DuckDuckGo, Slack…), chiusa le raccoglie.
**Le app restano sempre aperte**: la cartella cambia solo come le vedi.

Decisioni:
- **Una scheda sta in una sola cartella.** *(confermato)*
- Schede fuori da ogni cartella = schede libere, come oggi.
- Una cartella può contenere anche **viste divise**.
- **Interruttore generale "Cartelle: attive / disattivate"** in impostazioni: spento →
  tutte le schede si vedono sciolte. *(interpretazione di Claude da confermare con
  Daniele: "mettiamo un interruttore cartella on/off così se uno la vuole divisa le vede
  tutte divise")*
- **"Chiudi cartella"** = chiude tutte le app della cartella (es. fine lavoro, ma resta
  aperto il PDF che stai leggendo). *(confermato)*
- **"Apri cartella"**: lancia le app della cartella che non sono aperte e apre i suoi
  siti come webapp. Con Chrome/Safari: finestre nuove via AppleScript. **Con DuckDuckGo
  non è possibile in modo affidabile** (niente AppleScript): documentare "funzione
  completa con Chrome/Safari"; per DuckDuckGo valutare apertura come schede/`open -a`.
- **"Apri all'avvio"** per ogni cartella: la mattina la cartella si prepara da sola.
- La cartella ricorda la sua "ricetta": app (bundle ID), siti (URL), viste divise.

Interfaccia:
- **Configurazione dal tasto ⚡︎**: voce "Cartelle" → nuova cartella, rinomina, apri,
  chiudi; si **trascinano le schede dentro** (stesso meccanismo delle zone). Anche
  trascinando una scheda sopra una cartella direttamente sulla barra.
- **Tabby laterale** (come la usa Daniele): riga cartella con ▸/▾, nome, numero schede;
  aperta mostra le schede rientrate sotto.
- **Tabby in alto/in basso**: la cartella è una scheda con ▸; cliccata **si apre in
  linea** (le sue schede compaiono accanto, rientrate o con sfondo diverso); se manca
  spazio → menu a tendina. *(confermato: "apertura in linea è top")*
- Notifiche: la riga cartella mostra la somma (come le viste divise).
- Scorciatoie: ⌃⌥numero conta le schede visibili; valutare ⌃⌥ + lettera per cartelle.

## Giro di rifiniture (feedback di Daniele del 21/10/2026, prima di C)
1. **Google Meet** fa "impazzire" Tabby (difetto, servono dettagli; sospetto: finestrelle
   di Meet come condivisione schermo / video in miniatura trattate come finestre normali).
2. **Scheda "+"** in fondo alle schede: apre Spotlight; Spotlight esce dal menu ⚡︎.
   (Cambia la decisione D "nessun tasto +".) Da decidere: nella vista cartella l'app
   aperta col + entra nella cartella (proposta).
3. **Scambia** nella vista divisa: ruota le app tra le zone (2 = scambio). Tasto ⇄ sulla
   scheda della vista divisa + ⌃⌥S (proposta; Daniele aveva detto "a caso").
4. **Icona del gatto** al posto dello schermo (tasto scrivania): disegno di Daniele, senza
   sfondo nero, colori di Tabby.
5. Lentezze viste in console (DuckDuckGo con pagine complesse fino a 336 ms, cambio di
   scheda fino a 595 ms; diagnosi DuckDuckGo troppo chiacchierona) + GitHub privato per
   tenere uguali i due Mac.

## Cartelle, seconda parte (dopo C)
- **Finestra di browser con più siti** dentro una cartella: ricordare l'elenco dei siti e
  riaprirli come schede di una finestra (Chrome/Safari). Da decidere: siti o pagine esatte.
- "Apri all'avvio" e altre automazioni.

## Dopo la v1 (aggiunte)
- **Colori di Tabby a scelta** (temi): i colori sono già tutti nella tabella `COL`.

## C. Avvio e schermata di partenza

Problema: con nessuna scheda aperta Tabby è "vuota" e non accoglie.

- **Schermata di partenza** (come la "nuova scheda" del browser) quando non c'è nulla
  aperto o si è sulla scrivania: pannello al centro con saluto, **cartelle** (cliccabili:
  aprono la cartella), app preferite.
- **Configurazione guidata al primo avvio**: permessi (Accessibilità, Automazione per i
  browser), barra dei menu e Dock nascosti (applicati da Tabby con consenso), avvio di
  Hammerspoon al login, posizione di Tabby.

## D. Dock e scrivania

Decisione: **Tabby sostituisce il Dock** → Dock sempre nascosto. *(confermato)*

- Tabby può nasconderlo da sola (con consenso): `defaults write com.apple.dock autohide
  -bool true` (+ eventuale ritardo lungo) e `killall Dock`; ripristino dalle impostazioni.
- App nuove: **Spotlight**, più le cartelle con "Apri all'avvio" e la schermata di
  partenza. Nessun tasto "+" necessario per ora. *(confermato)*
- Scrivania (tasto / ⌃⌥0): mostrare la schermata di partenza.
- Notifiche: oggi lette dal Dock; con il Dock nascosto continuano a funzionare
  (verificare sul Mac vero).

## E. Documentazione e buone pratiche

- **Foglio delle scorciatoie** dentro Tabby (⌃⌥? e voce "Guida" in impostazioni).
- **Guida utente** (in italiano): installazione, scorciatoie, cartelle, viste divise,
  impostazioni consigliate (Dock e barra dei menu nascosti, Tabby a destra su portatile).
- **Tabella browser**: cosa funziona con Chrome/Safari/Brave/Edge vs DuckDuckGo.
- Farla per ultima, quando il comportamento della v1 è definitivo.

---

## Dopo la v1
Vedi "Futuro oltre la v1" in `PRODOTTO.md` (app Swift, Claude/agente, ricerca veloce,
concentrazione, più monitor, iCloud).
