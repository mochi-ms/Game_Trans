"""Entry point: ``python -m game_trans``."""

from __future__ import annotations

import os
import sys

# Must be set before Qt loads QML controls so Windows light-mode theme never overrides dark popups/text.
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from .app import run


def main() -> None:
    sys.exit(run())


if __name__ == "__main__":
    main()
