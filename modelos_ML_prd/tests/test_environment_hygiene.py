from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def test_dags_do_not_depend_on_old_absolute_path():
    for dag in ROOT.glob("eterlotto_*_dag.py"):
        text = dag.read_text(encoding="utf-8")
        assert "/opt/airflow/pry_dataloto/modelos_ML" not in text, dag.name


def test_dags_do_not_embed_smtp_passwords():
    for dag in ROOT.glob("eterlotto_*_dag.py"):
        text = dag.read_text(encoding="utf-8")
        assert not re.search(r"^\s*password\s*=\s*['\"]", text, re.MULTILINE), dag.name
        assert "smtplib" not in text, dag.name


def test_local_secret_files_are_gitignored():
    ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert ".env.*" in ignore
    assert ".secrets/" in ignore
