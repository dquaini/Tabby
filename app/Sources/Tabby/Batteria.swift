import Foundation
import IOKit.ps

/// La batteria (L-5). Si rilegge solo quando macOS avvisa di un cambio: niente controlli
/// continui, niente consumo.
@MainActor
final class Batteria {
    struct Stato: Equatable { var presente = false; var livello = 0; var inCarica = false }
    private(set) var stato = Stato()
    var cambiata: ((Stato) -> Void)?
    private var sorgente: CFRunLoopSource?

    init() {
        leggi()
        let me = Unmanaged.passUnretained(self).toOpaque()
        if let s = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let b = Unmanaged<Batteria>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { b.leggi() }
        }, me)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), s, .defaultMode)
            sorgente = s
        }
    }

    func leggi() {
        var nuovo = Stato()
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let elenco = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for ps in elenco {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            nuovo.presente = true
            let cap = d[kIOPSCurrentCapacityKey] as? Int ?? 0, max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            nuovo.livello = max > 0 ? cap * 100 / max : cap
            nuovo.inCarica = (d[kIOPSIsChargingKey] as? Bool ?? false) || (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        }
        if nuovo != stato { stato = nuovo; cambiata?(nuovo) }
    }
}
