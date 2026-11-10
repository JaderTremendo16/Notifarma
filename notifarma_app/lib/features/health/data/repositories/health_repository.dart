import 'package:notifarma_app/core/network/api_client.dart';
import 'package:notifarma_app/features/health/data/models/appointment_model.dart';
import 'package:notifarma_app/features/health/data/models/mood_model.dart';
import 'package:notifarma_app/features/health/data/models/symptom_model.dart';

class HealthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<MoodModel> recordMood(String animo) async {
    final response = await _apiClient.post(
      '/health/mood',
      body: {'animo': animo},
    );
    return MoodModel.fromJson(response);
  }

  Future<List<MoodModel>> getTodayMoods() async {
    final response = await _apiClient.get('/health/mood/hoy');
    if (response is List) {
      return response.map((e) => MoodModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<SymptomCatalogModel>> getSymptomCatalog() async {
    final response = await _apiClient.get('/health/sintomas/catalogo', isPublic: true);
    if (response is List) {
      return response.map((e) => SymptomCatalogModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<RegisteredSymptomModel>> registerSymptoms(List<Map<String, dynamic>> symptoms) async {
    final response = await _apiClient.post(
      '/health/sintomas',
      body: symptoms,
    );
    if (response is List) {
      return response.map((e) => RegisteredSymptomModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<String> getRecomendacionHoy() async {
    try {
      final response = await _apiClient.get('/health/recomendacion-hoy');
      return response['mensaje'] ?? 'Recuerda registrar cómo te sientes hoy.';
    } catch (_) {
      return 'Recuerda registrar cómo te sientes durante el día.';
    }
  }

  Future<List<AppointmentModel>> getAppointments() async {
    final response = await _apiClient.get('/health/citas');
    if (response is List) {
      return response.map((e) => AppointmentModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<AppointmentModel> createAppointment({
    required String especialidad,
    String? medico,
    String? lugar,
    String? direccion,
    required String fechaHoraIso,
    String? notas,
  }) async {
    final response = await _apiClient.post(
      '/health/citas',
      body: {
        'especialidad': especialidad,
        'medico': medico,
        'lugar': lugar,
        'direccion': direccion,
        'fecha_hora': fechaHoraIso,
        'notas': notas,
      },
    );
    return AppointmentModel.fromJson(response);
  }

  Future<void> updateAppointmentStatus(String id, String estado) async {
    await _apiClient.patch(
      '/health/citas/$id/estado',
      body: {'estado': estado},
    );
  }

  Future<AppointmentModel> updateAppointment({
    required String id,
    String? especialidad,
    String? medico,
    String? lugar,
    String? direccion,
    String? fechaHoraIso,
    String? notas,
  }) async {
    final Map<String, dynamic> body = {};
    if (especialidad != null) body['especialidad'] = especialidad;
    if (medico != null) body['medico'] = medico;
    if (lugar != null) body['lugar'] = lugar;
    if (direccion != null) body['direccion'] = direccion;
    if (fechaHoraIso != null) body['fecha_hora'] = fechaHoraIso;
    if (notas != null) body['notas'] = notas;

    final response = await _apiClient.put(
      '/health/citas/$id',
      body: body,
    );
    return AppointmentModel.fromJson(response);
  }

  Future<void> cancelAppointment(String id) async {
    await _apiClient.delete('/health/citas/$id');
  }
}
