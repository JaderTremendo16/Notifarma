import 'package:notifarma_app/core/network/api_client.dart';
import 'package:notifarma_app/features/medications/data/models/medication_model.dart';
import 'package:notifarma_app/features/medications/data/models/toma_model.dart';

class MedicationRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<MedicationModel>> getActiveMedications() async {
    final response = await _apiClient.get('/medications');
    if (response is List) {
      return response.map((e) => MedicationModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getProximoMedicamento() async {
    try {
      final response = await _apiClient.get('/medications/proximo');
      return response as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<MedicationModel> createMedication({
    required String nombre,
    String? dosis,
    required int frecuenciaHoras,
    required String horaInicio,
    String? fechaInicio,
    String? fechaFin,
    int stockActual = 30,
    int stockMinimoAlerta = 5,
  }) async {
    final response = await _apiClient.post(
      '/medications',
      body: {
        'nombre': nombre,
        'dosis': dosis,
        'frecuencia_horas': frecuenciaHoras,
        'hora_inicio': horaInicio,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'stock_actual': stockActual,
        'stock_minimo_alerta': stockMinimoAlerta,
      },
    );
    return MedicationModel.fromJson(response);
  }

  Future<TomaModel> registrarToma(String medId, String estado) async {
    final response = await _apiClient.post(
      '/medications/$medId/tomas',
      body: {'estado': estado},
    );
    return TomaModel.fromJson(response);
  }

  Future<List<TomaModel>> getHistorialTomas() async {
    final response = await _apiClient.get('/medications/tomas/historial');
    if (response is List) {
      return response.map((e) => TomaModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<MedicationModel> updateStock(
    String medId,
    int stockActual, {
    int? stockMinimo,
  }) async {
    final response = await _apiClient.patch(
      '/medications/$medId/stock',
      body: {
        'stock_actual': stockActual,
        'stock_minimo_alerta': ?stockMinimo,
      },
    );
    return MedicationModel.fromJson(response);
  }
}
