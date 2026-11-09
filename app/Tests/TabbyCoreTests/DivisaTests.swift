import Foundation
import Testing
@testable import TabbyCore

/// Prove della tappa 5: la vista divisa.
struct DivisaTests {
    func s(_ k: String, _ n: String? = nil, notifica: String? = nil) -> Scheda { Scheda(chiave: k, bid: k, nome: n ?? k, pid: 1, notifica: notifica) }

    @Test func zoneConLoSpazioInMezzo() {
        let z = zoneIn(schema("2-50"), spazio: CGRect(x: 0, y: 38, width: 1000, height: 800))
        #expect(z[0] == CGRect(x: 0, y: 38, width: 497, height: 800))
        #expect(z[1] == CGRect(x: 503, y: 38, width: 497, height: 800))
        let q = zoneIn(schema("4"), spazio: CGRect(x: 0, y: 0, width: 1000, height: 800))
        #expect(q[3] == CGRect(x: 503, y: 403, width: 497, height: 397))
    }

    @Test func creareUnaVista() {
        #expect(creaVista(id: 1, schema: "2-50", zone: ["a", nil]) == nil)            // una sola app: niente vista
        let v = creaVista(id: 1, schema: "4", zone: ["a", nil, "b", "c"])!
        #expect(v.membri == ["a", "b", "c"] && v.schema == "3")                       // lo schema si adatta
    }

    @Test func scambia() {
        #expect(ruota(VistaDivisa(id: 1, schema: "3", membri: ["a", "b", "c"])).membri == ["c", "a", "b"])
    }

    @Test func laVistaSiSciogliereOSiAdatta() {
        let v = VistaDivisa(id: 1, schema: "3", membri: ["a", "b", "c"], attenzione: "c")
        let r = aggiornaViste([v], presenti: ["a", "b"])
        #expect(r.count == 1 && r[0].schema == "2-50" && r[0].attenzione == "a")
        #expect(aggiornaViste([v], presenti: ["a"]).isEmpty)
    }

    @Test func laSchedaDellaVista() {
        let v = VistaDivisa(id: 7, schema: "2-50", membri: ["slack", "gmail"])
        let r = conViste([s("x"), s("gmail", "Gmail", notifica: "3"), s("y"), s("slack", "Slack", notifica: "2")], [v])
        #expect(r.map(\.chiave) == ["x", "g:7", "y"])
        #expect(r[1].nome == "Slack + Gmail" && r[1].notifica == "5")
    }

    @Test func salvataggio() {
        let v = VistaDivisa(id: 3, schema: "2-70", membri: ["a", "b"], attenzione: "b")
        #expect(VistaDivisa(v.dizionario) == v)
    }
}
