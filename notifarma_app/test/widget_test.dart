import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifarma_app/features/health/data/models/appointment_model.dart';
import 'package:notifarma_app/features/health/presentation/widgets/appointment_edit_dialog.dart';

void main() {
  testWidgets(
    'appointment editor shows existing details and can be dismissed',
    (tester) async {
      final appointment = AppointmentModel(
        id: 'appointment-1',
        pacienteId: 'patient-1',
        especialidad: 'Cardiología',
        medico: 'Dra. Rivera',
        lugar: 'Clínica Central',
        direccion: 'Consultorio 402',
        fechaHora: DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String(),
        notas: 'Llevar exámenes',
        activo: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showAppointmentEditDialog(context, appointment);
                },
                child: const Text('Abrir editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir editor'));
      await tester.pumpAndSettle();

      expect(find.text('Editar recordatorio'), findsOneWidget);
      expect(find.text('Dra. Rivera'), findsOneWidget);
      expect(find.text('Clínica Central'), findsOneWidget);
      expect(find.text('Consultorio 402'), findsOneWidget);
      expect(find.text('Llevar exámenes'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar recordatorio'), findsNothing);
    },
  );
}
