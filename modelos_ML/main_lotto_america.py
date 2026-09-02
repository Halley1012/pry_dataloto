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

from src.lotto_america.scraper import LottoAmericaScraper
from src.lotto_america.predictor import LottoAmericaPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Lotto America")
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
    print(f"Iniciando orquestación: Lotería=Lotto America | Tarea={task}")
    print("==================================================")

    if task in ["scrap", "all"]:
        try:
            scraper_inst = LottoAmericaScraper()
            hubo_sorteo = scraper_inst.run()
            if hubo_sorteo is False:
                print('No se encontraron sorteos nuevos. Terminando DAG exitosamente.')
                try:
                    from airflow.exceptions import AirflowSkipException
                    raise AirflowSkipException("No se encontraron sorteos nuevos.")
                except ImportError:
                    return

        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Lotto America: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = LottoAmericaPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Lotto America: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("lotto_america")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Lotto America: {e}")

    print("✅ ¡Proceso completado exitosamente para Lotto America!")

if __name__ == "__main__":
    main()
