# Client Recap Tool

Version 1 of the Client Recap Tool from the one-pager: turn a client call into
a recap email the PM is happy to send, and keep a simple list of open
commitments per client. The tool never sends anything itself: it prints a
draft that the PM edits and sends from their own email.

## Install

```bash
pip install -e ".[dev]"
```

## Web page

```bash
recap-web            # then open http://127.0.0.1:5000
```

Paste your notes, fill in client and your name, and get the recap email to
edit and copy. The commitments go to the **Open commitments** page, where you
can filter by client and mark items done.

## AI drafting

Tick **Use AI drafting** on the web page (or pass `--ai` to `recap draft`) to
paste free-form notes or a transcript. Claude (`claude-opus-5-5`) reads the
notes and returns agreements, decisions and commitments as structured data,
resolving dates like "Friday" against the call date; the email is still built
from the same template, and it is never sent for you.

Set `ANTHROPIC_API_KEY` first. If the key is missing or the call fails, the app
says so and falls back to the prefix rules below.

## Write notes (without AI)

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
recap draft my-notes.txt --client Acme --pm Fabrizio --ai
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
