import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DataBaseHelper {

  static final DataBaseHelper instance = DataBaseHelper._internal();
  factory DataBaseHelper() => instance;
  DataBaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'digidoc.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Document (
            document_id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_type_name TEXT NOT NULL,
            file_data BLOB NOT NULL,
            file_data_print BLOB NOT NULL,
            extracted_texts TEXT,
            created_at DATETIME NOT NULL,
            alerts INTEGER,
            dossier_id INTEGER NOT NULL,
            FOREIGN KEY (alerts) REFERENCES Alert(alert_id),
            FOREIGN KEY (dossier_id) REFERENCES Dossier(dossier_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE User_data (
            user_data_id INTEGER PRIMARY KEY AUTOINCREMENT,
            pin TEXT NOT NULL,
            biometric BOOLEAN NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE Alert (
            alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
            date DATETIME NOT NULL,
            name TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE Dossier (
            dossier_id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at DATETIME NOT NULL,
            name TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> createDossier(String dossierName) async {
    final db = await database;
    await db.insert('Dossier', {
      'name': dossierName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> isDossierNameExists(String dossierName) async {
    final db = await database;
    var result = await db.query(
      'Dossier',
      where: 'name = ?',
      whereArgs: [dossierName],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getDossiers() async {
    final db = await database;
    return await db.query('Dossier', orderBy: 'created_at DESC');
  }

  Future<int> insertDocument(String documentType, Uint8List fileData, Uint8List fileDataPrint, String? extractedTexts, int dossierId, {int? alertId}) async {
    final db = await database;
    return await db.insert('Document', {
      'document_type_name': documentType,
      'file_data': fileData,
      'file_data_print': fileDataPrint,
      'extracted_texts': extractedTexts,
      'created_at': DateTime.now().toIso8601String(),
      'alerts': alertId,
      'dossier_id': dossierId
    });
  }

  Future<List<Map<String, dynamic>>> getDocuments(int dossierId) async {
    final db = await database;
    return await db.query(
      'Document',
      where: 'dossier_id = ?',
      whereArgs: [dossierId],
    );
  }

  Future<void> deleteDocument(int id) async {
    final db = await database;
    await db.delete('Document', where: 'document_id = ?', whereArgs: [id]);
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sucesso'),
          content: Text('Dossier criado com sucesso!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Erro'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Fechar"),
            ),
          ],
        );
      },
    );
  }
}
