import ApplicationServices
import Foundation

/// I permessi di macOS che servono a Tabby.
/// Solo uno è indispensabile: **Accessibilità** (vedere, spostare e nascondere le finestre).
/// L'accesso ai browser (Automazione) lo chiede macOS da solo, la prima volta, browser per
/// browser. Tabby non chiede altro (niente registrazione dello schermo, microfono, ecc.).
public enum Permessi {
    /// Tabby ha già il permesso Accessibilità?
    public static var accessibilita: Bool { AXIsProcessTrusted() }

    /// Fa comparire la richiesta di macOS (con il pulsante per aprire Impostazioni di Sistema).
    /// Si usa solo dalla guida del primo avvio, dopo aver spiegato il perché.
    public static func chiediAccessibilita() {
        let chiave = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([chiave: true] as CFDictionary)
    }

    /// Apre Impostazioni di Sistema direttamente su Privacy e sicurezza › Accessibilità.
    public static let paginaAccessibilita =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}

/// Si accorge da sola quando Daniele dà il permesso (niente riavvio): controlla una volta al
/// secondo **solo finché manca**, poi si ferma e non consuma più nulla.
@MainActor
public final class AttesaPermesso {
    private var lavoro: Task<Void, Never>?
    private var inAttesa: [@MainActor () -> Void] = []

    public init() {}

    /// Chi aspetta (l'avvio di Tabby, la pagina della guida…) viene avvisato, ognuno: prima una
    /// seconda richiesta cancellava la prima e Tabby restava ferma dopo il permesso dato nella guida.
    public func aspetta(_ fatto: @escaping @MainActor () -> Void) {
        if Permessi.accessibilita { fatto(); return }
        inAttesa.append(fatto)
        guard lavoro == nil else { return }
        lavoro = Task { @MainActor in
            while !Permessi.accessibilita { try? await Task.sleep(for: .seconds(1)) }
            diario("permesso Accessibilità dato")
            let tutti = inAttesa
            inAttesa = []; lavoro = nil
            tutti.forEach { $0() }
        }
    }
}
