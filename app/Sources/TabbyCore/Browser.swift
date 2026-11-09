import Foundation

/// I browser che Tabby conosce (SPECIFICA 3). Chrome, Brave, Edge e Safari rispondono ad
/// AppleScript; DuckDuckGo no: lì Tabby guarda con l'Accessibilità.
public struct BrowserNoto: Sendable {
    public enum Tipo: Sendable { case chrome, safari, accessibilita }
    public let tipo: Tipo
    public let nomeAS: String      // il nome per AppleScript
    public let breve: String       // il nome sulla scheda
}

public let browserNoti: [String: BrowserNoto] = [
    "com.google.Chrome": .init(tipo: .chrome, nomeAS: "Google Chrome", breve: "Chrome"),
    "com.brave.Browser": .init(tipo: .chrome, nomeAS: "Brave Browser", breve: "Brave"),
    "com.microsoft.edgemac": .init(tipo: .chrome, nomeAS: "Microsoft Edge", breve: "Edge"),
    "com.apple.Safari": .init(tipo: .safari, nomeAS: "Safari", breve: "Safari"),
    "com.duckduckgo.macos.browser": .init(tipo: .accessibilita, nomeAS: "", breve: "DuckDuckGo"),
]

/// Il dominio di un indirizzo, minuscolo e senza «www.» (B-4). Nil se non è una pagina web.
public func dominio(_ url: String) -> String? {
    guard let c = URLComponents(string: url), let s = c.scheme?.lowercased(), s == "http" || s == "https",
          var h = c.host?.lowercased(), !h.isEmpty else { return nil }
    if h.hasPrefix("www.") { h.removeFirst(4) }
    return h
}

/// Privacy (B-2): di un indirizzo si tiene solo il sito, «https://dominio/».
public func soloSito(_ url: String) -> String? {
    var u = url.trimmingCharacters(in: .whitespaces)
    if !u.contains("://") { u = "https://" + u }
    guard let c = URLComponents(string: u), let s = c.scheme, let h = c.host, !h.isEmpty else { return nil }
    return "\(s)://\(h)/"
}

/// Il sito di una finestra se **tutte** le sue schede sono dello stesso sito (webapp).
public func sitoDi(_ urls: [String]) -> String? {
    guard !urls.isEmpty else { return nil }
    var d: String?
    for u in urls {
        guard let x = dominio(u), d == nil || d == x else { return nil }
        d = x
    }
    return d
}

/// Il nome di una webapp dal titolo della finestra e dal dominio (B-4):
/// «Posta - io@x - Gmail» → «Gmail», «Inbox | Proton Mail» su mail.proton.me → «Proton Mail».
public func nomeSito(titolo: String?, dominio dom: String) -> String {
    var t = titolo ?? ""
    if let r = t.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) { t.removeSubrange(r) }
    for sep in [" — ", " – ", " | ", " · ", " • ", " :: "] { t = t.replacingOccurrences(of: sep, with: " - ") }
    let pezzi = t.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    let etichette = dom.split(separator: ".").map(String.init)
    let principale = etichette.count >= 2 ? etichette[etichette.count - 2] : (etichette.first ?? dom)
    // 1) il pezzo che contiene il nome principale del dominio
    if let p = pezzi.reversed().first(where: { $0.count <= 24 && $0.lowercased().contains(principale.lowercased()) }) { return p }
    // 2) un pezzo uguale a un'etichetta del dominio («Meet» su meet.google.com)
    for p in pezzi.reversed() {
        if etichette.contains(where: { $0.count >= 3 && $0.lowercased() == p.lowercased() }) { return p }
    }
    // 3) l'ultimo pezzo, se il titolo è fatto a pezzi
    if pezzi.count >= 2, let u = pezzi.last, (2...24).contains(u.count) { return u }
    // 4) il nome del dominio con l'iniziale maiuscola
    return principale.prefix(1).uppercased() + principale.dropFirst()
}

/// Le notifiche scritte nel titolo delle webapp (N-2): «(3) WhatsApp», «Posta (12) - …».
public func notificaDalTitolo(_ titolo: String?) -> String? {
    guard let t = titolo else { return nil }
    if let r = t.range(of: #"^\((\d+)\)"#, options: .regularExpression) {
        return String(t[r].dropFirst().dropLast())
    }
    if let r = t.range(of: #"^[^-|]*?\((\d+)\)\s"#, options: .regularExpression) {
        let pezzo = t[r]
        if let a = pezzo.lastIndex(of: "("), let b = pezzo.lastIndex(of: ")") { return String(pezzo[pezzo.index(after: a)..<b]) }
    }
    return nil
}

// MARK: - Le finestre secondo il browser (AppleScript)

/// Una finestra come la descrive il browser (B-1).
public struct FinestraBrowser: Equatable, Sendable {
    public var nome: String
    public var numero: Int?            // il numero che il browser dà alla finestra (non cambia)
    public var cornice: CGRect?        // in coordinate dall'alto, come l'Accessibilità
    public var urls: [String]
    public init(nome: String, numero: Int? = nil, cornice: CGRect? = nil, urls: [String]) {
        self.nome = nome; self.numero = numero; self.cornice = cornice; self.urls = urls
    }
}

/// Legge la risposta dello script (una riga per finestra, campi separati da tabulazione:
/// titolo, «id<n>», «sx,alto,dx,basso», poi gli indirizzi).
public func leggiRisposta(_ testo: String) -> [FinestraBrowser] {
    testo.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).map { riga in
        var campi = riga.components(separatedBy: "\t")
        let nome = campi.isEmpty ? "" : campi.removeFirst()
        var numero: Int?
        if let f = campi.first, f.hasPrefix("id") { numero = Int(f.dropFirst(2)); campi.removeFirst() }
        var cornice: CGRect?
        if let f = campi.first {
            let n = f.split(separator: ",").compactMap { Double($0) }
            if n.count == 4 { cornice = CGRect(x: n[0], y: n[1], width: n[2] - n[0], height: n[3] - n[1]); campi.removeFirst() }
            else if f == "-" { campi.removeFirst() }
        }
        return FinestraBrowser(nome: nome, numero: numero, cornice: cornice, urls: campi.filter { !$0.isEmpty })
    }
}

/// Lo script per Chrome/Brave/Edge/Safari. Attenzione: dentro «tell application» la parola
/// `tab` è la scheda del browser, quindi i separatori si preparano prima (TB, NL).
public func scriptFinestre(_ nomeAS: String) -> String {
    """
    set TB to (ASCII character 9)
    set NL to (ASCII character 10)
    with timeout of 2 seconds
      tell application "\(nomeAS)"
        set out to ""
        repeat with w in windows
          try
            set row to (name of w) & TB
            try
              set row to row & "id" & ((id of w) as text) & TB
            on error
              set row to row & "id?" & TB
            end try
            try
              set b to bounds of w
              set row to row & ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text) & TB
            on error
              set row to row & "-" & TB
            end try
            repeat with t in tabs of w
              try
                set row to row & (URL of t) & TB
              on error
                set row to row & "about:blank" & TB
              end try
            end repeat
            set out to out & row & NL
          end try
        end repeat
        return out
      end tell
    end timeout
    """
}

/// Una finestra sullo schermo, per l'abbinamento.
public struct FinestraSchermo: Sendable {
    public var id: UInt32
    public var titolo: String
    public var cornice: CGRect
    public var piccola: Bool
    public init(id: UInt32, titolo: String, cornice: CGRect, piccola: Bool) {
        self.id = id; self.titolo = titolo; self.cornice = cornice; self.piccola = piccola
    }
}

/// Abbina le finestre sullo schermo a quelle del browser (B-3), dal modo più sicuro al meno:
/// 0) il numero della finestra ricordato · 1) titolo e posizione · 2) inizio del titolo e
/// posizione · 3) titolo · 4) inizio del titolo (3 e 4 solo finestre grandi) · 5) solo
/// posizione, se unica. Restituisce l'abbinamento (finestra → indice nel browser) e la
/// memoria aggiornata dei numeri (solo per gli abbinamenti sicuri).
public func abbina(_ schermo: [FinestraSchermo], _ browser: [FinestraBrowser], memoria: [UInt32: Int])
    -> (trovate: [UInt32: Int], memoria: [UInt32: Int]) {
    var trovate: [UInt32: Int] = [:], come: [UInt32: Int] = [:], usate = Set<Int>()
    func stessoPosto(_ w: FinestraSchermo, _ b: FinestraBrowser) -> Bool {
        guard let r = b.cornice else { return false }
        let f = w.cornice
        return abs(f.minX - r.minX) < 4 && abs(f.minY - r.minY) < 4 && abs(f.width - r.width) < 4 && abs(f.height - r.height) < 4
    }
    func inizia(_ w: FinestraSchermo, _ b: FinestraBrowser) -> Bool {
        !b.nome.isEmpty && w.titolo.count > b.nome.count && w.titolo.hasPrefix(b.nome + " ")
    }
    // 0) il numero ricordato
    for w in schermo {
        guard let n = memoria[w.id], let k = browser.indices.first(where: { !usate.contains($0) && browser[$0].numero == n }) else { continue }
        trovate[w.id] = k; usate.insert(k); come[w.id] = 0
    }
    func passaggio(_ passo: Int, soloGrandi: Bool = false, _ prova: (FinestraSchermo, Int) -> Bool) {
        for w in schermo where trovate[w.id] == nil && !(soloGrandi && w.piccola) {
            if let k = browser.indices.first(where: { !usate.contains($0) && prova(w, $0) }) {
                trovate[w.id] = k; usate.insert(k); come[w.id] = passo
            }
        }
    }
    passaggio(1) { w, k in browser[k].nome == w.titolo && stessoPosto(w, browser[k]) }
    passaggio(2) { w, k in inizia(w, browser[k]) && stessoPosto(w, browser[k]) }
    passaggio(3, soloGrandi: true) { w, k in browser[k].nome == w.titolo }
    passaggio(4, soloGrandi: true) { w, k in inizia(w, browser[k]) }
    passaggio(5) { w, k in
        guard stessoPosto(w, browser[k]) else { return false }
        let altreQui = schermo.contains { $0.id != w.id && trovate[$0.id] == nil && stessoPosto($0, browser[k]) }
        let altriLà = browser.indices.contains { $0 != k && !usate.contains($0) && stessoPosto(w, browser[$0]) }
        return !altreQui && !altriLà
    }
    // si ricorda il numero solo per gli abbinamenti sicuri (titolo unico, non «solo posizione»)
    var conta: [String: Int] = [:]
    for w in schermo { conta[w.titolo, default: 0] += 1 }
    var nuova: [UInt32: Int] = [:]
    for w in schermo {
        guard let k = trovate[w.id], let n = browser[k].numero, let c = come[w.id] else { continue }
        if c == 0 || (c != 5 && conta[w.titolo] == 1) { nuova[w.id] = n }
    }
    return (trovate, nuova)
}
