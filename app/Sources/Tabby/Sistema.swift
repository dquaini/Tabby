import AppKit
import ApplicationServices
import TabbyCore

/// Chiede a macOS il numero di una finestra (funzione interna di macOS, usata da tutte le app
/// che gestiscono finestre, Hammerspoon compreso).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ e: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Tutto quello che Tabby chiede a macOS sulle app e le finestre, tramite l'Accessibilità.
/// Ogni domanda a un'app ha un tempo massimo di 0,25 s: un'app impegnata (es. Chrome in una
/// videochiamata) non deve mai bloccare Tabby.
@MainActor
enum Sistema {
    static let mioBid = Bundle.main.bundleIdentifier ?? "com.dquaini.Tabby"
    /// Le app aperte come Lampo in questo momento (le tiene aggiornate GestoreLampi).
    static var veloci = Set<String>()
    /// App che non sono schede: Tabby, Hammerspoon e i Lampi aperti come Lampo (aperte in un
    /// altro modo, Calcolatrice & co. sono app normali, Q-1).
    static func ignorate() -> Set<String> { veloci.union([mioBid, "org.hammerspoon.Hammerspoon"]) }

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

    /// Il numero della finestra (lo stesso che usa macOS): serve a riconoscerla nel tempo.
    static func numero(_ w: AXUIElement) -> UInt32? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(w, &id) == .success && id != 0 ? id : nil
    }

    /// Le finestre viste almeno una volta come "standard": macOS 26 chiama «dialogo» le
    /// finestre ridotte o di app nascoste, e senza questa memoria sparirebbero dalla barra.
    static var standardViste = Set<UInt32>()

    /// Una finestra che conta come scheda: standard, ridotta, già vista standard, oppure
    /// (macOS 26) una finestra di un'app nascosta che macOS chiama «dialogo». Mai a schermo
    /// intero (Z-1).
    static func èScheda(_ w: AXUIElement, appNascosta: Bool = false) -> Bool {
        if (attributo(w, "AXFullScreen") as Bool?) == true { return false }
        let sub: String? = attributo(w, kAXSubroleAttribute)
        let n = numero(w)
        if sub == kAXStandardWindowSubrole { if let n { standardViste.insert(n) }; return true }
        if let n, standardViste.contains(n) { return true }
        if appNascosta && sub == kAXDialogSubrole { return true }
        return (attributo(w, kAXMinimizedAttribute) as Bool?) == true && sub != kAXFloatingWindowSubrole
    }

    /// Legge un'app: le sue finestre-scheda (numero, titolo, ridotta) e gli elementi per
    /// agire su di esse.
    static func leggi(_ app: NSRunningApplication) -> (InfoApp, [UInt32: AXUIElement]) {
        var info: [InfoFinestra] = [], el: [UInt32: AXUIElement] = [:]
        for w in finestre(app.processIdentifier) where èScheda(w, appNascosta: app.isHidden) {
            guard let n = numero(w) else { continue }
            info.append(InfoFinestra(id: n, titolo: attributo(w, kAXTitleAttribute) ?? "",
                                     ridotta: (attributo(w, kAXMinimizedAttribute) as Bool?) == true))
            el[n] = w
        }
        let bid = app.bundleIdentifier ?? ""
        return (InfoApp(bid: bid, nome: app.localizedName ?? bid, pid: app.processIdentifier, finestre: info), el)
    }

    /// Le app "vere" (nel Dock) che possono essere schede (S-1).
    static func appVere() -> [NSRunningApplication] {
        let ign = ignorate()
        var viste = Set<String>()
        return NSWorkspace.shared.runningApplications.filter { a in
            guard a.activationPolicy == .regular, let b = a.bundleIdentifier, !ign.contains(b), !a.isTerminated else { return false }
            return viste.insert(b).inserted
        }
    }

    /// Posizione e misura di una finestra, in coordinate dall'alto (come l'Accessibilità).
    static func cornice(_ w: AXUIElement) -> CGRect? {
        guard let pv: AXValue = attributo(w, kAXPositionAttribute), let dv: AXValue = attributo(w, kAXSizeAttribute) else { return nil }
        var p = CGPoint.zero, d = CGSize.zero
        AXValueGetValue(pv, .cgPoint, &p); AXValueGetValue(dv, .cgSize, &d)
        return CGRect(origin: p, size: d)
    }

    /// La finestra che ha l'attenzione in un'app.
    static func finestraAttiva(_ pid: pid_t) -> AXUIElement? {
        let e = elemento(pid)
        return attributo(e, kAXFocusedWindowAttribute) ?? attributo(e, kAXMainWindowAttribute)
    }

    // MARK: - Lo spazio delle app

    /// Lo schermo principale (Tabby usa sempre quello).
    static var schermo: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    /// Dove sta la barra, secondo la posizione scelta.
    // MARK: - Il notch (A-2)

    /// Dove sta la tacca della fotocamera (in x, coordinate dello schermo), se lo schermo ce l'ha:
    /// macOS dice quali parti in alto restano libere a sinistra e a destra.
    static var notch: (da: CGFloat, a: CGFloat)? {
        guard let s = NSScreen.screens.first, s.safeAreaInsets.top > 0,
              let sx = s.auxiliaryTopLeftArea, let dx = s.auxiliaryTopRightArea else { return nil }
        return (sx.maxX, dx.minX)
    }

    /// La fascia del notch: Tabby in alto sale nella striscia accanto alla tacca. Automatica se
    /// c'è il notch **e** la barra dei menu si nasconde da sola; oppure accesa o spenta a mano.
    static var fasciaNotch: Bool {
        switch Impostazioni.shared.valore("notchBand") as? String {
        case "on": return true
        case "off": return false
        default: return notch != nil && barraMenuNascosta
        }
    }

    /// La barra dei menu si nasconde da sola? Si rilegge dalle preferenze al massimo ogni 30 s.
    private static var letturaBarraMenu: (quando: Date, nascosta: Bool) = (.distantPast, false)
    static func rileggiBarraMenu() { letturaBarraMenu.quando = .distantPast }
    static var barraMenuNascosta: Bool {
        if Date().timeIntervalSince(letturaBarraMenu.quando) > 30 {
            let n = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["_HIHideMenuBar"] as? Bool ?? false
            letturaBarraMenu = (Date(), n)
        }
        return letturaBarraMenu.nascosta
    }

    /// L'altezza della barra dei menu di Apple (più alta accanto al notch).
    static var altezzaBarraMenu: CGFloat { max(NSStatusBar.system.thickness, schermo.safeAreaInsets.top, 30) + 4 }   // 30 su macOS 26

    static func cornice(posizione: String) -> NSRect {
        let v = schermo.visibleFrame
        if posizione == "top" && fasciaNotch {                  // in cima allo schermo, accanto alla tacca
            let f = schermo.frame
            return NSRect(x: f.minX, y: f.maxY - Misure.altezza, width: f.width, height: Misure.altezza)
        }
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
        default:
            if fasciaNotch { v.size.height = schermo.frame.maxY - Misure.altezza - v.minY }
            else { v.size.height -= Misure.altezza }
        }
        return v
    }

    // MARK: - Azioni

    /// Porta davanti una scheda (P-1/P-2): mostra l'app se nascosta, riapre la finestra se
    /// ridotta, la alza e le dà l'attenzione; senza finestre fa come il Dock (ne riapre una).
    static func portaDavanti(_ app: NSRunningApplication, finestra: AXUIElement?) {
        let nascosta = app.isHidden
        if nascosta { app.unhide() }
        let e = elemento(app.processIdentifier)
        let tutte = finestre(app.processIdentifier).filter { èScheda($0, appNascosta: nascosta) }
        let w = finestra ?? tutte.first { (attributo($0, kAXMinimizedAttribute) as Bool?) != true } ?? tutte.first
        if let w {
            if (attributo(w, kAXMinimizedAttribute) as Bool?) == true {
                AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            AXUIElementPerformAction(w, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(e, kAXFocusedWindowAttribute as CFString, w)
        }
        AXUIElementSetAttributeValue(e, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        if NSApp.isActive { NSApp.yieldActivation(to: app) }          // da un foglio di Tabby: cede il primo piano
        app.activate()
        if w == nil, let url = app.bundleURL {
            let c = NSWorkspace.OpenConfiguration(); c.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: c)
        }
    }

    /// X-5: la finestra davanti dell'app è un pannello? Piccola (meno di metà larghezza e meno del
    /// 60% dell'altezza dello spazio delle app) e non una finestra normale (fluttuante, dialogo o
    /// sconosciuta), non ridotta, non a schermo intero. Restituisce il suo ruolo, per il diario.
    static func pannello(_ app: NSRunningApplication, spazio: CGRect) -> String? {
        guard let w = finestraAttiva(app.processIdentifier), let r = cornice(w),
              r.width < spazio.width * 0.5, r.height < spazio.height * 0.6 else { return nil }
        let sub: String = attributo(w, kAXSubroleAttribute) ?? "sconosciuto"
        guard sub != kAXStandardWindowSubrole,
              (attributo(w, kAXMinimizedAttribute) as Bool?) != true,
              (attributo(w, "AXFullScreen") as Bool?) != true else { return nil }
        let pannelli: Set<String> = [kAXFloatingWindowSubrole, kAXSystemFloatingWindowSubrole, kAXDialogSubrole, kAXSystemDialogSubrole, "sconosciuto", kAXUnknownSubrole]
        return pannelli.contains(sub) ? "\(sub) \(Int(r.width))×\(Int(r.height))" : nil
    }

    static func riduci(_ w: AXUIElement) {
        AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    /// Una scheda alla volta (U-1): nasconde tutte le altre app vere.
    static func nascondiAltre(tranne bid: String) { nascondiAltre(tranne: [bid]) }
    static func nascondiAltre(tranne bids: Set<String>) {
        let ign = ignorate()
        for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular {
            guard let b = a.bundleIdentifier, !bids.contains(b), !ign.contains(b), !a.isHidden else { continue }
            // Z-4: un'app con una finestra a schermo intero non si nasconde (ha la sua scrivania)
            if finestre(a.processIdentifier).contains(where: { (attributo($0, "AXFullScreen") as Bool?) == true }) { continue }
            a.hide()
        }
    }

    /// Adatta (U-3): **tutte** le finestre dell'app (non ridotte) prendono esattamente lo
    /// spazio delle app, così quella davanti copre le altre. Le finestrelle (popup di accesso,
    /// miniature) restano come sono.
    static func adatta(_ app: NSRunningApplication, posizione: String, tranne: Set<UInt32> = []) {
        let r = spazioApp(posizione: posizione)
        for w in finestre(app.processIdentifier) {
            if let n = numero(w), tranne.contains(n) { continue }            // nelle viste divise: hanno la loro zona
            guard (attributo(w, kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole,
                  (attributo(w, kAXMinimizedAttribute) as Bool?) != true,
                  (attributo(w, "AXFullScreen") as Bool?) != true,
                  let c = cornice(w), c.width >= r.width * 0.6 || browserNoti[app.bundleIdentifier ?? ""] == nil else { continue }
            adattaFinestra(w, a: r)
        }
    }

    /// Se la misura è già giusta (±1 punto) non chiede niente (ogni richiesta costa).
    static func adattaFinestra(_ w: AXUIElement, a r: CGRect) {
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

    /// Da un rettangolo in coordinate dall'alto (Accessibilità) a quelle di macOS (dal basso).
    static func dalBasso(_ r: CGRect) -> CGRect {
        let h = NSScreen.screens.first?.frame.height ?? r.maxY
        return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }
    static func dallAlto(_ r: CGRect) -> CGRect { dalBasso(r) }      // è la stessa operazione, all'indietro

    /// Chiude una finestra (C-1, C-2) premendo il suo pallino rosso.
    static func chiudi(_ w: AXUIElement) {
        guard let b: AXUIElement = attributo(w, kAXCloseButtonAttribute) else { return }
        AXUIElementPerformAction(b, kAXPressAction as CFString)
    }

    static func titolo(_ w: AXUIElement) -> String? { attributo(w, kAXTitleAttribute) }

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
            for w in finestre(f.processIdentifier) where èScheda(w) {
                AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            }
            f.activate()
        }
    }
}
