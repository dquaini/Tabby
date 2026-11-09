import AppKit
import SwiftUI
import TabbyCore

/// Mentre si divide lo schermo (D-2): lo schema scelto, cosa c'è in ogni zona, quale zona è
/// illuminata, e la scheda che stai trascinando (il «fantasma» sotto il puntatore).
struct Divisione: Equatable {
    var schema: String
    var zone: [String?]
    var illuminata: Int?
    var fantasma: (chiave: String, punto: CGPoint)?      // punto in coordinate del velo (dall'alto)
    static func == (a: Divisione, b: Divisione) -> Bool {
        a.schema == b.schema && a.zone == b.zone && a.illuminata == b.illuminata
            && a.fantasma?.chiave == b.fantasma?.chiave && a.fantasma?.punto == b.fantasma?.punto
    }
}

/// Il velo con le zone, sopra le finestre delle app e sotto la barra di Tabby (così ci si
/// trascinano le schede). Non prende la tastiera: Esc e Invio arrivano come scorciatoie.
@MainActor
final class VeloDivisione: NSPanel {
    let controllore: Controllore

    init(controllore c: Controllore) {
        controllore = c
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        contentView = VistaOspite(rootView: VistaVelo(c: c, stato: c.stato))
    }

    override var canBecomeKey: Bool { false }

    func mostra(in r: NSRect) {
        setFrame(r, display: true)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; animator().alphaValue = 1 }
    }

    func nascondi() {
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; animator().alphaValue = 0 }) { [weak self] in
            MainActor.assumeIsolated { self?.orderOut(nil) }
        }
    }

    /// Da un punto dello schermo (coordinate di macOS, dal basso) alle coordinate del velo.
    func locale(_ p: NSPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y) }

    /// La zona sotto un punto dello schermo, se c'è.
    func zona(a p: NSPoint) -> Int? {
        guard let d = controllore.stato.divisione else { return nil }
        let l = locale(p)
        return zoneIn(schema(d.schema), spazio: CGRect(origin: .zero, size: frame.size), spazio: 6).firstIndex { $0.contains(l) }
    }
}

/// Il disegno del velo: zone tratteggiate (vuote) o con l'app dentro, e in basso il pannello
/// nello stile dei menu con Annulla e Fatto.
struct VistaVelo: View {
    let c: Controllore
    @Bindable var stato: StatoBarra

    var body: some View {
        GeometryReader { g in
            if let d = stato.divisione {
                let zone = zoneIn(schema(d.schema), spazio: CGRect(origin: .zero, size: g.size), spazio: 6)
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    ForEach(zone.indices, id: \.self) { i in
                        zona(i, d.zone[i], illuminata: d.illuminata == i)
                            .frame(width: zone[i].width - 24, height: zone[i].height - 24)
                            .offset(x: zone[i].minX + 12, y: zone[i].minY + 12)
                            .onTapGesture { c.svuotaZona(i) }
                    }
                    pannello
                        .position(x: g.size.width / 2, y: g.size.height - 46)
                    if let f = d.fantasma, let s = c.scheda(f.chiave) {
                        fantasma(s).position(x: f.punto.x, y: f.punto.y)
                    }
                }
                .animation(Tema.molla, value: d.zone)
                .animation(.easeOut(duration: 0.12), value: d.illuminata)
            }
        }
    }

    private func icona(_ s: Scheda, _ lato: CGFloat) -> some View {
        Group {
            if let i = s.sito.flatMap({ stato.loghi[$0] }) ?? stato.icone[s.bid] {
                Image(nsImage: i).resizable().interpolation(.high).frame(width: lato, height: lato)
                    .clipShape(RoundedRectangle(cornerRadius: s.sito != nil ? lato / 4 : 0))
            }
        }
    }

    private func zona(_ i: Int, _ chiave: String?, illuminata: Bool) -> some View {
        let r = RoundedRectangle(cornerRadius: 12)
        return ZStack {
            if let k = chiave, let s = c.scheda(k) {
                r.fill(Color.white.opacity(illuminata ? 0.12 : 0.07))
                r.strokeBorder(illuminata ? Tema.accento : Color.white.opacity(0.25), lineWidth: illuminata ? 2 : 1)
                VStack(spacing: 10) {
                    icona(s, 44)
                    Text(s.nome).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    Text("clic per togliere").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.45))
                }
            } else {
                r.fill(illuminata ? Tema.accento.opacity(0.16) : Color.clear)
                r.strokeBorder(illuminata ? Tema.accento : Color.white.opacity(0.35),
                               style: StrokeStyle(lineWidth: illuminata ? 2 : 1.5, dash: illuminata ? [] : [7, 6]))
                Text("\(i + 1)").font(.system(size: 28, weight: .light)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .contentShape(r)
    }

    /// Il pannello in basso, identico ai menu (vetro scuro, angoli 12).
    private var pannello: some View {
        HStack(spacing: 14) {
            Text("Trascina le schede di Tabby nelle zone, o cliccale")
                .foregroundStyle(.white.opacity(0.75))
            Button { c.annullaDivisione() } label: {
                HStack(spacing: 6) { Text("Annulla"); Text("esc").foregroundStyle(.white.opacity(0.45)) }
                    .padding(.horizontal, 10).frame(height: 24)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
            Button { c.fineDivisione() } label: {
                HStack(spacing: 6) { Text("Fatto"); Text("↩").opacity(0.7) }
                    .padding(.horizontal, 10).frame(height: 24)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 14).frame(height: 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .background(Tema.c(0x262628, 0.6), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
    }

    private func fantasma(_ s: Scheda) -> some View {
        HStack(spacing: 7) {
            icona(s, 16)
            Text(s.nome).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Tema.testo).lineLimit(1)
        }
        .padding(.horizontal, 10).frame(height: 28)
        .background(Tema.c(0x26231B), in: RoundedRectangle(cornerRadius: Misure.angoloScheda))
        .overlay(RoundedRectangle(cornerRadius: Misure.angoloScheda).strokeBorder(Tema.c(0xFFE2A0, 0.14), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        .rotationEffect(.degrees(-2))
        .allowsHitTesting(false)
    }
}

/// La figurina di uno schema, per il menu ⊞ (rettangoli dello spazio con le zone).
@MainActor func figurina(_ s: Schema) -> NSImage {
    let i = NSImage(size: NSSize(width: 26, height: 16), flipped: true) { r in
        for z in zoneIn(s, spazio: r.insetBy(dx: 0.5, dy: 0.5), spazio: 1) {
            let p = NSBezierPath(roundedRect: z, xRadius: 2, yRadius: 2)
            NSColor.black.withAlphaComponent(0.85).setStroke(); p.lineWidth = 1.2; p.stroke()
        }
        return true
    }
    i.isTemplate = true
    return i
}
