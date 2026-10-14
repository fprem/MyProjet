# Client Recap Tool

Version 1 of the Client Recap Tool from the one-pager: turn a client call into
a recap email the PM is happy to send, and keep a simple list of open
commitments per client. The tool never sends anything itself: it prints a
draft that the PM edits and sends from their own email.

## Install

```bash
pip install -e ".[dev]"
```

## Write notes

Plain text, one item per line. The first line without a prefix is the title.

```
Website redesign kickoff
Agreed: homepage goes live in two phases
Decision: we drop the blog section for now
Action: Maria (Acme) to send brand feedback by 2026-10-20
TODO: Fabrizio to deliver the first draft
```

Commitments read as `<owner> to|will <task> [by YYYY-MM-DD]`.

## Use

```bash
recap draft examples/acme-call.txt --client Acme --pm Fabrizio --save
recap open --client Acme
recap done 1
```

`--save` records the call's commitments in `commitments.json` (change with `--db`).

## Manual-test metrics

`recap.metrics.summarize()` takes one `CallRecord` per call from the
three-week test log and reports the one-pager's success metrics: send rate,
share of draft edited, minutes from call end to sent recap, and commitments
missed per call, each checked against its early target.

## Develop (TDD)

Tests live in `tests/` and were written before the code. Run them with:

```bash
pytest
```
