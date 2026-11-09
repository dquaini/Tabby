import SwiftUI

/// I colori del tema Notte · Tabby (di serie, DESIGN.md 1). Gli altri temi e l'aspetto Nativo
/// arrivano con la sezione Design.
enum Tema {
    static func c(_ hex: UInt32, _ a: Double = 1) -> Color {
        Color(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: a)
    }
    static let testo = c(0xF2EDE1)
    static let tenue = c(0xA69E8B)
    static let sopra = c(0xFFD478, 0.08)          // sotto il mouse
    static let accento = c(0xE9B44A)
    static let suAttiva = c(0x1C1505)             // testo sulla scheda attiva
    static let notifica = c(0xFF453A)
    static let verde = c(0x34C27A)
    static let rossa = c(0xFF6B5E)

    /// Lo sfondo della barra: nero caldo con un bagliore ambra dal lato del gatto.
    static func sfondo(verticale: Bool) -> some View {
        ZStack {
            LinearGradient(colors: [c(0x15120C), c(0x0A0907)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [c(0xECAC3C, 0.11), c(0xECAC3C, 0)],
                           center: verticale ? .top : .leading, startRadius: 0, endRadius: verticale ? 420 : 520)
        }
    }

    /// Il riempimento della scheda attiva: più punti di luce, come nel prototipo.
    static var riempimento: some View {
        ZStack {
            c(0xDDA23A)
            RadialGradient(colors: [c(0xEDBD52), c(0xEDBD52, 0)], center: UnitPoint(x: 0.66, y: 0.24), startRadius: 0, endRadius: 80)
            RadialGradient(colors: [c(0xB9661E), c(0xB9661E, 0)], center: .bottomTrailing, startRadius: 0, endRadius: 110)
            RadialGradient(colors: [c(0xFBE2A0, 0.85), c(0xFBE2A0, 0)], center: UnitPoint(x: 0.12, y: 0), startRadius: 0, endRadius: 60)
        }
    }

    /// Le animazioni elastiche decise (0,38 s, con un piccolo rimbalzo); con «Riduci
    /// movimento» del Mac niente rimbalzi.
    @MainActor static var molla: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72)
    }
}
