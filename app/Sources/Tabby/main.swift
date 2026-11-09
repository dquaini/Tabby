import AppKit
import TabbyCore

// Tabby, l'app. Tappa 1 (fondamenta): diario, impostazioni importate da Hammerspoon, permesso
// Accessibilità. Tappa 2: la barra (Controllore.swift, Barra.swift).
// Tappa 3: le finestre come schede (Finestre.swift nel motore).
// Tabby non ha icona nel Dock (è "accessoria", come le app della barra dei menu).
//
// Prova dal Terminale senza aprire niente:  Tabby.app/Contents/MacOS/Tabby --prova

let versione = "0.3"

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
    let attesa = AttesaPermesso()
    let inizio = Date()
    let controllore = Controllore()

    func applicationDidFinishLaunching(_ n: Notification) {
        diario("avvio \(versione) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        Importazione.daHammerspoon()
        if Permessi.accessibilita {
            pronta()
        } else {
            // La guida del primo avvio (tappa più avanti) spiegherà il perché; per ora la
            // richiesta di macOS, e Tabby aspetta da sola che il permesso arrivi.
            diario("manca il permesso Accessibilità: lo chiedo")
            Permessi.chiediAccessibilita()
            attesa.aspetta { [weak self] in self?.pronta() }
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
