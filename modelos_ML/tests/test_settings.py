"""Pruebas del contrato de configuración DEV/PRD sin usar secretos reales."""

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


MODELOS_ML_ROOT = Path(__file__).resolve().parents[1]
if str(MODELOS_ML_ROOT) not in sys.path:
    sys.path.insert(0, str(MODELOS_ML_ROOT))

from config import settings as settings_module


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.original_project_root = settings_module.PROJECT_ROOT
        self.original_modelos_root = settings_module.MODELOS_ML_ROOT

    def tearDown(self):
        settings_module.PROJECT_ROOT = self.original_project_root
        settings_module.MODELOS_ML_ROOT = self.original_modelos_root

    def _use_temporary_roots(self, root: Path) -> None:
        modelos_root = root / "modelos_ML"
        modelos_root.mkdir()
        settings_module.PROJECT_ROOT = root
        settings_module.MODELOS_ML_ROOT = modelos_root

    def test_injected_values_override_dev_file(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / ".env.dev").write_text(
                "APP_ENV=dev\n"
                "PGHOST=file-dev-host\n"
                "PGDATABASE=db-eterlotto-dev\n"
                "PGUSER=file-user\n"
                "PGPASSWORD=file-password\n"
                "DATABASE_ENV_MARKER=dev\n",
                encoding="utf-8",
            )
            self._use_temporary_roots(root)

            with patch.dict(os.environ, {"APP_ENV": "dev", "PGHOST": "injected-dev-host"}, clear=True):
                configuration = settings_module.load_settings()

            self.assertEqual(configuration.environment, "dev")
            self.assertEqual(configuration.pg_host, "injected-dev-host")
            configuration.validate_database_configuration()

    def test_prd_requires_matching_database_marker(self):
        environment = {
            "APP_ENV": "prd",
            "PGHOST": "postgres-prd",
            "PGDATABASE": "db-eterlotto-prd",
            "PGUSER": "user",
            "PGPASSWORD": "password",
            "DATABASE_ENV_MARKER": "dev",
        }
        with patch.dict(os.environ, environment, clear=True):
            configuration = settings_module.load_settings()

        with self.assertRaises(settings_module.ConfigurationError):
            configuration.validate_database_configuration()

    def test_prd_never_falls_back_to_legacy_dev_env(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self._use_temporary_roots(root)
            (settings_module.MODELOS_ML_ROOT / ".env").write_text(
                "PGHOST=legacy-dev-host\n"
                "PGDATABASE=db-eterlotto-dev\n"
                "PGUSER=user\n"
                "PGPASSWORD=password\n",
                encoding="utf-8",
            )

            with patch.dict(os.environ, {"APP_ENV": "prd"}, clear=True):
                configuration = settings_module.load_settings()

        self.assertIsNone(configuration.env_file)
        self.assertIsNone(configuration.pg_host)
        with self.assertRaises(settings_module.ConfigurationError):
            configuration.validate_database_configuration()

    def test_prd_accepts_database_url_with_matching_marker(self):
        environment = {
            "APP_ENV": "prd",
            "DATABASE_URL": "postgresql+psycopg2://user:password@postgres-prd/db-eterlotto-prd",
            "DATABASE_ENV_MARKER": "prd",
        }
        with patch.dict(os.environ, environment, clear=True):
            configuration = settings_module.load_settings()

        configuration.validate_database_configuration()
        self.assertEqual(configuration.database_target, "postgres-prd/db-eterlotto-prd/user")

    def test_invalid_environment_is_rejected(self):
        with patch.dict(os.environ, {"APP_ENV": "staging"}, clear=True):
            with self.assertRaises(settings_module.ConfigurationError):
                settings_module.load_settings()


if __name__ == "__main__":
    unittest.main()
