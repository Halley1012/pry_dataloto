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

from src.millionaire_life.scraper import MillionaireLifeScraper
from src.millionaire_life.predictor import MillionaireLifePredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Millionaire for Life")
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
    print(f"Iniciando orquestación: Lotería=Millionaire for Life | Tarea={task}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = MillionaireLifeScraper()
            hubo_sorteo = scraper_inst.run()
            if hubo_sorteo is False:
                print('No se encontraron sorteos nuevos. Terminando DAG exitosamente.')
                sys.exit(0)
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Millionaire for Life: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = MillionaireLifePredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Millionaire for Life: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("millionaire_life")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Millionaire for Life: {e}")

    print("✅ ¡Proceso completado exitosamente para Millionaire for Life!")

if __name__ == "__main__":
    main()
