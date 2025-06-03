import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import '../services/notification_service.dart';
import 'package:diacritic/diacritic.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  AlertsScreenState createState() => AlertsScreenState();
}

class AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _filteredAlerts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortOption = 'date_asc';

  @override
  void initState() {
    super.initState();
    print('AlertsScreen: initState chamado');
    loadAlerts();
    _searchController.addListener(_filterAndSortAlerts);
  }

  Future<void> loadAlerts() async {
    print('AlertsScreen: loadAlerts iniciado');
    try {
      final alerts = await DataBaseHelper.instance.getAlerts();
      print('AlertsScreen: Carregados ${alerts.length} alertas');
      setState(() {
        _alerts = alerts;
        _filterAndSortAlerts();
        _isLoading = false;
      });
      print('AlertsScreen: setState concluído, _filteredAlerts: ${_filteredAlerts.length}');
    } catch (e, stackTrace) {
      print('AlertsScreen: Erro ao carregar alertas: $e');
      print('AlertsScreen: Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  void _filterAndSortAlerts() {
    print('AlertsScreen: _filterAndSortAlerts chamado');
    final query = removeDiacritics(_searchController.text.toLowerCase());
    print('AlertsScreen: Filtrando com query: $query');
    List<Map<String, dynamic>> filtered = _alerts.where((alert) {
      final documentName =
      removeDiacritics(alert['document_type_name']?.toString().toLowerCase() ?? '');
      final description = removeDiacritics(alert['description']?.toString().toLowerCase() ?? '');
      return query.isEmpty || documentName.contains(query) || description.contains(query);
    }).toList();

    print('AlertsScreen: Alertas após filtro: ${filtered.length}');
    switch (_sortOption) {
      case 'date_asc':
        filtered.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
        break;
      case 'date_desc':
        filtered.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        break;
      case 'doc_name_asc':
        filtered.sort((a, b) => (a['document_type_name'] ?? 'Sem Nome')
            .toLowerCase()
            .compareTo((b['document_type_name'] ?? 'Sem Nome').toLowerCase()));
        break;
      case 'doc_name_desc':
        filtered.sort((a, b) => (b['document_type_name'] ?? 'Sem Nome')
            .toLowerCase()
            .compareTo((a['document_type_name'] ?? 'Sem Nome').toLowerCase()));
        break;
    }

    setState(() {
      _filteredAlerts = filtered;
      print('AlertsScreen: _filteredAlerts atualizado: ${_filteredAlerts.length}');
    });
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
    print('AlertsScreen: _toggleAlertActive chamado para alertId: $alertId, isActive: $isActive');
    try {
      final db = await DataBaseHelper.instance.database;
      await db.update(
        'Alert',
        {'is_active': isActive ? 1 : 0},
        where: 'alert_id = ?',
        whereArgs: [alertId],
      );

      final alert = _alerts.firstWhere((a) => a['alert_id'] == alertId);
      if (isActive) {
        await scheduleNotification(
          id: alertId,
          title: alert['description'] ?? 'Alerta',
          body: 'Prazo para ${alert['document_type_name'] ?? 'Documento'}',
          scheduledDate: DateTime.parse(alert['date']),
          payload: 'alert_$alertId',
        );
      } else {
        await cancelNotification(alertId);
      }

      await loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alerta ${isActive ? 'ativado' : 'desativado'} com sucesso')),
        );
      }
    } catch (e) {
      print('AlertsScreen: Erro ao atualizar alerta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar alerta: $e')),
        );
      }
    }
  }

  Future<void> _editAlert(Map<String, dynamic> alert) async {
    print('AlertsScreen: _editAlert chamado para alertId: ${alert['alert_id']}');
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
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.darkerBlue,
                                ),
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
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.darkerBlue,
                                ),
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

                    if (alert['is_active'] == 1) {
                      await scheduleNotification(
                        id: alert['alert_id'],
                        title: descController.text,
                        body: 'Prazo para ${alert['document_type_name'] ?? 'Documento'}',
                        scheduledDate: updatedDate,
                        payload: 'alert_${alert['alert_id']}',
                      );
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alerta atualizado com sucesso')),
                      );
                      await loadAlerts();
                      Navigator.pop(dialogContext);
                    }
                  } catch (e) {
                    print('AlertsScreen: Erro ao atualizar alerta: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao atualizar alerta: $e')),
                      );
                    }
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
    print('AlertsScreen: _deleteAlert chamado para alertId: $alertId');
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

                  await cancelNotification(alertId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alerta excluído com sucesso')),
                    );
                    await loadAlerts();
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  print('AlertsScreen: Erro ao excluir alerta: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir alerta: $e')),
                    );
                  }
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
    print('AlertsScreen: build chamado, _isLoading: $_isLoading, _filteredAlerts: ${_filteredAlerts.length}');
    return Scaffold(
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
                      labelText: 'Pesquisar por documento ou descrição',
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
                print('AlertsScreen: Renderizando alerta $index: alert_id=${alert['alert_id']}');
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        alert['file_data'] != null
                            ? Image.memory(
                          Uint8List.fromList(List<int>.from(alert['file_data'])),
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
                                alert['description'] ?? 'Sem descrição',
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
                              Text(
                                'Documento: ${alert['document_type_name'] ?? 'Sem documento associado'}',
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
    );
  }

  @override
  void dispose() {
    print('AlertsScreen: dispose chamado');
    _searchController.dispose();
    super.dispose();
  }
}