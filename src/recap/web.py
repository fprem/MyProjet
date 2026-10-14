"""A small web page: paste notes, get a recap email to copy, track commitments."""

from __future__ import annotations

from datetime import date
from pathlib import Path

from flask import Flask, abort, redirect, render_template_string, request, url_for

from recap.drafting import Extractor, build_meeting
from recap.recap_email import draft_recap
from recap.store import CommitmentStore

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Client Recap</title>
<style>
  :root { --fg:#1d1d1f; --muted:#6e6e73; --bg:#fafafa; --card:#fff; --line:#e3e3e8; --accent:#2f5bea; }
  * { box-sizing: border-box; }
  body { margin:0; font:16px/1.5 system-ui, sans-serif; color:var(--fg); background:var(--bg); }
  main { max-width:760px; margin:0 auto; padding:24px 16px 48px; }
  nav a { margin-right:16px; color:var(--accent); text-decoration:none; }
  h1 { font-size:1.5rem; margin:16px 0; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:16px; margin:16px 0; }
  label { display:block; font-weight:600; margin:12px 0 4px; }
  input[type=text], input[type=date], textarea { width:100%; padding:8px; border:1px solid var(--line); border-radius:6px; font:inherit; }
  textarea { min-height:180px; }
  .row { display:flex; gap:12px; flex-wrap:wrap; } .row > div { flex:1 1 200px; }
  .check { display:flex; gap:8px; align-items:center; margin-top:12px; font-weight:400; }
  button { margin-top:16px; padding:10px 16px; border:0; border-radius:6px; background:var(--accent); color:#fff; font:inherit; cursor:pointer; }
  .notice { background:#fff6e0; border:1px solid #f0d58a; border-radius:6px; padding:8px 12px; }
  .muted { color:var(--muted); font-size:.9rem; }
  table { width:100%; border-collapse:collapse; } td, th { text-align:left; padding:8px 4px; border-bottom:1px solid var(--line); vertical-align:top; }
  td form button { margin:0; padding:4px 10px; }
</style>
</head>
<body><main>
<nav><a href="{{ url_for('home') }}">New recap</a><a href="{{ url_for('open_commitments') }}">Open commitments</a></nav>

{% if view == 'home' %}
<h1>Draft a recap email</h1>
<form class="card" method="post" action="{{ url_for('draft') }}">
  <div class="row">
    <div><label for="client">Client</label><input type="text" id="client" name="client" required></div>
    <div><label for="pm">Your name</label><input type="text" id="pm" name="pm" required></div>
    <div><label for="date">Call date</label><input type="date" id="date" name="date" value="{{ today }}"></div>
  </div>
  <label for="notes">Meeting notes</label>
  <textarea id="notes" name="notes" required placeholder="Agreed: ...&#10;Decision: ...&#10;Action: Maria to send feedback by 2026-10-20"></textarea>
  <label class="check"><input type="checkbox" name="use_ai" checked> Use AI drafting (free-form notes are fine)</label>
  <p class="muted">Without AI, write one item per line starting with Agreed:, Decision: or Action:.</p>
  <button type="submit">Draft recap</button>
</form>

{% elif view == 'draft' %}
<h1>Your recap draft</h1>
{% if notice %}<p class="notice">{{ notice }}</p>{% endif %}
<div class="card">
  <label for="subject">Subject</label><input type="text" id="subject" value="{{ email.subject }}">
  <label for="body">Body</label><textarea id="body" rows="18">{{ email.body }}</textarea>
  <button type="button" onclick="copyEmail()">Copy email</button>
  <p class="muted">Edit as you like, then send it from your own email. {{ saved }} commitment(s) saved to the open list.</p>
</div>
<script>
function copyEmail() {
  const text = "Subject: " + document.getElementById("subject").value + "\\n\\n" + document.getElementById("body").value;
  navigator.clipboard.writeText(text);
}
</script>

{% else %}
<h1>Open commitments{% if client %} for {{ client }}{% endif %}</h1>
<form method="get"><div class="row"><div><input type="text" name="client" placeholder="Filter by client" value="{{ client or '' }}"></div></div></form>
<div class="card">
{% if items %}
<table>
  <tr><th>Client</th><th>Who</th><th>What</th><th>Due</th><th></th></tr>
  {% for c in items %}
  <tr>
    <td>{{ c.client }}</td><td>{{ c.owner or 'Unassigned' }}</td><td>{{ c.task }}</td>
    <td>{{ c.due.isoformat() if c.due else '—' }}{% if c.due and c.due < today_date %} <strong>overdue</strong>{% endif %}</td>
    <td><form method="post" action="{{ url_for('done', commitment_id=c.id) }}"><button type="submit">Done</button></form></td>
  </tr>
  {% endfor %}
</table>
{% else %}<p>No open commitments.</p>{% endif %}
</div>
{% endif %}
</main></body></html>
"""


def create_app(db_path: str | Path = "commitments.json", extractor: Extractor | None = None) -> Flask:
    app = Flask(__name__)

    def store() -> CommitmentStore:
        return CommitmentStore(db_path)

    def render(**ctx):
        return render_template_string(PAGE, today=date.today().isoformat(), today_date=date.today(), **ctx)

    @app.get("/")
    def home():
        return render(view="home")

    @app.post("/draft")
    def draft():
        notes = request.form.get("notes", "").strip()
        client = request.form.get("client", "").strip()
        pm = request.form.get("pm", "").strip()
        if not (notes and client and pm):
            abort(400, "Notes, client and your name are required.")
        try:
            call_date = date.fromisoformat(request.form.get("date") or date.today().isoformat())
        except ValueError:
            abort(400, "Call date must be YYYY-MM-DD.")
        meeting, notice = build_meeting(
            request.form["notes"], call_date=call_date, use_ai=bool(request.form.get("use_ai")), extractor=extractor
        )
        email = draft_recap(meeting, client=client, pm_name=pm, call_date=call_date)
        saved = store().add(client, meeting.commitments, call_date=call_date)
        return render(view="draft", email=email, notice=notice, saved=len(saved))

    @app.get("/open")
    def open_commitments():
        client = request.args.get("client", "").strip() or None
        return render(view="open", items=store().open_commitments(client=client), client=client)

    @app.post("/done/<int:commitment_id>")
    def done(commitment_id: int):
        try:
            store().mark_done(commitment_id)
        except KeyError:
            abort(404)
        return redirect(url_for("open_commitments"))

    return app


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(prog="recap-web", description="Run the Client Recap web page.")
    parser.add_argument("--db", default="commitments.json")
    parser.add_argument("--port", type=int, default=5000)
    args = parser.parse_args()
    create_app(args.db).run(port=args.port)


if __name__ == "__main__":
    main()
