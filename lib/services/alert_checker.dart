import 'dart:async';
import 'package:flutter/material.dart';
import 'package:DigiDoc/models/DataBaseHelper.dart';
import '../screens/custom_notification.dart';

void startAlertChecker(GlobalKey<NavigatorState> navigatorKey) {
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      final db = await DataBaseHelper.instance.database;
      final alerts = await db.query('Alert', where: 'is_active = ?', whereArgs: [1]);

      final now = DateTime.now();

      for (var alert in alerts) {
        final alertDate = DateTime.parse(alert['date'] as String);
        final alertId = alert['id'] as int;
        final alertName = alert['name'] as String;

        // Check if alert is due (within 1 second)
        if (alertDate.difference(now).inSeconds.abs() <= 1) {
          await showNotification(
            alertId,
            'Prazo do Documento',
            alertName,
            '/alerts',
          );

          // Deactivate alert after triggering
          await db.update(
            'Alert',
            {'is_active': 0},
            where: 'id = ?',
            whereArgs: [alertId],
          );
        }

        // Check for 7-day reminder
        final reminderDate = alertDate.subtract(const Duration(days: 7));
        if (reminderDate.difference(now).inSeconds.abs() <= 1) {
          await showNotification(
            alertId + 1000,
            'Lembrete: Prazo do Documento',
            'Lembrete: $alertName',
            '/alerts',
          );
        }
      }
    } catch (e) {}
  });
}