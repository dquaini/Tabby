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

/// B-9: un'altra finestra (fra quelle in `altre`) dove `sito` è già aperto: da sola (webapp),
/// fra le sue schede (Chrome, Safari) o nella scheda in vista (DuckDuckGo, che dice solo quella).
public func dovèGiàAperto(_ sito: String, tranne finestra: UInt32, in altre: [Scheda]) -> Scheda? {
    altre.first { t in
        guard let f = t.finestra, f != finestra else { return false }
        return t.sito == sito || t.inVista.flatMap(dominio) == sito || (t.indirizzi ?? []).contains { dominio($0) == sito }
    }
}

/// I nomi dei servizi più comuni, per dominio (il titolo della pagina spesso dice altro:
/// «Posta in arrivo», l'indirizzo email, il nome della chat).
public let serviziNoti: [String: String] = [
    "mail.proton.me": "Proton Mail", "calendar.proton.me": "Proton Calendar", "drive.proton.me": "Proton Drive",
    "pass.proton.me": "Proton Pass", "account.proton.me": "Proton",
    "mail.google.com": "Gmail", "calendar.google.com": "Google Calendar", "drive.google.com": "Google Drive",
    "docs.google.com": "Google Docs", "meet.google.com": "Meet", "chat.google.com": "Google Chat",
    "outlook.live.com": "Outlook", "outlook.office.com": "Outlook", "outlook.office365.com": "Outlook",
    "teams.microsoft.com": "Teams", "teams.live.com": "Teams",
    "web.whatsapp.com": "WhatsApp", "web.telegram.org": "Telegram", "app.slack.com": "Slack",
    "notion.so": "Notion", "app.notion.com": "Notion", "claude.ai": "Claude", "chatgpt.com": "ChatGPT",
    "github.com": "GitHub", "youtube.com": "YouTube", "music.youtube.com": "YouTube Music",
    "open.spotify.com": "Spotify", "linkedin.com": "LinkedIn", "x.com": "X", "instagram.com": "Instagram",
    "facebook.com": "Facebook", "messenger.com": "Messenger", "figma.com": "Figma", "trello.com": "Trello",
    "app.asana.com": "Asana", "linear.app": "Linear", "icloud.com": "iCloud", "netflix.com": "Netflix",
]

/// I servizi che la ricerca propone di aprire scrivendone il nome («proton» → Proton Mail), in
/// ordine: vince il primo il cui nome (o una sua parola) comincia con quello che hai scritto.
public let serviziDaAprire: [(nome: String, indirizzo: String)] = [
    ("Proton Mail", "https://mail.proton.me/"), ("Gmail", "https://mail.google.com/"), ("Google Calendar", "https://calendar.google.com/"),
    ("Google Drive", "https://drive.google.com/"), ("Google Docs", "https://docs.google.com/"), ("Meet", "https://meet.google.com/"),
    ("Outlook", "https://outlook.live.com/"), ("Teams", "https://teams.microsoft.com/"), ("WhatsApp", "https://web.whatsapp.com/"),
    ("Telegram", "https://web.telegram.org/"), ("Slack", "https://app.slack.com/"), ("Notion", "https://www.notion.so/"),
    ("Claude", "https://claude.ai/"), ("ChatGPT", "https://chatgpt.com/"), ("GitHub", "https://github.com/"),
    ("YouTube", "https://www.youtube.com/"), ("YouTube Music", "https://music.youtube.com/"), ("Spotify", "https://open.spotify.com/"),
    ("LinkedIn", "https://www.linkedin.com/"), ("X", "https://x.com/"), ("Instagram", "https://www.instagram.com/"),
    ("Facebook", "https://www.facebook.com/"), ("Messenger", "https://www.messenger.com/"), ("Figma", "https://www.figma.com/"),
    ("Trello", "https://trello.com/"), ("Asana", "https://app.asana.com/"), ("Linear", "https://linear.app/"),
    ("iCloud", "https://www.icloud.com/"), ("Netflix", "https://www.netflix.com/"), ("Proton Calendar", "https://calendar.proton.me/"),
    ("Proton Drive", "https://drive.proton.me/"), ("Proton Pass", "https://pass.proton.me/"),
]

/// Cosa propone la ricerca di Tabby sul web, per un testo (deciso con Daniele il 10/11/2026):
/// un **sito da aprire** se il testo è un indirizzo («raycast.com») o il nome di un servizio
/// conosciuto («proton»), e sempre, per ultima, la **ricerca** sul web (DuckDuckGo). Niente
/// esce dal Mac finché non scegli.
public enum PropostaWeb: Equatable, Sendable {
    case sito(nome: String, indirizzo: String, dominio: String)
    case ricerca(testo: String, indirizzo: String)
}

public func proposteWeb(_ domanda: String) -> [PropostaWeb] {
    let q = domanda.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }
    var out: [PropostaWeb] = []
    // un indirizzo: con «://», oppure senza spazi, con un punto e un finale di almeno 2 lettere
    let pezzi = q.split(separator: ".")
    let sembraIndirizzo = q.contains("://") || (!q.contains(" ") && pezzi.count >= 2 && (pezzi.last?.count ?? 0) >= 2
                                                && pezzi.last!.allSatisfy { $0.isLetter || $0 == "/" || $0.isNumber })
    if sembraIndirizzo {
        let u = q.contains("://") ? q : "https://" + q
        if let d = dominio(u) { out.append(.sito(nome: serviziNoti[d] ?? d, indirizzo: u, dominio: d)) }
    } else {
        let nq = normalizza(q)
        if nq.count >= 3, let s = serviziDaAprire.first(where: { s in
            let n = normalizza(s.nome)
            return n.hasPrefix(nq) || n.split(separator: " ").contains { $0.hasPrefix(nq) }
        }), let d = dominio(s.indirizzo) {
            out.append(.sito(nome: s.nome, indirizzo: s.indirizzo, dominio: d))
        }
    }
    let codificato = q.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? q
    out.append(.ricerca(testo: q, indirizzo: "https://duckduckgo.com/?q=" + codificato))
    return out
}

/// Un testo (un indirizzo) da mettere fra virgolette in un AppleScript: barre e virgolette
/// protette, così un indirizzo strano non rompe il comando.
public func perAppleScript(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

/// Il nome di una webapp dal titolo della finestra e dal dominio (B-4):
/// «Posta - io@x - Gmail» → «Gmail», «Inbox | Proton Mail» su mail.proton.me → «Proton Mail».
public func nomeSito(titolo: String?, dominio dom: String) -> String {
    // 0) i servizi conosciuti hanno il loro nome, qualunque cosa dica il titolo
    if let n = serviziNoti[dom] { return n }
    var t = titolo ?? ""
    if let r = t.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) { t.removeSubrange(r) }
    for sep in [" — ", " – ", " | ", " · ", " • ", " :: "] { t = t.replacingOccurrences(of: sep, with: " - ") }
    // mai un indirizzo email o web come nome («daniele@proton.me» non è il servizio)
    let pezzi = t.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.contains("@") && !$0.contains("://") && !$0.contains("/") }
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
