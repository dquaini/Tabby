import AppKit
@preconcurrency import SwiftUI
import TabbyCore

// I componenti comuni (DESIGN.md 3.2–3.5): il velo, i fogli e gli avvisi. Tutti nello stile dei
// menu di macOS (vetro scuro in Notte, angoli 12, righe da 22, scelta col colore del Mac).

// MARK: - Il vetro dei menu

extension View {
    /// Il vetro dei menu di macOS, scuro (Notte), con bordo sottile e l'ombra dei menu.
    func vetroMenu(angolo: CGFloat = 12) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: angolo))
            .background(Tema.c(0x262628, 0.72), in: RoundedRectangle(cornerRadius: angolo))
            .overlay(RoundedRectangle(cornerRadius: angolo).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
            .environment(\.colorScheme, .dark)
    }
}

/// I pulsanti piccoli come quelli di macOS: il principale nel colore principale del Mac.
struct Pulsante: View {
    let titolo: String
    var principale = false
    var rosso = false
    var acceso = true
    let azione: () -> Void
    var body: some View {
        Button(action: azione) {
            Text(titolo).font(.system(size: 12.5, weight: principale ? .medium : .regular))
                .padding(.horizontal, 11).frame(minWidth: 64, minHeight: 22)
                .background(principale ? (rosso ? Color.red : Color.accentColor) : Color.white.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(acceso ? 1 : 0.4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!acceso)
    }
}

/// Un tasto disegnato come un tastino vero (⌃ ⌥ M), la prima delle quattro firme dei menu.
struct Tastino: View {
    let testo: String
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(testo.split(separator: " ").enumerated()), id: \.offset) { _, t in
                Text(t).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

// MARK: - Il palco: velo + foglio (3.3, 3.4)

/// Un foglio: simbolo nel colore del tema, titolo, una riga di spiegazione, il contenuto, e in
/// fondo i tasti con due pulsanti (Invio = principale, Esc = Annulla).
struct Foglio<Contenuto: View>: View {
    let simbolo: String
    let titolo: String
    let spiegazione: String
    var principale = "Fatto"
    var principaleAcceso = true
    var largo: CGFloat = 320
    let annulla: () -> Void
    let conferma: () -> Void
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: simbolo).font(.system(size: 17, weight: .medium)).foregroundStyle(Tema.accento)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titolo).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(.white)
                    Text(spiegazione).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
            Divider().overlay(Color.white.opacity(0.08))
            contenuto().padding(.vertical, 6)
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 8) {
                Text("↵ · esc").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                Spacer()
                Pulsante(titolo: "Annulla", azione: annulla).keyboardShortcut(.cancelAction)
                Pulsante(titolo: principale, principale: true, acceso: principaleAcceso, azione: conferma).keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
        .frame(width: largo)
        .vetroMenu()
    }
}

/// Un titolo di sezione dei menu (piccolo, grigio).
struct TitoloSezione: View {
    let testo: String
    var body: some View {
        Text(testo).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.42))
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
    }
}

/// Il palco: una finestra grande quanto lo spazio delle app con il velo scuro (~78%, come
/// Spotlight) e al centro ottico (45% dall'alto) il foglio. La barra di Tabby resta sopra e
/// cliccabile. Il foglio prende la tastiera (per scrivere, Invio ed Esc).
@MainActor
final class Palco: NSPanel {
    private var chiudi: (() -> Void)?
    private var appPrima: NSRunningApplication?
    private(set) var cornice: CGRect = .zero     // il foglio, in coordinate dello schermo
    var aperto: Bool { isVisible }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    /// Apre `foglio` sopra il velo. `annulla` si chiama per un clic sul velo.
    func apri<V: View>(_ foglio: V, sopra barra: NSWindow?, posizione: String, annulla: @escaping () -> Void) {
        appPrima = NSWorkspace.shared.frontmostApplication
        chiudi = annulla
        setFrame(Sistema.spazioApp(posizione: posizione), display: false)
        contentView = VistaOspite(rootView: ScenaPalco(foglio: foglio, palco: self, annulla: annulla))
        alphaValue = 1
        makeKeyAndOrderFront(nil)
        NSApp.activate()
        barra?.orderFrontRegardless()
    }

    func ricordaCornice(_ r: CGRect) {      // r in coordinate della vista (dall'alto)
        cornice = CGRect(x: frame.minX + r.minX, y: frame.maxY - r.maxY, width: r.width, height: r.height)
    }

    /// Chiude il foglio (uscita veloce, 0,2 s) e ridà la tastiera all'app di prima.
    func chiudiFoglio(tornaA app: NSRunningApplication? = nil) {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.18; animator().alphaValue = 0 }) { [weak self] in
            MainActor.assumeIsolated { self?.orderOut(nil); self?.contentView = nil }
        }
        if let a = app ?? appPrima, a.bundleIdentifier != Sistema.mioBid { a.activate() }
    }
}

private struct ScenaPalco<V: View>: View {
    let foglio: V
    let palco: Palco
    let annulla: () -> Void
    @State private var dentro = false

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                Color.black.opacity(0.78).contentShape(Rectangle()).onTapGesture(perform: annulla)
                    .opacity(dentro ? 1 : 0)
                foglio
                    .background(GeometryReader { f in
                        Color.clear.onAppear { palco.ricordaCornice(f.frame(in: .global)) }
                            .onChange(of: f.frame(in: .global)) { _, r in palco.ricordaCornice(r) }
                    })
                    .scaleEffect(dentro ? 1 : 0.94)
                    .opacity(dentro ? 1 : 0)
                    .alignmentGuide(.top) { d in -(g.size.height * 0.45 - d.height / 2) }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .onAppear { withAnimation(Tema.molla) { dentro = true } }
    }
}

// MARK: - Gli avvisi (3.5)

/// Un avviso: stile dei menu, largo 270, 4 s (8 con pulsanti); passandoci sopra il tempo si
/// ferma; ✕ al passaggio del mouse.
struct Avviso: Identifiable, Equatable {
    struct Scelta: Equatable {
        let titolo: String
        var principale = false
        let azione: () -> Void
        static func == (a: Scelta, b: Scelta) -> Bool { a.titolo == b.titolo }
    }
    let id = UUID()
    var simbolo: String = "info.circle"
    var icona: NSImage?
    var problema = false
    var titolo: String
    var testo: String?
    var scelte: [Scelta] = []
    var durata: Double { scelte.isEmpty ? 4 : 8 }
    static func == (a: Avviso, b: Avviso) -> Bool { a.id == b.id }
}

@MainActor @Observable
final class StatoAvvisi {
    var visibili: [Avviso] = []
    var inAttesa: [Avviso] = []
    var sopra: UUID?
    var resto: [UUID: Double] = [:]          // secondi che restano a ciascuno
}

/// Gli avvisi sotto la barra, a destra, **affiancati in orizzontale** (il più nuovo a destra),
/// al massimo 3; gli altri aspettano («+2 altri»). Lo stesso avviso rinnova il tempo.
@MainActor
final class Avvisi {
    let stato = StatoAvvisi()
    private let finestra: NSPanel
    private var timer: Timer?
    var posizione: () -> String = { "top" }
    var silenzio: () -> Bool = { false }          // Concentrazione: solo quelli con una scelta

    init() {
        finestra = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        finestra.level = .floating
        finestra.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        finestra.isOpaque = false
        finestra.backgroundColor = .clear
        finestra.hasShadow = false
        finestra.contentView = VistaOspite(rootView: VistaAvvisi(avvisi: self, stato: stato))
    }

    func mostra(_ a: Avviso) {
        if silenzio() && a.scelte.isEmpty { return }
        if let i = stato.visibili.firstIndex(where: { $0.titolo == a.titolo }) {
            stato.resto[stato.visibili[i].id] = a.durata; return
        }
        withAnimation(Tema.molla) {
            if stato.visibili.count >= 3 { stato.inAttesa.append(a) } else { stato.visibili.append(a); stato.resto[a.id] = a.durata }
        }
        posiziona()
        if timer == nil {
            let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.passa(0.25) } }
            RunLoop.main.add(t, forMode: .common); timer = t
        }
    }

    func togli(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            stato.visibili.removeAll { $0.id == id }
            stato.resto[id] = nil
            if !stato.inAttesa.isEmpty, stato.visibili.count < 3 {
                let a = stato.inAttesa.removeFirst(); stato.visibili.append(a); stato.resto[a.id] = a.durata
            }
        }
        if stato.visibili.isEmpty {
            timer?.invalidate(); timer = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                MainActor.assumeIsolated { if self?.stato.visibili.isEmpty == true { self?.finestra.orderOut(nil) } }
            }
        }
    }

    private func passa(_ dt: Double) {
        for a in stato.visibili where a.id != stato.sopra {
            let r = (stato.resto[a.id] ?? 0) - dt
            if r <= 0 { togli(a.id) } else { stato.resto[a.id] = r }
        }
    }

    /// Sotto la barra a destra; con Tabby di lato in alto, accanto alla barra.
    private func posiziona() {
        let spazio = Sistema.spazioApp(posizione: posizione())
        let w: CGFloat = 270 * 3 + 16 * 2 + 140, h: CGFloat = 130
        finestra.setFrame(NSRect(x: spazio.maxX - w - 10, y: spazio.maxY - h - 6, width: w, height: h), display: true)
        finestra.orderFrontRegardless()
    }
}

private struct VistaAvvisi: View {
    let avvisi: Avvisi
    @Bindable var stato: StatoAvvisi

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer(minLength: 0)
            if !stato.inAttesa.isEmpty {
                Text("+\(stato.inAttesa.count) \(stato.inAttesa.count == 1 ? "altro" : "altri")")
                    .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 9).frame(height: 24).vetroMenu(angolo: 12)
            }
            ForEach(stato.visibili) { a in
                scheda(a).transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(.top, 2).padding(.trailing, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func scheda(_ a: Avviso) -> some View {
        let su = stato.sopra == a.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if let i = a.icona { Image(nsImage: i).resizable().frame(width: 26, height: 26) }
                    else { Image(systemName: a.simbolo).font(.system(size: 17, weight: .medium)).foregroundStyle(a.problema ? Color.orange : Tema.accento) }
                }.frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(a.titolo).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    if let t = a.testo { Text(t).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
            if !a.scelte.isEmpty {
                HStack(spacing: 6) {
                    Spacer()
                    ForEach(a.scelte, id: \.titolo) { s in
                        Pulsante(titolo: s.titolo, principale: s.principale) { s.azione(); avvisi.togli(a.id) }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 270)
        .overlay(alignment: .bottom) {
            if su { Capsule().fill(Color.white.opacity(0.25)).frame(height: 2).padding(.horizontal, 14).padding(.bottom, 3) }
        }
        .vetroMenu()
        .overlay(alignment: .topLeading) {
            if su {
                Button { avvisi.togli(a.id) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                }.buttonStyle(.plain).offset(x: -5, y: -5)
            }
        }
        .onHover { stato.sopra = $0 ? a.id : (stato.sopra == a.id ? nil : stato.sopra) }
    }
}
