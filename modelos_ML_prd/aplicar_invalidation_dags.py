from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent
BACKUP_DIR = ROOT / "_cache_patch_backups"
MARKER = "# ETERLOTTO_CACHE_INVALIDATION_V1"


def _newline_for(line: str) -> str:
    return "\r\n" if line.endswith("\r\n") else "\n"


def patch_file(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        return "already"

    lines = text.splitlines(keepends=True)
    execute_start = None
    execute_end = None

    for i, line in enumerate(lines):
        if re.match(r"^def\s+ejecutar_[A-Za-z0-9_]+\([^)]*\):\s*$", line.strip("\r\n")):
            execute_start = i
            break

    if execute_start is None:
        return "no_execute_wrapper"

    # El bloque termina en la siguiente definición/clase/decorador a nivel 0.
    for i in range(execute_start + 1, len(lines)):
        raw = lines[i]
        if raw.strip() and not raw.startswith((" ", "\t")):
            execute_end = i
            break
    if execute_end is None:
        execute_end = len(lines)

    call_index = None
    for i in range(execute_start + 1, execute_end):
        stripped = lines[i].strip()
        if re.fullmatch(r"main_[A-Za-z0-9_]+\(\)", stripped) or stripped == "main()":
            call_index = i
            break

    if call_index is None:
        return "no_main_call"

    source_line = lines[call_index]
    indent = source_line[: len(source_line) - len(source_line.lstrip())]
    nl = _newline_for(source_line)
    injection = [
        f"{indent}{MARKER}{nl}",
        f"{indent}from config.backend_cache_invalidation import invalidar_cache_backend{nl}",
        f"{indent}invalidar_cache_backend(){nl}",
    ]
    lines[call_index + 1:call_index + 1] = injection

    BACKUP_DIR.mkdir(exist_ok=True)
    shutil.copy2(path, BACKUP_DIR / path.name)
    path.write_text("".join(lines), encoding="utf-8", newline="")
    return "patched"


def main():
    files = sorted(ROOT.glob("eterlotto_*_dag.py"))
    if not files:
        print("No se encontraron eterlotto_*_dag.py en", ROOT)
        return

    counts = {"patched": 0, "already": 0, "skipped": 0}
    for path in files:
        result = patch_file(path)
        if result == "patched":
            counts["patched"] += 1
            print("✅", path.name)
        elif result == "already":
            counts["already"] += 1
            print("↪️  ya estaba:", path.name)
        else:
            counts["skipped"] += 1
            print(f"⚠️  revisar {path.name}: {result}")

    print("\nResumen:", counts)
    print("Backups:", BACKUP_DIR)


if __name__ == "__main__":
    main()
