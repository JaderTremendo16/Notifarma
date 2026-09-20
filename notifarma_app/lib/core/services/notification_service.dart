import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notifarma_app/core/network/api_client.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ApiClient _apiClient = ApiClient();
  Timer? _pollingTimer;

  Future<void> initialize() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null && response.payload!.isNotEmpty) {
          await confirmarNotificacion(response.payload!);
        }
      },
    );
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'notifarma_reminders',
      'Recordatorios NotiFarma',
      channelDescription: 'Canal de alta prioridad para recordatorios de medicamentos y salud',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  void startPolling({Duration interval = const Duration(minutes: 1)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => checkPendingNotifications());
    // Initial check immediately
    checkPendingNotifications();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<List<dynamic>> checkPendingNotifications() async {
    try {
      final response = await _apiClient.get('/notifications/pendientes');
      if (response is List && response.isNotEmpty) {
        for (var i = 0; i < response.length; i++) {
          final item = response[i];
          final notifId = item['id'].toString();
          final mensaje = item['mensaje'] ?? 'Tienes un recordatorio pendiente';
          final tipo = item['tipo'] ?? 'medicamento';

          final notificationTitle = tipo == 'cita'
              ? '📅 Recordatorio de Cita Médica'
              : '💊 Hora de tomar tu Medicamento';

          await showLocalNotification(
            id: notifId.hashCode,
            title: notificationTitle,
            body: mensaje,
            payload: notifId,
          );
        }
        return response;
      }
    } catch (_) {
      // Ignorar errores de red temporales en polling silencioso
    }
    return [];
  }

  Future<bool> confirmarNotificacion(String id) async {
    try {
      await _apiClient.post('/notifications/$id/confirmar');
      return true;
    } catch (e) {
      return false;
    }
  }
}
