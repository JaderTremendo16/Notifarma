
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user_model import User, RolUsuario
from app.schemas.user_schema import UserCreate, UserLogin, UserResponse
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])
# Esto le dice a FastAPI de dónde espera sacar el token en /me
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

@router.post("/register", response_model=UserResponse)
def register(user_data: UserCreate, db: Session = Depends(get_db)):

    #Validar que no existe un correo
    user_exists = db.query(User).filter(User.email == user_data.email).first()
    if user_exists:
        raise HTTPException(
            status_code=400, detail="El correo ya se encuentra registrado"
        )

    # Hashear la contraseña
    hashed_pwd = hash_password(user_data.password)

    # Crear y guardar objeto
    new_user = User(
        nombres=user_data.nombres,
        email=user_data.email,
        rol=user_data.rol,
        password_hash=hashed_pwd,
        edad=user_data.edad,
        contacto_emergencia_nombre=user_data.contacto_emergencia_nombre,
        contacto_emergencia_telefono=user_data.contacto_emergencia_telefono,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

@router.post("/login")
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    # Buscar por email
    user = db.query(User).filter(User.email == credentials.email).first()

    # Validar usuario y contraseña
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=401, detail="Credenciales incorrectas"
        )

    # Generar y devolver token
    token = create_access_token(user_id=str(user.id), email=user.email, rol=user.rol.value)
    return {"access_token": token, "token_type": "bearer"}


@router.get("/me", response_model=UserResponse)
def me(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    # Decodificar token y extraer ID
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirable")

    user_id = payload.get("sub")

    # Buscar usuario por ID y devolverlo
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    return user
    pass 

@router.post("/vincular-cuidador")
def vincular_cuidador(
    email_cuidador: str,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    # 1. decodificar el token para saber quién es el paciente (el que está pidiendo esto)
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido")

    paciente_id = payload.get("sub")
    paciente = db.query(User).filter(User.id == paciente_id).first()

    # 2. buscar al cuidador por su email
    cuidador = db.query(User).filter(
        User.email == email_cuidador, User.rol == RolUsuario.cuidador
    ).first()
    if not cuidador:
        raise HTTPException(status_code=404, detail="Cuidador no encontrado")

    # 3. verificar que ese cuidador no esté ya vinculado a otro paciente
    ya_vinculado = db.query(User).filter(User.cuidador_id == cuidador.id).first()
    if ya_vinculado:
        raise HTTPException(status_code=400, detail="Ese cuidador ya está vinculado a otro paciente")

    # 4. vincular
    paciente.cuidador_id = cuidador.id
    db.commit()
    db.refresh(paciente)

    return {"message": f"Cuidador {cuidador.nombres} vinculado correctamente"}


@router.get("/internal/cuidador-de/{paciente_id}")
def obtener_cuidador_de_paciente(paciente_id: str, db: Session = Depends(get_db)):
    """
    Endpoint interno (sin JWT) para que otros microservicios (como Notification Service)
    consulten si un paciente tiene un cuidador vinculado.
    """
    user = db.query(User).filter(User.id == paciente_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")

    return {"cuidador_id": str(user.cuidador_id) if user.cuidador_id else None}


@router.get("/cuidador/mi-paciente", response_model=UserResponse)
def obtener_mi_paciente(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """
    Permite a un usuario con rol 'cuidador' obtener los datos de su paciente a cargo.
    """
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    cuidador_id = payload.get("sub")
    paciente = db.query(User).filter(User.cuidador_id == cuidador_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="No tienes ningún paciente vinculado")

    return paciente


@router.get("/internal/paciente-de/{cuidador_id}")
def obtener_paciente_de_cuidador(cuidador_id: str, db: Session = Depends(get_db)):
    """
    Endpoint interno (sin JWT) para que otros servicios (como Medication Service)
    obtengan el paciente_id asignado a un cuidador_id.
    """
    paciente = db.query(User).filter(User.cuidador_id == cuidador_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado para este cuidador")

    return {"paciente_id": str(paciente.id)}
