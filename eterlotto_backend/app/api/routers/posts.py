from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.api import schemas, dependencies
from app.application.post_use_cases import PostUseCases

router = APIRouter()

@router.post("/posts", response_model=schemas.PostResponse)
async def create_post(post: schemas.PostCreate, current_user: dict = Depends(dependencies.get_current_user), use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    user_id = int(current_user["user_id"])
    return await use_cases.crear_post(post.title, post.content, user_id)

@router.get("/posts", response_model=List[schemas.PostResponse])
async def get_posts(use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    return await use_cases.listar_posts()

@router.put("/posts/{post_id}", response_model=schemas.PostResponse)
async def update_post(post_id: int, post_update: schemas.PostCreate, current_user: dict = Depends(dependencies.get_current_user), use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    try:
        user_id = int(current_user["user_id"])
        return await use_cases.editar_post(post_id, post_update.title, post_update.content, user_id)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.delete("/posts/{post_id}")
async def delete_post(post_id: int, current_user: dict = Depends(dependencies.get_current_user), use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    try:
        user_id = int(current_user["user_id"])
        return await use_cases.eliminar_post(post_id, user_id)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.post("/posts/{post_id}/comments", response_model=schemas.CommentResponse)
async def create_comment(post_id: int, comment: schemas.CommentCreate, current_user: dict = Depends(dependencies.get_current_user), use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    try:
        user_id = int(current_user["user_id"])
        return await use_cases.crear_comentario(post_id, user_id, comment.content, comment.parent_id)
    except HTTPException:
        raise
    except (PermissionError, ValueError) as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.patch("/comments/{comment_id}", response_model=schemas.CommentResponse)
async def update_comment(comment_id: int, comment_update: schemas.CommentCreate, current_user: dict = Depends(dependencies.get_current_user), use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    try:
        user_id = int(current_user["user_id"])
        return await use_cases.editar_comentario(comment_id, user_id, comment_update.content)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.delete("/comments/{comment_id}")
async def delete_comment(comment_id: int, current_user: dict = Depends(dependencies.get_current_user), use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    try:
        user_id = int(current_user["user_id"])
        return await use_cases.eliminar_comentario(comment_id, user_id)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.get("/posts/{post_id}/comments", response_model=List[schemas.CommentResponse])
async def get_comments(post_id: int, use_cases: PostUseCases = Depends(dependencies.get_post_use_cases)):
    return await use_cases.listar_comentarios(post_id)


