"""HTTP layer with retry and a clean failure mode.

Two environment facts shaped this module, both measured rather than assumed
(docs/HANDOVER.md):

1. Yahoo rate-limits an anonymous client and answers 429. A browser User-Agent
   plus backoff gets round it.
2. NSE is network-blocked and BSE's JSON API answers 403 behind Akamai. When a
   source cannot be reached, the fetchers must fail *cleanly* so the seed can
   record the gap instead of writing a wrong number.
"""

from __future__ import annotations

import json
import time
from typing import Any

import httpx

from . import config


class FetchError(RuntimeError):
    """Raised when a source cannot be read. Callers must handle this."""


def _headers() -> dict[str, str]:
    return {
        "User-Agent": config.USER_AGENT,
        "Accept": "application/json, text/html;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }


def get_json(url: str, *, retries: int = config.HTTP_RETRIES) -> Any:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            with httpx.Client(timeout=config.HTTP_TIMEOUT, follow_redirects=True) as c:
                r = c.get(url, headers=_headers())
            if r.status_code == 429:
                time.sleep(config.HTTP_BACKOFF * (2**attempt))
                last = FetchError(f"{url} → 429 rate limited")
                continue
            if r.status_code >= 400:
                raise FetchError(f"{url} → HTTP {r.status_code}")
            return r.json()
        except FetchError:
            raise
        except (httpx.HTTPError, json.JSONDecodeError) as e:
            last = e
            time.sleep(config.HTTP_BACKOFF * (2**attempt))
    raise FetchError(f"{url} → {last}")


def get_text(url: str, *, retries: int = config.HTTP_RETRIES) -> str:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            with httpx.Client(timeout=config.HTTP_TIMEOUT, follow_redirects=True) as c:
                r = c.get(url, headers=_headers())
            if r.status_code == 429:
                time.sleep(config.HTTP_BACKOFF * (2**attempt))
                last = FetchError(f"{url} → 429 rate limited")
                continue
            if r.status_code >= 400:
                raise FetchError(f"{url} → HTTP {r.status_code}")
            return r.text
        except FetchError:
            raise
        except httpx.HTTPError as e:
            last = e
            time.sleep(config.HTTP_BACKOFF * (2**attempt))
    raise FetchError(f"{url} → {last}")


def get_bytes(url: str, *, retries: int = config.HTTP_RETRIES) -> bytes:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            with httpx.Client(timeout=config.HTTP_TIMEOUT, follow_redirects=True) as c:
                r = c.get(url, headers=_headers())
            if r.status_code >= 400:
                raise FetchError(f"{url} → HTTP {r.status_code}")
            return r.content
        except FetchError:
            raise
        except httpx.HTTPError as e:
            last = e
            time.sleep(config.HTTP_BACKOFF * (2**attempt))
    raise FetchError(f"{url} → {last}")
