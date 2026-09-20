class MedicationModel {
  final String id;
  final String pacienteId;
  final String nombre;
  final String? dosis;
  final int frecuenciaHoras;
  final String horaInicio;
  final String? fechaInicio;
  final String? fechaFin;
  final int stockActual;
  final int stockMinimoAlerta;
  final bool activo;

  MedicationModel({
    required this.id,
    required this.pacienteId,
    required this.nombre,
    this.dosis,
    required this.frecuenciaHoras,
    required this.horaInicio,
    this.fechaInicio,
    this.fechaFin,
    required this.stockActual,
    required this.stockMinimoAlerta,
    required this.activo,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      id: json['id'] ?? '',
      pacienteId: json['paciente_id'] ?? '',
      nombre: json['nombre'] ?? '',
      dosis: json['dosis'],
      frecuenciaHoras: json['frecuencia_horas'] ?? 12,
      horaInicio: json['hora_inicio'] ?? '08:00:00',
      fechaInicio: json['fecha_inicio'],
      fechaFin: json['fecha_fin'],
      stockActual: json['stock_actual'] ?? 0,
      stockMinimoAlerta: json['stock_minimo_alerta'] ?? 5,
      activo: json['activo'] ?? true,
    );
  }
}
