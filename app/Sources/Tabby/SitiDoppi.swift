import AppKit
import TabbyCore

/// I siti doppi (SPECIFICA B-9): una finestra di browser con un solo sito che compare quando lo
/// stesso sito è già aperto da solo in un'altra finestra (anche di un altro browser) → un avviso
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
        for s in schede where s.chiave.hasPrefix("win:") {
            guard let sito = s.sito, let f = s.finestra, !doppiAvvisati.contains(f),
                  let quando = vistaLaPrimaVolta[f], ora.timeIntervalSince(quando) < 120, quando > avviataIl.addingTimeInterval(15),
                  let altra = schede.first(where: { $0.chiave == "site:" + sito }) else { continue }
            doppiAvvisati.insert(f)
            let questa = s
            avvisi.mostra(Avviso(icona: stato.loghi[sito], titolo: "\(altra.nome) è già aperto in un'altra finestra",
                                 scelte: [.init(titolo: "Lascia") {},
                                          .init(titolo: "Vai a quella") { [weak self] in self?.vai(altra) },
                                          .init(titolo: "Chiudi questa", principale: true) { [weak self] in
                                              self?.chiudiFinestra(questa); self?.vai(altra)
                                          }]))
            diario("sito doppio: \(sito)")
        }
    }
}
