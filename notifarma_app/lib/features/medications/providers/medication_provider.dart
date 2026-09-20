import 'package:flutter/material.dart';
import 'package:notifarma_app/features/medications/data/models/medication_model.dart';
import 'package:notifarma_app/features/medications/data/models/toma_model.dart';
import 'package:notifarma_app/features/medications/data/repositories/medication_repository.dart';

class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repository = MedicationRepository();

  List<MedicationModel> _medications = [];
  Map<String, dynamic>? _proximoMedicamento;
  List<TomaModel> _tomasHistorial = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'Mañana'; // 'Mañana', 'Tarde', 'Noche'

  List<MedicationModel> get medications => _medications;
  Map<String, dynamic>? get proximoMedicamento => _proximoMedicamento;
  List<TomaModel> get tomasHistorial => _tomasHistorial;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedFilter => _selectedFilter;

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> fetchMedicationsData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _medications = await _repository.getActiveMedications();
      _proximoMedicamento = await _repository.getProximoMedicamento();
      _tomasHistorial = await _repository.getHistorialTomas();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registrarToma(String medId, String estado) async {
    try {
      await _repository.registrarToma(medId, estado);
      await fetchMedicationsData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createMedication({
    required String nombre,
    String? dosis,
    required int frecuenciaHoras,
    required String horaInicio,
    String? fechaInicio,
    String? fechaFin,
    int stockActual = 30,
    int stockMinimoAlerta = 5,
  }) async {
    try {
      await _repository.createMedication(
        nombre: nombre,
        dosis: dosis,
        frecuenciaHoras: frecuenciaHoras,
        horaInicio: horaInicio,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        stockActual: stockActual,
        stockMinimoAlerta: stockMinimoAlerta,
      );
      await fetchMedicationsData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
