import AppKit
import TabbyCore

/// V-1 e X-4: il velo #0B0D12 all'85% sotto Spotlight e sotto il **pannello di qualunque app** (la
/// chat rapida di Claude, le azioni rapide), così il testo dietro non si legge. Sta sotto la barra di
/// Tabby (come il velo della vista divisa), non prende i clic e compare senza dissolvenza.
///
/// A riposo non costa niente: si guarda solo dopo un segnale (⌘Spazio, un'app che passa davanti o
/// cambia la finestra con l'attenzione, un'azione di Tabby), per poco più di un secondo; poi solo
/// finché il pannello c'è (20 volte al secondo, al massimo 10 minuti).
///
/// Visto sul Mac (10/11/2026): Spotlight non diventa mai l'app davanti; aperto ha una finestra ben
/// visibile al livello 23, chiudendolo diventa trasparente subito e sparisce un secondo dopo. La chat
/// rapida di Claude è una finestra grande come lo schermo al livello 1000. Raycast invece non dà
/// nessun segnale affidabile (finestra «sullo schermo» anche da chiuso, app sempre «nascosta»): dopo
/// tre tentativi resta senza velo (deciso con Daniele).
@MainActor
final class VeloSpotlight {
    private var pannello: NSPanel?
    private var controllo: Timer?
    private var da = Date.distantPast
    private var visto = false
    /// Il pannello di quale app si aspetta (nil = Spotlight); `pid` nil = aperto da un'azione di Tabby.
    private var app: String?
    private var pid: pid_t?

    func forse(app: String? = nil, pid: pid_t? = nil) {
        guard Impostazioni.shared.valore("spotlightDim") as? Bool ?? true else { return }
        if controllo != nil && visto && app != nil && app != self.app { return }   // un velo acceso resta del suo pannello
        da = Date(); visto = false; self.app = app; self.pid = pid
        controllo?.invalidate()
        controllo = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.controlla() }
        }
    }

    /// Un'app che smette di essere davanti: il velo va via subito, senza aspettare il prossimo controllo.
    func ricontrolla() { if controllo != nil { controlla() } }

    /// Quanto si aspetta che il pannello compaia: Spotlight e le azioni di Tabby ci mettono un attimo;
    /// un'app appena passata davanti (o con la finestra appena cambiata) ce l'ha già.
    private var attesa: Double { app != nil && pid != nil ? 0.6 : 1.5 }

    private func controlla() {
        let tempo = Date().timeIntervalSince(da)
        let finestre = VeloSpotlight.finestreSopra()
        // il pannello dell'app, e comunque Spotlight (un'altra app non spegne il suo velo)
        let livello = app.flatMap { pannelloConTastiera($0, finestre) } ?? finestre.filter { $0.app == "Spotlight" }.map(\.livello).max()
        if let livello, tempo < 600 {
            visto = true
            mostra(sotto: livello)
        } else if visto || tempo > attesa || tempo >= 600 {      // chiuso, o non si è mai aperto
            spegni()
        }
    }

    /// Il pannello di un'app conta solo se ha la tastiera: è la finestra con l'attenzione dell'app
    /// davanti. Una finestrella che sta sopra senza che tu ci scriva (il video piccolo di un browser) no.
    private func pannelloConTastiera(_ nome: String, _ finestre: [Finestra]) -> Int? {
        guard let p = finestre.filter({ $0.app == nome }).max(by: { $0.livello < $1.livello }) else { return nil }
        guard let pid else { return p.livello }                  // da un'azione di Tabby: sì
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
        // sotto la barra di Tabby (che resta in vista) e sopra le finestre delle app
        p.level = NSWindow.Level(rawValue: min(livello - 1, NSWindow.Level.floating.rawValue - 1))
        if !p.isVisible { p.setFrame(Sistema.schermo.frame, display: false); p.orderFrontRegardless() }
    }

    private func spegni() {
        controllo?.invalidate(); controllo = nil
        pannello?.orderOut(nil)
    }

    struct Finestra { let app: String; let livello: Int; let cornice: CGRect }

    /// Le finestre sopra quelle normali (livello > 0, non i menu aperti) ben visibili (trasparenza
    /// > 0,5) e non minuscole, con la cornice contata dall'alto come l'Accessibilità. Nome e livello
    /// si leggono senza permessi.
    nonisolated static func finestreSopra() -> [Finestra] {
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return l.compactMap { w in
            guard let app = w[kCGWindowOwnerName as String] as? String, (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let ly = w[kCGWindowLayer as String] as? Int, ly > 0, ly < 2000, ly != 101,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let r = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            return r.width > 200 && r.height > 40 ? Finestra(app: app, livello: ly, cornice: r) : nil
        }
    }
}
