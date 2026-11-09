import AppKit
import ApplicationServices
import Carbon.HIToolbox
import TabbyCore
import WebKit

/// I Lampi (SPECIFICA 14): piccole app che si aprono in alto a destra, sopra quello che fai,
/// con ⌃⌥ + lettera; restano finché non premi Esc (o di nuovo la scorciatoia). Il Memo è di
/// Tabby; le altre sono app vere, «veloci» solo se aperte da Tabby.
@MainActor
final class GestoreLampi {
    unowned let c: Controllore
    let memo = Memo()
    /// Le app aperte come Lampo (si ricordano anche dopo un riavvio, `floatMode`).
    private(set) var veloci: Set<String> = Set((Impostazioni.shared.valore("floatMode") as? [String: Any] ?? [:]).keys)
    var lampi: [Lampo] = (Impostazioni.shared.valore("quick") as? [[String: Any]])?.compactMap(Lampo.init) ?? lampiDiSerie

    init(_ c: Controllore) {
        self.c = c
        memo.chiuso = { [weak self] in self?.disponi(); self?.c.ricostruisciPresto() }
    }

    private func salvaVeloci() {
        c.imp.imposta("floatMode", Dictionary(uniqueKeysWithValues: veloci.map { ($0, true) }))
        Sistema.veloci = veloci
    }
    func salvaLampi() { c.imp.imposta("quick", lampi.map(\.dizionario)); c.registraLampi() }

    func èVeloce(_ bid: String) -> Bool { veloci.contains(bid) }
    var aperti: [Lampo] {
        lampi.filter { l in
            if l.memo { return memo.aperto }
            guard let b = l.bid, veloci.contains(b) else { return false }
            return NSRunningApplication.runningApplications(withBundleIdentifier: b).first.map { !$0.isHidden } ?? false
        }
    }

    // MARK: - Aprire e chiudere

    /// ⌃⌥ + lettera, o un clic nel menu ⚡︎: apre il Lampo; se è già davanti, lo chiude.
    func premi(_ l: Lampo) {
        if l.barraMenu { premiNellaBarraDeiMenu(l); return }
        if l.memo { memo.aperto && NSApp.isActive ? memo.chiudi() : apriMemo(); return }
        guard let b = l.bid else { return }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: b).first, veloci.contains(b), !app.isHidden {
            if app.isActive { chiudi(b); return }
            app.activate(); return                                   // in vista ma senza tastiera: gliela dà
        }
        veloci.insert(b); salvaVeloci()
        c.ricostruisciPresto()
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: b).first {
            app.unhide(); app.activate()
        } else if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
            NSWorkspace.shared.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration())
        }
        for t in [0.15, 0.4, 0.9, 1.7] {                              // le app ci mettono un attimo a fare la finestra
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in self?.disponi() }
        }
    }

    /// Esc su un Lampo (o di nuovo la scorciatoia): si nasconde e torna un'app normale.
    func chiudi(_ b: String) {
        veloci.remove(b); salvaVeloci()
        NSRunningApplication.runningApplications(withBundleIdentifier: b).first?.hide()
        disponi()
        c.ricostruisciPresto()
        c.tornaAllaScheda()
    }

    private func apriMemo() {
        memo.apri(in: posto(per: lampi.first(where: \.memo) ?? lampiDiSerie[0]))
        disponi()
    }

    // MARK: - In fila (Q-1b)

    /// Dove va un Lampo nuovo: il primo posto libero in fila.
    private func posto(per l: Lampo) -> CGRect {
        let spazio = Sistema.dallAlto(Sistema.spazioApp(posizione: c.stato.posizione))
        let altri = aperti.filter { $0.id != l.id }
        let f = inFila(altri.map { CGSize(width: $0.larghezza, height: $0.altezza) } + [CGSize(width: l.larghezza, height: l.altezza)], spazio: spazio)
        return f.last.flatMap { $0 } ?? CGRect(x: spazio.maxX - l.larghezza - 12, y: spazio.minY + 12, width: l.larghezza, height: l.altezza)
    }

    /// Rimette in fila i Lampi aperti (anche dopo un cambio di posizione di Tabby).
    func disponi() {
        let spazio = Sistema.dallAlto(Sistema.spazioApp(posizione: c.stato.posizione))
        let ap = aperti
        let posti = inFila(ap.map { CGSize(width: $0.larghezza, height: $0.altezza) }, spazio: spazio)
        for (l, p) in zip(ap, posti) {
            guard let p else { continue }
            if l.memo { memo.sposta(in: p); continue }
            guard let b = l.bid, let app = NSRunningApplication.runningApplications(withBundleIdentifier: b).first,
                  let w = Sistema.finestraAttiva(app.processIdentifier) else { continue }
            Sistema.adattaFinestra(w, a: Sistema.dalBasso(p))
        }
        aggiornaCoperti()
    }

    // MARK: - Il ripiano dei Lampi coperti (Q-1)

    /// macOS non lascia tenere sopra la finestra di un'altra app: quando un Lampo è coperto da una
    /// finestra che non è un Lampo, il tasto ⚡︎ si allarga con la sua icona.
    func aggiornaCoperti() {
        let davanti = NSWorkspace.shared.frontmostApplication
        var coperti: [String] = []
        if let d = davanti, let db = d.bundleIdentifier, !veloci.contains(db), db != Sistema.mioBid,
           let fw = Sistema.finestraAttiva(d.processIdentifier), let fr = Sistema.cornice(fw) {
            for l in aperti where !l.memo {
                guard let b = l.bid, let a = NSRunningApplication.runningApplications(withBundleIdentifier: b).first,
                      let w = Sistema.finestraAttiva(a.processIdentifier), let r = Sistema.cornice(w), r.intersects(fr) else { continue }
                coperti.append(b)
            }
        }
        if coperti != c.stato.lampiCoperti { withAnimationMolla { c.stato.lampiCoperti = coperti } }
    }

    func riporta(_ bids: [String]) {
        for b in bids { NSRunningApplication.runningApplications(withBundleIdentifier: b).first?.activate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.aggiornaCoperti() }
    }

    // MARK: - Le azioni nella barra dei menu (X-1)

    /// Claude · chat rapida, Notion · cerca: si preme l'icona dell'app nella barra dei menu (e la
    /// voce del suo menu, se c'è). Se l'app non è aperta si apre dietro e si riprova una volta.
    func premiNellaBarraDeiMenu(_ l: Lampo, riprova: Bool = true) {
        guard let b = l.bid else { return }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: b).first else {
            if riprova, let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
                let conf = NSWorkspace.OpenConfiguration(); conf.activates = false
                NSWorkspace.shared.openApplication(at: u, configuration: conf)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.premiNellaBarraDeiMenu(l, riprova: false) }
            }
            return
        }
        let e = Sistema.elemento(app.processIdentifier)
        guard let barra: AXUIElement = Sistema.attributo(e, "AXExtrasMenuBar"),
              let icona = (Sistema.attributo(barra, kAXChildrenAttribute) as [AXUIElement]?)?.first else {
            diario("\(l.nome): icona nella barra dei menu non trovata"); app.activate(); return
        }
        AXUIElementPerformAction(icona, kAXPressAction as CFString)
        guard let voce = l.voceMenu else { return }
        // la voce del menu dell'icona, cercata per 1,5 s
        func cerca(_ resto: Int) {
            if let menu = (Sistema.attributo(icona, kAXChildrenAttribute) as [AXUIElement]?)?.first,
               let v = ((Sistema.attributo(menu, kAXChildrenAttribute) as [AXUIElement]?) ?? []).first(where: { (Sistema.attributo($0, kAXTitleAttribute) as String?) == voce }) {
                AXUIElementPerformAction(v, kAXPressAction as CFString); return
            }
            if resto > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { cerca(resto - 1) } }
            else { diario("\(l.nome): voce «\(voce)» non trovata") }
        }
        cerca(15)
    }
}

/// Il Memo (Q-2): la pagina `memo.html` di sempre (elenchi, cose da fare, sezioni apribili) in
/// una finestrella di Tabby. Il testo è un file vero: ~/Documents/Tabby Memo.txt.
@MainActor
final class Memo: NSObject, WKScriptMessageHandler {
    static let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Tabby Memo.txt")
    var chiuso: (() -> Void)?
    private var finestra: NSPanel?
    private var web: WKWebView?
    private var dataLetta: Date?
    private var appPrima: NSRunningApplication?
    var aperto: Bool { finestra?.isVisible == true }

    private func prepara() -> NSPanel {
        if let f = finestra { return f }
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "tabbymemo")
        let w = WKWebView(frame: .zero, configuration: cfg)
        if let u = Bundle.main.url(forResource: "memo", withExtension: "html") { w.loadFileURL(u, allowingReadAccessTo: u) }
        let p = PannelloMemo(contentRect: NSRect(x: 0, y: 0, width: 340, height: 280), styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = NSColor(red: 0.106, green: 0.114, blue: 0.133, alpha: 1)
        // il testo parte sotto i pallini della finestra (non ci finisce sotto)
        let fondo = NSView()
        w.translatesAutoresizingMaskIntoConstraints = false
        fondo.addSubview(w)
        NSLayoutConstraint.activate([w.topAnchor.constraint(equalTo: fondo.topAnchor, constant: 28),
                                     w.bottomAnchor.constraint(equalTo: fondo.bottomAnchor),
                                     w.leadingAnchor.constraint(equalTo: fondo.leadingAnchor),
                                     w.trailingAnchor.constraint(equalTo: fondo.trailingAnchor)])
        p.contentView = fondo
        p.hidesOnDeactivate = false
        finestra = p; web = w
        return p
    }

    func apri(in r: CGRect) {
        appPrima = NSWorkspace.shared.frontmostApplication
        let p = prepara()
        p.setFrame(Sistema.dalBasso(r), display: true)
        carica()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate()
        for t in [0.08, 0.25, 0.6] {                                  // la tastiera deve arrivare davvero
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                self?.web?.evaluateJavaScript("typeof focusLast === 'function' && focusLast()")
            }
        }
    }

    func sposta(in r: CGRect) { finestra?.setFrame(Sistema.dalBasso(r), display: true) }

    /// Il testo si ricarica dal file solo se è cambiato (es. modificato con TextEdit).
    private func carica() {
        let data = (try? FileManager.default.attributesOfItem(atPath: Memo.file.path))?[.modificationDate] as? Date
        guard data != dataLetta || dataLetta == nil else { return }
        dataLetta = data
        let testo = (try? String(contentsOf: Memo.file, encoding: .utf8)) ?? ""
        let pieghe = Impostazioni.shared.valore("memoFold") as? [String] ?? []
        let js = "setDoc(\(json(testo)), \(json(pieghe)))"
        if web?.isLoading == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.web?.evaluateJavaScript(js) }
        } else { web?.evaluateJavaScript(js) }
    }

    func chiudi() {
        web?.evaluateJavaScript("typeof serialize === 'function' && send({text: serialize()})")
        finestra?.orderOut(nil)
        if let a = appPrima, a.bundleIdentifier != Sistema.mioBid { a.activate() }
        chiuso?()
    }

    nonisolated func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let d = m.body as? [String: Any] else { return }
        let testo = d["text"] as? String, pieghe = d["fold"] as? [String], chiudi = d["close"] as? Bool == true
        MainActor.assumeIsolated {
            if let testo {
                do {
                    try testo.write(to: Memo.file, atomically: true, encoding: .utf8)
                    dataLetta = (try? FileManager.default.attributesOfItem(atPath: Memo.file.path))?[.modificationDate] as? Date
                } catch { diario("Memo: impossibile salvare in \(Memo.file.path)") }
            }
            if let pieghe { Impostazioni.shared.imposta("memoFold", pieghe) }
            if chiudi { self.chiudi() }
        }
    }

    private func json(_ v: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: [v]), var s = String(data: d, encoding: .utf8) else { return "''" }
        s.removeFirst(); s.removeLast(); return s
    }
}

/// La finestrella del Memo prende la tastiera.
final class PannelloMemo: NSPanel {
    override var canBecomeKey: Bool { true }
}
