import argparse
import sys
from pathlib import Path

# Calculamos dinámicamente la raíz del proyecto (2 niveles arriba de donde está este main.py)
# Si main.py está en D:\pry_dataloto\modelos_ML\, PROJECT_ROOT será D:\pry_dataloto
PROJECT_ROOT = str(Path(__file__).resolve().parents[1])

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Dejamos también /opt/airflow por compatibilidad absoluta con los contenedores
if "/opt/airflow" not in sys.path:
    sys.path.append("/opt/airflow")

# Ahora sí, los imports funcionarán de forma idéntica en Docker y en Windows Local
from src.miloto.scraper import MilotoScraper
from src.miloto.predictor import MilotoPredictor
from src.baloto.scraper import BalotoScraper
from src.baloto.predictor import BalotoPredictor
#from src.colorloto.scraper import ColorLotoScraper
#from src.colorloto.predictor import ColorLotoPredictor

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Dataloto")
    parser.add_argument(
        "--loteria",
        type=str,
        default="all",
        choices=["miloto", "baloto"],
        help="El nombre de la lotería a procesar (default: all)"
    )
    parser.add_argument(
        "--task",
        type=str,
        default="all",
        choices=["scrap", "predict", "all"],
        help="La tarea a ejecutar (scraping, predicción o ambas) (default: all)"
    )

    args = parser.parse_args()
    loteria_arg = args.loteria
    task = args.task

    # Mapping of lottery identifiers to scraper and predictor classes
    scrapers = {
        "miloto": MilotoScraper,
        "baloto": BalotoScraper,
        # "colorloto": ColorLotoScraper,
    }
    predictors = {
        "miloto": MilotoPredictor,
        "baloto": BalotoPredictor,
        # "colorloto": ColorLotoPredictor,
    }
    
    # Determine which lotteries to process (default "all" runs every configured lottery)
    loterias = [loteria_arg] if loteria_arg != "all" else list(scrapers.keys())

    for loteria in loterias:
        print("==================================================")
        print(f"Iniciando orquestación: Lotería={loteria} | Tarea={task}")
        print("==================================================")

        # 1. Ejecutar scraping
        if task in ["scrap", "all"]:
            try:
                scraper_inst = scrapers[loteria]()
                scraper_inst.run()
            except Exception as e:
                print(f"❌ Falló la tarea de scraping para {loteria}: {e}")
                sys.exit(1)

        # 2. Ejecutar predicción
        if task in ["predict", "all"]:
            try:
                predictor_inst = predictors[loteria]()
                predictor_inst.run()
            except Exception as e:
                print(f"❌ Falló la tarea de predicción para {loteria}: {e}")
                sys.exit(1)

    print("✅ ¡Proceso completado exitosamente!")

if __name__ == "__main__":
    main()