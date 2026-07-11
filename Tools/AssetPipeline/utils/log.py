"""ログ設定。"""

from __future__ import annotations

import logging
import sys


def setup_logging(verbose: bool = False) -> logging.Logger:
    """パイプライン共通のロガーを初期化する。"""
    logger = logging.getLogger("pipeline")
    if logger.handlers:
        return logger
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("[%(levelname)s] %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)
    return logger
