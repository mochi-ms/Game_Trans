import asyncio

import pytest

from game_trans.ai.rate_limiter import RateLimiter
from game_trans.ai.usage import UsageMeter
from game_trans.config import load_config
from game_trans.platform.hotkeys import MOD_CONTROL, MOD_SHIFT, parse_hotkey


def test_rate_limiter_burst_then_blocks():
    limiter = RateLimiter(rpm=60, burst=2)
    assert limiter.try_acquire()
    assert limiter.try_acquire()
    assert not limiter.try_acquire()
    assert 0 < limiter.wait_time() <= 1.0


def test_rate_limiter_async_acquire():
    limiter = RateLimiter(rpm=600, burst=1)

    async def run():
        await limiter.acquire()
        await limiter.acquire()  # waits ~0.1s

    asyncio.run(asyncio.wait_for(run(), timeout=2))


def test_usage_cost_and_budget():
    meter = UsageMeter(input_per_mtok=0.30, output_per_mtok=2.50, monthly_budget_usd=1.0)
    cost = meter.record(input_tokens=1_000_000, output_tokens=100_000)
    assert cost == pytest.approx(0.30 + 0.25)
    assert meter.requests_last_minute() == 1
    assert meter.budget_ratio == pytest.approx(0.55)
    assert not meter.over_budget
    assert UsageMeter.estimate_audio_tokens(60) == 1920


def test_parse_hotkey():
    mods, vk = parse_hotkey("Ctrl+Shift+Space")
    assert mods & MOD_CONTROL and mods & MOD_SHIFT
    assert vk == 0x20
    with pytest.raises(ValueError):
        parse_hotkey("Ctrl+Shift")


def test_config_defaults(tmp_path):
    cfg = load_config(tmp_path / "missing.toml")
    assert cfg.ai.model == "gemini-3.5-flash-lite"
    p = tmp_path / "c.toml"
    p.write_text('[ai]\nrpm_limit = 300\n[ai.pricing]\ninput_per_mtok = 0.5\n', encoding="utf-8")
    cfg = load_config(p)
    assert cfg.ai.rpm_limit == 300
    assert cfg.ai.pricing.input_per_mtok == 0.5
    assert cfg.ai.pricing.output_per_mtok == 2.50
