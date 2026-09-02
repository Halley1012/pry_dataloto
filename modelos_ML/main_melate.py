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

from src.melate.scraper import MelateScraper
from src.melate.predictor import MelatePredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Melate (México)")
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
    print(f"Iniciando orquestación: Lotería=Melate | Tarea={task} | Backfill={backfill}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = MelateScraper()
            hubo_sorteo = scraper_inst.run(backfill=backfill)
            if hubo_sorteo is False:
                print("No se encontraron sorteos nuevos. Terminando DAG exitosamente.")
                try:
                    from airflow.exceptions import AirflowSkipException
                    raise AirflowSkipException("No se encontraron sorteos nuevos.")
                except ImportError:
                    return

        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Melate: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = MelatePredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Melate: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("melate")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Melate: {e}")

    print("✅ ¡Proceso completado exitosamente para Melate!")

if __name__ == "__main__":
    main()
