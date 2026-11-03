"""LLM provider interface with three backends and a cost ledger.

The design decision recorded in docs/HANDOVER.md is the important part here:

    the hosted proxy has no credits on this host, and the local 1.5B model
    hallucinated a margin target ("18.0%") that appears nowhere in the Maruti
    transcript.

So the pipeline ships on the `deterministic` tier. Nothing user-visible depends
on a model. The interface exists so the tier can be swapped without touching
call sites, and every call is written to the cost ledger with its real cost
(which is zero on the deterministic tier).
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Protocol

from . import config, store


@dataclass
class LLMResult:
    text: str
    provider: str
    model: str | None
    tokens: int
    cost: float
    cached: bool = False


class Provider(Protocol):
    name: str

    def complete(self, prompt: str, *, purpose: str = "") -> LLMResult: ...


class DeterministicProvider:
    """No model. Returns a refusal so callers fall through to their rules.

    This is the shipped tier. A refusal is better than a guess: every caller
    treats an empty completion as "use the deterministic path".
    """

    name = "deterministic"

    def complete(self, prompt: str, *, purpose: str = "") -> LLMResult:
        return LLMResult(text="", provider=self.name, model=None, tokens=0, cost=0.0)


class LocalProvider:
    """Local GGUF via llama-cpp if it happens to be installed.

    Not required: if llama_cpp is absent this raises, and the caller degrades to
    the deterministic tier. Kept explicit rather than silently disabled.
    """

    name = "local-qwen2.5-1.5b"

    def __init__(self) -> None:
        self.model_path = os.environ.get("FINN_GGUF", "")
        self._llm = None

    def _load(self):
        if self._llm is not None:
            return self._llm
        if not self.model_path or not os.path.exists(self.model_path):
            raise RuntimeError("FINN_GGUF not set; local tier unavailable")
        from llama_cpp import Llama  # type: ignore

        self._llm = Llama(model_path=self.model_path, n_ctx=2048, verbose=False)
        return self._llm

    def complete(self, prompt: str, *, purpose: str = "") -> LLMResult:
        llm = self._load()
        out = llm(prompt, max_tokens=256, temperature=0.0)
        text = out["choices"][0]["text"].strip()
        tokens = int(out.get("usage", {}).get("total_tokens", 0))
        return LLMResult(
            text=text,
            provider=self.name,
            model="qwen2.5-1.5b-instruct",
            tokens=tokens,
            cost=0.0,  # local compute, no per-token charge
        )


class HostedProvider:
    """Hosted proxy, if FINN_HOSTED_URL is configured. Off by default."""

    name = "hosted"

    def __init__(self) -> None:
        self.url = os.environ.get("FINN_HOSTED_URL", "")
        self.key = os.environ.get("FINN_HOSTED_KEY", "")
        if not self.url:
            raise RuntimeError("FINN_HOSTED_URL not set; hosted tier unavailable")

    def complete(self, prompt: str, *, purpose: str = "") -> LLMResult:
        import httpx

        r = httpx.post(
            self.url,
            headers={"Authorization": f"Bearer {self.key}"},
            json={"prompt": prompt, "temperature": 0.0, "max_tokens": 256},
            timeout=60,
        )
        if r.status_code != 200:
            raise RuntimeError(f"hosted LLM → HTTP {r.status_code}: {r.text[:200]}")
        d = r.json()
        return LLMResult(
            text=d.get("text", ""),
            provider=self.name,
            model=d.get("model"),
            tokens=int(d.get("tokens", 0)),
            cost=float(d.get("cost", 0.0)),
        )


def _cache_path(prompt: str, purpose: str) -> str:
    h = hashlib.sha256(f"{purpose}:{prompt}".encode()).hexdigest()
    return f"{h}.txt"


_CACHE: dict[str, str] = {}


def provider_for(tier: str | None = None) -> Provider:
    tier = tier or config.LLM_TIER
    if tier == "local":
        return LocalProvider()
    if tier == "hosted":
        return HostedProvider()
    return DeterministicProvider()


def complete(prompt: str, *, purpose: str = "", tier: str | None = None) -> LLMResult:
    """Run a completion, honouring the content-hash cache and cost ledger."""
    provider = provider_for(tier)

    key = _cache_path(prompt, purpose)
    if config.LLM_CACHE_ENABLED and key in _CACHE:
        cached = LLMResult(
            text=_CACHE[key], provider=provider.name, model=None, tokens=0,
            cost=0.0, cached=True,
        )
        _record(cached, purpose)
        return cached

    try:
        result = provider.complete(prompt, purpose=purpose)
    except Exception:
        # Any backend failure degrades to the deterministic tier rather than
        # breaking the caller. This is what keeps the demo alive.
        result = LLMResult(
            text="", provider="deterministic", model=None, tokens=0, cost=0.0
        )

    if config.LLM_CACHE_ENABLED and result.text:
        _CACHE[key] = result.text

    _record(result, purpose)
    return result


def _record(result: LLMResult, purpose: str) -> None:
    """Append to the cost ledger. Never let telemetry break a request."""
    try:
        with store.session() as conn:
            conn.execute(
                "INSERT INTO llm_calls (provider, model, purpose, tokens, cost, at) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (
                    result.provider,
                    result.model,
                    purpose,
                    result.tokens,
                    result.cost,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
    except Exception:
        pass


def ledger() -> dict:
    """Cost summary for /api/cost."""
    by_provider: list[dict] = []
    try:
        with store.session() as conn:
            rows = conn.execute(
                "SELECT provider, COUNT(*) c, COALESCE(SUM(cost),0) cost, "
                "COALESCE(SUM(tokens),0) tokens FROM llm_calls GROUP BY provider"
            ).fetchall()
        by_provider = [dict(r) for r in rows]
    except Exception:
        by_provider = []

    total = round(sum(float(r["cost"]) for r in by_provider), 6)
    tokens = sum(int(r["tokens"]) for r in by_provider)
    return {
        "total_cost": total,
        "currency": "INR",
        "tokens": tokens,
        "tier": config.LLM_TIER,
        "by_provider": by_provider,
        "note": (
            "The pipeline ships on the deterministic tier, so classification and "
            "extraction cost nothing. No hosted LLM calls were made."
            if config.LLM_TIER == "deterministic"
            else f"Active tier: {config.LLM_TIER}."
        ),
    }


def dump_cache() -> str:
    return json.dumps(_CACHE)
