"""Async token-bucket rate limiter (requests per minute)."""

from __future__ import annotations

import asyncio
import time


class RateLimiter:
    """Allows ``rpm`` requests per rolling minute with smooth refill.

    >>> limiter = RateLimiter(rpm=10)
    >>> await limiter.acquire()   # waits if the bucket is empty
    """

    def __init__(self, rpm: int, burst: int | None = None) -> None:
        if rpm <= 0:
            raise ValueError("rpm must be positive")
        self.rpm = rpm
        self.capacity = float(burst if burst is not None else max(1, min(rpm, 5)))
        self._tokens = self.capacity
        self._rate = rpm / 60.0  # tokens per second
        self._last = time.monotonic()
        self._lock = asyncio.Lock()

    def _refill(self) -> None:
        now = time.monotonic()
        self._tokens = min(self.capacity, self._tokens + (now - self._last) * self._rate)
        self._last = now

    def try_acquire(self) -> bool:
        """Non-blocking acquire. Returns False if no token is available."""
        self._refill()
        if self._tokens >= 1:
            self._tokens -= 1
            return True
        return False

    def wait_time(self) -> float:
        self._refill()
        return 0.0 if self._tokens >= 1 else (1 - self._tokens) / self._rate

    async def acquire(self) -> None:
        async with self._lock:
            while not self.try_acquire():
                await asyncio.sleep(self.wait_time())

    def penalize(self, seconds: float) -> None:
        """Called on HTTP 429: drain the bucket so callers back off for ``seconds``."""
        self._refill()
        self._tokens = min(self._tokens, 0.0) - seconds * self._rate
