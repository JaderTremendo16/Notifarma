
import random
import string
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user_model import User, RolUsuario, CodigoVinculacion
from app.schemas.user_schema import (
    UserCreate,
    UserLogin,
    UserResponse,
    GenerarCodigoResponse,
    VincularCodigoRequest,
)
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
        zona_horaria=user_data.zona_horaria or "America/Bogota",
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user


@router.post("/login")
async def login(request: Request, db: Session = Depends(get_db)):
    content_type = request.headers.get("content-type", "")

    if "application/x-www-form-urlencoded" in content_type:
        # Swagger Authorize button
        form = await request.form()
        email = form.get("username")
        password = form.get("password")
    else:
        # Flutter / Postman (JSON)
        body = await request.json()
        email = body.get("email")
        password = body.get("password")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Se requiere email y password")

    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

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


@router.get("/internal/zona-horaria/{user_id}")
def obtener_zona_horaria(user_id: str, db: Session = Depends(get_db)):
    """Retorna la zona horaria configurada del usuario (default: America/Bogota)."""
    usuario = db.query(User).filter(User.id == user_id).first()
    if not usuario or not usuario.zona_horaria:
        return {"zona_horaria": "America/Bogota"}
    return {"zona_horaria": usuario.zona_horaria}


# ─── Vinculación por Código (Flujo Bidireccional Accesible) ───────────────────

def _generar_codigo_unico(db: Session) -> str:
    """Genera un código corto único de 6 caracteres tipo 'NF-4829'."""
    caracteres = string.digits
    for _ in range(10):
        sufijo = "".join(random.choices(caracteres, k=4))
        codigo = f"NF-{sufijo}"
        if not db.query(CodigoVinculacion).filter(CodigoVinculacion.codigo == codigo).first():
            return codigo
    # Fallback alfanumérico si colisiona
    sufijo = "".join(random.choices(string.ascii_uppercase + string.digits, k=4))
    return f"NF-{sufijo}"


@router.post("/generar-codigo", response_model=GenerarCodigoResponse)
def generar_codigo_vinculacion(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """
    Genera un código de vinculación de 6 caracteres (ej: 'NF-4829') válido por 24 horas.
    Cualquiera de los dos roles (Paciente o Cuidador) puede generarlo para que la otra parte
    lo ingrese fácilmente en su aplicación.
    """
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    user_id = payload.get("sub")
    usuario = db.query(User).filter(User.id == user_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Si ya está vinculado, avisar
    if usuario.rol == RolUsuario.paciente and usuario.cuidador_id:
        raise HTTPException(status_code=400, detail="Este paciente ya tiene un cuidador vinculado")
    if usuario.rol == RolUsuario.cuidador:
        ya_vinculado = db.query(User).filter(User.cuidador_id == usuario.id).first()
        if ya_vinculado:
            raise HTTPException(status_code=400, detail="Este cuidador ya tiene un paciente vinculado")

    # Inactivar códigos previos no usados generados por este usuario
    db.query(CodigoVinculacion).filter(
        CodigoVinculacion.generador_id == usuario.id,
        CodigoVinculacion.usado == 0,
    ).update({"usado": 2})  # 2: cancelado/reemplazado

    codigo_str = _generar_codigo_unico(db)
    expiracion = datetime.utcnow() + timedelta(hours=24)

    nuevo_codigo = CodigoVinculacion(
        generador_id=usuario.id,
        rol_generador=usuario.rol,
        codigo=codigo_str,
        fecha_expiracion=expiracion,
        usado=0,
    )
    db.add(nuevo_codigo)
    db.commit()
    db.refresh(nuevo_codigo)

    return GenerarCodigoResponse(
        codigo=nuevo_codigo.codigo,
        rol_generador=nuevo_codigo.rol_generador,
        expira_en_minutos=1440,
        fecha_expiracion=nuevo_codigo.fecha_expiracion,
    )


@router.post("/vincular-codigo")
def vincular_por_codigo(
    datos: VincularCodigoRequest,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """
    Canjea el código de vinculación.
    Funciona bidireccionalmente:
    - Si el Paciente generó el código -> El Cuidador lo digita y se vincula.
    - Si el Cuidador generó el código -> El Paciente lo digita y se vincula.
    """
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    user_id = payload.get("sub")
    usuario_actual = db.query(User).filter(User.id == user_id).first()
    if not usuario_actual:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    codigo_norm = datos.codigo.strip().upper()
    registro_codigo = db.query(CodigoVinculacion).filter(
        CodigoVinculacion.codigo == codigo_norm,
        CodigoVinculacion.usado == 0,
    ).first()

    if not registro_codigo:
        raise HTTPException(status_code=404, detail="Código inválido o ya utilizado")

    if datetime.utcnow() > registro_codigo.fecha_expiracion:
        raise HTTPException(status_code=400, detail="El código ha expirado. Por favor genera uno nuevo")

    generador = db.query(User).filter(User.id == registro_codigo.generador_id).first()
    if not generador:
        raise HTTPException(status_code=404, detail="El usuario que generó el código no existe")

    # No se puede vincular consigo mismo o con su mismo rol
    if generador.id == usuario_actual.id:
        raise HTTPException(status_code=400, detail="No puedes vincularte con tu propio código")

    if generador.rol == usuario_actual.rol:
        raise HTTPException(status_code=400, detail="Ambos usuarios tienen el mismo rol. La vinculación debe ser entre un paciente y un cuidador")

    # Identificar quién es el paciente y quién es el cuidador
    if usuario_actual.rol == RolUsuario.cuidador and generador.rol == RolUsuario.paciente:
        cuidador = usuario_actual
        paciente = generador
    elif usuario_actual.rol == RolUsuario.paciente and generador.rol == RolUsuario.cuidador:
        cuidador = generador
        paciente = usuario_actual
    else:
        raise HTTPException(status_code=400, detail="Roles no compatibles para vinculación")

    # Validar que no tengan vínculos previos
    if paciente.cuidador_id:
        raise HTTPException(status_code=400, detail="El paciente ya tiene un cuidador vinculado")

    ya_ocupado = db.query(User).filter(User.cuidador_id == cuidador.id).first()
    if ya_ocupado:
        raise HTTPException(status_code=400, detail="Ese cuidador ya está vinculado a otro paciente")

    # Vincular
    paciente.cuidador_id = cuidador.id
    registro_codigo.usado = 1
    db.commit()
    db.refresh(paciente)

    return {
        "message": f"Vinculación exitosa entre paciente {paciente.nombres} y cuidador {cuidador.nombres}",
        "paciente_id": str(paciente.id),
        "cuidador_id": str(cuidador.id),
    }


@router.post("/cancelar-codigo")
def cancelar_codigo_vinculacion(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """
    Inactiva / revoca cualquier código de vinculación activo generado por el usuario autenticado.
    """
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    user_id = payload.get("sub")
    usuario = db.query(User).filter(User.id == user_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    afectados = db.query(CodigoVinculacion).filter(
        CodigoVinculacion.generador_id == usuario.id,
        CodigoVinculacion.usado == 0,
    ).update({"usado": 2})
    db.commit()

    return {"message": "Código cancelado correctamente", "codigos_cancelados": afectados}
