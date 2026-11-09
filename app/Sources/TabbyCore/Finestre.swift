import Foundation

/// Quello che Tabby sa di un'app aperta (lo legge dall'Accessibilità).
public struct InfoApp: Sendable {
    public var bid: String
    public var nome: String
    public var pid: Int32
    public var finestre: [InfoFinestra]
    /// Per i browser: il nome breve («Chrome»); le finestre sono sempre schede separate.
    public var breve: String?
    public init(bid: String, nome: String, pid: Int32, finestre: [InfoFinestra], breve: String? = nil) {
        self.bid = bid; self.nome = nome; self.pid = pid; self.finestre = finestre; self.breve = breve
    }
}

public struct InfoFinestra: Sendable {
    public var id: UInt32
    public var titolo: String
    public var ridotta: Bool
    /// Browser: il sito, se la finestra è una webapp (tutte le schede dello stesso sito).
    public var sito: String?
    /// Browser: il titolo come lo dà il browser (senza il nome del profilo).
    public var titoloBrowser: String?
    /// Browser: gli indirizzi delle schede (Chrome, Safari…) e il sito in vista (DuckDuckGo).
    public var indirizzi: [String]?
    public var inVista: String?
    public init(id: UInt32, titolo: String, ridotta: Bool = false, sito: String? = nil, titoloBrowser: String? = nil,
                indirizzi: [String]? = nil, inVista: String? = nil) {
        self.id = id; self.titolo = titolo; self.ridotta = ridotta; self.sito = sito; self.titoloBrowser = titoloBrowser
        self.indirizzi = indirizzi; self.inVista = inVista
    }
}

/// Le schede di tutte le app (S-2, S-3, S-4, S-6):
/// - 1 finestra → una scheda col nome dell'app (chiave = bundle ID);
/// - 2 o più → una scheda per finestra, la più vecchia con chiave = bundle ID, le altre
///   `win:<id>`; nome = titolo senza il nome dell'app; titoli uguali → «(2)», «(3)»…;
/// - app con «una scheda sola» (`separate` falso) → una scheda per tutta l'app;
/// - app senza finestre → una scheda solo se `senzaFinestre` (altrimenti niente);
/// - `nomi`: i nomi dati dall'utente (Rinomina), per chiave.
public func costruisciSchede(_ apps: [InfoApp], separate: (String) -> Bool = { _ in true },
                             senzaFinestre: Bool = false, nomi: [String: String] = [:]) -> [Scheda] {
    var schede: [Scheda] = []
    var prese = Set<String>()
    for a0 in apps {
        var a = a0
        var fin = a.finestre.sorted { $0.id < $1.id }
        // Browser (B-4, B-5): le finestre con un solo sito sono webapp (`site:<dominio>`),
        // le altre come le finestre di ogni app, col nome breve del browser.
        if let breve = a.breve {
            for f in fin {
                guard let d = f.sito else { continue }
                var k = "site:" + d
                if prese.contains(k) { k = "win:\(f.id)" }      // stesso sito già aperto altrove: scheda a sé
                prese.insert(k)
                schede.append(Scheda(chiave: k, bid: a.bid, nome: nomi[k] ?? nomeSito(titolo: f.titoloBrowser ?? f.titolo, dominio: d),
                                     pid: a.pid, finestra: f.id, ridotta: f.ridotta, sito: d,
                                     notifica: notificaDalTitolo(f.titolo) ?? notificaDalTitolo(f.titoloBrowser)))
            }
            fin = fin.filter { $0.sito == nil }.map { var x = $0; x.titolo = x.titoloBrowser ?? x.titolo; return x }
            a.nome = breve
            if fin.isEmpty { continue }
        }
        if fin.isEmpty {
            if senzaFinestre, prese.insert(a.bid).inserted {
                schede.append(Scheda(chiave: a.bid, bid: a.bid, nome: nomi[a.bid] ?? a.nome, pid: a.pid))
            }
            continue
        }
        if fin.count == 1 || (a.breve == nil && !separate(a.bid)) {
            let f = fin.first { !$0.ridotta } ?? fin[0]
            let k = prese.contains(a.bid) ? "win:\(f.id)" : a.bid
            prese.insert(k)
            schede.append(Scheda(chiave: k, bid: a.bid, nome: nomi[k] ?? a.nome, pid: a.pid,
                                 finestra: fin.count == 1 ? f.id : nil, ridotta: fin.allSatisfy(\.ridotta)))
            continue
        }
        var visti: [String: Int] = [:]
        for (i, f) in fin.enumerated() {
            var nome = nomeFinestra(titolo: f.titolo, app: a.nome)
            visti[nome, default: 0] += 1
            if let n = visti[nome], n > 1 { nome += " (\(n))" }
            var k = i == 0 ? a.bid : "win:\(f.id)"
            if prese.contains(k) { k = "win:\(f.id)" }          // S-6: chiave già presa
            prese.insert(k)
            schede.append(Scheda(chiave: k, bid: a.bid, nome: nomi[k] ?? nome, pid: a.pid, finestra: f.id, ridotta: f.ridotta))
        }
    }
    // per le cartelle: titolo, indirizzi e sito in vista di ogni finestra
    var info: [UInt32: (InfoFinestra, String)] = [:]
    for a in apps { for f in a.finestre { info[f.id] = (f, a.breve ?? a.nome) } }
    for i in schede.indices {
        guard let f = schede[i].finestra, let (x, app) = info[f] else { continue }
        schede[i].titolo = nomeFinestra(titolo: x.titoloBrowser ?? x.titolo, app: app)
        schede[i].indirizzi = x.indirizzi
        schede[i].inVista = x.inVista
    }
    return schede
}

/// La scheda accanto (C-4): quando la scheda attiva si chiude o si riduce si passa a quella
/// alla sua sinistra, o a destra se era la prima. `prima` = le schede di prima, `dopo` = quelle
/// di adesso. Restituisce la chiave della scheda dove andare (nil se non c'è niente).
public func schedaAccanto(chiusa: String, prima: [String], dopo: [String]) -> String? {
    guard let i = prima.firstIndex(of: chiusa) else { return dopo.first }
    let candidati = (i > 0 ? Array(prima[..<i].reversed()) : []) + Array(prima[(i + 1)...])
    return candidati.first { dopo.contains($0) } ?? dopo.first
}

/// Una scheda è davvero chiusa (C-4)? Non lo è se è solo raccolta dentro una vista divisa o una
/// scheda-cartella: `visibili` sono le schede in barra, `tutte` anche quelle raccolte.
public func èChiusa(_ chiave: String, visibili: [Scheda], tutte: [Scheda]) -> Bool {
    !(visibili + tutte).contains { $0.chiave == chiave && !$0.ridotta }
}

/// Dove andare quando si chiude (o si riduce) la scheda attiva: se la sua app ha altre
/// finestre, anche ridotte, la più vicina di quelle (come C-3); altrimenti la scheda accanto.
public func dopoLaChiusura(di chiusa: Scheda, prima: [Scheda], adesso: [Scheda]) -> String? {
    let stessa = adesso.filter { $0.bid == chiusa.bid }.map(\.chiave)
    return schedaAccanto(chiusa: chiusa.chiave, prima: prima.map(\.chiave), dopo: stessa.isEmpty ? adesso.map(\.chiave) : stessa)
}

/// Il riordino trascinando (T-1): sposta `chiave` prima di `davanti` (nil = in fondo)
/// nell'ordine ricordato, che contiene anche schede non visibili.
public func sposta(_ chiave: String, davanti: String?, in ordine: [String]) -> [String] {
    var o = ordine.filter { $0 != chiave }
    if let d = davanti, let i = o.firstIndex(of: d) { o.insert(chiave, at: i) }
    else if let d = davanti, d == chiave { return ordine }
    else { o.append(chiave) }
    return o
}
