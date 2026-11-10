import AppKit
import Carbon.HIToolbox
import TabbyCore

/// V-1: con Spotlight (o Raycast) aperto lo schermo, Tabby compresa, si copre con un velo #0B0D12 all'85%,
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
        controllo = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.controlla() }
        }
    }

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

    /// Il pannello di un'app (sopra le finestre normali, non a tutto schermo), se è aperto.
    nonisolated static func livelloPannello(_ app: String) -> Int? {
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let largo = NSScreen.screens.first?.frame.width ?? 1440
        for w in l where (w[kCGWindowOwnerName as String] as? String) == app {
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:], ly = w[kCGWindowLayer as String] as? Int ?? 0
            if ly > 0, ly < 1000, (b["Width"] ?? 0) > 200, (b["Width"] ?? 0) < largo * 0.7, (b["Height"] ?? 0) > 60 { return ly }
        }
        return nil
    }

    /// Il livello della finestra di Spotlight, se è aperta (nome e livello si leggono senza permessi).
    nonisolated static func livelloSpotlight() -> Int? {
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        // anche Raycast, che molti (Daniele compreso) usano al posto di Spotlight con ⌘Spazio
        for w in l where ["Spotlight", "Raycast"].contains(w[kCGWindowOwnerName as String] as? String ?? "") {
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            if (b["Height"] ?? 0) > 40, (b["Width"] ?? 0) > 200 { return w[kCGWindowLayer as String] as? Int }
        }
        return nil
    }
}
