import 'package:flutter/material.dart';
import 'package:notifarma_app/features/health/data/models/appointment_model.dart';
import 'package:notifarma_app/features/health/data/models/mood_model.dart';
import 'package:notifarma_app/features/health/data/models/symptom_model.dart';
import 'package:notifarma_app/features/health/data/repositories/health_repository.dart';

class HealthProvider extends ChangeNotifier {
  final HealthRepository _repository = HealthRepository();

  List<MoodModel> _todayMoods = [];
  List<SymptomCatalogModel> _symptomCatalog = [];
  List<AppointmentModel> _appointments = [];
  String _recomendacionHoy = 'Recuerda registrar cómo te sientes hoy.';
  String? _selectedMood;
  bool _isLoading = false;
  String? _errorMessage;

  List<MoodModel> get todayMoods => _todayMoods;
  List<SymptomCatalogModel> get symptomCatalog => _symptomCatalog;
  List<AppointmentModel> get appointments => _appointments;
  String get recomendacionHoy => _recomendacionHoy;
  String? get selectedMood => _selectedMood;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchHealthData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todayMoods = await _repository.getTodayMoods();
      if (_todayMoods.isNotEmpty) {
        _selectedMood = _todayMoods.first.animo;
      }
      _symptomCatalog = await _repository.getSymptomCatalog();
      _recomendacionHoy = await _repository.getRecomendacionHoy();
      _appointments = await _repository.getAppointments();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordMood(String animo) async {
    _selectedMood = animo;
    notifyListeners();
    try {
      await _repository.recordMood(animo);
      _recomendacionHoy = await _repository.getRecomendacionHoy();
      await fetchHealthData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
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
    required String fechaHoraIso,
    String? notas,
  }) async {
    try {
      await _repository.createAppointment(
        especialidad: especialidad,
        medico: medico,
        lugar: lugar,
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

  Future<void> cancelAppointment(String id) async {
    try {
      await _repository.cancelAppointment(id);
      _appointments = await _repository.getAppointments();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
