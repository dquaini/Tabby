import Testing
@testable import TabbyCore

/// Prove della tappa 6: le cartelle.
struct CartelleTests {
    func s(_ k: String, _ bid: String, sito: String? = nil, fin: UInt32? = nil, titolo: String? = nil, url: [String]? = nil, notifica: String? = nil) -> Scheda {
        var x = Scheda(chiave: k, bid: bid, nome: k, pid: 1, finestra: fin, sito: sito, notifica: notifica)
        x.titolo = titolo; x.indirizzi = url
        return x
    }

    @Test func laTuaCartellaDiHammerspoon() {
        let d: [String: Any] = ["id": 4, "name": "Daily", "items": [
            ["bid": "com.anthropic.claudefordesktop", "name": "Claude", "title": "Claude", "win": 1],
            ["bid": "com.duckduckgo.macos.browser", "name": "Proton Mail", "site": "mail.proton.me"]]]
        let c = Cartella(d)!
        #expect(c.nome == "Daily" && c.voci.count == 2)
        #expect(c.voci[0].chiave == "finestra:com.anthropic.claudefordesktop:Claude:nil")
        #expect(c.voci[1].chiave == "site:mail.proton.me")
        #expect(Cartella(c.dizionario) == c)
    }

    @Test func corrispondenze() {
        #expect(corrisponde(Voce(bid: "ddg", nome: "", sito: "mail.proton.me"), s("site:mail.proton.me", "ddg", sito: "mail.proton.me")))
        #expect(!corrisponde(Voce(bid: "chrome", nome: ""), s("site:x.com", "chrome", sito: "x.com")))   // app ≠ webapp
        let pag = Voce(bid: "chrome", nome: "", pagine: ["https://notion.so/a", "https://linear.app/b"])
        #expect(corrisponde(pag, s("win:3", "chrome", fin: 3, url: ["https://notion.so/z", "https://google.com"])))
        #expect(!corrisponde(pag, s("win:3", "chrome", fin: 3, url: ["https://x.com", "https://google.com", "https://notion.so"])))
        #expect(corrisponde(Voce(bid: "f", nome: "", finestra: true, titolo: "Download"), s("win:2", "f", fin: 2, titolo: "Download")))
    }

    @Test func ogniVoceUnaSchedaSola() {
        let c = Cartella(id: 1, nome: "Lavoro", voci: [Voce(bid: "chrome", nome: "", sito: "mail.google.com")])
        let sch = [s("site:mail.google.com", "chrome", sito: "mail.google.com", fin: 1), s("win:2", "chrome", sito: "mail.google.com", fin: 2)]
        let r = assegna([c], schede: sch, legami: [:])
        #expect(r.diChi == ["site:mail.google.com": 1])
        #expect(r.legami["1|site:mail.google.com"] == 1)
        // la finestra legata vince anche se non è la prima
        #expect(assegna([c], schede: sch, legami: ["1|site:mail.google.com": 2]).diChi == ["win:2": 1])
    }

    @Test func unaVoceInUnaCartellaSola() {
        let a = Cartella(id: 1, nome: "A", voci: [Voce(bid: "x", nome: "X"), Voce(bid: "y", nome: "Y")])
        let b = Cartella(id: 2, nome: "B", voci: [Voce(bid: "x", nome: "X")])
        let r = salva(Cartella(id: 3, nome: "C", voci: [Voce(bid: "x", nome: "X")]), in: [a, b])
        #expect(r.map(\.id) == [1, 3])            // B è rimasta vuota: si cancella
        #expect(r[0].voci.map(\.bid) == ["y"])
    }

    @Test func vociDalleSchede() {
        #expect(voce(da: s("site:a.com", "c", sito: "a.com"), browser: true, breve: "Chrome", variePerApp: false).sito == "a.com")
        let p = voce(da: s("c", "c", fin: 1, titolo: "Lavoro", url: ["https://a.com/x?token=1", "https://b.com"]), browser: true, breve: "Chrome", variePerApp: false)
        #expect(p.pagine == ["https://a.com/x", "https://b.com"] && p.nome == "Lavoro · 2 pagine")
        #expect(voce(da: s("f", "f", fin: 1, titolo: "Download"), browser: false, breve: nil, variePerApp: true).finestra)
        #expect(!voce(da: s("n", "n", fin: 1), browser: false, breve: nil, variePerApp: false).finestra)
    }

    @Test func laSchedaCartella() {
        let c = Cartella(id: 4, nome: "Daily", voci: [])
        let sch = [s("a", "a"), s("b", "b", notifica: "2"), s("c", "c", notifica: "1")]
        let diChi = ["b": 4, "c": 4]
        #expect(conCartelle(sch, cartelle: [c], diChi: diChi, vistaCartelle: true, aperta: nil).map(\.chiave) == ["a", "f:4"])
        #expect(conCartelle(sch, cartelle: [c], diChi: diChi, vistaCartelle: true, aperta: nil)[1].notifica == "3")
        #expect(conCartelle(sch, cartelle: [c], diChi: diChi, vistaCartelle: false, aperta: nil).count == 3)
        #expect(conCartelle(sch, cartelle: [c], diChi: diChi, vistaCartelle: true, aperta: 4).map(\.chiave) == ["b", "c"])
    }
}
