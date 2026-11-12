import AppKit
import CoreMedia
import ScreenCaptureKit
import TabbyCore

/// Tieni in vista (fase 1, Daniele, 12/11/2026; dal «picture in picture» di Chrome e dal «sempre in
/// primo piano» di Linux): tasto destro su una scheda → la sua finestra diventa un riquadro **dal
/// vivo**, sopra tutto, sul lato **sinistro** (i Lampi stanno a destra), in alto o in basso, piccolo
/// o medio. Un clic sul riquadro porta alla scheda; ✕ lo toglie.
///
/// macOS non lascia tenere sopra le finestre delle altre app: Tabby ne mostra la copia dal vivo
/// (ScreenCaptureKit, 5 immagini al secondo, alla misura del riquadro: consuma solo mentre c'è).
/// La copia funziona se la finestra non è nascosta: l'app tenuta in vista non si nasconde quando
/// cambi scheda (resta dietro le altre). Serve il permesso «Registrazione schermo».
@MainActor
final class TieniInVista {
    enum Dove: String { case altoPiccola, altoMedia, bassoPiccola, bassoMedia
        var inAlto: Bool { self == .altoPiccola || self == .altoMedia }
        var largo: CGFloat { self == .altoMedia || self == .bassoMedia ? 480 : 320 }
    }
    private unowned let c: Controllore
    private var riquadri: [UInt32: Riquadro] = [:]
    init(_ c: Controllore) { self.c = c }

    var tenute: Set<UInt32> { Set(riquadri.keys) }

    func tieni(_ s: Scheda, _ dove: Dove) {
        guard let n = s.finestra else { return }
        guard CGPreflightScreenCaptureAccess() else {
            c.avvisi.mostra(Avviso(simbolo: "rectangle.on.rectangle", titolo: "Serve il permesso «Registrazione schermo»",
                                   testo: "Per tenere in vista una finestra",
                                   scelte: [.init(titolo: "Dai il permesso", principale: true) { CGRequestScreenCaptureAccess() }]))
            return
        }
        lascia(n)
        let r = Riquadro(n: n, dove: dove, nome: s.nome, pronto: { [weak self] in self?.disponi() }) { [weak self] in
            guard let self, let x = self.c.tutte.first(where: { $0.finestra == n }) else { return }
            self.c.vai(x)
        } chiudi: { [weak self] in self?.lascia(n) }
        riquadri[n] = r
        aggiornaEsclusi()
        disponi()
        r.avvia()
        diario("tieni in vista: «\(s.nome)»")
    }

    func lascia(_ n: UInt32) {
        guard let r = riquadri.removeValue(forKey: n) else { return }
        r.ferma()
        aggiornaEsclusi()
        disponi()
    }

    /// Le finestre chiuse: via i loro riquadri.
    func dimentica(tranne vive: Set<UInt32>) { for n in riquadri.keys where !vive.contains(n) { lascia(n) } }

    /// Le app tenute in vista non si nascondono cambiando scheda (la copia dal vivo ne ha bisogno).
    private func aggiornaEsclusi() {
        Sistema.tenuteInVista = Set(riquadri.keys.compactMap { n in c.tutte.first { $0.finestra == n }?.bid })
    }

    /// In colonna sul lato sinistro dello spazio delle app: quelli in alto dall'alto, quelli in basso dal basso.
    func disponi() {
        let spazio = Sistema.spazioApp(posizione: c.stato.posizione)
        var yAlto = spazio.maxY - 12, yBasso = spazio.minY + 12
        for r in riquadri.values.sorted(by: { $0.n < $1.n }) {
            let d = r.misura
            if r.dove.inAlto { yAlto -= d.height; r.pannello.setFrame(CGRect(x: spazio.minX + 12, y: yAlto, width: d.width, height: d.height), display: true); yAlto -= 12 }
            else { r.pannello.setFrame(CGRect(x: spazio.minX + 12, y: yBasso, width: d.width, height: d.height), display: true); yBasso += d.height + 12 }
        }
    }
}

/// Un riquadro: il pannello sempre sopra e la copia dal vivo della finestra.
@MainActor
final class Riquadro: NSObject {
    let n: UInt32
    let dove: TieniInVista.Dove
    let pannello: NSPanel
    private let vista = NSView()
    private var stream: SCStream?
    private let uscita = UscitaRiquadro()
    private(set) var misura: CGSize

    private let pronto: @MainActor () -> Void

    init(n: UInt32, dove: TieniInVista.Dove, nome: String, pronto: @escaping @MainActor () -> Void,
         vai: @escaping @MainActor () -> Void, chiudi: @escaping @MainActor () -> Void) {
        self.n = n; self.dove = dove; self.pronto = pronto
        misura = CGSize(width: dove.largo, height: dove.largo * 0.62)
        pannello = PannelloRiquadro(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        pannello.level = .floating
        pannello.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        pannello.isOpaque = false; pannello.backgroundColor = .clear; pannello.hasShadow = true
        vista.wantsLayer = true
        vista.layer?.backgroundColor = NSColor.black.cgColor
        vista.layer?.cornerRadius = 12; vista.layer?.masksToBounds = true
        vista.layer?.contentsGravity = .resizeAspect
        (pannello as? PannelloRiquadro)?.vai = vai
        let x = NSButton(title: "✕", target: nil, action: nil)
        x.isBordered = false; x.contentTintColor = .white
        x.font = .systemFont(ofSize: 13, weight: .semibold)
        x.toolTip = "Non tenere più in vista «\(nome)»"
        let azione = AzioneMenu(title: "", action: nil, keyEquivalent: ""); azione.fai = chiudi
        x.target = azione; x.action = #selector(AzioneMenu.esegui)
        objc_setAssociatedObject(x, "azione", azione, .OBJC_ASSOCIATION_RETAIN)
        x.translatesAutoresizingMaskIntoConstraints = false
        vista.addSubview(x)
        NSLayoutConstraint.activate([x.topAnchor.constraint(equalTo: vista.topAnchor, constant: 6), x.trailingAnchor.constraint(equalTo: vista.trailingAnchor, constant: -8)])
        pannello.contentView = vista
        uscita.immagine = { [weak self] s in self?.vista.layer?.contents = s }
    }

    func avvia() {
        pannello.orderFrontRegardless()
        let n = n, larghezza = misura.width
        Task { @MainActor [weak self] in
            guard let self,
                  let finestre = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false).windows,
                  let sw = finestre.first(where: { $0.windowID == n }) else { diario("tieni in vista: finestra \(n) non trovata"); return }
            // la misura del riquadro segue le proporzioni della finestra
            self.misura = CGSize(width: larghezza, height: (larghezza * sw.frame.height / max(sw.frame.width, 1)).rounded())
            let conf = SCStreamConfiguration()
            conf.width = Int(self.misura.width * 2); conf.height = Int(self.misura.height * 2)
            conf.minimumFrameInterval = CMTime(value: 1, timescale: 5)            // 5 al secondo: basta e consuma poco
            conf.showsCursor = false; conf.queueDepth = 3
            let s = SCStream(filter: SCContentFilter(desktopIndependentWindow: sw), configuration: conf, delegate: nil)
            do {
                try s.addStreamOutput(self.uscita, type: .screen, sampleHandlerQueue: .main)
                try await s.startCapture()
                self.stream = s
                self.pronto()                                         // la misura giusta: si ridispone la colonna
            } catch { diario("tieni in vista: copia dal vivo non partita (\(error.localizedDescription))") }
        }
    }

    func ferma() {
        stream?.stopCapture { _ in }
        stream = nil
        pannello.orderOut(nil)
    }
}

/// Riceve le immagini dal vivo e le passa al riquadro (sulla coda principale).
final class UscitaRiquadro: NSObject, SCStreamOutput, @unchecked Sendable {
    var immagine: (@MainActor (IOSurface) -> Void)?
    func stream(_ stream: SCStream, didOutputSampleBuffer b: CMSampleBuffer, of tipo: SCStreamOutputType) {
        guard tipo == .screen, let px = CMSampleBufferGetImageBuffer(b), let s = CVPixelBufferGetIOSurface(px)?.takeUnretainedValue() else { return }
        nonisolated(unsafe) let superficie = s            // arriva sulla coda principale (sampleHandlerQueue: .main)
        MainActor.assumeIsolated { immagine?(superficie) }
    }
}

/// Un clic sul riquadro porta alla scheda.
final class PannelloRiquadro: NSPanel {
    var vai: (@MainActor () -> Void)?
    override func mouseDown(with event: NSEvent) { MainActor.assumeIsolated { vai?() } }
}
