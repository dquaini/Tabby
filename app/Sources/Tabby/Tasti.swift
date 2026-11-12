import Carbon.HIToolbox
import Foundation

/// Le scorciatoie di Tabby: tutte partono da ⌃⌥ (control e option). Doppio meccanismo (K-1):
/// - registrate presso macOS (arrivano solo queste combinazioni);
/// - un **intercettatore** che le vede prima dell'app davanti, perché alcune app si prendono la
///   tastiera (Windows App, il desktop remoto del lavoro): guarda solo se sono premuti ⌃⌥ e
///   lascia passare tutto il resto senza leggerlo.
/// Se la stessa scorciatoia arriva dai due entro 0,3 s conta una volta sola.
@MainActor
final class Tasti {
    static var azioni: [UInt32: () -> Void] = [:]
    /// (tasto, con ⇧) → numero della scorciatoia, per l'intercettatore
    static var combinazioni: [Int: UInt32] = [:]
    /// ⌘Spazio visto dall'intercettatore (per il velo di Spotlight)
    static var suSpotlight: (() -> Void)?
    static var suSchermoIntero: (() -> Void)?
    private static var ultime: [UInt32: (quando: Date, daIntercettatore: Bool)] = [:]
    private var intercettatore: CFMachPort?
    private var controllo: Timer?
    private var registrate: [EventHotKeyRef] = []
    private var temporanei: [(EventHotKeyRef, UInt32)] = []
    private var gruppi: [String: [(EventHotKeyRef, UInt32)]] = [:]
    private var gestore: EventHandlerRef?

    init() {
        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, evento, _ in
            var id = EventHotKeyID()
            GetEventParameter(evento, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let n = id.id
            MainActor.assumeIsolated { Tasti.scatta(n, daIntercettatore: false) }
            return noErr
        }, 1, &tipo, nil, &gestore)
        accendiIntercettatore()
    }

    /// Una scorciatoia, da uno dei due meccanismi: due arrivi ravvicinati da strade diverse = una.
    static func scatta(_ n: UInt32, daIntercettatore: Bool) {
        guard let a = azioni[n] else { return }
        if let u = ultime[n], u.daIntercettatore != daIntercettatore, Date().timeIntervalSince(u.quando) < 0.3 { return }
        ultime[n] = (Date(), daIntercettatore)
        a()
    }

    private static func chiave(_ tasto: Int, _ maiuscolo: Bool) -> Int { tasto * 2 + (maiuscolo ? 1 : 0) }

    /// Ogni scorciatoia ha un numero tutto suo, mai riusato (prima tre modi diversi di contarli
    /// potevano dare lo stesso numero a due scorciatoie).
    private static var ultimoNumero: UInt32 = 0
    private static func nuovoNumero() -> UInt32 { ultimoNumero += 1; return ultimoNumero }

    /// L'intercettatore (serve il permesso Accessibilità): macOS a volte lo spegne se è lento;
    /// si riaccende da solo, e ogni 5 s si controlla.
    private func accendiIntercettatore() {
        let maschera = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: maschera, callback: { _, tipo, evento, info in
            if tipo == .tapDisabledByTimeout || tipo == .tapDisabledByUserInput {
                if let info { let t = Unmanaged<Tasti>.fromOpaque(info).takeUnretainedValue()
                    MainActor.assumeIsolated { if let p = t.intercettatore { CGEvent.tapEnable(tap: p, enable: true) } } }
                return Unmanaged.passUnretained(evento)
            }
            let f = evento.flags
            // ⌘Spazio: Spotlight si apre → il velo (V-1); il tasto va comunque a macOS
            if f.contains(.maskCommand), !f.contains(.maskControl), !f.contains(.maskAlternate), !f.contains(.maskShift),
               evento.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Space) {
                DispatchQueue.main.async { MainActor.assumeIsolated { Tasti.suSpotlight?() } }
                return Unmanaged.passUnretained(evento)
            }
            // ⌃⌘F: schermo intero (Z-3); il tasto va comunque all'app
            if f.contains(.maskCommand), f.contains(.maskControl), !f.contains(.maskAlternate),
               evento.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_F) {
                DispatchQueue.main.async { MainActor.assumeIsolated { Tasti.suSchermoIntero?() } }
                return Unmanaged.passUnretained(evento)
            }
            // solo ⌃⌥ (con o senza ⇧), mai ⌘: tutto il resto passa senza guardarlo
            guard f.contains(.maskControl), f.contains(.maskAlternate), !f.contains(.maskCommand) else { return Unmanaged.passUnretained(evento) }
            let tasto = Int(evento.getIntegerValueField(.keyboardEventKeycode))
            let maiuscolo = f.contains(.maskShift)
            let trovata: UInt32? = MainActor.assumeIsolated {
                guard evento.getIntegerValueField(.keyboardEventAutorepeat) == 0 || [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow].contains(tasto)
                else { return Tasti.combinazioni[Tasti.chiave(tasto, maiuscolo)] == nil ? nil : 0 }
                return Tasti.combinazioni[Tasti.chiave(tasto, maiuscolo)]
            }
            guard let n = trovata else { return Unmanaged.passUnretained(evento) }
            if n != 0 { DispatchQueue.main.async { MainActor.assumeIsolated { Tasti.scatta(n, daIntercettatore: true) } } }
            return nil                                       // è di Tabby: l'app davanti non la riceve
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { diario("intercettatore dei tasti non disponibile (manca l'Accessibilità?)"); return }
        intercettatore = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        controllo = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let p = self?.intercettatore, !CGEvent.tapIsEnabled(tap: p) { CGEvent.tapEnable(tap: p, enable: true) } }
        }
    }

    /// Dopo il permesso Accessibilità arrivato a Tabby già aperta.
    func riprovaIntercettatore() { if intercettatore == nil { accendiIntercettatore() } }

    /// Un tasto senza ⌃⌥, solo per un momento (Esc e Invio mentre dividi lo schermo).
    func temporaneo(_ tasto: Int, _ azione: @escaping () -> Void) {
        let n = Tasti.nuovoNumero()
        Tasti.azioni[n] = azione
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(tasto), 0, EventHotKeyID(signature: 0x54424259, id: n), GetApplicationEventTarget(), 0, &ref)
        if let ref { temporanei.append((ref, n)) }
    }

    func togliTemporanei() {
        for (r, n) in temporanei { UnregisterEventHotKey(r); Tasti.azioni[n] = nil }
        temporanei = []
    }

    /// Un gruppo di scorciatoie che cambia (i Lampi): si toglie e si rimette senza riavviare.
    func gruppo(_ nome: String, tasto: Int, maiuscolo: Bool = false, modificatori: Bool = true, _ azione: @escaping () -> Void) {
        let n = Tasti.nuovoNumero()
        Tasti.azioni[n] = azione
        var ref: EventHotKeyRef?
        let mod = modificatori ? UInt32(controlKey | optionKey | (maiuscolo ? shiftKey : 0)) : 0
        RegisterEventHotKey(UInt32(tasto), mod, EventHotKeyID(signature: 0x54424259, id: n), GetApplicationEventTarget(), 0, &ref)
        if let ref { gruppi[nome, default: []].append((ref, n)) } else { Tasti.azioni[n] = nil; return }
        if modificatori { Tasti.combinazioni[Tasti.chiave(tasto, maiuscolo)] = n }
    }

    func togliGruppo(_ nome: String) {
        for (r, n) in gruppi[nome] ?? [] {
            UnregisterEventHotKey(r); Tasti.azioni[n] = nil
            Tasti.combinazioni = Tasti.combinazioni.filter { $0.value != n }
        }
        gruppi[nome] = nil
    }

    /// Il codice del tasto per una lettera (tastiera italiana e americana hanno le lettere allo stesso posto).
    static func codice(_ lettera: String) -> Int? {
        let t: [String: Int] = ["a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
                                "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
                                "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
                                "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
                                "y": kVK_ANSI_Y, "z": kVK_ANSI_Z]
        return t[lettera.lowercased()]
    }

    /// `aggiungi(kVK_ANSI_1) { … }` → ⌃⌥1
    func aggiungi(_ tasto: Int, maiuscolo: Bool = false, _ azione: @escaping () -> Void) {
        let n = Tasti.nuovoNumero()
        Tasti.azioni[n] = azione
        var ref: EventHotKeyRef?
        let mod = UInt32(controlKey | optionKey | (maiuscolo ? shiftKey : 0))
        let stato = RegisterEventHotKey(UInt32(tasto), mod, EventHotKeyID(signature: 0x54424259, id: n),
                                        GetApplicationEventTarget(), 0, &ref)
        if let ref { registrate.append(ref) } else { diario("scorciatoia non registrata (tasto \(tasto), errore \(stato))") }
        Tasti.combinazioni[Tasti.chiave(tasto, maiuscolo)] = n      // anche se macOS non l'ha presa
    }
}

import TabbyCore
