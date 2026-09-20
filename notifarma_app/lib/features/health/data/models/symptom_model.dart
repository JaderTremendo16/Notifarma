class SymptomCatalogModel {
  final String id;
  final String nombre;

  SymptomCatalogModel({required this.id, required this.nombre});

  factory SymptomCatalogModel.fromJson(Map<String, dynamic> json) {
    return SymptomCatalogModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
    );
  }
}

class RegisteredSymptomModel {
  final String id;
  final String pacienteId;
  final String? sintomaId;
  final String? sintomaOtro;
  final String intensidad; // 'leve', 'moderada', 'fuerte'
  final String? observacion;
  final String fechaHora;

  RegisteredSymptomModel({
    required this.id,
    required this.pacienteId,
    this.sintomaId,
    this.sintomaOtro,
    required this.intensidad,
    this.observacion,
    required this.fechaHora,
  });

  factory RegisteredSymptomModel.fromJson(Map<String, dynamic> json) {
    return RegisteredSymptomModel(
      id: json['id'] ?? '',
      pacienteId: json['paciente_id'] ?? '',
      sintomaId: json['sintoma_id'],
      sintomaOtro: json['sintoma_otro'],
      intensidad: json['intensidad'] ?? 'leve',
      observacion: json['observacion'],
      fechaHora: json['fecha_hora'] ?? '',
    );
  }
}
