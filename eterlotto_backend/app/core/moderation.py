import re
import time
from typing import Tuple, Optional
from fastapi import HTTPException

# Patrones para clasificar contenido inapropiado o dañino
PROFANITY_PATTERNS = [
    (r"\b(put[ao]s?|hdp|malparid[ao]s?|gonorrea[s]?|maric[ao]n(es)?|estafador(es)?|ladron(es)?|mierda|hijueputa|hp)\b", "insulto"),
    (r"\b(te voy a (matar|golpear|destruir)|amenaza|muerete)\b", "amenaza"),
    (r"\b(porn[o|ografía]|xxx|nopor|pedofil\w+)\b", "contenido_inapropiado"),
]

SPAM_PATTERNS = [
    r"(https?://\S+|www\.\S+)",  # Enlaces externos no deseados en comentarios
    r"\b(t\.me/\S+|bit\.ly/\S+|wa\.me/\S+)",
    r"\b(gana dinero (fácil|rapido|sin trabajar)|trabaja desde casa|inversión garantizada|cripto bot)\b",
    r"\b(escribeme al whatsapp|contactame al \+?\d{8,})\b",
]

# Control de frecuencia en memoria (Rate Limiting)
_user_last_comment_timestamps: dict[int, float] = {}
COMMENT_COOLDOWN_SECONDS = 5.0

def check_rate_limit(user_id: int, cooldown: float = COMMENT_COOLDOWN_SECONDS):
    """
    Verifica que el usuario no envíe comentarios con demasiada frecuencia.
    Lanza HTTPException(429) si no ha transcurrido el tiempo mínimo.
    """
    now = time.time()
    last_timestamp = _user_last_comment_timestamps.get(user_id, 0.0)
    elapsed = now - last_timestamp
    if elapsed < cooldown:
        wait_seconds = int(cooldown - elapsed) + 1
        raise HTTPException(
            status_code=429,
            detail=f"Estás comentando demasiado rápido. Espera {wait_seconds} segundo(s) antes de intentar nuevamente."
        )
    _user_last_comment_timestamps[user_id] = now

def moderate_content(content: str) -> Tuple[bool, Optional[str]]:
    """
    Evalúa el texto del comentario.
    Retorna:
      (True, None) si el contenido es válido.
      (False, 'spam' | 'insulto' | 'amenaza' | 'contenido_inapropiado') si es rechazado.
    """
    if not content or not content.strip():
        return False, "contenido_inapropiado"

    normalized = content.strip().lower()

    # 1. Chequeo de Spam
    for pattern in SPAM_PATTERNS:
        if re.search(pattern, normalized, re.IGNORECASE):
            return False, "spam"

    # 2. Chequeo de Insultos, Amenazas y Contenido Inapropiado
    for pattern, reason in PROFANITY_PATTERNS:
        if re.search(pattern, normalized, re.IGNORECASE):
            return False, reason

    return True, None
