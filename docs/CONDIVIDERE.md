# Come condividere Tabby

## Oggi (versione Hammerspoon)

Tabby oggi è un insieme di file che gira dentro **Hammerspoon**, un'app gratuita per
Mac. Per darla a qualcuno servono tre cose: Hammerspoon, la cartella di Tabby e una
riga che dice a Hammerspoon di caricarla. Circa 10 minuti, anche per chi non è
pratico.

### 1. Dare la cartella di Tabby

Il progetto su GitHub (`dquaini/Tabby`) è **privato**: gli altri non lo vedono. Tre
strade, dalla più semplice:

| Strada | Come | Aggiornamenti |
|---|---|---|
| **File .zip** | github.com/dquaini/Tabby → Code → Download ZIP, e lo mandi (AirDrop, mail, WhatsApp) | a mano: gli rimandi lo zip |
| **Invito su GitHub** | github.com/dquaini/Tabby → Settings → Collaborators → Add people (serve un suo account GitHub) | lui fa `git pull` |
| **Progetto pubblico** | Settings → Danger Zone → Change visibility → Public | chiunque scarica e aggiorna |

Consiglio per i primi amici: **lo zip**. Il progetto pubblico solo quando Tabby è
pronta per tutti (e magari prima togliendo le note personali da `CLAUDE.md`).
Nello zip non ci sono dati tuoi: Memo, cartelle e impostazioni stanno sul tuo Mac,
non nel progetto.

### 2. Istruzioni da mandare a chi la installa

1. Scarica e installa **Hammerspoon** da hammerspoon.org (gratuito), aprilo e dagli
   il permesso **Accessibilità** quando lo chiede (Impostazioni di Sistema → Privacy e
   sicurezza → Accessibilità → Hammerspoon acceso).
2. Metti la cartella di Tabby dove vuoi, per esempio in Documenti, e chiamala
   `Tabby`.
3. Nella barra dei menu, icona di Hammerspoon (il martello) → **Open Config**: si apre
   il file `init.lua`. Scrivici questa riga (con il percorso giusto) e salva:
   ```lua
   dofile(os.getenv("HOME") .. "/Documents/Tabby/tabby.lua")
   ```
4. Icona di Hammerspoon → **Reload Config**. Compare "Tabby v… attiva".
5. La prima volta che apri Chrome, Safari, Brave o Edge, macOS chiede "Hammerspoon
   vuole controllare …": **Consenti** (serve per nomi e loghi dei siti).
6. Consigliati: Impostazioni → Barra dei menu → nascondi automaticamente; Dock →
   nascondi automaticamente; Trackpad → Altri gesti → togli lo scorrimento a tre dita
   tra le scrivanie (lo fa Tabby). Icona di Hammerspoon → Preferences → "Launch
   Hammerspoon at login" acceso.
7. Tutto parte con **⌃⌥ (Ctrl + Option)**: ⌃⌥1…9 per le schede, ⌃⌥M il Memo.
   La presentazione spiega il resto.

Se qualcosa non va: icona di Hammerspoon → Console, e mandare le righe che iniziano
con `Tabby ·`.

### 3. Il tuo Mac di lavoro (MacBook Air col notch)

Lì Tabby va installata da GitHub, così si aggiorna con un comando:

1. Nel Terminale: `ssh-keygen -t ed25519` (Invio a tutte le domande), poi
   `cat ~/.ssh/id_ed25519.pub` e copia la riga su github.com/settings/keys → New SSH
   key (nome "Mac di lavoro").
2. `git clone git@github.com:dquaini/Tabby.git ~/Progetti/Tabby`
3. `init.lua` di Hammerspoon:
   ```lua
   require("hs.ipc")
   dofile(os.getenv("HOME") .. "/Progetti/Tabby/tabby.lua")
   ```
4. Reload Config. Per aggiornare: `cd ~/Progetti/Tabby && git pull`, poi ⌘⌃⌥R.

Oppure apri Claude Code nella cartella e chiedi: "metti in funzione Tabby su questo
Mac" (le istruzioni sono in `CLAUDE.md`).

## Domani (app Swift)

Con l'app Swift basterà **scaricare Tabby.app** e aprirla: niente Hammerspoon, niente
file da scrivere; una configurazione guidata chiede i permessi.
Per distribuirla senza che macOS dica "sviluppatore non identificato" serve
l'**Apple Developer Program** (99 $ l'anno): l'app viene firmata e controllata da
Apple (notarizzazione). Poi si può mettere su un sito con gli aggiornamenti
automatici (Sparkle). Il Mac App Store è difficile: Tabby deve controllare le altre
app, cosa che l'App Store limita molto.
