import Foundation
import Testing
@testable import TabbyCore

/// Prove della tappa 4: i browser.
struct BrowserTests {
    @Test func dominiESiti() {
        #expect(dominio("https://www.YouTube.com/watch?v=1") == "youtube.com")
        #expect(dominio("about:blank") == nil)
        #expect(sitoDi(["https://mail.google.com/a", "https://mail.google.com/b"]) == "mail.google.com")
        #expect(sitoDi(["https://mail.google.com/a", "https://notion.so"]) == nil)
        #expect(soloSito("notion.so/pagina-segreta?token=x") == "https://notion.so/")
    }

    @Test func nomiDeiSiti() {
        #expect(nomeSito(titolo: "Posta in arrivo (3) - io@x.it - Gmail", dominio: "mail.google.com") == "Gmail")
        #expect(nomeSito(titolo: "Inbox | Proton Mail", dominio: "mail.proton.me") == "Proton Mail")
        #expect(nomeSito(titolo: "Meet - abc-defg-hij", dominio: "meet.google.com") == "Meet")
        #expect(nomeSito(titolo: "Una pagina qualsiasi", dominio: "youtube.com") == "YouTube")
        #expect(nomeSito(titolo: "(2) Home / X", dominio: "x.com") == "X")
    }

    @Test func notificheNelTitolo() {
        #expect(notificaDalTitolo("(3) WhatsApp") == "3")
        #expect(notificaDalTitolo("Posta (12) - io@x - Gmail") == "12")
        #expect(notificaDalTitolo("Gmail") == nil)
    }

    @Test func rispostaDelBrowser() {
        let r = leggiRisposta("Gmail\tid7\t0,38,1440,900\thttps://mail.google.com/a\t\nNuova\tid?\t-\tabout:blank\t\n")
        #expect(r.count == 2)
        #expect(r[0].numero == 7 && r[0].urls == ["https://mail.google.com/a"])
        #expect(r[0].cornice == CGRect(x: 0, y: 38, width: 1440, height: 862))
        #expect(r[1].numero == nil && r[1].cornice == nil)
    }

    @Test func abbinamento() {
        let c = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let schermo = [FinestraSchermo(id: 1, titolo: "Gmail - Lavoro", cornice: c, piccola: false),
                       FinestraSchermo(id: 2, titolo: "Notion", cornice: c, piccola: false)]
        let browser = [FinestraBrowser(nome: "Notion", numero: 5, cornice: c, urls: ["https://notion.so"]),
                       FinestraBrowser(nome: "Gmail", numero: 9, cornice: c, urls: ["https://mail.google.com"])]
        let r = abbina(schermo, browser, memoria: [:])
        #expect(r.trovate[1] == 1 && r.trovate[2] == 0)
        #expect(r.memoria[1] == 9 && r.memoria[2] == 5)
        // due «Meet» uguali: vince il numero ricordato
        let due = [FinestraSchermo(id: 1, titolo: "Meet", cornice: c, piccola: false), FinestraSchermo(id: 2, titolo: "Meet", cornice: c, piccola: false)]
        let b2 = [FinestraBrowser(nome: "Meet", numero: 20, cornice: c, urls: []), FinestraBrowser(nome: "Meet", numero: 10, cornice: c, urls: [])]
        #expect(abbina(due, b2, memoria: [1: 10, 2: 20]).trovate == [1: 1, 2: 0])
    }

    @Test func schedeDiBrowser() {
        let a = InfoApp(bid: "chrome", nome: "Google Chrome", pid: 1, finestre: [
            InfoFinestra(id: 1, titolo: "(2) Posta - io@x - Gmail", sito: "mail.google.com", titoloBrowser: "(2) Posta - io@x - Gmail"),
            InfoFinestra(id: 2, titolo: "Ricerca - Google Chrome", titoloBrowser: "Ricerca"),
            InfoFinestra(id: 3, titolo: "Altro - Google Chrome", titoloBrowser: "Altro"),
        ], breve: "Chrome")
        let s = costruisciSchede([a], separate: { _ in false })     // i browser sono sempre separati
        #expect(s.map(\.chiave) == ["site:mail.google.com", "chrome", "win:3"])
        #expect(s.map(\.nome) == ["Gmail", "Ricerca", "Altro"])
        #expect(s[0].notifica == "2" && s[0].sito == "mail.google.com")
    }

    @Test func stessoSitoInDueFinestre() {
        let a = InfoApp(bid: "chrome", nome: "Chrome", pid: 1, finestre: [
            InfoFinestra(id: 1, titolo: "Gmail", sito: "mail.google.com"), InfoFinestra(id: 2, titolo: "Gmail", sito: "mail.google.com")], breve: "Chrome")
        #expect(costruisciSchede([a]).map(\.chiave) == ["site:mail.google.com", "win:2"])
    }

    @Test func unaSolaFinestraNormaleColNomeBreve() {
        let a = InfoApp(bid: "ddg", nome: "DuckDuckGo", pid: 1, finestre: [InfoFinestra(id: 1, titolo: "Qualcosa")], breve: "DuckDuckGo")
        let s = costruisciSchede([a])
        #expect(s.map(\.chiave) == ["ddg"] && s[0].nome == "DuckDuckGo")
    }
}

/// Prove del 10/11/2026: il nome del servizio, mai l'indirizzo email.
struct NomeServizioTests {
    @Test func servizioConosciuto() {
        #expect(nomeSito(titolo: "Posta in arrivo | daniele@proton.me", dominio: "mail.proton.me") == "Proton Mail")
    }
    @Test func maiUnaMail() {
        #expect(nomeSito(titolo: "Posta in arrivo | io@esempio.it", dominio: "posta.esempio.it") == "Esempio")
    }
}
