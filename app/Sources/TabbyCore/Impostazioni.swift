import Foundation

/// Le impostazioni di Tabby, salvate nelle preferenze di macOS dell'app (com.dquaini.Tabby).
/// Le chiavi tengono il prefisso storico «tabbar.» della Tabby di Hammerspoon, così si
/// riconoscono e l'importazione è una semplice copia.
public final class Impostazioni: @unchecked Sendable {
    public static let shared = Impostazioni()

    public let archivio: UserDefaults
    public init(archivio: UserDefaults = .standard) { self.archivio = archivio }

    public func valore(_ nome: String) -> Any? { archivio.object(forKey: "tabbar." + nome) }
    public func imposta(_ nome: String, _ v: Any?) { archivio.set(v, forKey: "tabbar." + nome) }

    // Le impostazioni più usate, con il valore di serie (lo stesso di Hammerspoon).
    public var posizione: String { valore("position") as? String ?? "top" }
    public var ordine: [String] { valore("order") as? [String] ?? [] }
    public var preferite: [String] { valore("pinned") as? [String] ?? [] }
    public var unaAllaVolta: Bool { valore("oneAtATime") as? Bool ?? true }
    public var adatta: Bool { valore("fit") as? Bool ?? true }
    public var nascondiTabby: Bool { valore("autohide") as? Bool ?? false }
    public var inPausa: Bool { valore("paused") as? Bool ?? false }
    public var cartelle: [[String: Any]] { valore("folders") as? [[String: Any]] ?? [] }
    public var lampi: [[String: Any]] { valore("quick") as? [[String: Any]] ?? [] }
}

/// Porta nell'app le impostazioni della Tabby di Hammerspoon (schede, cartelle, Lampi, Memo,
/// posizione…), **una volta sola**, senza toccare quelle di Hammerspoon.
public enum Importazione {
    public static let dominioHammerspoon = "org.hammerspoon.Hammerspoon"
    static let fatta = "tabby.importazioneFatta"

    /// Restituisce quante impostazioni ha copiato (0 se era già fatta o non c'era niente).
    @discardableResult
    public static func daHammerspoon(sorgente: UserDefaults? = UserDefaults(suiteName: dominioHammerspoon),
                                     in impostazioni: Impostazioni = .shared) -> Int {
        let dest = impostazioni.archivio
        guard !dest.bool(forKey: fatta), let sorgente else { return 0 }
        let vecchie = sorgente.dictionaryRepresentation().filter { $0.key.hasPrefix("tabbar.") }
        for (chiave, valore) in vecchie where dest.object(forKey: chiave) == nil {
            dest.set(valore, forKey: chiave)
        }
        dest.set(true, forKey: fatta)
        diario("importate \(vecchie.count) impostazioni da Hammerspoon")
        return vecchie.count
    }
}
