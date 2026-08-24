import argparse
import sys
from pathlib import Path

# Calculamos dinámicamente la raíz del proyecto (2 niveles arriba de donde está este main.py)
# Si main.py está en D:\pry_dataloto\modelos_ML\, PROJECT_ROOT será D:\pry_dataloto
PROJECT_ROOT = str(Path(__file__).resolve().parents[1])

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

if "/opt/airflow" not in sys.path:
    sys.path.append("/opt/airflow")

# Ahora sí, los imports funcionarán de forma idéntica en Docker y en Windows Local
from src.miloto.scraper import MilotoScraper
from src.miloto.predictor import MilotoPredictor
from src.baloto.scraper import BalotoScraper
from src.baloto.predictor import BalotoPredictor
from src.powerball.scraper import PowerballScraper
from src.powerball.predictor import PowerballPredictor
from src.lotto_america.scraper import LottoAmericaScraper
from src.lotto_america.predictor import LottoAmericaPredictor
from src.double_play.scraper import DoublePlayScraper
from src.double_play.predictor import DoublePlayPredictor
from src.millionaire_life.scraper import MillionaireLifeScraper
from src.millionaire_life.predictor import MillionaireLifePredictor
from src.megamillions.scraper import MegaMillionsScraper
from src.megamillions.predictor import MegaMillionsPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Dataloto")
    parser.add_argument(
        "--loteria",
        type=str,
        default="all",
        choices=["miloto", "baloto", "powerball", "lotto_america", "double_play", "millionaire_life", "megamillions", "all"],
        help="El nombre de la lotería a procesar (default: all)"
    )
    parser.add_argument(
        "--task",
        type=str,
        default="all",
        choices=["scrap", "predict", "notify", "all"],
        help="La tarea a ejecutar (scraping, predicción, notificación o todas) (default: all)"
    )

    args, _ = parser.parse_known_args()
    loteria_arg = args.loteria
    task = args.task

    # Mapping of lottery identifiers to scraper and predictor classes
    scrapers = {
        "miloto": MilotoScraper,
        "baloto": BalotoScraper,
        "powerball": PowerballScraper,
        "lotto_america": LottoAmericaScraper,
        "double_play": DoublePlayScraper,
        "millionaire_life": MillionaireLifeScraper,
        "megamillions": MegaMillionsScraper,
    }
    predictors = {
        "miloto": MilotoPredictor,
        "baloto": BalotoPredictor,
        "powerball": PowerballPredictor,
        "lotto_america": LottoAmericaPredictor,
        "double_play": DoublePlayPredictor,
        "millionaire_life": MillionaireLifePredictor,
        "megamillions": MegaMillionsPredictor,
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

        # 3. Ejecutar notificaciones
        if task in ["notify", "all"]:
            try:
                notif_inst = NotificationGenerator()
                notif_inst.run(loteria)
            except Exception as e:
                print(f"❌ Falló la tarea de notificaciones para {loteria}: {e}")
                # No hacemos sys.exit(1) aquí para que no rompa el flujo si solo falló el mensaje

    print("✅ ¡Proceso completado exitosamente!")

if __name__ == "__main__":
    main()