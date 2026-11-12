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

    /// Prende la tastiera solo mentre rinomini una scheda (si scrive sulla scheda).
    override var canBecomeKey: Bool { controllore.stato.rinomina != nil }
    override var canBecomeMain: Bool { false }

    /// Conta le sparizioni: una barra che ricompare annulla quella in corso (prima, col mouse che
    /// scendeva in fretta dal menu di Apple, l'animazione finiva e Tabby restava via).
    private var giro = 0
    var inUscita: Bool { isVisible && alphaValue < 0.99 }

    /// `scendendo`: rientra scivolando dall'alto (dopo il menu di Apple).
    func mostra(scendendo: Bool = false) {
        giro += 1
        // nella fascia del notch macOS spingerebbe giù una finestra normale: si sale di livello
        level = controllore.stato.posizione == "top" && Sistema.fasciaNotch ? .statusBar : .floating
        let f = Sistema.cornice(posizione: controllore.stato.posizione)
        if scendendo && !isVisible { setFrame(f.offsetBy(dx: 0, dy: f.height), display: false); alphaValue = 0 }
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in       // ferma anche un'animazione in corso
            ctx.duration = scendendo ? 0.16 : 0
            animator().setFrame(f, display: true); animator().alphaValue = 1
        }
    }

    /// La barra sale (o scivola di lato) e sparisce: arriva la sfera (0,2 s).
    func nascondiScivolando() {
        guard isVisible, !inUscita else { return }
        giro += 1
        let questo = giro
        var f = frame
        switch controllore.stato.posizione {
        case "bottom": f.origin.y -= f.height
        case "left": f.origin.x -= f.width
        case "right": f.origin.x += f.width
        default: f.origin.y += f.height
        }
        NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.2; animator().setFrame(f, display: true); animator().alphaValue = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, self.giro == questo else { return }   // nel frattempo è ricomparsa
            self.orderOut(nil)
        }
    }
}

/// Il primo clic funziona subito, anche se Tabby non è l'app attiva.
final class VistaOspite<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Il nome di una scheda che non ci sta: prima si tolgono le ultime parole («Proton Mail» →
/// «Proton»), i puntini solo se non basta nemmeno la prima parola.
struct NomeCorto: View {
    let nome: String
    var body: some View {
        let parole = nome.split(separator: " ").map(String.init)
        ViewThatFits(in: .horizontal) {
            Text(nome).lineLimit(1).fixedSize()
            ForEach((1..<max(parole.count, 1)).reversed(), id: \.self) { n in
                Text(parole.prefix(n).joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " -–—·|:,"))).lineLimit(1).fixedSize()
            }
            Text(nome).lineLimit(1).truncationMode(.tail)
        }
    }
}

// MARK: - I menu (NSMenu di macOS, scuri in Notte, attaccati al tasto dal lato delle app)

@MainActor
enum Menu {
    static weak var vista: NSView?
    static var stato: StatoBarra?

    static func apri(_ m: NSMenu, sopra cornice: CGRect) {
        guard let v = vista, let stato else { return }
        m.appearance = NSAppearance(named: .darkAqua)
        let flip = v.isFlipped, h = v.bounds.height, w = v.bounds.width
        func y(_ yy: CGFloat) -> CGFloat { flip ? yy : h - yy }
        // Il menu parte dal bordo della barra (non dal tasto), così non la copre mai. Se il tasto
        // non ha ancora una posizione, si usa quella del puntatore.
        var r = cornice
        if r == .zero, let win = v.window {
            let q = v.convert(win.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            r = CGRect(x: q.x - 8, y: (flip ? q.y : h - q.y) - 8, width: 16, height: 16)
        }
        var p: NSPoint
        switch stato.posizione {
        case "right":  p = NSPoint(x: -m.size.width - 4, y: y(r.minY))
        case "left":   p = NSPoint(x: w + 4, y: y(r.minY))
        case "bottom": p = NSPoint(x: r.minX, y: y(-m.size.height - 4))
        default:       p = NSPoint(x: r.minX, y: y(h + 4))
        }
        m.popUp(positioning: nil, at: p, in: v)
    }

    /// L'icona di una voce di menu, a 16 punti (una copia: l'originale serve anche alla barra).
    static func icona(_ i: NSImage?) -> NSImage? {
        guard let x = i?.copy() as? NSImage else { return nil }
        x.size = NSSize(width: 16, height: 16); return x
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
    @FocusState private var scrivendo: Bool
    // il trascinamento (T-1)
    @State private var trascinata: String?
    @State private var primoClicX: (chiave: String, quando: Date, menu: DispatchWorkItem)?
    @State private var provvisorio: [String]?   // l'ordine mentre trascini: le altre schede fanno posto dal vivo
    @State private var puntatore: CGPoint = .zero
    @State private var presa: CGFloat = 0        // dove hai preso la scheda (dal suo bordo)

    /// Le schede nell'ordine da mostrare (durante il trascinamento, quello provvisorio).
    private var mostrate: [Scheda] {
        guard let p = provvisorio else { return stato.schede }
        let posto = Dictionary(uniqueKeysWithValues: p.enumerated().map { ($1, $0) })
        return stato.schede.sorted { (posto[$0.chiave] ?? .max) < (posto[$1.chiave] ?? .max) }
    }

    var body: some View {
        Group { if stato.verticale { colonna } else { riga } }
            .foregroundStyle(Tema.tenue)
            .font(.system(size: 12.5))
            // T-2: se macOS perde il rilascio del clic durante un trascinamento, ogni 0,3 s si
            // guarda il tasto del mouse: alzato → il trascinamento finisce (niente riordino) e
            // spariscono lineetta e scheda fantasma
            .task(id: trascinata) {
                while trascinata != nil && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                    if trascinata != nil && NSEvent.pressedMouseButtons & 1 == 0 {
                        withAnimationMolla { trascinata = nil; provvisorio = nil }
                    }
                }
            }
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
            let fisso = Misure.gatto + Misure.piu + Misure.tasto * 4 + 16 + (stato.concentrazione != nil ? 20 : 0) + CGFloat(stato.lampiCoperti.count) * 22
            let sch = mostrate
            let att = sch.firstIndex { $0.chiave == stato.attiva && !stato.scrivania }
            let tacca = taccaNellaBarra()
            let d = disponiOrizzontale(spazio: g.size.width - fisso - (tacca.map { $0.a - $0.da + 12 } ?? 0), numero: sch.count, attiva: att)
            let salto = salto(d, sch: sch, att: att, tacca: tacca)
            HStack(spacing: 2) {
                gatto
                if stato.cartellaAperta != nil { testataCartella }
                ForEach(d.visibili.map { sch[$0] }) { s in
                    let i = sch.firstIndex(of: s), on = i == att
                    // nessuna scheda sotto la tacca della fotocamera (margine 6)
                    if let salto, s.chiave == salto.chiave { Color.clear.frame(width: salto.largo) }
                    scheda(s, attiva: on, larghezza: d.compatta ? (on ? Misure.compattaAttiva : Misure.compatta) : d.larghezza,
                           soloIcona: d.compatta && !on)
                }
                if d.altre > 0 { altre(d) }
                piu
                Spacer(minLength: 0)
                batteriaOTempo
                dividi
                fulmine
                impostazioni
            }
            .padding(.horizontal, 2)
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(Tema.sfondo(verticale: false).clipShape(forma))
    }

    /// Dove cade la tacca dentro la barra (coordinate della barra), se Tabby è nella fascia.
    private func taccaNellaBarra() -> (da: CGFloat, a: CGFloat)? {
        guard stato.posizione == "top", Sistema.fasciaNotch, let n = Sistema.notch, let w = Menu.vista?.window else { return nil }
        return (n.da - w.frame.minX, n.a - w.frame.minX)
    }

    /// Prima di quale scheda mettere il vuoto della tacca, e quanto largo.
    private func salto(_ d: DisposizioneOrizzontale, sch: [Scheda], att: Int?, tacca: (da: CGFloat, a: CGFloat)?) -> (chiave: String, largo: CGFloat)? {
        guard let t = tacca else { return nil }
        var x: CGFloat = 2 + Misure.gatto + 2 + (stato.cartellaAperta != nil ? 170 : 0)
        for i in d.visibili {
            let w = d.compatta ? (i == att ? Misure.compattaAttiva : Misure.compatta) : d.larghezza
            if x + w > t.da - 6 { return (sch[i].chiave, max(0, t.a + 6 - x)) }
            x += w + 2
        }
        return nil
    }

    // MARK: di lato

    private var colonna: some View {
        GeometryReader { g in
            let sch = mostrate
            let att = sch.firstIndex { $0.chiave == stato.attiva && !stato.scrivania }
            // A-7: con la barra dei menu che si nasconde (senza notch) in cima resta una fascia vuota
            // alta come lei: quando scende copre solo quella, niente sparisce e niente si sposta
            let fascia: CGFloat = Sistema.barraMenuNascosta && Sistema.notch == nil ? Sistema.altezzaBarraMenu - 4 : 0
            let d = disponiVerticale(spazio: g.size.height - 74 - 30 - 34 - 34 - 24 - fascia, numero: sch.count, attiva: att)
            VStack(spacing: 2) {
                if fascia > 0 { Color.clear.frame(height: fascia) }
                gattoIntero
                if stato.cartellaAperta != nil { testataCartella.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 6) }
                ForEach(d.visibili.map { sch[$0] }) { s in
                    scheda(s, attiva: sch.firstIndex(of: s) == att, larghezza: g.size.width - 12, soloIcona: false, altezza: d.riga - 2)
                }
                if d.altre > 0 { altre(DisposizioneOrizzontale(larghezza: 0, compatta: false, visibili: d.visibili, altre: d.altre), largo: true) }
                piu.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
                Spacer(minLength: 0)
                batteriaOTempo
                if !stato.lampiCoperti.isEmpty { fulmine.frame(maxWidth: .infinity).padding(.horizontal, 6) }
                HStack(spacing: 0) { Spacer(); dividi; if stato.lampiCoperti.isEmpty { fulmine }; impostazioni; Spacer() }
            }
            .padding(.vertical, 6)
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(Tema.sfondo(verticale: true).clipShape(forma))
    }

    // MARK: i pezzi

    /// Le immagini del gatto si leggono dal disco una volta sola (la barra si ridisegna spesso:
    /// a ogni passaggio del mouse, a ogni cambio di scheda).
    @MainActor private static var gatti: [String: NSImage] = [:]
    private func immagineGatto(_ nome: String) -> NSImage? {
        if let i = BarraVista.gatti[nome] { return i }
        guard let u = Bundle.main.url(forResource: nome, withExtension: "png"), let i = NSImage(contentsOf: u) else { return nil }
        i.isTemplate = true
        BarraVista.gatti[nome] = i
        return i
    }

    private var gatto: some View {
        Button { c.gatto() } label: {
            Group {
                if let i = immagineGatto("gatto-spento") { Image(nsImage: i).resizable().scaledToFit().frame(width: 20, height: 20) }
                else { Image(systemName: "pawprint.fill") }
            }
            .foregroundStyle(stato.scrivania ? Tema.suAttiva : Tema.tenue)
            .frame(width: Misure.gatto - 4, height: Misure.altezzaScheda)
            .background {
                // la scheda Scrivania attiva: lo stesso riempimento delle schede, che scivola fin qui
                if stato.scrivania {
                    Tema.riempimento.clipShape(RoundedRectangle(cornerRadius: Misure.angoloScheda))
                        .shadow(color: Tema.ombraAttiva, radius: 5, y: 2)
                        .matchedGeometryEffect(id: "riempimento", in: ns)
                }
            }
            .frame(width: Misure.gatto, height: Misure.gatto)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(CorniceMenu(id: "gatto"))
    }

    private var gattoIntero: some View {
        Button { c.gatto() } label: {
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
        let tr = trascinata == s.chiave
        let su = sopra == s.chiave || tr
        let rid = s.ridotta && !on
        let vista = stato.membri[s.chiave]
        let cartella = stato.membriCartella[s.chiave]
        let scelta = stato.scelta?.contains(s.chiave) == true
        return HStack(spacing: 7) {
            if let gruppo = vista ?? cartella {
                // vista divisa (fino a 4) o cartella (prime 3): le icone delle sue app, sovrapposte
                HStack(spacing: -5) {
                    ForEach(gruppo.prefix(cartella != nil ? 3 : 4)) { m in
                        if let i = m.sito.flatMap({ stato.loghi[$0] }) ?? stato.icone[m.bid] {
                            Image(nsImage: i).resizable().interpolation(.high).frame(width: 16, height: 16)
                                .clipShape(RoundedRectangle(cornerRadius: m.sito != nil ? 4 : 0))
                        }
                    }
                }
            } else if let i = s.sito.flatMap({ stato.loghi[$0] }) ?? stato.icone[s.bid] {
                Image(nsImage: i).resizable().interpolation(.high).frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: s.sito != nil ? 4 : 0))
                    .opacity(rid ? 0.45 : 1)
                    .overlay(alignment: .topTrailing) {
                        // compatta: un puntino rosso al posto del numerino (N-4)
                        if soloIcona, s.notifica != nil {
                            Circle().fill(Tema.notifica).frame(width: 7, height: 7)
                                .overlay(Circle().stroke(Tema.c(0x0F0D09), lineWidth: 1.5)).offset(x: 4, y: -4)
                        }
                    }
            }
            if !soloIcona {
                if stato.rinomina == s.chiave {
                    // si scrive direttamente sulla scheda, come un file nel Finder (DESIGN 3.2)
                    TextField("", text: $stato.nomeInModifica)
                        .textFieldStyle(.plain).focused($scrivendo)
                        .onSubmit { c.fineRinomina(salva: true) }
                        .onKeyPress(.escape) { c.fineRinomina(salva: false); return .handled }
                        .padding(.horizontal, 4).frame(height: 20)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Tema.accento, lineWidth: 1.5))
                        .help("↵ salva · esc annulla · vuoto: torna al nome di prima")
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { scrivendo = true } }
                } else {
                    NomeCorto(nome: s.nome).italic(rid).opacity(rid ? 0.7 : 1)
                }
                Spacer(minLength: 0)
                if let n = s.notifica { numerino(n) }
                if let cartella {
                    // la cartella: quante schede, e ⋯ per il suo menu
                    Text("\(cartella.count)").font(.system(size: 9.5, weight: .bold)).monospacedDigit()
                        .padding(.horizontal, 3).frame(minWidth: 15, minHeight: 14)
                        .background(on ? Color.black.opacity(0.16) : Tema.sopra, in: RoundedRectangle(cornerRadius: 4))
                    Button { apriMenuCartella(s.chiave) } label: {
                        Image(systemName: "ellipsis").font(.system(size: 11, weight: .bold)).opacity(0.7)
                            .frame(width: 18, height: 18).contentShape(Rectangle())
                    }.buttonStyle(.plain).background(CorniceMenu(id: "m:" + s.chiave))
                } else if vista != nil, on || su {
                    // ⇄ Scambia e Scomponi al posto della ✕
                    Button { c.scambia(s.chiave) } label: {
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 10.5, weight: .medium)).opacity(0.7)
                            .frame(width: 18, height: 18).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Scambia  ⌃⌥S")
                    Button { c.scomponi(s.chiave) } label: {
                        Image(systemName: "rectangle.split.2x1").font(.system(size: 10.5, weight: .medium)).opacity(0.7)
                            .frame(width: 18, height: 18).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Scomponi")
                } else if on || su {
                    Button { clicSullaX(s) } label: {
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
                    .shadow(color: Tema.ombraAttiva, radius: 5, y: 2)
                    .matchedGeometryEffect(id: "riempimento", in: ns)
            } else if tr {
                // la scheda in mano: fondo pieno e ombra, così si legge sopra le altre
                RoundedRectangle(cornerRadius: Misure.angoloScheda).fill(Tema.c(0x26231B))
                    .overlay(RoundedRectangle(cornerRadius: Misure.angoloScheda).strokeBorder(Tema.c(0xFFE2A0, 0.14), lineWidth: 0.5))
            } else if su {
                RoundedRectangle(cornerRadius: Misure.angoloScheda).fill(Tema.sopra)
            }
        }
        .overlay {
            // scelta in un foglio (cartella, Concentrazione): contorno del tema + spunta
            if scelta {
                RoundedRectangle(cornerRadius: Misure.angoloScheda).strokeBorder(Tema.accento, lineWidth: 1.5)
                    .shadow(color: Tema.accento.opacity(0.5), radius: 4)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Tema.suAttiva, Tema.accento)
                            .background(Circle().fill(Tema.c(0x0F0D09)).padding(-1)).offset(x: 4, y: -4)
                    }
            }
        }
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(tr ? 0.5 : 0), radius: 10, y: 4)
        .offset(tr ? scostamento(s.chiave) : .zero)
        .zIndex(tr ? 1 : 0)
        .background(CorniceMenu(id: "t:" + s.chiave))       // il posto della scheda (senza lo spostamento)
        .onHover { dentro in sopra = dentro ? s.chiave : (sopra == s.chiave ? nil : sopra) }
        // il doppio clic rinomina; si legge dal clic stesso, così il clic singolo resta immediato
        .onTapGesture {
            if NSApp.currentEvent?.clickCount == 2, !s.chiave.hasPrefix("g:") { c.iniziaRinomina(s.chiave) } else { c.vai(s) }
        }
        .contextMenu { menuScheda(s) }
        .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { v in muovi(s.chiave, v) }
            .onEnded { v in lascia(s.chiave, in: v.location) })
        .help(soloIcona ? s.nome : "")
    }

    /// Il tasto destro su una scheda (DESIGN 3.1): Rinomina · Torna al nome di prima · Chiudi.
    @ViewBuilder private func menuScheda(_ s: Scheda) -> some View {
        if !s.chiave.hasPrefix("g:") {
            Button { c.iniziaRinomina(s.chiave) } label: { Label("Rinomina", systemImage: "square.and.pencil") }
        }
        if c.haNomeTuo(s.chiave) {
            Button { c.tornaAlNome(s.chiave) } label: { Label("Torna al nome di prima", systemImage: "arrow.uturn.backward") }
        }
        // B-8: per una finestra di browser con più siti, quale mostrare
        let siti = c.siti(di: s)
        if siti.count > 1 || c.sitiScelti[s.finestra ?? 0] != nil {
            SwiftUI.Menu {
                ForEach(siti, id: \.self) { d in
                    Button { c.scegliSito(s, d) } label: { Text(nomeSito(titolo: nil, dominio: d)) }
                }
                if c.sitiScelti[s.finestra ?? 0] != nil {
                    Divider()
                    Button { c.scegliSito(s, nil) } label: { Text("Il nome del browser") }
                }
            } label: { Label("Mostra come", systemImage: "globe") }
        }
        // S-3: le finestre di un'app (non dei browser) in una scheda sola, o una per finestra
        if browserNoti[s.bid] == nil, !s.chiave.hasPrefix("g:"), !s.chiave.hasPrefix("f:"),
           c.finestreUnite(s.bid) || c.tutte.filter({ $0.bid == s.bid }).count > 1 {
            let unite = c.finestreUnite(s.bid)
            Button { c.uniscFinestre(s.bid, !unite) } label: {
                Label(unite ? "Una scheda per finestra" : "Tutte le finestre in una scheda", systemImage: unite ? "square.split.2x1" : "square.on.square")
            }
        }
        if s.chiave.hasPrefix("f:"), let id = Int(s.chiave.dropFirst(2)) {
            Button { c.apriFoglioCartella(id) } label: { Label("Modifica la cartella", systemImage: "square.stack.3d.up") }
        } else if !s.chiave.hasPrefix("g:") {
            Divider()
            Button { c.chiudiFinestra(s) } label: { Label("Chiudi la finestra", systemImage: "xmark") }
        }
    }

    /// Il numerino rosso delle notifiche, come in macOS (oltre 99: «99+»; senza numero: un pallino).
    @ViewBuilder private func numerino(_ n: String) -> some View {
        // un numero (oltre 99: «99+»), anche già scritto dall'app come «99+»; altrimenti un pallino
        if let t = Int(n).map({ $0 > 99 ? "99+" : n }) ?? (n.contains(where: \.isNumber) ? n : nil) {
            Text(t).font(.system(size: 10, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
                .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 15)
                .background(Capsule().fill(Tema.notifica))
        } else { Circle().fill(Tema.notifica).frame(width: 7, height: 7) }
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

    /// Durante la Concentrazione, al posto della batteria un cerchio che si riempie col tempo
    /// passato (come il consumo dei limiti di Claude; deciso con Daniele il 10/11/2026). Un clic:
    /// quanto manca, aggiungi o togli minuti (H-3).
    @ViewBuilder private var batteriaOTempo: some View {
        if let conc = stato.concentrazione {
            Button { apriMenuTempo() } label: {
                TimelineView(.periodic(from: .now, by: 5)) { ctx in
                    let resto = conc.fine.map { $0.timeIntervalSince(ctx.date) }
                    let tot = conc.fine.map { $0.timeIntervalSince(conc.inizio) } ?? 1
                    let fatto = resto.map { max(0, min(1, 1 - $0 / max(tot, 1))) } ?? 0
                    ZStack {
                        Circle().stroke(Tema.sopra, lineWidth: 3)
                        Circle().trim(from: 0, to: fatto)
                            .stroke(Tema.accento, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.6), value: fatto)
                        if resto == nil { Text("∞").font(.system(size: 9, weight: .semibold)).foregroundStyle(Tema.tenue) }
                    }
                    .frame(width: 17, height: 17)
                    .frame(width: 34, height: stato.verticale ? 38 : Misure.altezza)
                    .help(resto.map { "Concentrazione · mancano " + tempoCheManca($0) } ?? "Concentrazione · senza tempo")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(CorniceMenu(id: "tempo"))
        } else { batteria }
    }

    private func apriMenuTempo() {
        guard let conc = stato.concentrazione else { return }
        let m = NSMenu()
        m.addItem(NSMenuItem.sectionHeader(title: conc.fine.map { "Concentrazione · mancano " + tempoCheManca($0.timeIntervalSinceNow) } ?? "Concentrazione · senza tempo"))
        m.addItem(Menu.voce("+5 minuti", simbolo: "plus") { c.prolunga(5) })
        m.addItem(Menu.voce("+15 minuti", simbolo: "plus") { c.prolunga(15) })
        if conc.fine.map({ $0.timeIntervalSinceNow > 6 * 60 }) == true {
            m.addItem(Menu.voce("−5 minuti", simbolo: "minus") { c.prolunga(-5) })
        }
        m.addItem(.separator())
        m.addItem(Menu.voce("Termina adesso", simbolo: "stop") { c.fineConcentrazione(suono: false) })
        Menu.apri(m, sopra: CorniceMenu.cornici["tempo"] ?? .zero)
    }

    /// ⚡︎ i Lampi. Quando un Lampo è coperto da un'altra finestra il tasto si allarga con la sua
    /// icona (e «Tutti» se sono due o più): un clic lo riporta davanti (Q-1).
    private var fulmine: some View {
        HStack(spacing: 4) {
            Button { apriMenuLampi() } label: {
                Image(systemName: "sparkles").font(.system(size: 14))
                    .frame(width: stato.lampiCoperti.isEmpty ? Misure.tasto : 20, height: stato.verticale ? Misure.tasto : Misure.altezza)
                    .foregroundStyle(Tema.accento).contentShape(Rectangle())
            }.buttonStyle(.plain).background(CorniceMenu(id: "lampi"))
            ForEach(stato.lampiCoperti, id: \.self) { b in
                Button { c.lampi.riporta([b]) } label: {
                    if let i = stato.icone[b] ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: b).map({ NSWorkspace.shared.icon(forFile: $0.path) }) {
                        Image(nsImage: i).resizable().frame(width: 18, height: 18)
                    }
                }.buttonStyle(.plain)
            }
            if stato.lampiCoperti.count >= 2 {
                Button("Tutti") { c.lampi.riporta(stato.lampiCoperti) }.buttonStyle(.plain).font(.system(size: 11.5)).foregroundStyle(Tema.testo)
            }
        }
        .padding(.horizontal, stato.lampiCoperti.isEmpty ? 0 : 6)
        .frame(height: Misure.altezzaScheda)
        .background(stato.lampiCoperti.isEmpty ? .clear : Tema.sopra, in: RoundedRectangle(cornerRadius: Misure.angoloScheda))
        .help("Lampi")
    }

    /// Il menu ⚡︎ (DESIGN 3.1): in cima la riga dei Lampi, poi Strumenti, App e Personalizza.
    private func apriMenuLampi() {
        let m = NSMenu()
        let aperti = Set(c.lampi.aperti.map(\.id))
        let riga = NSMenuItem()
        let vista = NSHostingView(rootView: RigaLampi(lampi: c.lampi.lampi.filter { !$0.barraMenu }, aperti: aperti) { l in
            m.cancelTracking(); c.lampi.premi(l)
        })
        vista.frame.size = vista.fittingSize
        riga.view = vista
        m.addItem(NSMenuItem.sectionHeader(title: "Lampi · \(aperti.count) \(aperti.count == 1 ? "aperto" : "aperti")"))
        m.addItem(riga)
        m.addItem(.separator())
        m.addItem(NSMenuItem.sectionHeader(title: "Strumenti"))
        if let conc = stato.concentrazione {
            let v = Menu.voce("Concentrazione · " + (conc.fine.map { "mancano " + tempoCheManca($0.timeIntervalSinceNow) } ?? "senza tempo"), simbolo: "target") { apriMenuTempo() }
            m.addItem(v)
        } else {
            m.addItem(Menu.voce("Concentrazione…", simbolo: "target") { c.apriFoglioConcentrazione() })
        }
        let cerca = Menu.voce("Cerca", simbolo: "text.magnifyingglass") { c.apriRicerca() }
        cerca.keyEquivalent = " "; cerca.keyEquivalentModifierMask = [.control, .option]
        m.addItem(cerca)
        let app = c.lampi.lampi.filter(\.barraMenu)
        let scoperte = c.lampi.appBarraMenu.filter { a in !app.contains { $0.bid == a.bid } }
        if !app.isEmpty || !scoperte.isEmpty {
            m.addItem(.separator())
            m.addItem(NSMenuItem.sectionHeader(title: "App"))
            for l in app {
                let v = Menu.voce(l.nome, tasto: l.tasto) { c.lampi.premi(l) }
                if let b = l.bid, let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
                    v.image = Menu.icona(NSWorkspace.shared.icon(forFile: u.path))
                }
                m.addItem(v)
            }
            if !scoperte.isEmpty {
                let sotto = NSMenu()
                for a in scoperte {
                    let v = Menu.voce("Apri \(a.nome)") { c.lampi.premiNellaBarraDeiMenu(Lampo(bid: a.bid, nome: a.nome, tasto: "", barraMenu: true)) }
                    if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: a.bid) {
                        v.image = Menu.icona(NSWorkspace.shared.icon(forFile: u.path))
                    }
                    sotto.addItem(v)
                }
                let t = Menu.voce("Tutte le App", simbolo: "menubar.rectangle"); t.submenu = sotto; t.isEnabled = true
                m.addItem(t)
            }
        }
        // le cartelle (deciso con Daniele il 9/11/2026: dal gatto passano qui)
        m.addItem(.separator())
        m.addItem(NSMenuItem.sectionHeader(title: "Cartelle"))
        for (n, f) in stato.cartelle.enumerated() {
            let v = Menu.voce(f.nome, simbolo: "square.stack.3d.up", tasto: n < 9 ? "\(n + 1)" : "") { c.attivaCartella(f.id) }
            if n < 9 { v.keyEquivalentModifierMask = [.control, .option, .shift] }
            v.state = c.attive.contains(f.id) ? .on : .off
            m.addItem(v)
        }
        m.addItem(Menu.voce("Nuova cartella…", simbolo: "plus") { c.apriFoglioCartella() })
        if !stato.cartelle.isEmpty {                 // modificare o eliminare anche le cartelle spente
            let sotto = NSMenu()
            for f in stato.cartelle { sotto.addItem(Menu.voce(f.nome, simbolo: "square.stack.3d.up") { c.apriFoglioCartella(f.id) }) }
            let v = Menu.voce("Modifica o elimina…", simbolo: "square.and.pencil"); v.submenu = sotto
            m.addItem(v)
        }
        m.addItem(.separator())
        m.addItem(Menu.voce("Personalizza i Lampi…", simbolo: "slider.horizontal.3") { c.apriFoglioLampi() })
        Menu.apri(m, sopra: CorniceMenu.cornici["lampi"] ?? .zero)
    }

    /// ⊞ Dividi lo schermo: il menu con gli schemi. Acceso mentre dividi o su una vista divisa.
    private var dividi: some View {
        let acceso = stato.divisione != nil || stato.attiva?.hasPrefix("g:") == true
        return Button { apriDividi() } label: {
            Image(systemName: "rectangle.grid.2x2").font(.system(size: 14))
                .frame(width: Misure.tasto, height: stato.verticale ? Misure.tasto : Misure.altezza)
                .foregroundStyle(acceso ? Tema.accento : sopra == "⊞" ? Tema.testo : Tema.tenue)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { sopra = $0 ? "⊞" : nil }
        .background(CorniceMenu(id: "dividi"))
        .help("Dividi lo schermo")
    }

    private func apriDividi() {
        if stato.divisione != nil { c.annullaDivisione(); return }
        let m = NSMenu()
        for sc in schemi {
            let v = Menu.voce(sc.nome) { c.avviaDivisione(sc.id) }
            v.image = figurina(sc)
            m.addItem(v)
        }
        Menu.apri(m, sopra: CorniceMenu.cornici["dividi"] ?? .zero)
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

    /// Quanto spostare la scheda in mano dal suo posto, perché segua il puntatore.
    private func scostamento(_ k: String) -> CGSize {
        guard let f = CorniceMenu.cornici["t:" + k] else { return .zero }
        return stato.verticale ? CGSize(width: 0, height: puntatore.y - presa - f.minY)
                               : CGSize(width: puntatore.x - presa - f.minX, height: 0)
    }

    /// Da un punto della barra (coordinate di SwiftUI, dall'alto) a un punto dello schermo.
    private func schermo(_ p: CGPoint) -> NSPoint {
        guard let w = Menu.vista?.window else { return p }
        return NSPoint(x: w.frame.minX + p.x, y: w.frame.maxY - p.y)
    }

    /// Mentre trascini: la scheda segue il puntatore e le altre si spostano per farle posto.
    private func muovi(_ k: String, _ v: DragGesture.Value) {
        if stato.divisione != nil { c.trascinaInDivisione(k, schermo(v.location)); return }   // verso le zone
        if stato.scelta != nil { c.trascinaNelFoglio(schermo(v.location)); return }          // verso il foglio
        if trascinata == nil, let f = CorniceMenu.cornici["t:" + k] {
            presa = stato.verticale ? v.startLocation.y - f.minY : v.startLocation.x - f.minX
            provvisorio = stato.schede.map(\.chiave)
            trascinata = k
        }
        puntatore = v.location
        let altre = cornici(tranne: k)
        guard var o = provvisorio, let ultima = altre.last else { return }
        let davanti = altre.first { stato.verticale ? v.location.y < $0.f.midY : v.location.x < $0.f.midX }?.chiave
        o.removeAll { $0 == k }
        if let d = davanti, let i = o.firstIndex(of: d) { o.insert(k, at: i) }
        else if let i = o.firstIndex(of: ultima.chiave) { o.insert(k, at: i + 1) }
        else { o.append(k) }
        if o != provvisorio { withAnimationMolla { provvisorio = o } }
    }

    private func lascia(_ k: String, in p: CGPoint) {
        if stato.divisione != nil { c.lasciaInDivisione(k, schermo(p)); return }
        if stato.scelta != nil { c.lasciaNelFoglio(k, schermo(p)); return }
        let b = Menu.vista?.bounds ?? .zero
        let dentro = b.insetBy(dx: -24, dy: -24).contains(p)    // fuori dalla barra (margine 24) → niente
        if dentro, let o = provvisorio, let i = o.firstIndex(of: k) {
            c.riordina(k, davanti: i + 1 < o.count ? o[i + 1] : nil)
        }
        withAnimationMolla { trascinata = nil; provvisorio = nil }
    }

    /// La vista cartella (F-6): «‹» per tornare a tutte le schede, e l'etichetta della cartella —
    /// nel colore del tema, col simbolo della cartella e quante schede ha, così non sembra una
    /// scheda (clic = il suo menu).
    @ViewBuilder private var testataCartella: some View {
        if let id = stato.cartellaAperta, let f = stato.cartelle.first(where: { $0.id == id }) {
            HStack(spacing: 4) {
                Button { c.esciDallaVistaCartella() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tema.testo)
                        .frame(width: 28, height: Misure.altezzaScheda)
                        .background(sopra == "←" ? Tema.sopra : .clear, in: RoundedRectangle(cornerRadius: Misure.angoloScheda))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).onHover { sopra = $0 ? "←" : nil }.help("Tutte le schede")
                Button { apriMenuCartella(f.chiave) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 12))
                        Text(f.nome).font(.system(size: 13, weight: .semibold))
                        Text("\(stato.schede.count)").font(.system(size: 10, weight: .bold)).monospacedDigit().opacity(0.7)
                    }
                    .foregroundStyle(Tema.accento)
                    .padding(.horizontal, 10).frame(height: Misure.altezzaScheda - 4)
                    .background(Capsule().fill(Tema.accento.opacity(sopra == "cartella" ? 0.24 : 0.15)))
                    .overlay(Capsule().strokeBorder(Tema.accento.opacity(0.45), lineWidth: 0.75))
                    .contentShape(Capsule())
                }.buttonStyle(.plain).onHover { sopra = $0 ? "cartella" : nil }
            }
            .padding(.trailing, 6)
        }
    }

    /// Il menu ⋯ di una cartella (F-5).
    private func apriMenuCartella(_ chiave: String) {
        guard let id = Int(chiave.dropFirst(2)), let f = stato.cartelle.first(where: { $0.id == id }) else { return }
        let m = NSMenu()
        m.addItem(NSMenuItem.sectionHeader(title: f.nome))
        for s in stato.membriCartella[chiave] ?? [] {
            let v = Menu.voce(s.nome) { c.entraNellaCartella(id, su: s.chiave) }
            v.image = Menu.icona(s.sito.flatMap { stato.loghi[$0] } ?? stato.icone[s.bid])
            v.state = c.ultimaDi[id] == s.chiave ? .on : .off
            m.addItem(v)
        }
        m.addItem(.separator())
        if stato.cartellaAperta != id { m.addItem(Menu.voce("Apri la cartella", simbolo: "arrow.up.forward.square") { c.entraNellaCartella(id) }) }
        m.addItem(Menu.voce("Modifica le schede…", simbolo: "square.and.pencil") { c.apriFoglioCartella(id) })
        m.addItem(Menu.voce("Aggiorna con le schede di adesso", simbolo: "arrow.clockwise") { c.aggiornaCartella(id) })
        m.addItem(Menu.voce("Esci dalla cartella", simbolo: "arrow.uturn.backward") { c.esciDallaCartella(id) })
        m.addItem(Menu.voce("Chiudi la cartella", simbolo: "xmark") { c.chiudiCartella(id) })
        m.addItem(.separator())
        m.addItem(Menu.voce("Elimina la cartella", simbolo: "trash") { c.eliminaCartella(id) })
        Menu.apri(m, sopra: CorniceMenu.cornici["m:" + chiave] ?? .zero)
    }

    // MARK: i menu

    /// ✕: un clic apre il menu (C-1); **doppio clic** chiude subito (Daniele, 10/11/2026): la
    /// finestra, o l'app intera se era la sua sola finestra. Il menu aspetta il tempo del doppio
    /// clic del Mac (Impostazioni → Mouse), per capire se arriva il secondo: prima 0,3 s, più
    /// stretto del Mac (0,5 s), e un doppio clic un po' lento apriva il menu.
    private func clicSullaX(_ s: Scheda) {
        let attesa = NSEvent.doubleClickInterval
        if NSApp.currentEvent?.clickCount ?? 1 >= 2 || primoClicX.map({ $0.chiave == s.chiave && Date().timeIntervalSince($0.quando) < attesa + 0.05 }) == true {
            primoClicX?.menu.cancel(); primoClicX = nil
            c.chiudiDavvero(s)
            return
        }
        primoClicX?.menu.cancel()
        let m = DispatchWorkItem { apriChiudi(s); primoClicX = nil }
        primoClicX = (s.chiave, Date(), m)
        DispatchQueue.main.asyncAfter(deadline: .now() + attesa, execute: m)
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
            v.image = Menu.icona(s.sito.flatMap { stato.loghi[$0] } ?? stato.icone[s.bid])
            m.addItem(v)
        }
        Menu.apri(m, sopra: CorniceMenu.cornici["altre"] ?? .zero)
    }

    /// Il menu ⚙︎ (DESIGN 3.1): Tabby… · Impostazioni · Scorciatoie · Posizione · Chiudi tutte le
    /// app (conferma col secondo clic) · Metti in pausa Tabby (con ⌥: Esci da Tabby).
    private func apriImpostazioni() {
        let m = NSMenu()
        let tabby = Menu.voce("Tabby…", simbolo: "text.magnifyingglass") { c.apriRicerca(con: "Tabby ") }
        m.addItem(tabby)
        m.addItem(Menu.voce("Impostazioni", simbolo: "gearshape") { c.apriFinestraTabby(sezione: "set") })
        m.addItem(Menu.voce("Scorciatoie", simbolo: "command", tasto: "/") { c.apriFinestraTabby(sezione: "doc") })
        let pos = NSMenu()
        for (k, t) in [("top", "In alto"), ("right", "A destra"), ("left", "A sinistra"), ("bottom", "In basso")] {
            pos.addItem(Menu.voce(t, segno: stato.posizione == k) { c.cambiaPosizione(k) })
        }
        let p = Menu.voce("Posizione", simbolo: "macwindow"); p.submenu = pos; p.isEnabled = true
        m.addItem(p)
        m.addItem(.separator())
        let tutte = NSMenuItem()
        let conferma = NSHostingView(rootView: VoceConferma(titolo: "Chiudi tutte le app…", conferma: "Clic di nuovo per chiudere tutte") {
            m.cancelTracking(); c.chiudiTutteLeApp()
        })
        conferma.frame.size = NSSize(width: 250, height: 22)
        tutte.view = conferma
        m.addItem(tutte)
        m.addItem(Menu.voce("Metti in pausa Tabby", simbolo: "pause.circle") { c.pausa(true) })
        m.addItem(Menu.voce("Chiudi Tabby", simbolo: "macwindow") { c.chiudiTabby() })
        let esci = Menu.voce("Esci da Tabby", simbolo: "power") { NSApp.terminate(nil) }
        esci.isAlternate = true; esci.keyEquivalentModifierMask = [.option]
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

/// La riga dei Lampi in cima al menu ⚡︎: icone grandi col nome, puntino verde su quelli aperti.
struct RigaLampi: View {
    let lampi: [Lampo]
    let aperti: Set<String>
    let premi: (Lampo) -> Void
    var body: some View {
        HStack(spacing: 4) {
            ForEach(lampi) { l in
                Button { premi(l) } label: {
                    VStack(spacing: 3) {
                        Group {
                            if l.memo { Image(systemName: "note.text").font(.system(size: 18)).foregroundStyle(Tema.accento) }
                            else if let b = l.bid, let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable()
                            }
                        }
                        .frame(width: 28, height: 28)
                        .overlay(alignment: .topTrailing) {
                            if aperti.contains(l.id) { Circle().fill(Color.green).frame(width: 7, height: 7).offset(x: 2, y: -1) }
                        }
                        Text(l.nome).font(.system(size: 10.5)).lineLimit(1).frame(maxWidth: 58)
                        Text("⌃⌥" + l.tasto.uppercased()).font(.system(size: 9.5)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4).frame(width: 62).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
    }
}

/// Una voce di menu che chiede conferma col secondo clic (DESIGN 3.2): al primo diventa rossa.
struct VoceConferma: View {
    let titolo: String
    let conferma: String
    let azione: () -> Void
    @State private var armata = false
    @State private var sopra = false
    var body: some View {
        Text(armata ? conferma : titolo)
            .font(.system(size: 13)).foregroundStyle(armata ? .white : (sopra ? .white : .primary))
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).frame(height: 22)
            .background(armata ? Color.red : (sopra ? Color.accentColor : .clear), in: RoundedRectangle(cornerRadius: 5))
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
            .onHover { sopra = $0 }
            .onTapGesture { if armata { azione() } else { armata = true } }
    }
}
