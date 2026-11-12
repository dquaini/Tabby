import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit
import SwiftUI
import TabbyCore

/// Il selettore con le anteprime (fase 1, deciso con Daniele il 12/11/2026; idea di AltTab).
/// ⌃⌥ tenuti + Tab: al centro dello schermo le schede in ordine d'uso, con la miniatura della
/// finestra; ogni Tab va avanti, ⇧Tab indietro, Esc annulla; lasciando ⌃⌥ si va alla scheda scelta.
/// Un Tab veloce (lasciato prima che il selettore compaia) torna alla scheda di prima, come sempre.
///
/// Le miniature: macOS non fa fotografare le finestre nascoste, e Tabby nasconde le altre app.
/// Allora ogni finestra si fotografa poco dopo che ci arrivi (in piccolo, solo in memoria) e il
/// selettore mostra l'ultima foto. Serve il permesso «Registrazione schermo»: Tabby non lo chiede
/// da sola; senza, le schede hanno l'icona dell'app e una riga per attivarlo.
@MainActor @Observable
final class StatoSelettore {
    var schede: [Scheda] = []
    var scelta = 0
    var aperto = false
}

@MainActor
final class Selettore {
    let s = StatoSelettore()
    private unowned let c: Controllore
    private var pannello: NSPanel?
    private var controllo: Timer?
    private var compare: DispatchWorkItem?
    /// Le foto delle finestre, per numero di finestra (solo in memoria, piccole).
    private(set) var foto: [UInt32: NSImage] = [:]
    private var fotoDopo: DispatchWorkItem?

    init(_ c: Controllore) { self.c = c }

    var permesso: Bool { CGPreflightScreenCaptureAccess() }

    // MARK: - Tab, ⇧Tab, Esc, i tasti lasciati

    /// ⌃⌥Tab (`avanti`) o ⌃⌥⇧Tab: apre il selettore o sposta la scelta.
    func tab(avanti: Bool) {
        if !s.aperto {
            s.schede = c.inOrdineDUso()
            guard s.schede.count > 1 else { return }
            s.aperto = true
            s.scelta = avanti ? 1 : s.schede.count - 1
            // compare solo se tieni premuto un attimo: un Tab veloce va e basta
            let w = DispatchWorkItem { [weak self] in self?.mostra() }
            compare = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: w)
            controllo = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.guardaITasti() }
            }
            c.tasti.temporaneo("selettore", kVK_Escape) { [weak self] in self?.chiudi(andando: false) }
            return
        }
        let n = s.schede.count
        withAnimation(.easeOut(duration: 0.12)) { s.scelta = (s.scelta + (avanti ? 1 : n - 1)) % n }
    }

    /// Lasciati ⌃ o ⌥: si va alla scheda scelta.
    private func guardaITasti() {
        let f = CGEventSource.flagsState(.combinedSessionState)
        if !f.contains(.maskControl) || !f.contains(.maskAlternate) { chiudi(andando: true) }
    }

    func scegli(_ i: Int) { s.scelta = i; chiudi(andando: true) }

    private func chiudi(andando: Bool) {
        guard s.aperto else { return }
        compare?.cancel(); compare = nil
        controllo?.invalidate(); controllo = nil
        c.tasti.togliTemporanei(di: "selettore")
        s.aperto = false
        pannello?.orderOut(nil)
        if andando, s.scelta < s.schede.count { c.vai(s.schede[s.scelta]) }
    }

    private func mostra() {
        guard s.aperto else { return }
        let p = pannello ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
            p.contentView = VistaOspite(rootView: VistaSelettore(sel: self, s: s, stato: c.stato))
            pannello = p
            return p
        }()
        p.setFrame(Sistema.schermo.frame, display: true)
        p.orderFrontRegardless()
        fotografaDavanti()                            // la finestra di adesso, aggiornata
    }

    // MARK: - Le foto

    /// Poco dopo l'arrivo su una scheda (si è appena sistemata): la sua foto. Solo col permesso.
    func arrivatoSu(_ s: Scheda) {
        fotoDopo?.cancel()
        guard permesso, s.finestra != nil else { return }
        let w = DispatchWorkItem { [weak self] in self?.fotografaDavanti() }
        fotoDopo = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: w)
    }

    private func fotografaDavanti() {
        guard permesso, let app = NSWorkspace.shared.frontmostApplication,
              let w = Sistema.finestraAttiva(app.processIdentifier), let n = Sistema.numero(w) else { return }
        Task { @MainActor [weak self] in
            guard let finestre = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true).windows,
                  let sw = finestre.first(where: { $0.windowID == n }) else { return }
            let conf = SCStreamConfiguration()
            let lato = max(sw.frame.width, sw.frame.height)
            let scala = min(1, 480 / max(lato, 1))                          // piccola: al massimo 480 punti
            conf.width = Int(sw.frame.width * scala * 2); conf.height = Int(sw.frame.height * scala * 2)
            conf.showsCursor = false
            guard let img = try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: sw), configuration: conf)
            else { return }
            self?.foto[n] = NSImage(cgImage: img, size: NSSize(width: sw.frame.width * scala, height: sw.frame.height * scala))
        }
    }

    /// Le finestre chiuse non servono più.
    func dimentica(tranne vive: Set<UInt32>) { foto = foto.filter { vive.contains($0.key) } }

    func chiediPermesso() { CGRequestScreenCaptureAccess() }
}

// MARK: - Il disegno

private struct VistaSelettore: View {
    let sel: Selettore
    @Bindable var s: StatoSelettore
    @Bindable var stato: StatoBarra

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(220), spacing: 14), count: min(5, max(1, s.schede.count))), spacing: 14) {
                ForEach(Array(s.schede.enumerated()), id: \.element.chiave) { i, x in scheda(x, i) }
            }
            if !sel.permesso {
                Button { sel.chiediPermesso() } label: {
                    Text("Per le anteprime delle finestre: permesso «Registrazione schermo» →")
                        .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6))
                }.buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(Color(white: 0.04).opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheda(_ x: Scheda, _ i: Int) -> some View {
        let su = s.scelta == i
        let icona = x.sito.flatMap { stato.loghi[$0] } ?? stato.icone[x.bid]
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05))
                if let f = x.finestra.flatMap({ sel.foto[$0] }) {
                    Image(nsImage: f).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8)).padding(4)
                } else if let icona {
                    Image(nsImage: icona).resizable().frame(width: 52, height: 52)
                }
            }
            .frame(width: 220, height: 138)
            HStack(spacing: 7) {
                if let icona { Image(nsImage: icona).resizable().frame(width: 16, height: 16) }
                Text(x.nome).font(.system(size: 13, weight: su ? .semibold : .regular)).foregroundStyle(.white.opacity(su ? 1 : 0.6)).lineLimit(1)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Tema.accento, lineWidth: su ? 2 : 0))
        .contentShape(Rectangle())
        .onTapGesture { sel.scegli(i) }
    }
}

extension Controllore {
    /// Le schede della barra in ordine d'uso: le più recenti prima, poi le altre nell'ordine della barra.
    func inOrdineDUso() -> [Scheda] {
        let vis = stato.schede
        let recenti = storiaUso.compactMap { k in vis.first { $0.chiave == k } }
        return recenti + vis.filter { s in !recenti.contains { $0.chiave == s.chiave } }
    }
}
