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

from src.powerball.scraper import PowerballScraper
from src.powerball.predictor import PowerballPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Powerball")
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
    print(f"Iniciando orquestación: Lotería=Powerball | Tarea={task}")
    print("==================================================")

    # 1. Ejecutar scraping
    if task in ["scrap", "all"]:
        try:
            scraper_inst = PowerballScraper()
            scraper_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Powerball: {e}")
            sys.exit(1)

    # 2. Ejecutar predicción
    if task in ["predict", "all"]:
        try:
            predictor_inst = PowerballPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Powerball: {e}")
            sys.exit(1)

    # 3. Ejecutar notificaciones
    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("powerball")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Powerball: {e}")

    print("✅ ¡Proceso completado exitosamente para Powerball!")

if __name__ == "__main__":
    main()
