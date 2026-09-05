import logging
import contextvars

# Context variable para almacenar el request_id
request_id_ctx_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")

class RequestIdFilter(logging.Filter):
    def filter(self, record):
        record.request_id = request_id_ctx_var.get()
        return True

def setup_logging():
    log_format = "%(asctime)s | %(levelname)-8s | req_id=%(request_id)s | %(name)s | %(message)s"
    
    logging.basicConfig(
        level=logging.INFO,
        format=log_format,
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    
    root_logger = logging.getLogger()
    
    # Asegurarnos de que el filtro está en todos los handlers existentes
    for handler in root_logger.handlers:
        handler.addFilter(RequestIdFilter())
        handler.setFormatter(logging.Formatter(log_format, datefmt="%Y-%m-%d %H:%M:%S"))

    # Silenciar logs de httpx para no filtrar tokens en URLs
    logging.getLogger("httpx").setLevel(logging.WARNING)
