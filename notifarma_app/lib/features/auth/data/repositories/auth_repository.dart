import 'package:notifarma_app/core/network/api_client.dart';
import 'package:notifarma_app/features/auth/data/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      isPublic: true,
    );
    return response as Map<String, dynamic>;
  }

  Future<UserModel> register({
    required String nombres,
    required String email,
    required String password,
    required String rol,
    int? edad,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'nombres': nombres,
        'email': email,
        'password': password,
        'rol': rol,
        'edad': edad,
        'contacto_emergencia_nombre': contactoEmergenciaNombre,
        'contacto_emergencia_telefono': contactoEmergenciaTelefono,
      },
      isPublic: true,
    );
    return UserModel.fromJson(response);
  }

  Future<UserModel> getProfile() async {
    final response = await _apiClient.get('/auth/me');
    return UserModel.fromJson(response);
  }

  Future<Map<String, dynamic>> vincularCuidador(String emailCuidador) async {
    final response = await _apiClient.post('/auth/vincular-cuidador?email_cuidador=$emailCuidador');
    return response as Map<String, dynamic>;
  }
}
