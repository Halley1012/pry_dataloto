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

from src.megamillions.scraper import MegaMillionsScraper
from src.megamillions.predictor import MegaMillionsPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Mega Millions")
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
    print(f"Iniciando orquestación: Lotería=Mega Millions | Tarea={task}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = MegaMillionsScraper()
            scraper_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Mega Millions: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = MegaMillionsPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Mega Millions: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("megamillions")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Mega Millions: {e}")

    print("✅ ¡Proceso completado exitosamente para Mega Millions!")

if __name__ == "__main__":
    main()
