import Foundation
import Testing
@testable import TabbyCore

/// Prove della tappa 1: diario e importazione delle impostazioni da Hammerspoon.
struct FondamentaTests {
    func cartellaProvvisoria() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("tabby-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    @Test func ilDiarioScriveLeRighe() throws {
        let file = cartellaProvvisoria().appendingPathComponent("Tabby.log")
        let d = Diario(percorso: file)
        d.scrivi("prima riga")
        d.scrivi("seconda riga")
        d.aspetta()
        let testo = try String(contentsOf: file, encoding: .utf8)
        #expect(testo.contains("Tabby · prima riga"))
        #expect(testo.contains("Tabby · seconda riga"))
    }

    @Test func ilDiarioRicominciaOltreIlLimite() throws {
        let cartella = cartellaProvvisoria()
        let file = cartella.appendingPathComponent("Tabby.log")
        let d = Diario(percorso: file, limite: 100)
        for i in 0..<10 { d.scrivi("riga numero \(i) abbastanza lunga") }
        d.aspetta()
        #expect(FileManager.default.fileExists(atPath: cartella.appendingPathComponent("Tabby.1.log").path))
        let dim = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! Int
        #expect(dim < 200)
    }

    @Test func importaUnaVoltaSolaSenzaSovrascrivere() {
        let vecchio = UserDefaults(suiteName: "tabby.test.hs.\(UUID().uuidString)")!
        vecchio.set("right", forKey: "tabbar.position")
        vecchio.set(["notion.id", "site:mail.proton.me"], forKey: "tabbar.order")
        vecchio.set([["id": 4, "name": "Lavoro"]], forKey: "tabbar.folders")
        vecchio.set("non mio", forKey: "altra.chiave")

        let nuovo = UserDefaults(suiteName: "tabby.test.app.\(UUID().uuidString)")!
        nuovo.set(true, forKey: "tabbar.fit")
        let imp = Impostazioni(archivio: nuovo)

        let n = Importazione.daHammerspoon(sorgente: vecchio, in: imp)
        #expect(n == 3)
        #expect(imp.posizione == "right")
        #expect(imp.ordine == ["notion.id", "site:mail.proton.me"])
        #expect(imp.cartelle.count == 1)
        #expect(nuovo.object(forKey: "altra.chiave") == nil)

        // La seconda volta non fa niente, anche se Hammerspoon cambia.
        vecchio.set("left", forKey: "tabbar.position")
        #expect(Importazione.daHammerspoon(sorgente: vecchio, in: imp) == 0)
        #expect(imp.posizione == "right")
    }

    @Test func valoriDiSerie() {
        let imp = Impostazioni(archivio: UserDefaults(suiteName: "tabby.test.vuoto.\(UUID().uuidString)")!)
        #expect(imp.posizione == "top")
        #expect(imp.unaAllaVolta)
        #expect(!imp.inPausa)
    }

    @Test func misuraRestituisceIlRisultato() {
        #expect(misura("somma") { 2 + 2 } == 4)
    }
}
