from collections.abc import Callable
from pathlib import Path
from typing import TypedDict

class Config:
    cache_dir: Path
    min_duration_s: float

class StoreStats(TypedDict):
    entries: int
    total_bytes: int
    total_hits: int
    estimated_ns_saved: int

class Stats(TypedDict):
    hits: int
    misses: int
    impure_skips: int
    too_fast_skips: int
    too_big_skips: int
    saved_seconds: float
    spent_seconds: float
    invalidation_reasons: dict[str, int]
    store: StoreStats

def cache[**Args, Result](
    function: Callable[Args, Result],
    /,
) -> Callable[Args, Result]: ...
def configure(*, cache_dir: Path, min_duration_s: float) -> Config: ...
def stats() -> Stats: ...
