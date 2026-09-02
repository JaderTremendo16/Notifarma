# app/main.py

# Esto va de primero para cargar todos los datos del .env antes de cualquier import
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from app.database import Base, engine, SessionLocal
from app.routers import health_router
from app.models.health_model import Sintoma

# Crea las tablas en la base de datos si no existen
Base.metadata.create_all(bind=engine)

# Instancia principal de la aplicacion FastAPI
app = FastAPI(title="Health Service")

app.include_router(health_router.router)


# Catalogo fijo de sintomas — se precarga una sola vez si la tabla esta vacia
SINTOMAS_INICIALES = [
    "Dolor de cabeza",
    "Fatiga",
    "Mareo",
    "Nauseas",
    "Dolor muscular",
]

@app.on_event("startup")
def precargar_catalogo_sintomas():
    """Inserta los sintomas del catalogo fijo si la tabla esta vacia."""
    db = SessionLocal()
    try:
        if db.query(Sintoma).count() == 0:
            for nombre in SINTOMAS_INICIALES:
                db.add(Sintoma(nombre=nombre))
            db.commit()
    finally:
        db.close()


# Endpoint para prueba rapida
@app.get("/")
def root():
    return {"message": "Health Service corriendo correctamente."}
