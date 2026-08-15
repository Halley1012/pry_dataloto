import psycopg2.extras
from typing import Dict, Any, Optional
from app.domain.ports import TransactionRepositoryPort
from app.infrastructure import db_connection

class PostgresTransactionRepository(TransactionRepositoryPort):
    def create_transaction(self, referencia: str, nombre_cliente: str, email_cliente: str, monto: float, moneda: str, descripcion: str) -> int:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO transacciones (referencia, nombre_cliente, email_cliente, monto, moneda, descripcion, estado)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id;
                """, (referencia, nombre_cliente, email_cliente, monto, moneda, descripcion, "pendiente"))
                transaccion_id = cur.fetchone()["id"]
            conn.commit()
            return transaccion_id

    async def update_transaction_confirmation(self, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        # Usamos conexión sync como el original para confirmation, o podemos usar el pool.
        # El original usa psycopg2 síncrono. Respetemos eso.
        referencia = data.get("x_ref_payco")
        if not referencia:
            return None
        
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("""
                    UPDATE transacciones
                    SET estado = %s,
                        epayco_transaction_id = %s,
                        metodo_pago = %s,
                        monto = %s,
                        moneda = %s,
                        descripcion = %s,
                        email_cliente = %s,
                        nombre_cliente = %s,
                        respuesta_json = %s,
                        updated_at = NOW()
                    WHERE referencia = %s
                    RETURNING *;
                """, (
                    data.get("x_response"),
                    data.get("x_transaction_id"),
                    data.get("x_franchise"),
                    data.get("x_amount"),
                    data.get("x_currency_code"),
                    data.get("x_description"),
                    data.get("x_customer_email"),
                    data.get("x_customer_name"),
                    psycopg2.extras.Json(data),
                    referencia
                ))
                row = cur.fetchone()
            conn.commit()
            return row if row else None
