# Tabby v1 — roadmap

Obiettivo: chiudere una **v1 solida** con questi cinque filoni, decisi insieme a Daniele
il 20/10/2026. Ordine consigliato: **A → B → C → D → E** (ognuno prepara il successivo).

Nomi decisi:
- **Cartella** = insieme di schede con toggle aperta/chiusa (Lavoro, Studio…).
- **Vista divisa** = schermo diviso in zone (oggi nel codice "gruppo").

---

## A. Più schede per qualsiasi app

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
