import Foundation

/// Le cartelle (SPECIFICA 8): spazi di lavoro salvati, «ricette» di app e siti.

/// Una voce di una cartella (F-1).
public struct Voce: Equatable, Sendable {
    public var bid: String
    public var nome: String
    public var sito: String?          // webapp
    public var pagine: [String]?      // finestra di browser con più siti
    public var finestra: Bool         // una finestra precisa (DuckDuckGo, o una delle finestre di un'app)
    public var titolo: String?
    public var host: String?

    public init(bid: String, nome: String, sito: String? = nil, pagine: [String]? = nil, finestra: Bool = false,
                titolo: String? = nil, host: String? = nil) {
        self.bid = bid; self.nome = nome; self.sito = sito; self.pagine = pagine; self.finestra = finestra
        self.titolo = titolo; self.host = host
    }

    /// La chiave della voce (la stessa della Tabby di Hammerspoon: serve ai legami salvati).
    public var chiave: String {
        if let p = pagine, let prima = p.first { return "pagine:\(bid):\(prima)" }
        if finestra { return "finestra:\(bid):\(titolo ?? "nil"):\(host ?? "nil")" }
        return sito.map { "site:" + $0 } ?? bid
    }

    public init?(_ d: [String: Any]) {
        guard let b = d["bid"] as? String else { return nil }
        let w = (d["win"] as? Bool) ?? ((d["win"] as? Int).map { $0 != 0 } ?? false)
        self.init(bid: b, nome: d["name"] as? String ?? b, sito: d["site"] as? String, pagine: d["pages"] as? [String],
                  finestra: w, titolo: d["title"] as? String, host: d["host"] as? String)
    }
    public var dizionario: [String: Any] {
        var d: [String: Any] = ["bid": bid, "name": nome]
        if let sito { d["site"] = sito }
        if let pagine { d["pages"] = pagine }
        if finestra { d["win"] = true }
        if let titolo { d["title"] = titolo }
        if let host { d["host"] = host }
        return d
    }
}

public struct Cartella: Equatable, Sendable {
    public var id: Int
    public var nome: String
    public var voci: [Voce]
    public var chiave: String { "f:\(id)" }
    public init(id: Int, nome: String, voci: [Voce]) { self.id = id; self.nome = nome; self.voci = voci }
    public init?(_ d: [String: Any]) {
        guard let id = d["id"] as? Int else { return nil }
        self.init(id: id, nome: d["name"] as? String ?? "Cartella", voci: (d["items"] as? [[String: Any]] ?? []).compactMap(Voce.init))
    }
    public var dizionario: [String: Any] { ["id": id, "name": nome, "items": voci.map(\.dizionario)] }
}

/// Gli indirizzi di una voce «pagine», senza la parte dopo `?` e `#` (lì finiscono i codici di
/// accesso), solo http(s).
public func pulisci(_ url: String) -> String? {
    guard var c = URLComponents(string: url), let s = c.scheme?.lowercased(), s == "http" || s == "https" else { return nil }
    c.query = nil; c.fragment = nil
    return c.string
}

/// La scheda corrisponde alla voce? (F-2, punto 2). Per un browser la voce «app» sono le sue
/// finestre normali, non le webapp.
public func corrisponde(_ v: Voce, _ s: Scheda) -> Bool {
    if let sito = v.sito { return s.sito == sito }
    guard s.bid == v.bid, s.sito == nil else { return false }
    if let p = v.pagine {
        // almeno metà delle schede della finestra sono di siti della voce
        let siti = Set(p.compactMap(dominio))
        let tutte = (s.indirizzi ?? []).compactMap(dominio)
        return !tutte.isEmpty && tutte.filter(siti.contains).count * 2 >= tutte.count
    }
    if v.finestra {
        if let t = v.titolo, s.titolo == t { return true }
        return v.host != nil && s.inVista.flatMap(dominio) == v.host
    }
    return true
}

/// Il motore (F-2): per ogni cartella attiva (nell'ordine di attivazione), per ogni voce, la
/// scheda della finestra legata alla voce se c'è ancora; altrimenti la prima scheda libera che
/// corrisponde. Ogni voce prende al massimo una scheda, ogni scheda va in una cartella sola.
/// `membri`: per le viste divise, le loro schede (una vista corrisponde se uno dei membri
/// corrisponde). Restituisce scheda → cartella, i legami voce → finestra aggiornati, e per ogni
/// voce («id|chiave della voce») la scheda presa.
public func assegna(_ cartelle: [Cartella], schede: [Scheda], membri: [String: [Scheda]] = [:],
                    legami: [String: UInt32]) -> (diChi: [String: Int], legami: [String: UInt32], prese: [String: String]) {
    var diChi: [String: Int] = [:], nuovi = legami, prese: [String: String] = [:]
    func finestre(_ s: Scheda) -> [UInt32] { (membri[s.chiave] ?? [s]).compactMap(\.finestra) }
    for c in cartelle {
        for v in c.voci {
            let lk = "\(c.id)|\(v.chiave)"
            var presa: Scheda?
            if let w = legami[lk] { presa = schede.first { diChi[$0.chiave] == nil && finestre($0).contains(w) } }
            if presa == nil {
                presa = schede.first { s in diChi[s.chiave] == nil && (membri[s.chiave] ?? [s]).contains { corrisponde(v, $0) } }
            }
            guard let s = presa else { continue }
            diChi[s.chiave] = c.id
            prese[lk] = s.chiave
            if let w = finestre(s).first { nuovi[lk] = w }
        }
    }
    return (diChi, nuovi, prese)
}

/// La voce che rappresenta una scheda (per creare o aggiornare una cartella).
/// `variePerApp`: l'app ha più finestre-scheda (allora si ricorda quale).
public func voce(da s: Scheda, browser: Bool, breve: String?, variePerApp: Bool) -> Voce {
    if let sito = s.sito { return Voce(bid: s.bid, nome: s.nome, sito: sito) }
    if browser, let u = s.indirizzi?.compactMap(pulisci), !u.isEmpty, u.count > 1 || sitoDi(u) == nil {
        let t = s.titolo ?? breve ?? s.nome
        return Voce(bid: s.bid, nome: "\(t) · \(u.count) \(u.count == 1 ? "pagina" : "pagine")", pagine: u)
    }
    if s.finestra != nil && (browser || variePerApp) {
        return Voce(bid: s.bid, nome: (browser ? "\(breve ?? "") · " : "") + (s.titolo ?? s.nome), finestra: true,
                    titolo: s.titolo ?? s.nome, host: s.inVista.flatMap(dominio))
    }
    return Voce(bid: s.bid, nome: s.nome)
}

/// Una voce sta in una sola cartella (F-1): salvando `c`, le altre perdono le sue voci, e una
/// cartella rimasta vuota si cancella.
public func salva(_ c: Cartella, in tutte: [Cartella]) -> [Cartella] {
    let mie = Set(c.voci.map(\.chiave))
    var out = tutte.compactMap { x -> Cartella? in
        guard x.id != c.id else { return nil }
        var y = x
        y.voci.removeAll { mie.contains($0.chiave) }
        return y.voci.isEmpty ? nil : y
    }
    if let i = tutte.firstIndex(where: { $0.id == c.id }) { out.insert(c, at: min(i, out.count)) } else { out.append(c) }
    return out
}

/// Le schede da mostrare con le cartelle attive (F-5, F-6):
/// - nella **vista cartella** (`aperta`) solo le schede di quella cartella;
/// - con «Vista cartelle» accesa, le schede di ogni cartella attiva diventano **una scheda sola**
///   («f:<id>», al posto della sua prima scheda) con la somma delle notifiche;
/// - altrimenti le schede restano come sono.
public func conCartelle(_ schede: [Scheda], cartelle: [Cartella], diChi: [String: Int], vistaCartelle: Bool, aperta: Int?) -> [Scheda] {
    if let a = aperta { return schede.filter { diChi[$0.chiave] == a } }
    guard vistaCartelle else { return schede }
    var fatte = Set<Int>(), out: [Scheda] = []
    for s in schede {
        guard let id = diChi[s.chiave], let c = cartelle.first(where: { $0.id == id }) else { out.append(s); continue }
        guard fatte.insert(id).inserted else { continue }
        let sue = schede.filter { diChi[$0.chiave] == id }
        var somma = 0, pallino = false
        for m in sue { if let n = m.notifica { if let x = Int(n) { somma += x } else { pallino = true } } }
        out.append(Scheda(chiave: c.chiave, bid: s.bid, nome: c.nome, pid: s.pid, notifica: somma > 0 ? String(somma) : pallino ? "•" : nil))
    }
    return out
}
