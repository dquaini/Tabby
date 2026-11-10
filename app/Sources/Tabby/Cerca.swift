import AppKit
@preconcurrency import ApplicationServices
import SwiftUI
import TabbyCore

/// Il testo dentro le finestre (16c E-2): letto con l'Accessibilità **in sottofondo**, una finestra
/// alla volta (al massimo 5000 elementi e 60 000 caratteri), tenuto **solo in memoria**.
@MainActor
final class LettoreTesti {
    private(set) var testi: [UInt32: (testo: String, quando: Date)] = [:]
    private var inLettura = Set<UInt32>()
    private var elettron = Set<pid_t>()
    private let coda = DispatchQueue(label: "tabby.testi", qos: .utility)
    var letto: (() -> Void)?

    /// Legge le finestre lette da più di 30 s (prima le più usate).
    func aggiorna(_ finestre: [(id: UInt32, pid: pid_t, w: AXUIElement)]) {
        for f in finestre {
            if let t = testi[f.id], Date().timeIntervalSince(t.quando) < 30 { continue }
            guard inLettura.insert(f.id).inserted else { continue }
            if elettron.insert(f.pid).inserted {    // Slack, Notion (Electron): il testo va chiesto una volta
                AXUIElementSetAttributeValue(AXUIElementCreateApplication(f.pid), "AXManualAccessibility" as CFString, kCFBooleanTrue)
            }
            let w = f.w, id = f.id, bid = NSRunningApplication(processIdentifier: f.pid)?.bundleIdentifier ?? ""
            coda.async { [weak self] in
                var t = LettoreTesti.leggi(w)
                if let brano = LettoreTesti.inAscolto(bid) { t += "\n" + brano }
                DispatchQueue.main.async { MainActor.assumeIsolated {
                    self?.inLettura.remove(id)
                    // vuoto (un'app Electron che prepara ancora il testo): si riprova la volta dopo
                    if !t.isEmpty { self?.testi[id] = (t, Date()) }
                    self?.letto?()
                } }
            }
        }
    }

    /// Spotify e Musica non fanno leggere il testo della finestra: si chiede a loro il brano in
    /// ascolto (titolo, artista, album). La prima volta macOS chiede il permesso.
    nonisolated static func inAscolto(_ bid: String) -> String? {
        let app = ["com.spotify.client": "Spotify", "com.apple.Music": "Music"][bid]
        guard let app else { return nil }
        let p = Process(), uscita = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"\(app)\" to if player state is not stopped then return (name of current track) & linefeed & (artist of current track) & linefeed & (album of current track)"]
        p.standardOutput = uscita; p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        let s = String(data: uscita.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return s?.isEmpty == false ? s : nil
    }

    nonisolated static func leggi(_ radice: AXUIElement) -> String {
        var visti = 0, parti: [String] = [], lunghezza = 0
        let ruoli: Set<String> = ["AXStaticText", "AXTextArea", "AXTextField", "AXCell", "AXHeading", "AXLink"]
        func a<T>(_ e: AXUIElement, _ n: String) -> T? {
            var v: CFTypeRef?
            return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v as? T : nil
        }
        func giù(_ e: AXUIElement, _ p: Int) {
            guard visti < 5000, lunghezza < 60_000, p < 40 else { return }
            visti += 1
            let r: String = a(e, kAXRoleAttribute) ?? ""
            if ruoli.contains(r), let v: String = a(e, kAXValueAttribute) ?? a(e, kAXTitleAttribute) ?? a(e, kAXDescriptionAttribute), !v.isEmpty {
                parti.append(v); lunghezza += v.count
            }
            for c in (a(e, kAXChildrenAttribute) as [AXUIElement]?) ?? [] { giù(c, p + 1) }
        }
        AXUIElementSetMessagingTimeout(radice, 0.5)
        giù(radice, 0)
        return parti.joined(separator: "\n")
    }
}

/// Ciò che si sceglie dalla barra di ricerca.
enum AzioneRicerca {
    case scheda(String), cartella(Int), lampo(Lampo), comando(() -> Void), impostazione(String)
}

extension Controllore {
    /// ⌃⌥Spazio: la barra che cerca tutto (DESIGN 3.6), a un terzo dello spazio delle app.
    func apriRicerca(con testo: String = "") {
        if palco.aperto && stato.ricerca != nil { chiudiRicerca(); return }
        stato.ricerca = testo
        stato.sceltaRicerca = 0
        stato.confermaForte = nil
        aggiornaTesti()
        palco.apri(BarraRicerca(c: self, stato: stato), sopra: pannello, posizione: stato.posizione, inAlto: true) { [weak self] in
            self?.chiudiRicerca()
        }
    }

    func chiudiRicerca(torna: Bool = true) { stato.ricerca = nil; palco.chiudiFoglio(torna: torna) }

    private func aggiornaTesti() {
        var f: [(id: UInt32, pid: pid_t, w: AXUIElement)] = []
        for s in tutte { if let id = s.finestra, let w = elementi[s.chiave] { f.append((id, s.pid, w)) } }
        testi.aggiorna(f)
    }

    /// Tutto quello che si può trovare, coi gruppi decisi.
    func cercabili() -> [(Trovato, AzioneRicerca)] {
        var out: [(Trovato, AzioneRicerca)] = []
        let recenti = storiaUso
        for s in tutte {
            let app = NSRunningApplication(processIdentifier: s.pid)?.localizedName ?? ""
            let uso = (recenti.firstIndex(of: s.chiave)).map { 30 - $0 } ?? 0
            out.append((Trovato(id: "s:" + s.chiave, gruppo: .schede, titolo: s.nome, sotto: app, uso: uso), .scheda(s.chiave)))
            if let id = s.finestra, let t = testi.testi[id]?.testo, !t.isEmpty {
                out.append((Trovato(id: "w:" + s.chiave, gruppo: .finestre, titolo: s.titolo ?? s.nome, sotto: app, testo: t, uso: uso), .scheda(s.chiave)))
            }
        }
        if let memo = try? String(contentsOf: Memo.file, encoding: .utf8) {
            out.append((Trovato(id: "memo", gruppo: .finestre, titolo: "Memo", sotto: "Tabby", testo: memo), .lampo(lampi.lampi.first(where: \.memo) ?? lampiDiSerie[0])))
        }
        for f in cartelle {
            out.append((Trovato(id: "f:\(f.id)", gruppo: .cartelle, titolo: f.nome, sotto: f.voci.map(\.nome).joined(separator: ", ")), .cartella(f.id)))
        }
        for l in lampi.lampi {
            out.append((Trovato(id: "l:" + l.id, gruppo: .lampi, titolo: l.nome, sotto: "⌃⌥" + l.tasto.uppercased()), .lampo(l)))
        }
        let azioni: [(String, String, Bool, () -> Void)] = [
            ("Nuova app", "Apri un'app con Spotlight", false, { [weak self] in self?.nuovaApp() }),
            ("Scrivania", "Il musetto del gatto · ⌃⌥0", false, { [weak self] in self?.gatto() }),
            ("Chiudi Tabby", "Resta la sfera; un clic riapre tutto", false, { [weak self] in self?.chiudiTabby() }),
            ("Concentrazione", "25 · 50 · 90 min", false, { [weak self] in self?.apriFoglioConcentrazione() }),
            ("Nuova cartella", "Scegli le schede, poi il nome", false, { [weak self] in self?.apriFoglioCartella() }),
            ("Personalizza i Lampi", "Ordine, scorciatoie, aggiungi", false, { [weak self] in self?.apriFoglioLampi() }),
            ("Dividi lo schermo", "Metà e metà", false, { [weak self] in self?.avviaDivisione("2-50") }),
            ("Chiudi tutte le app", "Le app di sistema restano", true, { [weak self] in self?.chiudiTutteLeApp() }),
            ("Metti in pausa Tabby", "Resta solo la sfera", true, { [weak self] in self?.pausa(true) }),
        ]
        for (t, s, forte, a) in azioni {
            out.append((Trovato(id: "a:" + t, gruppo: .azioni, titolo: t, sotto: s, forte: forte), .comando(a)))
        }
        for (t, s, sezione) in impostazioniCercabili {
            out.append((Trovato(id: "i:" + t, gruppo: .impostazioni, titolo: t, sotto: s, testo: "tabby impostazioni " + sezione), .impostazione(sezione)))
        }
        return out
    }

    /// Le impostazioni che si trovano scrivendo (aprono la finestra di Tabby su quella sezione).
    var impostazioniCercabili: [(String, String, String)] {
        [("Tabby", "La finestra di Tabby", ""), ("Impostazioni", "Tabby · tutte le scelte", "set"),
         ("Design", "Tabby · aspetto e temi", "des"), ("Documentazione", "Tabby · come funziona, scorciatoie", "doc"),
         ("Automazione", "Tabby · presto", "aut"), ("Kat", "Tabby · presto", "kat"),
         ("Posizione", "Dove sta Tabby", "set"),
         ("Una scheda alla volta", "Nasconde le altre app", "set"), ("Adatta le finestre a Tabby", "Spazio libero accanto alla barra", "set"),
         ("Vista cartelle", "Una cartella attiva = una scheda", "set"), ("Barra dei menu e Dock", "Nascondili", "set"),
         ("Apri Tabby all'accensione", "Elementi di login", "set"), ("Aspetto e temi", "Nativo · Notte", "des"),
         ("Scorciatoie", "Tutte, con ⌃⌥", "doc")]
    }

    func esegui(_ a: AzioneRicerca, alternativa: Bool) {
        let testo = stato.ricerca ?? ""
        chiudiRicerca(torna: false)                 // si va altrove: niente ritorno all'app di prima
        switch a {
        case .scheda(let k):
            let vis = conViste(tutte, viste)
            guard let s = vis.first(where: { $0.chiave == k || stato.membri[$0.chiave]?.contains { $0.chiave == k } == true }) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                if let id = self.stato.diChi[s.chiave] { self.entraNellaCartella(id, su: s.chiave) }   // dentro una cartella: si entra
                else { self.vai(s) }
                if alternativa { self.cercaDentro(testo) }              // ⌘↵: apri e cerca dentro (⌘F)
            }
        case .cartella(let id): attivaCartella(id)
        case .lampo(let l): lampi.premi(l)
        case .comando(let f): f()
        case .impostazione(let sezione): apriFinestraTabby(sezione: sezione.isEmpty ? nil : sezione)
        }
    }

    /// Dopo una scelta con ⌘↵: ⌘F nella finestra e le parole già scritte.
    private func cercaDentro(_ testo: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let src = CGEventSource(stateID: .hidSystemState)
            for giù in [true, false] { let e = CGEvent(keyboardEventSource: src, virtualKey: 3, keyDown: giù); e?.flags = .maskCommand; e?.post(tap: .cghidEventTap) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let u = Array(testo.utf16)
                let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
                e?.keyboardSetUnicodeString(stringLength: u.count, unicodeString: u)
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}

/// La barra: un campo come Spotlight e i risultati a gruppi. ↑↓ scegli · ↵ apri · ⌘↵ azione
/// alternativa · esc cancella il testo, di nuovo chiude. Le azioni forti chiedono un secondo ↵.
struct BarraRicerca: View {
    let c: Controllore
    @Bindable var stato: StatoBarra
    @FocusState private var dentro: Bool

    var body: some View {
        let tutto = c.cercabili()
        let r = cerca(stato.ricerca ?? "", in: tutto.map(\.0))
        let elenco = (r.migliore.map { [$0] } ?? []) + r.gruppi.flatMap(\.1)
        let azione = Dictionary(tutto.map { ($0.0.id, $0.1) }, uniquingKeysWith: { a, _ in a })
        // Come Spotlight di macOS 26: un vetro solo, che da capsula si allunga in giù coi risultati.
        let aperta = !elenco.isEmpty
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .medium)).foregroundStyle(.secondary)
                TextField("Cerca con Tabby", text: Binding(get: { stato.ricerca ?? "" }, set: { stato.ricerca = $0; stato.sceltaRicerca = 0; stato.confermaForte = nil }))
                    .textFieldStyle(.plain).font(.system(size: 22)).focused($dentro)
                    .onSubmit { scegli(elenco, azione, alternativa: NSEvent.modifierFlags.contains(.command)) }
            }
            .padding(.horizontal, 20).frame(height: 56)
            if aperta {
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 0) {
                    if let m = r.migliore { titoletto("Il migliore"); riga(m, 0) }
                    ForEach(r.gruppi, id: \.0) { g, righe in
                        titoletto(g.titolo)
                        ForEach(righe) { x in riga(x, elenco.firstIndex(of: x) ?? 0) }
                    }
                }
                .padding(.vertical, 8)
                .transition(.opacity)
            }
        }
        .frame(width: 680)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: aperta)
        .animation(.easeOut(duration: 0.12), value: elenco.map(\.id))
        // si scrive subito, senza cliccare
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dentro = true } }
        .onKeyPress(.upArrow) { stato.sceltaRicerca = max(0, stato.sceltaRicerca - 1); stato.confermaForte = nil; return .handled }
        .onKeyPress(.downArrow) { stato.sceltaRicerca = min(max(0, elenco.count - 1), stato.sceltaRicerca + 1); stato.confermaForte = nil; return .handled }
        .onKeyPress(.escape) {
            if (stato.ricerca ?? "").isEmpty { c.chiudiRicerca() } else { stato.ricerca = "" }
            return .handled
        }
    }

    private func scegli(_ elenco: [Risultato], _ azione: [String: AzioneRicerca], alternativa: Bool) {
        guard stato.sceltaRicerca < elenco.count else { return }
        let x = elenco[stato.sceltaRicerca]
        if x.t.forte && stato.confermaForte != x.id { stato.confermaForte = x.id; return }   // azione forte: un secondo ↵
        if let a = azione[x.id] { c.esegui(a, alternativa: alternativa) }
    }

    private func titoletto(_ t: String) -> some View {
        Text(t).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 3)
    }

    private func riga(_ x: Risultato, _ i: Int) -> some View {
        let su = stato.sceltaRicerca == i
        let forte = stato.confermaForte == x.id
        return HStack(spacing: 10) {
            icona(x.t).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(forte ? "Premi ↵ di nuovo per «\(x.t.titolo)»" : x.t.titolo).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(forte ? Color.red : (su ? .white : .primary)).lineLimit(1)
                if let p = x.pezzetto { Text(p).font(.system(size: 12)).foregroundStyle(su ? .white.opacity(0.85) : .secondary).lineLimit(1) }
            }
            Spacer()
            Text(x.t.sotto).font(.system(size: 12)).foregroundStyle(su ? .white.opacity(0.85) : .secondary).lineLimit(1)
        }
        .padding(.horizontal, 12).frame(height: x.pezzetto == nil ? 38 : 48)
        .background(su ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture { stato.sceltaRicerca = i; scegli(elencoAttuale(), mappaAttuale(), alternativa: false) }
    }

    private func elencoAttuale() -> [Risultato] {
        let r = cerca(stato.ricerca ?? "", in: c.cercabili().map(\.0))
        return (r.migliore.map { [$0] } ?? []) + r.gruppi.flatMap(\.1)
    }
    private func mappaAttuale() -> [String: AzioneRicerca] { Dictionary(c.cercabili().map { ($0.0.id, $0.1) }, uniquingKeysWith: { a, _ in a }) }

    @ViewBuilder private func icona(_ t: Trovato) -> some View {
        let k = String(t.id.dropFirst(2))
        switch t.gruppo {
        case .schede, .finestre:
            if let s = c.scheda(k), let i = s.sito.flatMap({ stato.loghi[$0] }) ?? stato.icone[s.bid] { Image(nsImage: i).resizable() }
            else { Image(systemName: "note.text").foregroundStyle(Tema.accento) }
        case .cartelle: Image(systemName: "square.stack.3d.up").foregroundStyle(Tema.accento)
        case .lampi: Image(systemName: "sparkles").foregroundStyle(Tema.accento)
        case .azioni: Image(systemName: t.forte ? "exclamationmark.triangle" : "command").foregroundStyle(t.forte ? Color.orange : Tema.accento)
        case .impostazioni: Image(systemName: "gearshape").foregroundStyle(Tema.accento)
        }
    }
}
