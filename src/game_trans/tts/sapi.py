"""Windows offline fallback TTS via System.Speech.Synthesis (SAPI)."""

from __future__ import annotations

import asyncio
import os
import subprocess
import tempfile
import wave
from pathlib import Path

from .base import SpeechAudio, TTSEngine


class SapiTTS(TTSEngine):
    name = "sapi"

    async def synthesize(self, text: str, lang: str) -> SpeechAudio:
        return await asyncio.to_thread(self._synthesize_sync, text)

    @staticmethod
    def _synthesize_sync(text: str) -> SpeechAudio:
        fd, tmp_name = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        tmp_path = Path(tmp_name)
        try:
            script = (
                "Add-Type -AssemblyName System.Speech; "
                "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
                f"$s.SetOutputToWaveFile('{str(tmp_path).replace(chr(39), chr(39)*2)}'); "
                f"$s.Speak($env:GT_TTS_TEXT); "
                "$s.Dispose()"
            )
            env = {**os.environ, "GT_TTS_TEXT": text}
            res = subprocess.run(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
                env=env,
                capture_output=True,
                timeout=15,
                check=False,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            if res.returncode != 0 or not tmp_path.exists() or tmp_path.stat().st_size <= 44:
                raise RuntimeError("Windows SAPI TTS failed")
            with wave.open(str(tmp_path), "rb") as w:
                pcm16 = w.readframes(w.getnframes())
                sr = w.getframerate()
            return SpeechAudio(pcm16=pcm16, sample_rate=sr)
        finally:
            tmp_path.unlink(missing_ok=True)
