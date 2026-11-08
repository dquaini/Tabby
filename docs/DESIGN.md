# Tabby — sistema di design

Il documento di riferimento per l'aspetto e il comportamento di Tabby (app Swift). Ogni
scelta qui è stata decisa con Daniele; l'app si costruisce seguendolo, senza decisioni prese
al volo. Diventa la sezione **Design** di Tabby. Prototipi in `docs/design-*.html`.

**Cosa comprende** (deciso l'8/11/2026): carattere e aspetto (colori, font, icone, angoli,
spazi, ombre, veli) · interazioni (clic, tasto destro, trascinamento, gesti, scorciatoie,
animazioni, risposte e suoni) · funzionalità e struttura (dove sta ogni cosa, i percorsi,
le funzioni nuove) · parole (nomi, frasi, tono). Fuori: il "motore" (finestre, browser,
notch), che è in `SPECIFICA.md`.

**Ordine di lavoro:** 1 direzione ✅ · 2 mattoni ✅ · 3 componenti · 4 struttura e percorsi ·
5 funzioni nuove · 6 parole.

**Principio (8/11/2026, Daniele):** Tabby **personalizzabile ma sempre efficace**: di base
semplice da usare come macOS; ovunque si sceglie, **poche opzioni curate** (3–5), come per
i temi. (Uno stile "risograph" per i momenti di carattere è stato provato e **scartato**.)

---

## 1. Direzione: aspetto e temi ✅ (8/11/2026)

Prototipo: `docs/design-temi.html` (le tre direzioni di partenza: `docs/design-direzioni.html`).

### 1.1 Due aspetti, a scelta (sezione Design)
- **Nativo** — Tabby come parte di macOS: materiali traslucidi (vetro sfocato), chiaro o
  scuro insieme al Mac. **Colore principale = quello scelto nelle Impostazioni del Mac**
  (Impostazioni di Sistema → Aspetto); nessuna scelta in più dentro Tabby.
- **Notte** — Tabby sempre scura (barra e tutte le sue finestre, anche col Mac chiaro), con
  uno dei **6 temi**.
- **Di serie: Notte · Tabby.**

### 1.2 I temi di Notte (pochi e curati, in stile Slack: un clic su un campione)
Nessun selettore di colori libero: ogni tema è preparato con cura perché stia bene e si
legga bene. Due gruppi:

**Base** — a tinta unita, sobri:

| Tema | Carattere | Barra | Finestre | Accento | Testo sull'accento |
|---|---|---|---|---|---|
| **Grafite** | la Tabby di oggi | `#000000` | `#17181C` / `#202228` | `#4C8DFF` | `#FFFFFF` |
| **Mono** | bianco e nero | `#000000` | `#161616` / `#1F1F1F` | `#EDEDED` | `#0E0E0E` |
| **Fumo** | grigio caldo e lavanda | `#141313` | `#1C1B1B` / `#252423` | `#A894F5` | `#18122E` |

**Tabby** — con sfumature e gradazioni (non "da tutorial": la misura giusta è una via di
mezzo, né piatta né troppo luminosa — deciso dopo due prove):

| Tema | Carattere | Accento (colore unico per linee e icone) |
|---|---|---|
| **Tabby** (di serie) | miele e ambra | `#E9B44A` |
| **Tramonto** | pesca, corallo e magenta | `#EE7470` |
| **Aurora** | menta, ghiaccio e indaco | `#4CCBB4` |

Regole dei temi Tabby:
- **Sfumatura a più punti** (3–4 colori che si fondono in punti diversi, come una macchia
  di luce; in Swift `MeshGradient`) per gli elementi "accesi": scheda attiva, pulsanti
  principali, voce scelta nei menu, selezione nei controlli a segmenti, sfera.
  - Tabby: crema `#FBE2A0` (in alto a sinistra) · miele `#EDBD52` · ambra `#DDA23A` (base) · bruciato `#B9661E` (in basso a destra).
  - Tramonto: pesca `#FAD0AC` · corallo `#EC7268` · rosa `#D9586F` (base) · magenta `#973488`.
  - Aurora: ghiaccio `#C4F6E2` · menta `#3BC2BA` · azzurro `#42A8C8` (base) · indaco `#5C4CD6`.
- **Sfondi vivi**: barra e finestre scure con un **bagliore tenue** del tema (nella barra
  parte dal gatto, nelle finestre da un angolo), intensità ~6–11%.
- **Grana** leggerissima (rumore, ~6%; ~8% sulla scheda attiva), come vetro smerigliato.
- **Profondità**: filo di luce sul bordo alto (bianco ~28%) e bagliore morbido sotto
  (colore del tema ~20%, 10 punti); il gatto della barra con un alone appena accennato.
- **Riflesso lento** sulla scheda attiva: una passata di luce tenue ogni ~14 s; niente se
  macOS ha «Riduci movimento».
- Testo sull'accento: scuro (`#1C1505`, `#2B0716`, `#03201E`).

I valori completi (tutte le sfumature e le trasparenze) sono nel prototipo; quando si
costruisce l'app diventano il file dei temi che Tabby legge.

---

## 2. Mattoni ✅

### 2.1 Carattere (font) ✅ (8/11/2026)
**Solo il carattere di macOS (SF Pro), ovunque, senza scelte.** *Perché* (Daniele): così tutto
è coerente — barra, finestre di Tabby, menu (che in macOS sono sempre in SF Pro) e il resto
del Mac. Una scelta tra 5 caratteri (SF Pro, SF Pro Rounded, un graziato stile Californian, uno
"goofy", uno da terminale) è stata provata (`docs/design-font.html`) e **scartata**.

- Grandezze e pesi: quelli di macOS (testo 13, piccolo 11–12, titoli 15–17; regolare,
  medio per la scheda attiva, grassetto per i titoli). Il dettaglio va con i componenti.
- I numeri che cambiano (tempo della Concentrazione, «3 di 5») a cifre di uguale larghezza,
  così non "ballano".

### 2.2 Icone ✅ (8/11/2026)
- **Tasti e azioni di Tabby: i simboli di Apple (SF Symbols)**, gli stessi di macOS, disegnati
  per stare con SF Pro e che si adattano da soli a grandezza e peso. **Scelti da Daniele**
  (8/11/2026, su `docs/design-icone.html`):

  | Funzione | Simbolo |
  |---|---|
  | Dividi lo schermo (tasto della barra) | `rectangle.grid.2x2` |
  | Lampi (tasto della barra) | `sparkles` |
  | Impostazioni — tasto della barra | `slider.horizontal.3` |
  | Impostazioni — sezione della finestra di Tabby | `gearshape` |
  | Nuova app | `plus.app` |
  | Chiudi (sulla scheda) | `xmark.circle.fill` |
  | Batteria | `battery.75percent` (e le sue varianti di carica) |
  | Concentrazione | `target` |
  | Cerca nelle finestre | `text.magnifyingglass` |
  | Cartella | `square.stack.3d.up` |
  | Scambia (vista divisa) | `arrow.left.arrow.right` |
  | Scrivania | `macwindow` |
  | Torna all'ultima finestra | `arrow.uturn.backward` |
  | Rinomina | `square.and.pencil` |
  | Memo | `note.text` |
  | Scorciatoie | `command` |
  | Avviso | `exclamationmark.triangle` |
  | Altro (⋯) | `ellipsis` |
  | Sezione Design | `paintpalette` |
  | Sezione Documentazione | `book.closed` |
  | Sezione Automazione | `clock.arrow.2.circlepath` |
  | Sezione Kat | `tray.full` |

- **Il gatto è l'unico disegno di Tabby**: il marchio (barra, sfera, icona dell'app).
- **Icone delle app e loghi dei siti**: quelli veri, come oggi.
- Le icone vere, con le alternative per ogni funzione: `docs/design-icone.html`.
- **Barra: niente riga verticale** tra la batteria e i tasti ⊞ ⚡︎ ⚙︎ (8/11/2026, Daniele).

### 2.3 Forme, spazio, ombre, movimento ✅ (8/11/2026)
Prototipo: `docs/design-forme.html`. Non sono scelte per l'utente: sono le misure fisse.
Scelta di Daniele: **Morbidi · Compatto · Profonde · Elastiche**.

| Cosa | Valore |
|---|---|
| **Angoli** (morbidi, come macOS di oggi) | barra 14 (solo dal lato delle app) · scheda 9 · menu 11 (voce 6) · finestra/foglio/avviso 18 · riquadro interno 11 · pulsante 8 · icona piccola 5 |
| **Spazio** (compatto) | barra alta 38 (in alto) · scheda alta 28, margine interno 8 · tra le schede 1 · voci di menu 3 sopra/sotto · righe dei riquadri 7 · margine interno dei fogli 16 |
| **Ombre** (profonde) | menu, fogli, avvisi: `0 22 54` nero al 55% + filo di luce interno in alto (bianco 6%) |
| **Animazioni** (elastiche) | durata 0,38 s, curva con un piccolo rimbalzo finale (`0.3, 1.45, 0.45, 1`; in Swift una molla con smorzamento ~0,72) |

Regole del movimento:
- **Entrano** con il rimbalzo: menu (dall'alto, da 97%), fogli (dal centro, da 96%), avvisi
  (scivolano da destra), la scheda attiva che **scivola** da una scheda all'altra.
- **Escono** senza rimbalzo, più veloci (~0,2 s), per non far aspettare.
- Il cambio di scheda non aspetta l'animazione: l'app arriva subito, il disegno la segue.
- Con «Riduci movimento» di macOS: solo dissolvenze brevi, niente rimbalzi né riflessi.

---

## 3. Componenti (in corso)

**Metodo** (8/11/2026): un componente alla volta, sempre in 4 passi — (1) cosa c'è oggi, in
tutti i punti di Tabby dove compare; (2) le regole (quando si usa, dove, quanto è grande, cosa
contiene, come si apre e si chiude, Invio/Esc); (3) prototipo coi mattoni decisi, su esempi
veri, in tutti i temi e in Nativo; (4) decide Daniele, si scrive qui.

**Insieme: ordine e pulizia della UX** (Daniele): per ogni componente si guarda anche *come si
avvia e come si modifica* ogni funzione, cercando il modo più diretto. Idee da proporre:
rinominare scrivendo sulla scheda (come nel Finder) invece di una finestra; creare una
cartella selezionando le schede nella barra (come per la Concentrazione) e dando il nome
alla fine; cambiare la scorciatoia di un Lampo premendo la combinazione invece di scriverla.

**La famiglia (proposta):** menu · domanda · foglio · avviso · velo · schermata piena; più la
barra, la sfera e la **finestra di Tabby** (le cinque sezioni: si apre al primo avvio e da
Impostazioni; non sta sotto la barra).

### 3.1 Menu ✅ (8/11/2026)
Prototipo: `docs/design-menu.html`. I **menu standard di macOS** (NSMenu), **ritoccati il
giusto per Tabby**: chi li apre deve pensare «è macOS, una versione particolare», non «un
design a parte». E **originali**: l'originalità viene da dettagli che solo Tabby può avere,
non da effetti (niente che faccia dire «fatto con un'AI»).

**Ritocchi:**
- in **Notte** menu **scuri** (anche col Mac chiaro), in **Nativo** come il Mac;
- **titoli di sezione** veri (piccoli, grigi) invece di voci spente;
- **un simbolo per ogni azione** (quelli scelti), di Tabby nel colore del tema (in Nativo nel
  colore principale), le app e i siti con la loro icona;
- **numerini** come in Mail;
- testi corti e coerenti, niente «…» superflui (solo dove si apre una finestra che chiede
  qualcosa).

**Le quattro firme di Tabby** (tutte, Daniele):
1. **Tasti veri** — le scorciatoie a destra, disegnate come piccoli tasti (⌃ ⌥ M).
2. **Stato vivo** — il menu mostra cosa succede adesso: puntino verde sui Lampi aperti, tempo
   rimasto accanto alla Concentrazione in corso («50 min»), le icone delle app dentro ogni
   cartella, i numerini delle notifiche.
3. **Intestazione** — in cima a ogni menu il gatto e il contesto: «Casa · sei su Slack»,
   «Notion · 3 finestre», «Lampi · 1 aperto», «Tabby · Notte · tema Tabby».
4. **Tieni premuto ⌥** — le voci diventano le versioni "potenti" (voci alternative di
   macOS): Chiudi la finestra → Chiudi l'app; Nuova app → Nuova finestra di [app];
   Concentrazione → Concentrazione rapida · 25 min; Metti in pausa Tabby → Esci da Tabby.

**Menu ⚡︎:** in cima **la riga dei Lampi** (icone grandi con il nome, come le etichette del
Finder; un clic apre/chiude) · Strumenti (Concentrazione, Cerca nelle finestre) · App (quelle
con scorciatoia; le altre in «Tutte le App ▸») · Personalizza i Lampi ▸.

**Menu del gatto («Casa»):** Torna a [ultima] · Nuova app · Scrivania · Cartelle.

**Tasto destro su una scheda:** Rinomina · Torna al nome di prima · Mostra come (siti della
finestra) · Chiudi la finestra.

**Menu ⚙︎ (nuovo):** Tabby… (⌃⌥,: il pannello al centro per le sezioni) · Scorciatoie (⌃⌥/) ·
Posizione (In alto / A destra / A sinistra / In basso, direttamente nel menu) · Chiudi tutte
le app… · **Metti in pausa Tabby** (al posto di «Chiudi Tabby (resta solo il cerchio)»).
Spariscono «Ricarica Tabby» e «Console» (servivano solo con Hammerspoon); tutte le altre
impostazioni passano nella sezione Impostazioni.

**Restano di macOS:** colore della voce sotto il mouse (= colore principale del Mac), angoli,
vetro, animazione, tastiera, sottomenu, ricerca nei menu.

**Dove si aprono** (8/11/2026): sempre **attaccati a ciò che li apre**, come in macOS, dal lato
verso le app — ⚡︎ e ⚙︎ sotto il loro tasto (Tabby in alto: in alto a destra; Tabby a destra:
alla sinistra del tasto; a sinistra: alla destra), il gatto accanto al gatto, il tasto destro
dove è il puntatore. **In centro** solo ciò che non nasce da un tasto: il pannello «Tabby…», la
ricerca ⌃⌥F, i fogli e le poche domande rimaste.

### Decisioni trasversali (8/11/2026)
- **Niente «Apri Tabby»**: da Tabby già avviata, al centro un **pannello come Spotlight**
  («Tabby…», proposta ⌃⌥,) per andare nelle cinque sezioni e cercare un'impostazione
  scrivendo. La **pagina iniziale** (le cinque sezioni) si vede solo al primo avvio. Da
  disegnare come componente.
- **Lingua: quella del Mac** per tutti i nomi e le frasi di Tabby (Lampi, menu, sezioni,
  avvisi). **Italiano e inglese**; con altre lingue, inglese. (In Swift: tutto scritto in
  più lingue fin dall'inizio.)

### 3.2 Domande e conferme ✅ (8/11/2026)
Prototipo: `docs/design-domande.html`. **Regola: niente domanda quando c'è un modo diretto**
(Daniele: tutti e quattro i casi senza domanda).
- **Rinominare una scheda** (anche una cartella): si scrive **direttamente sulla scheda**, come
  un file nel Finder (tasto destro → Rinomina, o doppio clic sul nome). Invio salva, Esc annulla,
  vuoto = torna al nome di prima; sotto, un fumetto con i tasti.
- **Chiudere tutte le app** (e ogni azione forte in un menu): **conferma dentro il menu** — al
  primo clic la voce diventa rossa, «Clic di nuovo per chiudere tutte»; secondo clic = fatto;
  uscendo dal menu si annulla.
- **Cambiare la scorciatoia** (Lampi, App): la voce **resta in ascolto** (tasti che pulsano col
  colore del tema) e **premi la combinazione** che vuoi; Esc annulla; se è già usata lo dice e
  aspetta un'altra.
- **Chiudere una cartella**: si chiude subito; un **avviso con «Riapri»** per qualche secondo
  la rimette com'era (le app si riaprono).

**La finestrella di domanda** (per i casi rari che restano, es. un nome nuovo da scrivere senza
una scheda su cui farlo): al centro dello spazio delle app, sopra il velo; larga 286, angoli 18,
margine 16; simbolo dell'azione in alto nel colore del tema (rosso se distruttiva), titolo breve,
una riga di spiegazione, al massimo due pulsanti. Invio = pulsante evidenziato, Esc = Annulla;
se distruttiva, pulsante rosso e Invio non la fa (serve il clic). Entra col rimbalzo (0,38 s),
esce veloce (0,2 s).
