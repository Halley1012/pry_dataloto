import sys
import pandas as pd
from pathlib import Path
from sqlalchemy import text
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class NotificationGenerator:
    def __init__(self):
        self.engine = get_engine()

    def _get_mitad(self, loteria_key, pred_nums):
        lower = loteria_key.lower()
        if "powerball" in lower: return 34
        if "megamillions" in lower or "mega millions" in lower: return 35
        if "double play" in lower or "double_play" in lower: return 34
        if "lotto america" in lower or "lotto_america" in lower: return 26
        if "millionaire" in lower or "millionaire_life" in lower: return 29
        if "euromillones" in lower: return 25
        if "bonoloto" in lower: return 25
        if "primitiva" in lower: return 25
        if "gordo" in lower or "el_gordo" in lower: return 27
        if "miloto" in lower or "mloto" in lower: return 20
        if "colorloto" in lower: return 10
        if "megasena" in lower or "mega_sena" in lower: return 30
        if "maismilionaria" in lower or "milionaria" in lower: return 25
        if "melateretro" in lower or "melate_retro" in lower or "retro" in lower: return 20
        if "melate" in lower: return 28
        if "chispazo" in lower: return 14
        if "quina" in lower: return 40
        if "duplasena" in lower or "dupla_sena" in lower: return 25
        if "latinka" in lower or "tinka" in lower: return 25
        if "kabala" in lower: return 20
        if "ganadiario" in lower or "gana_diario" in lower: return 18
        if "5deoro" in lower or "cincodeoro" in lower or "oro" in lower: return 24
        return 21  # Default / Baloto

    def run(self, loteria="all"):
        print(f"🔔 Iniciando Generador de Notificaciones para: {loteria}")
        self.limpiar_notificaciones_antiguas()

        loterias_config = {
            "baloto": {
                "route": "bloto",
                "nombre": "Baloto",
                "tabla_resultados": "resultados_bloto",
                "query_resultados": "SELECT * FROM resultados_bloto WHERE sorteo = 'Baloto' AND balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 21,
                "has_special": True,
                "is_baloto": True,
            },
            "miloto": {
                "route": "mloto",
                "nombre": "Miloto",
                "tabla_resultados": "resultados_mloto",
                "query_resultados": "SELECT * FROM resultados_mloto WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 20,
                "has_special": False,
                "is_baloto": False,
            },
            "powerball": {
                "route": "powerball",
                "nombre": "Powerball",
                "tabla_resultados": "resultados_powerball",
                "query_resultados": "SELECT * FROM resultados_powerball WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 34,
                "has_special": True,
                "is_baloto": False,
            },
            "megamillions": {
                "route": "megamillions",
                "nombre": "Mega Millions",
                "tabla_resultados": "resultados_megamillions",
                "query_resultados": "SELECT * FROM resultados_megamillions WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 35,
                "has_special": True,
                "is_baloto": False,
            },
            "double_play": {
                "route": "double_play",
                "nombre": "Double Play",
                "tabla_resultados": "resultados_double_play",
                "query_resultados": "SELECT * FROM resultados_double_play WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 34,
                "has_special": True,
                "is_baloto": False,
            },
            "millionaire_life": {
                "route": "millionaire_life",
                "nombre": "Millionaire for Life",
                "tabla_resultados": "resultados_millionaire_life",
                "query_resultados": "SELECT * FROM resultados_millionaire_life WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 29,
                "has_special": True,
                "is_baloto": False,
            },
            "lotto_america": {
                "route": "lotto_america",
                "nombre": "Lotto America",
                "tabla_resultados": "resultados_lotto_america",
                "query_resultados": "SELECT * FROM resultados_lotto_america WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 26,
                "has_special": True,
                "is_baloto": False,
            },
            "euromillones": {
                "route": "euromillones",
                "nombre": "Euromillones",
                "tabla_resultados": "resultados_euromillones",
                "query_resultados": "SELECT * FROM resultados_euromillones WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 25,
                "has_special": True,
                "is_baloto": False,
            },
            "bonoloto": {
                "route": "bonoloto",
                "nombre": "Bonoloto",
                "tabla_resultados": "resultados_bonoloto",
                "query_resultados": "SELECT * FROM resultados_bonoloto WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 25,
                "has_special": True,
                "is_baloto": False,
            },
            "primitiva": {
                "route": "primitiva",
                "nombre": "La Primitiva",
                "tabla_resultados": "resultados_primitiva",
                "query_resultados": "SELECT * FROM resultados_primitiva WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 25,
                "has_special": True,
                "is_baloto": False,
            },
            "el_gordo": {
                "route": "el_gordo",
                "nombre": "El Gordo de la Primitiva",
                "tabla_resultados": "resultados_el_gordo",
                "query_resultados": "SELECT * FROM resultados_el_gordo WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 27,
                "has_special": True,
                "is_baloto": False,
            },
            "eurodreams": {
                "route": "eurodreams",
                "nombre": "EuroDreams",
                "tabla_resultados": "resultados_eurodreams",
                "query_resultados": "SELECT * FROM resultados_eurodreams WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 20,
                "has_special": True,
                "is_baloto": False,
            },
            "megasena": {
                "route": "megasena",
                "nombre": "Mega-Sena",
                "tabla_resultados": "resultados_megasena",
                "query_resultados": "SELECT * FROM resultados_megasena WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 30,
                "has_special": False,
                "is_baloto": False,
            },
            "maismilionaria": {
                "route": "maismilionaria",
                "nombre": "+Milionária",
                "tabla_resultados": "resultados_maismilionaria",
                "query_resultados": "SELECT * FROM resultados_maismilionaria WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 25,
                "has_special": True,
                "is_baloto": False,
            },
            "melate": {
                "route": "melate",
                "nombre": "Melate",
                "tabla_resultados": "resultados_melate",
                "query_resultados": "SELECT * FROM resultados_melate WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 28,
                "has_special": True,
                "is_baloto": False,
            },
            "melateretro": {
                "route": "melateretro",
                "nombre": "Melate Retro",
                "tabla_resultados": "resultados_melateretro",
                "query_resultados": "SELECT * FROM resultados_melateretro WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 20,
                "has_special": True,
                "is_baloto": False,
            },
            "chispazo": {
                "route": "chispazo",
                "nombre": "Chispazo",
                "tabla_resultados": "resultados_chispazo",
                "query_resultados": "SELECT * FROM resultados_chispazo WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 14,
                "has_special": False,
                "is_baloto": False,
            },
            "quina": {
                "route": "quina",
                "nombre": "Quina",
                "tabla_resultados": "resultados_quina",
                "query_resultados": "SELECT * FROM resultados_quina WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 40,
                "has_special": False,
                "is_baloto": False,
            },
            "duplasena": {
                "route": "duplasena",
                "nombre": "Dupla Sena",
                "tabla_resultados": "resultados_duplasena",
                "query_resultados": "SELECT * FROM resultados_duplasena WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 25,
                "has_special": False,
                "is_baloto": False,
            },
            "latinka": {
                "route": "latinka",
                "nombre": "La Tinka",
                "tabla_resultados": "resultados_latinka",
                "query_resultados": "SELECT * FROM resultados_latinka WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 25,
                "has_special": True,
                "is_baloto": False,
            },
            "kabala": {
                "route": "kabala",
                "nombre": "Kábala",
                "tabla_resultados": "resultados_kabala",
                "query_resultados": "SELECT * FROM resultados_kabala WHERE sorteo = 'Kábala' AND balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 20,
                "has_special": False,
                "is_baloto": False,
            },
            "ganadiario": {
                "route": "ganadiario",
                "nombre": "Gana Diario",
                "tabla_resultados": "resultados_ganadiario",
                "query_resultados": "SELECT * FROM resultados_ganadiario WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 18,
                "has_special": False,
                "is_baloto": False,
            },
            "5deoro": {
                "route": "5deoro",
                "nombre": "5 de Oro",
                "tabla_resultados": "resultados_5deoro",
                "query_resultados": "SELECT * FROM resultados_5deoro WHERE sorteo = '5 de Oro' AND balota1 > 0 ORDER BY fecha DESC LIMIT 1",
                "mitad": 24,
                "has_special": True,
                "is_baloto": False,
            },
        }

        if loteria == "all":
            for key, cfg in loterias_config.items():
                self.procesar_loteria(cfg)
        elif loteria in loterias_config:
            self.procesar_loteria(loterias_config[loteria])
        else:
            print(f"⚠️ Lotería desconocida: {loteria}")

    def limpiar_notificaciones_antiguas(self):
        try:
            with self.engine.connect() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS notificaciones (
                        id SERIAL PRIMARY KEY,
                        usuario_id INT,
                        loteria_id INT,
                        fecha_sorteo DATE,
                        mensaje TEXT,
                        tipo VARCHAR(50),
                        leido BOOLEAN DEFAULT FALSE,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                    DELETE FROM notificaciones 
                    WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '3 days';
                """))
                conn.commit()
                print("🧹 Purga de notificaciones antiguas (más de 3 días) completada.")
        except Exception as e:
            print(f"⚠️ Error al limpiar notificaciones antiguas: {e}")

    def procesar_loteria(self, cfg: dict):
        nombre_display = cfg["nombre"]
        route = cfg["route"]
        query_res = cfg["query_resultados"]
        mitad_default = cfg["mitad"]
        has_special = cfg.get("has_special", False)
        is_baloto = cfg.get("is_baloto", False)

        try:
            # 1. Obtener último resultado con balotas válidas
            res = pd.read_sql(query_res, self.engine)
            if res.empty:
                print(f"ℹ️ No hay resultados registrados para {nombre_display}")
                return

            fecha = res.iloc[0]['fecha']
            ganadores = set([int(res.iloc[0][f'balota{i}']) for i in range(1, 7) if f'balota{i}' in res.columns and pd.notna(res.iloc[0][f'balota{i}'])])
            super_ganadoras = set()
            for col in ['balotaroja', 'balotaroja2']:
                val = res.iloc[0].get(col, None)
                if pd.notna(val):
                    try:
                        super_ganadoras.add(int(val))
                    except (ValueError, TypeError):
                        pass

            # 2. Obtener predicción desde la tabla unificada 'predicciones'
            pred = pd.read_sql(
                text("SELECT * FROM predicciones WHERE LOWER(loteria_route) = :route AND fecha = :fecha"),
                self.engine,
                params={"route": route.lower(), "fecha": fecha}
            )

            # Fallback a la predicción más reciente <= fecha del sorteo
            if pred.empty:
                pred = pd.read_sql(
                    text("SELECT * FROM predicciones WHERE LOWER(loteria_route) = :route AND fecha <= :fecha ORDER BY fecha DESC LIMIT 1"),
                    self.engine,
                    params={"route": route.lower(), "fecha": fecha}
                )

            if pred.empty:
                print(f"⚠️ No se encontró predicción para {nombre_display} en la fecha {fecha}")
                return

            pred_nums = list(pred.iloc[0]['numeros'])
            pred_rojas_raw = pred.iloc[0].get('balotaroja', None)
            pred_rojas = list(pred_rojas_raw) if pred_rojas_raw is not None else []

            # 3. Obtener loteria_id dinámicamente desde la tabla loterias
            loteria_id = None
            try:
                with self.engine.connect() as conn:
                    lot_row = conn.execute(
                        text("SELECT id FROM loterias WHERE LOWER(route) = :r OR LOWER(nombre) = :n LIMIT 1"),
                        {"r": route.lower(), "n": nombre_display.lower()}
                    ).fetchone()
                    if lot_row:
                        loteria_id = lot_row[0]
            except Exception as e:
                print(f"⚠️ Error buscando loteria_id para {nombre_display}: {e}")

            if not loteria_id:
                loteria_id = cfg.get("loteria_id", 1)

            # 4. Calcular métricas de acierto
            mitad = self._get_mitad(route, pred_nums) or mitad_default
            top_mitad = set(pred_nums[:mitad])
            coincidencias = ganadores.intersection(top_mitad)

            # A. Casi! (Acierto parcial de 3 o más en el top de mayor probabilidad)
            if len(coincidencias) >= 3:
                nums_str = ', '.join(map(str, sorted(list(coincidencias))))
                msj = f"¡Casi! De los {mitad} números con mayor probabilidad generados por la IA para {nombre_display}, cayeron {len(coincidencias)} números ({nums_str})."
                self.guardar_notificacion(loteria_id, fecha, msj, "acierto_parcial")

            # B. Acierto directo en balota especial / Superbalota
            if has_special and super_ganadoras and len(pred_rojas) > 0:
                aciertos_esp = super_ganadoras.intersection(set(pred_rojas[:len(super_ganadoras)]))
                if len(aciertos_esp) > 0:
                    if is_baloto:
                        msj = "¡La IA acertó la Superbalota en el sorteo de hoy de Baloto!"
                    elif route == "euromillones":
                        msj = f"¡La IA acertó {'las 2 estrellas' if len(aciertos_esp) == 2 else '1 estrella'} ({', '.join(map(str, sorted(list(aciertos_esp))))}) en el sorteo de hoy de Euromillones!"
                    else:
                        msj = f"¡La IA acertó la balota especial en el sorteo de hoy de {nombre_display}!"
                    self.guardar_notificacion(loteria_id, fecha, msj, "acierto_directo")

            # C. Precisión general
            total_winning = len(ganadores) if len(ganadores) > 0 else 5
            efectividad = (len(coincidencias) / total_winning) * 100
            msj = f"En el sorteo de {nombre_display}, los {mitad} números más probables tuvieron una efectividad del {int(efectividad)}% ({len(coincidencias)} de {total_winning} aciertos)."
            self.guardar_notificacion(loteria_id, fecha, msj, "precision")

        except Exception as e:
            print(f"❌ Error procesando notificaciones {nombre_display}: {e}")
            import traceback
            print(traceback.format_exc())

    def guardar_notificacion(self, loteria_id, fecha, mensaje, tipo):
        try:
            with self.engine.connect() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS notificaciones (
                        id SERIAL PRIMARY KEY,
                        usuario_id INT,
                        loteria_id INT,
                        fecha_sorteo DATE,
                        mensaje TEXT,
                        tipo VARCHAR(50),
                        leido BOOLEAN DEFAULT FALSE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                """))
                conn.commit()

                # Reemplazar o actualizar si ya existe para esa lotería, fecha y tipo
                conn.execute(text("""
                    DELETE FROM notificaciones 
                    WHERE loteria_id = :l_id AND fecha_sorteo = :fecha AND tipo = :tipo
                """), {"l_id": loteria_id, "fecha": fecha, "tipo": tipo})
                conn.commit()

                conn.execute(text("""
                    INSERT INTO notificaciones (loteria_id, fecha_sorteo, mensaje, tipo)
                    VALUES (:l_id, :fecha, :msj, :tipo)
                """), {"l_id": loteria_id, "fecha": fecha, "msj": mensaje, "tipo": tipo})
                conn.commit()
                print(f"✅ Notificación guardada en DB ({tipo}): {mensaje}")
                
                # 🔥 Enviar Push Notification vía FCM segmentada por país
                self.enviar_fcm_push(loteria_id, mensaje, tipo)
        except Exception as e:
            print(f"❌ Error al guardar notificación: {e}")

    def enviar_fcm_push(self, loteria_id, mensaje, tipo):
        try:
            import firebase_admin
            from firebase_admin import credentials, messaging

            if not firebase_admin._apps:
                rutas_credenciales = [
                    PROJECT_ROOT / "config" / "firebase_credentials.json",
                    Path("/opt/airflow/pry_dataloto/modelos_ML/config/firebase_credentials.json"),
                    Path("firebase_credentials.json")
                ]
                
                cred_path = None
                for ruta in rutas_credenciales:
                    if ruta.exists():
                        cred_path = ruta
                        break
                
                if cred_path:
                    try:
                        cred = credentials.Certificate(str(cred_path))
                        firebase_admin.initialize_app(cred)
                        print("✅ Firebase inicializado con éxito.")
                    except Exception as e:
                        print(f"❌ Error al inicializar Firebase con archivo: {e}")
                else:
                    try:
                        firebase_admin.initialize_app()
                        print("✅ Firebase inicializado con configuración por defecto (ADC).")
                    except Exception as e:
                        print(f"❌ Falló inicialización por defecto de Firebase: {e}")

            if not firebase_admin._apps:
                return

            with self.engine.connect() as conn:
                # 1. Obtener el pais_id de la lotería
                lot_res = conn.execute(text("SELECT pais_id FROM loterias WHERE id = :l_id"), {"l_id": loteria_id}).fetchone()
                if not lot_res:
                    print(f"⚠️ No se encontró el país para la lotería {loteria_id}")
                    return
                
                target_pais_id = lot_res[0]
                
                # 2. Buscar tokens de usuarios en ese país
                res = conn.execute(text("SELECT fcm_token FROM users WHERE pais_id = :p_id AND fcm_token IS NOT NULL AND fcm_token != ''"), {"p_id": target_pais_id})
                tokens = [r[0] for r in res.fetchall() if r[0]]

            print(f"🔍 Segmentación: País {target_pais_id}. Tokens encontrados: {len(tokens)}")
            if not tokens:
                return

            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title="🍀 Eterlotto - Acierto IA",
                    body=mensaje,
                ),
                data={
                    "tipo": tipo,
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                },
                tokens=tokens,
            )
            response = messaging.send_each_for_multicast(message)
            print(f"📲 FCM Push enviada: {response.success_count} exitosas, {response.failure_count} fallidas.")
            
            if response.failure_count > 0:
                invalid_tokens = []
                for idx, resp in enumerate(response.responses):
                    if not resp.success:
                        print(f"   ❌ Error en token {idx}: {resp.exception}")
                        err_str = str(resp.exception)
                        if "NotRegistered" in err_str or "invalid-registration-token" in err_str or "registration-token-not-registered" in err_str:
                            invalid_tokens.append(tokens[idx])
                
                if invalid_tokens:
                    with self.engine.connect() as conn:
                        for bad_tok in invalid_tokens:
                            conn.execute(
                                text("UPDATE users SET fcm_token = NULL WHERE fcm_token = :tok"),
                                {"tok": bad_tok}
                            )
                        conn.commit()
                        print(f"🧹 Se limpiaron {len(invalid_tokens)} tokens FCM obsoletos de la base de datos.")
        except Exception as e:
            print(f"⚠️ FCM Error Crítico: {e}")
            import traceback
            print(traceback.format_exc())

if __name__ == "__main__":
    lot = sys.argv[1] if len(sys.argv) > 1 else "all"
    NotificationGenerator().run(lot)

