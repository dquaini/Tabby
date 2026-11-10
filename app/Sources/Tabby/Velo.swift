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
    private var pid: pid_t?

    func forse(app: String? = nil, pid: pid_t? = nil) {
        guard Impostazioni.shared.valore("spotlightDim") as? Bool ?? true else { return }
        if controllo != nil && visto && app != nil && app != self.app { return }   // un velo già acceso resta del suo pannello
        da = Date(); visto = false; self.app = app; self.pid = pid
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
        // il pannello dell'app, e comunque Spotlight/Raycast (un'altra app non spegne il loro velo)
        let livello = app.flatMap { pannelloConTastiera($0) } ?? VeloSpotlight.livelloSpotlight()
        if let livello, tempo < 600 {
            visto = true
            mostra(sotto: livello)
        } else if visto || tempo > (app == nil ? 1.5 : 1.2) || tempo >= 600 {   // chiuso, o non si è mai aperto
            spegni()
        }
    }

    /// Il pannello di un'app conta solo se ha la tastiera (Raycast, la chat rapida di Claude): è la
    /// finestra con l'attenzione dell'app davanti. Una finestrella che sta sopra senza che tu ci
    /// scriva (il video piccolo di un browser) no.
    private func pannelloConTastiera(_ nome: String) -> Int? {
        guard let p = VeloSpotlight.finestraPannello(di: nome) else { return nil }
        guard let pid else { return p.livello }               // dalle azioni di Tabby: sì
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let w = Sistema.finestraAttiva(pid), let r = Sistema.cornice(w) else { return nil }
        return abs(r.minX - p.cornice.minX) < 3 && abs(r.minY - p.cornice.minY) < 3 && abs(r.width - p.cornice.width) < 3 ? p.livello : nil
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
        // sotto la barra di Tabby (che resta in vista, come col velo della vista divisa) e sopra le
        // finestre delle app; i lanciatori stanno tutti più in alto (Spotlight 23, Claude 1000)
        p.level = NSWindow.Level(rawValue: min(livello - 1, NSWindow.Level.floating.rawValue - 1))
        if !p.isVisible { p.setFrame(Sistema.schermo.frame, display: false); p.orderFrontRegardless() }
    }

    private func spegni() {
        controllo?.invalidate(); controllo = nil
        pannello?.orderOut(nil)
    }

    /// Il pannello di un'app aperto: una sua finestra sopra quelle normali (livello > 0) e visibile.
    /// La chat rapida di Claude è una finestra trasparente grande come lo schermo, al livello 1000.
    nonisolated static func livelloPannello(_ app: String) -> Int? { finestraPannello(di: app)?.livello }

    /// La finestra-pannello più alta di un'app (livello > 0, ben visibile), con la sua cornice
    /// (contata dall'alto, come l'Accessibilità).
    nonisolated static func finestraPannello(di nome: String) -> (livello: Int, cornice: CGRect)? {
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let c = l.compactMap { w -> (Int, CGRect)? in
            guard (w[kCGWindowOwnerName as String] as? String) == nome, (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let ly = w[kCGWindowLayer as String] as? Int, ly > 0, ly < 2000, ly != 101,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let r = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            return r.width > 200 && r.height > 40 ? (ly, r) : nil
        }
        return c.max { $0.0 < $1.0 }.map { (livello: $0.0, cornice: $0.1) }
    }

    /// Spotlight o Raycast aperti? Visto sul Mac il 10/11/2026: Spotlight non diventa mai l'app in
    /// primo piano; aperto ha una finestra visibile (livello 23), chiudendolo la finestra diventa
    /// **trasparente subito** e sparisce quasi un secondo dopo: conta solo se è ben visibile.
    static let lanciatori = ["com.apple.Spotlight": "Spotlight", "com.raycast.macos": "Raycast",
                             "com.runningwithcrayons.Alfred": "Alfred"]
    static func livelloSpotlight() -> Int? {
        if let l = livelloFinestra(di: "Spotlight", sopraLeNormali: true) ?? livelloFinestra(di: "Alfred", sopraLeNormali: true) { return l }
        // Raycast: aperto quando è davanti o ha una finestra ben visibile (anche al livello delle normali)
        if let r = NSRunningApplication.runningApplications(withBundleIdentifier: "com.raycast.macos").first,
           let l = livelloFinestra(di: "Raycast", sopraLeNormali: false, stretta: true) {   // non le Impostazioni di Raycast
            _ = r; return l
        }
        return nil
    }

    /// Il livello della finestra più alta di un'app fra quelle ben visibili (trasparenza > 0,5).
    nonisolated static func livelloFinestra(di nome: String, sopraLeNormali: Bool, stretta: Bool = false) -> Int? {
        let largo = NSScreen.screens.first?.frame.width ?? 1440
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        return l.filter { w in
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:], ly = w[kCGWindowLayer as String] as? Int ?? 0
            return (w[kCGWindowOwnerName as String] as? String) == nome && (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5
                && (b["Width"] ?? 0) > 200 && (b["Height"] ?? 0) > 40 && (!sopraLeNormali || ly > 0) && ly < 2000
                && (!stretta || (b["Width"] ?? 0) < largo * 0.7)
                && ly != 101                                   // i menu aperti non sono pannelli
        }.compactMap { $0[kCGWindowLayer as String] as? Int }.max()
    }
}
