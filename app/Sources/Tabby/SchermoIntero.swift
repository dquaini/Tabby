import AppKit
import ApplicationServices
import TabbyCore

/// Schermo intero (Z-1…Z-3). La barra non va sulle scrivanie a schermo intero (Z-1). Z-3, l'anticipo:
/// al clic sul pallino verde (letto con l'Accessibilità solo se il clic è nei primi 120×60 punti
/// della finestra davanti) o a ⌃⌘F Tabby sparisce **subito**, senza aspettare l'animazione di macOS;
/// se dopo 2 s lo schermo intero non c'è, ricompare. Si guardano solo i clic, mai i movimenti.
extension Controllore {
    func osservaSchermoIntero() {
        guard monitorClic == nil else { return }
        monitorClic = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            MainActor.assumeIsolated { self?.clicForseVerde(NSEvent.mouseLocation) }
        }
        Tasti.suSchermoIntero = { [weak self] in self?.anticipaSchermoIntero() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {                      // uscito dallo schermo intero: la barra torna
                guard let self, !self.davantiASchermoIntero() else { return }
                self.mostraBarra()
            }
        }
    }

    private func clicForseVerde(_ p: NSPoint) {
        guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Sistema.mioBid,
              let w = Sistema.finestraAttiva(app.processIdentifier), let r = Sistema.cornice(w) else { return }
        let altezza = NSScreen.screens.first?.frame.height ?? 0
        let q = CGPoint(x: p.x, y: altezza - p.y)                 // l'Accessibilità conta dall'alto
        guard q.x >= r.minX, q.x <= r.minX + 120, q.y >= r.minY, q.y <= r.minY + 60 else { return }
        var e: AXUIElement?
        guard AXUIElementCopyElementAtPosition(Sistema.elemento(app.processIdentifier), Float(q.x), Float(q.y), &e) == .success, let e,
              (Sistema.attributo(e, kAXSubroleAttribute) as String?) == kAXFullScreenButtonSubrole,
              (Sistema.attributo(w, "AXFullScreen") as Bool?) != true else { return }
        anticipaSchermoIntero()
    }

    func anticipaSchermoIntero() {
        guard !stato.inPausa else { return }
        pannello.nascondiScivolando()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, !self.davantiASchermoIntero() else { return }
            self.mostraBarra()                                  // non è andato a schermo intero
        }
    }

    func davantiASchermoIntero() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication, let w = Sistema.finestraAttiva(app.processIdentifier) else { return false }
        return (Sistema.attributo(w, "AXFullScreen") as Bool?) == true
    }
}
