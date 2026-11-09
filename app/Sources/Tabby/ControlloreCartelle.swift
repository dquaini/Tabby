import AppKit
import SwiftUI
import TabbyCore

/// Le cartelle nel regista di Tabby (SPECIFICA 8, DESIGN 3.2 e 3.4).
extension Controllore {
    // MARK: - Salvare

    func salvaCartelle() { imp.imposta("folders", cartelle.map(\.dizionario)); stato.cartelle = cartelle }
    func salvaAttive() { imp.imposta("activeFolders", attive) }
    func salvaLegami() { imp.imposta("itemWins", legami.mapValues { Int($0) }) }

    var vistaCartelle: Bool { imp.valore("folderView") as? Bool ?? true }
    func cartellaAttive() -> [Cartella] { attive.compactMap { id in cartelle.first { $0.id == id } } }

    /// Le schede di una cartella (dalle schede assegnate nell'ultima ricostruzione).
    func schede(di id: Int) -> [Scheda] {
        let tutteVisibili = conViste(tutte, viste)
        return tutteVisibili.filter { stato.diChi[$0.chiave] == id }
    }

    // MARK: - Dentro la ricostruzione

    /// Applica le cartelle alle schede (con le viste divise già al loro posto). Lega le finestre
    /// appena aperte alle voci (F-4.1), spegne le cartelle vuote (F-9), segue l'apertura.
    func applicaCartelle(_ vis: [Scheda]) -> [Scheda] {
        // finestre nuove arrivate per una voce: si legano a lei
        let ora = Date()
        for (bid, p) in inArrivo {
            if ora.timeIntervalSince(p.quando) > 8 { inArrivo[bid] = nil; continue }
            if let s = tutte.first(where: { $0.bid == bid && $0.finestra.map { !p.note.contains($0) } ?? false }), let f = s.finestra {
                legami[p.legame] = f; inArrivo[bid] = nil
            }
        }
        let a = TabbyCore.assegna(cartellaAttive(), schede: vis, membri: stato.membri, legami: legami)
        if a.legami != legami { legami = a.legami; salvaLegami() }
        if a.diChi != stato.diChi { stato.diChi = a.diChi }
        // F-9: una cartella attiva senza più schede si spegne (non nei primi 20 s)
        for id in attive where !a.diChi.values.contains(id) && ora.timeIntervalSince(attivataIl[id] ?? .distantPast) > 20 {
            attive.removeAll { $0 == id }; salvaAttive()
            if stato.cartellaAperta == id { stato.cartellaAperta = nil }
        }
        // l'apertura: le voci arrivate si accendono
        if var ap = stato.apertura, let c = cartelle.first(where: { $0.id == ap.cartella }) {
            let arrivate = Set(c.voci.indices.filter { a.prese["\(c.id)|\(c.voci[$0].chiave)"] != nil })
            if arrivate != ap.arrivate { ap.arrivate = arrivate; ap.ultimoArrivo = ora; stato.apertura = ap }
        }
        var m: [String: [Scheda]] = [:]
        for c in cartellaAttive() { m[c.chiave] = vis.filter { a.diChi[$0.chiave] == c.id } }
        if m != stato.membriCartella { stato.membriCartella = m }
        return conCartelle(vis, cartelle: cartelle, diChi: a.diChi, vistaCartelle: vistaCartelle, aperta: stato.cartellaAperta)
    }

    // MARK: - Attivare (F-4)

    /// Dal gatto o con ⌃⌥⇧ + numero. Ripremuto sulla cartella che stai guardando: torni a tutte.
    func attivaCartella(_ id: Int) {
        guard let c = cartelle.first(where: { $0.id == id }) else { return }
        if attive.contains(id) {
            if stato.cartellaAperta == id { esciDallaVistaCartella(); return }
            entraNellaCartella(id); return
        }
        let vis = conViste(tutte, viste)
        let prova = TabbyCore.assegna([c], schede: vis.filter { stato.diChi[$0.chiave] == nil }, membri: stato.membri, legami: legami)
        let mancanti = c.voci.filter { prova.prese["\(c.id)|\($0.chiave)"] == nil }
        let parti = {
            for v in mancanti { self.apri(v, legame: "\(c.id)|\(v.chiave)") }
            // se un'app appena aperta ti porta via, Tabby ti riporta nella cartella (1,2 s e 2,5 s)
            for t in [1.2, 2.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                    guard let self, self.stato.cartellaAperta == id else { return }
                    self.ricostruisci()
                    if let s = self.stato.schede.first(where: { $0.chiave == self.ultimaDi[id] }) ?? self.stato.schede.first,
                       self.stato.attiva != s.chiave { self.vai(s, daTe: false) }
                }
            }
        }
        attive.append(id); attivataIl[id] = Date(); salvaAttive()
        if mancanti.count >= 2 { apriConSchermata(c, parti) } else { parti() }
        // si entra sempre nella cartella, anche se le sue app erano già aperte (Daniele, 9/11/2026)
        entraNellaCartella(id)
        diario("cartella «\(c.nome)»: \(mancanti.count) da aprire")
    }

    /// Apre una voce che manca, **senza portarla davanti** (F-4.1). La prossima finestra nuova di
    /// quell'app (entro 8 s) viene legata alla voce.
    func apri(_ v: Voce, legame: String) {
        let note = Set(tutte.filter { $0.bid == v.bid }.compactMap(\.finestra))
        inArrivo[v.bid] = (legame, Date(), note)
        let B = browserNoti[v.bid]
        func script(_ s: String) { esegui("/usr/bin/osascript", ["-e", s]) }
        if let p = v.pagine?.compactMap(pulisci), !p.isEmpty {
            switch B?.tipo {
            case .chrome?:
                script((["tell application \"\(B!.nomeAS)\"", "set w to make new window", "set URL of active tab of w to \"\(p[0])\""]
                        + p.dropFirst().map { "tell w to make new tab with properties {URL:\"\($0)\"}" } + ["end tell"]).joined(separator: "\n"))
            case .safari?:
                script((["tell application \"Safari\"", "make new document with properties {URL:\"\(p[0])\"}"]
                        + p.dropFirst().map { "tell front window to make new tab at end of tabs with properties {URL:\"\($0)\"}" } + ["end tell"]).joined(separator: "\n"))
            default: esegui("/usr/bin/open", ["-g", "-b", v.bid] + p)
            }
        } else if let sito = v.sito, sito.range(of: #"^[\w.-]+$"#, options: .regularExpression) != nil {
            let u = "https://\(sito)/"
            switch B?.tipo {
            case .chrome?: script("tell application \"\(B!.nomeAS)\"\nset w to make new window\nset URL of active tab of w to \"\(u)\"\nend tell")
            case .safari?: script("tell application \"Safari\"\nmake new document with properties {URL:\"\(u)\"}\nend tell")
            default: esegui("/usr/bin/open", ["-g", "-b", v.bid, u])          // DuckDuckGo: come scheda del browser
            }
        } else if let B, B.tipo != .accessibilita, tutte.contains(where: { $0.bid == v.bid }) {
            script(B.tipo == .safari ? "tell application \"Safari\" to make new document" : "tell application \"\(B.nomeAS)\" to make new window")
        } else {
            esegui("/usr/bin/open", ["-g", "-b", v.bid])
        }
    }

    /// Un comando esterno, senza aspettarlo (Tabby non si ferma mai).
    func esegui(_ percorso: String, _ argomenti: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: percorso)
        p.arguments = argomenti
        do { try p.run() } catch { diario("non parte \(percorso): \(error)") }
    }

    /// F-6: entri nella vista cartella, sull'ultima scheda usata (o la prima).
    func entraNellaCartella(_ id: Int, su chiave: String? = nil) {
        withAnimationMolla { stato.cartellaAperta = id }
        ricostruisci()
        let sue = stato.schede
        if let s = sue.first(where: { $0.chiave == (chiave ?? ultimaDi[id]) }) ?? sue.first { vai(s) }
    }

    /// ← : torni a tutte le schede. Con «Vista cartelle» spenta la cartella si chiude anche come
    /// cartella (le schede tornano libere), altrimenti resta come scheda-cartella.
    func esciDallaVistaCartella() {
        guard let id = stato.cartellaAperta else { return }
        withAnimationMolla { stato.cartellaAperta = nil }
        if !vistaCartelle { attive.removeAll { $0 == id }; salvaAttive() }
        ricostruisci()
    }

    // MARK: - Il menu ⋯ (F-5) e le azioni

    /// Esci dalla cartella: le schede tornano libere.
    func esciDallaCartella(_ id: Int) {
        attive.removeAll { $0 == id }; salvaAttive()
        if stato.cartellaAperta == id { stato.cartellaAperta = nil }
        ricostruisci()
    }

    /// Chiudi la cartella (F-7): si chiude subito (app intere; per browser e Finder solo le sue
    /// finestre); un avviso con «Riapri» la rimette com'era (DESIGN 3.2).
    func chiudiCartella(_ id: Int) {
        guard let c = cartelle.first(where: { $0.id == id }) else { return }
        let sue = schede(di: id).flatMap { stato.membri[$0.chiave] ?? [$0] }
        for s in sue {
            if browserNoti[s.bid] != nil || s.bid == "com.apple.finder" { if let w = elementi[s.chiave] { Sistema.chiudi(w) } }
            else { NSRunningApplication(processIdentifier: s.pid)?.terminate() }
        }
        esciDallaCartella(id)
        avvisi.mostra(Avviso(simbolo: "square.stack.3d.up", titolo: "\(c.nome) chiusa", testo: "\(sue.count) \(sue.count == 1 ? "scheda" : "schede")",
                             scelte: [.init(titolo: "Riapri", principale: true) { [weak self] in self?.attivaCartella(id) }]))
    }

    /// Aggiorna con le schede di adesso (F-8).
    func aggiornaCartella(_ id: Int) {
        guard var c = cartelle.first(where: { $0.id == id }) else { return }
        let vecchie = Dictionary(c.voci.map { ($0.chiave, $0) }, uniquingKeysWith: { a, _ in a })
        c.voci = schede(di: id).flatMap { stato.membri[$0.chiave] ?? [$0] }.map { s in
            var v = vocePer(s)
            if v.pagine == nil, let u = s.indirizzi?.compactMap(pulisci), !u.isEmpty,
               vecchie.values.contains(where: { $0.pagine != nil && $0.bid == s.bid }) { v = Voce(bid: s.bid, nome: v.nome, pagine: u) }
            return v
        }
        cartelle = salva(c, in: cartelle); salvaCartelle()
        ricostruisci()
    }

    func eliminaCartella(_ id: Int) {
        guard let i = cartelle.firstIndex(where: { $0.id == id }) else { return }
        let c = cartelle.remove(at: i)
        esciDallaCartella(id); salvaCartelle()
        avvisi.mostra(Avviso(simbolo: "trash", titolo: "Cartella «\(c.nome)» eliminata",
                             scelte: [.init(titolo: "Annulla", principale: true) { [weak self] in
                                 guard let self else { return }
                                 self.cartelle.insert(c, at: min(i, self.cartelle.count)); self.salvaCartelle()
                             }]))
    }

    func vocePer(_ s: Scheda) -> Voce {
        let varie = tutte.filter { $0.bid == s.bid }.count > 1
        return voce(da: s, browser: browserNoti[s.bid] != nil, breve: browserNoti[s.bid]?.breve, variePerApp: varie)
    }

    // MARK: - Creare e modificare (foglio, DESIGN 3.4)

    /// Prima le schede (la scheda in cui sei parte già scelta), poi il nome. Stesso foglio per
    /// modificare una cartella.
    func apriFoglioCartella(_ id: Int? = nil) {
        let c = id.flatMap { i in cartelle.first { $0.id == i } }
        var scelte: [String] = [], extra: [Voce] = []
        if let c {
            scelte = schede(di: c.id).map(\.chiave)
            // le voci senza una scheda aperta restano (app chiuse)
            let prese = TabbyCore.assegna([c], schede: conViste(tutte, viste), membri: stato.membri, legami: legami).prese
            extra = c.voci.filter { prese["\(c.id)|\($0.chiave)"] == nil }
        } else if let a = stato.attiva, !a.hasPrefix("f:") { scelte = [a] }
        stato.vociExtra = extra
        stato.cercaApp = ""
        stato.scelta = scelte
        stato.cartellaInModifica = c?.id
        stato.nomeFoglio = c?.nome ?? ""
        let vista = FoglioCartella(c: self, stato: stato, modifica: c != nil)
        palco.apri(vista, sopra: pannello, posizione: stato.posizione) { [weak self] in self?.chiudiFoglioCartella() }
    }

    func chiudiFoglioCartella() {
        stato.scelta = nil; stato.foglioIlluminato = false
        palco.chiudiFoglio()
    }

    func salvaFoglioCartella(modifica id: Int?) {
        let nome = stato.nomeFoglio.trimmingCharacters(in: .whitespaces)
        let scelte = stato.scelta ?? []
        guard !scelte.isEmpty || !stato.vociExtra.isEmpty, !nome.isEmpty else { return }
        let schede = scelte.flatMap { k in stato.membri[k] ?? scheda(k).map { [$0] } ?? [] }
        let nuovoId = id ?? ((cartelle.map(\.id).max() ?? (imp.valore("folderSeq") as? Int ?? 0)) + 1)
        let voci = schede.map(vocePer)
        let c = Cartella(id: nuovoId, nome: nome, voci: voci + stato.vociExtra.filter { e in !voci.contains { $0.chiave == e.chiave } })
        cartelle = salva(c, in: cartelle); salvaCartelle()
        imp.imposta("folderSeq", max(nuovoId, imp.valore("folderSeq") as? Int ?? 0))
        for s in schede { if let f = s.finestra { legami["\(c.id)|\(vocePer(s).chiave)"] = f } }
        salvaLegami()
        if !attive.contains(c.id) { attive.append(c.id); attivataIl[c.id] = Date(); salvaAttive() }
        chiudiFoglioCartella()
        ricostruisci()
        let n = (cartelle.firstIndex { $0.id == c.id } ?? 0) + 1
        if id == nil {
            avvisi.mostra(Avviso(simbolo: "square.stack.3d.up", titolo: "Cartella «\(nome)» salvata",
                                 testo: n <= 9 ? "dal gatto o ⌃⌥⇧\(n)" : "dal gatto"))
        }
    }

    /// Mentre il foglio è aperto: un clic su una scheda la sceglie o la toglie.
    func scegli(_ k: String) {
        guard var s = stato.scelta, !k.hasPrefix("f:") else { return }
        withAnimationMolla { if let i = s.firstIndex(of: k) { s.remove(at: i) } else { s.append(k) }; stato.scelta = s }
    }

    func trascinaNelFoglio(_ p: NSPoint) { stato.foglioIlluminato = palco.cornice.contains(p) }
    func lasciaNelFoglio(_ k: String, _ p: NSPoint) {
        stato.foglioIlluminato = false
        if palco.cornice.contains(p), let s = stato.scelta, !s.contains(k), !k.hasPrefix("f:") { withAnimationMolla { stato.scelta = s + [k] } }
    }

    // MARK: - La schermata d'apertura (F-4.5)

    /// Due o più voci da aprire: prima si copre tutto lo schermo (barra compresa), poi partono
    /// le app; la schermata sfuma quando sono arrivate tutte e da 1 s non ne arriva un'altra (e
    /// sono passati almeno 2,9 s), al massimo 7 s. Un clic la toglie subito.
    func apriConSchermata(_ c: Cartella, _ parti: @escaping () -> Void) {
        stato.apertura = StatoApertura(cartella: c.id, nome: c.nome, voci: c.voci, inizio: Date(), ultimoArrivo: Date())
        schermata.mostra()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { parti() }
        controllaApertura()
    }

    private func controllaApertura() {
        guard let ap = stato.apertura else { return }
        let ora = Date(), dall = ora.timeIntervalSince(ap.inizio)
        let finita = (ap.arrivate.count == ap.voci.count && ora.timeIntervalSince(ap.ultimoArrivo) > 1 && dall > 2.9) || dall > 7
        if finita { chiudiApertura(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.controllaApertura() }
    }

    func chiudiApertura() {
        guard stato.apertura != nil else { return }
        schermata.nascondi { [weak self] in self?.stato.apertura = nil }
    }
}

// MARK: - Il foglio «Nuova cartella»

struct FoglioCartella: View {
    let c: Controllore
    @Bindable var stato: StatoBarra
    let modifica: Bool
    @FocusState private var sulNome: Bool

    var body: some View {
        let scelte = stato.scelta ?? []
        Foglio(simbolo: "square.stack.3d.up", titolo: modifica ? "Modifica la cartella" : "Nuova cartella",
               spiegazione: "Clicca le schede nella barra, o trascinale qui. Poi dai un nome.",
               principale: modifica ? "Salva" : "Crea",
               principaleAcceso: (!scelte.isEmpty || !stato.vociExtra.isEmpty) && !stato.nomeFoglio.trimmingCharacters(in: .whitespaces).isEmpty,
               annulla: { c.chiudiFoglioCartella() },
               conferma: { c.salvaFoglioCartella(modifica: stato.cartellaInModifica) }) {
            VStack(alignment: .leading, spacing: 0) {
                let n = scelte.count + stato.vociExtra.count
                TitoloSezione(testo: n == 0 ? "Nessuna scheda scelta" : "\(n) \(n == 1 ? "voce" : "voci")")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(scelte, id: \.self) { k in riga(k) }
                        ForEach(stato.vociExtra, id: \.chiave) { v in rigaVoce(v) }
                    }
                }
                .frame(maxHeight: 260)
                .fixedSize(horizontal: false, vertical: true)
                TitoloSezione(testo: "Aggiungi un'app, anche chiusa")
                CercaApp(testo: $stato.cercaApp) { v in
                    if !stato.vociExtra.contains(where: { $0.bid == v.bid }) { withAnimationMolla { stato.vociExtra.append(v) } }
                    stato.cercaApp = ""
                }
                TitoloSezione(testo: "Nome")
                TextField("es. Lavoro, Studio", text: $stato.nomeFoglio)
                    .textFieldStyle(.plain).font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.bottom, 4)
                    .focused($sulNome)
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1).padding(.horizontal, 14)
            }
            .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Tema.accento.opacity(stato.foglioIlluminato ? 0.9 : 0), lineWidth: 2).padding(4))
        }
        .onAppear { sulNome = true }
    }

    private func rigaVoce(_ v: Voce) -> some View {
        HStack(spacing: 10) {
            if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: v.bid) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable().frame(width: 20, height: 20)
            }
            Text(v.nome).font(.system(size: 14)).foregroundStyle(.white).lineLimit(1)
            Text("chiusa").font(.system(size: 12)).foregroundStyle(.white.opacity(0.35))
            Spacer()
            Button { withAnimationMolla { stato.vociExtra.removeAll { $0.chiave == v.chiave } } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.45))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).frame(height: 32)
    }

    private func riga(_ k: String) -> some View {
        let s = c.scheda(k)
        return HStack(spacing: 8) {
            if let s, let i = s.sito.flatMap({ stato.loghi[$0] }) ?? stato.icone[s.bid] {
                Image(nsImage: i).resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: s.sito != nil ? 4 : 0))
            }
            Text(s?.nome ?? k).font(.system(size: 14)).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Button { c.scegli(k) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.45)) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).frame(height: 32)
    }
}

// MARK: - La schermata d'apertura

struct StatoApertura: Equatable {
    var cartella: Int
    var nome: String
    var voci: [Voce]
    var inizio: Date
    var ultimoArrivo: Date
    var arrivate: Set<Int> = []
}

/// Copre tutto lo schermo, barra compresa, senza trasparenza: la Scrivania rimpicciolita e
/// sfocata, il nome della cartella, le icone delle voci (spente, che respirano; si accendono
/// quando arriva la loro finestra) e una barretta.
@MainActor
final class Schermata: NSPanel {
    init(stato: StatoBarra, chiudi: @escaping () -> Void) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        backgroundColor = .black
        contentView = VistaOspite(rootView: VistaApertura(stato: stato, chiudi: chiudi))
    }

    func mostra() {
        setFrame(Sistema.schermo.frame, display: true)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.22; animator().alphaValue = 1 }
    }

    func nascondi(_ fatto: @escaping @MainActor () -> Void) {
        NSAnimationContext.runAnimationGroup { $0.duration = 0.38; animator().alphaValue = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.orderOut(nil); fatto() }
    }
}

private struct VistaApertura: View {
    @Bindable var stato: StatoBarra
    let chiudi: () -> Void
    @State private var respiro = false

    var body: some View {
        ZStack {
            if let u = NSWorkspace.shared.desktopImageURL(for: Sistema.schermo), let i = NSImage(contentsOf: u) {
                Image(nsImage: i).resizable().scaledToFill().blur(radius: 40).scaleEffect(1.1).overlay(Color.black.opacity(0.45))
            } else { Color.black }
            if let ap = stato.apertura {
                VStack(spacing: 22) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 26, weight: .medium)).foregroundStyle(Tema.accento)
                    Text(ap.nome).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                    HStack(spacing: 18) {
                        ForEach(ap.voci.indices, id: \.self) { i in
                            let on = ap.arrivate.contains(i)
                            icona(ap.voci[i]).frame(width: 44, height: 44)
                                .opacity(on ? 1 : (respiro ? 0.45 : 0.25))
                                .scaleEffect(on ? 1 : 0.92)
                                .animation(Tema.molla, value: on)
                        }
                    }
                    GeometryReader { g in
                        Capsule().fill(Color.white.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Tema.accento).frame(width: g.size.width * CGFloat(ap.arrivate.count) / CGFloat(max(1, ap.voci.count)))
                            }
                    }
                    .frame(width: 220, height: 4)
                    .animation(.easeOut(duration: 0.3), value: ap.arrivate.count)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: chiudi)
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { respiro = true } }
    }

    @ViewBuilder private func icona(_ v: Voce) -> some View {
        if let s = v.sito, let l = stato.loghi[s] { Image(nsImage: l).resizable().clipShape(RoundedRectangle(cornerRadius: 10)) }
        else if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: v.bid) { Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable() }
        else { Image(systemName: "app").resizable().foregroundStyle(.white) }
    }
}

// MARK: - Le app installate (per aggiungerle anche chiuse)

/// Le app del Mac (Applicazioni, Utility, quelle di sistema): lette una volta sola.
@MainActor enum AppInstallate {
    static let tutte: [(nome: String, bid: String, url: URL)] = {
        let fm = FileManager.default
        let cartelle = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                        fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
        var out: [(String, String, URL)] = [], visti = Set<String>()
        for c in cartelle {
            for f in (try? fm.contentsOfDirectory(atPath: c)) ?? [] where f.hasSuffix(".app") {
                let u = URL(fileURLWithPath: c).appendingPathComponent(f)
                guard let b = Bundle(url: u)?.bundleIdentifier, visti.insert(b).inserted else { continue }
                out.append((String(f.dropLast(4)), b, u))
            }
        }
        return out.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }()
}

/// Un campo per cercare un'app per nome: le prime 5 che corrispondono, con l'icona.
struct CercaApp: View {
    @Binding var testo: String
    let scegli: (Voce) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.4))
                TextField("Cerca un'app", text: $testo).textFieldStyle(.plain).font(.system(size: 14)).foregroundStyle(.white)
            }
            .padding(.horizontal, 14).frame(height: 30)
            let q = normalizza(testo)
            if !q.isEmpty {
                ForEach(AppInstallate.tutte.filter { normalizza($0.nome).contains(q) }.prefix(5), id: \.bid) { a in
                    Button { scegli(Voce(bid: a.bid, nome: a.nome)) } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: a.url.path)).resizable().frame(width: 20, height: 20)
                            Text(a.nome).font(.system(size: 14)).foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "plus").foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 14).frame(height: 30).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
