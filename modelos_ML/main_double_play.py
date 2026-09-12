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

from src.double_play.scraper import DoublePlayScraper
from src.double_play.predictor import DoublePlayPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Double Play")
    parser.add_argument(
        "--task",
        type=str,
        default="all",
        choices=["scrap", "predict", "notify", "all"],
        help="La tarea a ejecutar (scraping, predicción, notificación o todas) (default: all)"
    )

    args, _ = parser.parse_known_args()
    task = args.task

    print("==================================================")
    print(f"Iniciando orquestación: Lotería=Double Play | Tarea={task}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = DoublePlayScraper()
            scraper_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Double Play: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = DoublePlayPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Double Play: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("double_play")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Double Play: {e}")

    print("✅ ¡Proceso completado exitosamente para Double Play!")

if __name__ == "__main__":
    main()
