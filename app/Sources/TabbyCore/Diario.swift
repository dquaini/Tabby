import Foundation
import os

/// Il diario di Tabby: ogni riga inizia con «Tabby ·» e finisce in ~/Library/Logs/Tabby.log
/// (lo stesso file della Tabby di Hammerspoon), che resta dopo i riavvii. Serve a capire i
/// problemi veri invece di tirare a indovinare. Va anche nella Console di macOS.
/// Quando il file supera 1 MB, il vecchio diventa Tabby.1.log e se ne comincia uno nuovo.
public final class Diario: @unchecked Sendable {
    public static let shared = Diario()

    public let percorso: URL
    private let limite: Int
    private let coda = DispatchQueue(label: "tabby.diario")   // scrive senza fermare l'app
    private let console = Logger(subsystem: "com.dquaini.Tabby", category: "diario")
    private let formato: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    public init(percorso: URL? = nil, limite: Int = 1_000_000) {
        self.percorso = percorso ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Tabby.log")
        self.limite = limite
    }

    /// Scrive una riga: `Diario.shared.scrivi("notch: 32 punti")` → «… Tabby · notch: 32 punti»
    public func scrivi(_ testo: String) {
        let riga = "Tabby · " + testo
        console.log("\(riga, privacy: .public)")
        let ora = formato.string(from: Date())
        coda.async { [self] in aggiungi("\(ora)  \(riga)\n") }
    }

    /// Aspetta che le righe in coda siano sul disco (per i test e prima di uscire).
    public func aspetta() { coda.sync {} }

    private func aggiungi(_ riga: String) {
        let fm = FileManager.default
        if let attr = try? fm.attributesOfItem(atPath: percorso.path),
           let dim = attr[.size] as? Int, dim > limite {
            let vecchio = percorso.deletingPathExtension().appendingPathExtension("1.log")
            try? fm.removeItem(at: vecchio)
            try? fm.moveItem(at: percorso, to: vecchio)
        }
        guard let dati = riga.data(using: .utf8) else { return }
        if let file = try? FileHandle(forWritingTo: percorso) {
            defer { try? file.close() }
            _ = try? file.seekToEnd()
            try? file.write(contentsOf: dati)
        } else {
            try? fm.createDirectory(at: percorso.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? dati.write(to: percorso)
        }
    }
}

/// Scorciatoia: `diario("…")`.
public func diario(_ testo: String) { Diario.shared.scrivi(testo) }

/// Misura un lavoro: se supera 150 ms lo scrive nel diario («Tabby · lento: …»), come faceva
/// la Tabby di Hammerspoon. Serve a tenere Tabby velocissima.
@discardableResult
public func misura<T>(_ nome: String, soglia: Double = 0.150, _ lavoro: () throws -> T) rethrows -> T {
    let inizio = DispatchTime.now().uptimeNanoseconds
    defer {
        let secondi = Double(DispatchTime.now().uptimeNanoseconds - inizio) / 1e9
        if secondi > soglia { diario("lento: \(nome) \(Int(secondi * 1000)) ms") }
    }
    return try lavoro()
}
