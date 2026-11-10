import AppKit
import TabbyCore

/// Nascondi Tabby (SPECIFICA A-3): la barra è nascosta e le app usano tutto lo schermo; compare
/// portando il mouse sul **bordo** dalla sua parte (entro 2 punti) e si nasconde quando il mouse
/// esce (margine 12). Il mouse si segue **solo** con questa impostazione accesa.
extension Controllore {
    var nascondiTabby: Bool { imp.valore("autohide") as? Bool ?? false }

    /// Accende o spegne il controllo del mouse secondo l'impostazione.
    func aggiornaNascondi() {
        Sistema.tabbyNascosta = nascondiTabby
        if let m = monitorMouse { NSEvent.removeMonitor(m); monitorMouse = nil }
        if let m = monitorMouseLocale { NSEvent.removeMonitor(m); monitorMouseLocale = nil }
        ascoltaMenu()
        let menuSopra = stato.posizione == "top" && (Sistema.fasciaNotch || Sistema.barraMenuNascosta)
        guard nascondiTabby || menuSopra else { mostraBarra(); return }
        monitorMouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMosso() }
        }
        monitorMouseLocale = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] e in
            MainActor.assumeIsolated { self?.mouseMosso() }; return e
        }
        if nascondiTabby && !barraSotto(NSEvent.mouseLocation, margine: 0) { pannello.orderOut(nil) }
        else { mostraBarra() }
    }

    /// Un menu di Tabby aperto (⚙︎, ⚡︎, tasto destro) tiene la barra in vista; chiuso, si ricontrolla.
    private func ascoltaMenu() {
        guard osservatoriMenu.isEmpty else { return }
        let nc = NotificationCenter.default
        osservatoriMenu = [
            nc.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuAperto = true }
            },
            nc.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuAperto = false; self?.mouseMosso() }
            },
        ]
    }

    func cambiaNascondi(_ sì: Bool) {
        imp.imposta("autohide", sì)
        aggiornaNascondi()
        if let a = NSWorkspace.shared.frontmostApplication { Sistema.adatta(a, posizione: stato.posizione, tranne: finestreInViste()) }
        lampi.disponi()
    }

    /// Mostra la barra, se deve vedersi: con «Nascondi Tabby» solo quando il mouse è sul bordo.
    func mostraBarra() {
        guard !stato.inPausa, !stato.tabbyChiusa, !sfera.s.visibile else { return }
        if nascondiTabby && !barraSotto(NSEvent.mouseLocation, margine: 0) && !bordo(NSEvent.mouseLocation) { return }
        pannello.mostra()
    }

    /// Il mouse decide se Tabby si vede:
    /// - **Menu di Apple** (Tabby in alto e barra dei menu nascosta, o nella fascia del notch): col
    ///   mouse in cima scende il menu di Apple e Tabby si toglie di mezzo; torna quando il mouse scende.
    /// - **Tabby si nasconde**: compare col mouse sul bordo (in alto: toccando la cima e scendendo
    ///   appena, perché la cima è del menu di Apple) e se ne va quando il mouse si allontana. Mentre
    ///   si vede, la finestra davanti le fa posto; quando se ne va, la finestra si riallarga.
    fileprivate func mouseMosso() {
        guard !stato.inPausa, !stato.tabbyChiusa, !sfera.s.visibile else { return }
        let p = NSEvent.mouseLocation, cima = Sistema.schermo.frame.maxY
        let menuSopra = stato.posizione == "top" && (Sistema.barraMenuNascosta || Sistema.fasciaNotch)
        let nelMenu = menuSopra && p.y >= cima - Sistema.altezzaBarraMenu
        if menuSopra && p.y >= cima - 1 { toccataLaCima = Date() }
        // mentre trascini, dividi, scegli schede, rinomini o un menu è aperto, la barra resta
        let occupata = stato.divisione != nil || stato.scelta != nil || stato.rinomina != nil || palco.aperto || menuAperto

        if !nascondiTabby {
            guard menuSopra, !occupata else { return }
            if nelMenu && p.y >= cima - 1 { togliBarra() }
            else if !nelMenu && !pannello.isVisible { pannello.mostra() }
            return
        }
        if occupata { return }
        if pannello.isVisible && pannello.alphaValue > 0.5 {
            if nelMenu || !barraSotto(p, margine: 12) { togliBarra() }
        } else if menuSopra {
            // in alto: si tocca la cima (scende il menu di Apple) e si scende appena → Tabby
            let appena = toccataLaCima.map { Date().timeIntervalSince($0) < 2 } ?? false
            if appena && !nelMenu && p.y >= cima - Sistema.altezzaBarraMenu - Misure.altezza - 24 { compari() }
        } else if bordo(p) {
            compari()
        }
    }

    private func compari() {
        pannello.mostra()
        faiPosto(true)
    }

    private func togliBarra() {
        pannello.nascondiScivolando()
        if nascondiTabby { faiPosto(false) }
    }

    /// Con «Tabby si nasconde»: mentre Tabby si vede la finestra davanti le fa posto, poi si riallarga.
    private func faiPosto(_ visibile: Bool) {
        guard Sistema.tabbyNascosta == visibile else { return }        // già a posto
        Sistema.tabbyNascosta = !visibile
        guard imp.adatta, let a = NSWorkspace.shared.frontmostApplication, a.bundleIdentifier != Sistema.mioBid else { return }
        Sistema.adatta(a, posizione: stato.posizione, tranne: finestreInViste())
    }

    /// Il mouse tocca il bordo dello schermo dalla parte di Tabby (entro 2 punti)?
    private func bordo(_ p: NSPoint) -> Bool {
        let f = Sistema.schermo.frame, v = Sistema.schermo.visibleFrame
        switch stato.posizione {
        case "bottom": return p.y <= v.minY + 2 && p.x >= v.minX && p.x <= v.maxX
        case "left": return p.x <= f.minX + 2
        case "right": return p.x >= f.maxX - 2
        default: return p.y >= f.maxY - 2
        }
    }

    private func barraSotto(_ p: NSPoint, margine m: CGFloat) -> Bool {
        var r = Sistema.cornice(posizione: stato.posizione).insetBy(dx: -m, dy: -m)
        if stato.posizione == "top" { r.size.height += Sistema.schermo.frame.maxY - r.maxY }   // conta anche la barra dei menu sopra
        return r.contains(p)
    }
}
