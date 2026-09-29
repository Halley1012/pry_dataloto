from fastapi import APIRouter, Depends, HTTPException, File, Form, UploadFile
from typing import Optional
import os
import uuid
from urllib.parse import quote

import httpx
from app.api import schemas, dependencies
from app.application.publicidad_use_cases import PublicidadUseCases

router = APIRouter()


_ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "image/heif": ".heif",
}
_MAX_IMAGE_BYTES = 2 * 1024 * 1024  # 2 MB tras compresión en Flutter


@router.post("/publicidad/upload-image")
async def upload_publicidad_image(
    file: UploadFile = File(...),
    tipo: str = Form("galeria"),
    current_user: dict = Depends(dependencies.get_current_user),
):
    """Sube una imagen de publicidad a Supabase Storage.

    La clave secreta vive únicamente en el backend. El cliente nunca recibe
    credenciales de Storage; sólo la URL pública resultante.
    """
    user_id = int(current_user["user_id"])
    content_type = (file.content_type or "").lower().strip()
    extension = _ALLOWED_IMAGE_TYPES.get(content_type)

    # `http.MultipartFile.fromPath()` puede enviar archivos seleccionados desde
    # Android como application/octet-stream. En ese caso resolvemos el tipo por
    # la extensión real del nombre del archivo, en vez de rechazar una imagen válida.
    if extension is None:
        filename = (file.filename or "").lower().strip()
        suffix_map = {
            ".jpg": ("image/jpeg", ".jpg"),
            ".jpeg": ("image/jpeg", ".jpg"),
            ".png": ("image/png", ".png"),
            ".webp": ("image/webp", ".webp"),
            ".heic": ("image/heic", ".heic"),
            ".heif": ("image/heif", ".heif"),
        }
        matched = next(
            (
                (mime, ext)
                for suffix, (mime, ext) in suffix_map.items()
                if filename.endswith(suffix)
            ),
            None,
        )
        if matched is not None:
            content_type, extension = matched

    if extension is None:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Formato no permitido ({file.content_type or 'sin MIME'}). "
                "Usa JPG, PNG, WEBP, HEIC o HEIF."
            ),
        )

    payload = await file.read(_MAX_IMAGE_BYTES + 1)
    if len(payload) > _MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="La imagen supera el máximo de 2 MB.",
        )
    if not payload:
        raise HTTPException(status_code=400, detail="La imagen está vacía.")

    supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    secret_key = (
        os.getenv("SUPABASE_SECRET_KEY")
        or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or ""
    ).strip()
    bucket = (os.getenv("SUPABASE_STORAGE_BUCKET") or "publicidad").strip()

    if not supabase_url or not secret_key or not bucket:
        raise HTTPException(
            status_code=503,
            detail="Storage de publicidad no está configurado.",
        )

    safe_tipo = "principal" if tipo == "principal" else "galeria"
    object_path = f"user_{user_id}/{safe_tipo}/{uuid.uuid4().hex}{extension}"
    encoded_path = quote(object_path, safe="/")
    upload_url = f"{supabase_url}/storage/v1/object/{bucket}/{encoded_path}"

    headers = {
        "apikey": secret_key,
        "Authorization": f"Bearer {secret_key}",
        "Content-Type": content_type,
        "x-upsert": "false",
    }

    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.post(upload_url, headers=headers, content=payload)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"No fue posible conectar con Storage: {exc}",
        ) from exc

    if response.status_code not in (200, 201):
        detail = response.text[:500]
        raise HTTPException(
            status_code=502,
            detail=f"Storage rechazó la imagen: {detail}",
        )

    public_url = (
        f"{supabase_url}/storage/v1/object/public/{bucket}/{encoded_path}"
    )
    return {
        "success": True,
        "url": public_url,
        "path": object_path,
        "tipo": safe_tipo,
    }

@router.get("/publicidad")
async def listar_publicidad(
    query: schemas.PublicidadQuery = Depends(),
    current_user: Optional[dict] = Depends(dependencies.get_optional_current_user),
    use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)
):
    user_id = None
    if current_user and current_user.get("user_id"):
        try:
            user_id = int(current_user["user_id"])
        except (ValueError, TypeError):
            pass

    filters = {
        "pais_id": query.pais_id,
        "departamento_id": query.departamento_id,
        "ciudad_id": query.ciudad_id,
        "categoria_id": query.categoria_id,
        "titulo": query.titulo,
        "user_id": user_id
    }
    try:
        return await use_cases.listar_publicidad(filters, query.limit, query.offset)
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/publicidad")
async def crear_publicidad(request: schemas.PublicidadCreate, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.crear_publicidad(user_id, request.dict(exclude_unset=True))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.delete("/publicidad/{publicidad_id}")
async def eliminar_publicidad(publicidad_id: int, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.eliminar_publicidad(publicidad_id, user_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.put("/publicidad/{publicidad_id}/aprobar")
async def aprobar_publicidad(
    publicidad_id: int, 
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)
):
    try:
        user_id = int(current_user["user_id"])
        return await use_cases.aprobar_publicidad(publicidad_id, admin_user_id=user_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/mis_publicidades")
async def listar_mis_publicidades(current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = current_user.get("user_id")
    try:
        user_id = int(user_id)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="ID de usuario inválido")
    try:
        return await use_cases.listar_mis_publicidades(user_id)
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.put("/publicidad/{id}")
async def actualizar_publicidad(id: int, request: dict, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.actualizar_publicidad(id, user_id, request)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/publicidad/{id}/favorito")
async def toggle_favorito_publicidad(id: int, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.toggle_favorito(user_id, id)
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/publicidad/{id}/calificar")
async def calificar_publicidad(id: int, request: dict, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    estrellas = int(request.get("estrellas", 5))
    try:
        return await use_cases.calificar_publicidad(user_id, id, estrellas)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")



