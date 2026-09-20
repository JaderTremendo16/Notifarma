# app/routers/proxy_router.py

from fastapi import APIRouter, Request, HTTPException, Response
import httpx

from app.services.jwt_service import decode_access_token
from app.config import (
    AUTH_SERVICE_URL,
    MEDICATION_SERVICE_URL,
    HEALTH_SERVICE_URL,
    NOTIFICATION_SERVICE_URL,
)

router = APIRouter()

PUBLIC_AUTH_PATHS = ["register", "login"]
PUBLIC_HEALTH_PATHS = ["sintomas/catalogo"]


def _extract_user_id(request: Request) -> str:
    """Valida el token Bearer y retorna el user_id (sub). Lanza 401 si no es válido."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Se requiere un token de autorización válido"
        )

    token = auth_header.split(" ")[1]
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Token inválido o expirado"
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail="Token no contiene identificador de usuario válido"
        )
    return str(user_id)


async def _forward_request(request: Request, target_url: str, user_id: str | None = None) -> Response:
    """Reenvía la petición al microservicio de destino inyectando X-User-Id si aplica."""
    headers = dict(request.headers)
    headers.pop("host", None)
    headers.pop("content-length", None)

    if user_id:
        headers["X-User-Id"] = user_id

    body = await request.body()
    query_params = dict(request.query_params)

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.request(
            method=request.method,
            url=target_url,
            headers=headers,
            params=query_params,
            content=body,
        )

    # Excluir cabeceras hop-by-hop o que puedan causar conflicto
    excluded_headers = {"content-encoding", "content-length", "transfer-encoding", "connection"}
    resp_headers = {
        k: v for k, v in response.headers.items()
        if k.lower() not in excluded_headers
    }

    return Response(
        content=response.content,
        status_code=response.status_code,
        headers=resp_headers,
        media_type=response.headers.get("content-type"),
    )


# ─── Auth Service Proxy ───────────────────────────────────────────────────────
@router.api_route("/auth/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy_auth(path: str, request: Request):
    if request.method == "OPTIONS":
        return Response(status_code=200)

    user_id = None
    if path not in PUBLIC_AUTH_PATHS:
        user_id = _extract_user_id(request)

    target_url = f"{AUTH_SERVICE_URL}/auth/{path}"
    return await _forward_request(request, target_url, user_id)


# ─── Medication Service Proxy ─────────────────────────────────────────────────
@router.api_route("/medications", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
@router.api_route("/medications/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy_medications(request: Request, path: str = ""):
    if request.method == "OPTIONS":
        return Response(status_code=200)

    user_id = None
    if not path.startswith("internal/"):
        user_id = _extract_user_id(request)

    subpath = f"/{path}" if path else ""
    target_url = f"{MEDICATION_SERVICE_URL}/medications{subpath}"
    return await _forward_request(request, target_url, user_id)


# ─── Health Service Proxy ─────────────────────────────────────────────────────
@router.api_route("/health/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy_health(path: str, request: Request):
    if request.method == "OPTIONS":
        return Response(status_code=200)

    user_id = None
    if path not in PUBLIC_HEALTH_PATHS:
        user_id = _extract_user_id(request)

    target_url = f"{HEALTH_SERVICE_URL}/health/{path}"
    return await _forward_request(request, target_url, user_id)


# ─── Notification Service Proxy ───────────────────────────────────────────────
@router.api_route("/notifications/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy_notifications(path: str, request: Request):
    if request.method == "OPTIONS":
        return Response(status_code=200)

    user_id = None
    if not path.startswith("internal/"):
        user_id = _extract_user_id(request)

    target_url = f"{NOTIFICATION_SERVICE_URL}/notifications/{path}"
    return await _forward_request(request, target_url, user_id)