import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:DigiDoc/models/DataBaseHelper.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications(GlobalKey<NavigatorState> navigatorKey) async {
  tz.initializeTimeZones();
  print('NotificationService: Inicializando notificações');

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  bool? initialized = await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      print('NotificationService: Notificação recebida com payload: ${response.payload}');
      if (response.payload != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/alerts', arguments: response.payload);
      }
    },
  );
  print('NotificationService: Inicialização concluída: $initialized');

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    final granted = await androidPlugin.requestNotificationsPermission();
    print('NotificationService: Permissão de notificação solicitada: $granted');
    if (granted == null || !granted) {
      print('NotificationService: Permissão de notificação não concedida');
    }
  }
}

Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
  required String payload,
}) async {
  print('NotificationService: Agendando notificação ID $id para $scheduledDate');
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'digidoc_alerts',
    'DigiDoc Alerts',
    channelDescription: 'Notificações de alertas do DigiDoc',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    print('NotificationService: Notificação ID $id agendada com sucesso para $tzScheduledDate');
  } catch (e, stackTrace) {
    print('NotificationService: Erro ao agendar notificação ID $id: $e');
    print('NotificationService: Stack trace: $stackTrace');
  }
}

Future<void> showImmediateNotification({
  required int id,
  required String title,
  required String body,
  required String payload,
}) async {
  print('NotificationService: Disparando notificação imediata ID $id');
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'digidoc_alerts',
    'DigiDoc Alerts',
    channelDescription: 'Notificações de alertas do DigiDoc',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  try {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    print('NotificationService: Notificação imediata ID $id disparada com sucesso');
  } catch (e, stackTrace) {
    print('NotificationService: Erro ao disparar notificação imediata ID $id: $e');
    print('NotificationService: Stack trace: $stackTrace');
  }
}

Future<void> cancelNotification(int id) async {
  print('NotificationService: Cancelando notificação ID $id');
  try {
    await flutterLocalNotificationsPlugin.cancel(id);
    print('NotificationService: Notificação ID $id cancelada com sucesso');
  } catch (e, stackTrace) {
    print('NotificationService: Erro ao cancelar notificação ID $id: $e');
    print('NotificationService: Stack trace: $stackTrace');
  }
}

Future<void> rescheduleActiveNotifications() async {
  print('NotificationService: Reagendando notificações ativas');
  try {
    final db = await DataBaseHelper.instance.database;
    final alerts = await db.query('Alert', where: 'is_active = ?', whereArgs: [1]);

    for (var alert in alerts) {
      final alertDate = DateTime.parse(alert['date'] as String);
      final alertId = alert['alert_id'] as int;
      final alertName = alert['name'] as String;

      if (alertDate.isAfter(DateTime.now())) {
        await scheduleNotification(
          id: alertId,
          title: 'Prazo do Documento',
          body: alertName,
          scheduledDate: alertDate,
          payload: '/alerts',
        );
        print('NotificationService: Notificação ID $alertId reagendada para $alertDate');

        final reminderDate = alertDate.subtract(const Duration(days: 7));
        if (reminderDate.isAfter(DateTime.now())) {
          await scheduleNotification(
            id: alertId + 1000,
            title: 'Lembrete: Prazo do Documento',
            body: 'Lembrete: $alertName',
            scheduledDate: reminderDate,
            payload: '/alerts',
          );
          print('NotificationService: Lembrete ID ${alertId + 1000} reagendado para $reminderDate');
        }
      }
    }
    print('NotificationService: Reagendamento concluído');
  } catch (e, stackTrace) {
    print('NotificationService: Erro ao reagendar notificações: $e');
    print('NotificationService: Stack trace: $stackTrace');
  }
}