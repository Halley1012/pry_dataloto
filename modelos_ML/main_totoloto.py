import argparse
import sys
from pathlib import Path

PROJECT_ROOT = str(Path(__file__).resolve().parents[1])

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

if "/opt/airflow" not in sys.path:
    sys.path.append("/opt/airflow")

from src.totoloto.scraper import TotolotoScraper
from src.totoloto.predictor import TotolotoPredictor
from src.notification_generator import NotificationGenerator


def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Totoloto (Portugal)")
    parser.add_argument(
        "--task",
        type=str,
        default="all",
        choices=["scrap", "predict", "notify", "all"],
        help="La tarea a ejecutar (scraping, predicción, notificación o todas) (default: all)"
    )
    parser.add_argument(
        "--backfill",
        action="store_true",
        help="Si se especifica, descarga el histórico amplio de sorteos"
    )

    args, _ = parser.parse_known_args()
    task = args.task
    backfill = args.backfill

    print("==================================================")
    print(f"Iniciando orquestación: Lotería=Totoloto | Tarea={task} | Backfill={backfill}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = TotolotoScraper()
            scraper_inst.run(backfill=backfill)
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Totoloto: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = TotolotoPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Totoloto: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("totoloto")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Totoloto: {e}")

    print("✅ ¡Orquestación de Totoloto completada exitosamente!")


if __name__ == "__main__":
    main()
