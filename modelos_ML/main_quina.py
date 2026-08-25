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

from src.quina.scraper import QuinaScraper
from src.quina.predictor import QuinaPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Quina (Brasil)")
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
    print(f"Iniciando orquestación: Lotería=Quina | Tarea={task} | Backfill={backfill}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = QuinaScraper()
            scraper_inst.run(backfill=backfill)
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Quina: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = QuinaPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Quina: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("quina")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Quina: {e}")

    print("✅ ¡Proceso completado exitosamente para Quina!")

if __name__ == "__main__":
    main()
