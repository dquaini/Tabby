import AppKit
import SwiftUI
import TabbyCore

// La barra di Tabby (DESIGN.md 3.7): Notte · Tabby, compatta (alta 38, schede da 28), angoli
// 14 dal lato delle app, scheda attiva col riempimento del tema che scivola, ✕ solo sulla
// scheda attiva e su quella sotto il mouse, niente righe divisorie.

/// La finestra della barra: sopra le finestre normali, su tutte le scrivanie, e i clic non le
/// danno l'attenzione (non ruba la tastiera all'app che stai usando).
@MainActor
final class PannelloBarra: NSPanel {
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
        acceptsMouseMovedEvents = true
        let v = VistaOspite(rootView: BarraVista(c: c, stato: c.stato))
        contentView = v
        Menu.vista = v
        Menu.stato = c.stato
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func mostra() {
        setFrame(Sistema.cornice(posizione: controllore.stato.posizione), display: true)
        orderFrontRegardless()
    }
}

/// Il primo clic funziona subito, anche se Tabby non è l'app attiva.
final class VistaOspite<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - I menu (NSMenu di macOS, scuri in Notte, attaccati al tasto dal lato delle app)

@MainActor
enum Menu {
    static weak var vista: NSView?
    static var stato: StatoBarra?

    static func apri(_ m: NSMenu, sopra cornice: CGRect) {
        guard let v = vista, let stato else { return }
        m.appearance = NSAppearance(named: .darkAqua)
        let flip = v.isFlipped, h = v.bounds.height
        func y(_ yy: CGFloat) -> CGFloat { flip ? yy : h - yy }
        var p: NSPoint
        switch stato.posizione {
        case "right":  p = NSPoint(x: cornice.minX - m.size.width - 4, y: y(cornice.minY))
        case "left":   p = NSPoint(x: cornice.maxX + 4, y: y(cornice.minY))
        case "bottom": p = NSPoint(x: cornice.minX, y: y(cornice.minY - m.size.height - 4))
        default:       p = NSPoint(x: cornice.minX, y: y(cornice.maxY + 4))
        }
        m.popUp(positioning: nil, at: p, in: v)
    }

    static func voce(_ titolo: String, simbolo: String? = nil, tasto: String = "", attiva: Bool = true,
                     segno: Bool = false, _ azione: (() -> Void)? = nil) -> NSMenuItem {
        let i = AzioneMenu(title: titolo, action: azione == nil ? nil : #selector(AzioneMenu.esegui), keyEquivalent: tasto)
        i.target = i
        i.fai = azione
        if !tasto.isEmpty { i.keyEquivalentModifierMask = [.control, .option] }
        if let simbolo { i.image = NSImage(systemSymbolName: simbolo, accessibilityDescription: nil) }
        i.isEnabled = attiva && azione != nil
        i.state = segno ? .on : .off
        return i
    }
}

final class AzioneMenu: NSMenuItem {
    var fai: (() -> Void)?
    @objc func esegui() { fai?() }
}

// MARK: - La vista

struct BarraVista: View {
    let c: Controllore
    @Bindable var stato: StatoBarra
    @Namespace private var ns
    @State private var sopra: String?
    // il trascinamento (T-1)
    @State private var trascinata: String?
    @State private var spostamento: CGSize = .zero
    @State private var dove: CGFloat?        // dove cadrà: x (in alto) o y (di lato) della lineetta

    var body: some View {
        Group { if stato.verticale { colonna } else { riga } }
            .foregroundStyle(Tema.tenue)
            .font(.system(size: 12.5))
    }

    private var forma: UnevenRoundedRectangle {
        let r = Misure.angoloBarra
        switch stato.posizione {
        case "bottom": return UnevenRoundedRectangle(topLeadingRadius: r, topTrailingRadius: r)
        case "left":   return UnevenRoundedRectangle(bottomTrailingRadius: r, topTrailingRadius: r)
        case "right":  return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r)
        default:       return UnevenRoundedRectangle(bottomLeadingRadius: r, bottomTrailingRadius: r)
        }
    }

    // MARK: in alto o in basso

    private var riga: some View {
        GeometryReader { g in
            let fisso = Misure.gatto + Misure.piu + Misure.tasto * 2 + 16
            let att = stato.schede.firstIndex { $0.chiave == stato.attiva && !stato.scrivania }
            let d = disponiOrizzontale(spazio: g.size.width - fisso, numero: stato.schede.count, attiva: att)
            HStack(spacing: 2) {
                gatto
                ForEach(d.visibili, id: \.self) { i in
                    let s = stato.schede[i], on = i == att
                    scheda(s, attiva: on, larghezza: d.compatta ? (on ? Misure.compattaAttiva : Misure.compatta) : d.larghezza,
                           soloIcona: d.compatta && !on)
                }
                if d.altre > 0 { altre(d) }
                piu
                Spacer(minLength: 0)
                batteria
                impostazioni
            }
            .padding(.horizontal, 2)
            .frame(width: g.size.width, height: g.size.height)
            .overlay(alignment: .topLeading) { lineetta(g.size) }
        }
        .background(Tema.sfondo(verticale: false).clipShape(forma))
    }

    // MARK: di lato

    private var colonna: some View {
        GeometryReader { g in
            let att = stato.schede.firstIndex { $0.chiave == stato.attiva && !stato.scrivania }
            let d = disponiVerticale(spazio: g.size.height - 74 - 30 - 34 - 34 - 24, numero: stato.schede.count, attiva: att)
            VStack(spacing: 2) {
                gattoIntero
                ForEach(d.visibili, id: \.self) { i in
                    scheda(stato.schede[i], attiva: i == att, larghezza: g.size.width - 12, soloIcona: false, altezza: d.riga - 2)
                }
                if d.altre > 0 { altre(DisposizioneOrizzontale(larghezza: 0, compatta: false, visibili: d.visibili, altre: d.altre), largo: true) }
                piu.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
                Spacer(minLength: 0)
                batteria
                HStack(spacing: 0) { Spacer(); impostazioni; Spacer() }
            }
            .padding(.vertical, 6)
            .frame(width: g.size.width, height: g.size.height)
            .overlay(alignment: .topLeading) { lineetta(g.size) }
        }
        .background(Tema.sfondo(verticale: true).clipShape(forma))
    }

    // MARK: i pezzi

    private func immagineGatto(_ nome: String) -> NSImage? {
        guard let u = Bundle.main.resourceURL?.appendingPathComponent(nome + ".png") else { return nil }
        let i = NSImage(contentsOf: u); i?.isTemplate = true; return i
    }

    private var gatto: some View {
        Button { apriCasa() } label: {
            Group {
                if let i = immagineGatto("gatto-spento") { Image(nsImage: i).resizable().scaledToFit().frame(width: 20, height: 20) }
                else { Image(systemName: "pawprint.fill") }
            }
            .foregroundStyle(stato.scrivania ? Tema.accento : Tema.tenue)
            .shadow(color: stato.scrivania ? Tema.accento.opacity(0.5) : .clear, radius: 4)
            .frame(width: Misure.gatto, height: Misure.gatto)
            .background(stato.scrivania ? Tema.sopra : .clear, in: RoundedRectangle(cornerRadius: Misure.angoloScheda))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(CorniceMenu(id: "gatto"))
    }

    private var gattoIntero: some View {
        Button { apriCasa() } label: {
            Group {
                let lato = stato.posizione == "left" ? "sinistra" : "destra"
                if let i = immagineGatto("gatto-intero-\(lato)-spento") { Image(nsImage: i).resizable().scaledToFit() }
                else { Image(systemName: "pawprint.fill").font(.system(size: 30)) }
            }
            .foregroundStyle(stato.scrivania ? Tema.accento : Tema.tenue)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(height: 74).frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(CorniceMenu(id: "gatto"))
    }

    private func scheda(_ s: Scheda, attiva on: Bool, larghezza w: Double, soloIcona: Bool, altezza h: Double = Misure.altezzaScheda) -> some View {
        let su = sopra == s.chiave
        let rid = s.ridotta && !on
        return HStack(spacing: 7) {
            if let i = stato.icone[s.bid] { Image(nsImage: i).resizable().frame(width: 16, height: 16).opacity(rid ? 0.45 : 1) }
            if !soloIcona {
                Text(s.nome).lineLimit(1).truncationMode(.tail).italic(rid).opacity(rid ? 0.7 : 1)
                Spacer(minLength: 0)
                if on || su {
                    Button { apriChiudi(s) } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11)).opacity(0.55)
                            .frame(width: 16, height: 16).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(CorniceMenu(id: "x:" + s.chiave))
                }
            }
        }
        .font(.system(size: 12.5, weight: on ? .semibold : .regular))
        .foregroundStyle(on ? Tema.suAttiva : su ? Tema.testo : Tema.tenue)
        .padding(.horizontal, soloIcona ? 0 : 8)
        .frame(width: w, height: h, alignment: soloIcona ? .center : .leading)
        .background {
            if on {
                Tema.riempimento
                    .clipShape(RoundedRectangle(cornerRadius: Misure.angoloScheda))
                    .overlay(RoundedRectangle(cornerRadius: Misure.angoloScheda)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center), lineWidth: 0.5))
                    .shadow(color: Tema.c(0xDC9628, 0.22), radius: 5, y: 2)
                    .matchedGeometryEffect(id: "riempimento", in: ns)
            } else if su {
                RoundedRectangle(cornerRadius: Misure.angoloScheda).fill(Tema.sopra)
            }
        }
        .contentShape(Rectangle())
        .background(CorniceMenu(id: "t:" + s.chiave))
        .offset(trascinata == s.chiave ? spostamento : .zero)
        .zIndex(trascinata == s.chiave ? 1 : 0)
        .shadow(color: .black.opacity(trascinata == s.chiave ? 0.45 : 0), radius: 8, y: 4)
        .onHover { dentro in sopra = dentro ? s.chiave : (sopra == s.chiave ? nil : sopra) }
        .onTapGesture { c.vai(s) }
        .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { v in
                trascinata = s.chiave
                spostamento = stato.verticale ? CGSize(width: 0, height: v.translation.height) : CGSize(width: v.translation.width, height: 0)
                dove = puntoDiCaduta(v.location, tranne: s.chiave).linea
            }
            .onEnded { v in lascia(s.chiave, in: v.location) })
        .help(soloIcona ? s.nome : "")
    }

    private func altre(_ d: DisposizioneOrizzontale, largo: Bool = false) -> some View {
        Button { apriAltre(d) } label: {
            Text(largo ? "+\(d.altre) altre" : "+\(d.altre)").font(.system(size: 12))
                .frame(minWidth: Misure.piuN, maxWidth: largo ? .infinity : nil, minHeight: Misure.altezzaScheda, alignment: largo ? .leading : .center)
                .padding(.leading, largo ? 10 : 0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(CorniceMenu(id: "altre"))
    }

    private var piu: some View {
        Button { c.nuovaApp() } label: {
            Image(systemName: "plus.app").font(.system(size: 14))
                .frame(width: Misure.piu, height: Misure.altezzaScheda)
                .background(sopra == "+" ? Tema.sopra : .clear, in: RoundedRectangle(cornerRadius: Misure.angoloScheda))
                .foregroundStyle(sopra == "+" ? Tema.testo : Tema.tenue)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { sopra = $0 ? "+" : nil }
        .help("Nuova app")
    }

    @ViewBuilder private var batteria: some View {
        let b = stato.batteria
        if b.presente {
            let col = coloreBatteria(livello: b.livello, inCarica: b.inCarica)
            Image(systemName: b.inCarica ? "battery.100percent.bolt" : simboloBatteria(b.livello))
                .font(.system(size: 15))
                .foregroundStyle(col == .verde ? Tema.verde : col == .rossa ? Tema.rossa : Tema.tenue)
                .frame(width: Misure.tasto, height: stato.verticale ? 30 : Misure.altezza)
                .help("\(b.livello)%" + (b.inCarica ? " · in carica" : ""))
        }
    }

    private func simboloBatteria(_ l: Int) -> String {
        l >= 88 ? "battery.100percent" : l >= 63 ? "battery.75percent" : l >= 38 ? "battery.50percent" : l >= 13 ? "battery.25percent" : "battery.0percent"
    }

    private var impostazioni: some View {
        Button { apriImpostazioni() } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                .frame(width: Misure.tasto, height: stato.verticale ? Misure.tasto : Misure.altezza)
                .foregroundStyle(sopra == "⚙︎" ? Tema.testo : Tema.tenue)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { sopra = $0 ? "⚙︎" : nil }
        .background(CorniceMenu(id: "impostazioni"))
    }

    // MARK: il trascinamento (T-1)

    /// Le schede visibili in ordine, con la loro cornice (in coordinate della barra).
    private func cornici(tranne k: String) -> [(chiave: String, f: CGRect)] {
        CorniceMenu.cornici.compactMap { (id, f) in id.hasPrefix("t:") && id != "t:" + k ? (String(id.dropFirst(2)), f) : nil }
            .sorted { stato.verticale ? $0.f.midY < $1.f.midY : $0.f.midX < $1.f.midX }
    }

    /// Davanti a quale scheda cadrà, e dove disegnare la lineetta.
    private func puntoDiCaduta(_ p: CGPoint, tranne k: String) -> (davanti: String?, linea: CGFloat?) {
        let cs = cornici(tranne: k)
        guard let ultima = cs.last else { return (nil, nil) }
        for x in cs where stato.verticale ? p.y < x.f.midY : p.x < x.f.midX {
            return (x.chiave, stato.verticale ? x.f.minY - 1 : x.f.minX - 1)
        }
        return (nil, stato.verticale ? ultima.f.maxY + 1 : ultima.f.maxX + 1)
    }

    private func lascia(_ k: String, in p: CGPoint) {
        let b = Menu.vista?.bounds ?? .zero
        let dentro = b.insetBy(dx: -24, dy: -24).contains(p)    // fuori dalla barra (margine 24) → niente
        let d = puntoDiCaduta(p, tranne: k)
        withAnimationMolla { trascinata = nil; spostamento = .zero; dove = nil }
        if dentro { c.riordina(k, davanti: d.davanti) }
    }

    @ViewBuilder private func lineetta(_ dim: CGSize) -> some View {
        if let d = dove {
            let r = RoundedRectangle(cornerRadius: 1).fill(Tema.accento).shadow(color: Tema.accento.opacity(0.6), radius: 3)
            if stato.verticale { r.frame(width: dim.width - 20, height: 2).offset(x: 10, y: d - 1) }
            else { r.frame(width: 2, height: 20).offset(x: d - 1, y: (dim.height - 20) / 2) }
        }
    }

    // MARK: i menu

    private func apriCasa() {
        let m = NSMenu()
        if let p = c.precedente {
            m.addItem(Menu.voce("Torna a \(p.nome)", simbolo: "arrow.uturn.backward") { c.vai(p) })
        }
        m.addItem(Menu.voce("Nuova app…", simbolo: "plus.app") { c.nuovaApp() })
        m.addItem(Menu.voce("Scrivania", simbolo: "macwindow", tasto: "0") { c.scrivania() })
        Menu.apri(m, sopra: CorniceMenu.cornici["gatto"] ?? .zero)
    }

    private func apriChiudi(_ s: Scheda) {
        let m = NSMenu()
        if s.bid == "com.apple.finder" {
            if let t = c.titolo(s) { m.addItem(Menu.voce("Chiudi la finestra «\(t)»") { c.chiudiFinestra(s) }) }
            m.addItem(Menu.voce("Il Finder non si può chiudere", attiva: false))
        } else {
            let t = c.titolo(s).map { "Chiudi la finestra «\(String($0.prefix(40)))»" } ?? "Chiudi la finestra"
            m.addItem(Menu.voce(t, simbolo: "xmark") { c.chiudiFinestra(s) })
            m.addItem(Menu.voce("Chiudi \(NSRunningApplication(processIdentifier: s.pid)?.localizedName ?? s.nome)") { c.chiudiApp(s) })
        }
        Menu.apri(m, sopra: CorniceMenu.cornici["x:" + s.chiave] ?? .zero)
    }

    private func apriAltre(_ d: DisposizioneOrizzontale) {
        let m = NSMenu()
        for (i, s) in stato.schede.enumerated() where !d.visibili.contains(i) {
            let v = Menu.voce(s.nome) { c.vai(s) }
            v.image = stato.icone[s.bid].map { let x = $0.copy() as! NSImage; x.size = NSSize(width: 16, height: 16); return x }
            m.addItem(v)
        }
        Menu.apri(m, sopra: CorniceMenu.cornici["altre"] ?? .zero)
    }

    private func apriImpostazioni() {
        let m = NSMenu()
        let pos = NSMenu()
        for (k, t) in [("top", "In alto"), ("right", "A destra"), ("left", "A sinistra"), ("bottom", "In basso")] {
            pos.addItem(Menu.voce(t, segno: stato.posizione == k) { c.cambiaPosizione(k) })
        }
        let p = Menu.voce("Posizione", simbolo: "macwindow"); p.submenu = pos; p.isEnabled = true
        m.addItem(p)
        m.addItem(Menu.voce("Una scheda alla volta", segno: c.imp.unaAllaVolta) { c.cambia("oneAtATime") })
        m.addItem(Menu.voce("Adatta le finestre a Tabby", segno: c.imp.adatta) { c.cambia("fit") })
        m.addItem(.separator())
        let esci = Menu.voce("Esci da Tabby") { NSApp.terminate(nil) }
        m.addItem(esci)
        Menu.apri(m, sopra: CorniceMenu.cornici["impostazioni"] ?? .zero)
    }
}

/// Ricorda dove sta un tasto nella barra, per aprirci accanto il suo menu.
struct CorniceMenu: View {
    @MainActor static var cornici: [String: CGRect] = [:]
    let id: String
    var body: some View {
        GeometryReader { g in
            Color.clear.onAppear { CorniceMenu.cornici[id] = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, f in CorniceMenu.cornici[id] = f }
                .onDisappear { CorniceMenu.cornici[id] = nil }
        }
    }
}
