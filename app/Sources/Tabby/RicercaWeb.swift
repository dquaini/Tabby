import AppKit
import Carbon.HIToolbox
import TabbyCore

/// La ricerca web della barra di Tabby (deciso con Daniele il 10/11/2026). Non sostituisce
/// Spotlight: aggiunge quello che lui non sa, le tue schede. Un sito già aperto → ci vai; uno
/// nuovo → una **finestra sua, con una scheda sola**, che diventa subito una scheda di Tabby (e
/// nasce nella cartella in cui sei); «Cerca sul web» → DuckDuckGo in una finestra nuova.
/// ⌘↵: come scheda nella finestra del browser che hai davanti. Il browser è quello di macOS.
extension Controllore {
    /// Le righe «Sul web» per il testo scritto (un sito già aperto non si ripropone: c'è la sua scheda).
    func righeWeb(_ testo: String) -> [(Trovato, AzioneRicerca)] {
        proposteWeb(testo).compactMap { p -> (Trovato, AzioneRicerca)? in
            switch p {
            case let .sito(nome, indirizzo, d):
                if dovèGiàAperto(d, tranne: 0, in: tutte) != nil { return nil }
                if stato.loghi[d] == nil, let l = loghi.logo(d) { stato.loghi[d] = l }
                return (Trovato(id: "w:" + d, gruppo: .web, titolo: "Apri \(nome)", sotto: "Una finestra con questa scheda · ⌘↵ qui"),
                        .web(indirizzo, dominio: d))
            case let .ricerca(t, indirizzo):
                return (Trovato(id: "w:?", gruppo: .web, titolo: "Cerca «\(t)» sul web", sotto: "DuckDuckGo"), .web(indirizzo, dominio: nil))
            }
        }
    }

    func apriSulWeb(_ indirizzo: String, dominio d: String?, nuovaFinestra: Bool) {
        guard let url = URL(string: indirizzo) else { diario("ricerca web: indirizzo non valido «\(indirizzo)»"); return }
        if let d, let già = dovèGiàAperto(d, tranne: 0, in: tutte) {
            diario("ricerca web: \(d) è già aperto in «\(già.nome)», ci vado"); vai(già); return
        }
        guard let bid = browserDelWeb, let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else { NSWorkspace.shared.open(url); return }
        if let d, let id = stato.cartellaAperta { nellaCartella = (d, id, Date()) }   // nasce nella cartella in cui sei
        diario("ricerca web: \(d ?? "ricerca") in \(nuovaFinestra ? "una finestra nuova" : "una scheda") di \(bid)")
        let conf = NSWorkspace.OpenConfiguration(); conf.activates = true
        guard nuovaFinestra else { NSWorkspace.shared.open([url], withApplicationAt: app, configuration: conf); return }
        switch browserNoti[bid]?.tipo {
        case .chrome?:
            // Chrome, Brave, Edge capiscono «--new-window»: più veloce di AppleScript (prima un attimo di troppo)
            let c = NSWorkspace.OpenConfiguration()
            c.activates = true; c.createsNewApplicationInstance = true; c.arguments = ["--new-window", indirizzo]
            NSWorkspace.shared.openApplication(at: app, configuration: c) { _, errore in
                if let errore { DispatchQueue.main.async { diario("ricerca web: \(bid) non ha aperto la finestra (\(errore.localizedDescription))") } }
            }
        case .safari?:
            let u = indirizzo.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "%22")
            esegui("tell application \"Safari\"\nmake new document with properties {URL:\"\(u)\"}\nactivate\nend tell")
        default:
            apriInFinestraDDG(url, app: app, bid: bid)
        }
    }

    /// DuckDuckGo (e i browser senza AppleScript): il sito si apre come scheda (davanti, nella finestra
    /// davanti), poi Tabby preme «Finestra → Sposta scheda in una nuova finestra»: una finestra con una
    /// scheda sola. Si sposta **solo** quando la scheda in vista è proprio quel sito e le schede sono
    /// una in più di prima (mai una tua scheda). Prima: ⌘N e l'indirizzo, che lasciava una scheda vuota.
    private func apriInFinestraDDG(_ url: URL, app: URL, bid: String) {
        let conf = NSWorkspace.OpenConfiguration(); conf.activates = true
        let già = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first
        let finestra = già.flatMap { Sistema.finestraAttiva($0.processIdentifier) }
        let prima = finestra.flatMap { Browser.esplora($0).schede }
        let id = finestra.flatMap(Sistema.numero)
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: conf)
        guard let pid = già?.processIdentifier, let id, let prima else {
            diario("ricerca web: \(bid) non aveva finestre, il sito ha già una finestra sua"); return
        }
        let voluto = dominio(url.absoluteString)
        Self.quando({
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, let w = Sistema.finestraAttiva(pid),
                  Sistema.numero(w) == id else { return false }
            let r = Browser.esplora(w)
            return r.schede == prima + 1 && r.sito.flatMap(dominio) == voluto
        }, entro: 4) { pronta in
            guard pronta else { diario("ricerca web: in \(bid) la scheda nuova non è arrivata: resta come scheda"); return }
            if prima == 0 { return }                                  // era una finestra vuota: è già sua
            if Self.premiNelMenu(pid, ["sposta scheda in una nuova finestra", "move tab to new window"]) {
                diario("ricerca web: scheda spostata in una finestra nuova")
            } else { diario("ricerca web: voce «Sposta scheda in una nuova finestra» non trovata") }
        }
    }

    /// Preme una voce del menu di un'app (per titolo, senza maiuscole): vero se l'ha trovata.
    private static func premiNelMenu(_ pid: pid_t, _ titoli: [String]) -> Bool {
        guard let barra: AXUIElement = Sistema.attributo(Sistema.elemento(pid), kAXMenuBarAttribute) else { return false }
        for m in (Sistema.attributo(barra, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
            for sotto in (Sistema.attributo(m, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
                for v in (Sistema.attributo(sotto, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
                    guard let t: String = Sistema.attributo(v, kAXTitleAttribute), titoli.contains(t.lowercased()),
                          (Sistema.attributo(v, kAXEnabledAttribute) as Bool?) != false else { continue }
                    return AXUIElementPerformAction(v, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }

    /// Il browser per i siti e le ricerche: quello scelto nella barra di ricerca, se no quello di macOS.
    var browserDelWeb: String? {
        if let b = imp.valore("webBrowser") as? String, NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) != nil { return b }
        return NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!).flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    /// I browser installati, per la scelta nella barra di ricerca.
    var browserInstallati: [(bid: String, nome: String)] {
        let noti = ["com.duckduckgo.macos.browser", "com.apple.Safari", "com.google.Chrome", "com.brave.Browser",
                    "com.microsoft.edgemac", "company.thebrowser.Browser", "org.mozilla.firefox"]
        return noti.compactMap { b in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: b).map { (b, FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "")) }
        }
    }

    /// Aspetta (ogni 0,1 s, al massimo `entro` secondi) che `condizione` sia vera.
    private static func quando(_ condizione: @escaping @MainActor () -> Bool, entro: Double, poi: @escaping @MainActor (Bool) -> Void) {
        let fine = Date().addingTimeInterval(entro)
        func prova() {
            if condizione() { poi(true); return }
            if Date() > fine { poi(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { prova() }
        }
        prova()
    }

    /// Una finestra nuova aperta dalla ricerca mentre eri in una cartella: entra nella cartella.
    func mettiNellaCartella(_ schede: [Scheda]) {
        guard let (d, id, quando) = nellaCartella else { return }
        if Date().timeIntervalSince(quando) > 10 { nellaCartella = nil; return }
        guard let s = schede.first(where: { $0.sito == d }), let i = cartelle.firstIndex(where: { $0.id == id }) else { return }
        nellaCartella = nil
        if !cartelle[i].voci.contains(where: { $0.sito == d }) {
            cartelle[i].voci.append(vocePer(s)); salvaCartelle()
            diario("«\(s.nome)» aggiunta alla cartella «\(cartelle[i].nome)»")
            ricostruisciPresto()
        }
    }

    /// AppleScript per il browser; se fallisce (es. manca il permesso Automazione) lo dice il diario.
    private func esegui(_ script: String) {
        let p = Process(), errore = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardError = errore
        p.terminationHandler = { q in
            let e = String(data: errore.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if q.terminationStatus != 0 { DispatchQueue.main.async { diario("ricerca web: il browser non ha aperto la finestra (\(e.prefix(160)))") } }
        }
        do { try p.run() } catch { diario("ricerca web: osascript non parte: \(error)") }
    }
}
