from __future__ import annotations

import sounddevice as sd

from game_trans.audio import output


def _fake_hostapis() -> list[dict[str, object]]:
    return [
        {"name": "MME"},
        {"name": "Windows DirectSound"},
        {"name": "Windows WASAPI"},
        {"name": "Windows WDM-KS"},
    ]


def _fake_devices() -> list[dict[str, object]]:
    return [
        {"name": "Microsoft 사운드 매퍼 - Output", "max_output_channels": 2, "hostapi": 0},
        {"name": "주 사운드 드라이버", "max_output_channels": 2, "hostapi": 1},
        {"name": "Microphone Only", "max_output_channels": 0, "hostapi": 2},
        {"name": "CABLE Input (VB-Audio Virtual ", "max_output_channels": 2, "hostapi": 0},
        {"name": "CABLE Input (VB-Audio Virtual Cable)", "max_output_channels": 2, "hostapi": 2},
        {"name": "Headphones (Arctis Nova 5)", "max_output_channels": 2, "hostapi": 1},
        {"name": "Headphones (Arctis Nova 5)", "max_output_channels": 2, "hostapi": 2},
    ]


def test_list_output_devices_prefers_wasapi_and_filters_generics(monkeypatch) -> None:
    monkeypatch.setattr(sd, "query_hostapis", _fake_hostapis)
    monkeypatch.setattr(sd, "query_devices", lambda *a, **kw: _fake_devices())

    devices = output.list_output_devices()
    indices = {idx for idx, _ in devices}
    names = [name for _, name in devices]

    assert 0 not in indices
    assert 1 not in indices
    assert 2 not in indices
    assert indices == {4, 6}
    assert names == [
        "CABLE Input (VB-Audio Virtual Cable)",
        "Headphones (Arctis Nova 5)",
    ]


def test_find_output_device_matches_preferred_device(monkeypatch) -> None:
    monkeypatch.setattr(sd, "query_hostapis", _fake_hostapis)
    monkeypatch.setattr(sd, "query_devices", lambda *a, **kw: _fake_devices())

    assert output.find_output_device("CABLE Input") == 4
    assert output.find_output_device("arctis nova 5") == 6
    assert output.find_output_device("Missing Device") is None
