import os
import time
import requests


def invalidar_cache_backend() -> bool:
    """Notifica al backend que un modelo terminó y hay datos nuevos.

    No lanza excepción al DAG: hace hasta 3 intentos y deja trazabilidad en logs.
    Usa las variables que Airflow ya expone por ambiente:
      - ETERLOTTO_API_BASE_URL
      - NOTIFICATION_INTERNAL_KEY
    """
    base_url = (os.getenv("ETERLOTTO_API_BASE_URL") or "").strip().rstrip("/")
    internal_key = (os.getenv("NOTIFICATION_INTERNAL_KEY") or "").strip()

    if not base_url or not internal_key:
        print(
            "⚠️ [CACHE] No se invalidó caché: faltan "
            "ETERLOTTO_API_BASE_URL o NOTIFICATION_INTERNAL_KEY"
        )
        return False

    url = f"{base_url}/internal/cache/invalidate"
    headers = {
        "X-Internal-Key": internal_key,
        "Content-Type": "application/json",
    }

    for intento in range(1, 4):
        try:
            response = requests.post(url, headers=headers, timeout=12)
            if response.status_code == 200:
                payload = response.json() if response.content else {}
                print(
                    "✅ [CACHE] Backend invalidado. "
                    f"version={payload.get('version')}"
                )
                return True

            print(
                f"⚠️ [CACHE] Intento {intento}/3: "
                f"HTTP {response.status_code}"
            )
        except Exception as exc:
            print(
                f"⚠️ [CACHE] Intento {intento}/3 falló: "
                f"{type(exc).__name__}"
            )

        if intento < 3:
            time.sleep(2)

    print(
        "⚠️ [CACHE] El modelo terminó, pero no se pudo invalidar el backend. "
        "El TTL de respaldo actualizará la app posteriormente."
    )
    return False
