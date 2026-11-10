import AppKit
import TabbyCore

/// G-1: tre dita verso **sinistra** = scheda dopo, verso **destra** = scheda prima (come le
/// scrivanie di macOS). Un solo cambio per gesto, quando le dita si spostano del 15% della
/// larghezza del trackpad. Tabby legge i tocchi dagli eventi «gesture» di macOS (solo ascolto:
/// non li toglie a nessuno). Il gesto va tolto a macOS (Impostazioni di Sistema → Trackpad → Altri
/// gesti → «Scorri tra le app a tutto schermo»: quattro dita), se no lo fanno entrambi.
/// Consumo: con due dita (scorrere una pagina) per 150 ms non si guarda niente.
@MainActor
final class Gesti {
    var scorri: ((Int) -> Void)?
    private var ascolto: CFMachPort?
    private var inizio: CGFloat?
    private var fatto = false
    private var pausaFino = Date.distantPast
    static let spostamento: CGFloat = 0.15

    var acceso: Bool { Impostazioni.shared.valore("gestures") as? Bool ?? true }

    func aggiorna() {
        if acceso && ascolto == nil { accendi() }
        if !acceso, let a = ascolto { CGEvent.tapEnable(tap: a, enable: false); ascolto = nil }
    }

    private func accendi() {
        let gesto: UInt64 = 29                                   // NSEvent.EventType.gesture
        ascolto = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                    eventsOfInterest: CGEventMask(1 << gesto), callback: { _, tipo, evento, info in
            guard let info else { return Unmanaged.passUnretained(evento) }
            let g = Unmanaged<Gesti>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated {
                if tipo == .tapDisabledByTimeout { if let a = g.ascolto { CGEvent.tapEnable(tap: a, enable: true) } }
                else { g.tocco(evento) }
            }
            return Unmanaged.passUnretained(evento)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let a = ascolto else { diario("gesti: ascolto del trackpad non disponibile"); return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, a, 0), .commonModes)
        CGEvent.tapEnable(tap: a, enable: true)
    }

    private func tocco(_ evento: CGEvent) {
        guard !Tasti.spente else { return }
        if inizio == nil && Date() < pausaFino { return }
        guard let e = NSEvent(cgEvent: evento) else { return }
        let dita = e.allTouches().filter { $0.phase != .ended && $0.phase != .cancelled }
        guard dita.count == 3 else {                             // finito, o due dita che scorrono
            inizio = nil; fatto = false
            if !dita.isEmpty { pausaFino = Date().addingTimeInterval(0.15) }
            return
        }
        let x = dita.map(\.normalizedPosition.x).reduce(0, +) / 3
        guard let x0 = inizio else { inizio = x; return }
        if !fatto && abs(x - x0) > Gesti.spostamento {
            fatto = true
            scorri?(x < x0 ? 1 : -1)                             // dita verso sinistra → scheda dopo
        }
    }
}
