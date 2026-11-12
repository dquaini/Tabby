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
    var tabbyChiusa = false                     // «Chiudi Tabby»: barra via, resta la sfera
    var suonano = Set<pid_t>()                  // le app che fanno suono (🔊 sulla scheda)
    var microfono = Set<pid_t>()                // le app che usano il microfono (🎙)
    var silenziate = Set<pid_t>()               // le app zittite da Tabby
    var rinomina: String?                       // la scheda che stai rinominando
    var nomeInModifica = ""
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
    let loghi = Loghi()
    private let dock = NotificheDock()
    private var ricostruzione: DispatchWorkItem?
    private var osservatori: [pid_t: AXObserver] = [:]
    private var finestreOsservate = Set<UInt32>()      // le finestre già ascoltate (chiusura, titolo)
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
    lazy var selettore = Selettore(self)
    lazy var cruscotto = Cruscotto(self)
    lazy var finestraTabby = FinestraTabby(self)
    let attesaPermesso = AttesaPermesso()
    var sferaDopo: DispatchWorkItem?
    var fineProgrammata: DispatchWorkItem?      // la fine della Concentrazione (H-4)
    var appPrimaRinomina: NSRunningApplication?
    var monitorMouse: Any?
    let avviataIl = Date()
    var vistaLaPrimaVolta: [UInt32: Date] = [:]     // quando Tabby ha visto ogni finestra (siti doppi)
    var doppiAvvisati = Set<UInt32>()
    var monitorMouseLocale: Any?
    var osservatoriMenu: [NSObjectProtocol] = []
    var osservatoreNotifiche: AXObserver?       // il Centro Notifiche (N-5)
    var ultimaNotaNotifiche = ""
    var menuAperto = false                      // un menu di Tabby è aperto
    /// Le ultime schede attive con l'istante del cambio (C-4: macOS a volte attiva un'altra
    /// app un attimo prima di dire che la finestra è chiusa).
    var storia: [(chiave: String, quando: Date)] = []
    var finestraScrivania: UInt32?               // la finestra del Finder aperta dal musetto
    let veloSpotlight = VeloSpotlight()
    var nellaCartella: (dominio: String, cartella: Int, quando: Date)?   // un sito aperto dalla ricerca dentro una cartella
    var primaVolta: [String: Date] = [:]          // quando è comparsa ogni scheda
    let gesti = Gesti()
    let audio = AudioSchede()
    let accessi = Accessi()
    var monitorClic: Any?
    var sitiScelti: [UInt32: String] = [:]       // B-8: il sito scelto per una finestra di browser
    var sitiVisti: [UInt32: [String]] = [:]       // B-8: i siti visti in ogni finestra di DuckDuckGo
    var scrivaniaDa = Date.distantPast           // quando si è andati sulla Scrivania (W-2)
    var ultimaFinestrella = Date.distantPast     // C-3
    var sceltaTua = Date.distantPast             // l'ultima volta che hai scelto tu una scheda
    private(set) var precedente: Scheda?

    func avvia() {
        tasti.riprovaIntercettatore()                   // se all'apertura mancava l'Accessibilità
        Tasti.suSpotlight = { [weak self] in self?.veloSpotlight.forse() }
        imp.imposta("autohide", nil)                    // un vecchio «Nascondi Tabby» non vale più (10/11/2026)
        imp.imposta("paused", nil)                      // la pausa non c'è più (Daniele, 12/11/2026)
        audio.cambiato = { [weak self] in
            guard let self else { return }
            withAnimationMolla {
                self.stato.suonano = self.audio.suonano; self.stato.microfono = self.audio.microfono
                self.stato.silenziate = Set(self.audio.silenziate.keys)
            }
        }
        audio.avvia()
        gesti.scorri = { [weak self] d in self?.scorri(d) }
        gesti.aggiorna()
        osservaSchermoIntero()
        defer { osservaNotifiche() }
        pannello = PannelloBarra(controllore: self)
        velo = VeloDivisione(controllore: self)
        stato.cartelle = cartelle
        avvisi.posizione = { [weak self] in self?.stato.posizione ?? "top" }
        avvisi.silenzio = { [weak self] in self?.stato.concentrazione != nil }
        testi.letto = { [weak self] in self?.stato.versioneTesti += 1 }
        Sistema.veloci = lampi.veloci
        registraLampi()
        riprendiConcentrazione()
        stato.batteria = batteria.stato
        batteria.cambiata = { [weak self] b in self?.stato.batteria = b }
        browser.cambiato = { [weak self] in self?.ricostruisciPresto() }
        loghi.arrivato = { [weak self] d, i in self?.stato.loghi[d] = i }
        dock.cambiate = { [weak self] _ in self?.ricostruisciPresto() }
        dock.leggi()
        ascoltaMacOS()
        registraTasti()
        ricostruisci()
        aggiornaMouse()
        if let a = NSWorkspace.shared.frontmostApplication { cruscotto.uso.davanti(a); siAttiva(a) }
        controllaSfera()
    }

    // MARK: - Ascoltare macOS

    private func ascoltaMacOS() {
        let nc = NSWorkspace.shared.notificationCenter
        func ascolta(_ n: Notification.Name, _ fai: @escaping @MainActor (Controllore, NSRunningApplication?) -> Void) {
            nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] nota in
                let app = nota.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated { if let self { fai(self, app) } }
            }
        }
        ascolta(NSWorkspace.didLaunchApplicationNotification) { c, _ in c.ricostruisciPresto() }
        // un'app chiusa del tutto (⌘Q): se macOS ti lascia sulla Scrivania vuota, si torna all'ultima scheda
        ascolta(NSWorkspace.didTerminateApplicationNotification) { c, a in c.ricostruisciPresto(); c.appChiusa(a?.bundleIdentifier) }
        ascolta(NSWorkspace.didHideApplicationNotification) { c, _ in c.ricostruisciPresto() }
        ascolta(NSWorkspace.didUnhideApplicationNotification) { c, _ in c.ricostruisciPresto() }
        ascolta(NSWorkspace.didActivateApplicationNotification) { c, a in
            guard let a else { return }
            c.cruscotto.uso.davanti(a)                      // il tempo d'uso di oggi
            c.siAttiva(a)
            // un'app che passa davanti con un pannello (la chat rapida di Claude…): il velo sotto
            if a.bundleIdentifier != Sistema.mioBid { c.veloSpotlight.forse(app: a.localizedName, pid: a.processIdentifier) }
        }
        ascolta(NSWorkspace.didDeactivateApplicationNotification) { c, _ in c.veloSpotlight.ricontrolla() }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mostraBarra() }
        }
    }

    /// Un osservatore dell'Accessibilità per app: finestre aperte, chiuse, ridotte, riaperte,
    /// cambio di finestra in primo piano, titoli. Solo avvisi, nessun controllo periodico.
    private func osserva(_ pid: pid_t) {
        guard osservatori[pid] == nil else { return }
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, el, nome, ctx in
            guard let ctx else { return }
            let c = Unmanaged<Controllore>.fromOpaque(ctx).takeUnretainedValue()
            let n = nome as String
            MainActor.assumeIsolated {
                if n == kAXWindowCreatedNotification {        // una finestrella d'accesso? (al centro, nello storico)
                    var p: pid_t = 0; AXUIElementGetPid(el, &p)
                    c.forseAccesso(el, pid: p)
                }
                if n == kAXFocusedWindowChangedNotification {
                    c.finestraCambiata()
                    // un pannello che prende la tastiera in un'app già davanti (la chat rapida di Claude con
                    // la sua scorciatoia): il velo sotto
                    var p: pid_t = 0; AXUIElementGetPid(el, &p)
                    if let a = NSRunningApplication(processIdentifier: p), a.bundleIdentifier != Sistema.mioBid {
                        c.veloSpotlight.forse(app: a.localizedName, pid: p)
                    }
                }
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
    /// Vero se l'ascolto è partito (si fa una volta per finestra).
    private func osservaFinestra(_ w: AXUIElement, pid: pid_t) -> Bool {
        guard let obs = osservatori[pid] else { return false }
        let me = Unmanaged.passUnretained(self).toOpaque()
        let a = AXObserverAddNotification(obs, w, kAXUIElementDestroyedNotification as CFString, me)
        AXObserverAddNotification(obs, w, kAXTitleChangedNotification as CFString, me)
        return a == .success || a == .notificationAlreadyRegistered
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
            for (p, o) in osservatori where !vivi.contains(p) {        // app chiusa: il suo ascolto si stacca del tutto
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
                osservatori[p] = nil
            }
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
                for (n, w) in e {
                    el[n] = w
                    if !finestreOsservate.contains(n), osservaFinestra(w, pid: app.processIdentifier) { finestreOsservate.insert(n) }
                }
                if stato.icone[i.bid] == nil, let ic = app.icon { stato.icone[i.bid] = ic }
            }
            let unite = imp.valore("joinWins") as? [String: Any] ?? [:]
            var nuove = costruisciSchede(infos, separate: { unite[$0] == nil },
                                         senzaFinestre: imp.valore("showWindowless") as? Bool ?? false,
                                         nomi: imp.valore("tabNames") as? [String: String] ?? [:])
            ricordaSitiVisti(nuove)
            mostraSitiScelti(&nuove)
            finestreOsservate.formIntersection(el.keys)              // le finestre chiuse si dimenticano
            selettore.dimentica(tranne: Set(el.keys))
            elementi = [:]
            for (n, s) in nuove.enumerated() {
                if let f = s.finestra, let w = el[f] { elementi[s.chiave] = w }
                // N-1: i numerini del Dock vanno sulla prima scheda dell'app
                if s.notifica == nil, s.chiave == s.bid, let d = dock.attuali[s.bid] { nuove[n].notifica = d }
                if let d = s.sito, stato.loghi[d] == nil, let l = loghi.logo(d) { stato.loghi[d] = l }
            }
            // la finestra della Scrivania aperta dal musetto è la scheda del gatto, non una scheda in più
            if let n = finestraScrivania {
                if nuove.contains(where: { $0.finestra == n }) { nuove.removeAll { $0.finestra == n } } else { finestraScrivania = nil }
            }
            let cambi = chiaviCambiate(prima: tutte, adesso: nuove)
            if !cambi.isEmpty { cambiaChiavi(cambi) }
            // quando è comparsa ogni scheda (quelle dei primi 15 s c'erano già)
            if Date().timeIntervalSince(avviataIl) > 15 { for s in nuove where primaVolta[s.chiave] == nil { primaVolta[s.chiave] = Date() } }
            primaVolta = primaVolta.filter { k, _ in nuove.contains { $0.chiave == k } }
            tutte = nuove
            mettiNellaCartella(nuove)
            controllaSitiDoppi(nuove)
            // i nomi dati alle finestre valgono finché la finestra è aperta
            if var nomi = imp.valore("tabNames") as? [String: String] {
                let n = nomi.count
                nomi = nomi.filter { k, _ in !k.hasPrefix("win:") || nuove.contains { $0.chiave == k } }
                if nomi.count != n { imp.imposta("tabNames", nomi) }
            }
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
            controllaFinestrella()
            aggiornaAttiva()
            controllaSfera()
        }
    }

    /// Una finestra ha cambiato chiave (vedi `chiaviCambiate`): tutto quello che si ricordava
    /// della vecchia passa alla nuova — posto, scheda attiva, viste divise, nome dato da te.
    private func cambiaChiavi(_ cambi: [String: String]) {
        imp.imposta("order", conChiaviNuove(imp.ordine, cambi))
        if let a = stato.attiva, let n = cambi[a] { stato.attiva = n }
        storia = storia.map { (cambi[$0.chiave] ?? $0.chiave, $0.quando) }
        var v2 = viste
        for i in v2.indices {
            v2[i].membri = v2[i].membri.map { cambi[$0] ?? $0 }
            if let a = v2[i].attenzione, let n = cambi[a] { v2[i].attenzione = n }
        }
        if v2 != viste { viste = v2; salvaViste() }
        if var nomi = imp.valore("tabNames") as? [String: String] {
            for (vecchia, nuova) in cambi where vecchia.hasPrefix("win:") { if let n = nomi.removeValue(forKey: vecchia) { nomi[nuova] = n } }
            imp.imposta("tabNames", nomi)
        }
        diario("stessa finestra, chiave nuova: " + cambi.map { "\($0.key) → \($0.value)" }.joined(separator: ", "))
    }

    /// Chiusa un'app che era tra le schede: macOS a volte mette davanti il Finder senza finestre (la
    /// Scrivania vuota, come chiudendo Goose). Allora si torna all'ultima scheda usata.
    private func appChiusa(_ bid: String?) {
        guard let bid, !stato.scrivania, !stato.tabbyChiusa, stato.schede.contains(where: { $0.bid == bid }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.stato.scrivania, let f = NSWorkspace.shared.frontmostApplication,
                  f.bundleIdentifier == "com.apple.finder", Sistema.finestraAttiva(f.processIdentifier) == nil else { return }
            diario("chiusa l'app \(bid), macOS lascia la Scrivania vuota: torno all'ultima scheda")
            self.tornaAllaScheda()
        }
    }

    /// C-3: chiusa una finestrella (accesso con Google, pagamento), all'app davanti restano solo
    /// finestre ridotte: 0,3 s dopo si riapre l'ultima usata, invece di lasciare il vuoto.
    private func controllaFinestrella() {
        guard !stato.scrivania, Date().timeIntervalSince(ultimaFinestrella) > 2,
              let app = NSWorkspace.shared.frontmostApplication, let bid = app.bundleIdentifier,
              !Sistema.ignorate().contains(bid), bid != "com.apple.finder" else { return }
        let sue = tutte.filter { $0.bid == bid && $0.finestra != nil }
        guard !sue.isEmpty, sue.allSatisfy(\.ridotta), Sistema.finestraAttiva(app.processIdentifier) == nil else { return }
        ultimaFinestrella = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, NSWorkspace.shared.frontmostApplication == app,
                  Sistema.finestraAttiva(app.processIdentifier) == nil else { return }
            let recenti = self.storiaUso
            guard let s = sue.min(by: { (recenti.firstIndex(of: $0.chiave) ?? 99) < (recenti.firstIndex(of: $1.chiave) ?? 99) }) else { return }
            diario("finestrella chiusa: riapro «\(s.nome)»")
            self.vai(s, daTe: false)
        }
    }

    /// C-4: chiusa o ridotta la scheda attiva → scheda accanto, sempre.
    private func controllaChiusura(prima: [Scheda]) {
        guard !stato.scrivania else { return }
        let ora = Date()
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
        if vecchia.ridotta { return }                       // era già ridotta: non è una chiusura adesso
        if ora.timeIntervalSince(sceltaTua) < 0.5 { return } // hai appena scelto tu dove andare
        // una scheda nata da sola da poco (un'app che si apre e si chiude da sé, una finestrella):
        // si torna dov'eri prima, non sulla scheda accanto
        // (solo se della sua app non resta niente: tra finestre della stessa app vale la più vicina)
        if let nata = primaVolta[chiusa], ora.timeIntervalSince(nata) < 20, !stato.schede.contains(where: { $0.bid == vecchia.bid }),
           let k = storiaUso.first(where: { k in k != chiusa && stato.schede.contains { $0.chiave == k } }),
           let s = stato.schede.first(where: { $0.chiave == k }) {
            diario("chiusa «\(vecchia.nome)», aperta da poco → torno a «\(s.nome)»")
            vai(s, daTe: false); return
        }
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

    func segnaAttiva(_ k: String) {
        if let a = stato.attiva, a != k { precedente = stato.schede.first { $0.chiave == a } }
        // l'ordine d'uso serve anche al selettore (⌃⌥Tab): si ricordano le ultime 30
        storia.append((k, Date())); if storia.count > 30 { storia.removeFirst() }
        withAnimationMolla { stato.attiva = k }
        if let s = stato.schede.first(where: { $0.chiave == k }) { selettore.arrivatoSu(s) }
    }

    /// P-7: cambio di finestra dentro la stessa app (⌘`, clic su un'altra finestra).
    func finestraCambiata() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            MainActor.assumeIsolated { self?.aggiornaAttiva() }
        }
    }

    /// Quando un'app viene in primo piano (P-3): scheda attiva, una scheda alla volta, adatta.
    func siAttiva(_ app: NSRunningApplication) {
        guard let bid = app.bundleIdentifier, bid != Sistema.mioBid else { return }
        if stato.rinomina != nil { fineRinomina(salva: true, torna: false) }   // sei andato altrove: il nome scritto resta
        ascoltaEscLampo(app)
        defer { lampi.aggiornaCoperti(); controllaSfera() }
        if Sistema.ignorate().contains(bid) { return }                  // un Lampo: non tocca niente
        // un'app che non sta nel Dock («Informazioni su questo Mac», le finestre delle app della barra
        // dei menu): non è una scheda e non nasconde le altre (prima si finiva sulla Scrivania)
        if app.activationPolicy != .regular { return }
        if controllaAppFuori(app) { return }                            // fuori dalla Concentrazione
        if stato.scrivania && bid == "com.apple.finder" { return }
        // W-2: subito dopo la Scrivania macOS a volte «rimbalza» su un'altra app: la si rinasconde
        if stato.scrivania && !stato.tabbyChiusa, Date().timeIntervalSince(scrivaniaDa) < 1.2, sceltaTua < scrivaniaDa {
            diario("rimbalzo su \(app.localizedName ?? bid) dopo la Scrivania: la rinascondo")
            app.hide()
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()
            return
        }
        // X-5: un pannello (la finestrella di Notion «vuoi registrare il meeting?»): non è una
        // scheda, non si ingrandisce e non nasconde le altre app (prima spariva anche il meeting)
        if browserNoti[bid] == nil, let p = Sistema.pannello(app, spazio: Sistema.spazioApp(posizione: stato.posizione)) {
            diario("pannello di \(app.localizedName ?? bid) (\(p)) · non nascondo le altre app")
            return
        }
        fuoriDallaScrivania()
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
            // alcune app (Spotify) si rimettono la loro misura un attimo dopo: un ultimo controllo,
            // e se ancora non va, una riga nel diario per capire perché
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                guard let self, !w.isCancelled, NSWorkspace.shared.frontmostApplication == app else { return }
                Sistema.adatta(app, posizione: self.stato.posizione, tranne: self.finestreInViste())
                let r = Sistema.dallAlto(Sistema.spazioApp(posizione: self.stato.posizione))
                if let f = Sistema.finestraAttiva(app.processIdentifier), let c = Sistema.cornice(f),
                   (Sistema.attributo(f, kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole,
                   abs(c.width - r.width) > 2 || abs(c.minX - r.minX) > 2 {
                    diario("\(app.localizedName ?? "?") non si adatta: chiesto \(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))×\(Int(r.height)), ha \(Int(c.minX)),\(Int(c.minY)) \(Int(c.width))×\(Int(c.height))")
                }
            }
        }
    }

    // MARK: - Passare da una scheda all'altra

    func vai(_ s: Scheda, daTe: Bool = true) {
        if stato.rinomina != nil { fineRinomina(salva: true, torna: false) }   // cambi scheda: il nome scritto si salva
        if stato.divisione != nil { assegna(s.chiave); return }          // mentre dividi: nella prima zona libera
        if stato.scelta != nil { scegli(s.chiave); return }              // un foglio aperto: scegli la scheda
        if s.chiave.hasPrefix("f:"), let id = Int(s.chiave.dropFirst(2)) { entraNellaCartella(id); return }
        if let v = viste.first(where: { $0.chiave == s.chiave }) {
            if daTe { sceltaTua = Date() }
            fuoriDallaScrivania()
            segnaAttiva(v.chiave)
            mostraVista(v, scelta: true)
            return
        }
        guard let app = NSRunningApplication(processIdentifier: s.pid) else { ricostruisci(); return }
        if daTe { sceltaTua = Date() }
        fuoriDallaScrivania()
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


    /// ⌃⌥0: la scheda Scrivania (il musetto del gatto); ripremuto torna all'ultima scheda.
    func scrivania() { if stato.scrivania { riapriDaScrivania() } else { gatto() } }

    /// Il musetto del gatto **è** la scheda Scrivania (Daniele, 9/11/2026): le app si nascondono,
    /// si vede la Scrivania del Mac, la barra resta col riempimento sul gatto.
    func gatto() {
        if stato.scrivania && !stato.tabbyChiusa { return }
        withAnimationMolla { stato.scrivania = true; stato.tabbyChiusa = false }
        scrivaniaDa = Date()
        // subito la finestra della Scrivania (porta davanti il Finder) e via le altre app nello
        // stesso momento; le finestre del Finder non si riducono più una per una (era lento)
        apriCartellaScrivania()
        Sistema.nascondiAltre(tranne: "com.apple.finder")
        controllaSfera()
    }

    /// Il musetto porta sul Finder con la Scrivania scelta (Daniele, 10/11/2026): una finestra del
    /// Finder sulla cartella Scrivania, che **è** la scheda del gatto (non compare in barra) e si
    /// chiude quando vai su un'altra scheda.
    private func apriCartellaScrivania() {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return }
        let pid = finder.processIdentifier
        if let n = finestraScrivania, let w = Sistema.finestre(pid).first(where: { Sistema.numero($0) == n }) {
            AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(w, kAXRaiseAction as CFString)
            finder.activate(); return
        }
        let già = Set(Sistema.finestre(pid).compactMap(Sistema.numero))
        NSWorkspace.shared.open(FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0])
        for t in [0.08, 0.16, 0.3, 0.6, 1.1] {   // il Finder ci mette un attimo a farla
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                guard let self, self.stato.scrivania, self.finestraScrivania == nil,
                      let w = Sistema.finestraAttiva(pid), let n = Sistema.numero(w), !già.contains(n) else { return }
                self.finestraScrivania = n                       // solo una finestra nuova: mai una tua
                Sistema.adattaFinestra(w, a: Sistema.spazioApp(posizione: self.stato.posizione))
                self.ricostruisciPresto()
            }
        }
    }

    /// Si lascia la Scrivania (un'altra scheda, la sfera): via la finestra del musetto.
    func fuoriDallaScrivania() {
        stato.scrivania = false; stato.tabbyChiusa = false
        guard let n = finestraScrivania else { return }
        finestraScrivania = nil
        if let f = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
           let w = Sistema.finestre(f.processIdentifier).first(where: { Sistema.numero($0) == n }) { Sistema.chiudi(w) }
    }

    /// Chiudi Tabby (⚙︎): come la Scrivania, ma la barra sparisce e resta la sfera; un clic e torna tutto.
    /// Tutto sparisce **in un colpo** (Daniele, 10/11/2026: prima le finestre ci mettevano troppo):
    /// macOS nasconde tutte le altre app con una sola richiesta, il Finder compreso, senza ridurre
    /// le sue finestre una per una; barra via e sfera subito, senza attese.
    func chiudiTabby() {
        fuoriDallaScrivania()
        withAnimationMolla { stato.scrivania = true; stato.tabbyChiusa = true }
        NSApp.activate()
        NSWorkspace.shared.hideOtherApplications()
        pannello.nascondiScivolando()
        sfera.mostra()
        controllaSfera()
    }

    /// Dalla Scrivania del Mac si torna all'ultima scheda, come l'avevi lasciata.
    func riapriDaScrivania() {
        let s = stato.schede.first(where: { $0.chiave == stato.attiva }) ?? stato.schede.first
        fuoriDallaScrivania()
        if let s { vai(s) }
    }

    func nuovaApp() { Sistema.apriSpotlight() }

    // MARK: - Finestre separate (S-3) e sito da mostrare (B-8), dal tasto destro

    /// S-3: le finestre di quest'app stanno in una scheda sola? (i browser mai)
    func finestreUnite(_ bid: String) -> Bool { (imp.valore("joinWins") as? [String: Any])?[bid] != nil }

    func uniscFinestre(_ bid: String, _ sì: Bool) {
        var d = imp.valore("joinWins") as? [String: Any] ?? [:]
        d[bid] = sì ? true : nil
        imp.imposta("joinWins", d)
        withAnimationMolla { ricostruisci() }
    }

    /// I siti di una finestra di browser. Chrome e Safari li dicono tutti; DuckDuckGo solo quello in
    /// vista, quindi Tabby si ricorda quelli visti in quella finestra (dal più recente, fino a 10).
    func siti(di s: Scheda) -> [String] {
        guard browserNoti[s.bid] != nil, let f = s.finestra else { return [] }
        var out: [String] = []
        for d in (s.indirizzi ?? []).compactMap(dominio) + (sitiVisti[f] ?? []) where !out.contains(d) { out.append(d) }
        return out
    }

    /// DuckDuckGo: a ogni ricostruzione il sito in vista di ogni finestra si aggiunge ai suoi «visti».
    private func ricordaSitiVisti(_ schede: [Scheda]) {
        let vive = Set(schede.compactMap(\.finestra))
        sitiVisti = sitiVisti.filter { vive.contains($0.key) }
        for s in schede {
            guard let f = s.finestra, let d = s.inVista.flatMap(dominio) else { continue }
            var v = sitiVisti[f] ?? []
            if v.first != d { v.removeAll { $0 == d }; v.insert(d, at: 0); sitiVisti[f] = Array(v.prefix(10)) }
            if stato.loghi[d] == nil, let l = loghi.logo(d) { stato.loghi[d] = l }   // per il menu «Mostra la scheda come»
        }
    }

    /// B-8: la scheda prende nome e logo del sito scelto finché quel sito è aperto nella finestra
    /// (con DuckDuckGo, che dice solo la scheda in vista, finché la finestra è aperta). "" = sempre il
    /// nome del browser («Mostra come DuckDuckGo»); nil = automatico.
    func scegliSito(_ s: Scheda, _ d: String?) {
        guard let f = s.finestra else { return }
        sitiScelti[f] = d
        ricostruisci()
    }

    private func mostraSitiScelti(_ schede: inout [Scheda]) {
        guard !sitiScelti.isEmpty else { return }
        let vive = Set(schede.compactMap(\.finestra))
        sitiScelti = sitiScelti.filter { vive.contains($0.key) }
        let nomi = imp.valore("tabNames") as? [String: String] ?? [:]
        for i in schede.indices {
            guard let f = schede[i].finestra, let d = sitiScelti[f] else { continue }
            if d.isEmpty {                                    // il nome e l'icona del browser, sempre
                if nomi[schede[i].chiave] == nil { schede[i].nome = browserNoti[schede[i].bid]?.breve ?? schede[i].nome }
                schede[i].sito = nil
                continue
            }
            if let u = schede[i].indirizzi, !u.contains(where: { dominio($0) == d }) { sitiScelti[f] = nil; continue }
            if nomi[schede[i].chiave] == nil { schede[i].nome = nomeSito(titolo: nil, dominio: d) }
            schede[i].sito = d
        }
    }

    // MARK: - Rinominare (B-8, DESIGN 3.2)

    func haNomeTuo(_ k: String) -> Bool {
        if k.hasPrefix("f:") { return false }
        return (imp.valore("tabNames") as? [String: String])?[k] != nil
    }

    /// Doppio clic sul nome o tasto destro → Rinomina: si scrive sulla scheda.
    func iniziaRinomina(_ k: String) {
        guard let s = stato.schede.first(where: { $0.chiave == k }) else { return }
        appPrimaRinomina = NSWorkspace.shared.frontmostApplication
        stato.nomeInModifica = s.nome
        stato.rinomina = k
        NSApp.activate()
        pannello.makeKey()
    }

    /// Invio salva, Esc annulla, vuoto = torna al nome di prima. Per una cartella cambia il suo nome.
    /// Cambiando scheda (o app) mentre scrivi, quello che hai scritto si salva (`torna: false`).
    func fineRinomina(salva: Bool, torna: Bool = true) {
        guard let k = stato.rinomina else { return }
        stato.rinomina = nil
        pannello.resignKey()
        if salva {
            let n = stato.nomeInModifica.trimmingCharacters(in: .whitespaces)
            if k.hasPrefix("f:"), let id = Int(k.dropFirst(2)), let i = cartelle.firstIndex(where: { $0.id == id }), !n.isEmpty {
                cartelle[i].nome = n; salvaCartelle()
            } else {
                var nomi = imp.valore("tabNames") as? [String: String] ?? [:]
                nomi[k] = n.isEmpty ? nil : n
                imp.imposta("tabNames", nomi)
            }
            ricostruisci()
        }
        if torna, let a = appPrimaRinomina, a.bundleIdentifier != Sistema.mioBid { a.activate() }
    }

    func tornaAlNome(_ k: String) {
        var nomi = imp.valore("tabNames") as? [String: String] ?? [:]
        nomi[k] = nil
        imp.imposta("tabNames", nomi)
        ricostruisci()
    }

    // MARK: - Chiudere

    func titolo(_ s: Scheda) -> String? { elementi[s.chiave].flatMap(Sistema.titolo) }

    func chiudiFinestra(_ s: Scheda) {
        if let w = elementi[s.chiave] ?? NSRunningApplication(processIdentifier: s.pid).flatMap({ Sistema.finestraAttiva($0.processIdentifier) }) {
            Sistema.chiudi(w)
        }
    }
    func chiudiApp(_ s: Scheda) { NSRunningApplication(processIdentifier: s.pid)?.terminate() }

    /// Doppio clic sulla ✕: se è la sola finestra dell'app si chiude l'app (Discord, Slack, Spotify
    /// chiudendo la finestra restano aperte in sottofondo); con altre finestre solo questa. Il
    /// Finder e i browser chiudono solo la finestra.
    func chiudiDavvero(_ s: Scheda) {
        let altre = tutte.contains { $0.bid == s.bid && $0.chiave != s.chiave }
        if altre || s.bid == "com.apple.finder" || browserNoti[s.bid] != nil { chiudiFinestra(s) } else { chiudiApp(s) }
    }

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
        aggiornaMouse()
        rimettiNotifiche()
        if let a = NSWorkspace.shared.frontmostApplication { Sistema.adatta(a, posizione: p) }
        lampi.disponi()
        diario("posizione: \(p)")
    }

    private func registraTasti() {
        let numeri = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (i, t) in numeri.enumerated() { tasti.aggiungi(t) { [weak self] in self?.vaiNumero(i) } }
        tasti.aggiungi(kVK_ANSI_0) { [weak self] in self?.scrivania() }
        tasti.aggiungi(kVK_RightArrow) { [weak self] in self?.scorri(1) }
        tasti.aggiungi(kVK_LeftArrow) { [weak self] in self?.scorri(-1) }
        tasti.aggiungi(kVK_DownArrow) { [weak self] in if self?.stato.verticale == true { self?.scorri(1) } }
        tasti.aggiungi(kVK_UpArrow) { [weak self] in if self?.stato.verticale == true { self?.scorri(-1) } }
        tasti.aggiungi(kVK_Tab) { [weak self] in self?.selettore.tab(avanti: true) }
        tasti.aggiungi(kVK_Tab, maiuscolo: true) { [weak self] in self?.selettore.tab(avanti: false) }
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
