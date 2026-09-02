# app/main.py

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from app.routers import proxy_router

app = FastAPI(title="API Gateway", version="1.0.0")

app.include_router(proxy_router.router)

@app.get("/")
def root():
    return {"message": "API Gateway corriendo 🚀"}