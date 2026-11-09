import Testing
@testable import TabbyCore

/// Prove della tappa 2: ordine delle schede, nomi, misure della barra, batteria.
struct BarraTests {
    func s(_ k: String, _ bid: String? = nil) -> Scheda { Scheda(chiave: k, bid: bid ?? k, nome: k, pid: 1) }

    @Test func seguonoLOrdineRicordato() {
        let r = ordina([s("c"), s("a"), s("b")], ordine: ["a", "b", "c"], preferite: [])
        #expect(r.schede.map(\.chiave) == ["a", "b", "c"])
    }

    @Test func leNuoveVannoInFondo() {
        let r = ordina([s("a"), s("nuova"), s("b")], ordine: ["a", "b"], preferite: [])
        #expect(r.schede.map(\.chiave) == ["a", "b", "nuova"])
        #expect(r.ordine == ["a", "b", "nuova"])
    }

    @Test func lePreferiteNuoveVannoInCimaNelLoroOrdine() {
        let r = ordina([s("x"), s("p2"), s("p1")], ordine: ["x"], preferite: ["p1", "p2"])
        #expect(r.schede.map(\.chiave) == ["p1", "p2", "x"])
    }

    @Test func unaFinestraNuovaStaVicinoAllaSuaApp() {
        let r = ordina([s("chrome", "chrome"), s("slack"), s("win:9", "chrome")],
                       ordine: ["chrome", "slack"], preferite: [])
        #expect(r.schede.map(\.chiave) == ["chrome", "win:9", "slack"])
    }

    @Test func siRicordanoAncheLeSchedeChiuse() {
        let r = ordina([s("a")], ordine: ["a", "chiusa", "win:3"], preferite: [])
        #expect(r.ordine == ["a", "chiusa"])     // le finestre chiuse si dimenticano, le app no
    }

    @Test func nomiDelleFinestre() {
        #expect(nomeFinestra(titolo: "Relazione — TextEdit", app: "TextEdit") == "Relazione")
        #expect(nomeFinestra(titolo: "TextEdit", app: "TextEdit") == "TextEdit")
        #expect(nomeFinestra(titolo: "", app: "Note") == "Note")
        #expect(nomeFinestra(titolo: "Inbox | Proton", app: "Proton") == "Inbox")
    }

    @Test func pocheSchedeLarghe() {
        let d = disponiOrizzontale(spazio: 1000, numero: 3, attiva: 0)
        #expect(d.larghezza == 190 && !d.compatta && d.altre == 0)
    }

    @Test func tanteSchedeCompatte() {
        let d = disponiOrizzontale(spazio: 600, numero: 10, attiva: 2)
        #expect(d.compatta && d.altre == 0 && d.visibili.count == 10)
    }

    @Test func troppeSchedeConPiuN() {
        let d = disponiOrizzontale(spazio: 400, numero: 30, attiva: 25)
        #expect(d.compatta && d.altre > 0)
        #expect(d.visibili.contains(25))                 // l'attiva resta visibile
        #expect(d.visibili.count + d.altre == 30)
    }

    @Test func diLato() {
        #expect(disponiVerticale(spazio: 600, numero: 5, attiva: nil).riga == 32)
        let v = disponiVerticale(spazio: 300, numero: 40, attiva: 39)
        #expect(v.altre > 0 && v.visibili.contains(39))
    }

    @Test func coloriDellaBatteria() {
        #expect(coloreBatteria(livello: 90, inCarica: false) == .verde)
        #expect(coloreBatteria(livello: 20, inCarica: false) == .rossa)
        #expect(coloreBatteria(livello: 20, inCarica: true) == .normale)
        #expect(coloreBatteria(livello: 50, inCarica: false) == .normale)
    }
}
