import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notifarma_app/features/health/data/models/appointment_model.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';

class AppointmentEditData {
  const AppointmentEditData({
    required this.especialidad,
    required this.medico,
    required this.lugar,
    required this.direccion,
    required this.fechaHoraIso,
    required this.notas,
  });

  final String especialidad;
  final String? medico;
  final String? lugar;
  final String? direccion;
  final String fechaHoraIso;
  final String? notas;
}

Future<AppointmentEditData?> showAppointmentEditDialog(
  BuildContext context,
  AppointmentModel appointment,
) {
  return showDialog<AppointmentEditData>(
    context: context,
    builder: (_) => _AppointmentEditDialog(appointment: appointment),
  );
}

class _AppointmentEditDialog extends StatefulWidget {
  const _AppointmentEditDialog({required this.appointment});

  final AppointmentModel appointment;

  @override
  State<_AppointmentEditDialog> createState() => _AppointmentEditDialogState();
}

class _AppointmentEditDialogState extends State<_AppointmentEditDialog> {
  late final TextEditingController _specialtyController;
  late final TextEditingController _doctorController;
  late final TextEditingController _placeController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late TimeOfDay _time;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _specialtyController = TextEditingController(
      text: widget.appointment.especialidad,
    );
    _doctorController = TextEditingController(
      text: widget.appointment.medico ?? '',
    );
    _placeController = TextEditingController(
      text: widget.appointment.lugar ?? '',
    );
    _addressController = TextEditingController(
      text: widget.appointment.direccion ?? '',
    );
    _notesController = TextEditingController(
      text: widget.appointment.notas ?? '',
    );
    final initial =
        DateFormatter.tryParseColombiaDateTime(widget.appointment.fechaHora) ??
        DateFormatter.nowColombia();
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay(hour: initial.hour, minute: initial.minute);
  }

  @override
  void dispose() {
    _specialtyController.dispose();
    _doctorController.dispose();
    _placeController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateFormatter.nowColombia().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (_specialtyController.text.trim().isEmpty) {
      setState(
        () => _validationMessage = 'Escribe la especialidad de la cita.',
      );
      return;
    }
    final appointmentTime = DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (!appointmentTime.isAfter(DateFormatter.nowColombia())) {
      setState(() => _validationMessage = 'La fecha y hora debe ser futura.');
      return;
    }

    Navigator.of(context).pop(
      AppointmentEditData(
        especialidad: _specialtyController.text.trim(),
        medico: _doctorController.text.trim().isEmpty
            ? null
            : _doctorController.text.trim(),
        lugar: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        direccion: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        fechaHoraIso: DateFormatter.toColombiaIsoString(appointmentTime),
        notas: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar recordatorio'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _specialtyController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Especialidad'),
              ),
              TextField(
                controller: _doctorController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Profesional'),
              ),
              TextField(
                controller: _placeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Centro médico'),
              ),
              TextField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              if (_validationMessage != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(
                        DateFormat('h:mm a').format(
                          DateTime(2000, 1, 1, _time.hour, _time.minute),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Indicaciones'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar cambios')),
      ],
    );
  }
}
