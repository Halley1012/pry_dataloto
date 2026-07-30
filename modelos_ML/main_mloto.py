import argparse
import sys
from pathlib import Path

# Calculamos dinámicamente la raíz del proyecto (2 niveles arriba de donde está este script)
PROJECT_ROOT = str(Path(__file__).resolve().parents[1])

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Forzar salida de logs en tiempo real (sin buffer) para Airflow
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(line_buffering=True)

# Dejamos también /opt/airflow por compatibilidad absoluta con los contenedores
if "/opt/airflow" not in sys.path:
    sys.path.append("/opt/airflow")

from src.miloto.scraper import MilotoScraper
from src.miloto.predictor import MilotoPredictor

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para MiLoto")
    parser.add_argument(
        "--task",
        type=str,
        default="all",
        choices=["scrap", "predict", "all"],
        help="La tarea a ejecutar (scraping, predicción o ambas) (default: all)"
    )

    args, _ = parser.parse_known_args()
    task = args.task

    print("==================================================")
    print(f"Iniciando orquestación: Lotería=MiLoto | Tarea={task}")
    print("==================================================")

    # 1. Ejecutar scraping
    if task in ["scrap", "all"]:
        try:
            scraper_inst = MilotoScraper()
            scraper_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de scraping para miloto: {e}")
            sys.exit(1)

    # 2. Ejecutar predicción
    if task in ["predict", "all"]:
        try:
            predictor_inst = MilotoPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para miloto: {e}")
            sys.exit(1)

    print("✅ ¡Proceso completado exitosamente para MiLoto!")

if __name__ == "__main__":
    main()
