# Tabby — sistema di design

Il documento di riferimento per l'aspetto e il comportamento di Tabby (app Swift). Ogni
scelta qui è stata decisa con Daniele; l'app si costruisce seguendolo, senza decisioni prese
al volo. Diventa la sezione **Design** di Tabby. Prototipi in `docs/design-*.html`.

**Cosa comprende** (deciso l'8/11/2026): carattere e aspetto (colori, font, icone, angoli,
spazi, ombre, veli) · interazioni (clic, tasto destro, trascinamento, gesti, scorciatoie,
animazioni, risposte e suoni) · funzionalità e struttura (dove sta ogni cosa, i percorsi,
le funzioni nuove) · parole (nomi, frasi, tono). Fuori: il "motore" (finestre, browser,
notch), che è in `SPECIFICA.md`.

**Ordine di lavoro:** 1 direzione ✅ · 2 mattoni · 3 componenti · 4 struttura e percorsi ·
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

## 2. Mattoni

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
  per stare con SF Pro e che si adattano da soli a grandezza e peso. Proposta di partenza
  (da confermare con i componenti): dividi `rectangle.split.2x1`, Lampi `bolt.fill`,
  impostazioni `gearshape`, nuova app `plus`, chiudi `xmark`, Concentrazione `moon.fill`,
  ricerca `magnifyingglass`, cartella `folder`, batteria `battery.75`, scambia
  `arrow.left.arrow.right`, Scrivania `menubar.dock.rectangle`.
- **Il gatto è l'unico disegno di Tabby**: il marchio (barra, sfera, icona dell'app).
- **Icone delle app e loghi dei siti**: quelli veri, come oggi.

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
