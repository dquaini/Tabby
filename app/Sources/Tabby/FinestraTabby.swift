import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI
import TabbyCore

/// La finestra di Tabby (DESIGN 3.9): schermo nero; ogni volta che l'app si apre da zero le due
/// animazioni (mentre girano Tabby si prepara dietro); al primo avvio la guida coi permessi; poi
/// al centro il riquadro di Spotlight con le cartelle ai lati e in alto le sezioni. Le pagine
/// sono solo testo bianco su nero, in SF Pro: niente scatole, la scelta è la parola bianca.
@MainActor @Observable
final class StatoFinestra {
    enum Fase: Equatable { case logo, logoFinito, gatto, guida(Int), casa }
    var fase: Fase = .casa
    var sezione: String?                         // "set", "des", "doc", "aut", "kat"
    var permessoDato = Permessi.accessibilita
}

@MainActor
final class FinestraTabby: NSPanel {
    let f = StatoFinestra()
    private unowned let c: Controllore
    private var appPrima: NSRunningApplication?

    init(_ c: Controllore) {
        self.c = c
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = true
        backgroundColor = .black
        hidesOnDeactivate = false
        contentView = VistaOspite(rootView: VistaFinestra(c: c, f: f, stato: c.stato, aspetto: Aspetto.shared))
    }

    override var canBecomeKey: Bool { true }

    /// All'avvio: le animazioni, poi (solo la prima volta) la guida.
    func avvio() {
        f.fase = .logo; f.sezione = nil
        apri()
    }

    /// Da Tabby già avviata (impostazioni, scorciatoie): niente animazioni, dritti alla pagina.
    func mostra(sezione: String?) {
        f.fase = .casa; f.sezione = sezione
        apri()
    }

    private func apri() {
        appPrima = NSWorkspace.shared.frontmostApplication
        setFrame(Sistema.schermo.frame, display: true)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.3; animator().alphaValue = 1 }
    }

    /// ✕ o esc: si torna alle app (la barra resta).
    func chiudi(tornando: Bool = true) {
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; animator().alphaValue = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { [weak self] in
            self?.orderOut(nil); self?.c.controllaSfera()
        }
        if tornando, let a = appPrima, a.bundleIdentifier != Sistema.mioBid { a.activate() }
    }

    override func cancelOperation(_ sender: Any?) {
        if f.sezione != nil { withAnimation(Tema.molla) { f.sezione = nil } } else { chiudi() }
    }
}

// MARK: - La vista

private struct VistaFinestra: View {
    let c: Controllore
    @Bindable var f: StatoFinestra
    @Bindable var stato: StatoBarra
    @Bindable var aspetto: Aspetto

    var body: some View {
        ZStack {
            Color.black
            switch f.fase {
            case .logo, .logoFinito:
                Video(nome: "1-logo") { f.fase = .logoFinito }
                if f.fase == .logoFinito {
                    Text("clicca per continuare").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 70)
                }
            case .gatto:
                Video(nome: "2-gatto") { dopoLeAnimazioni() }
            case .guida(let n):
                Guida(c: c, f: f, passo: n)
            case .casa:
                casa
            }
            if f.fase == .logo || f.fase == .gatto {
                Button("Salta") { dopoLeAnimazioni() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(20)
            }
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture { if f.fase == .logoFinito { f.fase = .gatto } }
    }

    private func dopoLeAnimazioni() {
        withAnimation(.easeInOut(duration: 0.4)) {
            f.fase = (Impostazioni.shared.valore("primoAvvioFatto") as? Bool ?? false) ? .casa : .guida(0)
        }
    }

    // MARK: la casa: sezioni in alto, riquadro di Spotlight al centro, cartelle ai lati

    private var casa: some View {
        VStack(spacing: 0) {
            // le sezioni restano ferme in alto: le pagine scorrono sotto, senza passarci sopra
            HStack(spacing: 22) {
                ForEach([("set", "Impostazioni", "gearshape"), ("des", "Design", "paintpalette"), ("doc", "Documentazione", "book.closed"),
                         ("aut", "Automazione", "clock.arrow.2.circlepath"), ("kat", "Kat", "tray.full")], id: \.0) { id, nome, simbolo in
                    Button { withAnimation(Tema.molla) { f.sezione = f.sezione == id ? nil : id } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: simbolo).font(.system(size: 13))
                            Text(nome).font(.system(size: 13.5))
                            if id == "aut" || id == "kat" { Text("presto").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)) }
                        }
                        .foregroundStyle(.white.opacity(f.sezione == id ? 1 : 0.45))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Button { c.finestraTabby.chiudi() } label: { Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)) }
                    .buttonStyle(.plain).padding(.trailing, 24).help("Chiudi (esc)")
            }
            .padding(.top, 26).padding(.bottom, 10)
            ZStack {
                if let s = f.sezione {
                    ScrollView {
                        Pagina(c: c, f: f, stato: stato, aspetto: aspetto, sezione: s).frame(width: 640, alignment: .leading)
                            .padding(.top, 60).padding(.bottom, 120)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.never)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06),
                                                 .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .transition(.opacity.combined(with: .offset(y: 12)))
                } else {
                    riquadro.offset(y: -30).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Il riquadro di Spotlight sempre al centro; le cartelle si alternano a destra e a sinistra.
    private var riquadro: some View {
        let fs = stato.cartelle
        let destra = fs.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let sinistra = Array(fs.enumerated().filter { $0.offset % 2 == 1 }.map(\.element).reversed())
        return HStack(alignment: .top, spacing: 34) {
            HStack(spacing: 34) { ForEach(sinistra, id: \.id) { cartella($0) } }.frame(maxWidth: .infinity, alignment: .trailing)
            Button { c.finestraTabby.chiudi(tornando: false); c.nuovaApp() } label: {
                RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .frame(width: 96, height: 96)
                    .overlay(Image(systemName: "plus").font(.system(size: 26, weight: .light)).foregroundStyle(.white.opacity(0.75)))
                    .shadow(color: .white.opacity(0.35), radius: 14, y: 10)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).help("Apri un'app")
            HStack(spacing: 34) { ForEach(destra, id: \.id) { cartella($0) } }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cartella(_ x: Cartella) -> some View {
        Button { c.finestraTabby.chiudi(tornando: false); c.attivaCartella(x.id) } label: {
            VStack(spacing: 9) {
                LazyVGrid(columns: [GridItem(.fixed(22), spacing: 4), GridItem(.fixed(22), spacing: 4)], spacing: 4) {
                    ForEach(Array(x.voci.prefix(4).enumerated()), id: \.offset) { _, v in iconaVoce(v).frame(width: 22, height: 22) }
                }
                .frame(width: 48, height: 48)
                Text(x.nome).font(.system(size: 13))
            }
            .frame(width: 96, height: 96).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func iconaVoce(_ v: Voce) -> some View {
        if let s = v.sito, let l = stato.loghi[s] { Image(nsImage: l).resizable().clipShape(RoundedRectangle(cornerRadius: 5)) }
        else if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: v.bid) { Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable() }
    }
}

/// Un video centrato (non a tutto schermo), col marchio in basso a destra coperto.
private struct Video: NSViewRepresentable {
    let nome: String
    let finito: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        guard let u = Bundle.main.url(forResource: nome, withExtension: "mp4") else { DispatchQueue.main.async(execute: finito); return v }
        let p = AVPlayer(url: u)
        let l = AVPlayerLayer(player: p)
        l.videoGravity = .resizeAspect
        v.layer?.addSublayer(l)
        let copri = CALayer(); copri.backgroundColor = NSColor.black.cgColor        // il marchio «creato con…»
        v.layer?.addSublayer(copri)
        context.coordinator.strati = (l, copri)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in finito() }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { p.seek(to: CMTime(seconds: 9.5, preferredTimescale: 600)) }
        p.play()
        return v
    }

    func updateNSView(_ v: NSView, context: Context) {
        guard let (l, copri) = context.coordinator.strati else { return }
        DispatchQueue.main.async {
            let w = v.bounds.width * 0.34, h = w * 0.55
            l.frame = CGRect(x: (v.bounds.width - w) / 2, y: (v.bounds.height - h) / 2, width: w, height: h)
            let r = l.videoRect
            copri.frame = CGRect(x: r.maxX - r.width * 0.24, y: r.minY, width: r.width * 0.24 + 1, height: r.height * 0.13)
        }
    }

    func makeCoordinator() -> Coordinatore { Coordinatore() }
    final class Coordinatore { var strati: (AVPlayerLayer, CALayer)? }
}

// MARK: - Le pagine: solo testo bianco su nero

/// Una riga: nome e spiegazione a sinistra, a destra le scelte come parole (la scelta è bianca).
private struct Riga<Destra: View>: View {
    let titolo: String
    var sotto: String?
    @ViewBuilder let destra: () -> Destra
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(titolo).font(.system(size: 13.5, weight: .medium))
                if let sotto { Text(sotto).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)) }
            }
            Spacer()
            destra()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
}

/// Una frase con una scelta dentro: «Tabby sta **in alto**.» Un clic sulla parola chiara e sotto
/// compaiono le alternative; scelta una, la frase si richiude.
private struct Frase<Dopo: View>: View {
    let prima: String
    let scelte: [String]
    let scelta: String
    let fine: String
    let scegli: (String) -> Void
    let dopo: () -> Dopo
    @State private var aperta = false

    init(_ prima: String, _ scelte: [String], _ scelta: String, _ fine: String, scegli: @escaping (String) -> Void,
         @ViewBuilder dopo: @escaping () -> Dopo = { EmptyView() }) {
        self.prima = prima; self.scelte = scelte; self.scelta = scelta; self.fine = fine; self.scegli = scegli; self.dopo = dopo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if !prima.isEmpty { Text(prima).foregroundStyle(.white.opacity(0.5)) }
                Button { if scelte.count > 1 { withAnimation(Tema.molla) { aperta.toggle() } } } label: {
                    Text(scelta).foregroundStyle(.white).fontWeight(.semibold)
                        .overlay(alignment: .bottom) {
                            if scelte.count > 1 { Rectangle().fill(.white.opacity(aperta ? 0.9 : 0.25)).frame(height: 1.5).offset(y: 3) }
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                if !fine.isEmpty { Text(fine).foregroundStyle(.white.opacity(0.5)).padding(.leading, fine.first == "." || fine.first == "," || fine.first == ":" ? -7 : 0) }
                dopo()
            }
            .font(.system(size: 22))
            if aperta {
                HStack(spacing: 22) {
                    ForEach(scelte.filter { $0 != scelta }, id: \.self) { s in
                        Button { scegli(s); withAnimation(Tema.molla) { aperta = false } } label: {
                            Text(s).font(.system(size: 16)).foregroundStyle(.white.opacity(0.55)).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .padding(.vertical, 12)
    }
}

/// Un'azione: un nome, una riga sotto, e il verbo da cliccare («modifica →»).
private struct Azione: View {
    let nome: String
    let sotto: String?
    let verbo: String
    var rosso = false
    let fai: () -> Void
    init(_ nome: String, _ sotto: String?, _ verbo: String, rosso: Bool = false, fai: @escaping () -> Void) {
        self.nome = nome; self.sotto = sotto; self.verbo = verbo; self.rosso = rosso; self.fai = fai
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(nome).font(.system(size: 17, weight: .medium))
                if let sotto { Text(sotto).font(.system(size: 13)).foregroundStyle(.white.opacity(0.42)).lineLimit(1) }
            }
            Spacer(minLength: 24)
            Button(action: fai) {
                Text(verbo + " →").font(.system(size: 15, weight: .medium))
                    .foregroundStyle(rosso ? Color(red: 1, green: 0.42, blue: 0.38) : .white.opacity(0.8))
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 11)
    }
}

private struct Spazio: View { var body: some View { Color.clear.frame(height: 34) } }


private struct Pagina: View {
    let c: Controllore
    @Bindable var f: StatoFinestra
    @Bindable var stato: StatoBarra
    @Bindable var aspetto: Aspetto
    let sezione: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch sezione {
            case "set": impostazioni
            case "des": design
            case "doc": documentazione
            case "aut": presto("clock.arrow.2.circlepath", "Automazione", "Presto: le cartelle che si aprono da sole, all'ora giusta o quando accendi il Mac.")
            default: presto("tray.full", "Kat", "Presto: una cartella del Mac legata a Tabby, col Memo e i file che creerai.")
            }
        }
    }

    private func titolo(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.system(size: 34, weight: .bold))
            Text(s).font(.system(size: 14)).foregroundStyle(.white.opacity(0.45))
        }.padding(.bottom, 34)
    }

    private func sezioneTitolo(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.white.opacity(0.4)).padding(.top, 24).padding(.bottom, 4)
    }


    // Le impostazioni come frasi, con la voce di Tabby (Daniele, 9/11/2026: più semplice e originale).
    // La parola chiara è la scelta: un clic e compaiono le altre.
    @ViewBuilder private var impostazioni: some View {
        titolo("Impostazioni", "Clicca le parole chiare per cambiarle.")
        let pos = ["top": "in alto", "right": "a destra", "left": "a sinistra", "bottom": "in basso"]
        Frase("Tabby sta", ["in alto", "a destra", "a sinistra", "in basso"], pos[stato.posizione] ?? "in alto", ".") { s in
            if let k = pos.first(where: { $0.value == s })?.key { c.cambiaPosizione(k) }
        }
        Frase("Tabby", ["resta sempre in vista", "si nasconde"], c.nascondiTabby ? "si nasconde" : "resta sempre in vista",
              c.nascondiTabby ? ": compare col mouse sul bordo." : ".") { c.cambiaNascondi($0 == "si nasconde"); f.sezione = sezione }
        if Sistema.notch != nil {
            let n = Impostazioni.shared.valore("notchBand") as? String ?? "auto"
            Frase("Accanto al notch, Tabby", ["sale da sola", "sale sempre", "non sale"], n == "on" ? "sale sempre" : n == "off" ? "non sale" : "sale da sola",
                  n == "auto" ? " se la barra dei menu si nasconde." : ".") { s in
                Impostazioni.shared.imposta("notchBand", s == "sale sempre" ? "on" : s == "non sale" ? "off" : "auto")
                c.cambiaPosizione(stato.posizione); c.aggiornaNascondi(); f.sezione = sezione
            }
        }
        Frase("Quando accendi il Mac, Tabby", ["si apre", "resta chiusa"], SMAppService.mainApp.status == .enabled ? "si apre" : "resta chiusa", ".") {
            c.accensione($0 == "si apre"); f.sezione = sezione
        }
        Frase("Quando scegli una scheda,", ["nascondo", "lascio in vista"], vero("oneAtATime", true) ? "nascondo" : "lascio in vista", "le altre app.") {
            imposta("oneAtATime", $0 == "nascondo")
        }
        Frase("Le finestre", ["prendono", "non prendono"], vero("fit", true) ? "prendono" : "non prendono", "tutto lo spazio accanto a me.") {
            imposta("fit", $0 == "prendono")
        }
        Frase("Le app aperte senza finestre", ["si vedono", "non si vedono"], vero("showWindowless", false) ? "si vedono" : "non si vedono", "tra le schede.") {
            imposta("showWindowless", $0 == "si vedono")
        }
        Frase("Fuori dalla sua vista, una cartella attiva è", ["una scheda sola", "tante schede"], vero("folderView", true) ? "una scheda sola" : "tante schede", ".") {
            imposta("folderView", $0 == "una scheda sola")
        }
        Frase("La barra dei menu del Mac", ["si nasconde", "resta in vista"], c.barraMenuNascosta ? "si nasconde" : "resta in vista", ".") { s in
            c.nascondiBarraMenu(s == "si nasconde"); f.sezione = sezione
        }
        Frase("Il Dock", ["si nasconde", "resta in vista"], c.dockNascosto ? "si nasconde" : "resta in vista", ".") { s in
            c.nascondiDock(s == "si nasconde"); f.sezione = sezione
        }
        Spazio()
        Azione("I tuoi Lampi", c.lampi.lampi.map { "\($0.nome) ⌃⌥\($0.tasto.uppercased())" }.joined(separator: " · "), "personalizza") {
            c.finestraTabby.chiudi(tornando: false); c.apriFoglioLampi()
        }
        ForEach(stato.cartelle, id: \.id) { x in
            Azione("La cartella \(x.nome)", x.voci.map(\.nome).joined(separator: " · "), "modifica") {
                c.finestraTabby.chiudi(tornando: false); c.apriFoglioCartella(x.id)
            }
        }
        Azione("Una cartella nuova", "Scegli le schede, poi il nome", "crea") { c.finestraTabby.chiudi(tornando: false); c.apriFoglioCartella() }
        Azione("Il Memo", "Documenti › Tabby Memo.txt", "mostra") { NSWorkspace.shared.activateFileViewerSelecting([Memo.file]) }
        Spazio()
        Azione("Una pausa", "Resta solo la sfera; un clic e riparto", "metti in pausa") { c.finestraTabby.chiudi(); c.pausa(true) }
        Azione("Tutte le app", "Le app di sistema restano", "chiudi", rosso: true) { c.finestraTabby.chiudi(tornando: false); c.chiudiTutteLeApp() }
        Azione("La guida del primo avvio", nil, "rivedi") { withAnimation { f.sezione = nil; f.fase = .guida(0) } }
        Azione("Tabby", nil, "esci") { NSApp.terminate(nil) }
    }

    private func vero(_ k: String, _ diSerie: Bool) -> Bool { c.imp.valore(k) as? Bool ?? diSerie }
    private func imposta(_ k: String, _ v: Bool) { c.imp.imposta(k, v); c.ricostruisci(); f.sezione = sezione }

    @ViewBuilder private var design: some View {
        titolo("Design", "Poche scelte, tutte curate: SF Pro e i simboli di Apple restano sempre.")
        Frase("Tabby è", ["nativa", "notte"], aspetto.nativo ? "nativa" : "notte", aspetto.nativo ? ", come macOS." : ".") { aspetto.scegli(nativo: $0 == "nativa") }
        if !aspetto.nativo {
            Frase("Il tema è", Aspetto.temi.map { $0.lowercased() }, aspetto.tema.lowercased(), ".") { t in
                aspetto.scegli(tema: Aspetto.temi.first { $0.lowercased() == t })
            }
        }
        Frase("Le animazioni", ["seguono il Mac"], "seguono il Mac", ": con «Riduci movimento» niente rimbalzi.") { _ in }
    }

    @ViewBuilder private var documentazione: some View {
        titolo("Documentazione", "Tutte le scorciatoie di Tabby. Partono tutte da ⌃ ⌥ (control e option).")
        gruppo("Schede", [("⌃ ⌥ 1…9", "Vai alla scheda 1–9", nil), ("⌃ ⌥ ← →", "Scheda prima e dopo", "↑ ↓ con Tabby di lato"),
                          ("⌃ ⌥ Tab", "Torna alla scheda di prima", nil), ("⌃ ⌥ W", "Chiudi la finestra", "L'app resta aperta"),
                          ("⌃ ⌥ 0", "Scrivania (il musetto del gatto)", "Ripremuto: torna all'ultima scheda")])
        gruppo("Cerca", [("⌃ ⌥ Spazio", "La barra che cerca tutto", "Schede, testo nelle finestre, cartelle, Lampi, azioni, impostazioni")])
        gruppo("Vista divisa", [("⌃ ⌥ S", "Scambia le zone", nil), ("↩", "Fatto, mentre dividi", nil), ("esc", "Annulla, mentre dividi", nil)])
        gruppo("Lampi", c.lampi.lampi.map { ("⌃ ⌥ \($0.tasto.uppercased())", $0.nome, nil) } + [("esc", "Chiudi il Lampo in primo piano", nil)])
        gruppo("Cartelle", stato.cartelle.prefix(9).enumerated().map { ("⌃ ⌥ ⇧ \($0.offset + 1)", $0.element.nome, nil) })
        gruppo("Tabby", [("⌃ ⌥ /", "Questa pagina", nil)])
    }

    @ViewBuilder private func gruppo(_ t: String, _ righe: [(String, String, String?)]) -> some View {
        sezioneTitolo(t)
        ForEach(righe, id: \.0) { k, n, s in
            Riga(titolo: n, sotto: s) { Text(k).font(.system(size: 13)).tracking(1.5) }
        }
    }

    private func presto(_ simbolo: String, _ t: String, _ s: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: simbolo).font(.system(size: 32)).foregroundStyle(.white.opacity(0.35))
            Text(t).font(.system(size: 22, weight: .semibold))
            Text(s).font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 140)
    }
}

// MARK: - La guida del primo avvio (richieste vere a macOS, una alla volta)

private struct Guida: View {
    let c: Controllore
    @Bindable var f: StatoFinestra
    let passo: Int
    @State private var inAttesa = false
    private let passi = 6

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch passo {
                case 0: benvenuto
                case 1: accessibilità
                case 2: browser
                case 3: posizione
                case 4: barraEDock
                default: accensione
                }
            }
            .frame(width: 440).multilineTextAlignment(.center)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
            .id(passo)
            HStack(spacing: 6) { ForEach(0..<passi, id: \.self) { i in Circle().fill(.white.opacity(i == passo ? 1 : 0.18)).frame(width: 6, height: 6) } }
                .padding(.top, 26)
        }
    }

    private func avanti() {
        withAnimation(Tema.molla) {
            if passo + 1 >= passi { Impostazioni.shared.imposta("primoAvvioFatto", true); f.fase = .casa } else { f.fase = .guida(passo + 1) }
        }
    }

    private func intestazione(_ simbolo: String?, _ t: String, _ testo: String) -> some View {
        VStack(spacing: 10) {
            if let simbolo { Image(systemName: simbolo).font(.system(size: 26)) }
            else if let u = Bundle.main.url(forResource: "gatto-sfera", withExtension: "png"), let i = NSImage(contentsOf: u) {
                Image(nsImage: i).resizable().frame(width: 52, height: 52).clipShape(Circle())
            }
            Text(t).font(.system(size: 22, weight: .semibold)).padding(.top, 4)
            Text(testo).font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func azione(_ prima: String, _ fPrima: @escaping () -> Void) -> some View {
        Button(prima + " →", action: fPrima).buttonStyle(.plain).font(.system(size: 14, weight: .medium)).padding(.top, 22)
    }

    private func azioni(_ seconda: String, _ fSeconda: @escaping () -> Void, _ prima: String, _ fPrima: @escaping () -> Void) -> some View {
        HStack(spacing: 28) {
            Button(seconda, action: fSeconda).buttonStyle(.plain).font(.system(size: 14)).foregroundStyle(.white.opacity(0.45))
            Button(prima + " →", action: fPrima).buttonStyle(.plain).font(.system(size: 14, weight: .medium))
        }.padding(.top, 22)
    }

    private var benvenuto: some View {
        VStack(spacing: 0) {
            intestazione(nil, "Ciao, sono Tabby", "Ogni app diventa una scheda: ne vedi una alla volta e passi dall'una all'altra con un clic o con ⌃⌥ e un numero. Due minuti per prepararmi.")
            azione("Iniziamo", avanti)
        }
    }

    private var accessibilità: some View {
        VStack(spacing: 0) {
            intestazione("accessibility", "Un permesso: Accessibilità",
                         "Per vedere le tue finestre, spostarle e nasconderle, Tabby ha bisogno del permesso Accessibilità di macOS. Non legge cosa scrivi e non manda niente fuori dal Mac.")
            Text("Impostazioni di Sistema › Privacy e sicurezza › Accessibilità › Tabby").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)).padding(.top, 8)
            if f.permessoDato || Permessi.accessibilita {
                Text("✓ Fatto, grazie").font(.system(size: 13)).padding(.top, 18)
                azione("Avanti", avanti)
            } else {
                if inAttesa { HStack(spacing: 7) { ProgressView().controlSize(.small); Text("In attesa del permesso…") }.font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.55)).padding(.top, 18) }
                azione("Apri Impostazioni di Sistema") {
                    inAttesa = true
                    Permessi.chiediAccessibilita()
                    NSWorkspace.shared.open(Permessi.paginaAccessibilita)
                    c.attesaPermesso.aspetta { f.permessoDato = true }
                }
            }
        }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            intestazione("globe", "I tuoi browser",
                         "Per mostrare i siti come schede (Gmail, Notion…) Tabby chiede ai browser quali pagine sono aperte. La prima volta macOS te lo chiederà per ogni browser: rispondi OK. DuckDuckGo non serve: Tabby guarda solo l'indirizzo.")
            azione("Ho capito", avanti)
        }
    }

    private var posizione: some View {
        VStack(spacing: 0) {
            intestazione("macwindow", "Dove tieni Tabby?", "Si cambia quando vuoi, dalle impostazioni.")
            let pos = ["top": "In alto", "right": "A destra", "left": "A sinistra", "bottom": "In basso"]
            Parole(scelte: ["In alto", "A destra", "A sinistra", "In basso"], scelta: pos[c.stato.posizione] ?? "In alto") { s in
                if let k = pos.first(where: { $0.value == s })?.key { c.cambiaPosizione(k) }
            }.padding(.top, 18)
            Text("E come la vuoi?").font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.62)).padding(.top, 18)
            Parole(scelte: ["Nativo", "Notte · Tabby"], scelta: Aspetto.shared.nativo ? "Nativo" : "Notte · Tabby") { s in
                Aspetto.shared.scegli(nativo: s == "Nativo", tema: s == "Nativo" ? nil : "Tabby")
            }.padding(.top, 8)
            azione("Avanti", avanti)
        }
    }

    private var barraEDock: some View {
        VStack(spacing: 0) {
            intestazione("menubar.rectangle", "Barra dei menu e Dock",
                         "Con Tabby non servono sempre in vista. Ti consiglio di nasconderli: ricompaiono portando il mouse sul bordo. Tabby cambia solo queste due impostazioni del Mac, e solo se dici sì.")
            azioni("Lascia così", avanti, "Nascondili") { c.nascondiBarraMenu(true); c.nascondiDock(true); avanti() }
        }
    }

    private var accensione: some View {
        VStack(spacing: 0) {
            intestazione("power", "Tabby all'accensione", "Vuoi che Tabby si apra da sola quando accendi il Mac? macOS ti avviserà che è tra gli elementi di login.")
            azioni("No", avanti, "Sì") { c.accensione(true); avanti() }
        }
    }
}

// MARK: - Le impostazioni del Mac (solo col tuo sì)

extension Controllore {
    var dockNascosto: Bool { UserDefaults(suiteName: "com.apple.dock")?.bool(forKey: "autohide") ?? false }
    var barraMenuNascosta: Bool { UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["_HIHideMenuBar"] as? Bool ?? false }

    func nascondiDock(_ sì: Bool) {
        esegui("/usr/bin/osascript", ["-e", "tell application \"System Events\" to set autohide of dock preferences to \(sì)"])
    }

    func nascondiBarraMenu(_ sì: Bool) {
        esegui("/usr/bin/osascript", ["-e", "tell application \"System Events\" to set autohide menu bar of dock preferences to \(sì)"])
    }

    func accensione(_ sì: Bool) {
        do { if sì { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { diario("apertura all'accensione: \(error.localizedDescription)") }
    }

    /// ⚙︎ → impostazioni, ⌃⌥/ → scorciatoie: la finestra di Tabby sulla sezione.
    func apriFinestraTabby(sezione: String?) { finestraTabby.mostra(sezione: sezione) }
}
