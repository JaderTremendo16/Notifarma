class UserModel {
  final String id;
  final String nombres;
  final String email;
  final String rol;
  final int? edad;
  final String? contactoEmergenciaNombre;
  final String? contactoEmergenciaTelefono;
  final String? cuidadorId;

  UserModel({
    required this.id,
    required this.nombres,
    required this.email,
    required this.rol,
    this.edad,
    this.contactoEmergenciaNombre,
    this.contactoEmergenciaTelefono,
    this.cuidadorId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      nombres: json['nombres'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'paciente',
      edad: json['edad'],
      contactoEmergenciaNombre: json['contacto_emergencia_nombre'],
      contactoEmergenciaTelefono: json['contacto_emergencia_telefono'],
      cuidadorId: json['cuidador_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombres': nombres,
      'email': email,
      'rol': rol,
      'edad': edad,
      'contacto_emergencia_nombre': contactoEmergenciaNombre,
      'contacto_emergencia_telefono': contactoEmergenciaTelefono,
      'cuidador_id': cuidadorId,
    };
  }
}
