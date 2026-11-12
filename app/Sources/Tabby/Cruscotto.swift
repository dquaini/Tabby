import AppKit
import Carbon.HIToolbox
import IOKit
import SwiftUI
import TabbyCore

/// Il centro di controllo, il «cruscotto» (fase 1, bozza approvata da Daniele il 12/11/2026): un
/// tasto nella barra al posto della batteria; un clic apre un pannello nello stile dei fogli di
/// Tabby, con le tessere scelte da te (ora, batteria, meteo, musica, borsa, Mac, tempo d'uso).
/// **Componibile**: «modifica →» toglie, riordina e aggiunge; lo stesso dalle Preferenze.
/// A pannello chiuso non costa niente: i dati si chiedono solo quando lo apri (meteo al massimo
/// ogni ora, borsa ogni 15 minuti, processore e memoria ogni 2 secondi mentre è aperto).
@MainActor @Observable
final class StatoCruscotto {
    var aperto = false
    var modifica = false
    var tessere: [Tessera] = TabbyCore.tessere(da: Impostazioni.shared.valore("ccTessere") as? [String])
    var città = (Impostazioni.shared.valore("ccCitta") as? [String: Any])?["nome"] as? String
    var meteo: Meteo?
    var meteoErrore: String?
    var giornoDa = 1                           // il primo dei giorni mostrati (0 = oggi)
    var musica: (titolo: String, artista: String, suona: Bool)?
    var quotazioni: [Quotazione] = []
    var borsaErrore = false
    var titoli: [String] = Impostazioni.shared.valore("ccTitoli") as? [String] ?? titoliDiSerie
    var processore: Double?
    var memoria: (usata: Double, totale: Double)?
    var gpu: Int?
    var uso: [(nome: String, secondi: Double)] = []
}

@MainActor
final class Cruscotto {
    let s = StatoCruscotto()
    private unowned let c: Controllore
    private var pannello: PannelloCruscotto?
    private var misure: Timer?
    private var fuori: [Any] = []
    private var meteoDel = Date.distantPast, borsaDel = Date.distantPast
    private var tickPrima: (occupati: UInt64, totali: UInt64)?
    private var appPrima: NSRunningApplication?
    let uso = ContaUso()

    init(_ c: Controllore) { self.c = c }

    // MARK: - Aprire e chiudere

    func clic() { s.aperto ? chiudi() : apri() }

    func apri(modifica: Bool = false) {
        s.modifica = modifica
        s.aperto = true
        let p = pannello ?? {
            let p = PannelloCruscotto()
            p.contentView = VistaOspite(rootView: VistaCruscotto(cc: self, s: s, stato: c.stato))
            pannello = p
            return p
        }()
        aggiorna()
        posiziona(p)
        p.orderFrontRegardless()
        if modifica { prendiLaTastiera() }
        // un clic fuori dal pannello (e fuori dal tasto) lo chiude; Esc anche
        fuori = [NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                    MainActor.assumeIsolated { self?.forseFuori() } } as Any,
                 NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
                    MainActor.assumeIsolated { self?.forseFuori() }; return e } as Any]
        c.tasti.temporaneo(kVK_Escape) { [weak self] in self?.chiudi() }
        misure = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.leggiMac() }
        }
    }

    func chiudi() {
        guard s.aperto else { return }
        s.aperto = false; s.modifica = false
        misure?.invalidate(); misure = nil
        for m in fuori { NSEvent.removeMonitor(m) }; fuori = []
        c.tasti.togliTemporanei()
        pannello?.orderOut(nil)
        if let a = appPrima, a.bundleIdentifier != Sistema.mioBid { a.activate() }
        appPrima = nil
    }

    /// Per scrivere (città, titoli) il pannello prende la tastiera; chiudendo torna all'app di prima.
    func prendiLaTastiera() {
        if appPrima == nil, let f = NSWorkspace.shared.frontmostApplication, f.bundleIdentifier != Sistema.mioBid { appPrima = f }
        NSApp.activate(); pannello?.makeKey()
    }

    private func forseFuori() {
        let p = NSEvent.mouseLocation
        if let f = pannello?.frame, f.contains(p) { return }
        if let t = cornice(del: "cruscotto"), t.contains(p) { return }        // il tasto stesso: ci pensa lui
        chiudi()
    }

    /// Dove sta un tasto della barra, sullo schermo.
    private func cornice(del id: String) -> CGRect? {
        guard let r = CorniceMenu.cornici[id], let w = c.pannello?.frame else { return nil }
        return CGRect(x: w.minX + r.minX, y: w.maxY - r.maxY, width: r.width, height: r.height)
    }

    /// Attaccato al tasto, dal lato delle app (come i menu), sempre tutto dentro lo schermo.
    func posiziona(_ p: NSPanel? = nil) {
        guard let p = p ?? pannello, let v = p.contentView else { return }
        let d = v.fittingSize, schermo = Sistema.schermo.visibleFrame
        let t = cornice(del: "cruscotto") ?? CGRect(x: schermo.maxX - 40, y: schermo.maxY - 40, width: 34, height: 34)
        let barra = c.pannello?.frame ?? .zero
        var o: CGPoint
        switch c.stato.posizione {
        case "right": o = CGPoint(x: barra.minX - d.width - 6, y: t.maxY - d.height)
        case "left": o = CGPoint(x: barra.maxX + 6, y: t.maxY - d.height)
        case "bottom": o = CGPoint(x: t.maxX - d.width, y: barra.maxY + 6)
        default: o = CGPoint(x: t.maxX - d.width, y: barra.minY - d.height - 6)
        }
        o.x = min(max(o.x, schermo.minX + 8), schermo.maxX - d.width - 8)
        o.y = min(max(o.y, schermo.minY + 8), schermo.maxY - d.height - 8)
        p.setFrame(CGRect(origin: o, size: d), display: true)
    }

    // MARK: - Componibile

    func salvaTessere(_ t: [Tessera]) {
        s.tessere = t
        c.imp.imposta("ccTessere", t.map(\.rawValue))
        DispatchQueue.main.async { [weak self] in self?.posiziona() }
    }

    func cambiaCittà(_ nome: String) {
        let n = nome.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, let q = n.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let u = URL(string: "https://geocoding-api.open-meteo.com/v1/search?count=1&language=it&name=\(q)") else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let (dati, _) = try? await URLSession.shared.data(from: u), let x = città(da: dati) else {
                self.s.meteoErrore = "Non trovo «\(n)»"; return
            }
            self.c.imp.imposta("ccCitta", ["nome": x.nome, "lat": x.lat, "lon": x.lon])
            self.s.città = x.nome; self.s.meteoErrore = nil
            self.meteoDel = .distantPast
            self.leggiMeteo()
        }
    }

    func cambiaTitoli(_ testo: String) {
        s.titoli = titoli(da: testo)
        c.imp.imposta("ccTitoli", s.titoli)
        borsaDel = .distantPast; leggiBorsa()
    }

    /// Le app per la musica che hai installato (si sceglie quale nelle Preferenze o nel pannello).
    static let appMusica = [("com.spotify.client", "Spotify"), ("com.apple.Music", "Musica"), ("com.tidal.desktop", "Tidal")]
    var musicaInstallate: [(bid: String, nome: String)] {
        Cruscotto.appMusica.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.0) != nil }.map { ($0.0, $0.1) }
    }
    var musicaScelta: String? {
        let b = c.imp.valore("ccMusica") as? String
        return musicaInstallate.first { $0.bid == b }?.bid ?? musicaInstallate.first?.bid
    }
    func scegliMusica(_ bid: String) { c.imp.imposta("ccMusica", bid); leggiMusica() }

    // MARK: - I dati (solo a pannello aperto)

    private func aggiorna() {
        leggiMac()
        if s.tessere.contains(.meteo) { leggiMeteo() }
        if s.tessere.contains(.borsa) { leggiBorsa() }
        if s.tessere.contains(.musica) { leggiMusica() }
        if s.tessere.contains(.uso) { s.uso = uso.oggi() }
    }

    private func leggiMeteo() {
        guard Date().timeIntervalSince(meteoDel) > 3600, let d = c.imp.valore("ccCitta") as? [String: Any],
              let lat = d["lat"] as? Double, let lon = d["lon"] as? Double,
              let u = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=7")
        else { return }
        meteoDel = Date()
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let (dati, _) = try? await URLSession.shared.data(from: u), let m = meteo(da: dati) { self.s.meteo = m; self.s.meteoErrore = nil }
            else { self.s.meteoErrore = "Meteo non disponibile"; self.meteoDel = .distantPast }
            self.posiziona()
        }
    }

    private func leggiBorsa() {
        guard Date().timeIntervalSince(borsaDel) > 900, !s.titoli.isEmpty else { return }
        borsaDel = Date()
        let titoli = s.titoli
        Task { @MainActor [weak self] in
            var trovate: [Quotazione] = []
            for t in titoli {
                guard let q = t.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                      let u = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(q)?range=1d&interval=1d") else { continue }
                var r = URLRequest(url: u); r.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                if let (dati, _) = try? await URLSession.shared.data(for: r), let x = quotazione(da: dati) { trovate.append(x) }
            }
            guard let self else { return }
            self.s.quotazioni = trovate
            self.s.borsaErrore = trovate.isEmpty
            if trovate.isEmpty { self.borsaDel = .distantPast }
            self.posiziona()
        }
    }

    // musica: Spotify e Musica si comandano con AppleScript; Tidal solo coi tasti multimediali
    private func leggiMusica() {
        guard let b = musicaScelta, let nome = Cruscotto.appMusica.first(where: { $0.0 == b })?.1 else { s.musica = nil; return }
        guard b != "com.tidal.desktop", NSRunningApplication.runningApplications(withBundleIdentifier: b).first != nil else {
            s.musica = (nome, b == "com.tidal.desktop" ? "comandi coi tasti multimediali" : "non è aperta", false); return
        }
        let app = b == "com.apple.Music" ? "Music" : "Spotify"
        Cruscotto.osascript("tell application \"\(app)\" to return (player state as text) & linefeed & (name of current track) & linefeed & (artist of current track)") { [weak self] r in
            let p = r.components(separatedBy: "\n")
            self?.s.musica = p.count >= 3 ? (p[1], p[2], p[0] == "playing") : (nome, "niente in ascolto", false)
        }
    }

    enum Comando { case indietro, pausa, avanti }
    func musica(_ k: Comando) {
        guard let b = musicaScelta else { return }
        if b == "com.tidal.desktop" { Cruscotto.tastoMultimediale(k == .pausa ? 16 : k == .avanti ? 17 : 18); return }
        let app = b == "com.apple.Music" ? "Music" : "Spotify"
        let cmd = k == .pausa ? "playpause" : k == .avanti ? "next track" : "previous track"
        Cruscotto.osascript("tell application \"\(app)\" to \(cmd)") { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.leggiMusica() }
        }
    }

    private static func osascript(_ script: String, _ fatto: @escaping @MainActor (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process(), out = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", script]
            p.standardOutput = out; p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return }
            let testo = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            p.waitUntilExit()
            DispatchQueue.main.async { MainActor.assumeIsolated { fatto(testo) } }
        }
    }

    /// Play/pausa (16), avanti (17), indietro (18): i tasti della tastiera del Mac.
    private static func tastoMultimediale(_ k: Int) {
        for giù in [true, false] {
            let dati = (k << 16) | ((giù ? 0xA : 0xB) << 8)
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: giù ? 0xA00 : 0xB00),
                               timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dati, data2: -1)?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    /// Processore (occupato fra due letture), memoria usata, scheda grafica.
    private func leggiMac() {
        guard s.tessere.contains(.mac) else { return }
        var n: natural_t = 0, info: processor_info_array_t?, conto: mach_msg_type_number_t = 0
        if host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &n, &info, &conto) == KERN_SUCCESS, let info {
            var occupati: UInt64 = 0, totali: UInt64 = 0
            for i in 0..<Int(n) {
                let b = Int(CPU_STATE_MAX) * i
                let u = UInt64(info[b + Int(CPU_STATE_USER)]), si = UInt64(info[b + Int(CPU_STATE_SYSTEM)])
                let ni = UInt64(info[b + Int(CPU_STATE_NICE)]), id = UInt64(info[b + Int(CPU_STATE_IDLE)])
                occupati += u + si + ni; totali += u + si + ni + id
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(conto) * vm_size_t(MemoryLayout<integer_t>.size))
            if let p = tickPrima, totali > p.totali { s.processore = Double(occupati - p.occupati) / Double(totali - p.totali) * 100 }
            tickPrima = (occupati, totali)
        }
        var v = vm_statistics64(), k = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let ok = withUnsafeMutablePointer(to: &v) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(k)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &k) } }
        if ok == KERN_SUCCESS {
            let pagina = Double(getpagesize())
            let usata = Double(UInt64(v.active_count) + UInt64(v.wire_count) + UInt64(v.compressor_page_count)) * pagina
            s.memoria = (usata / 1_073_741_824, Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
        }
        var it: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &it) == KERN_SUCCESS {
            var servizio = IOIteratorNext(it)
            while servizio != 0 {
                var p: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(servizio, &p, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let d = p?.takeRetainedValue() as? [String: Any], let st = d["PerformanceStatistics"] as? [String: Any],
                   let g = (st["Device Utilization %"] as? NSNumber)?.intValue { s.gpu = g }
                IOObjectRelease(servizio); servizio = IOIteratorNext(it)
            }
            IOObjectRelease(it)
        }
    }
}

/// Il pannello: non ruba la tastiera, tranne quando scrivi (città, titoli).
final class PannelloCruscotto: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false; backgroundColor = .clear; hasShadow = false; hidesOnDeactivate = false
    }
    override var canBecomeKey: Bool { true }
}

// MARK: - Il tempo d'uso (contato da Tabby, solo sul Mac)

/// Quanto tempo oggi in ogni app: si conta dal cambio d'app (nessun controllo periodico) e si
/// ferma quando lo schermo dorme. Si ricorda solo la giornata di oggi.
@MainActor
final class ContaUso {
    private var app: (bid: String, nome: String, da: Date)?
    private var giorno = ContaUso.oggiStringa()
    private var secondi: [String: Double] = [:]
    private var nomi: [String: String] = [:]

    init() {
        if let d = Impostazioni.shared.valore("usoOggi") as? [String: Any], d["giorno"] as? String == giorno {
            secondi = d["secondi"] as? [String: Double] ?? [:]; nomi = d["nomi"] as? [String: String] ?? [:]
        }
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.ferma() } }
        }
        for n in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if let a = NSWorkspace.shared.frontmostApplication { self?.davanti(a) } }
            }
        }
    }

    private static func oggiStringa() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    /// Un'app passa davanti.
    func davanti(_ a: NSRunningApplication) {
        ferma()
        guard a.activationPolicy == .regular, let b = a.bundleIdentifier, b != Sistema.mioBid else { return }
        app = (b, a.localizedName ?? b, Date())
    }

    private func ferma() {
        guard let a = app else { return }
        app = nil
        if ContaUso.oggiStringa() != giorno { giorno = ContaUso.oggiStringa(); secondi = [:]; nomi = [:] }
        secondi[a.bid, default: 0] += Date().timeIntervalSince(a.da)
        nomi[a.bid] = a.nome
        Impostazioni.shared.imposta("usoOggi", ["giorno": giorno, "secondi": secondi, "nomi": nomi])
    }

    /// Le app di oggi, dalla più usata (compresa quella davanti adesso).
    func oggi() -> [(nome: String, secondi: Double)] {
        var t = ContaUso.oggiStringa() == giorno ? secondi : [:]
        var n = nomi
        if let a = app { t[a.bid, default: 0] += Date().timeIntervalSince(a.da); n[a.bid] = a.nome }
        return t.sorted { $0.value > $1.value }.map { (n[$0.key] ?? $0.key, $0.value) }
    }
}
