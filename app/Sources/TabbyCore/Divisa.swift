import Foundation

/// La vista divisa (SPECIFICA 7; nella Tabby di Hammerspoon si chiamava «gruppo»): lo spazio
/// delle app diviso in 2–4 zone, una scheda per zona.

/// Gli schemi (D-1): zone in frazioni dello spazio delle app (x, y, larghezza, altezza; y dall'alto).
public struct Schema: Sendable, Equatable {
    public let id: String
    public let nome: String
    public let zone: [CGRect]
}

public let schemi: [Schema] = [
    .init(id: "2-50", nome: "Due app · metà e metà", zone: [CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)]),
    .init(id: "2-70", nome: "Due app · 70 / 30", zone: [CGRect(x: 0, y: 0, width: 0.7, height: 1), CGRect(x: 0.7, y: 0, width: 0.3, height: 1)]),
    .init(id: "3", nome: "Tre app · una sopra, due sotto", zone: [CGRect(x: 0, y: 0, width: 1, height: 0.5), CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)]),
    .init(id: "4", nome: "Quattro app · un quarto ciascuna", zone: [CGRect(x: 0, y: 0, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5), CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)]),
]

public func schema(_ id: String) -> Schema { schemi.first { $0.id == id } ?? schemi[0] }

/// Lo schema «di serie» per numero di app: 2 → metà e metà, 3 → tre, 4 → quarti.
public func schemaPer(_ n: Int) -> String { n >= 4 ? "4" : n == 3 ? "3" : "2-50" }

/// Le zone in punti dentro lo spazio delle app (coordinate dall'alto), con 3 punti di spazio
/// per lato tra le finestre (ma non contro i bordi).
public func zoneIn(_ s: Schema, spazio r: CGRect, spazio gap: Double = 3) -> [CGRect] {
    s.zone.map { z in
        var x = r.minX + z.minX * r.width, y = r.minY + z.minY * r.height
        var w = z.width * r.width, h = z.height * r.height
        if z.minX > 0 { x += gap; w -= gap }
        if z.maxX < 0.999 { w -= gap }
        if z.minY > 0 { y += gap; h -= gap }
        if z.maxY < 0.999 { h -= gap }
        return CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: h.rounded())
    }
}

/// Una vista divisa salvata.
public struct VistaDivisa: Equatable, Sendable {
    public var id: Int
    public var schema: String
    public var membri: [String]          // chiavi delle schede, nell'ordine delle zone
    public var attenzione: String?       // la scheda usata per ultima nella vista
    public var chiave: String { "g:\(id)" }
    public init(id: Int, schema: String, membri: [String], attenzione: String? = nil) {
        self.id = id; self.schema = schema; self.membri = membri; self.attenzione = attenzione
    }

    /// Come si salva (stesso formato della Tabby di Hammerspoon: id, layout, members, focus).
    public var dizionario: [String: Any] {
        var d: [String: Any] = ["id": id, "layout": schema, "members": membri]
        if let a = attenzione { d["focus"] = a }
        return d
    }
    public init?(_ d: [String: Any]) {
        guard let id = d["id"] as? Int, let m = d["members"] as? [String] else { return nil }
        self.init(id: id, schema: d["layout"] as? String ?? schemaPer(m.count), membri: m, attenzione: d["focus"] as? String)
    }
}

/// Crea una vista dalle zone riempite (D-2): con meno app delle zone lo schema si adatta al
/// numero; con una sola app non nasce nessuna vista.
public func creaVista(id: Int, schema s: String, zone: [String?]) -> VistaDivisa? {
    let membri = zone.compactMap { $0 }
    guard membri.count >= 2 else { return nil }
    let n = schema(s).zone.count
    return VistaDivisa(id: id, schema: membri.count < n ? schemaPer(membri.count) : s, membri: membri, attenzione: membri[0])
}

/// Scambia (D-5): le app ruotano di una zona (con due si scambiano).
public func ruota(_ v: VistaDivisa) -> VistaDivisa {
    var x = v
    guard x.membri.count >= 2 else { return x }
    x.membri.insert(x.membri.removeLast(), at: 0)
    return x
}

/// Le viste di fronte alle schede di adesso (D-7): un'app chiusa esce dalla vista; con meno di
/// 2 app la vista si scioglie; altrimenti prende lo schema adatto al numero rimasto.
public func aggiornaViste(_ viste: [VistaDivisa], presenti: Set<String>) -> [VistaDivisa] {
    viste.compactMap { v in
        var x = v
        x.membri = v.membri.filter { presenti.contains($0) }
        guard x.membri.count >= 2 else { return nil }
        if x.membri.count != v.membri.count { x.schema = schemaPer(x.membri.count) }
        if let a = x.attenzione, !x.membri.contains(a) { x.attenzione = x.membri[0] }
        return x
    }
}

/// Le schede da mostrare (D-3): i membri di una vista spariscono e al posto del primo (nell'ordine
/// delle schede) compare la scheda della vista, «Gmail + Slack», con la somma delle notifiche (N-3).
public func conViste(_ schede: [Scheda], _ viste: [VistaDivisa]) -> [Scheda] {
    var di: [String: VistaDivisa] = [:]
    for v in viste { for m in v.membri { di[m] = v } }
    var fatte = Set<Int>(), out: [Scheda] = []
    for s in schede {
        guard let v = di[s.chiave] else { out.append(s); continue }
        guard fatte.insert(v.id).inserted else { continue }
        let membri = v.membri.compactMap { m in schede.first { $0.chiave == m } }
        var somma = 0, pallino = false
        for m in membri { if let n = m.notifica { if let x = Int(n) { somma += x } else { pallino = true } } }
        out.append(Scheda(chiave: v.chiave, bid: membri.first?.bid ?? s.bid, nome: membri.map(\.nome).joined(separator: " + "),
                          pid: membri.first?.pid ?? s.pid, notifica: somma > 0 ? String(somma) : pallino ? "•" : nil))
    }
    return out
}
