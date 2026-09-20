class AppointmentModel {
  final String id;
  final String pacienteId;
  final String especialidad;
  final String? medico;
  final String? lugar;
  final String fechaHora;
  final String? notas;
  final bool activo;

  AppointmentModel({
    required this.id,
    required this.pacienteId,
    required this.especialidad,
    this.medico,
    this.lugar,
    required this.fechaHora,
    this.notas,
    required this.activo,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? '',
      pacienteId: json['paciente_id'] ?? '',
      especialidad: json['especialidad'] ?? '',
      medico: json['medico'],
      lugar: json['lugar'],
      fechaHora: json['fecha_hora'] ?? '',
      notas: json['notas'],
      activo: json['activo'] ?? true,
    );
  }
}
