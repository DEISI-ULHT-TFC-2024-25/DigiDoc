import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../constants/color_app.dart';
import '../models/DataBaseHelper.dart';
import 'package:diacritic/diacritic.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _filteredAlerts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortOption = 'date_asc';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _searchController.addListener(_filterAndSortAlerts);
  }

  Future<void> _loadAlerts() async {
    try {
      final db = await DataBaseHelper.instance.database;
      final alerts = await db.rawQuery('''
        SELECT a.alert_id, a.date, a.name AS description, a.is_active,
               d.document_id, d.document_type_name AS document_name, d.file_data,
               ds.dossier_id, ds.name AS dossier_name
        FROM Alert a
        LEFT JOIN Document d ON a.alert_id = d.alerts
        LEFT JOIN Dossier ds ON d.dossier_id = ds.dossier_id
        ORDER BY a.date ASC
      ''');
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _filterAndSortAlerts();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar alertas: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar alertas: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _filterAndSortAlerts() {
    final query = removeDiacritics(_searchController.text.toLowerCase());
    List<Map<String, dynamic>> filtered = _alerts.where((alert) {
      final documentName =
      removeDiacritics(alert['document_name']?.toString().toLowerCase() ?? '');
      return documentName.contains(query);
    }).toList();

    switch (_sortOption) {
      case 'date_asc':
        filtered.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
        break;
      case 'date_desc':
        filtered.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        break;
      case 'doc_name_asc':
        filtered.sort((a, b) =>
            (a['document_name'] ?? '').toLowerCase().compareTo((b['document_name'] ?? '').toLowerCase()));
        break;
      case 'doc_name_desc':
        filtered.sort((a, b) =>
            (b['document_name'] ?? '').toLowerCase().compareTo((a['document_name'] ?? '').toLowerCase()));
        break;
    }

    setState(() => _filteredAlerts = filtered);
  }

  Color _getDateIndicatorColor(DateTime date) {
    final now = DateTime.now();
    final oneMonthFromNow = now.add(const Duration(days: 30));
    if (date.isBefore(now)) {
      return Colors.red;
    } else if (date.isBefore(oneMonthFromNow)) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  Future<void> _toggleAlertActive(int alertId, bool isActive) async {
    try {
      final db = await DataBaseHelper.instance.database;
      await db.update(
        'Alert',
        {'is_active': isActive ? 1 : 0},
        where: 'alert_id = ?',
        whereArgs: [alertId],
      );

      final plugin = Provider.of<FlutterLocalNotificationsPlugin>(context, listen: false);
      if (isActive) {
        final alert = _alerts.firstWhere((a) => a['alert_id'] == alertId);
        await _scheduleNotification(
          alertId,
          alert['description'],
          DateTime.parse(alert['date']),
          alert['document_name'] ?? 'Documento',
          alert['dossier_name'] ?? 'Dossiê',
          plugin,
        );
      } else {
        await plugin.cancel(alertId);
      }

      await _loadAlerts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alerta ${isActive ? 'ativado' : 'desativado'} com sucesso')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar alerta: $e')),
      );
    }
  }

  Future<void> _scheduleNotification(
      int id,
      String description,
      DateTime date,
      String documentName,
      String dossierName,
      FlutterLocalNotificationsPlugin plugin,
      ) async {
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(date, tz.local);
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'digidoc_alerts',
      'DigiDoc Alerts',
      channelDescription: 'Notificações de alertas do DigiDoc',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await plugin.zonedSchedule(
      id,
      description,
      'Prazo para $documentName em $dossierName',
      scheduledTZDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'alert_$id',
    );
    print('Notificação agendada para ID $id em $scheduledTZDate');
  }

  Future<void> _editAlert(Map<String, dynamic> alert) async {
    final dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy', 'pt_PT').format(DateTime.parse(alert['date'])),
    );
    final descController = TextEditingController(text: alert['description']);
    final timeController = TextEditingController(
      text: TimeOfDay.fromDateTime(DateTime.parse(alert['date'])).format(context),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Editar Alerta'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Data (dd/mm/aaaa)',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.parse(alert['date']),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('pt', 'PT'),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(dialogContext).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.darkerBlue,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: Material(child: child),
                          );
                        },
                      );
                      if (pickedDate != null) {
                        dateController.text = DateFormat('dd/MM/yyyy', 'pt_PT').format(pickedDate);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Selecione uma data';
                      try {
                        DateFormat('dd/MM/yyyy', 'pt_PT').parseStrict(value);
                        return null;
                      } catch (e) {
                        return 'Formato inválido (use dd/mm/aaaa)';
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(DateTime.parse(alert['date'])),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(dialogContext).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.darkerBlue,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: Material(child: child),
                          );
                        },
                      );
                      if (pickedTime != null) {
                        timeController.text = pickedTime.format(context);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Selecione uma hora';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Insira uma descrição';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final date = DateFormat('dd/MM/yyyy', 'pt_PT').parseStrict(dateController.text);
                    final time = TimeOfDay.fromDateTime(
                      DateFormat.jm('pt_PT').parse(timeController.text),
                    );
                    final updatedDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );

                    final db = await DataBaseHelper.instance.database;
                    await db.update(
                      'Alert',
                      {
                        'date': updatedDate.toIso8601String(),
                        'name': descController.text,
                        'is_active': alert['is_active'],
                      },
                      where: 'alert_id = ?',
                      whereArgs: [alert['alert_id']],
                    );

                    final plugin = Provider.of<FlutterLocalNotificationsPlugin>(context, listen: false);
                    await _scheduleNotification(
                      alert['alert_id'],
                      descController.text,
                      updatedDate,
                      alert['document_name'] ?? 'Documento',
                      alert['dossier_name'] ?? 'Dossiê',
                      plugin,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alerta atualizado com sucesso')),
                      );
                      _loadAlerts();
                      Navigator.pop(dialogContext);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao atualizar alerta: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkerBlue),
              child: const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAlert(int alertId) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Deseja excluir este alerta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final db = await DataBaseHelper.instance.database;
                  await db.delete(
                    'Alert',
                    where: 'alert_id = ?',
                    whereArgs: [alertId],
                  );

                  final plugin = Provider.of<FlutterLocalNotificationsPlugin>(context, listen: false);
                  await plugin.cancel(alertId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alerta excluído com sucesso')),
                    );
                    _loadAlerts();
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir alerta: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkerBlue),
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => context.read<FlutterLocalNotificationsPlugin>(),
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Pesquisar por documento',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _sortOption,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sortOption = newValue;
                          _filterAndSortAlerts();
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'date_asc', child: Text('Data (Crescente)')),
                      DropdownMenuItem(value: 'date_desc', child: Text('Data (Decrescente)')),
                      DropdownMenuItem(value: 'doc_name_asc', child: Text('Nome Doc (A-Z)')),
                      DropdownMenuItem(value: 'doc_name_desc', child: Text('Nome Doc (Z-A)')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAlerts.isEmpty
                  ? const Center(
                child: Text(
                  'Nenhum alerta encontrado.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = _filteredAlerts[index];
                  final date = DateTime.parse(alert['date']);
                  final isActive = alert['is_active'] == 1;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          alert['file_data'] != null
                              ? Image.memory(
                            Uint8List.fromList(alert['file_data']),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 60),
                          )
                              : const Icon(Icons.document_scanner, size: 60),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert['description'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Data: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_PT').format(date)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _getDateIndicatorColor(date),
                                      ),
                                    ),
                                  ],
                                ),
                                if (alert['document_name'] != null)
                                  Text(
                                    'Documento: ${alert['document_name']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                if (alert['dossier_name'] != null)
                                  Text(
                                    'Dossiê: ${alert['dossier_name']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: AppColors.darkerBlue,
                                onChanged: (value) =>
                                    _toggleAlertActive(alert['alert_id'], value),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppColors.darkerBlue),
                                onPressed: () => _editAlert(alert),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.darkerBlue),
                                onPressed: () => _deleteAlert(alert['alert_id']),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}