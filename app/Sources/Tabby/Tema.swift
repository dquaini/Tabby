import AppKit
import Observation
import SwiftUI
import TabbyCore

/// L'aspetto scelto (DESIGN.md 1): **Nativo** (come macOS, col colore principale del Mac) o
/// **Notte** con sei temi — base: Grafite, Mono, Fumo; Tabby: Tabby (di serie), Tramonto, Aurora.
@MainActor @Observable
final class Aspetto {
    static let shared = Aspetto()
    var nativo = (Impostazioni.shared.valore("aspetto") as? String) == "Nativo"
    var tema = Impostazioni.shared.valore("tema") as? String ?? "Tabby"

    static let temi = ["Grafite", "Mono", "Fumo", "Tabby", "Tramonto", "Aurora"]

    func scegli(nativo n: Bool? = nil, tema t: String? = nil) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let n { nativo = n; Impostazioni.shared.imposta("aspetto", n ? "Nativo" : "Notte") }
            if let t { tema = t; Impostazioni.shared.imposta("tema", t) }
        }
    }
}

/// Una tavolozza: i colori di un tema.
struct Tavolozza {
    var accento: UInt32
    var testo: UInt32 = 0xF2EDE1
    var tenue: UInt32 = 0xA69E8B
    var sopra: (UInt32, Double) = (0xFFD478, 0.08)
    var suAttiva: UInt32 = 0x1C1505
    var fondo: (UInt32, UInt32) = (0x000000, 0x000000)
    var bagliore: UInt32? = nil
    var riempimento: [UInt32]? = nil          // più punti di luce (temi «Tabby»); nil = tinta piena
    var sfera: [UInt32]                        // i colori dentro la sfera (3.8)
}

enum Tema {
    static let tavolozze: [String: Tavolozza] = [
        "Tabby": .init(accento: 0xE9B44A, fondo: (0x15120C, 0x0A0907), bagliore: 0xECAC3C,
                       riempimento: [0xDDA23A, 0xEDBD52, 0xB9661E, 0xFBE2A0], sfera: [0xE9B44A, 0xC9702A, 0xF6D58A, 0x8A4A1C, 0x3A2A12]),
        "Tramonto": .init(accento: 0xEE7470, tenue: 0xA8918E, sopra: (0xFF9A90, 0.08), suAttiva: 0x2A0B0A, fondo: (0x170E0D, 0x0A0606), bagliore: 0xEE7470,
                          riempimento: [0xE5615C, 0xF2A541, 0xB04A7A, 0xFFC8BE], sfera: [0xEE7470, 0xF2A541, 0xB04A7A, 0xFFC2A8, 0x3A1620]),
        "Aurora": .init(accento: 0x4CCBB4, tenue: 0x8EA8A2, sopra: (0x9BF0C8, 0.07), suAttiva: 0x062420, fondo: (0x0B1513, 0x060A09), bagliore: 0x4CCBB4,
                        riempimento: [0x3FB9A3, 0x7FE0C8, 0x2A7FD0, 0xBEFFEB], sfera: [0x4CCBB4, 0x3E86FF, 0x9BF0C8, 0x1E6A7A, 0x0E2A30]),
        "Grafite": .init(accento: 0x4C8DFF, testo: 0xECEDF0, tenue: 0x9A9EA8, sopra: (0xFFFFFF, 0.07), suAttiva: 0xFFFFFF,
                         sfera: [0x4C8DFF, 0x6F7BFF, 0x9CC2FF, 0x24408A, 0x121C38]),
        "Mono": .init(accento: 0xEDEDED, testo: 0xF2F2F2, tenue: 0x9A9A9A, sopra: (0xFFFFFF, 0.07), suAttiva: 0x0E0E0E,
                      sfera: [0xEDEDED, 0x9A9A9A, 0xC8C8C8, 0x5A5A5A, 0x1A1A1A]),
        "Fumo": .init(accento: 0xA894F5, testo: 0xEEEBFA, tenue: 0x9D98B0, sopra: (0xC8B8FF, 0.08), suAttiva: 0x140D2E,
                      sfera: [0xA894F5, 0x6F7BFF, 0xD7CCFF, 0x4A3A8A, 0x1A1430]),
    ]

    @MainActor static var t: Tavolozza { tavolozze[Aspetto.shared.tema] ?? tavolozze["Tabby"]! }
    @MainActor static var nativo: Bool { Aspetto.shared.nativo }

    static func c(_ hex: UInt32, _ a: Double = 1) -> Color {
        Color(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: a)
    }

    // I colori della barra: in Nativo quelli di macOS (chiari o scuri come il Mac).
    @MainActor static var testo: Color { nativo ? .primary : c(t.testo) }
    @MainActor static var tenue: Color { nativo ? .secondary : c(t.tenue) }
    @MainActor static var sopra: Color { nativo ? Color.primary.opacity(0.07) : c(t.sopra.0, t.sopra.1) }
    @MainActor static var accento: Color { nativo ? .accentColor : c(t.accento) }
    @MainActor static var suAttiva: Color { nativo ? .primary : c(t.suAttiva) }
    static let notifica = c(0xFF453A)
    static let verde = c(0x34C27A)
    static let rossa = c(0xFF6B5E)

    /// Lo sfondo della barra.
    @MainActor static func sfondo(verticale: Bool) -> some View {
        ZStack {
            if nativo {
                Rectangle().fill(.bar)
            } else {
                LinearGradient(colors: [c(t.fondo.0), c(t.fondo.1)], startPoint: .top, endPoint: .bottom)
                if let b = t.bagliore {
                    RadialGradient(colors: [c(b, 0.11), c(b, 0)], center: verticale ? .top : .leading,
                                   startRadius: 0, endRadius: verticale ? 420 : 520)
                }
            }
        }
    }

    /// Il riempimento della scheda attiva: più punti di luce nei temi Tabby, tinta piena nei temi base,
    /// in Nativo come un controllo di macOS.
    @MainActor static var riempimento: some View {
        ZStack {
            if nativo {
                Rectangle().fill(.background).opacity(0.9)
            } else if let r = t.riempimento {
                c(r[0])
                RadialGradient(colors: [c(r[1]), c(r[1], 0)], center: UnitPoint(x: 0.66, y: 0.24), startRadius: 0, endRadius: 80)
                RadialGradient(colors: [c(r[2]), c(r[2], 0)], center: .bottomTrailing, startRadius: 0, endRadius: 110)
                RadialGradient(colors: [c(r[3], 0.85), c(r[3], 0)], center: UnitPoint(x: 0.12, y: 0), startRadius: 0, endRadius: 60)
            } else {
                c(t.accento)
            }
        }
    }

    /// L'ombra della scheda attiva.
    @MainActor static var ombraAttiva: Color { nativo ? .black.opacity(0.15) : (t.riempimento != nil ? c(t.accento, 0.22) : .clear) }

    /// Le animazioni elastiche decise (0,38 s, con un piccolo rimbalzo); con «Riduci
    /// movimento» del Mac niente rimbalzi.
    @MainActor static var molla: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72)
    }
}
