import 'package:flutter/material.dart';
import 'package:notifarma_app/features/medications/data/models/medication_model.dart';
import 'package:notifarma_app/features/medications/data/models/toma_model.dart';
import 'package:notifarma_app/features/medications/data/repositories/medication_repository.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';

class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repository = MedicationRepository();

  List<MedicationModel> _medications = [];
  Map<String, dynamic>? _proximoMedicamento;
  List<TomaModel> _tomasHistorial = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'Todos'; // 'Todos', 'Mañana', 'Tarde', 'Noche'

  List<MedicationModel> get medications => _medications;
  Map<String, dynamic>? get proximoMedicamento => _proximoMedicamento;
  List<TomaModel> get tomasHistorial => _tomasHistorial;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedFilter => _selectedFilter;

  /// Retorna la última dosis registrada, independientemente de su estado.
  TomaModel? getUltimaToma(String medId) {
    try {
      final tomasMed = _tomasHistorial
          .where((t) => t.medicamentoId == medId)
          .toList();
      if (tomasMed.isEmpty) return null;
      return tomasMed.first; // ya viene ordenado por fecha descendente
    } catch (_) {
      return null;
    }
  }

  /// Verifica si la dosis actual de este medicamento ya fue tomada recientemente
  bool isDoseTakenRecently(String medId, {int frecuenciaHoras = 8}) {
    final ultima = getUltimaToma(medId);
    if (ultima == null || ultima.estado.toLowerCase() != 'tomado') return false;
    return _isDoseRecent(ultima, frecuenciaHoras);
  }

  bool isDoseRegisteredRecently(String medId, {int frecuenciaHoras = 8}) {
    final ultima = getUltimaToma(medId);
    if (ultima == null) return false;
    return _isDoseRecent(ultima, frecuenciaHoras);
  }

  bool _isDoseRecent(TomaModel toma, int frecuenciaHoras) {
    try {
      final fechaStr = toma.fechaHoraConfirmacion ?? toma.fechaHoraProgramada;
      if (fechaStr.isEmpty) return false;
      final fechaToma = DateFormatter.tryParseColombiaDateTime(fechaStr);
      if (fechaToma == null) return false;
      final ahora = DateFormatter.nowColombia();
      final diferencia = ahora.difference(fechaToma);
      // Si la toma fue hace menos tiempo que la frecuencia (ej. 4h, 8h, 12h o min 2h), está bloqueada
      final minHoras = frecuenciaHoras > 0 ? frecuenciaHoras : 4;
      return diferencia.inMinutes >= 0 && diferencia.inHours < minHoras;
    } catch (_) {
      return false;
    }
  }

  DateTime? nextDoseAt(MedicationModel medication) {
    if (medication.frecuenciaHoras <= 0 || medication.stockActual <= 0) {
      return null;
    }
    final timeParts = medication.horaInicio.split(':');
    final hour = int.tryParse(timeParts.first);
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : null;
    if (hour == null || minute == null) return null;

    final now = DateFormatter.nowColombia();
    DateTime startDate = DateTime.utc(now.year, now.month, now.day);
    if (medication.fechaInicio != null) {
      final parsedStart = DateTime.tryParse(medication.fechaInicio!);
      if (parsedStart == null) return null;
      startDate = DateTime.utc(
        parsedStart.year,
        parsedStart.month,
        parsedStart.day,
      );
    }

    final firstDose = DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
      hour,
      minute,
    );
    final nextDose = firstDose.isAfter(now)
        ? firstDose
        : firstDose.add(
            Duration(
              hours:
                  (((now.difference(firstDose).inSeconds) ~/
                          (medication.frecuenciaHoras * 3600)) +
                      1) *
                  medication.frecuenciaHoras,
            ),
          );

    if (medication.fechaFin != null) {
      final parsedEnd = DateTime.tryParse(medication.fechaFin!);
      if (parsedEnd == null ||
          DateTime.utc(nextDose.year, nextDose.month, nextDose.day).isAfter(
            DateTime.utc(parsedEnd.year, parsedEnd.month, parsedEnd.day),
          )) {
        return null;
      }
    }
    return nextDose;
  }

  List<MedicationModel> get filteredMedications {
    if (_medications.isEmpty) return [];
    if (_selectedFilter == 'Todos') return _medications;
    return _medications.where((m) {
      try {
        final hour = int.tryParse(m.horaInicio.split(':')[0]) ?? 8;
        if (_selectedFilter == 'Mañana') {
          return hour >= 5 && hour < 12;
        } else if (_selectedFilter == 'Tarde') {
          return hour >= 12 && hour < 18;
        } else if (_selectedFilter == 'Noche') {
          return hour >= 18 || hour < 5;
        }
      } catch (_) {
        return true;
      }
      return true;
    }).toList();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> fetchMedicationsData({bool silent = false}) async {
    if (!silent) _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _medications = await _repository.getActiveMedications();
      _proximoMedicamento = await _repository.getProximoMedicamento();
      _tomasHistorial = await _repository.getHistorialTomas();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!silent) _isLoading = false;
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
    String? indicaciones,
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
        indicaciones: indicaciones,
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

  Future<bool> updateMedication(
    String medId, {
    String? nombre,
    String? dosis,
    String? indicaciones,
    int? frecuenciaHoras,
    String? horaInicio,
    int? stockActual,
    int? stockMinimoAlerta,
  }) async {
    try {
      await _repository.updateMedication(
        medId,
        nombre: nombre,
        dosis: dosis,
        indicaciones: indicaciones,
        frecuenciaHoras: frecuenciaHoras,
        horaInicio: horaInicio,
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

  Future<bool> deleteMedication(String medId) async {
    try {
      await _repository.deleteMedication(medId);
      await fetchMedicationsData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
