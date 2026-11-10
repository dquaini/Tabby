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
        let fascia = stato.posizione == "top" && Sistema.fasciaNotch
        guard nascondiTabby || fascia else { mostraBarra(); return }
        monitorMouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMosso() }
        }
        monitorMouseLocale = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] e in
            MainActor.assumeIsolated { self?.mouseMosso() }; return e
        }
        if !barraSotto(NSEvent.mouseLocation, margine: 0) { pannello.orderOut(nil) }
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

    private func mouseMosso() {
        guard !stato.inPausa, !stato.tabbyChiusa, !sfera.s.visibile else { return }
        let p = NSEvent.mouseLocation
        // A-6: nella fascia del notch, col mouse in cima scende la barra dei menu: Tabby si toglie
        // e torna quando il mouse si allontana (oltre l'altezza della barra dei menu)
        if !nascondiTabby {
            guard stato.posizione == "top", Sistema.fasciaNotch else { return }
            let cima = Sistema.schermo.frame.maxY
            if p.y >= cima - 1, pannello.isVisible { pannello.orderOut(nil) }
            else if p.y < cima - 34, !pannello.isVisible { pannello.mostra() }
            return
        }
        // mentre trascini, dividi, scegli schede o rinomini, la barra resta in vista
        let occupata = stato.divisione != nil || stato.scelta != nil || stato.rinomina != nil || palco.aperto
        if pannello.isVisible {
            if !occupata && !barraSotto(p, margine: 12) { pannello.orderOut(nil) }
        } else if bordo(p) {
            pannello.mostra()
        }
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
