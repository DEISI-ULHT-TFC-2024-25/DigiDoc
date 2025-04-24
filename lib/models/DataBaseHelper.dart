// models/DataBaseHelper.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
            email TEXT NOT NULL UNIQUE,
            pin_hash TEXT, -- Armazena o hash do PIN
            biometric_enabled BOOLEAN NOT NULL
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

  Future<bool> validateIdentifier(String email) async {
    final db = await database;
    final result = await db.query(
      'User_data',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty;
  }

  Future<bool> validatePin(String email, String pin) async {
    final db = await database;
    final result = await db.query(
      'User_data',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isEmpty) return false;

    final storedPinHash = result.first['pin_hash'] as String?;
    if (storedPinHash == null) return false;

    final inputPinHash = _hashPin(pin);
    return storedPinHash == inputPinHash;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<bool> isUserRegistered() async {
    final db = await database;
    final result = await db.query('User_data');
    return result.isNotEmpty;
  }

  Future<void> registerUser(String email, String pin, bool biometric) async {
    final db = await database;
    final pinHash = pin.isNotEmpty ? _hashPin(pin) : null;
    await db.insert('User_data', {
      'email': email,
      'pin_hash': pinHash,
      'biometric_enabled': biometric ? 1 : 0,
    });
    print('Usuário registrado: email=$email, biometric=${biometric ? 1 : 0}');
  }

  Future<bool> isBiometricEnabled(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        'User_data',
        where: 'email = ?',
        whereArgs: [email],
      );
      print('User_data query result: $result');
      if (result.isNotEmpty) {
        final biometricEnabled = result.first['biometric_enabled'] == 1;
        print('Biometria habilitada no banco: $biometricEnabled');
        return biometricEnabled;
      }
      print('Nenhum usuário registrado');
      return false;
    } catch (e) {
      print('Erro ao verificar biometria no banco: $e');
      return false;
    }
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