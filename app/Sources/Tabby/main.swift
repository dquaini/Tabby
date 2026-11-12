import AppKit
import TabbyCore

// Tabby, l'app. Tappa 1 (fondamenta): diario, impostazioni importate da Hammerspoon, permesso
// Accessibilità. Tappa 2: la barra (Controllore.swift, Barra.swift).
// Tappa 3: le finestre come schede (Finestre.swift nel motore).
// Tappa 4: i browser, i loghi dei siti, le notifiche (Browser.swift).
// Tappa 5: la vista divisa (Divisa.swift nel motore, Divisione.swift, ControlloreDivisa.swift).
// Tappa 6: le cartelle (Cartelle.swift nel motore, ControlloreCartelle.swift, Componenti.swift).
// Tappa 7: Lampi, Memo, Concentrazione, la barra che cerca tutto (Strumenti.swift nel motore).
// Tappa 8: la finestra di Tabby, la guida del primo avvio, la sfera, la pausa, i temi.
//
// In sviluppo, per riavviare senza le animazioni:  open Tabby.app --args --senza-avvio
// Tabby non ha icona nel Dock (è "accessoria", come le app della barra dei menu).
//
// Prova dal Terminale senza aprire niente:  Tabby.app/Contents/MacOS/Tabby --prova

let versione = "0.13"

if CommandLine.arguments.contains("--prova") {
    let n = Importazione.daHammerspoon()
    let s = Impostazioni.shared
    print("Tabby \(versione)")
    print("Accessibilità: \(Permessi.accessibilita ? "sì" : "no")")
    print("Impostazioni importate adesso: \(n)")
    print("Posizione: \(s.posizione) · schede in ordine: \(s.ordine.count) · cartelle: \(s.cartelle.count) · Lampi: \(s.lampi.count)")
    diario("prova dal Terminale")
    Diario.shared.aspetta()
    exit(0)
}

@MainActor
final class Avvio: NSObject, NSApplicationDelegate {
    let inizio = Date()
    let controllore = Controllore()

    func applicationDidFinishLaunching(_ n: Notification) {
        diario("avvio \(versione) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        // chi arriva da Hammerspoon ha già fatto tutto: niente guida del primo avvio
        if Importazione.daHammerspoon() > 0 { Impostazioni.shared.imposta("primoAvvioFatto", true) }
        let fatto = Impostazioni.shared.valore("primoAvvioFatto") as? Bool ?? false
        // ogni volta che l'app si apre da zero: le due animazioni (intanto Tabby si prepara dietro)
        let arg = CommandLine.arguments
        if let i = arg.firstIndex(of: "--sezione"), i + 1 < arg.count { controllore.finestraTabby.mostra(sezione: arg[i + 1]) }   // per provarla
        else if !arg.contains("--senza-avvio") { controllore.finestraTabby.avvio() }
        if Permessi.accessibilita {
            pronta()
        } else {
            // la guida spiega il perché; chi l'ha già vista riceve subito la richiesta di macOS
            diario("manca il permesso Accessibilità")
            if fatto { Permessi.chiediAccessibilita() }
            controllore.attesaPermesso.aspetta { [weak self] in self?.pronta() }
        }
    }

    func pronta() {
        controllore.avvia()
        let ms = Int(Date().timeIntervalSince(inizio) * 1000)
        diario("pronta in \(ms) ms · \(controllore.stato.schede.count) schede")
    }
}

let app = NSApplication.shared
let avvio = Avvio()
app.delegate = avvio
app.setActivationPolicy(.accessory)
app.run()
