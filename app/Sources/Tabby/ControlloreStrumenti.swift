import AppKit
import Carbon.HIToolbox
import SwiftUI
import TabbyCore

/// Lampi, scorciatoie che cambiano, «Chiudi tutte le app» e il ritorno alla scheda.
extension Controllore {
    /// Le scorciatoie dei Lampi: si rimettono a ogni cambio, senza riavviare Tabby.
    func registraLampi() {
        tasti.togliGruppo("lampi")
        for l in lampi.lampi {
            guard let k = Tasti.codice(l.tasto) else { continue }
            tasti.gruppo("lampi", tasto: k) { [weak self] in self?.lampi.premi(l) }
        }
    }

    /// Esc su un Lampo in primo piano lo chiude (Q-1): il tasto si ascolta solo in quel momento.
    func ascoltaEscLampo(_ app: NSRunningApplication?) {
        tasti.togliGruppo("esc")
        guard let b = app?.bundleIdentifier, lampi.èVeloce(b) else { return }
        tasti.gruppo("esc", tasto: kVK_Escape, modificatori: false) { [weak self] in self?.lampi.chiudi(b) }
    }

    /// Torna all'ultima scheda usata (dopo un Lampo chiuso, un'app fuori dalla Concentrazione).
    func tornaAllaScheda() {
        let vis = stato.schede
        if let k = storiaUso.first(where: { k in vis.contains { $0.chiave == k } }), let s = vis.first(where: { $0.chiave == k }) { vai(s, daTe: false) }
        else if let s = vis.first { vai(s, daTe: false) }
    }

    /// Le schede usate, dalla più recente (per la ricerca e per tornare indietro).
    var storiaUso: [String] { var v: [String] = []; for x in storia.reversed() where !v.contains(x.chiave) { v.append(x.chiave) }; return v }

    /// Le app che «Chiudi le app» può chiudere: non il Finder, non le app di sistema di Apple
    /// (tranne quelle da lavoro, che si usano come le altre).
    private func chiudibile(_ b: String) -> Bool {
        b != "com.apple.finder" && (!b.hasPrefix("com.apple.") || ["com.apple.Safari", "com.apple.Preview", "com.apple.TextEdit", "com.apple.Notes",
                                                                  "com.apple.mail", "com.apple.iCal", "com.apple.Terminal", "com.apple.calculator", "com.apple.systempreferences"].contains(b))
    }

    /// ⚙︎ → Chiudi le app → Tutte (C-5): le app con documenti non salvati chiedono loro; del Finder
    /// si chiudono solo le finestre; le app di sistema di Apple restano.
    func chiudiTutteLeApp() {
        for a in Sistema.appVere() {
            guard let b = a.bundleIdentifier else { continue }
            if b == "com.apple.finder" { for w in Sistema.finestre(a.processIdentifier) { Sistema.chiudi(w) }; continue }
            if chiudibile(b) { a.terminate() }
        }
        diario("chiudi tutte le app")
    }

    /// ⚙︎ → Chiudi le app → Solo quelle senza finestre (Daniele, 12/11/2026): le app aperte che non
    /// vedi in Tabby (consumano senza che tu lo sappia). Due controlli, per non chiudere mai un'app
    /// che stai usando: nessuna scheda in Tabby **e** nessuna finestra per macOS, nemmeno nascosta.
    func chiudiAppSenzaFinestre() {
        let conSchede = Set(tutte.map(\.bid))
        let conFinestre = Set(((CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? [])
            .filter { ($0[kCGWindowLayer as String] as? Int) == 0 && (($0[kCGWindowBounds as String] as? [String: CGFloat])?["Width"] ?? 0) > 100 }
            .compactMap { $0[kCGWindowOwnerPID as String] as? pid_t })
        var chiuse: [String] = []
        for a in Sistema.appVere() {
            guard let b = a.bundleIdentifier, chiudibile(b), !conSchede.contains(b), !conFinestre.contains(a.processIdentifier),
                  Sistema.finestre(a.processIdentifier).isEmpty else { continue }
            a.terminate(); chiuse.append(a.localizedName ?? b)
        }
        diario("chiuse le app senza finestre: " + (chiuse.isEmpty ? "nessuna" : chiuse.joined(separator: ", ")))
        avvisi.mostra(Avviso(simbolo: "eye.slash", titolo: chiuse.isEmpty ? "Nessuna app senza finestre" : "Chiuse \(chiuse.count) app senza finestre",
                             testo: chiuse.isEmpty ? nil : chiuse.joined(separator: ", ")))
    }

    // MARK: - Personalizza i Lampi (foglio, DESIGN 3.4.3)

    func apriFoglioLampi() {
        stato.lampiInModifica = lampi.lampi
        palco.apri(FoglioLampi(c: self, stato: stato), sopra: pannello, posizione: stato.posizione) { [weak self] in
            self?.palco.chiudiFoglio()
        }
    }

    func salvaFoglioLampi() {
        lampi.lampi = stato.lampiInModifica
        lampi.salvaLampi()
        palco.chiudiFoglio()
    }

    /// Le lettere già prese (Lampi e Tabby).
    func lettereUsate(tranne id: String? = nil) -> Set<String> {
        Set(stato.lampiInModifica.filter { $0.id != id }.map(\.tasto)).union(lettereDiTabby)
    }

    func aggiungiLampo(_ app: URL) {
        guard let b = Bundle(url: app)?.bundleIdentifier, !stato.lampiInModifica.contains(where: { $0.bid == b }) else { return }
        let nome = FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
        guard let k = letteraLibera(per: nome, usate: lettereUsate()) else { return }
        withAnimationMolla { stato.lampiInModifica.append(Lampo(bid: b, nome: nome, tasto: k)) }
    }
}

struct FoglioLampi: View {
    let c: Controllore
    @Bindable var stato: StatoBarra
    @State private var inAscolto: String?
    @State private var giàUsata: String?

    var body: some View {
        Foglio(simbolo: "sparkles", titolo: "Personalizza i Lampi",
               spiegazione: "Trascina per riordinare. Clicca la scorciatoia e premi una lettera.",
               annulla: { c.palco.chiudiFoglio() }, conferma: { c.salvaFoglioLampi() }) {
            VStack(alignment: .leading, spacing: 0) {
                List {
                    ForEach(stato.lampiInModifica) { l in riga(l).listRowBackground(Color.clear).listRowSeparator(.hidden) }
                        .onMove { stato.lampiInModifica.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .frame(height: CGFloat(min(8, stato.lampiInModifica.count)) * 28 + 6)
                if let g = giàUsata { Text(g).font(.system(size: 11.5)).foregroundStyle(.orange).padding(.horizontal, 14) }
                HStack(spacing: 8) {
                    SwiftUI.Menu("Aggiungi un Lampo") {
                        ForEach(NSWorkspace.shared.runningApplications.filter { a in
                            a.activationPolicy == .regular && a.bundleIdentifier != "com.apple.finder" && browserNoti[a.bundleIdentifier ?? ""] == nil
                                && !stato.lampiInModifica.contains { $0.bid == a.bundleIdentifier }
                        }, id: \.processIdentifier) { a in
                            Button(a.localizedName ?? "") { if let u = a.bundleURL { c.aggiungiLampo(u) } }
                        }
                        Divider()
                        Button("Altra app…") {
                            let p = NSOpenPanel(); p.directoryURL = URL(fileURLWithPath: "/Applications"); p.allowedContentTypes = [.application]
                            if p.runModal() == .OK, let u = p.url { c.aggiungiLampo(u) }
                        }
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    Spacer()
                    Button("Lampi di serie") { withAnimationMolla { stato.lampiInModifica = lampiDiSerie } }
                        .buttonStyle(.plain).foregroundStyle(.white.opacity(0.7))
                }
                .font(.system(size: 12.5)).padding(.horizontal, 14).padding(.top, 6)
            }
        }
        .onKeyPress(phases: .down) { k in
            guard let id = inAscolto else { return .ignored }
            let lettera = k.characters.lowercased()
            if k.key == .escape { inAscolto = nil; return .handled }
            guard lettera.count == 1, Tasti.codice(lettera) != nil else { return .handled }
            if c.lettereUsate(tranne: id).contains(lettera) { giàUsata = "⌃⌥\(lettera.uppercased()) è già usata: premi un'altra lettera"; return .handled }
            if let i = stato.lampiInModifica.firstIndex(where: { $0.id == id }) { stato.lampiInModifica[i].tasto = lettera }
            inAscolto = nil; giàUsata = nil
            return .handled
        }
    }

    private func riga(_ l: Lampo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
            Group {
                if l.memo { Image(systemName: "note.text").foregroundStyle(Tema.accento) }
                else if let b = l.bid, let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable()
                }
            }.frame(width: 18, height: 18)
            Text(l.nome).font(.system(size: 14)).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Button { inAscolto = l.id; giàUsata = nil } label: {
                if inAscolto == l.id {
                    Text("premi una lettera").font(.system(size: 11)).foregroundStyle(Tema.accento)
                        .padding(.horizontal, 6).frame(height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Tema.accento, lineWidth: 1))
                } else { Tastino(testo: "⌃ ⌥ \(l.tasto.uppercased())") }
            }.buttonStyle(.plain)
            Button { withAnimationMolla { stato.lampiInModifica.removeAll { $0.id == l.id } } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4))
            }.buttonStyle(.plain)
        }
        .frame(height: 22)
    }
}
