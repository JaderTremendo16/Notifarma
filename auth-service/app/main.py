# app/main.py}

#Esto va de primero para cargar todo los datos
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from app.database import Base, engine
from app.routers import auth_router




#Crea las tablas en la base de datos si no existen
Base.metadata.create_all(bind=engine)

#Instancia principal de la aplicación FastAPI
app = FastAPI(title="Auth Service")

app.include_router(auth_router.router)


#Enpoint para prueba rapida 

@app.get("/")
def root():
    return {"message": "Auth Service corriendo correctamente."}