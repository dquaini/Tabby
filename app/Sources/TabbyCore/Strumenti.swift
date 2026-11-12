import Foundation

// MARK: - Lampi (SPECIFICA 14)

/// Un Lampo: una piccola app che si apre in alto a destra, sopra quello che fai, con ⌃⌥ + lettera.
public struct Lampo: Equatable, Sendable, Identifiable {
    public var memo: Bool
    public var bid: String?
    public var nome: String
    public var tasto: String          // una lettera
    public var larghezza: Double
    public var altezza: Double
    /// Le azioni di un'app nella barra dei menu (Claude chat rapida, Notion cerca): non sono
    /// finestre, si premono (X-1).
    public var barraMenu: Bool
    public var voceMenu: String?
    public var id: String { memo ? "memo" : (bid ?? nome) + (voceMenu ?? "") }

    public init(memo: Bool = false, bid: String? = nil, nome: String, tasto: String, larghezza: Double = 560, altezza: Double = 480,
                barraMenu: Bool = false, voceMenu: String? = nil) {
        self.memo = memo; self.bid = bid; self.nome = nome; self.tasto = tasto
        self.larghezza = larghezza; self.altezza = altezza; self.barraMenu = barraMenu; self.voceMenu = voceMenu
    }

    public init?(_ d: [String: Any]) {
        guard let n = d["name"] as? String, let k = d["key"] as? String else { return nil }
        let memo = (d["memo"] as? Bool) ?? ((d["memo"] as? Int).map { $0 != 0 } ?? false)
        let mb = (d["menubar"] as? Bool) ?? ((d["menubar"] as? Int).map { $0 != 0 } ?? false)
        self.init(memo: memo, bid: d["bid"] as? String, nome: n, tasto: k,
                  larghezza: d["w"] as? Double ?? (memo ? 340 : 560), altezza: d["h"] as? Double ?? (memo ? 280 : 480),
                  barraMenu: mb, voceMenu: d["menuItem"] as? String)
    }

    public var dizionario: [String: Any] {
        var d: [String: Any] = ["name": nome, "key": tasto, "w": larghezza, "h": altezza]
        if memo { d["memo"] = true }
        if let bid { d["bid"] = bid }
        if barraMenu { d["menubar"] = true }
        if let voceMenu { d["menuItem"] = voceMenu }
        return d
    }
}

/// I Lampi di serie (Q-1).
public let lampiDiSerie: [Lampo] = [
    Lampo(memo: true, nome: "Memo", tasto: "m", larghezza: 340, altezza: 280),
    Lampo(bid: "com.apple.calculator", nome: "Calcolatrice", tasto: "c", larghezza: 230, altezza: 410),
    Lampo(bid: "com.apple.iCal", nome: "Calendario", tasto: "a", larghezza: 680, altezza: 520),
    Lampo(bid: "com.apple.Terminal", nome: "Terminale", tasto: "t", larghezza: 760, altezza: 480),
]

/// Le lettere che Tabby usa già per sé (non possono essere di un Lampo).
public let lettereDiTabby: Set<String> = ["w", "s", "f", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

/// La prima lettera libera del nome (Q-1c), poi le altre dell'alfabeto.
public func letteraLibera(per nome: String, usate: Set<String>) -> String? {
    let prese = usate.union(lettereDiTabby)
    let dalNome = nome.lowercased().folding(options: .diacriticInsensitive, locale: nil).filter { $0.isLetter }.map(String.init)
    return (dalNome + "abcdefghijklmnopqrstuvwxyz".map(String.init)).first { !prese.contains($0) }
}

/// In fila (Q-1b): i Lampi aperti stanno in alto a destra dello spazio delle app, a 12 punti
/// l'uno dall'altro, in colonne da destra verso sinistra (uno sotto l'altro finché c'è posto).
/// Coordinate dall'alto. Restituisce nil per chi non trova posto.
public func inFila(_ misure: [CGSize], spazio r: CGRect, margine m: Double = 12) -> [CGRect?] {
    var fatti: [CGRect] = []
    var x = r.maxX - m, y = r.minY + m, largaColonna = 0.0
    return misure.map { d in
        if y + d.height > r.maxY - m, largaColonna > 0 {          // colonna piena: la prossima a sinistra
            x -= largaColonna + m; y = r.minY + m; largaColonna = 0
        }
        let f = CGRect(x: x - d.width, y: y, width: d.width, height: d.height)
        guard f.minX >= r.minX + m, f.maxY <= r.maxY - m + 0.5, !fatti.contains(where: { $0.intersects(f) }) else { return nil }
        fatti.append(f)
        y = f.maxY + m
        largaColonna = max(largaColonna, d.width)
        return f
    }
}

// MARK: - Concentrazione (SPECIFICA 16b)

/// Il tempo che manca, come si legge nella barra: «24 min», nell'ultimo minuto «0:45».
public func tempoCheManca(_ secondi: Double) -> String {
    let s = max(0, Int(secondi.rounded(.up)))
    if s < 60 { return "0:\(String(format: "%02d", s))" }
    return "\((s + 59) / 60) min"
}

/// Le notifiche arrivate durante la Concentrazione (H-4): la differenza dei numerini tra
/// l'inizio e la fine, per nome. «Slack 4 · Gmail 2».
public func arrivateNelFrattempo(inizio: [String: Int], fine: [String: Int]) -> [(nome: String, quante: Int)] {
    fine.compactMap { (n, f) in
        let d = f - (inizio[n] ?? 0)
        return d > 0 ? (n, d) : nil
    }.sorted { $0.quante != $1.quante ? $0.quante > $1.quante : $0.nome < $1.nome }
}

// MARK: - La barra che cerca tutto (DESIGN 3.6)

/// Minuscole e senza accenti: «perche» trova «perché».
public func normalizza(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
}

/// Un risultato possibile.
public struct Trovato: Equatable, Sendable, Identifiable {
    public enum Gruppo: Int, Sendable, CaseIterable, Comparable {
        case schede, finestre, cartelle, lampi, azioni, impostazioni, web
        public static func < (a: Gruppo, b: Gruppo) -> Bool { a.rawValue < b.rawValue }
        public var titolo: String {
            ["Schede e app", "Nelle finestre", "Cartelle", "Lampi", "Azioni", "Preferenze di Tabby", "Sul web"][rawValue]
        }
    }
    public var id: String
    public var gruppo: Gruppo
    public var titolo: String
    public var sotto: String          // l'app, o una spiegazione
    public var testo: String          // dove si cerca (titolo + altre parole; per le finestre il loro testo)
    public var uso: Int               // più alto = usato più di recente
    public var forte: Bool            // un'azione forte: serve un secondo ↵
    public init(id: String, gruppo: Gruppo, titolo: String, sotto: String = "", testo: String = "", uso: Int = 0, forte: Bool = false) {
        self.id = id; self.gruppo = gruppo; self.titolo = titolo; self.sotto = sotto; self.testo = testo; self.uso = uso; self.forte = forte
    }
}

/// Un risultato trovato, con il punteggio e il pezzetto di testo intorno alla parola.
public struct Risultato: Equatable, Sendable, Identifiable {
    public var t: Trovato
    public var punti: Int
    public var pezzetto: String?
    public var id: String { t.id }
    public init(t: Trovato, punti: Int, pezzetto: String?) { self.t = t; self.punti = punti; self.pezzetto = pezzetto }
}

/// Cerca: tutte le parole devono esserci (nel titolo o nel testo). Prima chi le ha nel titolo
/// (e all'inizio), poi quante volte compaiono, poi le più usate. Al massimo 3 per gruppo e 8 in
/// tutto; in cima «Il migliore» (il primo di tutti). Barra vuota: niente.
public func cerca(_ domanda: String, in tutto: [Trovato]) -> (migliore: Risultato?, gruppi: [(Trovato.Gruppo, [Risultato])]) {
    let parole = normalizza(domanda).split(whereSeparator: \.isWhitespace).map(String.init)
    guard !parole.isEmpty else { return (nil, []) }
    var trovati: [Risultato] = []
    for t in tutto {
        let tit = normalizza(t.titolo + " " + t.sotto), tx = normalizza(t.testo)
        var punti = 0, ok = true
        for p in parole {
            if tit.hasPrefix(p) { punti += 120 }
            else if tit.contains(" " + p) { punti += 90 }
            else if tit.contains(p) { punti += 60 }
            else if tx.contains(p) { punti += min(40, 8 + tx.components(separatedBy: p).count * 4) }
            else { ok = false; break }
        }
        guard ok else { continue }
        punti += min(t.uso, 30)
        let nelTitolo = parole.allSatisfy { tit.contains($0) }
        trovati.append(Risultato(t: t, punti: punti, pezzetto: nelTitolo ? nil : pezzetto(t.testo, parola: parole[0])))
    }
    trovati.sort { $0.punti != $1.punti ? $0.punti > $1.punti : $0.t.titolo < $1.t.titolo }
    guard let primo = trovati.first else { return (nil, []) }
    var gruppi: [(Trovato.Gruppo, [Risultato])] = [], totale = 1
    for g in Trovato.Gruppo.allCases {
        let qui = trovati.filter { $0.t.gruppo == g && $0.id != primo.id }.prefix(3)
        let presi = Array(qui.prefix(max(0, 8 - totale)))
        if !presi.isEmpty { gruppi.append((g, presi)); totale += presi.count }
    }
    return (primo, gruppi)
}

/// Il pezzetto di testo intorno alla parola (per «Nelle finestre»).
public func pezzetto(_ testo: String, parola: String, intorno: Int = 36) -> String? {
    let n = normalizza(testo)
    guard let r = n.range(of: parola) else { return nil }
    let i = n.distance(from: n.startIndex, to: r.lowerBound)
    let chars = Array(testo)
    guard i < chars.count else { return nil }
    let da = max(0, i - intorno), a = min(chars.count, i + parola.count + intorno)
    let s = String(chars[da..<a]).replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    return (da > 0 ? "…" : "") + s + (a < chars.count ? "…" : "")
}
