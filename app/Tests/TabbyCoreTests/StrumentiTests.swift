import Foundation
import Testing
@testable import TabbyCore

/// Prove della tappa 7: Lampi, Concentrazione, la barra che cerca tutto.
struct StrumentiTests {
    @Test func iLampiDiHammerspoon() {
        let l = Lampo(["memo": 1, "name": "Memo", "key": "m"])!
        #expect(l.memo && l.larghezza == 340)
        let c = Lampo(["bid": "notion.id", "name": "Notion · cerca", "key": "n", "menubar": 1, "menuItem": "Toggle Command Search"])!
        #expect(c.barraMenu && c.voceMenu == "Toggle Command Search")
        #expect(Lampo(c.dizionario) == c)
    }

    @Test func letteraLiberaDalNome() {
        #expect(letteraLibera(per: "Note", usate: ["m", "c"]) == "n")
        #expect(letteraLibera(per: "Safari", usate: ["a"]) == "r")              // s è di Tabby, a è usata
        #expect(letteraLibera(per: "Èèè", usate: ["e"]) == "a")
    }

    @Test func inFilaInAltoADestra() {
        let r = CGRect(x: 0, y: 38, width: 1000, height: 600)
        let f = inFila([CGSize(width: 340, height: 280), CGSize(width: 230, height: 280), CGSize(width: 300, height: 300)], spazio: r)
        #expect(f[0] == CGRect(x: 648, y: 50, width: 340, height: 280))
        #expect(f[1] == CGRect(x: 758, y: 342, width: 230, height: 280))           // sotto
        #expect(f[2] == CGRect(x: 336, y: 50, width: 300, height: 300))             // colonna a sinistra
        #expect(inFila([CGSize(width: 2000, height: 100)], spazio: r)[0] == nil)    // non c'è posto
    }

    @Test func tempoDellaConcentrazione() {
        #expect(tempoCheManca(24 * 60) == "24 min")
        #expect(tempoCheManca(23 * 60 + 1) == "24 min")
        #expect(tempoCheManca(45) == "0:45")
        #expect(tempoCheManca(-3) == "0:00")
    }

    @Test func notificheArrivate() {
        let r = arrivateNelFrattempo(inizio: ["Slack": 2, "Gmail": 5], fine: ["Slack": 6, "Gmail": 5, "Notion": 1])
        #expect(r.map(\.nome) == ["Slack", "Notion"] && r[0].quante == 4)
    }

    @Test func cercaTuttoSenzaAccenti() {
        let tutto = [
            Trovato(id: "1", gruppo: .schede, titolo: "Gmail", sotto: "DuckDuckGo"),
            Trovato(id: "2", gruppo: .finestre, titolo: "Contratto", sotto: "Anteprima", testo: "Il motivo è perché il prezzo è alto"),
            Trovato(id: "3", gruppo: .azioni, titolo: "Concentrazione", sotto: "25 · 50 · 90 min"),
            Trovato(id: "4", gruppo: .impostazioni, titolo: "Posizione", sotto: "Dove sta Tabby"),
        ]
        #expect(cerca("", in: tutto).migliore == nil)
        #expect(cerca("gma", in: tutto).migliore?.id == "1")
        let p = cerca("perche prezzo", in: tutto)
        #expect(p.migliore?.id == "2" && p.migliore?.pezzetto?.contains("perché") == true)
        #expect(cerca("conc", in: tutto).migliore?.t.gruppo == .azioni)
        #expect(cerca("xyz", in: tutto).migliore == nil)
    }

    @Test func alMassimoTrePerGruppoEOttoInTutto() {
        let tante = (0..<20).map { Trovato(id: "\($0)", gruppo: Trovato.Gruppo(rawValue: $0 % 6)!, titolo: "Cosa \($0)") }
        let r = cerca("cosa", in: tante)
        #expect(r.gruppi.allSatisfy { $0.1.count <= 3 })
        #expect(r.gruppi.reduce(1) { $0 + $1.1.count } <= 8)
    }
}

/// Prove del 10/11/2026: la ricerca web della barra di Tabby.
struct RicercaWebTests {
    @Test func unServizioConosciuto() {
        #expect(proposteWeb("proton").first == .sito(nome: "Proton Mail", indirizzo: "https://mail.proton.me/", dominio: "mail.proton.me"))
        #expect(proposteWeb("Gmail").first == .sito(nome: "Gmail", indirizzo: "https://mail.google.com/", dominio: "mail.google.com"))
    }
    @Test func unIndirizzo() {
        #expect(proposteWeb("raycast.com").first == .sito(nome: "raycast.com", indirizzo: "https://raycast.com", dominio: "raycast.com"))
    }
    @Test func sempreLaRicercaPerUltima() {
        let p = proposteWeb("raycast è open source")
        #expect(p.count == 1)
        #expect(p.last == .ricerca(testo: "raycast è open source", indirizzo: "https://duckduckgo.com/?q=raycast%20%C3%A8%20open%20source"))
        #expect(proposteWeb("  ").isEmpty)
    }
    @Test func paroleCorteNonSonoServizi() {
        #expect(proposteWeb("pr").count == 1)            // solo la ricerca
        #expect(proposteWeb("3.5").count == 1)           // un numero non è un indirizzo
    }
}
