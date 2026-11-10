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
        let u = indirizzo.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "%22")
        switch browserNoti[bid]?.tipo {
        case .chrome?:
            let n = browserNoti[bid]!.nomeAS
            esegui("tell application \"\(n)\"\nmake new window\nset URL of active tab of front window to \"\(u)\"\nactivate\nend tell")
        case .safari?:
            esegui("tell application \"Safari\"\nmake new document with properties {URL:\"\(u)\"}\nactivate\nend tell")
        default:
            // DuckDuckGo (e i browser sconosciuti) non accettano comandi: come faresti tu. Si aspetta che
            // sia davanti, ⌘N, si aspetta che la finestra nuova ci sia davvero, poi ⌘L e l'indirizzo
            // incollato (gli appunti tornano com'erano). Prima si scriveva troppo presto e non arrivava.
            NSWorkspace.shared.openApplication(at: app, configuration: conf)
            Self.quando({ NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bid }, entro: 2) { pronto in
                guard pronto, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
                    NSWorkspace.shared.open([url], withApplicationAt: app, configuration: conf); return
                }
                let prima = Set(Sistema.finestre(pid).compactMap(Sistema.numero))
                Self.premi(kVK_ANSI_N, comando: true)
                Self.quando({ Sistema.finestraAttiva(pid).flatMap(Sistema.numero).map { !prima.contains($0) } ?? false }, entro: 2.5) { nuova in
                    // solo nella finestra nuova del browser, mai in un'altra app
                    guard nuova, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bid else {
                        diario("ricerca web: la finestra nuova di \(bid) non è arrivata"); return
                    }
                    Self.incolla(indirizzo)
                }
            }
        }
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

    /// ⌘L, l'indirizzo incollato, Invio; poi gli appunti tornano com'erano.
    private static func incolla(_ testo: String) {
        let pb = NSPasteboard.general
        let vecchi = pb.pasteboardItems?.map { i in i.types.compactMap { t in i.data(forType: t).map { (t, $0) } } } ?? []
        pb.clearContents(); pb.setString(testo, forType: .string)
        premi(kVK_ANSI_L, comando: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            premi(kVK_ANSI_V, comando: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                premi(kVK_Return)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    pb.clearContents()
                    let items = vecchi.map { coppie -> NSPasteboardItem in
                        let i = NSPasteboardItem(); for (t, d) in coppie { i.setData(d, forType: t) }; return i
                    }
                    if !items.isEmpty { pb.writeObjects(items) }
                }
            }
        }
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

    private static func premi(_ tasto: Int, comando: Bool = false) {
        let src = CGEventSource(stateID: .hidSystemState)
        for giù in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(tasto), keyDown: giù)
            if comando { e?.flags = .maskCommand }
            e?.post(tap: .cghidEventTap)
        }
    }
}
