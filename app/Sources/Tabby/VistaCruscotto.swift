import SwiftUI
import TabbyCore

/// Il disegno del cruscotto, nello stile dei fogli di Tabby: nero, testo bianco, le cose
/// importanti grandi, i comandi come parole (bozza approvata da Daniele il 12/11/2026). Le
/// tessere sono **al centro**, come un quadrante (Daniele, 12/11/2026); «modifica» resta a sinistra.
struct VistaCruscotto: View {
    let cc: Cruscotto
    @Bindable var s: StatoCruscotto
    @Bindable var stato: StatoBarra

    var body: some View {
        VStack(alignment: s.modifica ? .leading : .center, spacing: 20) {
            if s.modifica { modifica } else {
                if s.tessere.isEmpty { Text("Nessuna tessera: aggiungine con «modifica».").foregroundStyle(.white.opacity(0.5)) }
                ForEach(s.tessere, id: \.self) { tessera($0) }
                parola("modifica →") { s.modifica = true; cc.prendiLaTastiera() }
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .multilineTextAlignment(s.modifica ? .leading : .center)
        .padding(20)
        .frame(width: 340, alignment: s.modifica ? .leading : .center)
        .background(Color(white: 0.04).opacity(0.97), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: s.modifica) { DispatchQueue.main.async { cc.posiziona() } }
    }

    private let grigio = Color.white.opacity(0.5)

    private func parola(_ t: String, forte: Bool = false, _ fai: @escaping () -> Void) -> some View {
        Button(action: fai) { Text(t).font(.system(size: 13, weight: forte ? .semibold : .regular)).foregroundStyle(.white.opacity(forte ? 1 : 0.8)) }
            .buttonStyle(.plain)
    }

    // MARK: - Le tessere

    @ViewBuilder private func tessera(_ t: Tessera) -> some View {
        switch t {
        case .ora: ora
        case .batteria: batteria
        case .meteo: meteo
        case .musica: musica
        case .borsa: borsa
        case .mac: mac
        case .uso: uso
        }
    }

    private var ora: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            VStack(alignment: .center, spacing: 2) {
                Text(ctx.date.formatted(.dateTime.hour().minute())).font(.system(size: 30, weight: .light)).monospacedDigit()
                Text(ctx.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT")))).foregroundStyle(grigio)
            }
        }
    }

    @ViewBuilder private var batteria: some View {
        let b = stato.batteria
        VStack(alignment: .center, spacing: 2) {
            if b.presente {
                Text("\(b.livello)%").font(.system(size: 26, weight: .light)).monospacedDigit()
                    .foregroundStyle(b.livello < 20 && !b.inCarica ? Tema.rossa : .white)
                Text(b.inCarica ? "in carica" : "a batteria").foregroundStyle(grigio)
            } else {
                Text("Alla corrente").font(.system(size: 17)); Text("questo Mac non ha batteria").foregroundStyle(grigio)
            }
        }
    }

    @ViewBuilder private var meteo: some View {
        if s.città == nil {
            VStack(alignment: .center, spacing: 6) {
                Text("Meteo").font(.system(size: 17))
                CampoParola(segnaposto: "La tua città, poi ↵", iniziale: "") { cc.cambiaCittà($0) }.frame(width: 180)
                if let e = s.meteoErrore { Text(e).foregroundStyle(Tema.rossa) }
            }
        } else if let m = s.meteo, let città = s.città {
            VStack(alignment: .center, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: simboloMeteo(m.codice)).font(.system(size: 17))
                    Text("\(città) \(Int(m.temperatura.rounded()))°").font(.system(size: 20, weight: .light))
                    Text(descrizioneMeteo(m.codice)).foregroundStyle(grigio)
                }
                let giorni = Array(m.giorni.dropFirst(s.giornoDa).prefix(3))
                HStack(spacing: 12) {
                    if s.giornoDa > 1 { parola("←") { s.giornoDa = max(1, s.giornoDa - 3) } }
                    ForEach(giorni, id: \.data) { g in
                        VStack(spacing: 2) {
                            Text(g.data.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "it_IT")))).foregroundStyle(grigio)
                            Image(systemName: simboloMeteo(g.codice)).font(.system(size: 12))
                            Text("\(Int(g.massima.rounded()))° \(Int(g.minima.rounded()))°").monospacedDigit()
                        }
                    }
                    if s.giornoDa + 3 < m.giorni.count { parola("→") { s.giornoDa += 3 } }
                }
            }
        } else {
            Text(s.meteoErrore ?? "Meteo di \(s.città ?? "")…").foregroundStyle(grigio)
        }
    }

    @ViewBuilder private var musica: some View {
        if let m = s.musica {
            VStack(alignment: .center, spacing: 4) {
                Text(m.titolo).font(.system(size: 15)).lineLimit(1)
                Text(m.artista).foregroundStyle(grigio).lineLimit(1)
                HStack(spacing: 18) {
                    parola("← indietro") { cc.musica(.indietro) }
                    parola(m.suona ? "pausa" : "suona", forte: true) { cc.musica(.pausa) }
                    parola("avanti →") { cc.musica(.avanti) }
                }.padding(.top, 4)
            }
        } else {
            Text("Musica: nessuna app installata (Spotify, Musica, Tidal)").foregroundStyle(grigio)
        }
    }

    @ViewBuilder private var borsa: some View {
        if s.titoli.isEmpty {
            Text("Borsa: aggiungi i titoli con «modifica»").foregroundStyle(grigio)
        } else if s.borsaErrore {
            Text("Borsa non disponibile").foregroundStyle(grigio)
        } else {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                ForEach(s.quotazioni, id: \.simbolo) { q in
                    GridRow {
                        Text(q.simbolo)
                        Text(q.prezzo.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "it_IT"))) + " " + q.valuta)
                            .foregroundStyle(grigio).monospacedDigit()
                        Text((q.variazione >= 0 ? "+" : "−") + abs(q.variazione).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "it_IT"))) + "%")
                            .foregroundStyle(q.variazione >= 0 ? Tema.verde : Tema.rossa).monospacedDigit()
                    }
                }
            }
        }
    }

    private var mac: some View {
        let p = s.processore.map { "\(Int($0.rounded()))%" } ?? "…"
        let m = s.memoria.map { String(format: "%.1f/%.0f GB", $0.usata, $0.totale).replacingOccurrences(of: ".", with: ",") } ?? "…"
        let g = s.gpu.map { Text(" \(Text("· GPU").foregroundStyle(grigio)) \($0)%") } ?? Text("")
        return Text("\(Text("Processore").foregroundStyle(grigio)) \(p) \(Text("· Memoria").foregroundStyle(grigio)) \(m)\(g)").monospacedDigit()
    }

    @ViewBuilder private var uso: some View {
        let primi = s.uso.prefix(3)
        if primi.isEmpty { Text("Tempo d'uso: niente ancora oggi").foregroundStyle(grigio) }
        else {
            primi.enumerated().reduce(Text("Oggi:").foregroundStyle(grigio)) { t, x in
                Text("\(t)\(Text((x.offset > 0 ? " ·" : "") + " " + x.element.nome).foregroundStyle(grigio)) \(durata(x.element.secondi))")
            }
        }
    }

    // MARK: - Componibile: togli, riordina, aggiungi

    private var modifica: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRASCINA PER RIORDINARE").font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(grigio)
            List {
                ForEach(s.tessere, id: \.self) { t in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        Text(t.nome)
                        extra(t)
                        Spacer()
                        Button("togli") { cc.salvaTessere(s.tessere.filter { $0 != t }) }.buttonStyle(.plain).foregroundStyle(Tema.rossa)
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                .onMove { var x = s.tessere; x.move(fromOffsets: $0, toOffset: $1); cc.salvaTessere(x) }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            .frame(height: CGFloat(s.tessere.count) * 30 + 4)
            let mancanti = Tessera.allCases.filter { !s.tessere.contains($0) }
            if !mancanti.isEmpty {
                Text("DA AGGIUNGERE").font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(grigio).padding(.top, 6)
                ForEach(mancanti, id: \.self) { t in parola("+ " + t.nome) { cc.salvaTessere(s.tessere + [t]) } }
            }
            HStack { Spacer(); parola("Fatto →", forte: true) { s.modifica = false } }.padding(.top, 6)
        }
    }

    /// La parola che si cambia, accanto al nome della tessera.
    @ViewBuilder private func extra(_ t: Tessera) -> some View {
        switch t {
        case .meteo: CampoParola(segnaposto: "città", iniziale: s.città ?? "") { cc.cambiaCittà($0) }.frame(width: 110)
        case .musica:
            let app = cc.musicaInstallate
            if app.count > 1 {
                SwiftUI.Menu(app.first { $0.bid == cc.musicaScelta }?.nome ?? "scegli") {
                    ForEach(app, id: \.bid) { a in Button(a.nome) { cc.scegliMusica(a.bid) } }
                }.menuStyle(.borderlessButton).fixedSize()
            } else if let a = app.first { Text(a.nome).foregroundStyle(grigio) }
        case .borsa: CampoParola(segnaposto: "STZ, DSY.PA", iniziale: s.titoli.joined(separator: ", ")) { cc.cambiaTitoli($0) }.frame(width: 120)
        default: EmptyView()
        }
    }
}

/// Una parola da cambiare scrivendo (sottolineata): ↵ salva.
struct CampoParola: View {
    let segnaposto: String
    let iniziale: String
    let salva: (String) -> Void
    @State private var testo = ""
    var body: some View {
        TextField(segnaposto, text: $testo)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.leading)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.35)).frame(height: 1).offset(y: 2) }
            .onSubmit { salva(testo) }
            .onAppear { testo = iniziale }
    }
}
