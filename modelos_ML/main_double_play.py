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

from src.double_play.scraper import DoublePlayScraper
from src.double_play.predictor import DoublePlayPredictor
from src.notification_generator import NotificationGenerator

def main():
    parser = argparse.ArgumentParser(description="Orquestador de Tareas ML para Double Play")
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
    print(f"Iniciando orquestación: Lotería=Double Play | Tarea={task}")
    print("==================================================")
    # 1. Ejecutar scraping
    if task in ["scrap", "all"]:
        try:
            scraper_inst = DoublePlayScraper()
            res_scrap = scraper_inst.run()

            hubo_sorteo = True
            ultimo_sorteo = None
            proximo_esperado = None

            if isinstance(res_scrap, dict):
                hubo_sorteo = res_scrap.get("hubo_sorteo", True)
                ultimo_sorteo = res_scrap.get("ultimo_sorteo")
                proximo_esperado = res_scrap.get("proximo_esperado")
            elif isinstance(res_scrap, tuple):
                hubo_sorteo = res_scrap[0]
                if len(res_scrap) > 1:
                    ultimo_sorteo = res_scrap[1]
                if len(res_scrap) > 2:
                    proximo_esperado = res_scrap[2]
            elif res_scrap is False:
                hubo_sorteo = False

            if hubo_sorteo is False:
                print("\n==================================================")
                print("ℹ️ No hay sorteo nuevo para procesar en Double Play.")
                if ultimo_sorteo:
                    print(f"📅 Último sorteo: {ultimo_sorteo}")
                if proximo_esperado:
                    print(f"🎯 Próximo sorteo esperado: {proximo_esperado}")
                print("✅ Finalizando ejecución con éxito (código 0).")
                print("==================================================\n")
                return

        except Exception as e:
            print(f"❌ Falló la tarea de scraping para Double Play: {e}")
            sys.exit(1)

    if task in ["predict", "all"]:
        try:
            predictor_inst = DoublePlayPredictor()
            predictor_inst.run()
        except Exception as e:
            print(f"❌ Falló la tarea de predicción para Double Play: {e}")
            sys.exit(1)

    if task in ["notify", "all"]:
        try:
            notif_inst = NotificationGenerator()
            notif_inst.run("double_play")
        except Exception as e:
            print(f"❌ Falló la tarea de notificaciones para Double Play: {e}")

    print("✅ ¡Proceso completado exitosamente para Double Play!")

if __name__ == "__main__":
    main()
