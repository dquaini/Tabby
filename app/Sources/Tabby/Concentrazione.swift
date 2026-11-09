import AppKit
import SwiftUI
import TabbyCore

/// La Concentrazione (SPECIFICA 16b, DESIGN 3.4): scegli le schede da tenere e per quanto; le
/// altre app si nascondono (non si chiudono), nella barra restano solo le scelte, al posto della
/// batteria il tempo che manca. Alla fine, «Fatto!» con le notifiche arrivate nel frattempo.
struct StatoConcentrazione: Equatable {
    var inizio: Date
    var fine: Date?                    // nil = senza tempo («Resta così»)
    var chiavi: Set<String>            // le schede scelte
    var app: Set<String>               // le loro app (le finestre nuove di queste app restano)
    var chiaviAllInizio: Set<String>
    var notificheInizio: [String: Int]

    var dizionario: [String: Any] {
        var d: [String: Any] = ["inizio": inizio.timeIntervalSince1970, "chiavi": Array(chiavi), "app": Array(app),
                                "tutte": Array(chiaviAllInizio), "notifiche": notificheInizio]
        if let fine { d["fine"] = fine.timeIntervalSince1970 }
        return d
    }
    init(inizio: Date, fine: Date?, chiavi: Set<String>, app: Set<String>, chiaviAllInizio: Set<String>, notificheInizio: [String: Int]) {
        self.inizio = inizio; self.fine = fine; self.chiavi = chiavi; self.app = app
        self.chiaviAllInizio = chiaviAllInizio; self.notificheInizio = notificheInizio
    }
    init?(_ d: [String: Any]) {
        guard let i = d["inizio"] as? Double, let k = d["chiavi"] as? [String] else { return nil }
        self.init(inizio: Date(timeIntervalSince1970: i), fine: (d["fine"] as? Double).map { Date(timeIntervalSince1970: $0) },
                  chiavi: Set(k), app: Set(d["app"] as? [String] ?? []), chiaviAllInizio: Set(d["tutte"] as? [String] ?? []),
                  notificheInizio: d["notifiche"] as? [String: Int] ?? [:])
    }
}

extension Controllore {
    // MARK: - Il foglio

    func apriFoglioConcentrazione() {
        let ultima = imp.valore("focusLast") as? [String: Any] ?? [:]
        var scelte = (ultima["chiavi"] as? [String] ?? []).filter { k in stato.schede.contains { $0.chiave == k } }
        if let a = stato.attiva, !scelte.contains(a), !a.hasPrefix("f:") { scelte.insert(a, at: 0) }
        stato.scelta = scelte
        stato.minutiConc = ultima["minuti"] as? Int ?? 50
        palco.apri(FoglioConcentrazione(c: self, stato: stato), sopra: pannello, posizione: stato.posizione) { [weak self] in
            self?.stato.scelta = nil; self?.palco.chiudiFoglio()
        }
    }

    /// Inizia (H-2): le app non scelte si nascondono; nella barra solo le schede scelte.
    func iniziaConcentrazione() {
        guard let scelte = stato.scelta, !scelte.isEmpty else { return }
        let minuti = stato.minutiConc
        imp.imposta("focusLast", ["chiavi": scelte, "minuti": minuti])
        let schede = scelte.flatMap { k in stato.membri[k] ?? stato.membriCartella[k] ?? scheda(k).map { [$0] } ?? [] }
        let c = StatoConcentrazione(inizio: Date(), fine: Date().addingTimeInterval(Double(minuti) * 60),
                                    chiavi: Set(scelte + schede.map(\.chiave)), app: Set(schede.map(\.bid)),
                                    chiaviAllInizio: Set(tutte.map(\.chiave) + stato.schede.map(\.chiave)), notificheInizio: numeriniOra())
        stato.scelta = nil
        palco.chiudiFoglio(torna: false)
        stato.concentrazione = c
        salvaConcentrazione()
        if stato.nonDisturbare { esegui("/usr/bin/shortcuts", ["run", "Concentrazione on"]) }
        Sistema.nascondiAltre(tranne: c.app)
        ricostruisci()
        // si resta sulla scheda in cui eri, se è tra le scelte; altrimenti la prima
        if let s = stato.schede.first(where: { $0.chiave == stato.attiva }) ?? stato.schede.first { vai(s, daTe: false) }
        controllaConcentrazione()
        diario("concentrazione: \(minuti) min, \(c.chiavi.count) schede")
    }

    func salvaConcentrazione() { imp.imposta("focus", stato.concentrazione?.dizionario) }

    /// Dopo un riavvio la Concentrazione continua, o finisce se il tempo è passato (H-5).
    func riprendiConcentrazione() {
        guard let d = imp.valore("focus") as? [String: Any], let c = StatoConcentrazione(d) else { return }
        if let f = c.fine, f < Date() { imp.imposta("focus", nil); return }
        stato.concentrazione = c
        controllaConcentrazione()
    }

    /// Ogni secondo, solo mentre è in corso: è finita?
    private func controllaConcentrazione() {
        guard let c = stato.concentrazione else { return }
        if let f = c.fine, f <= Date() { fineConcentrazione(suono: true); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.controllaConcentrazione() }
    }

    func prolunga(_ minuti: Int) {
        guard var c = stato.concentrazione else { return }
        c.fine = (c.fine ?? Date()).addingTimeInterval(Double(minuti) * 60)
        stato.concentrazione = c; salvaConcentrazione()
    }

    /// Le schede che restano in barra durante la Concentrazione: le scelte, più le finestre
    /// nuove delle app scelte.
    func filtraConcentrazione(_ s: [Scheda]) -> [Scheda] {
        guard let c = stato.concentrazione else { return s }
        return s.filter { x in
            c.chiavi.contains(x.chiave) || (c.app.contains(x.bid) && !c.chiaviAllInizio.contains(x.chiave))
                || (stato.membri[x.chiave] ?? stato.membriCartella[x.chiave] ?? []).contains { c.chiavi.contains($0.chiave) }
        }
    }

    /// Un'app non scelta viene davanti (Dock, Spotlight, ⌘Tab): torna nascosta, si torna
    /// all'ultima scheda permessa e Tabby chiede «Aprire X?» (H-3). Lampi, Memo e Finder no.
    func controllaAppFuori(_ app: NSRunningApplication) -> Bool {
        guard let c = stato.concentrazione, let b = app.bundleIdentifier, !c.app.contains(b),
              b != "com.apple.finder", !lampi.èVeloce(b) else { return false }
        app.hide()
        tornaAllaScheda()
        let nome = app.localizedName ?? b
        avvisi.mostra(Avviso(icona: app.icon, titolo: "Aprire \(nome)?", testo: "Sei in Concentrazione",
                             scelte: [.init(titolo: "Aprila lo stesso") { [weak self] in
                                         guard let self, var x = self.stato.concentrazione else { return }
                                         x.app.insert(b); self.stato.concentrazione = x; self.salvaConcentrazione()
                                         self.ricostruisci(); app.unhide(); app.activate()
                                      },
                                      .init(titolo: "Resto concentrato", principale: true) {}]))
        return true
    }

    /// I numerini di adesso, per nome (per la differenza alla fine).
    func numeriniOra() -> [String: Int] {
        var n: [String: Int] = [:]
        for s in tutte { if let x = s.notifica.flatMap(Int.init) { n[s.nome, default: 0] += x } }
        return n
    }

    // MARK: - La fine (H-4)

    func fineConcentrazione(suono: Bool) {
        guard let c = stato.concentrazione else { return }
        if suono { NSSound(named: "Glass")?.play() }
        let minuti = Int(Date().timeIntervalSince(c.inizio) / 60 + 0.5)
        let arrivate = arrivateNelFrattempo(inizio: c.notificheInizio, fine: numeriniOra())
        palco.apri(FoglioFatto(c: self, minuti: minuti, arrivate: arrivate), sopra: pannello, posizione: stato.posizione) { [weak self] in
            self?.restaCosì()
        }
    }

    func riapriTutto() {
        palco.chiudiFoglio()
        stato.concentrazione = nil; salvaConcentrazione()
        if stato.nonDisturbare { esegui("/usr/bin/shortcuts", ["run", "Concentrazione off"]) }
        ricostruisci()
    }

    func altriDieci() {
        palco.chiudiFoglio()
        guard var c = stato.concentrazione else { return }
        c.fine = Date().addingTimeInterval(600)
        stato.concentrazione = c; salvaConcentrazione()
        controllaConcentrazione()
    }

    func restaCosì() {
        palco.chiudiFoglio()
        guard var c = stato.concentrazione else { return }
        c.fine = nil                                                  // senza tempo: si termina dal clic sul tempo
        stato.concentrazione = c; salvaConcentrazione()
    }
}

// MARK: - I fogli

struct FoglioConcentrazione: View {
    let c: Controllore
    @Bindable var stato: StatoBarra

    var body: some View {
        let scelte = stato.scelta ?? []
        Foglio(simbolo: "target", titolo: "Concentrazione", spiegazione: "Scegli le schede da tenere: le altre app si nascondono.",
               principale: "Inizia", principaleAcceso: !scelte.isEmpty,
               annulla: { stato.scelta = nil; c.palco.chiudiFoglio() }, conferma: { c.iniziaConcentrazione() }) {
            VStack(alignment: .leading, spacing: 0) {
                TitoloSezione(testo: "Durata")
                Parole(scelte: ["25 min", "50 min", "90 min"], scelta: "\(stato.minutiConc) min", grandi: true) { s in
                    stato.minutiConc = Int(s.prefix(2)) ?? 50
                }
                .padding(.horizontal, 14)
                TitoloSezione(testo: scelte.isEmpty ? "Schede da tenere: clicca nella barra" : "Schede da tenere · \(scelte.count)")
                ForEach(scelte, id: \.self) { k in
                    HStack(spacing: 8) {
                        if let s = c.scheda(k), let i = s.sito.flatMap({ stato.loghi[$0] }) ?? stato.icone[s.bid] {
                            Image(nsImage: i).resizable().frame(width: 20, height: 20)
                        }
                        Text(c.scheda(k)?.nome ?? k).font(.system(size: 14)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        Button { c.scegli(k) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.45)) }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).frame(height: 32)
                }
                let cartelle = stato.cartelle.filter { f in c.attive.contains(f.id) }
                if !cartelle.isEmpty {
                    TitoloSezione(testo: "Cartelle")
                    ForEach(cartelle, id: \.id) { f in
                        Button {
                            let sue = c.schede(di: f.id).map(\.chiave)
                            withAnimationMolla { stato.scelta = Array(Set(scelte + sue)) }
                        } label: {
                            HStack { Image(systemName: "square.stack.3d.up").foregroundStyle(Tema.accento); Text(f.nome).foregroundStyle(.white); Spacer() }
                                .font(.system(size: 13)).padding(.horizontal, 14).frame(height: 32).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                HStack {
                    Text("Non disturbare").font(.system(size: 14)).foregroundStyle(.white)
                    Spacer()
                    Parole(scelte: ["Sì", "No"], scelta: stato.nonDisturbare ? "Sì" : "No") { stato.nonDisturbare = $0 == "Sì" }
                }
                .padding(.horizontal, 14).padding(.top, 8).frame(height: 40)
            }
        }
    }
}

struct FoglioFatto: View {
    let c: Controllore
    let minuti: Int
    let arrivate: [(nome: String, quante: Int)]

    var body: some View {
        Foglio(simbolo: "checkmark.seal", titolo: "Fatto! \(minuti) minuti",
               spiegazione: arrivate.isEmpty ? "Nessuna notifica nel frattempo." : "Nel frattempo sono arrivate:",
               principale: "Riapri tutto", annullaTitolo: "Resta così", annulla: { c.restaCosì() }, conferma: { c.riapriTutto() }) {
            VStack(alignment: .leading, spacing: 0) {
                if !arrivate.isEmpty {
                    Text(arrivate.map { "\($0.nome) \($0.quante)" }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 4)
                }
                Button("Altri 10 minuti") { c.altriDieci() }.buttonStyle(.plain).font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
    }
}
