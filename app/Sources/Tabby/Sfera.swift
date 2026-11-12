import AppKit
import SwiftUI
import TabbyCore

/// La sfera (SPECIFICA W-3/W-4, DESIGN 3.8): con Tabby chiusa, sulla Scrivania, Tabby è una sfera
/// viva in basso a destra, col gatto di Daniele, nei colori del tema. Reagisce al puntatore; al clic
/// riapre tutto (o, senza schede, il ventaglio). In Concentrazione ha l'anello che si consuma; mostra
/// il totale delle notifiche.
@MainActor @Observable
final class StatoSfera {
    var visibile = false
    var vicino: CGFloat = 0                  // 0 lontano … 1 sopra
    var verso: CGSize = .zero                // da -1 a 1: dove sta il puntatore
    var ventaglio = false
    var sopraPetalo: Int?
}

@MainActor
final class Sfera: NSPanel {
    let s = StatoSfera()
    private unowned let c: Controllore
    private var monitor: Any?
    static let lato: CGFloat = 440

    init(_ c: Controllore) {
        self.c = c
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        contentView = VistaOspite(rootView: VistaSfera(c: c, s: s, stato: c.stato))
    }

    /// I clic passano attraverso le parti trasparenti (solo sfera e petali li prendono).
    override var canBecomeKey: Bool { false }

    func mostra() {
        guard !s.visibile else { return }
        aggiornaMisura()
        orderFrontRegardless()
        withAnimation(Tema.molla) { s.visibile = true }
        // il puntatore si segue solo mentre la sfera c'è
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.puntatore() }
        }
    }

    /// La finestrella è piccola (prende i clic solo intorno alla sfera); col ventaglio aperto si allarga.
    func aggiornaMisura() {
        let v = Sistema.schermo.visibleFrame, lato: CGFloat = s.ventaglio ? Sfera.lato : 150
        // la sfera a 60 punti dai bordi, in basso a destra (il suo centro a 90 dall'angolo)
        setFrame(NSRect(x: v.maxX - lato, y: v.minY, width: lato, height: lato), display: true)
    }

    func nascondi() {
        guard s.visibile else { return }
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        withAnimation(.easeOut(duration: 0.2)) { s.visibile = false; s.ventaglio = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, !self.s.visibile else { return }
            self.orderOut(nil)
        }
    }

    private func puntatore() {
        let p = NSEvent.mouseLocation
        let centro = CGPoint(x: frame.maxX - 90, y: frame.minY + 90)
        let dx = p.x - centro.x, dy = centro.y - p.y, d = hypot(dx, dy)
        let vicino = max(0, min(1, 1 - (d - 30) / 200))
        s.vicino = vicino
        s.verso = CGSize(width: d > 0 ? dx / d * vicino : 0, height: d > 0 ? dy / d * vicino : 0)
    }
}

private struct VistaSfera: View {
    let c: Controllore
    @Bindable var s: StatoSfera
    @Bindable var stato: StatoBarra

    var body: some View {
        let t = Tema.t
        let colori = Tema.nativo ? [0x0A84FF, 0x5AC8FA, 0x5E5CE6, 0xBFE3FF, 0x0C2240] : t.sfera.map { Int($0) }
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            if s.ventaglio { ventaglio }
            // la sfera esiste (e si anima) solo quando si vede: nascosta non consuma niente
            // il movimento è lento: 10 immagini al secondo bastano, disegnate dalla scheda grafica
            if s.visibile {
                let fermo = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                TimelineView(.animation(minimumInterval: 1.0 / 10, paused: fermo)) { ctx in
                    sfera(colori.map { UInt32($0) }, tempo: fermo ? 0 : ctx.date.timeIntervalSinceReferenceDate)
                }
                .frame(width: 60, height: 60)
                .padding(.trailing, 60).padding(.bottom, 60)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
    }

    /// `tempo` fa girare i colori (un giro ogni 12 s) e respirare l'alone (2,5 s); 0 = ferma.
    private func sfera(_ k: [UInt32], tempo: Double) -> some View {
        let giro = tempo.truncatingRemainder(dividingBy: 120) / 12 * 360   // ogni 120 s tutti i colori tornano al via
        let respiro = tempo == 0 ? 0 : (1 - cos(tempo / 2.5 * .pi)) / 2      // 0…1…0
        let px = s.verso.width, py = s.verso.height
        return ZStack {
            // l'alone che respira
            Circle().fill(RadialGradient(colors: [Tema.c(k[0], 0.6), Tema.c(k[1], 0.35), .clear], center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 80, height: 80).blur(radius: 9)
                .opacity(0.5 + respiro * 0.4)
                .offset(x: px * 5, y: py * 5).scaleEffect(1 + s.vicino * 0.25)
            ZStack {
                Circle().fill(RadialGradient(colors: [Tema.c(k[4]), Tema.c(0x08080C)], center: UnitPoint(x: 0.5, y: 0.6), startRadius: 0, endRadius: 45))
                // i colori che girano dentro
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(Tema.c(k[i])).frame(width: i == 3 ? 28 : 38, height: i == 3 ? 28 : 38).blur(radius: 8)
                        .opacity(i == 3 ? 0.55 : 0.85)
                        .offset(x: [13, 15, 12, 17][i])
                        .rotationEffect(.degrees(giro * [1, -1, 1.4, -1.7][i] + Double(i) * 90))
                }
                .offset(x: px * 8, y: py * 8)
                if let g = gatto { Image(nsImage: g).resizable().scaledToFill().scaleEffect(1.04).offset(x: -px * 2, y: -py * 2) }
                // riflesso che va verso il puntatore, bordo più scuro
                Circle().fill(RadialGradient(colors: [.white.opacity(0.55), .clear], center: UnitPoint(x: 0.32 + px * 0.14, y: 0.24 + py * 0.14), startRadius: 0, endRadius: 12))
                Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center, startRadius: 16, endRadius: 30))
                Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .clipShape(Circle())
            .drawingGroup()
            .shadow(color: .black.opacity(0.5), radius: 9, y: 6)
            .scaleEffect(1 + s.vicino * 0.1)
            .animation(.spring(response: 0.38, dampingFraction: 0.7), value: s.vicino)
            // la Concentrazione: l'anello nel colore del tema che si consuma
            if let conc = stato.concentrazione, let fine = conc.fine {
                TimelineView(.periodic(from: .now, by: 5)) { ctx in
                    let tot = fine.timeIntervalSince(conc.inizio), resto = max(0, fine.timeIntervalSince(ctx.date))
                    Circle().trim(from: 0, to: tot > 0 ? resto / tot : 0)
                        .stroke(Tema.accento, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 72, height: 72)
                        .shadow(color: Tema.accento, radius: 3)
                        .help(tempoCheManca(resto))
                }
            }
            if let n = sommaNotifiche {
                Text(n).font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
                    .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(Tema.notifica)).offset(x: 24, y: -24)
            }
        }
        .contentShape(Circle())
        .onTapGesture { c.cliccaSfera() }
    }

    private var gatto: NSImage? { Self.gattoPronto }

    /// Il gatto si carica **una volta sola**, già alla misura della sfera (60 punti × 2): rileggerlo
    /// a ogni immagine dell'animazione costava un terzo del processore.
    private static let gattoPronto: NSImage? = {
        guard let url = Bundle.main.url(forResource: "gatto-sfera", withExtension: "png"),
              let grande = NSImage(contentsOf: url) else { return nil }
        let lato = 120
        guard let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: lato, pixelsHigh: lato, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0) else { return grande }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
        grande.draw(in: NSRect(x: 0, y: 0, width: lato, height: lato))
        NSGraphicsContext.restoreGraphicsState()
        let piccola = NSImage(size: NSSize(width: 60, height: 60)); piccola.addRepresentation(r)
        return piccola
    }()

    private var sommaNotifiche: String? {
        let n = c.tutte.compactMap { $0.notifica.flatMap(Int.init) }.reduce(0, +)
        return n > 0 ? (n > 99 ? "99+" : String(n)) : nil
    }

    // MARK: - Il ventaglio: piccole sfere nei colori del tema, da sinistra verso l'alto

    private var voci: [(String, NSImage?, String?, () -> Void)] {
        var v: [(String, NSImage?, String?, () -> Void)] = []
        if let p = c.precedente { v.append(("Torna a \(p.nome)", stato.icone[p.bid], nil, { c.vai(p) })) }
        v.append(("Nuova app", nil, "plus", { c.nuovaApp() }))
        v.append(("Scrivania", stato.icone["com.apple.finder"], nil, { c.gatto() }))
        for f in stato.cartelle {
            v.append((f.nome, nil, "square.stack.3d.up", { c.attivaCartella(f.id) }))
        }
        return v
    }

    private var ventaglio: some View {
        let giri: [(r: CGFloat, n: Int)] = [(92, 3), (150, 4), (208, 5)]
        var posti: [CGPoint] = []
        for g in giri { for k in 0..<g.n {
            let a = (180 - 90 * Double(k) / Double(g.n - 1)) * .pi / 180
            posti.append(CGPoint(x: cos(a) * g.r, y: -sin(a) * g.r))
        } }
        let vv = voci
        return ZStack(alignment: .bottomTrailing) {
            ForEach(Array(vv.prefix(posti.count).enumerated()), id: \.offset) { i, v in
                let p = posti[i]
                petalo(v.1, simbolo: v.2, i: i)
                    .frame(width: 44, height: 44)
                    .onTapGesture { s.ventaglio = false; v.3() }
                    .onHover { s.sopraPetalo = $0 ? i : (s.sopraPetalo == i ? nil : s.sopraPetalo) }
                    .overlay(alignment: .trailing) {
                        if s.sopraPetalo == i {
                            Text(v.0).font(.system(size: 12.5)).foregroundStyle(.white).fixedSize()
                                .padding(.horizontal, 9).frame(height: 24).vetroMenu(angolo: 8).offset(x: -54)
                        }
                    }
                    .offset(x: p.x - 68, y: p.y - 68)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
    }

    private func petalo(_ icona: NSImage?, simbolo: String?, i: Int) -> some View {
        let k = Tema.t.sfera
        return ZStack {
            Circle().fill(AngularGradient(colors: [Tema.c(k[i % 3]), Tema.c(k[(i + 1) % 3]), Tema.c(k[(i + 2) % 3]), Tema.c(k[i % 3])], center: .center))
                .blur(radius: 6).clipShape(Circle())
            Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center, startRadius: 8, endRadius: 24))
            Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
            if let icona { Image(nsImage: icona).resizable().frame(width: 20, height: 20).shadow(radius: 2) }
            else if let simbolo { Image(systemName: simbolo).font(.system(size: 17, weight: .medium)).foregroundStyle(.white) }
        }
        .scaleEffect(s.sopraPetalo == i ? 1.12 : 1)
        .shadow(color: .black.opacity(0.45), radius: 8, y: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: s.sopraPetalo)
    }
}

extension Controllore {
    /// W-3: la sfera c'è solo con Tabby chiusa **e** nessuna finestra in vista (app tutte
    /// nascoste, ridotte o chiuse; Lampi e Memo non contano), dopo 0,4 s; altrimenti la barra.
    func controllaSfera() {
        let inVista = tutte.contains { s in
            !s.ridotta && !(NSRunningApplication(processIdentifier: s.pid)?.isHidden ?? true) && !lampi.èVeloce(s.bid)
        }
        // «solo e solamente» (Daniele, 10/11/2026): mai a schermo intero, mai sopra la finestra di Tabby
        let serve = stato.tabbyChiusa && !inVista && !davantiASchermoIntero() && !finestraTabby.isVisible
        sferaDopo?.cancel()
        if serve == sfera.s.visibile { return }
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if serve { self.pannello.nascondiScivolando(); self.sfera.mostra() }
            else { self.sfera.nascondi(); self.mostraBarra() }
        }
        sferaDopo = w
        DispatchQueue.main.asyncAfter(deadline: .now() + (serve ? 0.4 : 0), execute: w)
    }

    /// Clic sulla sfera: se c'erano schede aperte si riaprono come le avevi lasciate (niente
    /// domande); il ventaglio (Nuova app, cartelle) solo se non c'è nessuna scheda.
    func cliccaSfera() {
        if !stato.schede.isEmpty { riapriDaScrivania(); return }
        sfera.s.ventaglio.toggle()
        sfera.aggiornaMisura()
    }
}
