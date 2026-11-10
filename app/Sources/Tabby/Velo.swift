import AppKit
import Carbon.HIToolbox
import TabbyCore

/// V-1: con Spotlight (o Raycast, con qualunque scorciatoia) aperto lo schermo, Tabby compresa, si copre con un velo #0B0D12 all'85%,
/// così il testo dietro non si legge. Non prende i clic (un clic fuori chiude Spotlight come
/// sempre) e compare senza dissolvenza. Si accende con ⌘Spazio (anche dalla scheda «+»); finché
/// è acceso, 20 volte al secondo si guarda se Spotlight c'è ancora; dopo 10 minuti si toglie
/// comunque. A riposo non costa niente: nessun controllo se Spotlight non è stato aperto.
@MainActor
final class VeloSpotlight {
    private var pannello: NSPanel?
    private var controllo: Timer?
    private var da = Date.distantPast
    private var visto = false
    private var app: String?                                  // X-4: il pannello di un'app (Claude, Notion)

    /// ⌘Spazio premuto: Spotlight sta per aprirsi. Con `app`: un'azione rapida ha aperto il pannello
    /// di quell'app (X-4), il velo sta sotto il pannello finché c'è.
    func forse(app: String? = nil) {
        guard Impostazioni.shared.valore("spotlightDim") as? Bool ?? true else { return }
        da = Date(); visto = false; self.app = app
        controllo?.invalidate()
        controllo?.invalidate()
        controllo = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.controlla() }
        }
    }

    /// Un lanciatore che smette di essere in primo piano: il velo va via subito, senza aspettare.
    func ricontrolla() { if controllo != nil { controlla() } }

    private func controlla() {
        let tempo = Date().timeIntervalSince(da)
        let livello = app.map(VeloSpotlight.livelloPannello) ?? VeloSpotlight.livelloSpotlight()
        if let livello, tempo < 600 {
            visto = true
            mostra(sotto: livello)
        } else if visto || tempo > (app == nil ? 1.5 : 3) || tempo >= 600 {   // chiuso, o non si è mai aperto
            spegni()
        }
    }

    private func mostra(sotto livello: Int) {
        let p = pannello ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.backgroundColor = NSColor(red: 0x0B / 255, green: 0x0D / 255, blue: 0x12 / 255, alpha: 0.85)
            p.isOpaque = false; p.hasShadow = false; p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            pannello = p
            return p
        }()
        p.level = NSWindow.Level(rawValue: livello - 1)        // appena sotto Spotlight, sopra Tabby
        if !p.isVisible { p.setFrame(Sistema.schermo.frame, display: false); p.orderFrontRegardless() }
    }

    private func spegni() {
        controllo?.invalidate(); controllo = nil
        pannello?.orderOut(nil)
    }

    /// Il pannello di un'app aperto: una sua finestra sopra quelle normali (livello > 0) e visibile.
    /// La chat rapida di Claude è una finestra trasparente grande come lo schermo, al livello 1000.
    nonisolated static func livelloPannello(_ app: String) -> Int? { livelloFinestra(di: app, sopraLeNormali: true) }

    /// Spotlight o Raycast aperti? Visto sul Mac il 10/11/2026: Spotlight non diventa mai l'app in
    /// primo piano; aperto ha una finestra visibile (livello 23), chiudendolo la finestra diventa
    /// **trasparente subito** e sparisce quasi un secondo dopo: conta solo se è ben visibile.
    static let lanciatori = ["com.apple.Spotlight": "Spotlight", "com.raycast.macos": "Raycast"]
    static func livelloSpotlight() -> Int? {
        livelloFinestra(di: "Spotlight", sopraLeNormali: true) ?? livelloFinestra(di: "Raycast", sopraLeNormali: true)
    }

    /// Il livello della finestra più alta di un'app fra quelle ben visibili (trasparenza > 0,5).
    nonisolated static func livelloFinestra(di nome: String, sopraLeNormali: Bool) -> Int? {
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        return l.filter { w in
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:], ly = w[kCGWindowLayer as String] as? Int ?? 0
            return (w[kCGWindowOwnerName as String] as? String) == nome && (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5
                && (b["Width"] ?? 0) > 200 && (b["Height"] ?? 0) > 40 && (!sopraLeNormali || ly > 0) && ly < 2000
        }.compactMap { $0[kCGWindowLayer as String] as? Int }.max()
    }
}
