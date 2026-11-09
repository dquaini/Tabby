import AppKit
import ApplicationServices
import TabbyCore

/// Tutto quello che Tabby chiede a macOS sulle app e le finestre, tramite l'Accessibilità.
/// Ogni domanda a un'app ha un tempo massimo di 0,25 s: un'app impegnata (es. Chrome in una
/// videochiamata) non deve mai bloccare Tabby.
@MainActor
enum Sistema {
    static let mioBid = Bundle.main.bundleIdentifier ?? "com.dquaini.Tabby"
    /// App che non sono mai schede (oltre a Tabby): Hammerspoon e i Lampi.
    static func ignorate() -> Set<String> {
        var s: Set<String> = [mioBid, "org.hammerspoon.Hammerspoon"]
        for l in Impostazioni.shared.lampi { if let b = l["bid"] as? String, l["menubar"] == nil { s.insert(b) } }
        return s
    }

    static func elemento(_ pid: pid_t) -> AXUIElement {
        let e = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(e, 0.25)
        return e
    }

    static func attributo<T>(_ e: AXUIElement, _ nome: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, nome as CFString, &v) == .success else { return nil }
        return v as? T
    }

    static func finestre(_ pid: pid_t) -> [AXUIElement] {
        attributo(elemento(pid), kAXWindowsAttribute) ?? []
    }

    /// Una finestra che conta come scheda: standard, oppure ridotta, oppure (macOS 26) una
    /// finestra di un'app nascosta che macOS chiama «dialogo». Mai a schermo intero.
    static func èScheda(_ w: AXUIElement, appNascosta: Bool) -> Bool {
        if (attributo(w, "AXFullScreen") as Bool?) == true { return false }
        let sub: String? = attributo(w, kAXSubroleAttribute)
        if sub == kAXStandardWindowSubrole { return true }
        if (attributo(w, kAXMinimizedAttribute) as Bool?) == true { return true }
        return appNascosta && sub == kAXDialogSubrole
    }

    /// Le app che sono schede (S-1, S-4): app "vere" (nel Dock) con almeno una finestra-scheda,
    /// o anche senza finestre se l'impostazione lo chiede.
    static func appSchede() -> [NSRunningApplication] {
        let ign = ignorate()
        let senza = Impostazioni.shared.valore("showWindowless") as? Bool ?? false
        var viste = Set<String>()
        return NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular, let bid = app.bundleIdentifier,
                  !ign.contains(bid), !app.isTerminated, viste.insert(bid).inserted else { return false }
            if senza { return true }
            return finestre(app.processIdentifier).contains { èScheda($0, appNascosta: app.isHidden) }
        }
    }

    // MARK: - Lo spazio delle app

    /// Lo schermo principale (Tabby usa sempre quello).
    static var schermo: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    /// Dove sta la barra, secondo la posizione scelta.
    static func cornice(posizione: String) -> NSRect {
        let v = schermo.visibleFrame
        switch posizione {
        case "bottom": return NSRect(x: v.minX, y: v.minY, width: v.width, height: Misure.altezza)
        case "left":   return NSRect(x: v.minX, y: v.minY, width: Misure.larghezzaLato, height: v.height)
        case "right":  return NSRect(x: v.maxX - Misure.larghezzaLato, y: v.minY, width: Misure.larghezzaLato, height: v.height)
        default:       return NSRect(x: v.minX, y: v.maxY - Misure.altezza, width: v.width, height: Misure.altezza)
        }
    }

    /// Lo spazio delle app: lo schermo utile meno la barra di Tabby dal suo lato.
    static func spazioApp(posizione: String) -> NSRect {
        var v = schermo.visibleFrame
        switch posizione {
        case "bottom": v.origin.y += Misure.altezza; v.size.height -= Misure.altezza
        case "left":   v.origin.x += Misure.larghezzaLato; v.size.width -= Misure.larghezzaLato
        case "right":  v.size.width -= Misure.larghezzaLato
        default:       v.size.height -= Misure.altezza
        }
        return v
    }

    // MARK: - Azioni

    /// Porta davanti un'app (P-1/P-2): la mostra se nascosta, la mette in primo piano, alza la
    /// sua finestra principale; se non ha finestre fa come il Dock (ne riapre una).
    static func portaDavanti(_ app: NSRunningApplication) {
        if app.isHidden { app.unhide() }
        let e = elemento(app.processIdentifier)
        let ws = finestre(app.processIdentifier).filter { èScheda($0, appNascosta: false) }
        if let w = ws.first(where: { (attributo($0, kAXMainAttribute) as Bool?) == true }) ?? ws.first {
            if (attributo(w, kAXMinimizedAttribute) as Bool?) == true {
                AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            AXUIElementPerformAction(w, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue)
        }
        AXUIElementSetAttributeValue(e, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        app.activate()
        if ws.isEmpty, let url = app.bundleURL {
            let c = NSWorkspace.OpenConfiguration(); c.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: c)
        }
    }

    /// Una scheda alla volta (U-1): nasconde tutte le altre app vere.
    static func nascondiAltre(tranne bid: String) {
        let ign = ignorate()
        for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular {
            guard let b = a.bundleIdentifier, b != bid, !ign.contains(b), !a.isHidden else { continue }
            a.hide()
        }
    }

    /// Adatta (U-3): la finestra in primo piano dell'app prende esattamente lo spazio delle
    /// app. Se la misura è già giusta (±1 punto) non chiede niente (ogni richiesta costa).
    static func adatta(_ app: NSRunningApplication, posizione: String) {
        let e = elemento(app.processIdentifier)
        guard let w: AXUIElement = attributo(e, kAXFocusedWindowAttribute) ?? attributo(e, kAXMainWindowAttribute),
              (attributo(w, kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole,
              (attributo(w, "AXFullScreen") as Bool?) != true else { return }
        let r = spazioApp(posizione: posizione)
        let altezzaPrincipale = NSScreen.screens.first?.frame.height ?? r.maxY
        var pos = CGPoint(x: r.minX, y: altezzaPrincipale - r.maxY)    // l'Accessibilità conta dall'alto
        var dim = CGSize(width: r.width, height: r.height)
        if let pv: AXValue = attributo(w, kAXPositionAttribute), let dv: AXValue = attributo(w, kAXSizeAttribute) {
            var p = CGPoint.zero, d = CGSize.zero
            AXValueGetValue(pv, .cgPoint, &p); AXValueGetValue(dv, .cgSize, &d)
            if abs(p.x - pos.x) <= 1, abs(p.y - pos.y) <= 1, abs(d.width - dim.width) <= 1, abs(d.height - dim.height) <= 1 { return }
        }
        let p = AXValueCreate(.cgPoint, &pos)!, d = AXValueCreate(.cgSize, &dim)!
        AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, p)
        AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, d)
        AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, p)   // alcune app lo vogliono dopo
    }

    /// Chiude la finestra principale dell'app (C-1), premendo il suo pallino rosso.
    static func chiudiFinestra(_ app: NSRunningApplication) {
        let e = elemento(app.processIdentifier)
        guard let w: AXUIElement = attributo(e, kAXFocusedWindowAttribute) ?? attributo(e, kAXMainWindowAttribute),
              let b: AXUIElement = attributo(w, kAXCloseButtonAttribute) else { return }
        AXUIElementPerformAction(b, kAXPressAction as CFString)
    }

    static func titoloFinestra(_ app: NSRunningApplication) -> String? {
        let e = elemento(app.processIdentifier)
        guard let w: AXUIElement = attributo(e, kAXFocusedWindowAttribute) ?? attributo(e, kAXMainWindowAttribute) else { return nil }
        return attributo(w, kAXTitleAttribute)
    }

    /// Apre Spotlight (la scheda «+» e «Nuova app»), come premere ⌘Spazio.
    static func apriSpotlight() {
        let src = CGEventSource(stateID: .hidSystemState)
        for giù in [true, false] {
            let ev = CGEvent(keyboardEventSource: src, virtualKey: 49, keyDown: giù)
            ev?.flags = .maskCommand
            ev?.post(tap: .cghidEventTap)
        }
    }

    /// La Scrivania (W-1): nasconde tutte le app tranne il Finder, che resta davanti.
    static func scrivania() {
        nascondiAltre(tranne: "com.apple.finder")
        if let f = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            for w in finestre(f.processIdentifier) where èScheda(w, appNascosta: false) {
                AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            }
            f.activate()
        }
    }
}
