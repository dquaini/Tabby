import Carbon.HIToolbox
import Foundation

/// Le scorciatoie di Tabby: tutte partono da ⌃⌥ (control e option). Registrate presso macOS
/// (non servono permessi e non spiano la tastiera: arrivano solo queste combinazioni).
@MainActor
final class Tasti {
    static var azioni: [UInt32: () -> Void] = [:]
    private var registrate: [EventHotKeyRef] = []
    private var temporanei: [(EventHotKeyRef, UInt32)] = []
    private var gruppi: [String: [(EventHotKeyRef, UInt32)]] = [:]
    /// In pausa (W-4) le scorciatoie passano alle app: Tabby non le usa.
    static var spente = false
    private var gestore: EventHandlerRef?

    init() {
        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, evento, _ in
            var id = EventHotKeyID()
            GetEventParameter(evento, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let n = id.id
            MainActor.assumeIsolated { if !Tasti.spente { Tasti.azioni[n]?() } }
            return noErr
        }, 1, &tipo, nil, &gestore)
    }

    /// Un tasto senza ⌃⌥, solo per un momento (Esc e Invio mentre dividi lo schermo).
    func temporaneo(_ tasto: Int, _ azione: @escaping () -> Void) {
        let n = UInt32(Tasti.azioni.count + 1000)
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
        let n = UInt32(5000 + gruppi.values.reduce(0) { $0 + $1.count } + Int.random(in: 0..<100000))
        Tasti.azioni[n] = azione
        var ref: EventHotKeyRef?
        let mod = modificatori ? UInt32(controlKey | optionKey | (maiuscolo ? shiftKey : 0)) : 0
        RegisterEventHotKey(UInt32(tasto), mod, EventHotKeyID(signature: 0x54424259, id: n), GetApplicationEventTarget(), 0, &ref)
        if let ref { gruppi[nome, default: []].append((ref, n)) } else { Tasti.azioni[n] = nil }
    }

    func togliGruppo(_ nome: String) {
        for (r, n) in gruppi[nome] ?? [] { UnregisterEventHotKey(r); Tasti.azioni[n] = nil }
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
        let n = UInt32(Tasti.azioni.count + 1)
        Tasti.azioni[n] = azione
        var ref: EventHotKeyRef?
        let mod = UInt32(controlKey | optionKey | (maiuscolo ? shiftKey : 0))
        let stato = RegisterEventHotKey(UInt32(tasto), mod, EventHotKeyID(signature: 0x54424259, id: n),
                                        GetApplicationEventTarget(), 0, &ref)
        if let ref { registrate.append(ref) } else { diario("scorciatoia non registrata (tasto \(tasto), errore \(stato))") }
    }
}

import TabbyCore
