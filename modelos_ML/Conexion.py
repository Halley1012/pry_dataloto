# Módulo legacy de conexión segura delegada (Neon PostgreSQL)
# Redirige a config/database.py para evitar credenciales expuestas.

import os
import sys

# Agregar la ruta base al path para poder importar config.database
base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.append(base_dir)

from config.database import get_engine

engine = get_engine()