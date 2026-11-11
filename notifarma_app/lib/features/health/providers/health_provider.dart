import 'package:flutter/material.dart';
import 'package:notifarma_app/features/health/data/models/appointment_model.dart';
import 'package:notifarma_app/features/health/data/models/mood_model.dart';
import 'package:notifarma_app/features/health/data/models/symptom_model.dart';
import 'package:notifarma_app/features/health/data/repositories/health_repository.dart';

class HealthProvider extends ChangeNotifier {
  final HealthRepository _repository = HealthRepository();

  List<MoodModel> _todayMoods = [];
  final List<SymptomCatalogModel> _symptomCatalog = [];
  List<AppointmentModel> _appointments = [];
  String _recomendacionHoy = 'Recuerda registrar cómo te sientes hoy.';
  String? _selectedMood;
  bool _isLoading = false;
  bool _isRecordingMood = false;
  String? _errorMessage;

  List<MoodModel> get todayMoods => _todayMoods;
  List<SymptomCatalogModel> get symptomCatalog => _symptomCatalog;
  List<AppointmentModel> get appointments => _appointments;
  String get recomendacionHoy => _recomendacionHoy;
  String? get selectedMood => _selectedMood;
  bool get isLoading => _isLoading;
  bool get isRecordingMood => _isRecordingMood;
  String? get errorMessage => _errorMessage;

  Future<void> fetchHealthData({bool silent = false}) async {
    if (!silent) _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todayMoods = await _repository.getTodayMoods();
      _selectedMood = _todayMoods.isNotEmpty ? _todayMoods.first.animo : null;
      _recomendacionHoy = await _repository.getRecomendacionHoy();
      _appointments = await _repository.getAppointments();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!silent) _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordMood(String animo) async {
    if (_isRecordingMood) return false;
    final previousMood = _selectedMood;
    _isRecordingMood = true;
    _selectedMood = animo;
    notifyListeners();
    try {
      await _repository.recordMood(animo);
      _recomendacionHoy = await _repository.getRecomendacionHoy();
      await fetchHealthData(silent: true);
      return true;
    } catch (e) {
      _selectedMood = previousMood;
      _errorMessage = e.toString();
      return false;
    } finally {
      _isRecordingMood = false;
      notifyListeners();
    }
  }

  Future<bool> registerSymptoms(List<Map<String, dynamic>> symptoms) async {
    try {
      await _repository.registerSymptoms(symptoms);
      _recomendacionHoy = await _repository.getRecomendacionHoy();
      await fetchHealthData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createAppointment({
    required String especialidad,
    String? medico,
    String? lugar,
    String? direccion,
    required String fechaHoraIso,
    String? notas,
  }) async {
    try {
      await _repository.createAppointment(
        especialidad: especialidad,
        medico: medico,
        lugar: lugar,
        direccion: direccion,
        fechaHoraIso: fechaHoraIso,
        notas: notas,
      );
      _appointments = await _repository.getAppointments();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAppointmentStatus(String id, String estado) async {
    try {
      await _repository.updateAppointmentStatus(id, estado);
      _appointments = await _repository.getAppointments();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAppointment({
    required String id,
    String? especialidad,
    String? medico,
    String? lugar,
    String? direccion,
    String? fechaHoraIso,
    String? notas,
  }) async {
    try {
      await _repository.updateAppointment(
        id: id,
        especialidad: especialidad,
        medico: medico,
        lugar: lugar,
        direccion: direccion,
        fechaHoraIso: fechaHoraIso,
        notas: notas,
      );
      _appointments = await _repository.getAppointments();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelAppointment(String id) async {
    try {
      await _repository.cancelAppointment(id);
      _appointments = await _repository.getAppointments();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
