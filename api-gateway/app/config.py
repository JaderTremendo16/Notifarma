# app/config.py
import os

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000")

# Cada quien reemplaza el nombre de su contenedor y puerto cuando su servicio exista
MEDICATION_SERVICE_URL = os.getenv("MEDICATION_SERVICE_URL", "http://medication-service:8002")
HEALTH_SERVICE_URL = os.getenv("HEALTH_SERVICE_URL", "http://health-service:8003")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8004")