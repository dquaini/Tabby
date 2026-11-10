import AppKit
@preconcurrency import ApplicationServices
import TabbyCore

/// Cosa c'è nelle finestre dei browser (SPECIFICA 3).
/// - Chrome, Brave, Edge, Safari: si chiede al browser con AppleScript, **in parallelo**
///   (un processo `osascript`): Tabby non resta mai ferma ad aspettare; usa l'ultima risposta
///   e, quando ne arriva una diversa, ricostruisce le schede.
/// - DuckDuckGo: si guarda nella finestra con l'Accessibilità, **senza leggere la pagina**:
///   solo l'indirizzo (di cui si tiene il sito) e quante schede ci sono.
@MainActor
final class Browser {
    var cambiato: (() -> Void)?

    // AppleScript
    private var risposte: [String: (testo: String, buona: Bool)] = [:]
    private var lavori: [String: (p: Process, quando: Date)] = [:]
    private var memoria: [String: [UInt32: Int]] = [:]        // finestra → numero del browser (B-3, passo 0)
    private var conosciute: [UInt32: FinestraBrowser] = [:]   // l'ultima descrizione di ogni finestra
    private var avvisato: [String: Bool] = [:]
    private var timer: Timer?

    // DuckDuckGo
    private struct Vista { var sito: String?; var schede: Int?; var titolo: String; var quando: Date }
    /// Ricordate anche dopo un riavvio di Tabby (solo sito, numero di schede e titolo): un
    /// DuckDuckGo nascosto non si lascia guardare dentro.
    private var inLettura = Set<UInt32>()
    private let coda = DispatchQueue(label: "tabby.duckduckgo", qos: .userInitiated)
    private var viste: [UInt32: Vista] = {
        var v: [UInt32: Vista] = [:]
        for (k, x) in Impostazioni.shared.valore("ddgViste") as? [String: [String: Any]] ?? [:] {
            guard let id = UInt32(k) else { continue }
            v[id] = Vista(sito: x["sito"] as? String, schede: x["schede"] as? Int, titolo: x["titolo"] as? String ?? "", quando: .distantPast)
        }
        return v
    }()

    private func salvaViste() {
        var d: [String: [String: Any]] = [:]
        for (id, x) in viste.prefix(60) { d[String(id)] = ["sito": x.sito ?? "", "schede": x.schede ?? 0, "titolo": x.titolo] }
        Impostazioni.shared.imposta("ddgViste", d)
    }

    init() {
        // Le domande ai browser: ogni 3 s se ne stai usando uno, ogni 15 s se sono dietro;
        // solo se c'è un browser con AppleScript aperto. Il timer ha margine (consumo).
        let t = Timer(timeInterval: 3, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.giro() } }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private var ultimoGiro: [String: Date] = [:]
    private func giro() {
        let davanti = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        for a in NSWorkspace.shared.runningApplications {
            guard let b = a.bundleIdentifier, let B = browserNoti[b], B.tipo != .accessibilita else { continue }
            let pausa: TimeInterval = b == davanti ? 3 : 15
            if Date().timeIntervalSince(ultimoGiro[b] ?? .distantPast) >= pausa - 0.5 { chiedi(b, B) }
        }
    }

    /// Fa partire una domanda al browser (se non ce n'è già una in corso da meno di 6 s).
    func chiedi(_ bid: String, _ B: BrowserNoto) {
        if let l = lavori[bid] {
            if Date().timeIntervalSince(l.quando) < 6 { return }
            l.p.terminate()                                        // senza risposta da 6 s: si lascia perdere
        }
        ultimoGiro[bid] = Date()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", scriptFinestre(B.nomeAS)]
        let fuori = Pipe(), errori = Pipe()
        p.standardOutput = fuori; p.standardError = errori
        do { try p.run(); lavori[bid] = (p, Date()) } catch { diario("\(B.breve): osascript non parte (\(error))"); return }
        // la risposta si legge **mentre arriva** (in sottofondo): con tante schede non sta tutta nel
        // tubo e, letta solo alla fine, osascript restava fermo ad aspettare fino ai 6 s
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let testo = String(data: fuori.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: errori.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            p.waitUntilExit()
            let ok = p.terminationStatus == 0
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.risposta(bid, B, ok: ok, testo: testo, errore: err, proc: p) } }
        }
    }

    private func risposta(_ bid: String, _ B: BrowserNoto, ok: Bool, testo: String, errore: String, proc: Process) {
        guard lavori[bid]?.p === proc else { return }               // risposta vecchia
        lavori[bid] = nil
        let prima = risposte[bid]
        // senza risposta (browser occupato, permesso tolto) si tiene l'ultima buona
        let nuova = ok ? (testo, true) : (prima?.testo ?? "", false)
        risposte[bid] = nuova
        if avvisato[bid] != ok {
            avvisato[bid] = ok
            if !ok && errore.contains("-1743") {
                diario("\(B.breve): manca il permesso, niente nomi e loghi dei siti. Impostazioni di Sistema → Privacy e sicurezza → Automazione → Tabby → \(B.nomeAS)")
            } else if !ok { diario("\(B.breve) non ha risposto in tempo: uso l'ultima risposta buona") }
        }
        if prima?.testo != nuova.0 || prima?.buona != nuova.1 { cambiato?() }
    }

    /// Browser chiuso: si dimentica tutto di lui.
    func dimentica(_ bid: String) { risposte[bid] = nil; memoria[bid] = nil }

    // MARK: - Le finestre arricchite

    /// Aggiunge a ogni finestra il sito (se è una webapp) e il titolo dato dal browser; toglie
    /// le finestrelle (miniatura video, B-7).
    func arricchisci(_ app: NSRunningApplication, _ info: InfoApp, _ el: [UInt32: AXUIElement], spazio: CGRect) -> InfoApp {
        guard let B = browserNoti[info.bid] else { return info }
        var out = info
        out.breve = B.breve
        if B.tipo == .accessibilita {
            out.finestre = info.finestre.map { f in
                var f = f
                if let w = el[f.id] {
                    let v = guarda(w, id: f.id, titolo: f.titolo, nascosta: app.isHidden, ridotta: f.ridotta)
                    f.sito = v.schede == 1 ? v.sito.flatMap(dominio) : nil
                    f.inVista = v.sito
                }
                return f
            }
            return out
        }
        if risposte[info.bid] == nil { chiedi(info.bid, B) }
        let desc = leggiRisposta(risposte[info.bid]?.testo ?? "")
        let schermo = info.finestre.compactMap { f -> FinestraSchermo? in
            guard let w = el[f.id], let r = Sistema.cornice(w) else { return nil }
            let piccola = r.width < spazio.width * 0.5 && r.height < spazio.height * 0.6
            return FinestraSchermo(id: f.id, titolo: f.titolo, cornice: r, piccola: piccola)
        }
        let a = abbina(schermo, desc, memoria: memoria[info.bid] ?? [:])
        memoria[info.bid] = a.memoria
        var finestre: [InfoFinestra] = []
        for f in info.finestre {
            var f = f
            var trovata = a.trovate[f.id].map { desc[$0] }
            if trovata == nil { trovata = conosciute[f.id] }        // Meet e Gmail cambiano titolo di continuo
            if let t = trovata {
                conosciute[f.id] = t
                f.titoloBrowser = t.nome
                f.sito = sitoDi(t.urls)
                f.indirizzi = t.urls
            } else if risposte[info.bid] != nil, schermo.first(where: { $0.id == f.id })?.piccola == true {
                continue                                            // finestrella: non è una scheda
            }
            finestre.append(f)
        }
        out.finestre = finestre
        return out
    }

    /// DuckDuckGo (B-2): leggere dentro una finestra costa; si rilegge solo se il titolo è
    /// cambiato o dopo 10 s. Ridotta o browser nascosto: vale l'ultima cosa vista.
    private func guarda(_ w: AXUIElement, id: UInt32, titolo: String, nascosta: Bool, ridotta: Bool) -> (sito: String?, schede: Int?) {
        if let v = viste[id], nascosta || ridotta || (v.titolo == titolo && Date().timeIntervalSince(v.quando) < 10) {
            if v.sito?.isEmpty == true { return (nil, v.schede) }
            return (v.sito, v.schede)
        }
        if nascosta || ridotta { return (nil, nil) }
        // Guardare dentro una finestra può costare qualche decimo di secondo: si fa **in
        // sottofondo** e intanto vale l'ultima cosa vista; quando arriva la risposta, se è
        // cambiato qualcosa, le schede si ricostruiscono.
        if !inLettura.contains(id) {
            inLettura.insert(id)
            coda.async { [weak self] in
                let r = Browser.esplora(w)
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.letta(id, titolo: titolo, r) } }
            }
        }
        if let v = viste[id] { return (v.sito, v.schede) }
        return (nil, nil)
    }

    private func letta(_ id: UInt32, titolo: String, _ r: (sito: String?, schede: Int?)) {
        inLettura.remove(id)
        guard r.sito != nil, r.schede != nil else { return }
        let cambiata = viste[id]?.sito != r.sito || viste[id]?.schede != r.schede
        if cambiata { diario("DuckDuckGo «\(titolo.prefix(40))»: sito=\(r.sito.flatMap(dominio) ?? "?") · schede=\(r.schede ?? 0)") }
        let titoloCambiato = viste[id]?.titolo != titolo
        viste[id] = Vista(sito: r.sito, schede: r.schede, titolo: titolo, quando: Date())
        if cambiata || titoloCambiato { salvaViste() }
        if cambiata { cambiato?() }
    }

    /// Guarda dentro la finestra (al massimo 800 elementi, profondità 14) senza entrare nella
    /// pagina: l'indirizzo e i pulsanti delle schede.
    nonisolated static func esplora(_ radice: AXUIElement) -> (sito: String?, schede: Int?) {
        var visti = 0, pulsanti = 0, radio = 0, descr = 0
        var gruppo: Int?, pagina: String?, campo: String?
        func a<T>(_ e: AXUIElement, _ n: String) -> T? {
            var v: CFTypeRef?
            return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v as? T : nil
        }
        func giù(_ e: AXUIElement, _ p: Int) {
            guard visti < 800, p <= 14 else { return }
            visti += 1
            let ruolo: String = a(e, kAXRoleAttribute) ?? "?"
            if ruolo == "AXWebArea" {
                if let u: URL = a(e, "AXURL"), let s = u.scheme, s.hasPrefix("http") { pagina = u.absoluteString }
                return                                                  // la pagina non si legge
            }
            if (ruolo == kAXTextFieldRole || ruolo == kAXComboBoxRole) && campo == nil,
               let v: String = a(e, kAXValueAttribute), !v.contains(" "), v.range(of: #"^[\w-]+[.:]"#, options: .regularExpression) != nil {
                campo = v
            }
            if ruolo == kAXTabGroupRole, let t: [AXUIElement] = a(e, kAXTabsAttribute), !t.isEmpty { gruppo = t.count }
            let sub: String? = a(e, kAXSubroleAttribute)
            if sub == "AXTabButton" || ruolo == "AXTab" { pulsanti += 1 }
            if ruolo == kAXRadioButtonRole { radio += 1 }
            if let d: String = a(e, kAXRoleDescriptionAttribute), ["tab", "scheda"].contains(d.lowercased()) { descr += 1 }
            for c in (a(e, kAXChildrenAttribute) as [AXUIElement]?) ?? [] { giù(c, p + 1) }
        }
        AXUIElementSetMessagingTimeout(radice, 0.25)
        giù(radice, 0)
        let schede = gruppo ?? (pulsanti > 0 ? pulsanti : descr > 0 ? descr : radio > 0 ? radio : nil)
        return ((pagina ?? campo).flatMap(soloSito), schede)
    }
}

// MARK: - I loghi dei siti (B-6)

/// Scaricati una volta e ricordati (anche su disco, così dopo un riavvio ci sono subito).
/// Fonti in ordine: servizio loghi di DuckDuckGo (dominio, poi dominio principale), Google,
/// e il sito stesso. Se falliscono tutte (es. Wi-Fi non ancora connesso) si riprova dopo 60 s.
@MainActor
final class Loghi {
    var arrivato: ((String, NSImage) -> Void)?
    private var memoria: [String: NSImage] = [:]
    private var falliti: [String: Date] = [:]
    private var inCorso = Set<String>()
    private let cartella: URL = {
        let u = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.dquaini.Tabby/loghi")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    func logo(_ dom: String) -> NSImage? {
        if let i = memoria[dom] { return i }
        let file = cartella.appendingPathComponent(dom + ".png")
        if let i = NSImage(contentsOf: file), i.size.width >= 8 { memoria[dom] = i; return i }
        if inCorso.contains(dom) { return nil }
        if let f = falliti[dom], Date().timeIntervalSince(f) < 60 { return nil }
        inCorso.insert(dom)
        let parti = dom.split(separator: ".")
        var fonti = ["https://icons.duckduckgo.com/ip3/\(dom).ico"]
        if parti.count > 2 { fonti.append("https://icons.duckduckgo.com/ip3/\(parti.suffix(2).joined(separator: ".")).ico") }
        fonti += ["https://www.google.com/s2/favicons?sz=64&domain=\(dom)", "https://\(dom)/favicon.ico"]
        prova(dom, fonti, file)
        return nil
    }

    private func prova(_ dom: String, _ fonti: [String], _ file: URL) {
        guard let f = fonti.first, let u = URL(string: f) else {
            inCorso.remove(dom); falliti[dom] = Date()
            diario("logo di \(dom) non trovato (riprovo tra un minuto)")
            return
        }
        URLSession.shared.dataTask(with: u) { [weak self] dati, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let dati, let i = NSImage(data: dati), i.size.width >= 8 {
                        self.inCorso.remove(dom)
                        self.memoria[dom] = i
                        if let t = i.tiffRepresentation, let r = NSBitmapImageRep(data: t), let png = r.representation(using: .png, properties: [:]) {
                            try? png.write(to: file)
                        }
                        self.arrivato?(dom, i)
                    } else { self.prova(dom, Array(fonti.dropFirst()), file) }
                }
            }
        }.resume()
    }
}

// MARK: - I numerini del Dock (N-1)

/// Le app mostrano i numerini sulla loro icona nel Dock: Tabby li legge ogni 5 s (non c'è un
/// avviso di macOS per questo). Funziona anche col Dock nascosto.
@MainActor
final class NotificheDock {
    var cambiate: (([String: String]) -> Void)?
    private(set) var attuali: [String: String] = [:]
    private var percorsi: [String: String] = [:]
    private var timer: Timer?

    init() {
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.leggi() } }
        t.tolerance = 1.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func leggi() {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        var nuove: [String: String] = [:]
        let e = Sistema.elemento(dock.processIdentifier)
        for lista in (Sistema.attributo(e, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
            for icona in (Sistema.attributo(lista, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
                guard let n: String = Sistema.attributo(icona, "AXStatusLabel"), !n.isEmpty else { continue }
                var bid: String?
                if let u: URL = Sistema.attributo(icona, "AXURL") {
                    let p = u.path
                    if percorsi[p] == nil { percorsi[p] = Bundle(url: u)?.bundleIdentifier ?? "" }
                    bid = percorsi[p].flatMap { $0.isEmpty ? nil : $0 }
                }
                if let bid { nuove[bid] = n }
            }
        }
        if nuove != attuali { attuali = nuove; cambiate?(nuove) }
    }
}
