import AppKit
import CoreAudio
import TabbyCore

/// L'audio sulle schede (fase 1, Daniele, 12/11/2026; dall'icona dell'altoparlante di Chrome):
/// sulla scheda di un'app che fa suono compare 🔊, su quella che usa il microfono 🎙 (macOS accende
/// il pallino arancione ma non dice chi); col tasto destro «Silenzia» zittisce **solo quell'app**.
///
/// Come: macOS (dalla 14) elenca i processi che suonano o ascoltano, e avvisa quando cambia —
/// nessun controllo periodico. Il suono dei browser parte da processi aiutanti: si risale all'app
/// «responsabile» (funzione interna di macOS, usata anche da Monitoraggio Attività; senza, si
/// usa il processo stesso). Silenziare usa i «tap» ufficiali di macOS: la prima volta chiede il
/// permesso di registrare l'audio delle altre app (Tabby non registra niente, lo azzera soltanto).
@MainActor
final class AudioSchede {
    var cambiato: (() -> Void)?
    private(set) var suonano = Set<pid_t>()
    private(set) var microfono = Set<pid_t>()
    private(set) var silenziate: [pid_t: [AudioObjectID]] = [:]     // app → i suoi tap
    private var ascoltati = Set<AudioObjectID>()

    private typealias Responsabile = @convention(c) (pid_t) -> pid_t
    private static let responsabile: Responsabile? =
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid").map { unsafeBitCast($0, to: Responsabile.self) }

    func avvia() {
        var a = AudioSchede.indirizzo(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.rileggi() }
        }
        rileggi()
    }

    /// Chi suona e chi ascolta adesso; i processi nuovi si ascoltano (una volta sola).
    private func rileggi() {
        var s = Set<pid_t>(), m = Set<pid_t>()
        for o in AudioSchede.processi() {
            if ascoltati.insert(o).inserted {
                for sel in [kAudioProcessPropertyIsRunningOutput, kAudioProcessPropertyIsRunningInput] {
                    var a = AudioSchede.indirizzo(sel)
                    AudioObjectAddPropertyListenerBlock(o, &a, .main) { [weak self] _, _ in MainActor.assumeIsolated { self?.rileggi() } }
                }
            }
            let app = AudioSchede.app(di: o)
            if AudioSchede.numero(o, kAudioProcessPropertyIsRunningOutput) != 0 { s.insert(app) }
            if AudioSchede.numero(o, kAudioProcessPropertyIsRunningInput) != 0 { m.insert(app) }
        }
        let vivi = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        for p in silenziate.keys where !vivi.contains(p) { riattiva(p) }
        guard s != suonano || m != microfono else { return }
        suonano = s; microfono = m
        cambiato?()
    }

    // MARK: - Silenziare una sola app

    func silenzia(_ pid: pid_t) {
        guard silenziate[pid] == nil else { return }
        let suoi = AudioSchede.processi().filter { AudioSchede.app(di: $0) == pid }
        var tap: [AudioObjectID] = []
        for o in suoi {
            let d = CATapDescription(stereoMixdownOfProcesses: [o])
            d.muteBehavior = .muted
            d.isPrivate = true
            var t = AudioObjectID(kAudioObjectUnknown)
            if AudioHardwareCreateProcessTap(d, &t) == noErr { tap.append(t) }
        }
        if tap.isEmpty { diario("audio: non riesco a silenziare \(pid) (permesso «registrare l'audio» negato?)"); return }
        silenziate[pid] = tap
        diario("audio: silenziata l'app \(NSRunningApplication(processIdentifier: pid)?.localizedName ?? "\(pid)")")
        cambiato?()
    }

    func riattiva(_ pid: pid_t) {
        guard let tap = silenziate.removeValue(forKey: pid) else { return }
        for t in tap { AudioHardwareDestroyProcessTap(t) }
        cambiato?()
    }

    // MARK: - Domande a Core Audio

    private static func indirizzo(_ s: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: s, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func processi() -> [AudioObjectID] {
        var a = indirizzo(kAudioHardwarePropertyProcessObjectList), dim: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &dim) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(dim) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &dim, &ids) == noErr else { return [] }
        return ids
    }

    private static func numero(_ o: AudioObjectID, _ s: AudioObjectPropertySelector) -> UInt32 {
        var a = indirizzo(s), x: UInt32 = 0, dim = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(o, &a, 0, nil, &dim, &x) == noErr ? x : 0
    }

    /// L'app a cui appartiene un processo audio (per i browser: l'app, non il suo aiutante).
    private static func app(di o: AudioObjectID) -> pid_t {
        var a = indirizzo(kAudioProcessPropertyPID), pid: pid_t = 0, dim = UInt32(MemoryLayout<pid_t>.size)
        AudioObjectGetPropertyData(o, &a, 0, nil, &dim, &pid)
        let r = responsabile?(pid) ?? pid
        return r > 0 ? r : pid
    }
}
