import AppKit
import Carbon.HIToolbox
import TabbyCore

/// La vista divisa nel regista di Tabby (SPECIFICA 7): dividere lo schermo, mostrare una
/// vista (ogni finestra nella sua zona), Scambia, Scomponi.
extension Controllore {
    func salvaViste() {
        imp.imposta("groups", viste.map(\.dizionario))
    }

    func scheda(_ k: String) -> Scheda? { tutte.first { $0.chiave == k } ?? stato.schede.first { $0.chiave == k } }

    func bidDi(_ v: VistaDivisa) -> Set<String> { Set(v.membri.compactMap { scheda($0)?.bid }) }

    /// Le finestre che stanno in una vista divisa (non si adattano a tutto lo spazio).
    func finestreInViste() -> Set<UInt32> { Set(viste.flatMap { $0.membri.compactMap { scheda($0)?.finestra } }) }

    // MARK: - Mostrare una vista (D-4)

    /// Ogni app nella sua zona; le altre app si nascondono. Davanti alle altre finestre si
    /// portano solo quando **scegli** la vista (altrimenti macOS lo annuncia e la vista si
    /// ridisporrebbe all'infinito).
    func mostraVista(_ v: VistaDivisa, scelta: Bool) {
        disponi(v)
        if imp.unaAllaVolta { Sistema.nascondiAltre(tranne: bidDi(v)) }
        if scelta {
            let att = v.attenzione ?? v.membri[0]
            for k in v.membri.reversed() where k != att {
                if let w = elementi[k] { AXUIElementPerformAction(w, kAXRaiseAction as CFString) }
            }
            if let s = scheda(att), let app = NSRunningApplication(processIdentifier: s.pid) {
                Sistema.portaDavanti(app, finestra: elementi[att])
            }
        }
        dopoVista?.cancel()
        let w = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.disponi(v) } }
        dopoVista = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: w)
    }

    /// Mette ogni finestra della vista nella sua zona (una già al suo posto non si tocca).
    func disponi(_ v: VistaDivisa) {
        let spazio = Sistema.dallAlto(Sistema.spazioApp(posizione: stato.posizione))
        let zone = zoneIn(schema(v.schema), spazio: spazio)
        for (i, k) in v.membri.enumerated() where i < zone.count {
            guard let s = scheda(k), let app = NSRunningApplication(processIdentifier: s.pid) else { continue }
            if app.isHidden { app.unhide() }
            guard let w = elementi[k] ?? Sistema.finestraAttiva(s.pid) else { continue }
            if (Sistema.attributo(w, kAXMinimizedAttribute) as Bool?) == true {
                AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            Sistema.adattaFinestra(w, a: Sistema.dalBasso(zone[i]))
        }
    }

    // MARK: - Scambia e Scomponi

    /// ⇄ o ⌃⌥S (D-5): le app della vista che stai guardando ruotano di una zona.
    func scambia(_ chiave: String? = nil) {
        guard let k = chiave ?? stato.attiva, let i = viste.firstIndex(where: { $0.chiave == k }) else { return }
        viste[i] = ruota(viste[i])
        salvaViste()
        ricostruisci()
        disponi(viste[i])
    }

    /// Scomponi (D-6): le schede tornano singole; si resta su quella che guardavi.
    func scomponi(_ chiave: String) {
        guard let i = viste.firstIndex(where: { $0.chiave == chiave }) else { return }
        let v = viste.remove(at: i)
        salvaViste()
        imp.imposta("order", sposta(chiave, davanti: nil, in: imp.ordine).filter { $0 != chiave })
        withAnimationMolla { ricostruisci() }
        // tutte le finestre della vista tornano a tutto spazio, subito
        if imp.adatta {
            for k in v.membri {
                if let x = scheda(k), let app = NSRunningApplication(processIdentifier: x.pid) {
                    Sistema.adatta(app, posizione: stato.posizione, tranne: finestreInViste())
                }
            }
        }
        if let s = scheda(v.attenzione ?? v.membri[0]) { vai(s) }
    }

    // MARK: - Dividere lo schermo (D-2)

    func avviaDivisione(_ schemaId: String) {
        let n = schema(schemaId).zone.count
        var zone = [String?](repeating: nil, count: n)
        if let a = stato.attiva {
            if let v = viste.first(where: { $0.chiave == a }) { for (i, k) in v.membri.prefix(n).enumerated() { zone[i] = k } }
            else if !a.hasPrefix("f:") { zone[0] = a }
        }
        stato.divisione = Divisione(schema: schemaId, zone: zone, illuminata: nil, fantasma: nil)
        velo.mostra(in: Sistema.spazioApp(posizione: stato.posizione))
        pannello.orderFrontRegardless()                               // la barra sopra il velo
        tasti.temporaneo(kVK_Escape) { [weak self] in self?.annullaDivisione() }
        tasti.temporaneo(kVK_Return) { [weak self] in self?.fineDivisione() }
        diario("dividi: \(schema(schemaId).nome)")
    }

    func annullaDivisione() { esciDivisione() }

    private func esciDivisione() {
        stato.divisione = nil
        velo.nascondi()
        tasti.togliTemporanei()
    }

    /// Clic su una scheda mentre dividi: va nella prima zona libera. Viste e cartelle no.
    func assegna(_ k: String) {
        guard var d = stato.divisione, !k.hasPrefix("g:"), !k.hasPrefix("f:") else { return }
        d.zone = d.zone.map { $0 == k ? nil : $0 }
        guard let i = d.zone.firstIndex(where: { $0 == nil }) else { return }
        d.zone[i] = k
        stato.divisione = d
        seTuttePiene()
    }

    func svuotaZona(_ i: Int) {
        guard var d = stato.divisione, i < d.zone.count else { return }
        d.zone[i] = nil
        stato.divisione = d
    }

    /// Mentre trascini una scheda dalla barra: la zona sotto il puntatore si illumina.
    func trascinaInDivisione(_ k: String, _ p: NSPoint) {
        guard var d = stato.divisione else { return }
        d.illuminata = velo.zona(a: p)
        d.fantasma = (k, velo.locale(p))
        stato.divisione = d
    }

    func lasciaInDivisione(_ k: String, _ p: NSPoint) {
        guard var d = stato.divisione else { return }
        d.illuminata = nil; d.fantasma = nil
        if let i = velo.zona(a: p), !k.hasPrefix("g:"), !k.hasPrefix("f:") {
            d.zone = d.zone.map { $0 == k ? nil : $0 }
            d.zone[i] = k
        }
        stato.divisione = d
        seTuttePiene()
    }

    /// Tutte le zone piene → la vista nasce da sola, 0,35 s dopo.
    private func seTuttePiene() {
        guard let d = stato.divisione, !d.zone.contains(where: { $0 == nil }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            MainActor.assumeIsolated { if self?.stato.divisione == d { self?.fineDivisione() } }
        }
    }

    /// Fatto (o Invio): nasce la vista con le app messe; una sola app → si va su quella.
    func fineDivisione() {
        guard let d = stato.divisione else { return }
        esciDivisione()
        let seq = (imp.valore("groupSeq") as? Int ?? 0) + 1
        guard let v = creaVista(id: seq, schema: d.schema, zone: d.zone) else {
            if let k = d.zone.compactMap({ $0 }).first, let s = scheda(k) { vai(s) }
            return
        }
        imp.imposta("groupSeq", seq)
        // una scheda sta in una vista sola: la si toglie dalle altre
        viste = viste.map { var x = $0; x.membri.removeAll { v.membri.contains($0) }; return x }.filter { $0.membri.count >= 2 }
        viste.append(v)
        salvaViste()
        // la scheda della vista prende il posto della prima app
        var o = imp.ordine.filter { $0 != v.chiave }
        o.insert(v.chiave, at: o.firstIndex(of: v.membri[0]) ?? o.count)
        imp.imposta("order", o)
        withAnimationMolla { ricostruisci() }
        segnaAttivaVista(v)
        mostraVista(v, scelta: true)
        diario("vista divisa: \(v.membri.compactMap { scheda($0)?.nome }.joined(separator: " + "))")
    }

    private func segnaAttivaVista(_ v: VistaDivisa) { withAnimationMolla { stato.attiva = v.chiave } }
}
