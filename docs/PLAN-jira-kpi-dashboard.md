# Piano: Dashboard KPI da Jira per progetto + team (TDD)

> Stato: **IN ATTESA DI CONFERMA** — nessun codice scritto finché il piano non è approvato.

## 1. Requisiti (riformulati)

Una dashboard che:
1. **Raccoglie** issue, sprint e storico dei cambi di stato da Jira (Cloud), filtrati per **un progetto** e **un team**.
2. **Trasforma** i dati grezzi in **KPI** di performance del team.
3. **Visualizza** i KPI con trend nel tempo (per sprint e/o per settimana) e filtri (periodo, tipo issue).
4. È sviluppata in **TDD** (Red → Green → Refactor), copertura ≥ 80% sul dominio.

### Fuori scope (v1)
- Valutazione delle performance del singolo individuo (solo team: evita metriche tossiche).
- Scrittura su Jira, multi-tenant, autenticazione SSO della dashboard.

## 2. Decisioni da confermare

| # | Decisione | Proposta (default) | Alternative |
|---|-----------|--------------------|-------------|
| D1 | Come si identifica il "team" in Jira | JQL configurabile: `project = X AND "Team[Team]" = <id>` | Board Scrum/Kanban, component, label |
| D2 | Stack | **Python 3.12**: `httpx` + `pydantic` + `pandas` + **Streamlit**, test con `pytest` | TypeScript (Node + React/Recharts, Vitest) |
| D3 | Metodo di lavoro del team | Scrum (sprint) **e** metriche flow (funzionano anche in Kanban) | Solo Kanban |
| D4 | Persistenza | SQLite locale con snapshot incrementali | Nessuna (fetch live), Postgres |
| D5 | Unità di stima | Story points (campo custom configurabile) | Conteggio issue |

## 3. KPI proposti

**Delivery (Scrum)**
- **Velocity** — SP completati per sprint (+ media mobile 3 sprint).
- **Say/Do ratio (commitment reliability)** — SP completati / SP committati a inizio sprint.
- **Scope change** — SP aggiunti/rimossi dopo l'avvio dello sprint.
- **Carry-over** — issue non completate trascinate allo sprint successivo.

**Flow (Kanban-friendly)**
- **Throughput** — issue completate per settimana.
- **Cycle time** — da primo "In Progress" a "Done" (p50 / p85 / p95).
- **Lead time** — da creazione a "Done" (p50 / p85).
- **WIP** — issue in corso per giorno (+ Cumulative Flow Diagram).
- **Flow efficiency** — tempo in stati attivi / tempo totale (stati di attesa configurabili).
- **Aging WIP** — età delle issue ancora aperte vs p85 del cycle time.

**Qualità**
- **Bug ratio** — bug creati / issue completate nel periodo.
- **Bug resolution time** — p50 per priorità.
- **Reopen rate** — % issue tornate indietro da "Done".

Mapping degli stati (`To Do` / `In Progress` / `Waiting` / `Done`) **configurabile**, perché ogni workflow Jira è diverso.

## 4. Architettura (ports & adapters)

```
config (yaml/.env) ─┐
                    ▼
JiraClient (adapter HTTP) ──► Mapper ──► Domain models ──► KPI engine (funzioni pure)
     │                                       ▲                    │
     └──────► Repository (SQLite snapshot) ──┘                    ▼
                                                        Dashboard (Streamlit)
```

```
src/jira_kpi/
  config.py              # Settings (pydantic-settings): URL, token, JQL, mapping stati, campo SP
  jira/client.py         # httpx: /rest/api/3/search/jql (paginazione nextPageToken), changelog, agile/sprint
  jira/mapper.py         # JSON Jira -> domain
  domain/models.py       # Issue, StatusTransition, Sprint, StatusCategory
  domain/timeline.py     # ricostruzione storico stati da changelog
  kpi/flow.py            # throughput, cycle/lead time, WIP, flow efficiency, aging
  kpi/scrum.py           # velocity, say/do, scope change, carry-over
  kpi/quality.py         # bug ratio, resolution time, reopen rate
  storage/repository.py  # SQLite: upsert issue, sync incrementale (updated >= last_sync)
  sync.py                # orchestrazione fetch -> map -> persist
  app/dashboard.py       # Streamlit: filtri, KPI tiles, trend chart, CFD
tests/
  fixtures/              # JSON Jira reali anonimizzati
  unit/ integration/ e2e/
```

Principio chiave: **il KPI engine non conosce Jira** — lavora su modelli di dominio immutabili, quindi è testabile al 100% senza rete.

## 5. Piano di implementazione TDD

Ogni step: **RED** (test che fallisce) → **GREEN** (codice minimo) → **REFACTOR**. Un commit per ciclo.

### Fase 0 — Setup (½ giorno)
- `pyproject.toml` (uv), `pytest`, `pytest-cov`, `ruff`, `mypy`, `respx` (mock httpx), `freezegun`.
- CI GitHub Actions: lint + typecheck + test + soglia copertura 80%.
- SessionStart hook per sessioni cloud (opzionale).

### Fase 1 — Dominio (1 giorno)
1. `StatusTransition`/`Issue` immutabili; test di validazione.
2. `timeline`: dato un changelog → intervalli per stato. Test: issue mai iniziata, riaperta, salto diretto a Done, transizioni fuori ordine.

### Fase 2 — KPI engine (2–3 giorni) — *cuore del TDD*
Test tabellari (`pytest.mark.parametrize`) con dataset costruiti a mano dal risultato noto:
1. Cycle time / lead time + percentili (lista vuota, 1 elemento, issue non chiuse escluse).
2. Throughput settimanale (settimane senza completamenti = 0, fuso orario).
3. WIP giornaliero + CFD.
4. Flow efficiency, aging WIP.
5. Velocity, say/do, scope change, carry-over (issue aggiunte a metà sprint, rimosse, split).
6. Bug ratio, resolution time, reopen rate.

### Fase 3 — Integrazione Jira (1–2 giorni)
1. `mapper`: fixture JSON → domain (campi custom mancanti, SP null).
2. `client` con `respx`: paginazione, rate-limit 429 con retry/backoff, 401 → errore chiaro, timeout.
3. Sprint API (`/rest/agile/1.0/board/{id}/sprint`) e ricostruzione del commitment iniziale dal changelog del campo Sprint.

### Fase 4 — Persistenza & sync (1 giorno)
- Repository SQLite (test su DB in-memory): upsert idempotente, sync incrementale.

### Fase 5 — Dashboard (1–2 giorni)
- Layer "view-model" puro (KPI → dati per grafico) testato in unit.
- Streamlit: selettore periodo, tile KPI con delta vs periodo precedente, trend, CFD, scatter cycle time con linee p50/p85.
- Smoke test con `streamlit.testing.AppTest`; E2E Playwright sul flusso principale.

### Fase 6 — Hardening (½ giorno)
- Security review (token solo da env, mai loggato), README, `.env.example`.

**Stima totale: ~8–10 giorni/persona.**

## 6. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| Workflow Jira non standard | KPI sbagliati | Mapping stati configurabile + test su fixture reali |
| Campo "Team"/SP sono custom field con ID diversi per istanza | Fetch vuoto | Config esplicita + comando `discover-fields` |
| Endpoint `/rest/api/3/search` deprecato | Rottura client | Usare `/search/jql` con `nextPageToken` |
| Rate limiting / grandi volumi | Sync lenta | Sync incrementale, `fields` ristretti, backoff |
| Ricostruire il commitment di sprint | Say/do impreciso | Derivarlo dal changelog del campo Sprint; testarlo con casi limite |
| Uso dei KPI per giudicare individui | Effetti culturali negativi | Solo aggregati di team; documentarlo nel README |
| Il connettore Atlassian MCP non è raggiungibile da questa sessione | Niente dati reali per i test | Sviluppo su fixture; servono URL + API token per la verifica finale |

## 7. Prossimo passo
Confermare D1–D5 (o rispondere "procedi" per i default) → si parte da Fase 0 + primo ciclo RED sul `timeline`.
