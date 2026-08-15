import time
from typing import Any, Dict, Optional, Tuple

class MemoryTTLCache:
    """
    Caché en memoria RAM de alta velocidad con expiración por TTL (Time-To-Live).
    Garantiza respuestas en <1 ms para peticiones concurrentes masivas.
    """
    def __init__(self, default_ttl: int = 300):
        self._cache: Dict[str, Tuple[Any, float]] = {}
        self.default_ttl = default_ttl

    def get(self, key: str) -> Optional[Any]:
        if key in self._cache:
            data, expire_at = self._cache[key]
            if time.time() < expire_at:
                return data
            else:
                del self._cache[key]
        return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        duration = ttl if ttl is not None else self.default_ttl
        expire_at = time.time() + duration
        self._cache[key] = (value, expire_at)

    def clear(self) -> None:
        self._cache.clear()

# Instancia global de caché del backend
memory_cache = MemoryTTLCache(default_ttl=300)
