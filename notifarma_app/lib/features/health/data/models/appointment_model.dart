class AppointmentModel {
  final String id;
  final String pacienteId;
  final String especialidad;
  final String? medico;
  final String? lugar;
  final String? direccion;
  final String fechaHora;
  final String? notas;
  final String estado; // "programada", "asistida", "no_asistida", "sin_confirmar"
  final bool activo;

  AppointmentModel({
    required this.id,
    required this.pacienteId,
    required this.especialidad,
    this.medico,
    this.lugar,
    this.direccion,
    required this.fechaHora,
    this.notas,
    this.estado = 'programada',
    required this.activo,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? '',
      pacienteId: json['paciente_id'] ?? '',
      especialidad: json['especialidad'] ?? '',
      medico: json['medico'],
      lugar: json['lugar'],
      direccion: json['direccion'],
      fechaHora: json['fecha_hora'] ?? '',
      notas: json['notas'],
      estado: json['estado'] ?? 'programada',
      activo: json['activo'] ?? true,
    );
  }
}
