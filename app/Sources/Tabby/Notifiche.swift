import AppKit
import ApplicationServices
import TabbyCore

/// Le notifiche di macOS non vanno sopra Tabby (SPECIFICA N-5). macOS 26 le disegna in una
/// finestra trasparente grande come lo schermo, del Centro Notifiche, che si può spostare con
/// l'Accessibilità: con Tabby in alto scende sotto la barra, con Tabby a destra va alla sua
/// sinistra; negli altri casi resta dov'è. Tabby se ne accorge quando quella finestra nasce
/// (un avviso, nessun controllo periodico).
extension Controllore {
    func osservaNotifiche() {
        guard osservatoreNotifiche == nil,
              let nc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return }
        var obs: AXObserver?
        guard AXObserverCreate(nc.processIdentifier, { _, elemento, _, ctx in
            guard let ctx else { return }
            let c = Unmanaged<Controllore>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { c.spostaNotifiche(elemento) }
        }, &obs) == .success, let obs else { return }
        let e = Sistema.elemento(nc.processIdentifier)
        AXObserverAddNotification(obs, e, kAXWindowCreatedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        osservatoreNotifiche = obs
        rimettiNotifiche()
    }

    /// Dopo un cambio di posizione: le finestre delle notifiche già aperte si rimettono a posto.
    func rimettiNotifiche() {
        guard let nc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return }
        for w in Sistema.finestre(nc.processIdentifier) { spostaNotifiche(w) }
    }

    fileprivate func spostaNotifiche(_ w: AXUIElement) {
        guard !stato.inPausa, let r = Sistema.cornice(w) else { return }
        let schermo = Sistema.schermo.frame
        guard r.width >= schermo.width * 0.9 else { return }          // solo la finestra grande delle notifiche
        let altezza = NSScreen.screens.first?.frame.height ?? schermo.maxY
        var dx: CGFloat = 0, dy: CGFloat = 0                           // (l'Accessibilità conta dall'alto)
        if !stato.tabbyChiusa && !sfera.s.visibile {
            let barra = Sistema.cornice(posizione: stato.posizione)
            switch stato.posizione {
            case "top": dy = max(0, (altezza - barra.minY) - (altezza - schermo.maxY))
            case "right": dx = -barra.width
            default: break
            }
        }
        var p = CGPoint(x: schermo.minX + dx, y: (altezza - schermo.maxY) + dy)
        if abs(r.minX - p.x) < 1 && abs(r.minY - p.y) < 1 { return }
        AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
        let d = "notifiche spostate di \(Int(dx)), \(Int(dy)) (accanto a Tabby)"
        if d != ultimaNotaNotifiche { ultimaNotaNotifiche = d; diario(d) }
    }
}
