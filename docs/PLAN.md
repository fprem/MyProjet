# Piano: agente per riconoscere file generati da AI

Ultimo aggiornamento: 2026-11-09

## Obiettivo

Un agente che, dato un file (testo, codice o immagine), stima se è stato
generato da un'AI e restituisce:

- un **punteggio** da 0 a 1 (0 = quasi certamente umano, 1 = quasi certamente AI);
- una **motivazione** leggibile: gli indizi trovati, ciascuno con il suo peso;
- un livello di **confidenza**, perché per molti file la risposta onesta è
  "non si può dire".

Il risultato è una stima, mai una prova: l'agente lo dice sempre nell'output.

## Stato attuale del repository

Il repository `fprem/MyProjet` oggi non contiene ancora nulla dell'agente.
Contiene due progetti precedenti, non collegati all'obiettivo:

| Progetto | Dove | Stato |
| --- | --- | --- |
| Client Recap Tool (Python, Flask, Claude) | `src/recap/`, `tests/` | v1 unita il 14/10 (PR #1) |
| Medicine Archive (app Android in Flutter) | `medicine_archive/` | unita il 2/11 (PR #2 e #3) |

Medicine Archive non ha legami con il riconoscimento di contenuti AI e resta
com'è. Del Client Recap Tool riusiamo solo l'impostazione: pacchetto Python in
`src/`, test con `pytest`, CI già attiva in `.github/workflows/tests.yml`, e il
modo di chiamare Claude con output strutturato (`recap/ai_extractor.py`) e un
client finto nei test.

## Regole di lavoro

- **TDD**: prima i test che falliscono (commit separato), poi l'implementazione
  minima che li fa passare, poi il refactoring.
- **Ogni modifica passa da una PR in bozza** su `fprem/MyProjet`, con test verdi
  in CI prima di chiederne la revisione.
- **Questo piano si aggiorna** nella stessa PR che cambia una fase o prende una
  decisione. `tests/test_plan_doc.py` controlla che le sezioni ci siano.

## Fasi

### Fase 0: piano e impostazione

Stato: in corso (questa PR)

- Scrivere questo piano e un test che ne verifica la struttura.

### Fase 1: nucleo e contratto di output

Stato: da fare

- Pacchetto `src/aidetect/` con il tipo `Verdict` (punteggio, confidenza,
  lista di `Evidence` con descrizione e peso) e il riconoscimento del tipo di
  file (testo, codice, immagine, non supportato).
- Interfaccia comune `Detector`: ogni rilevatore riceve il file e restituisce
  indizi; un aggregatore li combina in un unico `Verdict`.
- CLI `aidetect <file> [--json]` che stampa punteggio e motivazione.
- Test: file non supportati, file vuoti, file enormi (limite di dimensione),
  formato JSON stabile.

### Fase 2: testo

Stato: da fare

- Euristiche locali, senza rete: varietà del lessico, uniformità della
  lunghezza delle frasi ("burstiness"), frasi tipiche dei modelli, punteggiatura.
- Giudizio di Claude con output strutturato (punteggio e motivi), con client
  finto nei test e ripiego sulle sole euristiche se la chiave manca.
- Piccolo set di esempi etichettati in `tests/fixtures/` per misurare
  l'accuratezza.

### Fase 3: codice

Stato: da fare

- Indizi specifici del codice: densità e stile dei commenti, nomi generici,
  struttura troppo regolare, commenti che spiegano l'ovvio, marcatori lasciati
  dagli assistenti.
- Stesso giudizio di Claude della fase 2, con un prompt dedicato al codice.

### Fase 4: immagini

Stato: da fare

- Metadati: EXIF della fotocamera, credenziali di contenuto C2PA, tag di
  software di generazione noti.
- Giudizio visivo di Claude sull'immagine (artefatti, mani, testo, luci).
- Un'immagine senza metadati non è per questo AI: abbassa la confidenza, non
  alza il punteggio.

### Fase 5: agente e valutazione

Stato: da fare

- L'agente decide quali rilevatori usare per il file e spiega come ha pesato
  gli indizi.
- Script di valutazione sul set etichettato (accuratezza, falsi positivi) da
  far girare prima di ogni cambio dei pesi.
- Eventuale interfaccia web, sul modello di `recap-web`.

## Decisioni prese

| Data | Decisione | Perché |
| --- | --- | --- |
| 2026-11-09 | Lavoro in TDD, ogni modifica in una PR in bozza con test verdi | Regola del progetto |
| 2026-11-09 | Il piano vive in `docs/PLAN.md`, in italiano, ed è controllato da un test | Regola del progetto |
| 2026-11-09 | L'agente nasce in Python in `src/aidetect/`, accanto a `src/recap/`, nello stesso `pyproject.toml` e nella stessa CI | Riusa strumenti e CI già funzionanti |
| 2026-11-09 | Medicine Archive e Client Recap Tool non si toccano | Non sono legati all'obiettivo |
| 2026-11-09 | Output: punteggio 0..1, confidenza e motivazione con indizi pesati | Una sola cifra senza motivi non è utile né verificabile |
| 2026-11-09 | Euristiche locali sempre attive; Claude come secondo parere, sostituibile da un client finto nei test | I test restano veloci e senza rete, e l'agente funziona anche senza chiave |

## Domande aperte

- Il progetto resta in questo repository o merita un repository suo? Oggi
  qui convivono tre progetti diversi.
- Quali formati servono per primi? Proposta: `.txt`/`.md`, i sorgenti più
  comuni (`.py`, `.js`, `.ts`, `.java`) e `.jpg`/`.png`.
- Si possono inviare i file a Claude (API Anthropic) o serve una modalità solo
  locale per file riservati?
- Da dove prendiamo gli esempi etichettati (umano/AI) per misurare l'accuratezza?
