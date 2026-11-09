// swift-tools-version: 6.0
// Tabby, l'app per macOS (dal 9/11/2026). Si costruisce con ./costruisci.sh (crea Tabby.app).
//  - TabbyCore: il "motore" (diario, permessi, impostazioni…), senza finestre: si prova coi test.
//  - Tabby: l'app vera e propria, che usa il motore.
import PackageDescription

let package = Package(
    name: "Tabby",
    platforms: [.macOS("26.0")],          // deciso con Daniele: da macOS 26 in poi
    targets: [
        .target(name: "TabbyCore"),
        .executableTarget(name: "Tabby", dependencies: ["TabbyCore"]),
        .testTarget(name: "TabbyCoreTests", dependencies: ["TabbyCore"]),
    ]
)
