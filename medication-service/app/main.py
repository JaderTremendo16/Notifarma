# app/main.py

# Esto va de primero para cargar todos los datos del .env antes de cualquier import
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from app.database import Base, engine
from app.routers import medication_router

# Crea las tablas en la base de datos si no existen
Base.metadata.create_all(bind=engine)

# Instancia principal de la aplicación FastAPI
app = FastAPI(title="Medication Service")

app.include_router(medication_router.router)


# Endpoint para prueba rápida
@app.get("/")
def root():
    return {"message": "Medication Service corriendo correctamente."}
