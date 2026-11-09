import Foundation

/// Le misure della barra, decise nel design (DESIGN.md 2.3 e 3.7) e nella SPECIFICA (L-1, L-2).
public enum Misure {
    public static let altezza: Double = 38          // barra in alto o in basso
    public static let larghezzaLato: Double = 168   // barra a destra o a sinistra
    public static let altezzaScheda: Double = 28
    public static let angoloBarra: Double = 14      // solo dal lato delle app
    public static let angoloScheda: Double = 9
    public static let gatto: Double = 38
    public static let tasto: Double = 34            // batteria, ⊞, ⚡︎, ⚙︎
    public static let piu: Double = 30
    public static let schedaMax: Double = 190
    public static let schedaMin: Double = 120
    public static let compatta: Double = 30         // solo l'icona
    public static let compattaAttiva: Double = 160
    public static let piuN: Double = 40             // «+3»
    public static let riga: Double = 32             // di lato: righe da 32 …
    public static let rigaMin: Double = 26          // … che si abbassano fino a 26
}

/// Come stanno le schede in una barra orizzontale (L-1): tutte larghe uguali fino a 190;
/// se non ci stanno si stringono fino a 120; sotto → **compatte** (solo icona, l'attiva larga
/// col nome); se non ci stanno neanche così, le ultime finiscono in «+N» (l'attiva resta).
public struct DisposizioneOrizzontale: Equatable, Sendable {
    public var larghezza: Double        // delle schede normali (o compatte)
    public var compatta: Bool
    public var visibili: [Int]          // indici delle schede mostrate, in ordine
    public var altre: Int               // quante nel «+N»

    public init(larghezza: Double, compatta: Bool, visibili: [Int], altre: Int) {
        self.larghezza = larghezza; self.compatta = compatta; self.visibili = visibili; self.altre = altre
    }
}

public func disponiOrizzontale(spazio: Double, numero n: Int, attiva: Int?) -> DisposizioneOrizzontale {
    guard n > 0 else { return .init(larghezza: 0, compatta: false, visibili: [], altre: 0) }
    let gap = 2.0
    let w = min(Misure.schedaMax, (spazio - gap * Double(n - 1)) / Double(n))
    if w >= Misure.schedaMin {
        return .init(larghezza: w.rounded(.down), compatta: false, visibili: Array(0..<n), altre: 0)
    }
    // compatte: l'attiva larga, le altre solo icona
    func serve(_ k: Int, conAttiva: Bool) -> Double {
        let base = Double(k) * (Misure.compatta + gap)
        return conAttiva ? base - Misure.compatta + Misure.compattaAttiva : base
    }
    if serve(n, conAttiva: attiva != nil) <= spazio {
        return .init(larghezza: Misure.compatta, compatta: true, visibili: Array(0..<n), altre: 0)
    }
    // non ci stanno: quante ne entrano lasciando posto a «+N»
    var k = n
    while k > 1 && serve(k, conAttiva: attiva != nil) + Misure.piuN > spazio { k -= 1 }
    var vis = Array(0..<k)
    if let a = attiva, a >= k { vis[k - 1] = a }     // la scheda attiva resta sempre visibile
    return .init(larghezza: Misure.compatta, compatta: true, visibili: vis, altre: n - k)
}

/// Di lato (L-2): righe da 32 che si abbassano fino a 26; poi «+N altre».
public func disponiVerticale(spazio: Double, numero n: Int, attiva: Int?) -> (riga: Double, visibili: [Int], altre: Int) {
    guard n > 0 else { return (Misure.riga, [], 0) }
    let r = min(Misure.riga, spazio / Double(n))
    if r >= Misure.rigaMin { return (r.rounded(.down), Array(0..<n), 0) }
    var k = max(1, Int((spazio - Misure.rigaMin) / Misure.rigaMin))
    k = min(k, n)
    var vis = Array(0..<k)
    if let a = attiva, a >= k { vis[k - 1] = a }
    return (Misure.rigaMin, vis, n - k)
}

/// Il colore della batteria (L-5): verde da 80% in su, rossa sotto il 35% se non è in carica.
public enum ColoreBatteria: Equatable, Sendable { case verde, rossa, normale }
public func coloreBatteria(livello: Int, inCarica: Bool) -> ColoreBatteria {
    if livello >= 80 { return .verde }
    if livello < 35 && !inCarica { return .rossa }
    return .normale
}
