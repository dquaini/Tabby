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
