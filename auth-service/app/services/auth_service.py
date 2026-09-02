from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta
import os

# Config para passlib: para que use bcrypt como algoritmo
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY no está configurada")
ALGORITHM = "HS256"
EXPIRATION_DAYS= 7

def hash_password(password: str) -> str:
    return pwd_context.hash(password)
    

def verify_password(plain_password: str, hashed_password: str ) -> bool:
    return pwd_context.verify(plain_password, hashed_password)
    

def create_access_token(user_id:str, email:str, rol: str) -> str:

    # 1. Calcular la expiración (tiempo actual + 7 adías)
    expire = datetime.utcnow() + timedelta(days=EXPIRATION_DAYS)

    #2. Armar el diccionario payload
    payload = {"sub":str(user_id), "email":email, "rol":rol, "exp": expire }

    #3. Empaquetar el token
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def decode_access_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None