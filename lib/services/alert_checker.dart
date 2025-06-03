import 'dart:async';
import 'package:flutter/material.dart';
import 'package:DigiDoc/models/data_base_helper.dart';
import 'package:DigiDoc/services/notification_service.dart';

void startAlertChecker(GlobalKey<NavigatorState> navigatorKey) {
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      final db = await DataBaseHelper.instance.database;
      final alerts = await db.query('Alert', where: 'is_active = ?', whereArgs: [1]);

      final now = DateTime.now();

      for (var alert in alerts) {
        final alertDate = DateTime.parse(alert['date'] as String);
        final alertId = alert['alert_id'] as int;
        final alertName = alert['name'] as String;

        // Verificar se o alerta está vencido (dentro de 1 segundo)
        if (alertDate.difference(now).inSeconds.abs() <= 1) {
          print('AlertChecker: Disparando notificação imediata para alerta $alertId');
          await showImmediateNotification(
            id: alertId,
            title: 'Prazo do Documento',
            body: alertName,
            payload: '/alerts',
          );

          // Desativar alerta após disparo
          await db.update(
            'Alert',
            {'is_active': 0},
            where: 'alert_id = ?',
            whereArgs: [alertId],
          );
          print('AlertChecker: Alerta $alertId desativado após notificação');
        }

        // Verificar lembrete de 7 dias
        final reminderDate = alertDate.subtract(const Duration(days: 7));
        if (reminderDate.difference(now).inSeconds.abs() <= 1) {
          print('AlertChecker: Disparando lembrete de 7 dias para alerta $alertId');
          await showImmediateNotification(
            id: alertId + 1000,
            title: 'Lembrete: Prazo do Documento',
            body: 'Lembrete: $alertName',
            payload: '/alerts',
          );
          print('AlertChecker: Lembrete de 7 dias disparado para alerta $alertId');
        }
      }
    } catch (e, stackTrace) {
      print('AlertChecker: Erro ao verificar alertas: $e');
      print('AlertChecker: Stack trace: $stackTrace');
    }
  });
}