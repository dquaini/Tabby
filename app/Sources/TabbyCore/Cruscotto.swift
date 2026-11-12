import Foundation

// MARK: - Il centro di controllo (il «cruscotto», fase 1, deciso con Daniele il 12/11/2026)

/// Le tessere del cruscotto: si scelgono, si tolgono e si riordinano (componibile).
public enum Tessera: String, CaseIterable, Sendable {
    case ora, batteria, meteo, musica, borsa, mac, uso
    public var nome: String {
        switch self {
        case .ora: "Ora e data"
        case .batteria: "Batteria"
        case .meteo: "Meteo"
        case .musica: "Musica"
        case .borsa: "Borsa"
        case .mac: "Mac"
        case .uso: "Tempo d'uso"
        }
    }
}

public let tessereDiSerie: [Tessera] = [.ora, .batteria, .meteo, .musica, .borsa, .mac, .uso]
public let titoliDiSerie = ["STZ", "DSY.PA", "XYZ"]          // Constellation Brands, Dassault Systèmes, Block

/// Le tessere salvate (nomi), senza doppioni né nomi sconosciuti; nil o vuoto = quelle di serie.
public func tessere(da salvate: [String]?) -> [Tessera] {
    guard let salvate else { return tessereDiSerie }
    var viste = Set<Tessera>()
    return salvate.compactMap(Tessera.init(rawValue:)).filter { viste.insert($0).inserted }
}

// MARK: - Meteo (Open-Meteo: gratis, senza account)

public struct GiornoMeteo: Equatable, Sendable {
    public var data: Date
    public var minima: Double
    public var massima: Double
    public var codice: Int
}

public struct Meteo: Equatable, Sendable {
    public var temperatura: Double
    public var codice: Int
    public var giorni: [GiornoMeteo]
}

/// La risposta di api.open-meteo.com/v1/forecast (current + daily) → il meteo.
public func meteo(da dati: Data) -> Meteo? {
    guard let j = try? JSONSerialization.jsonObject(with: dati) as? [String: Any],
          let ora = j["current"] as? [String: Any], let t = (ora["temperature_2m"] as? NSNumber)?.doubleValue,
          let c = (ora["weather_code"] as? NSNumber)?.intValue, let d = j["daily"] as? [String: Any],
          let date = d["time"] as? [String], let mx = d["temperature_2m_max"] as? [NSNumber],
          let mn = d["temperature_2m_min"] as? [NSNumber], let cc = d["weather_code"] as? [NSNumber] else { return nil }
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    let n = min(date.count, mx.count, mn.count, cc.count)
    let giorni = (0..<n).compactMap { i in
        f.date(from: date[i]).map { GiornoMeteo(data: $0, minima: mn[i].doubleValue, massima: mx[i].doubleValue, codice: cc[i].intValue) }
    }
    return Meteo(temperatura: t, codice: c, giorni: giorni)
}

/// La città cercata per nome (geocoding-api.open-meteo.com): nome, latitudine, longitudine.
public func città(da dati: Data) -> (nome: String, lat: Double, lon: Double)? {
    guard let j = try? JSONSerialization.jsonObject(with: dati) as? [String: Any],
          let r = (j["results"] as? [[String: Any]])?.first, let n = r["name"] as? String,
          let lat = (r["latitude"] as? NSNumber)?.doubleValue, let lon = (r["longitude"] as? NSNumber)?.doubleValue else { return nil }
    return (n, lat, lon)
}

/// Il tempo in parole, dai codici WMO di Open-Meteo.
public func descrizioneMeteo(_ c: Int) -> String {
    switch c {
    case 0: "sereno"
    case 1: "poco nuvoloso"
    case 2: "parzialmente nuvoloso"
    case 3: "coperto"
    case 45, 48: "nebbia"
    case 51...57: "pioviggine"
    case 61, 63, 80, 81: "pioggia"
    case 65, 82: "pioggia forte"
    case 66, 67: "pioggia gelata"
    case 71...77, 85, 86: "neve"
    case 95...99: "temporale"
    default: "—"
    }
}

/// Il simbolo di Apple per il tempo (SF Symbols).
public func simboloMeteo(_ c: Int) -> String {
    switch c {
    case 0: "sun.max"
    case 1, 2: "cloud.sun"
    case 3: "cloud"
    case 45, 48: "cloud.fog"
    case 51...67, 80...82: "cloud.rain"
    case 71...77, 85, 86: "cloud.snow"
    case 95...99: "cloud.bolt.rain"
    default: "cloud"
    }
}

// MARK: - Borsa (Yahoo Finance: non ufficiale, senza chiave; Apple non dà accesso)

public struct Quotazione: Equatable, Sendable {
    public var simbolo: String
    public var prezzo: Double
    public var variazione: Double        // in percento sul giorno prima
    public var valuta: String
}

/// La risposta di query1.finance.yahoo.com/v8/finance/chart/<simbolo> → la quotazione.
public func quotazione(da dati: Data) -> Quotazione? {
    guard let j = try? JSONSerialization.jsonObject(with: dati) as? [String: Any],
          let m = ((j["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first?["meta"] as? [String: Any],
          let s = m["symbol"] as? String, let p = (m["regularMarketPrice"] as? NSNumber)?.doubleValue else { return nil }
    let prima = (m["chartPreviousClose"] as? NSNumber)?.doubleValue ?? (m["previousClose"] as? NSNumber)?.doubleValue ?? p
    return Quotazione(simbolo: s, prezzo: p, variazione: prima > 0 ? (p - prima) / prima * 100 : 0, valuta: m["currency"] as? String ?? "")
}

/// I titoli scritti a mano («stz, dsy.pa  xyz») → simboli puliti, in maiuscolo, senza doppioni.
public func titoli(da testo: String) -> [String] {
    var visti = Set<String>()
    return testo.split(whereSeparator: { $0 == "," || $0 == " " || $0 == ";" }).map { $0.uppercased() }
        .filter { !$0.isEmpty && visti.insert($0).inserted }
}

// MARK: - Tempo d'uso (contato da Tabby: quello di macOS non si legge)

/// «2 h 10», «40 min», «meno di 1 min».
public func durata(_ secondi: Double) -> String {
    let m = Int(secondi / 60)
    if m < 1 { return "meno di 1 min" }
    if m < 60 { return "\(m) min" }
    return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60)"
}
