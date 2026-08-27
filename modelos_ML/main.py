import argparse
import sys
from pathlib import Path

# Calculamos dinámicamente la raíz del proyecto (2 niveles arriba de donde está este main.py)
PROJECT_ROOT = str(Path(__file__).resolve().parents[1])

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

if "/opt/airflow" not in sys.path:
    sys.path.append("/opt/airflow")

# Imports de Scrapers y Predictors
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
from src.bonoloto.scraper import BonolotoScraper
from src.bonoloto.predictor import BonolotoPredictor
from src.primitiva.scraper import PrimitivaScraper
from src.primitiva.predictor import PrimitivaPredictor
from src.el_gordo.scraper import ElGordoScraper
from src.el_gordo.predictor import ElGordoPredictor
from src.euromillones.scraper import EuromillonesScraper
from src.euromillones.predictor import EuromillonesPredictor
from src.eurodreams.scraper import EurodreamsScraper
from src.eurodreams.predictor import EurodreamsPredictor
from src.megasena.scraper import MegasenaScraper
from src.megasena.predictor import MegasenaPredictor
from src.maismilionaria.scraper import MaisMilionariaScraper
from src.maismilionaria.predictor import MaisMilionariaPredictor
from src.duplasena.scraper import DuplaSenaScraper
from src.duplasena.predictor import DuplaSenaPredictor
from src.quina.scraper import QuinaScraper
from src.quina.predictor import QuinaPredictor
from src.melate.scraper import MelateScraper
from src.melate.predictor import MelatePredictor
from src.melateretro.scraper import MelateRetroScraper
from src.melateretro.predictor import MelateRetroPredictor
from src.chispazo.scraper import ChispazoScraper
from src.chispazo.predictor import ChispazoPredictor
from src.latinka.scraper import LatinkaScraper
from src.latinka.predictor import LatinkaPredictor
from src.kabala.scraper import KabalaScraper
from src.kabala.predictor import KabalaPredictor
from src.ganadiario.scraper import GanadiarioScraper
from src.ganadiario.predictor import GanadiarioPredictor
from src.cincodeoro.scraper import CincoDeOroScraper
from src.cincodeoro.predictor import CincoDeOroPredictor
from src.lotto_cr.scraper import LottoCostaRicaScraper
from src.lotto_cr.predictor import LottoCostaRicaPredictor

from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador Global de Tareas ML para Eterlotto")
    parser.add_argument(
        "--loteria",
        type=str,
        default="all",
        choices=[
            "miloto", "baloto", "powerball", "lotto_america", "double_play", "millionaire_life", "megamillions",
            "bonoloto", "primitiva", "el_gordo", "euromillones", "eurodreams",
            "megasena", "maismilionaria", "duplasena", "quina",
            "melate", "melateretro", "chispazo",
            "latinka", "kabala", "ganadiario",
            "5deoro", "lotto_cr", "all"
        ],
        help="El nombre de la lotería a procesar (default: all)"
    )
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
    loteria_arg = args.loteria
    task = args.task
    backfill = args.backfill

    # Mapping of lottery identifiers to scraper and predictor classes
    scrapers = {
        "miloto": MilotoScraper,
        "baloto": BalotoScraper,
        "powerball": PowerballScraper,
        "lotto_america": LottoAmericaScraper,
        "double_play": DoublePlayScraper,
        "millionaire_life": MillionaireLifeScraper,
        "megamillions": MegaMillionsScraper,
        "bonoloto": BonolotoScraper,
        "primitiva": PrimitivaScraper,
        "el_gordo": ElGordoScraper,
        "euromillones": EuromillonesScraper,
        "eurodreams": EurodreamsScraper,
        "megasena": MegasenaScraper,
        "maismilionaria": MaisMilionariaScraper,
        "duplasena": DuplaSenaScraper,
        "quina": QuinaScraper,
        "melate": MelateScraper,
        "melateretro": MelateRetroScraper,
        "chispazo": ChispazoScraper,
        "latinka": LatinkaScraper,
        "kabala": KabalaScraper,
        "ganadiario": GanadiarioScraper,
        "5deoro": CincoDeOroScraper,
        "lotto_cr": LottoCostaRicaScraper,
    }
    predictors = {
        "miloto": MilotoPredictor,
        "baloto": BalotoPredictor,
        "powerball": PowerballPredictor,
        "lotto_america": LottoAmericaPredictor,
        "double_play": DoublePlayPredictor,
        "millionaire_life": MillionaireLifePredictor,
        "megamillions": MegaMillionsPredictor,
        "bonoloto": BonolotoPredictor,
        "primitiva": PrimitivaPredictor,
        "el_gordo": ElGordoPredictor,
        "euromillones": EuromillonesPredictor,
        "eurodreams": EurodreamsPredictor,
        "megasena": MegasenaPredictor,
        "maismilionaria": MaisMilionariaPredictor,
        "duplasena": DuplaSenaPredictor,
        "quina": QuinaPredictor,
        "melate": MelatePredictor,
        "melateretro": MelateRetroPredictor,
        "chispazo": ChispazoPredictor,
        "latinka": LatinkaPredictor,
        "kabala": KabalaPredictor,
        "ganadiario": GanadiarioPredictor,
        "5deoro": CincoDeOroPredictor,
        "lotto_cr": LottoCostaRicaPredictor,
    }
    
    # Determine which lotteries to process (default "all" runs every configured lottery)
    loterias = [loteria_arg] if loteria_arg != "all" else list(scrapers.keys())

    for loteria in loterias:
        print("==================================================")
        print(f"Iniciando orquestación: Lotería={loteria} | Tarea={task} | Backfill={backfill}")
        print("==================================================")

        # 1. Ejecutar scraping
        if task in ["scrap", "all"]:
            try:
                scraper_inst = scrapers[loteria]()
                # Check if run supports backfill argument
                import inspect
                if 'backfill' in inspect.signature(scraper_inst.run).parameters:
                    scraper_inst.run(backfill=backfill)
                else:
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