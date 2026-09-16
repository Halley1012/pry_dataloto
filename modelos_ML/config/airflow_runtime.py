"""Bootstrap compartido para los DAGs de Eterlotto.

Evita rutas absolutas ligadas a una instalación concreta. Por defecto usa la
carpeta ``modelos_ML`` que contiene el DAG y su ``.venv_airflow``. Si una
instalación necesita otra ubicación, puede definir ``ETERLOTTO_VENV_ROOT``.
"""

from __future__ import annotations

import os
import site
import sys
from pathlib import Path


def configure_airflow_runtime(modelos_ml_dir: str | Path | None = None) -> Path:
    root = Path(modelos_ml_dir or Path(__file__).resolve().parents[1]).resolve()

    root_str = str(root)
    if root_str not in sys.path:
        sys.path.insert(0, root_str)

    raw_venv = os.getenv("ETERLOTTO_VENV_ROOT", "").strip()
    venv_root = Path(raw_venv).expanduser() if raw_venv else root / ".venv_airflow"
    if not venv_root.is_absolute():
        venv_root = root / venv_root

    # Linux/WSL/Docker y Windows local.
    candidates = list(venv_root.glob("lib/python*/site-packages"))
    windows_site = venv_root / "Lib" / "site-packages"
    if windows_site.is_dir():
        candidates.append(windows_site)

    for site_packages in candidates:
        if site_packages.is_dir():
            site.addsitedir(str(site_packages))

    return root
