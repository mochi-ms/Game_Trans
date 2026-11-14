"""Token / cost accounting from Gemini ``usage_metadata`` with optional SQLite persistence."""

from __future__ import annotations

import datetime as dt
import sqlite3
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

AUDIO_TOKENS_PER_SECOND = 32  # Gemini audio input rate


@dataclass
class UsageStats:
    requests: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0


class UsageStore:
    """Persists daily usage rows in ``%APPDATA%\\GameTrans\\usage.sqlite``."""

    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path))
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS daily_usage (
                day TEXT PRIMARY KEY,
                requests INTEGER NOT NULL DEFAULT 0,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cost_usd REAL NOT NULL DEFAULT 0.0
            )
            """
        )
        self._conn.commit()

    def add(self, day: str, input_tokens: int, output_tokens: int, cost_usd: float) -> None:
        self._conn.execute(
            """
            INSERT INTO daily_usage (day, requests, input_tokens, output_tokens, cost_usd)
            VALUES (?, 1, ?, ?, ?)
            ON CONFLICT(day) DO UPDATE SET
                requests = requests + 1,
                input_tokens = input_tokens + excluded.input_tokens,
                output_tokens = output_tokens + excluded.output_tokens,
                cost_usd = cost_usd + excluded.cost_usd
            """,
            (day, input_tokens, output_tokens, cost_usd),
        )
        self._conn.commit()

    def load_totals(self, today: dt.date | None = None) -> tuple[UsageStats, UsageStats]:
        today = today or dt.date.today()
        day_str = today.isoformat()
        month_prefix = today.strftime("%Y-%m-")
        row_today = self._conn.execute(
            "SELECT requests, input_tokens, output_tokens, cost_usd FROM daily_usage WHERE day = ?",
            (day_str,),
        ).fetchone()
        row_month = self._conn.execute(
            """
            SELECT COALESCE(SUM(requests), 0), COALESCE(SUM(input_tokens), 0),
                   COALESCE(SUM(output_tokens), 0), COALESCE(SUM(cost_usd), 0.0)
            FROM daily_usage WHERE day LIKE ?
            """,
            (f"{month_prefix}%",),
        ).fetchone()
        today_stats = UsageStats(*row_today) if row_today else UsageStats()
        month_stats = UsageStats(*row_month) if row_month else UsageStats()
        return today_stats, month_stats

    def recent_days(self, days: int = 12, today: dt.date | None = None) -> list[tuple[str, float]]:
        today = today or dt.date.today()
        start = today - dt.timedelta(days=days - 1)
        rows = dict(
            self._conn.execute(
                "SELECT day, cost_usd FROM daily_usage WHERE day >= ? ORDER BY day ASC",
                (start.isoformat(),),
            ).fetchall()
        )
        result: list[tuple[str, float]] = []
        for i in range(days):
            d = (start + dt.timedelta(days=i)).isoformat()
            result.append((d, float(rows.get(d, 0.0))))
        return result

    def close(self) -> None:
        self._conn.close()


@dataclass
class UsageMeter:
    input_per_mtok: float = 0.30
    output_per_mtok: float = 2.50
    monthly_budget_usd: float = 9.0
    warn_ratio: float = 0.8
    store: UsageStore | None = None
    month: UsageStats = field(default_factory=UsageStats)
    today: UsageStats = field(default_factory=UsageStats)
    _recent: deque[float] = field(default_factory=deque)
    _current_day: str = field(default_factory=lambda: dt.date.today().isoformat())

    def __post_init__(self) -> None:
        if self.store is not None:
            self.today, self.month = self.store.load_totals()

    def record(self, input_tokens: int, output_tokens: int) -> float:
        day_str = dt.date.today().isoformat()
        if day_str != self._current_day:
            if day_str[:7] != self._current_day[:7]:
                self.month = UsageStats()
            self.today = UsageStats()
            self._current_day = day_str
        cost = input_tokens / 1e6 * self.input_per_mtok + output_tokens / 1e6 * self.output_per_mtok
        for s in (self.month, self.today):
            s.requests += 1
            s.input_tokens += input_tokens
            s.output_tokens += output_tokens
            s.cost_usd += cost
        self._recent.append(time.monotonic())
        if self.store is not None:
            self.store.add(day_str, input_tokens, output_tokens, cost)
        return cost

    def requests_last_minute(self) -> int:
        cutoff = time.monotonic() - 60
        while self._recent and self._recent[0] < cutoff:
            self._recent.popleft()
        return len(self._recent)

    @property
    def budget_ratio(self) -> float:
        return self.month.cost_usd / self.monthly_budget_usd if self.monthly_budget_usd else 0.0

    @property
    def should_warn(self) -> bool:
        return self.budget_ratio >= self.warn_ratio

    @property
    def over_budget(self) -> bool:
        return self.budget_ratio >= 1.0

    @staticmethod
    def estimate_audio_tokens(seconds: float) -> int:
        return int(seconds * AUDIO_TOKENS_PER_SECOND)
