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

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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

    // Solicitar permisos de notificación en tiempo de ejecución (Android 13+ / iOS)
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      try {
        await androidImpl.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      'notifarma_alarms_v2',
      'Alertas Médicas NotiFarma',
      channelDescription: 'Canal de máxima prioridad y sonido para tomas de medicamentos y citas médicas',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      groupKey: 'com.notifarma.notifications',
      setAsGroupSummary: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  void startPolling({Duration interval = const Duration(minutes: 1)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      interval,
      (_) => checkPendingNotifications(),
    );
    // Initial check immediately
    checkPendingNotifications();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  final Set<String> _notificacionesMostradas = {};

  Future<List<dynamic>> checkPendingNotifications() async {
    try {
      final response = await _apiClient.get('/notifications/pendientes');
      if (response is List) {
        final pendingIds = response
            .map((item) => item['id'].toString())
            .toSet();
        final resolvedIds = _notificacionesMostradas.difference(pendingIds);
        for (final id in resolvedIds) {
          if (!kIsWeb) {
            await _notificationsPlugin.cancel(id.hashCode);
          }
          _notificacionesMostradas.remove(id);
        }

        for (var i = 0; i < response.length; i++) {
          final item = response[i];
          final notifId = item['id'].toString();

          // Si ya se mostró esta notificación localmente, evitar hacerla sonar repetidamente
          if (_notificacionesMostradas.contains(notifId)) {
            continue;
          }

          final mensaje = item['mensaje'] ?? 'Tienes un recordatorio pendiente';
          final tipo = item['tipo'] ?? 'medicamento';

          final notificationTitle = tipo == 'cita'
              ? 'Recordatorio de cita médica'
              : 'Hora de tomar el medicamento';

          await showLocalNotification(
            id: notifId.hashCode,
            title: notificationTitle,
            body: mensaje,
            payload: notifId,
          );

          _notificacionesMostradas.add(notifId);
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
      _notificacionesMostradas.remove(id);
      if (!kIsWeb) {
        await _notificationsPlugin.cancel(id.hashCode);
      }
      await _apiClient.post('/notifications/$id/confirmar');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> cancelarNotificacionLocal(int id) async {
    if (!kIsWeb) {
      await _notificationsPlugin.cancel(id);
    }
  }
}
