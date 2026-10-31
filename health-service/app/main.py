# app/main.py

# Esto va de primero para cargar todos los datos del .env antes de cualquier import
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from app.database import Base, engine, SessionLocal
from app.routers import health_router
# Crea las tablas en la base de datos si no existen
Base.metadata.create_all(bind=engine)

# Instancia principal de la aplicacion FastAPI
app = FastAPI(title="Health Service")

app.include_router(health_router.router)


# Endpoint para prueba rapida
@app.get("/")
def root():
    return {"message": "Health Service corriendo correctamente."}
