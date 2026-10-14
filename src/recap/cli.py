"""Command line: draft a recap, list open commitments, mark one done."""

from __future__ import annotations

import argparse
import sys
from datetime import date

from recap.drafting import build_meeting
from recap.recap_email import draft_recap
from recap.store import CommitmentStore


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="recap", description=__doc__)
    parser.add_argument("--db", default="commitments.json", help="commitments file (default: %(default)s)")
    sub = parser.add_subparsers(dest="command", required=True)

    draft = sub.add_parser("draft", help="draft a recap email from meeting notes")
    draft.add_argument("notes", help="notes file, or - for stdin")
    draft.add_argument("--client", required=True)
    draft.add_argument("--pm", required=True, help="your name, used to sign the email")
    draft.add_argument("--date", type=date.fromisoformat, default=None, help="call date, YYYY-MM-DD (default: today)")
    draft.add_argument("--save", action="store_true", help="record the commitments as open")
    draft.add_argument("--ai", action="store_true", help="extract items from free-form notes with Claude")

    open_ = sub.add_parser("open", help="list open commitments")
    open_.add_argument("--client")

    done = sub.add_parser("done", help="mark a commitment as done")
    done.add_argument("id", type=int)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    store = CommitmentStore(args.db)

    if args.command == "draft":
        text = sys.stdin.read() if args.notes == "-" else open(args.notes, encoding="utf-8").read()
        call_date = args.date or date.today()
        meeting, notice = build_meeting(text, call_date=call_date, use_ai=args.ai)
        if notice:
            print(notice, file=sys.stderr)
        print(draft_recap(meeting, client=args.client, pm_name=args.pm, call_date=call_date).as_text())
        if args.save:
            store.add(args.client, meeting.commitments, call_date=call_date)
        return 0

    if args.command == "open":
        items = store.open_commitments(client=args.client)
        if not items:
            print("No open commitments.")
        for c in items:
            due = c.due.isoformat() if c.due else "no date"
            print(f"#{c.id}  [{c.client}]  {c.owner or 'unassigned'}: {c.task}  (due {due})")
        return 0

    try:
        store.mark_done(args.id)
    except KeyError:
        print(f"No commitment with id {args.id}.", file=sys.stderr)
        return 1
    print(f"Marked #{args.id} as done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
