import AppKit
import ApplicationServices
import TabbyCore

/// Gli accessi con Google, Apple, Microsoft (idea di Daniele, 12/11/2026). Quando un browser apre
/// la finestrella d'accesso, Tabby la mette **al centro** dello schermo sopra uno sfondo nero come
/// quello di Spotlight; quando si chiude, si torna alla scheda di prima. Ogni accesso finisce nello
/// **storico** (solo sul Mac: quando, quale sito, con quale servizio), nella sezione Privacy.
/// Si guarda solo quando un browser crea una finestra: nessun controllo periodico.
extension Controllore {
    /// Un browser ha creato una finestra: è un accesso? Il titolo arriva un attimo dopo.
    func forseAccesso(_ w: AXUIElement, pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid), let b = app.bundleIdentifier, browserNoti[b] != nil,
              let n = Sistema.numero(w), !accessi.visti.contains(n) else { return }
        let prima = stato.schede.first { $0.chiave == stato.attiva }        // il sito per cui accedi
        for t in [0.4, 1.0, 2.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                self?.controllaAccesso(w, n, app, prima: prima)
            }
        }
    }

    private func controllaAccesso(_ w: AXUIElement, _ n: UInt32, _ app: NSRunningApplication, prima: Scheda?) {
        guard !accessi.visti.contains(n), let b = app.bundleIdentifier else { return }
        let dom = browserNoti[b]?.tipo == .accessibilita ? Browser.esplora(w).sito.flatMap(dominio) : nil
        guard let servizio = servizioDAccesso(titolo: Sistema.titolo(w) ?? "", dominio: dom) else { return }
        accessi.visti.insert(n)
        let sito = prima.flatMap { $0.sito ?? $0.inVista.flatMap(dominio) } ?? prima?.nome ?? "?"
        accessi.registra(sito: sito, servizio: servizio, browser: browserNoti[b]?.breve ?? b)
        diario("accesso con \(servizio) per \(sito)")
        // al centro dello spazio delle app, davanti, sopra lo sfondo nero
        if let r = Sistema.cornice(w) {
            let spazio = Sistema.dallAlto(Sistema.spazioApp(posizione: stato.posizione))
            var p = CGPoint(x: spazio.midX - r.width / 2, y: max(spazio.minY, spazio.midY - r.height / 2))
            AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
        }
        AXUIElementPerformAction(w, kAXRaiseAction as CFString)
        accessi.mostraVelo(sotto: n, pid: app.processIdentifier) { [weak self] in
            if let s = prima, let x = self?.stato.schede.first(where: { $0.chiave == s.chiave }) { self?.vai(x, daTe: false) }
        }
    }
}

/// Lo storico degli accessi e il velo nero sotto la finestrella.
@MainActor
final class Accessi {
    struct Voce: Equatable { let quando: Date; let sito: String; let servizio: String; let browser: String }
    var visti = Set<UInt32>()
    private(set) var storico: [Voce] = (Impostazioni.shared.valore("accessi") as? [[String: Any]] ?? []).compactMap { d in
        guard let q = d["quando"] as? Double, let s = d["sito"] as? String, let v = d["servizio"] as? String else { return nil }
        return Voce(quando: Date(timeIntervalSince1970: q), sito: s, servizio: v, browser: d["browser"] as? String ?? "")
    }
    private var velo: NSPanel?
    private var controllo: Timer?

    func registra(sito: String, servizio: String, browser: String) {
        storico.insert(Voce(quando: Date(), sito: sito, servizio: servizio, browser: browser), at: 0)
        storico = Array(storico.prefix(300))
        salva()
    }

    func cancellaStorico() { storico = []; salva() }

    private func salva() {
        Impostazioni.shared.imposta("accessi", storico.map { ["quando": $0.quando.timeIntervalSince1970, "sito": $0.sito, "servizio": $0.servizio, "browser": $0.browser] })
    }

    /// Il velo nero (come Spotlight) appena sotto la finestrella; un clic sul velo la riporta davanti.
    /// Va via quando la finestrella si chiude (si guarda solo finché c'è).
    func mostraVelo(sotto n: UInt32, pid: pid_t, chiusa: @escaping @MainActor () -> Void) {
        let p = velo ?? {
            let p = PannelloVelo(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.backgroundColor = NSColor(red: 0x0B / 255, green: 0x0D / 255, blue: 0x12 / 255, alpha: 0.85)
            p.isOpaque = false; p.hasShadow = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            velo = p
            return p
        }()
        (p as? PannelloVelo)?.clic = { if let w = Sistema.finestre(pid).first(where: { Sistema.numero($0) == n }) { AXUIElementPerformAction(w, kAXRaiseAction as CFString) } }
        p.level = .normal
        p.setFrame(Sistema.schermo.frame, display: false)
        p.order(.below, relativeTo: Int(n))
        controllo?.invalidate()
        controllo = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !Sistema.finestre(pid).contains(where: { Sistema.numero($0) == n }) else { return }
                self.controllo?.invalidate(); self.controllo = nil
                self.velo?.orderOut(nil)
                chiusa()
            }
        }
    }
}

/// Il velo prende i clic (non passano alle finestre dietro): un clic riporta davanti la finestrella.
final class PannelloVelo: NSPanel {
    var clic: (() -> Void)?
    override func mouseDown(with event: NSEvent) { clic?() }
}
