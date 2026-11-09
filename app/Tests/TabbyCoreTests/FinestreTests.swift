import Testing
@testable import TabbyCore

/// Prove della tappa 3: le finestre come schede.
struct FinestreTests {
    func app(_ bid: String, _ nome: String, _ f: [InfoFinestra]) -> InfoApp { InfoApp(bid: bid, nome: nome, pid: 1, finestre: f) }

    @Test func unaFinestraUnaSchedaColNomeDellApp() {
        let s = costruisciSchede([app("te", "TextEdit", [InfoFinestra(id: 5, titolo: "Lettera — TextEdit")])])
        #expect(s.map(\.chiave) == ["te"] && s[0].nome == "TextEdit" && s[0].finestra == 5)
    }

    @Test func piuFinestrePiuSchede() {
        let s = costruisciSchede([app("te", "TextEdit", [InfoFinestra(id: 9, titolo: "B — TextEdit"), InfoFinestra(id: 4, titolo: "A — TextEdit")])])
        #expect(s.map(\.chiave) == ["te", "win:9"])        // la più vecchia tiene il bundle ID
        #expect(s.map(\.nome) == ["A", "B"])
    }

    @Test func titoliUgualiNumerati() {
        let s = costruisciSchede([app("f", "Finder", [InfoFinestra(id: 1, titolo: "Download"), InfoFinestra(id: 2, titolo: "Download")])])
        #expect(s.map(\.nome) == ["Download", "Download (2)"])
    }

    @Test func unaSchedaSolaSeLAppLoChiede() {
        let s = costruisciSchede([app("w", "Windows App", [InfoFinestra(id: 1, titolo: "a"), InfoFinestra(id: 2, titolo: "b")])], separate: { _ in false })
        #expect(s.count == 1 && s[0].chiave == "w" && s[0].finestra == nil)
    }

    @Test func senzaFinestre() {
        #expect(costruisciSchede([app("x", "X", [])]).isEmpty)
        #expect(costruisciSchede([app("x", "X", [])], senzaFinestre: true).count == 1)
    }

    @Test func ridotteRestanoSchede() {
        let s = costruisciSchede([app("n", "Note", [InfoFinestra(id: 1, titolo: "Note", ridotta: true)])])
        #expect(s.count == 1 && s[0].ridotta)
    }

    @Test func nomiDatiDallUtente() {
        let s = costruisciSchede([app("m", "Mail", [InfoFinestra(id: 1, titolo: "x")])], nomi: ["m": "Posta di lavoro"])
        #expect(s[0].nome == "Posta di lavoro")
    }

    @Test func schedaAccantoASinistraOADestra() {
        #expect(schedaAccanto(chiusa: "b", prima: ["a", "b", "c"], dopo: ["a", "c"]) == "a")
        #expect(schedaAccanto(chiusa: "a", prima: ["a", "b", "c"], dopo: ["b", "c"]) == "b")
        #expect(schedaAccanto(chiusa: "c", prima: ["a", "b", "c"], dopo: []) == nil)
    }

    @Test func chiusaUnaFinestraSiRiapreLAltraDellaStessaApp() {
        // due finestre del Finder, la seconda ridotta; si chiude la prima → si va sull'altra del Finder
        let a = Scheda(chiave: "slack", bid: "slack", nome: "Slack", pid: 1)
        let f1 = Scheda(chiave: "finder", bid: "finder", nome: "A", pid: 2, finestra: 1)
        let f2 = Scheda(chiave: "win:2", bid: "finder", nome: "B", pid: 2, finestra: 2, ridotta: true)
        #expect(dopoLaChiusura(di: f1, prima: [a, f1, f2], adesso: [a, f2]) == "win:2")
        #expect(dopoLaChiusura(di: a, prima: [a, f1], adesso: [f1]) == "finder")
    }

    @Test func raccoltaInUnaCartellaNonEChiusa() {
        // uscendo dalla vista cartella Claude finisce dentro la scheda «Daily»: non è chiuso (9/11/2026)
        let claude = Scheda(chiave: "claude", bid: "claude", nome: "Claude", pid: 1, finestra: 1)
        let daily = Scheda(chiave: "f:4", bid: "claude", nome: "Daily", pid: 1)
        #expect(!èChiusa("claude", visibili: [daily], tutte: [claude]))
        #expect(èChiusa("claude", visibili: [daily], tutte: []))
        var ridotta = claude; ridotta.ridotta = true
        #expect(èChiusa("claude", visibili: [], tutte: [ridotta]))
    }

    @Test func spostareTrascinando() {
        #expect(sposta("c", davanti: "a", in: ["a", "b", "c", "x"]) == ["c", "a", "b", "x"])
        #expect(sposta("a", davanti: nil, in: ["a", "b"]) == ["b", "a"])
        #expect(sposta("a", davanti: "x", in: ["a", "b", "x"]) == ["b", "a", "x"])
    }
}
