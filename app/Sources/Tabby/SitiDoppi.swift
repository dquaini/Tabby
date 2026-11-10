import AppKit
import TabbyCore

/// I siti doppi (SPECIFICA B-9): una finestra di browser con un solo sito che compare quando lo
/// stesso sito è già aperto in una finestra più vecchia (da solo o fra le sue schede, anche di
/// un altro browser) → un avviso
/// con Lascia · Vai a quella · Chiudi questa. Una volta per finestra; solo per finestre nuove da
/// meno di 2 minuti; quello che c'è nei primi 15 s dopo l'avvio di Tabby c'era già.
extension Controllore {
    func controllaSitiDoppi(_ schede: [Scheda]) {
        let ora = Date()
        let vive = Set(schede.compactMap(\.finestra))
        for f in vive where vistaLaPrimaVolta[f] == nil { vistaLaPrimaVolta[f] = ora }
        vistaLaPrimaVolta = vistaLaPrimaVolta.filter { vive.contains($0.key) }
        doppiAvvisati.formIntersection(vive)
        guard ora.timeIntervalSince(avviataIl) > 15 else { return }
        for s in schede {
            guard let sito = s.sito, let f = s.finestra, !doppiAvvisati.contains(f), sitiScelti[f] == nil,
                  let quando = vistaLaPrimaVolta[f], ora.timeIntervalSince(quando) < 120, quando > avviataIl.addingTimeInterval(15)
            else { continue }
            let piùVecchie = schede.filter { t in t.finestra.flatMap { vistaLaPrimaVolta[$0] }.map { $0 < quando } ?? false }
            guard let altra = dovèGiàAperto(sito, tranne: f, in: piùVecchie) else { continue }
            doppiAvvisati.insert(f)
            let questa = s
            avvisi.mostra(Avviso(icona: stato.loghi[sito], titolo: "\(s.nome) è già aperto in un'altra finestra",
                                 scelte: [.init(titolo: "Lascia") {},
                                          .init(titolo: "Vai a quella") { [weak self] in self?.vai(altra) },
                                          .init(titolo: "Chiudi questa", principale: true) { [weak self] in
                                              self?.chiudiFinestra(questa); self?.vai(altra)
                                          }]))
            diario("sito doppio: \(sito)")
        }
    }
}
