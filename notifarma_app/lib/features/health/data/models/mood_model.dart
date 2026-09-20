class MoodModel {
  final String id;
  final String pacienteId;
  final String animo; // 'muy_bien', 'bien', 'regular', 'mal'
  final String fechaHora;

  MoodModel({
    required this.id,
    required this.pacienteId,
    required this.animo,
    required this.fechaHora,
  });

  factory MoodModel.fromJson(Map<String, dynamic> json) {
    return MoodModel(
      id: json['id'] ?? '',
      pacienteId: json['paciente_id'] ?? '',
      animo: json['animo'] ?? 'bien',
      fechaHora: json['fecha_hora'] ?? '',
    );
  }
}
