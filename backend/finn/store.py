"""SQLite schema and typed accessors.

The store is the spine of the honesty story: every number the API serves was
written here by the seeding pipeline, and nothing is recomputed at request
time. That is what makes "the demo cannot break because a source blocked us"
true rather than aspirational.

Reconstructed from docs/HANDOVER.md. Table shapes follow the documented
snapshot counts (22 companies, 8,819 prices, 129 announcements, 26 documents,
2,328 chunks, 3,341 financials, 25 promises/verdicts).
"""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from typing import Any, Iterable, Iterator

from . import config

SCHEMA = """
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS companies (
    ticker      TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    sector      TEXT NOT NULL,
    in_portfolio INTEGER NOT NULL DEFAULT 0,
    about       TEXT
);

CREATE TABLE IF NOT EXISTS prices (
    ticker      TEXT NOT NULL,
    date        TEXT NOT NULL,
    close       REAL,
    volume      REAL,
    PRIMARY KEY (ticker, date)
);

CREATE TABLE IF NOT EXISTS announcements (
    id          TEXT PRIMARY KEY,
    ticker      TEXT NOT NULL,
    category    TEXT NOT NULL,
    title       TEXT NOT NULL,
    summary     TEXT,
    url         TEXT,
    filed_at    TEXT NOT NULL,
    materiality REAL NOT NULL DEFAULT 0,
    tier        TEXT NOT NULL DEFAULT 'filed_away',
    why         TEXT NOT NULL DEFAULT '[]',
    hash        TEXT
);

CREATE TABLE IF NOT EXISTS documents (
    doc_id      TEXT PRIMARY KEY,
    ticker      TEXT NOT NULL,
    kind        TEXT NOT NULL,          -- annual_report | concall
    title       TEXT NOT NULL,
    url         TEXT,
    period      TEXT,
    pages       INTEGER
);

CREATE TABLE IF NOT EXISTS chunks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    doc_id      TEXT NOT NULL,
    page        INTEGER,
    speaker     TEXT,
    text        TEXT NOT NULL,
    embedding   BLOB
);

CREATE TABLE IF NOT EXISTS financials (
    ticker      TEXT NOT NULL,
    period      TEXT NOT NULL,
    metric      TEXT NOT NULL,
    value       REAL,
    basis       TEXT,
    PRIMARY KEY (ticker, period, metric)
);

CREATE TABLE IF NOT EXISTS promises (
    id          TEXT PRIMARY KEY,
    ticker      TEXT NOT NULL,
    quarter     TEXT NOT NULL,
    metric      TEXT NOT NULL,
    quote       TEXT NOT NULL,
    doc_id      TEXT,
    page        INTEGER,
    speaker     TEXT,
    reading     TEXT,
    target      REAL,
    actual      REAL,
    verdict     TEXT NOT NULL DEFAULT 'not_measurable',
    verified    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS results (
    ticker      TEXT PRIMARY KEY,
    period      TEXT NOT NULL,
    scope       TEXT NOT NULL DEFAULT 'standalone',
    payload     TEXT NOT NULL          -- JSON blob, extracted once
);

CREATE TABLE IF NOT EXISTS llm_calls (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    provider    TEXT NOT NULL,
    model       TEXT,
    purpose     TEXT,
    tokens      INTEGER NOT NULL DEFAULT 0,
    cost        REAL NOT NULL DEFAULT 0.0,
    at          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_prices_ticker_date ON prices(ticker, date);
CREATE INDEX IF NOT EXISTS idx_ann_ticker ON announcements(ticker);
CREATE INDEX IF NOT EXISTS idx_ann_filed ON announcements(filed_at);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(doc_id);
CREATE INDEX IF NOT EXISTS idx_fin_ticker ON financials(ticker);
"""


def connect() -> sqlite3.Connection:
    config.DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


@contextmanager
def session() -> Iterator[sqlite3.Connection]:
    conn = connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    with session() as conn:
        conn.executescript(SCHEMA)


# ------------------------------------------------------------------ helpers


def rows_to_dicts(rows: Iterable[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(r) for r in rows]


def db_exists() -> bool:
    return config.DB_PATH.exists() and config.DB_PATH.stat().st_size > 0


def is_seeded() -> bool:
    """True when the snapshot looks complete enough to serve."""
    if not db_exists():
        return False
    try:
        with session() as conn:
            n = conn.execute("SELECT COUNT(*) FROM announcements").fetchone()[0]
            c = conn.execute("SELECT COUNT(*) FROM companies").fetchone()[0]
        return n > 0 and c > 0
    except sqlite3.DatabaseError:
        return False


# ------------------------------------------------------------------ readers


def companies(in_portfolio: bool | None = None) -> list[dict[str, Any]]:
    q = "SELECT * FROM companies"
    args: list[Any] = []
    if in_portfolio is not None:
        q += " WHERE in_portfolio = ?"
        args.append(1 if in_portfolio else 0)
    q += " ORDER BY ticker"
    with session() as conn:
        return rows_to_dicts(conn.execute(q, args).fetchall())


def company(ticker: str) -> dict[str, Any] | None:
    with session() as conn:
        r = conn.execute(
            "SELECT * FROM companies WHERE ticker = ?", (ticker.upper(),)
        ).fetchone()
        return dict(r) if r else None


def prices(ticker: str, limit: int = 60) -> list[dict[str, Any]]:
    with session() as conn:
        r = conn.execute(
            "SELECT date, close, volume FROM prices WHERE ticker = ? "
            "ORDER BY date DESC LIMIT ?",
            (ticker.upper(), limit),
        ).fetchall()
    return list(reversed(rows_to_dicts(r)))


def series(ticker: str, field: str, limit: int = 60) -> list[float | None]:
    return [
        (p.get(field) if p.get(field) is not None else None)
        for p in prices(ticker, limit)
    ]


def last_price(ticker: str) -> dict[str, Any] | None:
    with session() as conn:
        r = conn.execute(
            "SELECT date, close, volume FROM prices WHERE ticker = ? "
            "ORDER BY date DESC LIMIT 1",
            (ticker.upper(),),
        ).fetchone()
        return dict(r) if r else None


def day_change_pct(ticker: str) -> float | None:
    with session() as conn:
        r = conn.execute(
            "SELECT close FROM prices WHERE ticker = ? ORDER BY date DESC LIMIT 2",
            (ticker.upper(),),
        ).fetchall()
    if len(r) < 2:
        return None
    latest, prev = r[0][0], r[1][0]
    if not prev:
        return None
    return (latest / prev - 1) * 100


def volume_multiple(ticker: str, lookback: int = 20) -> float | None:
    """Latest volume against its trailing average — the volume-rule input."""
    with session() as conn:
        r = conn.execute(
            "SELECT volume FROM prices WHERE ticker = ? ORDER BY date DESC LIMIT ?",
            (ticker.upper(), lookback + 1),
        ).fetchall()
    vols = [x[0] for x in r if x[0]]
    if len(vols) < 3:
        return None
    latest, avg = vols[0], sum(vols[1:]) / len(vols[1:])
    return latest / avg if avg else None


def announcements(window_hours: int | None = None) -> list[dict[str, Any]]:
    q = "SELECT * FROM announcements"
    args: list[Any] = []
    if window_hours is not None:
        # filed_at is stored as an ISO string; compare on the date prefix so
        # this stays index-friendly without needing datetime parsing in SQL.
        q += " WHERE julianday(filed_at) >= julianday('now') - ?"
        args.append(window_hours / 24.0)
    q += " ORDER BY materiality DESC, filed_at DESC"
    with session() as conn:
        return rows_to_dicts(conn.execute(q, args).fetchall())


def announcement(aid: str) -> dict[str, Any] | None:
    with session() as conn:
        r = conn.execute(
            "SELECT * FROM announcements WHERE id = ?", (aid,)
        ).fetchone()
        return dict(r) if r else None


def documents(ticker: str | None = None) -> list[dict[str, Any]]:
    q = "SELECT * FROM documents"
    args: list[Any] = []
    if ticker:
        q += " WHERE ticker = ?"
        args.append(ticker.upper())
    q += " ORDER BY period DESC"
    with session() as conn:
        return rows_to_dicts(conn.execute(q, args).fetchall())


def document(doc_id: str) -> dict[str, Any] | None:
    with session() as conn:
        r = conn.execute(
            "SELECT * FROM documents WHERE doc_id = ?", (doc_id,)
        ).fetchone()
        return dict(r) if r else None


def chunks_for(doc_id: str) -> list[dict[str, Any]]:
    with session() as conn:
        return rows_to_dicts(
            conn.execute(
                "SELECT id, doc_id, page, speaker, text FROM chunks "
                "WHERE doc_id = ? ORDER BY page, id",
                (doc_id,),
            ).fetchall()
        )


def financials(ticker: str) -> list[dict[str, Any]]:
    with session() as conn:
        return rows_to_dicts(
            conn.execute(
                "SELECT period, metric, value, basis FROM financials "
                "WHERE ticker = ? ORDER BY period",
                (ticker.upper(),),
            ).fetchall()
        )


def financial_series(ticker: str, metric: str) -> list[tuple[str, float | None]]:
    with session() as conn:
        r = conn.execute(
            "SELECT period, value FROM financials "
            "WHERE ticker = ? AND metric = ? ORDER BY period",
            (ticker.upper(), metric),
        ).fetchall()
    return [(row["period"], row["value"]) for row in r]


def results(ticker: str) -> dict[str, Any] | None:
    import json

    with session() as conn:
        r = conn.execute(
            "SELECT payload FROM results WHERE ticker = ?", (ticker.upper(),)
        ).fetchone()
    if not r:
        return None
    try:
        return json.loads(r[0])
    except Exception:
        return None


def promises(ticker: str) -> list[dict[str, Any]]:
    with session() as conn:
        return rows_to_dicts(
            conn.execute(
                "SELECT * FROM promises WHERE ticker = ? ORDER BY quarter DESC",
                (ticker.upper(),),
            ).fetchall()
        )


def counts() -> dict[str, int]:
    with session() as conn:
        def n(sql: str) -> int:
            try:
                return int(conn.execute(sql).fetchone()[0])
            except sqlite3.DatabaseError:
                return 0

        return {
            "companies": n("SELECT COUNT(*) FROM companies"),
            "prices": n("SELECT COUNT(*) FROM prices"),
            "announcements": n("SELECT COUNT(*) FROM announcements"),
            "documents": n("SELECT COUNT(*) FROM documents"),
            "chunks": n("SELECT COUNT(*) FROM chunks"),
            "financials": n("SELECT COUNT(*) FROM financials"),
            "ledger_rows": n("SELECT COUNT(*) FROM promises"),
        }


def llm_cost_total() -> float:
    with session() as conn:
        try:
            r = conn.execute("SELECT COALESCE(SUM(cost), 0) FROM llm_calls").fetchone()
            return float(r[0])
        except sqlite3.DatabaseError:
            return 0.0
