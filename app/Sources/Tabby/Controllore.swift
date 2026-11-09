import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Observation
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

/// Il regista di Tabby: ascolta macOS (app aperte, chiuse, in primo piano, finestre nuove),
/// ricostruisce le schede, risponde ai clic e alle scorciatoie.
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

    /// Le finestre aperte e chiuse dentro un'app: un osservatore dell'Accessibilità per app.
    private func osserva(_ pid: pid_t) {
        guard osservatori[pid] == nil else { return }
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, _, _, ctx in
            guard let ctx else { return }
            let c = Unmanaged<Controllore>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { c.ricostruisciPresto() }
        }, &obs) == .success, let obs else { return }
        let e = Sistema.elemento(pid), me = Unmanaged.passUnretained(self).toOpaque()
        for n in [kAXWindowCreatedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(obs, e, n as CFString, me)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        osservatori[pid] = obs
    }

    /// Le finestre chiuse si vedono osservando ogni finestra (macOS non lo dice all'app).
    private func osservaFinestre(_ pid: pid_t) {
        guard let obs = osservatori[pid] else { return }
        let me = Unmanaged.passUnretained(self).toOpaque()
        for w in Sistema.finestre(pid) {
            AXObserverAddNotification(obs, w, kAXUIElementDestroyedNotification as CFString, me)
        }
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
            let nomi = imp.valore("tabNames") as? [String: String] ?? [:]
            var nuove: [Scheda] = []
            let vivi = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
            for p in osservatori.keys where !vivi.contains(p) { osservatori[p] = nil }
            for app in Sistema.appSchede() {
                guard let bid = app.bundleIdentifier else { continue }
                nuove.append(Scheda(chiave: bid, bid: bid, nome: nomi[bid] ?? app.localizedName ?? bid, pid: app.processIdentifier))
                if stato.icone[bid] == nil, let i = app.icon { stato.icone[bid] = i }
                osserva(app.processIdentifier)
                osservaFinestre(app.processIdentifier)
            }
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular { osserva(app.processIdentifier) }
            let r = ordina(nuove, ordine: imp.ordine, preferite: imp.preferite)
            if r.ordine != imp.ordine { imp.imposta("order", r.ordine) }
            if r.schede != stato.schede { stato.schede = r.schede }
        }
    }

    // MARK: - Passare da una scheda all'altra

    /// Quando un'app viene in primo piano (P-3): scheda attiva, una scheda alla volta, adatta.
    func siAttiva(_ app: NSRunningApplication) {
        guard let bid = app.bundleIdentifier, bid != Sistema.mioBid else { return }
        if Sistema.ignorate().contains(bid) { return }                  // un Lampo: non tocca niente
        if stato.scrivania && bid == "com.apple.finder" { return }
        stato.scrivania = false
        if stato.attiva != bid, let k = stato.attiva { precedente = stato.schede.first { $0.chiave == k } }
        if stato.attiva != bid { withAnimationMolla { stato.attiva = bid } }
        if !stato.schede.contains(where: { $0.bid == bid }) { ricostruisciPresto() }
        if imp.unaAllaVolta { Sistema.nascondiAltre(tranne: bid) }
        if imp.adatta {
            Sistema.adatta(app, posizione: stato.posizione)
            adattaDopo?.cancel()                                          // alcune app creano la finestra in ritardo
            let w = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.stato.attiva == bid else { return }
                    Sistema.adatta(app, posizione: self.stato.posizione)
                }
            }
            adattaDopo = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
        }
    }

    /// La scheda usata prima (per «Torna a …» e, più avanti, ⌃⌥Tab).
    private(set) var precedente: Scheda?

    func titolo(_ s: Scheda) -> String? {
        NSRunningApplication(processIdentifier: s.pid).flatMap(Sistema.titoloFinestra)
    }

    func vai(_ s: Scheda) {
        guard let app = NSRunningApplication(processIdentifier: s.pid) else { ricostruisci(); return }
        if stato.attiva != s.chiave, let k = stato.attiva { precedente = stato.schede.first { $0.chiave == k } }
        stato.scrivania = false
        withAnimationMolla { stato.attiva = s.chiave }
        Sistema.portaDavanti(app)
    }

    func vaiNumero(_ n: Int) { if n < stato.schede.count { vai(stato.schede[n]) } }

    /// ⌃⌥← / ⌃⌥→ (P-5): la scheda prima o dopo, in tondo.
    func scorri(_ passo: Int) {
        let s = stato.schede; guard !s.isEmpty else { return }
        guard let i = s.firstIndex(where: { $0.chiave == stato.attiva }) else { vai(passo > 0 ? s[0] : s[s.count - 1]); return }
        vai(s[(i + passo + s.count) % s.count])
    }

    func scrivania() {
        if stato.scrivania, let k = stato.attiva, let s = stato.schede.first(where: { $0.chiave == k }) {
            stato.scrivania = false; vai(s); return                       // ripremuto: torna all'ultima scheda
        }
        withAnimationMolla { stato.scrivania = true }
        Sistema.scrivania()
    }

    func nuovaApp() { Sistema.apriSpotlight() }

    func chiudiFinestra(_ s: Scheda) {
        if let a = NSRunningApplication(processIdentifier: s.pid) { Sistema.chiudiFinestra(a) }
    }
    func chiudiApp(_ s: Scheda) { NSRunningApplication(processIdentifier: s.pid)?.terminate() }

    func cambiaPosizione(_ p: String) {
        imp.imposta("position", p)
        withAnimationMolla { stato.posizione = p }
        pannello.mostra()
        if let k = stato.attiva, let s = stato.schede.first(where: { $0.chiave == k }),
           let a = NSRunningApplication(processIdentifier: s.pid) { Sistema.adatta(a, posizione: p) }
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
        tasti.aggiungi(kVK_DownArrow) { [weak self] in self?.scorri(1) }
        tasti.aggiungi(kVK_UpArrow) { [weak self] in self?.scorri(-1) }
    }
}

import SwiftUI
@MainActor func withAnimationMolla(_ fai: () -> Void) { withAnimation(Tema.molla, fai) }
