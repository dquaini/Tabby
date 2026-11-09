import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Observation
import SwiftUI
import TabbyCore

/// Quello che la barra mostra. La vista lo legge; il Controllore lo aggiorna.
@MainActor @Observable
final class StatoBarra {
    var schede: [Scheda] = []
    var attiva: String?
    var posizione = Impostazioni.shared.posizione
    var scrivania = false
    var batteria = Batteria.Stato()
    var icone: [String: NSImage] = [:]
    var loghi: [String: NSImage] = [:]          // i loghi dei siti, per dominio
    var divisione: Divisione?                   // mentre si divide lo schermo
    var membri: [String: [Scheda]] = [:]        // vista divisa → le sue schede
    // cartelle
    var cartelle: [Cartella] = []
    var diChi: [String: Int] = [:]              // scheda → cartella attiva
    var membriCartella: [String: [Scheda]] = [:]
    var cartellaAperta: Int?                    // la vista cartella (F-6)
    var apertura: StatoApertura?
    // il foglio con le schede da scegliere (cartella, Concentrazione)
    var scelta: [String]?
    var nomeFoglio = ""
    var cartellaInModifica: Int?
    var vociExtra: [Voce] = []                  // app non aperte aggiunte a una cartella
    var cercaApp = ""
    var foglioIlluminato = false
    // strumenti
    var ricerca: String?
    var sceltaRicerca = 0
    var confermaForte: String?
    var versioneTesti = 0
    var concentrazione: StatoConcentrazione?
    var minutiConc = 50
    var nonDisturbare = true
    var lampiCoperti: [String] = []
    var lampiInModifica: [Lampo] = []
    var inPausa = Impostazioni.shared.valore("paused") as? Bool ?? false
    var verticale: Bool { posizione == "left" || posizione == "right" }
}

/// Il regista di Tabby: ascolta macOS (app e finestre che si aprono, chiudono, riducono,
/// cambiano), ricostruisce le schede, risponde ai clic e alle scorciatoie.
@MainActor
final class Controllore {
    let stato = StatoBarra()
    let imp = Impostazioni.shared
    private(set) var pannello: PannelloBarra!
    var velo: VeloDivisione!
    private let batteria = Batteria()
    let tasti = Tasti()
    private let browser = Browser()
    private let loghi = Loghi()
    private let dock = NotificheDock()
    private var ricostruzione: DispatchWorkItem?
    private var osservatori: [pid_t: AXObserver] = [:]
    private var adattaDopo: DispatchWorkItem?
    /// chiave → finestra (per agire sulla scheda)
    var elementi: [String: AXUIElement] = [:]
    /// Tutte le schede, anche quelle dentro le viste divise (in barra c'è la vista al loro posto).
    var tutte: [Scheda] = []
    /// Le viste divise salvate.
    var viste: [VistaDivisa] = (Impostazioni.shared.valore("groups") as? [[String: Any]] ?? []).compactMap(VistaDivisa.init)
    var dopoVista: DispatchWorkItem?
    // cartelle (SPECIFICA 8)
    var cartelle: [Cartella] = (Impostazioni.shared.valore("folders") as? [[String: Any]] ?? []).compactMap(Cartella.init)
    var attive: [Int] = Impostazioni.shared.valore("activeFolders") as? [Int] ?? []
    var legami: [String: UInt32] = (Impostazioni.shared.valore("itemWins") as? [String: Int] ?? [:]).mapValues { UInt32($0) }
    var inArrivo: [String: (legame: String, quando: Date, note: Set<UInt32>)] = [:]
    var attivataIl: [Int: Date] = [:]
    var ultimaDi: [Int: String] = [:]            // l'ultima scheda usata di ogni cartella
    let palco = Palco()
    let avvisi = Avvisi()
    lazy var schermata = Schermata(stato: stato) { [weak self] in self?.chiudiApertura() }
    lazy var lampi = GestoreLampi(self)
    let testi = LettoreTesti()
    lazy var sfera = Sfera(self)
    lazy var finestraTabby = FinestraTabby(self)
    let attesaPermesso = AttesaPermesso()
    var sferaDopo: DispatchWorkItem?
    /// Le finestre ridotte da Tabby stessa (U-2): non fanno scattare «scheda accanto».
    private var ridotteDaTabby: [UInt32: Date] = [:]
    /// Le ultime schede attive con l'istante del cambio (C-4: macOS a volte attiva un'altra
    /// app un attimo prima di dire che la finestra è chiusa).
    var storia: [(chiave: String, quando: Date)] = []
    /// L'ultima volta che hai scelto tu una scheda (clic o scorciatoia).
    private var sceltaTua = Date.distantPast
    private(set) var precedente: Scheda?

    func avvia() {
        pannello = PannelloBarra(controllore: self)
        velo = VeloDivisione(controllore: self)
        stato.cartelle = cartelle
        avvisi.posizione = { [weak self] in self?.stato.posizione ?? "top" }
        avvisi.silenzio = { [weak self] in self?.stato.concentrazione != nil }
        testi.letto = { [weak self] in self?.stato.versioneTesti += 1 }
        Sistema.veloci = lampi.veloci
        registraLampi()
        riprendiConcentrazione()
        Tasti.spente = stato.inPausa
        stato.batteria = batteria.stato
        batteria.cambiata = { [weak self] b in self?.stato.batteria = b }
        browser.cambiato = { [weak self] in self?.ricostruisciPresto() }
        loghi.arrivato = { [weak self] d, i in self?.stato.loghi[d] = i }
        dock.cambiate = { [weak self] _ in self?.ricostruisciPresto() }
        dock.leggi()
        ascoltaMacOS()
        registraTasti()
        ricostruisci()
        if !stato.inPausa { pannello.mostra() }
        if let a = NSWorkspace.shared.frontmostApplication { siAttiva(a) }
        controllaSfera()
    }

    // MARK: - Ascoltare macOS

    private func ascoltaMacOS() {
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                  NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.ricostruisciPresto() }
            }
        }
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { if let app { self?.siAttiva(app) } }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pannello.mostra() }
        }
    }

    /// Un osservatore dell'Accessibilità per app: finestre aperte, chiuse, ridotte, riaperte,
    /// cambio di finestra in primo piano, titoli. Solo avvisi, nessun controllo periodico.
    private func osserva(_ pid: pid_t) {
        guard osservatori[pid] == nil else { return }
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, _, nome, ctx in
            guard let ctx else { return }
            let c = Unmanaged<Controllore>.fromOpaque(ctx).takeUnretainedValue()
            let n = nome as String
            MainActor.assumeIsolated {
                if n == kAXFocusedWindowChangedNotification { c.finestraCambiata() }
                c.ricostruisciPresto()
            }
        }, &obs) == .success, let obs else { return }
        let e = Sistema.elemento(pid), me = Unmanaged.passUnretained(self).toOpaque()
        for n in [kAXWindowCreatedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
                  kAXFocusedWindowChangedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(obs, e, n as CFString, me)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        osservatori[pid] = obs
    }

    /// Le finestre chiuse e i titoli cambiati si sentono solo osservando ogni finestra.
    private func osservaFinestra(_ w: AXUIElement, pid: pid_t) {
        guard let obs = osservatori[pid] else { return }
        let me = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(obs, w, kAXUIElementDestroyedNotification as CFString, me)
        AXObserverAddNotification(obs, w, kAXTitleChangedNotification as CFString, me)
    }

    // MARK: - Le schede

    /// Tanti avvisi insieme → una ricostruzione sola, 0,3 s dopo (S-8).
    func ricostruisciPresto() {
        ricostruzione?.cancel()
        let w = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.ricostruisci() } }
        ricostruzione = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
    }

    func ricostruisci() {
        misura("ricostruisci") {
            let vivi = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
            for p in osservatori.keys where !vivi.contains(p) { osservatori[p] = nil }
            var infos: [InfoApp] = [], el: [UInt32: AXUIElement] = [:]
            let spazio = Sistema.spazioApp(posizione: stato.posizione)
            let aperti = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            for b in browserNoti.keys where !aperti.contains(b) { browser.dimentica(b) }
            lampi.dimenticaChiusi()
            for app in Sistema.appVere() {
                osserva(app.processIdentifier)
                var (i, e) = Sistema.leggi(app)
                if browserNoti[i.bid] != nil { i = browser.arricchisci(app, i, e, spazio: spazio) }
                infos.append(i)
                for (n, w) in e { el[n] = w; osservaFinestra(w, pid: app.processIdentifier) }
                if stato.icone[i.bid] == nil, let ic = app.icon { stato.icone[i.bid] = ic }
            }
            let unite = imp.valore("joinWins") as? [String: Any] ?? [:]
            var nuove = costruisciSchede(infos, separate: { unite[$0] == nil },
                                         senzaFinestre: imp.valore("showWindowless") as? Bool ?? false,
                                         nomi: imp.valore("tabNames") as? [String: String] ?? [:])
            elementi = [:]
            for (n, s) in nuove.enumerated() {
                if let f = s.finestra, let w = el[f] { elementi[s.chiave] = w }
                // N-1: i numerini del Dock vanno sulla prima scheda dell'app
                if s.notifica == nil, s.chiave == s.bid, let d = dock.attuali[s.bid] { nuove[n].notifica = d }
                if let d = s.sito, stato.loghi[d] == nil, let l = loghi.logo(d) { stato.loghi[d] = l }
            }
            tutte = nuove
            // le viste divise: chi è chiuso esce, con meno di 2 app la vista si scioglie
            let v2 = aggiornaViste(viste, presenti: Set(nuove.map(\.chiave)))
            if v2 != viste { viste = v2; salvaViste() }
            let r = ordina(nuove, ordine: imp.ordine, preferite: imp.preferite)
            let ord = r.ordine.filter { k in !k.hasPrefix("g:") || viste.contains { $0.chiave == k } }
            if ord != imp.ordine { imp.imposta("order", ord) }
            // la scheda della vista al posto della sua prima app, poi l'ordine (anche della vista)
            let posto = Dictionary(ord.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
            let vis = conViste(r.schede, viste).enumerated()
                .sorted { (posto[$0.element.chiave] ?? .max, $0.offset) < (posto[$1.element.chiave] ?? .max, $1.offset) }
                .map(\.element)
            var m: [String: [Scheda]] = [:]
            for v in viste { m[v.chiave] = v.membri.compactMap { k in nuove.first { $0.chiave == k } } }
            if m != stato.membri { stato.membri = m }
            let visibili = filtraConcentrazione(applicaCartelle(vis))
            let prima = stato.schede
            if visibili != stato.schede { stato.schede = visibili }
            controllaChiusura(prima: prima)
            aggiornaAttiva()
            controllaSfera()
        }
    }

    /// C-4: chiusa o ridotta la scheda attiva → scheda accanto, sempre.
    private func controllaChiusura(prima: [Scheda]) {
        guard !stato.scrivania else { return }
        let ora = Date()
        ridotteDaTabby = ridotteDaTabby.filter { ora.timeIntervalSince($0.value) < 2 }
        // vive: anche le schede dentro una vista divisa o una scheda-cartella (non sono chiuse,
        // sono solo raccolte lì) — prima uscire da una cartella sembrava una chiusura e ci si
        // ritrovava dentro (9/11/2026)
        func chiusa(_ k: String) -> Bool { èChiusa(k, visibili: stato.schede, tutte: tutte) }
        // la scheda attiva, o quella di un attimo fa se nel frattempo macOS ha cambiato app
        var candidata: String?
        if let k = stato.attiva, chiusa(k) { candidata = k }
        else if storia.count >= 2, ora.timeIntervalSince(storia[storia.count - 1].quando) < 1.5,
                sceltaTua < storia[storia.count - 1].quando, chiusa(storia[storia.count - 2].chiave) {
            candidata = storia[storia.count - 2].chiave
        }
        guard let chiusa = candidata, let vecchia = prima.first(where: { $0.chiave == chiusa }) else { return }
        if let f = vecchia.finestra, ridotteDaTabby[f] != nil { return }
        if vecchia.ridotta { return }                       // era già ridotta: non è una chiusura adesso
        if ora.timeIntervalSince(sceltaTua) < 0.5 { return } // hai appena scelto tu dove andare
        guard let k = dopoLaChiusura(di: vecchia, prima: prima, adesso: stato.schede),
              let s = stato.schede.first(where: { $0.chiave == k }) else { return }
        diario("chiusa «\(vecchia.nome)» → «\(s.nome)»")
        vai(s, daTe: false)
    }

    // MARK: - Scheda attiva

    /// P-4: la scheda della finestra in primo piano; altrimenti la prima della stessa app.
    private func aggiornaAttiva() {
        guard !stato.scrivania, let app = NSWorkspace.shared.frontmostApplication,
              let bid = app.bundleIdentifier, !Sistema.ignorate().contains(bid) else { return }
        var k = tutte.first { $0.bid == bid }?.chiave
        if let w = Sistema.finestraAttiva(app.processIdentifier), let n = Sistema.numero(w),
           let s = tutte.first(where: { $0.finestra == n }) { k = s.chiave }
        guard var k else { return }
        if let i = viste.firstIndex(where: { $0.membri.contains(k) }) {   // dentro una vista divisa
            if viste[i].attenzione != k { viste[i].attenzione = k; salvaViste() }
            k = viste[i].chiave
        }
        if let id = stato.diChi[k] {                                      // dentro una cartella attiva
            ultimaDi[id] = k
            // stai guardando un'altra cartella: si passa alla vista di questa
            if let a = stato.cartellaAperta, a != id { stato.cartellaAperta = id; ricostruisciPresto() }
            if vistaCartelle && stato.cartellaAperta == nil { k = "f:\(id)" }
        } else if stato.cartellaAperta != nil && !stato.schede.contains(where: { $0.chiave == k }) {
            stato.cartellaAperta = nil; ricostruisciPresto()              // un'app fuori dalla cartella: vista generale
        }
        if k != stato.attiva { segnaAttiva(k) }
    }

    private func segnaAttiva(_ k: String) {
        if let a = stato.attiva, a != k { precedente = stato.schede.first { $0.chiave == a } }
        storia.append((k, Date())); if storia.count > 4 { storia.removeFirst() }
        withAnimationMolla { stato.attiva = k }
    }

    /// P-7: cambio di finestra dentro la stessa app (⌘`, clic su un'altra finestra).
    func finestraCambiata() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            MainActor.assumeIsolated { self?.aggiornaAttiva() }
        }
    }

    /// Quando un'app viene in primo piano (P-3): scheda attiva, una scheda alla volta, adatta.
    func siAttiva(_ app: NSRunningApplication) {
        guard !stato.inPausa, let bid = app.bundleIdentifier, bid != Sistema.mioBid else { return }
        ascoltaEscLampo(app)
        defer { lampi.aggiornaCoperti(); controllaSfera() }
        if Sistema.ignorate().contains(bid) { return }                  // un Lampo: non tocca niente
        if controllaAppFuori(app) { return }                            // fuori dalla Concentrazione
        if stato.scrivania && bid == "com.apple.finder" { return }
        stato.scrivania = false
        aggiornaAttiva()
        if !tutte.contains(where: { $0.bid == bid }) { ricostruisciPresto() }
        if let k = stato.attiva, let v = viste.first(where: { $0.chiave == k }) {
            // una finestra di una vista divisa: si ridispone tutta la vista (D-4), dopo 0,6 s
            if imp.unaAllaVolta { Sistema.nascondiAltre(tranne: bidDi(v)) }
            dopoVista?.cancel()
            let w = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.disponi(v) } }
            dopoVista = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
            return
        }
        if imp.unaAllaVolta { Sistema.nascondiAltre(tranne: [bid]) }
        if imp.adatta {
            Sistema.adatta(app, posizione: stato.posizione, tranne: finestreInViste())
            adattaDopo?.cancel()                                          // alcune app creano la finestra in ritardo
            let w = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, NSWorkspace.shared.frontmostApplication == app else { return }
                    Sistema.adatta(app, posizione: self.stato.posizione, tranne: self.finestreInViste())
                }
            }
            adattaDopo = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
        }
    }

    // MARK: - Passare da una scheda all'altra

    func vai(_ s: Scheda, daTe: Bool = true) {
        if stato.divisione != nil { assegna(s.chiave); return }          // mentre dividi: nella prima zona libera
        if stato.scelta != nil { scegli(s.chiave); return }              // un foglio aperto: scegli la scheda
        if s.chiave.hasPrefix("f:"), let id = Int(s.chiave.dropFirst(2)) { entraNellaCartella(id); return }
        if let v = viste.first(where: { $0.chiave == s.chiave }) {
            if daTe { sceltaTua = Date() }
            stato.scrivania = false
            segnaAttiva(v.chiave)
            mostraVista(v, scelta: true)
            return
        }
        guard let app = NSRunningApplication(processIdentifier: s.pid) else { ricostruisci(); return }
        if daTe { sceltaTua = Date() }
        stato.scrivania = false
        segnaAttiva(s.chiave)
        let w = elementi[s.chiave]
        Sistema.portaDavanti(app, finestra: w)
        // Non si aspetta l'avviso di macOS: se l'app era già davanti (es. dopo Scomponi) non
        // arriverebbe, e la finestra resterebbe della misura di prima.
        if imp.unaAllaVolta { Sistema.nascondiAltre(tranne: [s.bid]) }
        if imp.adatta { Sistema.adatta(app, posizione: stato.posizione, tranne: finestreInViste()) }
        // Le altre finestre della stessa app restano aperte dietro (deciso con Daniele il
        // 9/11/2026, al posto di U-2 che le riduceva nel Dock): hanno tutte la stessa misura,
        // quindi quella davanti le copre.
    }

    func vaiNumero(_ n: Int) { if n < stato.schede.count { vai(stato.schede[n]) } }

    /// ⌃⌥← / ⌃⌥→ (P-5): la scheda prima o dopo, in tondo.
    func scorri(_ passo: Int) {
        let s = stato.schede; guard !s.isEmpty else { return }
        guard let i = s.firstIndex(where: { $0.chiave == stato.attiva }) else { vai(passo > 0 ? s[0] : s[s.count - 1]); return }
        vai(s[(i + passo + s.count) % s.count])
    }

    /// ⌃⌥Tab (P-6): la scheda usata prima.
    func tornaIndietro() {
        guard let p = precedente, let s = stato.schede.first(where: { $0.chiave == p.chiave }) else { return }
        vai(s)
    }

    /// Chiudi Tabby (⚙︎ o ⌃⌥0; Daniele, 9/11/2026): le app si nascondono, resta la Scrivania del Mac
    /// con la sfera; Tabby ricorda dov'eri. Un clic sulla sfera (o ⌃⌥0 di nuovo) e torna tutto.
    func scrivania() {
        if stato.scrivania { riapriDaScrivania(); return }
        withAnimationMolla { stato.scrivania = true }
        for s in stato.schede where s.bid == "com.apple.finder" { if let f = s.finestra { ridotteDaTabby[f] = Date() } }
        Sistema.scrivania()
    }

    /// Dalla Scrivania del Mac si torna all'ultima scheda, come l'avevi lasciata.
    func riapriDaScrivania() {
        let s = stato.schede.first(where: { $0.chiave == stato.attiva }) ?? stato.schede.first
        stato.scrivania = false
        if let s { vai(s) }
    }

    /// Il gatto: una finestra del Finder sulla cartella Scrivania, come una scheda normale.
    func gatto() {
        stato.scrivania = false
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
    }

    func nuovaApp() { Sistema.apriSpotlight() }

    // MARK: - Chiudere

    func titolo(_ s: Scheda) -> String? { elementi[s.chiave].flatMap(Sistema.titolo) }

    func chiudiFinestra(_ s: Scheda) {
        if let w = elementi[s.chiave] ?? NSRunningApplication(processIdentifier: s.pid).flatMap({ Sistema.finestraAttiva($0.processIdentifier) }) {
            Sistema.chiudi(w)
        }
    }
    func chiudiApp(_ s: Scheda) { NSRunningApplication(processIdentifier: s.pid)?.terminate() }

    /// ⌃⌥W (C-2): chiude la finestra in primo piano, non l'app (in un browser la finestra intera).
    func chiudiFinestraDavanti() {
        guard let app = NSWorkspace.shared.frontmostApplication, let bid = app.bundleIdentifier,
              !Sistema.ignorate().contains(bid), let w = Sistema.finestraAttiva(app.processIdentifier),
              Sistema.èScheda(w) else { return }
        Sistema.chiudi(w)
    }

    // MARK: - Riordino e impostazioni

    /// T-1: la scheda trascinata va prima di `davanti` (nil = in fondo).
    func riordina(_ chiave: String, davanti: String?) {
        var o = imp.ordine
        let dentro: [String] = chiave.hasPrefix("f:") ? stato.membriCartella[chiave]?.map(\.chiave) ?? [] : [chiave]
        let prima = davanti.flatMap { d in d.hasPrefix("f:") ? stato.membriCartella[d]?.first?.chiave : d }
        for k in dentro { o = sposta(k, davanti: prima, in: o) }
        imp.imposta("order", o)
        withAnimationMolla { ricostruisci() }
    }

    func cambiaPosizione(_ p: String) {
        imp.imposta("position", p)
        withAnimationMolla { stato.posizione = p }
        pannello.mostra()
        if let a = NSWorkspace.shared.frontmostApplication { Sistema.adatta(a, posizione: p) }
        lampi.disponi()
        diario("posizione: \(p)")
    }

    func cambia(_ nome: String) {
        let ora = imp.valore(nome) as? Bool ?? true
        imp.imposta(nome, !ora)
    }

    private func registraTasti() {
        let numeri = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (i, t) in numeri.enumerated() { tasti.aggiungi(t) { [weak self] in self?.vaiNumero(i) } }
        tasti.aggiungi(kVK_ANSI_0) { [weak self] in self?.scrivania() }
        tasti.aggiungi(kVK_RightArrow) { [weak self] in self?.scorri(1) }
        tasti.aggiungi(kVK_LeftArrow) { [weak self] in self?.scorri(-1) }
        tasti.aggiungi(kVK_DownArrow) { [weak self] in if self?.stato.verticale == true { self?.scorri(1) } }
        tasti.aggiungi(kVK_UpArrow) { [weak self] in if self?.stato.verticale == true { self?.scorri(-1) } }
        tasti.aggiungi(kVK_Tab) { [weak self] in self?.tornaIndietro() }
        tasti.aggiungi(kVK_ANSI_W) { [weak self] in self?.chiudiFinestraDavanti() }
        tasti.aggiungi(kVK_ANSI_S) { [weak self] in self?.scambia() }
        tasti.aggiungi(kVK_Space) { [weak self] in self?.apriRicerca() }
        tasti.aggiungi(kVK_ANSI_Slash) { [weak self] in self?.apriFinestraTabby(sezione: "doc") }
        // ⌃⌥⇧1…9: le cartelle, nel loro ordine
        for (i, t) in numeri.enumerated() {
            tasti.aggiungi(t, maiuscolo: true) { [weak self] in
                guard let self, i < self.cartelle.count else { return }
                self.attivaCartella(self.cartelle[i].id)
            }
        }
    }
}

@MainActor func withAnimationMolla(_ fai: () -> Void) { withAnimation(Tema.molla, fai) }
