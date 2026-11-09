import Carbon.HIToolbox
import Foundation

/// Le scorciatoie di Tabby: tutte partono da ⌃⌥ (control e option). Registrate presso macOS
/// (non servono permessi e non spiano la tastiera: arrivano solo queste combinazioni).
@MainActor
final class Tasti {
    static var azioni: [UInt32: () -> Void] = [:]
    private var registrate: [EventHotKeyRef] = []
    private var temporanei: [(EventHotKeyRef, UInt32)] = []
    private var gestore: EventHandlerRef?

    init() {
        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, evento, _ in
            var id = EventHotKeyID()
            GetEventParameter(evento, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let n = id.id
            MainActor.assumeIsolated { Tasti.azioni[n]?() }
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
