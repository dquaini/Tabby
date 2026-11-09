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

    public init() {}

    public func aspetta(_ fatto: @escaping @MainActor () -> Void) {
        if Permessi.accessibilita { fatto(); return }
        lavoro?.cancel()
        lavoro = Task { @MainActor in
            while !Permessi.accessibilita {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            diario("permesso Accessibilità dato")
            fatto()
        }
    }

    public func smetti() { lavoro?.cancel(); lavoro = nil }
}
