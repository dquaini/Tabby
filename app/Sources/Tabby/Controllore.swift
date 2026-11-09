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
    var verticale: Bool { posizione == "left" || posizione == "right" }
}

/// Il regista di Tabby: ascolta macOS (app e finestre che si aprono, chiudono, riducono,
/// cambiano), ricostruisce le schede, risponde ai clic e alle scorciatoie.
@MainActor
final class Controllore {
    let stato = StatoBarra()
    let imp = Impostazioni.shared
    private var pannello: PannelloBarra!
    private let batteria = Batteria()
    private let tasti = Tasti()
    private var ricostruzione: DispatchWorkItem?
    private var osservatori: [pid_t: AXObserver] = [:]
    private var adattaDopo: DispatchWorkItem?
    /// chiave → finestra (per agire sulla scheda)
    private var elementi: [String: AXUIElement] = [:]
    /// Le finestre ridotte da Tabby stessa (U-2): non fanno scattare «scheda accanto».
    private var ridotteDaTabby: [UInt32: Date] = [:]
    /// Le ultime schede attive con l'istante del cambio (C-4: macOS a volte attiva un'altra
    /// app un attimo prima di dire che la finestra è chiusa).
    private var storia: [(chiave: String, quando: Date)] = []
    /// L'ultima volta che hai scelto tu una scheda (clic o scorciatoia).
    private var sceltaTua = Date.distantPast
    private(set) var precedente: Scheda?

    func avvia() {
        pannello = PannelloBarra(controllore: self)
        stato.batteria = batteria.stato
        batteria.cambiata = { [weak self] b in self?.stato.batteria = b }
        ascoltaMacOS()
        registraTasti()
        ricostruisci()
        pannello.mostra()
        if let a = NSWorkspace.shared.frontmostApplication { siAttiva(a) }
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
            for app in Sistema.appVere() {
                osserva(app.processIdentifier)
                let (i, e) = Sistema.leggi(app)
                infos.append(i)
                for (n, w) in e { el[n] = w; osservaFinestra(w, pid: app.processIdentifier) }
                if stato.icone[i.bid] == nil, let ic = app.icon { stato.icone[i.bid] = ic }
            }
            let unite = imp.valore("joinWins") as? [String: Any] ?? [:]
            let nuove = costruisciSchede(infos, separate: { unite[$0] == nil },
                                         senzaFinestre: imp.valore("showWindowless") as? Bool ?? false,
                                         nomi: imp.valore("tabNames") as? [String: String] ?? [:])
            elementi = [:]
            for s in nuove { if let f = s.finestra, let w = el[f] { elementi[s.chiave] = w } }
            let r = ordina(nuove, ordine: imp.ordine, preferite: imp.preferite)
            if r.ordine != imp.ordine { imp.imposta("order", r.ordine) }
            let prima = stato.schede
            if r.schede != stato.schede { stato.schede = r.schede }
            controllaChiusura(prima: prima)
            aggiornaAttiva()
        }
    }

    /// C-4: chiusa o ridotta la scheda attiva → scheda accanto, sempre.
    private func controllaChiusura(prima: [Scheda]) {
        guard !stato.scrivania else { return }
        let ora = Date()
        ridotteDaTabby = ridotteDaTabby.filter { ora.timeIntervalSince($0.value) < 2 }
        let vive = Set(stato.schede.filter { !$0.ridotta }.map(\.chiave))
        // la scheda attiva, o quella di un attimo fa se nel frattempo macOS ha cambiato app
        var candidata: String?
        if let k = stato.attiva, !vive.contains(k) { candidata = k }
        else if storia.count >= 2, ora.timeIntervalSince(storia[storia.count - 1].quando) < 1.5,
                sceltaTua < storia[storia.count - 1].quando, !vive.contains(storia[storia.count - 2].chiave) {
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
        var k = stato.schede.first { $0.bid == bid }?.chiave
        if let w = Sistema.finestraAttiva(app.processIdentifier), let n = Sistema.numero(w),
           let s = stato.schede.first(where: { $0.finestra == n }) { k = s.chiave }
        if let k, k != stato.attiva { segnaAttiva(k) }
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
        guard let bid = app.bundleIdentifier, bid != Sistema.mioBid else { return }
        if Sistema.ignorate().contains(bid) { return }                  // un Lampo: non tocca niente
        if stato.scrivania && bid == "com.apple.finder" { return }
        stato.scrivania = false
        aggiornaAttiva()
        if !stato.schede.contains(where: { $0.bid == bid }) { ricostruisciPresto() }
        if imp.unaAllaVolta { Sistema.nascondiAltre(tranne: bid) }
        if imp.adatta {
            Sistema.adatta(app, posizione: stato.posizione)
            adattaDopo?.cancel()                                          // alcune app creano la finestra in ritardo
            let w = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, NSWorkspace.shared.frontmostApplication == app else { return }
                    Sistema.adatta(app, posizione: self.stato.posizione)
                }
            }
            adattaDopo = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
        }
    }

    // MARK: - Passare da una scheda all'altra

    func vai(_ s: Scheda, daTe: Bool = true) {
        guard let app = NSRunningApplication(processIdentifier: s.pid) else { ricostruisci(); return }
        if daTe { sceltaTua = Date() }
        stato.scrivania = false
        segnaAttiva(s.chiave)
        let w = elementi[s.chiave]
        Sistema.portaDavanti(app, finestra: w)
        // U-2: le altre finestre-scheda della stessa app si riducono (tornano quando le scegli)
        if daTe, s.finestra != nil {
            for altra in stato.schede where altra.bid == s.bid && altra.chiave != s.chiave && !altra.ridotta {
                guard let f = altra.finestra, let aw = elementi[altra.chiave] else { continue }
                ridotteDaTabby[f] = Date()
                Sistema.riduci(aw)
            }
        }
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

    func scrivania() {
        if stato.scrivania, let k = stato.attiva, let s = stato.schede.first(where: { $0.chiave == k }) {
            vai(s); return                                                 // ripremuto: torna all'ultima scheda
        }
        withAnimationMolla { stato.scrivania = true }
        for s in stato.schede where s.bid == "com.apple.finder" { if let f = s.finestra { ridotteDaTabby[f] = Date() } }
        Sistema.scrivania()
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
        let o = sposta(chiave, davanti: davanti, in: imp.ordine)
        imp.imposta("order", o)
        withAnimationMolla { ricostruisci() }
    }

    func cambiaPosizione(_ p: String) {
        imp.imposta("position", p)
        withAnimationMolla { stato.posizione = p }
        pannello.mostra()
        if let a = NSWorkspace.shared.frontmostApplication { Sistema.adatta(a, posizione: p) }
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
    }
}

@MainActor func withAnimationMolla(_ fai: () -> Void) { withAnimation(Tema.molla, fai) }
