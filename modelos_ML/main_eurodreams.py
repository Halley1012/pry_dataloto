import argparse
import sys
from pathlib import Path

# Añadir el directorio raíz de modelos_ML al sys.path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from src.eurodreams.scraper import EuroDreamsScraper
from src.eurodreams.predictor import EuroDreamsPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador para EuroDreams (España / Europa)")
    parser.add_argument(
        "--task",
        type=str,
        default="all",
        choices=["scrap", "predict", "notify", "all"],
        help="Tarea a ejecutar: scrap, predict, notify, o all (por defecto)"
    )
    parser.add_argument(
        "--backfill",
        action="store_true",
        help="Si se activa, realiza una extracción histórica completa de los sorteos desde 2023."
    )

    args = parser.parse_args()

    print("=" * 50)
    print(f"Iniciando orquestación: Lotería=EuroDreams | Tarea={args.task} | Backfill={args.backfill}")
    print("=" * 50)

    # 1. Scraping
    if args.task in ["scrap", "all"]:
        scraper = EuroDreamsScraper()
        scraper.run(backfill=args.backfill)

    # 2. Predicción ML
    if args.task in ["predict", "all"]:
        predictor = EuroDreamsPredictor()
        predictor.run()

    # 3. Notificaciones
    if args.task in ["notify", "all"]:
        notificador = NotificationGenerator()
        cfg_eurodreams = {
            "nombre": "EuroDreams",
            "route": "eurodreams",
            "query_resultados": "SELECT * FROM resultados_eurodreams WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1;",
            "mitad": 20,
            "has_special": True,
            "is_baloto": False,
        }
        notificador.procesar_loteria(cfg_eurodreams)

    print("✅ ¡Proceso completado exitosamente para EuroDreams!")

if __name__ == "__main__":
    main()
