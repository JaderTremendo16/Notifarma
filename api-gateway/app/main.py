# app/main.py

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from app.routers import proxy_router

app = FastAPI(title="API Gateway - NotiFarma", version="1.0.0")

# Permitir CORS para desarrollo y navegador web de Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(proxy_router.router)

@app.get("/")
def root():
    return {"message": "API Gateway corriendo 🚀"}


# ─── Swagger con botón Authorize ─────────────────────────────────────────────
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    schema = get_openapi(
        title="API Gateway - NotiFarma",
        version="1.0.0",
        description="Gateway unificado. Autentícate con tu email y contraseña para probar todos los servicios.",
        routes=app.routes,
    )

    # Declarar el esquema OAuth2 (botón verde Authorize)
    schema.setdefault("components", {})
    schema["components"]["securitySchemes"] = {
        "OAuth2PasswordBearer": {
            "type": "oauth2",
            "flows": {
                "password": {
                    "tokenUrl": "/auth/login",
                    "scopes": {}
                }
            }
        }
    }

    # Aplicar seguridad a todas las rutas excepto las públicas
    PUBLIC_PATHS = {"/", "/auth/register", "/auth/login", "/health/sintomas/catalogo"}
    for path, methods in schema.get("paths", {}).items():
        if path in PUBLIC_PATHS:
            continue
        for method_data in methods.values():
            method_data["security"] = [{"OAuth2PasswordBearer": []}]

    app.openapi_schema = schema
    return app.openapi_schema

app.openapi = custom_openapi