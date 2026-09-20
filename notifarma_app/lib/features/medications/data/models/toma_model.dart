class TomaModel {
  final String id;
  final String medicamentoId;
  final String pacienteId;
  final String fechaHoraProgramada;
  final String estado; // 'pendiente', 'tomado', 'omitido'
  final String? fechaHoraConfirmacion;

  TomaModel({
    required this.id,
    required this.medicamentoId,
    required this.pacienteId,
    required this.fechaHoraProgramada,
    required this.estado,
    this.fechaHoraConfirmacion,
  });

  factory TomaModel.fromJson(Map<String, dynamic> json) {
    return TomaModel(
      id: json['id'] ?? '',
      medicamentoId: json['medicamento_id'] ?? '',
      pacienteId: json['paciente_id'] ?? '',
      fechaHoraProgramada: json['fecha_hora_programada'] ?? '',
      estado: json['estado'] ?? 'pendiente',
      fechaHoraConfirmacion: json['fecha_hora_confirmacion'],
    );
  }
}
