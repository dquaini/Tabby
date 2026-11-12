import Foundation
import Testing
@testable import TabbyCore

/// Prove del 12/11/2026: il centro di controllo (tessere, meteo, borsa, tempo d'uso).
struct CruscottoTests {
    @Test func tessereComponibili() {
        #expect(tessere(da: nil) == tessereDiSerie)
        #expect(tessere(da: ["meteo", "ora", "meteo", "nonEsiste"]) == [.meteo, .ora])
        #expect(tessere(da: []).isEmpty)                      // tutte tolte: resta vuoto
    }

    @Test func meteoDaOpenMeteo() {
        let j = #"{"current":{"temperature_2m":14.3,"weather_code":61},"daily":{"time":["2026-11-12","2026-11-13"],"temperature_2m_max":[15.1,12],"temperature_2m_min":[8,7.5],"weather_code":[61,3]}}"#
        let m = meteo(da: Data(j.utf8))
        #expect(m?.temperatura == 14.3 && m?.codice == 61 && m?.giorni.count == 2 && m?.giorni[1].massima == 12)
        #expect(descrizioneMeteo(61) == "pioggia" && descrizioneMeteo(0) == "sereno" && descrizioneMeteo(96) == "temporale")
    }

    @Test func cittàDalNome() {
        let j = #"{"results":[{"name":"Milano","latitude":45.46,"longitude":9.19}]}"#
        #expect(città(da: Data(j.utf8))?.nome == "Milano")
        #expect(città(da: Data(#"{"generationtime_ms":0.1}"#.utf8)) == nil)   // città non trovata
    }

    @Test func quotazioneDaYahoo() {
        let j = #"{"chart":{"result":[{"meta":{"symbol":"STZ","regularMarketPrice":110,"chartPreviousClose":100,"currency":"USD"}}],"error":null}}"#
        let q = quotazione(da: Data(j.utf8))
        #expect(q?.simbolo == "STZ" && q?.prezzo == 110 && q?.valuta == "USD")
        #expect(abs((q?.variazione ?? 0) - 10) < 0.001)
        #expect(quotazione(da: Data(#"{"chart":{"result":null,"error":{"code":"Not Found"}}}"#.utf8)) == nil)
    }

    @Test func titoliScrittiAMano() {
        #expect(titoli(da: "stz, dsy.pa  xyz;STZ") == ["STZ", "DSY.PA", "XYZ"])
    }

    @Test func durateInParole() {
        #expect(durata(30) == "meno di 1 min" && durata(40 * 60) == "40 min" && durata(130 * 60) == "2 h 10" && durata(120 * 60) == "2 h")
    }
}
