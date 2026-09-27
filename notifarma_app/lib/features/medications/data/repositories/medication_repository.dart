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

  Future<MedicationModel> updateMedication(
    String medId, {
    String? nombre,
    String? dosis,
    int? frecuenciaHoras,
    String? horaInicio,
    int? stockActual,
    int? stockMinimoAlerta,
  }) async {
    final Map<String, dynamic> body = {};
    if (nombre != null) body['nombre'] = nombre;
    if (dosis != null) body['dosis'] = dosis;
    if (frecuenciaHoras != null) body['frecuencia_horas'] = frecuenciaHoras;
    if (horaInicio != null) body['hora_inicio'] = horaInicio;
    if (stockActual != null) body['stock_actual'] = stockActual;
    if (stockMinimoAlerta != null) body['stock_minimo_alerta'] = stockMinimoAlerta;

    final response = await _apiClient.put(
      '/medications/$medId',
      body: body,
    );
    return MedicationModel.fromJson(response);
  }

  Future<bool> deleteMedication(String medId) async {
    await _apiClient.delete('/medications/$medId');
    return true;
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
    final Map<String, dynamic> body = {
      'stock_actual': stockActual,
    };
    if (stockMinimo != null) {
      body['stock_minimo_alerta'] = stockMinimo;
    }

    final response = await _apiClient.patch(
      '/medications/$medId/stock',
      body: body,
    );
    return MedicationModel.fromJson(response);
  }

  Future<List<dynamic>> getAlertasStock() async {
    final response = await _apiClient.get('/medications/stock/alertas');
    if (response is List) {
      return response;
    }
    return [];
  }

  Future<List<dynamic>> getAuditoriaClinica() async {
    final response = await _apiClient.get('/medications/auditoria');
    if (response is List) {
      return response;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getResumenCuidador() async {
    try {
      final response = await _apiClient.get('/medications/cuidador/resumen-paciente');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> downloadAdherencePdf({int dias = 30}) async {
    final bytes = await _apiClient.getBytes('/medications/reporte-adherencia/pdf?dias=$dias');
    return bytes;
  }
}
