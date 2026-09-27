import 'package:flutter/material.dart';
import 'package:notifarma_app/core/services/storage_service.dart';
import 'package:notifarma_app/features/auth/data/models/user_model.dart';
import 'package:notifarma_app/features/auth/data/repositories/auth_repository.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  final StorageService _storageService = StorageService();

  AuthStatus _status = AuthStatus.unauthenticated;
  UserModel? _user;
  String? _errorMessage;
  String _enteredPin = '';

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  String get enteredPin => _enteredPin;

  String get userInitials {
    if (_user == null || _user!.nombres.isEmpty) return 'DC';
    final parts = _user!.nombres.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _user!.nombres.substring(0, 2).toUpperCase();
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        _user = await _repository.getProfile();
        await _storageService.saveUserData(
          userId: _user!.id,
          name: _user!.nombres,
          role: _user!.rol,
          emergencyContact: _user!.contactoEmergenciaNombre,
        );
        _status = AuthStatus.authenticated;
      } catch (_) {
        await _storageService.clearAll();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.login(email, password);
      final token = res['access_token'];
      await _storageService.saveToken(token);

      _user = await _repository.getProfile();
      await _storageService.saveUserData(
        userId: _user!.id,
        name: _user!.nombres,
        role: _user!.rol,
        emergencyContact: _user!.contactoEmergenciaNombre,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String nombres,
    required String email,
    required String password,
    required String rol,
    int? edad,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.register(
        nombres: nombres,
        email: email,
        password: password,
        rol: rol,
        edad: edad,
        contactoEmergenciaNombre: contactoEmergenciaNombre,
        contactoEmergenciaTelefono: contactoEmergenciaTelefono,
      );
      // Login automatically after register
      return await login(email, password);
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  void appendPinDigit(String digit) {
    if (_enteredPin.length < 4) {
      _enteredPin += digit;
      notifyListeners();
    }
  }

  void removePinDigit() {
    if (_enteredPin.isNotEmpty) {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      notifyListeners();
    }
  }

  void clearPin() {
    _enteredPin = '';
    notifyListeners();
  }

  Future<String?> generarCodigoVinculacion() async {
    try {
      final res = await _repository.generarCodigoVinculacion();
      return res['codigo'] as String?;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> vincularPorCodigo(String codigo) async {
    try {
      await _repository.vincularPorCodigo(codigo);
      // Refresh user profile after linking
      _user = await _repository.getProfile();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelarCodigoVinculacion() async {
    try {
      await _repository.cancelarCodigoVinculacion();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storageService.clearAll();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _enteredPin = '';
    notifyListeners();
  }
}
