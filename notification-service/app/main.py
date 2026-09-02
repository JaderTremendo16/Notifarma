# app/main.py

# Esto va de primero para cargar todo los datos del .env
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from app.database import Base, engine
from app.routers import notification_router
from app.services.scheduler_service import iniciar_scheduler, detener_scheduler

# Crea las tablas en la base de datos si no existen
Base.metadata.create_all(bind=engine)

# Instancia principal de la aplicación FastAPI
app = FastAPI(title="Notification Service")

app.include_router(notification_router.router)


@app.on_event("startup")
def on_startup():
    iniciar_scheduler()


@app.on_event("shutdown")
def on_shutdown():
    detener_scheduler()


# Endpoint para prueba rápida
@app.get("/")
def root():
    return {"message": "Notification Service corriendo correctamente."}
