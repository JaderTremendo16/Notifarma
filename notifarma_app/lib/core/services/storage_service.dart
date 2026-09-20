import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyToken = 'access_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserPin = 'user_pin';
  static const String _keyEmergencyContact = 'emergency_contact';
  static const String _keyThemeMode = 'theme_mode';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> saveUserPin(String pin) async {
    await _storage.write(key: _keyUserPin, value: pin);
  }

  Future<String?> getUserPin() async {
    return await _storage.read(key: _keyUserPin);
  }

  Future<void> saveUserData({
    required String userId,
    required String name,
    required String role,
    String? emergencyContact,
  }) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyUserRole, value: role);
    if (emergencyContact != null) {
      await _storage.write(key: _keyEmergencyContact, value: emergencyContact);
    }
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: _keyUserName);
  }

  Future<String?> getEmergencyContact() async {
    return await _storage.read(key: _keyEmergencyContact);
  }

  Future<void> saveThemeMode(bool isDark) async {
    await _storage.write(key: _keyThemeMode, value: isDark ? 'dark' : 'light');
  }

  Future<bool> getIsDarkMode() async {
    final mode = await _storage.read(key: _keyThemeMode);
    return mode == 'dark';
  }

  Future<void> clearAll() async {
    // Retain theme preference across logout
    final isDark = await getIsDarkMode();
    await _storage.deleteAll();
    await saveThemeMode(isDark);
  }
}
