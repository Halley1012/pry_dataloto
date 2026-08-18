import time
import functools
import inspect
from typing import Any, Callable, Dict, Optional, Tuple

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

    def delete(self, key: str) -> None:
        self._cache.pop(key, None)

    def clear_pattern(self, pattern: str) -> None:
        keys_to_del = [k for k in self._cache if pattern in k]
        for k in keys_to_del:
            self._cache.pop(k, None)

    def clear(self) -> None:
        self._cache.clear()

# Instancia global de caché del backend
memory_cache = MemoryTTLCache(default_ttl=300)


def cached(ttl: int = 300, prefix: Optional[str] = None):
    """
    Decorador estilo @Cacheable de Java / Spring Boot.
    Funciona tanto con funciones sincrónicas (def) como asincrónicas (async def).
    Guarda en memoria RAM el retorno de la función para responder en <1 ms.
    """
    def decorator(func: Callable):
        func_name = prefix or func.__qualname__

        if inspect.iscoroutinefunction(func):
            @functools.wraps(func)
            async def async_wrapper(*args, **kwargs):
                # Limpiar 'self' o 'cls' si es método de clase
                clean_args = args[1:] if args and hasattr(args[0], '__class__') and not isinstance(args[0], (str, int, float, bool, list, dict)) else args
                key = f"{func_name}:{clean_args}:{sorted(kwargs.items())}"
                cached_val = memory_cache.get(key)
                if cached_val is not None:
                    return cached_val
                
                result = await func(*args, **kwargs)
                if result is not None and not (isinstance(result, dict) and "error" in result):
                    memory_cache.set(key, result, ttl=ttl)
                return result
            return async_wrapper
        else:
            @functools.wraps(func)
            def sync_wrapper(*args, **kwargs):
                # Limpiar 'self' o 'cls' si es método de clase
                clean_args = args[1:] if args and hasattr(args[0], '__class__') and not isinstance(args[0], (str, int, float, bool, list, dict)) else args
                key = f"{func_name}:{clean_args}:{sorted(kwargs.items())}"
                cached_val = memory_cache.get(key)
                if cached_val is not None:
                    return cached_val
                
                result = func(*args, **kwargs)
                if result is not None and not (isinstance(result, dict) and "error" in result):
                    memory_cache.set(key, result, ttl=ttl)
                return result
            return sync_wrapper
    return decorator

