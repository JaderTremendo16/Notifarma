# app/main.py

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import proxy_router

app = FastAPI(title="API Gateway", version="1.0.0")

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