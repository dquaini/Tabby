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
        guard let url = URL(string: indirizzo) else { return }
        if let d, let già = dovèGiàAperto(d, tranne: 0, in: tutte) { vai(già); return }
        guard let app = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://")!),
              let bid = Bundle(url: app)?.bundleIdentifier else { NSWorkspace.shared.open(url); return }
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
            // DuckDuckGo (e i browser sconosciuti) non accettano comandi: ⌘N e l'indirizzo, come faresti tu
            NSWorkspace.shared.openApplication(at: app, configuration: conf)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bid else {
                    NSWorkspace.shared.open([url], withApplicationAt: app, configuration: conf); return
                }
                Self.premi(kVK_ANSI_N, comando: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    // si scrive solo se davanti c'è ancora il browser (mai in un'altra app)
                    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bid else { return }
                    Self.scrivi(indirizzo); Self.premi(kVK_Return)
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

    private func esegui(_ script: String) { esegui("/usr/bin/osascript", ["-e", script]) }

    private static func premi(_ tasto: Int, comando: Bool = false) {
        let src = CGEventSource(stateID: .hidSystemState)
        for giù in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(tasto), keyDown: giù)
            if comando { e?.flags = .maskCommand }
            e?.post(tap: .cghidEventTap)
        }
    }

    /// Scrive un testo (a pezzi di 20 caratteri, il massimo per un evento).
    private static func scrivi(_ testo: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        let u = Array(testo.utf16)
        for i in stride(from: 0, to: u.count, by: 20) {
            var pezzo = Array(u[i..<min(i + 20, u.count)])
            for giù in [true, false] {
                let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: giù)
                e?.keyboardSetUnicodeString(stringLength: pezzo.count, unicodeString: &pezzo)
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}
