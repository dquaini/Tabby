# Ricerca: Berd, Goose e Buzz (Block) — spunti per «Automazione» di Tabby

Raccolta l'8/11/2026 su richiesta di Daniele, da riprendere quando si progetta la sezione
**Automazione**. Fonti: berd.xyz e i repository pubblici GitHub `block/berd`, `block/buzz`,
`aaif-goose/goose` (i documenti originali sono in questa cartella: `berd/`, `buzz/`, `goose/`).

## In breve: cosa sono

Tre prodotti open source di **Block** (Square, Cash App) che lavorano insieme:

- **Goose** — il "motore": un agente AI che gira sul tuo computer (app, terminale, API). Usa
  15+ modelli (Anthropic, OpenAI, Google, Ollama…) e 70+ estensioni tramite MCP. Ora sta nella
  Linux Foundation (Agentic AI Foundation).
- **Berd** — l'app desktop "carina" sopra Goose (Tauri + React): chat con agenti, progetti
  legati a cartelle e repo, *skill*, *automazioni*, scelta del modello. Slogan: «Less chatting,
  more doing». ~1.000 stelle, molto attivo.
- **Buzz** — uno spazio di lavoro stile Slack dove **persone e agenti stanno negli stessi
  canali** (gli agenti sono membri, non bot), self-hosted, ogni azione è un evento firmato
  (protocollo Nostr). Ha **workflow** in YAML. ~37.000 stelle.

## Come funzionano le automazioni da loro

- **Berd — "Automations":** un'automazione è un compito salvato e ripetibile, distinto da una
  chat. **Si crea chiacchierando** («Descrivi cosa vuoi automatizzare»): una sessione apposita
  scrive una bozza, la vedi a lato, la correggi a parole («Edit with chat»), poi la approvi e
  diventa una "tessera". Ogni automazione ha: titolo, **istruzioni** (testo per l'agente),
  **pianificazione** (nessuna / ogni ora / ogni giorno / … / espressione cron), fuso orario,
  strumenti e collegamenti usati, notifiche (Slack) su successo/errore/«serve il tuo input»,
  **cronologia delle esecuzioni** con l'ultimo risultato, «Esegui ora», duplica, elimina.
- **Goose — "Recipes" + "Scheduler":** una *ricetta* è un flusso riutilizzabile (istruzioni,
  estensioni, impostazioni) in un file YAML, condivisibile con un link. Si pianifica: nome,
  ricetta, modalità (in background senza finestra, o in primo piano), frequenza (convertita in
  cron). Elenco delle pianificazioni con «Esegui ora», «Modifica», «Pausa» e le sessioni create
  da ogni esecuzione. Le ricette possono lanciare *sub-ricette* e *subagenti* in parallelo.
- **Buzz — "Workflows":** automazioni per canale in YAML, con condizioni. **Inneschi:**
  messaggio, reazione (emoji), orario, webhook. Ogni passo tracciato; *cancelli di
  approvazione* (un umano approva prima di proseguire, es. una 👍 su un messaggio). Gli agenti
  gestiscono i workflow tramite MCP.

## Principi di prodotto interessanti (dal loro PRODUCT.md)

«Rendi leggibile il contesto» (si deve sempre capire quale progetto, file, agente, modello è
attivo) · «Tieni quieta la superficie di lavoro» · «La configurazione fa parte del lavoro» ·
«Mostra la verità operativa» (caricamenti, errori, permessi detti chiaramente) · «Progetta per
la continuità» (riprendere senza ricostruire nella testa). Anti-riferimenti: chatbot
generico, terminale scuro, cruscotto pieno di metriche, «magia dell'assistente».

## Dove Tabby è diversa (e autentica)

Loro automatizzano **dentro la loro app** (chat, repo, canali). Tabby vive **un livello sopra
tutte le app, a livello di sistema**: sa quali app e finestre sono aperte, quali siti, le
cartelle (spazi di lavoro), la Concentrazione, i Lampi, la scrivania, l'ora, il Wi-Fi.
Quindi le automazioni di Tabby possono **preparare e riordinare l'ambiente di lavoro**, non
solo produrre testo.

## Spunti da valutare per Automazione (da discutere, niente è deciso)

1. **Crearle a parole, con anteprima** (come Berd): «ogni mattina alle 9 apri Lavoro e la
   Concentrazione da 50 minuti» → Tabby mostra la bozza come una scheda leggibile, la correggi,
   la confermi. Con un modulo semplice come alternativa.
2. **Inneschi propri di un livello di sistema** (al posto dei messaggi/reazioni di Buzz):
   all'avvio del Mac · a un orario · collegandosi a un Wi-Fi · aprendo/chiudendo un'app ·
   collegando un monitor · inizio/fine di una Concentrazione · un evento del Calendario.
3. **Azioni di Tabby**: apri una cartella, avvia la Concentrazione, vista divisa, apri un Lampo,
   chiudi le app di svago, scrivi nel Memo, (in futuro) affida un compito a un agente che salva
   in **Kat**.
4. **Cronologia e "Esegui ora"**, «Pausa», ultimo risultato (come Goose/Berd): verità
   operativa.
5. **Cancelli di approvazione** (come Buzz): prima di un'azione forte, Tabby chiede con un
   avviso («Apro Lavoro?» · Sì / Più tardi).
6. **Ricette condivisibili** (come Goose): esportare un'automazione o una cartella come file
   da dare a un collega.
7. **Agenti dentro Tabby** in futuro: Tabby come l'ambiente (finestre, cartelle, Kat) e un
   agente (Goose, Claude…) collegato tramite protocolli aperti (MCP/ACP), senza rifare un
   motore AI.
