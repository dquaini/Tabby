import AppKit
import TabbyCore

/// Tabby è **sempre in vista** (scelta di Daniele del 10/11/2026: «se usi Tabby la tieni sempre»;
/// «Nascondi Tabby» non c'è più). Un solo caso la fa spostare: Tabby in alto con la barra dei menu
/// che si nasconde da sola (o nella fascia del notch). Col mouse in cima scende il menu di Apple e
/// Tabby si toglie di mezzo; torna quando il mouse scende sotto il menu (SPECIFICA A-6).
/// Il mouse si segue **solo** in quel caso.
extension Controllore {
    /// Accende o spegne il controllo del mouse secondo la posizione e la barra dei menu.
    func aggiornaMouse() {
        if let m = monitorMouse { NSEvent.removeMonitor(m); monitorMouse = nil }
        if let m = monitorMouseLocale { NSEvent.removeMonitor(m); monitorMouseLocale = nil }
        ascoltaMenu()
        mostraBarra()
        guard menuSopra else { return }
        monitorMouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMosso() }
        }
        monitorMouseLocale = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] e in
            MainActor.assumeIsolated { self?.mouseMosso() }; return e
        }
    }

    /// Mostra la barra (non in pausa, non chiusa, non quando c'è la sfera).
    func mostraBarra() {
        guard !stato.tabbyChiusa, !sfera.s.visibile else { return }
        pannello.mostra()
    }

    /// Il menu di Apple può scendere sopra Tabby?
    private var menuSopra: Bool {
        stato.posizione == "top" && (Sistema.barraMenuNascosta || Sistema.fasciaNotch)
    }

    /// Un menu di Tabby aperto (⚙︎, ⚡︎, tasto destro) tiene la barra in vista.
    private func ascoltaMenu() {
        guard osservatoriMenu.isEmpty else { return }
        let nc = NotificationCenter.default
        osservatoriMenu = [
            nc.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuAperto = true }
            },
            nc.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuAperto = false }
            },
        ]
    }

    /// Mouse in cima → il menu di Apple scende: Tabby sale via. Sotto il menu → Tabby torna.
    private func mouseMosso() {
        guard menuSopra, !stato.tabbyChiusa, !sfera.s.visibile else { return }
        let occupata = stato.divisione != nil || stato.scelta != nil || stato.rinomina != nil || palco.aperto || menuAperto
        guard !occupata else { return }
        let p = NSEvent.mouseLocation, cima = Sistema.schermo.frame.maxY
        if p.y >= cima - 1 { pannello.nascondiScivolando() }
        else if p.y < cima - Sistema.altezzaBarraMenu && (!pannello.isVisible || pannello.inUscita) { pannello.mostra(scendendo: true) }
    }
}
