# Tabby v1 — roadmap

Aggiornata il 31/10/2026 con Daniele (versione attuale **v9.65**). Mission: lo spazio di
lavoro per persone e agenti AI (vedi `PRODOTTO.md`). Il comportamento di oggi, regola per
regola, è in `SPECIFICA.md`; la storia delle versioni in `STORIA.md`.

Nomi decisi: **Cartella** = spazio di lavoro salvato · **Vista divisa** = schermo diviso in
zone (nel codice "gruppo") · **Lampi** = le app piccole del menu ⚡︎ (nel codice "app veloci").

---

## ▶ Il piano, in ordine (deciso il 31/10/2026)

1. **Ordine nella UX** *(adesso, in Hammerspoon)*: decidere insieme come si comporta Tabby
   dove oggi è incoerente (vedi sotto), scriverlo nella specifica e, dove non cambia
   abitudini senza che Daniele lo voglia, sistemarlo già qui.
2. **Sistema di design** *(decisioni adesso, realizzazione in Swift)*: carattere di Tabby,
   colori, componenti (schede, menu, finestre, veli), poche schermate chiave. Con 2–3
   prototipi cliccabili in HTML tra cui scegliere, come per la sfera.
3. **Seconda settimana di prova** sui due Mac (2–8/11/2026; la prima è stata quella del
   26/10). Correzioni piccole qui; il resto si annota per Swift.
4. **App Swift**: prima il motore con lo stesso comportamento (dalla specifica), poi design,
   le sezioni di Tabby, avvio, configurazione guidata, Dock.

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
  Hammerspoon, nasce qui.)*
- **Kat** — una **cartella del Mac collegata a Tabby** dove stanno tutti i file di Tabby
  (il Memo e gli altri). Con Tabby ambiente multi-agente, è anche il posto dove finiscono
  tutti gli HTML e gli altri file generati dagli agenti con Tabby. (Oggi il Memo è in
  `~/Documents/Tabby Memo.txt`: in Swift si sposta in Kat.)

---

## 🛠 Direttamente nell'app Swift
- **Animazione d'avvio** (storia di Daniele del 22/10: schermo nero, video del logo e del
  gatto, poi il riquadro che porta a Spotlight o alle cartelle — prototipo
  `docs/prototipo-avvio.html`, video in `assets/avvio/`).
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
