import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:notifarma_app/core/config/api_config.dart';
import 'package:notifarma_app/core/network/api_exception.dart';
import 'package:notifarma_app/core/services/storage_service.dart';

class ApiClient {
  final StorageService _storageService = StorageService();

  Future<Map<String, String>> _getHeaders({bool isPublic = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (!isPublic) {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {bool isPublic = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isPublic: isPublic);

    try {
      final response = await http.get(uri, headers: headers).timeout(ApiConfig.connectTimeout);
      return _processResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<int>> getBytes(String endpoint, {bool isPublic = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isPublic: isPublic);
    headers['Accept'] = 'application/pdf';

    try {
      final response = await http.get(uri, headers: headers).timeout(ApiConfig.connectTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw _processResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body, bool isPublic = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isPublic: isPublic);

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.connectTimeout);
      return _processResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String endpoint, {dynamic body, bool isPublic = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isPublic: isPublic);

    try {
      final response = await http
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.connectTimeout);
      return _processResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> patch(String endpoint, {dynamic body, bool isPublic = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isPublic: isPublic);

    try {
      final response = await http
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.connectTimeout);
      return _processResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String endpoint, {bool isPublic = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isPublic: isPublic);

    try {
      final response = await http.delete(uri, headers: headers).timeout(ApiConfig.connectTimeout);
      return _processResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMessage = 'Error en la petición (${response.statusCode})';
    if (body is Map && body.containsKey('detail')) {
      errorMessage = body['detail'].toString();
    } else if (body is Map && body.containsKey('message')) {
      errorMessage = body['message'].toString();
    }

    throw ApiException(errorMessage, statusCode: response.statusCode);
  }

  ApiException _handleError(dynamic e) {
    if (e is ApiException) return e;
    return ApiException('Error de conexión con el servidor. Verifique su red.');
  }
}
