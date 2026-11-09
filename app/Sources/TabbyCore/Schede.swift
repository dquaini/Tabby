import Foundation

/// Una scheda della barra (SPECIFICA 1–2). Nella tappa 2 c'è una scheda per app; la chiave è
/// il bundle ID. Nelle tappe dopo arrivano `win:<id>`, `site:<dominio>`, `g:<n>`, `f:<n>`.
public struct Scheda: Equatable, Identifiable, Sendable {
    public var chiave: String
    public var bid: String
    public var nome: String
    public var pid: Int32
    public var id: String { chiave }

    public init(chiave: String, bid: String, nome: String, pid: Int32) {
        self.chiave = chiave; self.bid = bid; self.nome = nome; self.pid = pid
    }
}

/// L'ordine delle schede (S-7). `ordine` è l'elenco di chiavi ricordato (anche di schede che
/// oggi non ci sono). Le schede nuove si inseriscono così:
///  1. le **preferite** appena comparse vanno in cima, nell'ordine dell'elenco delle preferite;
///  2. una scheda nuova di un'app che ha già schede va subito dopo l'ultima di quell'app;
///  3. le altre in fondo.
/// Restituisce le schede in ordine e l'ordine aggiornato da salvare.
public func ordina(_ schede: [Scheda], ordine: [String], preferite: [String]) -> (schede: [Scheda], ordine: [String]) {
    var ord = ordine
    for s in schede where !ord.contains(s.chiave) {
        if let p = preferite.firstIndex(of: s.chiave) {
            // prima della prima chiave che non è una preferita venuta prima di questa
            let prima = Set(preferite[..<p])
            let i = ord.firstIndex { !prima.contains($0) } ?? ord.count
            ord.insert(s.chiave, at: i)
        } else if let ultima = ord.lastIndex(where: { k in schede.contains { $0.chiave == k && $0.bid == s.bid } }) {
            ord.insert(s.chiave, at: ultima + 1)
        } else {
            ord.append(s.chiave)
        }
    }
    // pulizia: le chiavi di finestre che non ci sono più non servono; troppe chiavi → via le vecchie invisibili
    ord.removeAll { k in k.hasPrefix("win:") && !schede.contains(where: { $0.chiave == k }) }
    if ord.count > 300 {
        let visibili = Set(schede.map(\.chiave))
        var togliere = ord.count - 300
        ord.removeAll { k in
            guard togliere > 0, !visibili.contains(k) else { return false }
            togliere -= 1; return true
        }
    }
    let posto = Dictionary(uniqueKeysWithValues: ord.enumerated().map { ($1, $0) })
    let ordinate = schede.sorted { (posto[$0.chiave] ?? .max) < (posto[$1.chiave] ?? .max) }
    return (ordinate, ord)
}

/// Il nome di una finestra quando un'app ne ha più di una (S-2): il titolo senza il nome
/// dell'app in fondo. «Relazione — TextEdit» → «Relazione».
public func nomeFinestra(titolo: String, app: String) -> String {
    let t = titolo.trimmingCharacters(in: .whitespaces)
    if t.isEmpty || t == app { return app }
    for sep in [" — ", " – ", " - ", " | "] where t.hasSuffix(sep + app) {
        let r = String(t.dropLast(sep.count + app.count)).trimmingCharacters(in: .whitespaces)
        return r.isEmpty ? app : r
    }
    return t
}
