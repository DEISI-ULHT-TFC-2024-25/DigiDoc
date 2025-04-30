import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:diacritic/diacritic.dart';

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
      version: 9,
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON;');

        await db.execute('''
        CREATE TABLE Document (
          document_id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_type_name TEXT NOT NULL,
          document_name TEXT NOT NULL,
          file_data BLOB NOT NULL,
          file_data_print BLOB NOT NULL,
          extracted_texts TEXT,
          created_at DATETIME NOT NULL,
          dossier_id INTEGER NOT NULL,
          FOREIGN KEY (dossier_id) REFERENCES Dossier(dossier_id) ON DELETE CASCADE
        )
        ''');

        await db.execute('''
        CREATE TABLE User_data (
          user_data_id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL UNIQUE,
          pin_hash TEXT NULL,
          biometric_enabled BOOLEAN NOT NULL
        )
        ''');

        await db.execute('''
        CREATE TABLE Alert (
          alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
          date DATETIME NOT NULL,
          name TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          document_id INTEGER,
          FOREIGN KEY (document_id) REFERENCES Document(document_id) ON DELETE CASCADE
        )
        ''');

        await db.execute('''
        CREATE TABLE Dossier (
          dossier_id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at DATETIME NOT NULL,
          name TEXT NOT NULL
        )
        ''');

        await db.execute('''
        CREATE TABLE Image (
          image_id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id INTEGER NOT NULL,
          extracted_text TEXT,
          FOREIGN KEY (document_id) REFERENCES Document(document_id) ON DELETE CASCADE
        )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          final result = await db.rawQuery('PRAGMA table_info(Alert)');
          bool hasIsActive = result.any((column) => column['name'] == 'is_active');
          if (!hasIsActive) {
            await db.execute('ALTER TABLE Alert ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
            print('Coluna is_active adicionada à tabela Alert');
          }
        }
        if (oldVersion < 5) {
          final tables = await db.rawQuery(
              'SELECT name FROM sqlite_master WHERE type="table" AND name="Image"');
          if (tables.isEmpty) {
            await db.execute('''
            CREATE TABLE Image (
              image_id INTEGER PRIMARY KEY AUTOINCREMENT,
              document_id INTEGER NOT NULL,
              extracted_text TEXT,
              FOREIGN KEY (document_id) REFERENCES Document(document_id) ON DELETE CASCADE
            )
            ''');
            print('Tabela Image criada');
          }
          final alertColumns = await db.rawQuery('PRAGMA table_info(Alert)');
          bool hasDocumentId = alertColumns.any((column) => column['name'] == 'document_id');
          if (!hasDocumentId) {
            await db.execute('ALTER TABLE Alert ADD COLUMN document_id INTEGER');
            print('Coluna document_id adicionada à tabela Alert');
          }
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE Document DROP COLUMN alerts');
            print('Coluna alerts removida da tabela Document');
          } catch (e) {
            print('Erro ao remover coluna alerts: $e');
          }
        }
        if (oldVersion < 7) {
          final alertColumns = await db.rawQuery('PRAGMA table_info(Alert)');
          bool hasDocumentId = alertColumns.any((column) => column['name'] == 'document_id');
          if (!hasDocumentId) {
            await db.execute('ALTER TABLE Alert ADD COLUMN document_id INTEGER');
            print('Coluna document_id adicionada à tabela Alert na versão 7');
          }
        }
        if (oldVersion < 8) {
          final invalidDocs = await db.rawQuery('''
            SELECT document_id FROM Document 
            WHERE dossier_id NOT IN (SELECT dossier_id FROM Dossier)
          ''');
          if (invalidDocs.isNotEmpty) {
            print('Documentos com dossier_id inválido encontrados: $invalidDocs');
            for (var doc in invalidDocs) {
              await db.delete('Document', where: 'document_id = ?', whereArgs: [doc['document_id']]);
            }
            print('Documentos inválidos removidos');
          }
        }
        if (oldVersion < 9) {
          final docColumns = await db.rawQuery('PRAGMA table_info(Document)');
          bool hasDocumentName = docColumns.any((column) => column['name'] == 'document_name');
          if (!hasDocumentName) {
            await db.execute('ALTER TABLE Document ADD COLUMN document_name TEXT NOT NULL DEFAULT "Sem Nome"');
            print('Coluna document_name adicionada à tabela Document');
            await db.execute('''
              UPDATE Document 
              SET document_name = document_type_name 
              WHERE document_name IS NULL OR document_name = ''
            ''');
            print('Valores padrão para document_name definidos');
          }
        }
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<bool> hasPin() async {
    final db = await database;
    final result = await db.query('User_data');
    return result.isNotEmpty && result.first['pin_hash'] != null;
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

    final inputPinHash = hashPin(pin);
    return storedPinHash == inputPinHash;
  }

  String hashPin(String pin) {
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
    final pinHash = pin.isNotEmpty ? hashPin(pin) : null;
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

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
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

  Future<int> insertDossier(String dossierName) async {
    final db = await database;
    final dossier = {
      'name': dossierName,
      'created_at': DateTime.now().toIso8601String(),
    };
    final id = await db.insert('Dossier', dossier);
    if (id <= 0) {
      throw Exception('Falha ao criar dossiê: ID inválido gerado ($id)');
    }
    print('Dossier inserido com ID: $id');
    return id;
  }

  Future<int> insertDocument(
      String documentTypeName,
      String documentName,
      Uint8List fileData,
      Uint8List fileDataPrint,
      String extractedText,
      int dossierId) async {
    if (dossierId <= 0) {
      throw Exception('Invalid dossierId: $dossierId');
    }
    final db = await database;
    final dossierExists = await db.query(
      'Dossier',
      where: 'dossier_id = ?',
      whereArgs: [dossierId],
    );
    if (dossierExists.isEmpty) {
      throw Exception('Dossier com ID $dossierId não existe');
    }
    final document = {
      'document_type_name': documentTypeName,
      'document_name': documentName,
      'file_data': fileData,
      'file_data_print': fileDataPrint,
      'extracted_texts': extractedText,
      'created_at': DateTime.now().toIso8601String(),
      'dossier_id': dossierId,
    };
    final id = await db.insert('Document', document);
    print('Inserted document ID: $id with dossierId: $dossierId');
    return id;
  }

  Future<int> insertImage(int documentId, String extractedText) async {
    final db = await database;
    final image = {
      'document_id': documentId,
      'extracted_text': extractedText,
    };
    final id = await db.insert('Image', image);
    print('Inserted image ID: $id for documentId: $documentId');
    return id;
  }

  Future<int> insertAlert(String description, DateTime date, int documentId) async {
    final db = await database;
    final alert = {
      'date': date.toIso8601String(),
      'name': description,
      'is_active': 1,
      'document_id': documentId,
    };
    final id = await db.insert('Alert', alert);
    print('Inserted alert ID: $id for documentId: $documentId');
    return id;
  }

  Future<List<Map<String, dynamic>>> getDocuments(int dossierId) async {
    try {
      final db = await database;
      print('Buscando documentos para dossierId: $dossierId');
      final result = await db.query(
        'Document',
        where: 'dossier_id = ?',
        whereArgs: [dossierId],
        columns: [
          'document_id',
          'document_type_name',
          'document_name',
          'created_at',
          'file_data',
          'file_data_print',
        ],
        orderBy: 'created_at DESC',
      );
      print('Documentos encontrados: ${result.length} para dossierId: $dossierId');
      print('Documentos: $result');
      return result;
    } catch (e, stackTrace) {
      print('Erro ao buscar documentos: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDocumentFileData(int documentId) async {
    try {
      final db = await database;
      final result = await db.query(
        'Document',
        columns: ['file_data', 'file_data_print'],
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e, stackTrace) {
      print('Erro ao buscar file_data para documentId $documentId: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    try {
      final db = await database;
      print('Buscando todos os alertas');
      final result = await db.rawQuery('''
      SELECT 
        a.alert_id,
        a.date,
        a.name AS description,
        a.is_active,
        a.document_id,
        d.document_type_name,
        d.document_name,
        d.file_data
      FROM Alert a
      LEFT JOIN Document d ON a.document_id = d.document_id
    ''');
      print('Alertas encontrados: ${result.length}');
      for (var alert in result) {
        print('Alerta: alert_id=${alert['alert_id']}, description=${alert['description']}, '
            'date=${alert['date']}, is_active=${alert['is_active']}, '
            'document_id=${alert['document_id']}, document_type_name=${alert['document_type_name']}, '
            'document_name=${alert['document_name']}');
      }
      return result;
    } catch (e, stackTrace) {
      print('Erro ao buscar alertas: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAlertsForDocument(int documentId) async {
    try {
      final db = await database;
      print('Buscando alertas para documentId: $documentId');
      final result = await db.rawQuery('''
        SELECT 
          a.alert_id,
          a.date,
          a.name AS description,
          a.is_active
        FROM Alert a
        WHERE a.document_id = ? AND a.is_active = 1
      ''', [documentId]);
      print('Alertas encontrados para documentId $documentId: ${result.length}');
      print('Alertas: $result');
      return result;
    } catch (e, stackTrace) {
      print('Erro ao buscar alertas para documentId $documentId: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchDocumentsByText(String query) async {
    try {
      final normalizedQuery = removeDiacritics(query.toLowerCase());
      final db = await database;
      final result = await db.rawQuery('''
        SELECT DISTINCT 
          Document.document_id,
          Document.document_type_name,
          Document.document_name,
          Document.extracted_texts,
          Document.created_at,
          Document.dossier_id
        FROM Document
        LEFT JOIN Image ON Image.document_id = Document.document_id
        WHERE LOWER(removeDiacritics(Image.extracted_text)) LIKE ? 
           OR LOWER(removeDiacritics(Document.extracted_texts)) LIKE ?
      ''', ['%$normalizedQuery%', '%$normalizedQuery%']);
      print('Documentos encontrados para query "$query": ${result.length}');
      return result;
    } catch (e, stackTrace) {
      print('Erro ao buscar documentos por texto: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<int> deleteDossier(int dossierId) async {
    final db = await database;
    return await db.delete(
      'Dossier',
      where: 'dossier_id = ?',
      whereArgs: [dossierId],
    );
  }

  Future<void> deleteDocument(int id) async {
    final db = await database;
    await db.delete('Document', where: 'document_id = ?', whereArgs: [id]);
  }

  Future<void> diagnoseDatabase() async {
    final db = await database;
    final fkStatus = await db.rawQuery('PRAGMA foreign_keys;');
    print('Estado das chaves estrangeiras: $fkStatus');
    final invalidDocuments = await db.rawQuery('''
      SELECT document_id, dossier_id 
      FROM Document 
      WHERE dossier_id NOT IN (SELECT dossier_id FROM Dossier)
    ''');
    print('Documentos com dossierId inválido: $invalidDocuments');
    final nullDocuments = await db.query(
      'Document',
      where: 'dossier_id IS NULL OR dossier_id = 0',
      columns: ['document_id', 'dossier_id'],
    );
    print('Documentos com dossierId nulo ou zero: $nullDocuments');
    final dossiers = await db.query('Dossier');
    print('Dossiês no banco: $dossiers');
    final documents = await db.query(
      'Document',
      columns: ['document_id', 'document_type_name', 'document_name', 'created_at', 'dossier_id'],
    );
    print('Documentos no banco: $documents');
    final alerts = await db.query('Alert');
    print('Alertas no banco: $alerts');
    final images = await db.query('Image');
    print('Imagens no banco: $images');
    final tableInfo = await db.rawQuery('PRAGMA table_info(Document)');
    print('Estrutura da tabela Document: $tableInfo');
  }
}