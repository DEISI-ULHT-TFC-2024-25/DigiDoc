import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:typed_data';
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
    print('DataBaseHelper: Tentando abrir banco de dados em: $path');
    try {
      return await openDatabase(
        path,
        version: 10,
        onCreate: (db, version) async {
          print('DataBaseHelper: Criando banco de dados versão $version');
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
            biometric_enabled BOOLEAN NOT NULL,
            is_dark_mode BOOLEAN NOT NULL DEFAULT 0
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
          print('DataBaseHelper: Atualizando banco de dados de v$oldVersion para v$newVersion');
          if (oldVersion < 3) {
            final result = await db.rawQuery('PRAGMA table_info(Alert)');
            bool hasIsActive = result.any((column) => column['name'] == 'is_active');
            if (!hasIsActive) {
              await db.execute('ALTER TABLE Alert ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
              print('DataBaseHelper: Coluna is_active adicionada à tabela Alert');
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
              print('DataBaseHelper: Tabela Image criada');
            }
            final alertColumns = await db.rawQuery('PRAGMA table_info(Alert)');
            bool hasDocumentId = alertColumns.any((column) => column['name'] == 'document_id');
            if (!hasDocumentId) {
              await db.execute('ALTER TABLE Alert ADD COLUMN document_id INTEGER');
              print('DataBaseHelper: Coluna document_id adicionada à tabela Alert');
            }
          }
          if (oldVersion < 6) {
            try {
              await db.execute('ALTER TABLE Document DROP COLUMN alerts');
              print('DataBaseHelper: Coluna alerts removida da tabela Document');
            } catch (e) {
              print('DataBaseHelper: Erro ao remover coluna alerts: $e');
            }
          }
          if (oldVersion < 7) {
            final alertColumns = await db.rawQuery('PRAGMA table_info(Alert)');
            bool hasDocumentId = alertColumns.any((column) => column['name'] == 'document_id');
            if (!hasDocumentId) {
              await db.execute('ALTER TABLE Alert ADD COLUMN document_id INTEGER');
              print('DataBaseHelper: Coluna document_id adicionada à tabela Alert na versão 7');
            }
          }
          if (oldVersion < 8) {
            final invalidDocs = await db.rawQuery('''
              SELECT document_id FROM Document 
              WHERE dossier_id NOT IN (SELECT dossier_id FROM Dossier)
            ''');
            if (invalidDocs.isNotEmpty) {
              print('DataBaseHelper: Documentos com dossier_id inválido encontrados: $invalidDocs');
              for (var doc in invalidDocs) {
                await db.delete('Document', where: 'document_id = ?', whereArgs: [doc['document_id']]);
              }
              print('DataBaseHelper: Documentos inválidos removidos');
            }
          }
          if (oldVersion < 9) {
            final docColumns = await db.rawQuery('PRAGMA table_info(Document)');
            bool hasDocumentName = docColumns.any((column) => column['name'] == 'document_name');
            if (!hasDocumentName) {
              await db.execute('ALTER TABLE Document ADD COLUMN document_name TEXT NOT NULL DEFAULT "Sem Nome"');
              print('DataBaseHelper: Coluna document_name adicionada à tabela Document');
              await db.execute('''
                UPDATE Document 
                SET document_name = document_type_name 
                WHERE document_name IS NULL OR document_name = ''
              ''');
              print('DataBaseHelper: Valores padrão para document_name definidos');
            }
          }
          if (oldVersion < 10) {
            final userColumns = await db.rawQuery('PRAGMA table_info(User_data)');
            bool hasDarkMode = userColumns.any((column) => column['name'] == 'is_dark_mode');
            if (!hasDarkMode) {
              await db.execute('ALTER TABLE User_data ADD COLUMN is_dark_mode BOOLEAN NOT NULL DEFAULT 0');
              print('DataBaseHelper: Coluna is_dark_mode adicionada à tabela User_data');
            }
          }
        },
        onOpen: (db) async {
          print('DataBaseHelper: Banco de dados aberto');
          await db.execute('PRAGMA foreign_keys = ON;');
        },
      );
    } catch (e) {
      print('DataBaseHelper: Erro ao inicializar banco de dados em $path: $e');
      try {
        await deleteDatabase(path);
        print('DataBaseHelper: Banco de dados corrompido excluído, recriando...');
        return await openDatabase(
          path,
          version: 10,
          onCreate: (db, version) async {
            print('DataBaseHelper: Recriando banco de dados versão $version');
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
              biometric_enabled BOOLEAN NOT NULL,
              is_dark_mode BOOLEAN NOT NULL DEFAULT 0
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
            print('DataBaseHelper: Atualizando banco recriado de v$oldVersion para v$newVersion');
          },
          onOpen: (db) async {
            print('DataBaseHelper: Banco recriado aberto');
            await db.execute('PRAGMA foreign_keys = ON;');
          },
        );
      } catch (recreateError) {
        print('DataBaseHelper: Erro ao recriar banco de dados: $recreateError');
        rethrow;
      }
    }
  }

  Future<bool> hasPin() async {
    try {
      final db = await database;
      final result = await db.query('User_data');
      print('DataBaseHelper: hasPin, User_data: $result');
      return result.isNotEmpty && result.first['pin_hash'] != null;
    } catch (e) {
      print('DataBaseHelper: Erro em hasPin: $e');
      return false;
    }
  }

  Future<bool> validateIdentifier(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        'User_data',
        where: 'email = ?',
        whereArgs: [email],
      );
      print('DataBaseHelper: validateIdentifier, email: $email, encontrado: ${result.isNotEmpty}');
      return result.isNotEmpty;
    } catch (e) {
      print('DataBaseHelper: Erro em validateIdentifier: $e');
      return false;
    }
  }

  Future<bool> validatePin(String email, String pin) async {
    try {
      final db = await database;
      final result = await db.query(
        'User_data',
        where: 'email = ?',
        whereArgs: [email],
      );
      if (result.isEmpty) {
        print('DataBaseHelper: validatePin, nenhum usuário encontrado para email: $email');
        return false;
      }
      final storedPinHash = result.first['pin_hash'] as String?;
      if (storedPinHash == null) {
        print('DataBaseHelper: validatePin, pin_hash nulo para email: $email');
        return false;
      }
      final inputPinHash = hashPin(pin);
      final isValid = storedPinHash == inputPinHash;
      print('DataBaseHelper: validatePin, email: $email, válido: $isValid');
      return isValid;
    } catch (e) {
      print('DataBaseHelper: Erro em validatePin: $e');
      return false;
    }
  }

  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<bool> isUserRegistered() async {
    try {
      final db = await database;
      final result = await db.query('User_data');
      print('DataBaseHelper: isUserRegistered, User_data: $result');
      return result.isNotEmpty;
    } catch (e) {
      print('DataBaseHelper: Erro em isUserRegistered: $e');
      return false;
    }
  }

  Future<void> registerUser(String email, String pin, bool biometric) async {
    try {
      final db = await database;
      final pinHash = pin.isNotEmpty ? hashPin(pin) : null;
      await db.insert(
        'User_data',
        {
          'email': email,
          'pin_hash': pinHash,
          'biometric_enabled': biometric ? 1 : 0,
          'is_dark_mode': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('DataBaseHelper: Usuário registrado: email=$email, biometric=${biometric ? 1 : 0}');
    } catch (e) {
      print('DataBaseHelper: Erro em registerUser: $e');
      rethrow;
    }
  }

  Future<bool> isBiometricEnabled(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        'User_data',
        where: 'email = ?',
        whereArgs: [email],
      );
      print('DataBaseHelper: isBiometricEnabled, User_data: $result');
      if (result.isNotEmpty) {
        final biometricEnabled = result.first['biometric_enabled'] == 1;
        print('DataBaseHelper: Biometria habilitada para $email: $biometricEnabled');
        return biometricEnabled;
      }
      print('DataBaseHelper: Nenhum usuário encontrado para $email');
      return false;
    } catch (e) {
      print('DataBaseHelper: Erro em isBiometricEnabled: $e');
      return false;
    }
  }

  Future<bool> isDarkModeEnabled(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        'User_data',
        where: 'email = ?',
        whereArgs: [email],
      );
      print('DataBaseHelper: isDarkModeEnabled, User_data: $result');
      if (result.isNotEmpty) {
        final darkModeEnabled = result.first['is_dark_mode'] == 1;
        print('DataBaseHelper: Modo escuro habilitado para $email: $darkModeEnabled');
        return darkModeEnabled;
      }
      print('DataBaseHelper: Nenhum usuário encontrado para $email');
      return false;
    } catch (e) {
      print('DataBaseHelper: Erro em isDarkModeEnabled: $e');
      return false;
    }
  }

  Future<void> setDarkMode(String email, bool isDarkMode) async {
    try {
      final db = await database;
      await db.update(
        'User_data',
        {'is_dark_mode': isDarkMode ? 1 : 0},
        where: 'email = ?',
        whereArgs: [email],
      );
      print('DataBaseHelper: Modo escuro atualizado para $email: $isDarkMode');
    } catch (e) {
      print('DataBaseHelper: Erro em setDarkMode: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      final result = await db.query(table, where: where, whereArgs: whereArgs);
      print('DataBaseHelper: query, tabela: $table, resultado: $result');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em query, tabela: $table: $e');
      rethrow;
    }
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      final result = await db.update(table, values, where: where, whereArgs: whereArgs);
      print('DataBaseHelper: update, tabela: $table, valores: $values, resultado: $result');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em update, tabela: $table: $e');
      rethrow;
    }
  }

  Future<void> createDossier(String dossierName) async {
    try {
      final db = await database;
      await db.insert('Dossier', {
        'name': dossierName,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('DataBaseHelper: Dossiê criado: $dossierName');
    } catch (e) {
      print('DataBaseHelper: Erro em createDossier: $e');
      rethrow;
    }
  }

  Future<bool> isDossierNameExists(String dossierName) async {
    try {
      final db = await database;
      final result = await db.query(
        'Dossier',
        where: 'name = ?',
        whereArgs: [dossierName],
      );
      print('DataBaseHelper: isDossierNameExists, nome: $dossierName, existe: ${result.isNotEmpty}');
      return result.isNotEmpty;
    } catch (e) {
      print('DataBaseHelper: Erro em isDossierNameExists: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDossiers() async {
    try {
      final db = await database;
      final result = await db.query('Dossier', orderBy: 'created_at DESC');
      print('DataBaseHelper: getDossiers, resultado: $result');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em getDossiers: $e');
      return [];
    }
  }

  Future<int> insertDossier(String dossierName) async {
    try {
      final db = await database;
      final dossier = {
        'name': dossierName,
        'created_at': DateTime.now().toIso8601String(),
      };
      final id = await db.insert('Dossier', dossier);
      if (id <= 0) {
        throw Exception('Falha ao criar dossiê: ID inválido gerado ($id)');
      }
      print('DataBaseHelper: Dossier inserido com ID: $id');
      return id;
    } catch (e) {
      print('DataBaseHelper: Erro em insertDossier: $e');
      rethrow;
    }
  }

  Future<int> insertDocument(
      String documentTypeName,
      String documentName,
      Uint8List fileData,
      Uint8List fileDataPrint,
      String extractedText,
      int dossierId) async {
    try {
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
      print('DataBaseHelper: Documento inserido com ID: $id, dossierId: $dossierId');
      return id;
    } catch (e) {
      print('DataBaseHelper: Erro em insertDocument: $e');
      rethrow;
    }
  }

  Future<int> insertImage(int documentId, String extractedText) async {
    try {
      final db = await database;
      final image = {
        'document_id': documentId,
        'extracted_text': extractedText,
      };
      final id = await db.insert('Image', image);
      print('DataBaseHelper: Imagem inserida com ID: $id para documentId: $documentId');
      return id;
    } catch (e) {
      print('DataBaseHelper: Erro em insertImage: $e');
      rethrow;
    }
  }

  Future<int> insertAlert(String description, DateTime date, int documentId) async {
    try {
      final db = await database;
      final alert = {
        'date': date.toIso8601String(),
        'name': description,
        'is_active': 1,
        'document_id': documentId,
      };
      final id = await db.insert('Alert', alert);
      print('DataBaseHelper: Alerta inserido com ID: $id para documentId: $documentId');
      return id;
    } catch (e) {
      print('DataBaseHelper: Erro em insertAlert: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDocuments(int dossierId) async {
    try {
      final db = await database;
      print('DataBaseHelper: Buscando documentos para dossierId: $dossierId');
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
      print('DataBaseHelper: Documentos encontrados: ${result.length} para dossierId: $dossierId');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em getDocuments: $e');
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
      print('DataBaseHelper: getDocumentFileData, documentId: $documentId, resultado: $result');
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('DataBaseHelper: Erro em getDocumentFileData: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    try {
      final db = await database;
      print('DataBaseHelper: Buscando todos os alertas');
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
      print('DataBaseHelper: Alertas encontrados: ${result.length}');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em getAlerts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAlertsForDocument(int documentId) async {
    try {
      final db = await database;
      print('DataBaseHelper: Buscando alertas para documentId: $documentId');
      final result = await db.rawQuery('''
        SELECT 
          a.alert_id,
          a.date,
          a.name AS description,
          a.is_active
        FROM Alert a
        WHERE a.document_id = ? AND a.is_active = 1
      ''', [documentId]);
      print('DataBaseHelper: Alertas encontrados para documentId $documentId: ${result.length}');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em getAlertsForDocument: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchDocumentsByText(int dossierId, String query) async {
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
        Document.dossier_id,
        Document.file_data
      FROM Document
      LEFT JOIN Image ON Image.document_id = Document.document_id
      WHERE Document.dossier_id = ? 
        AND (LOWER(Image.extracted_text) LIKE ? 
             OR LOWER(Document.extracted_texts) LIKE ?
             OR LOWER(Document.document_name) LIKE ?)
    ''', [dossierId, '%$normalizedQuery%', '%$normalizedQuery%', '%$normalizedQuery%']);

      print('DataBaseHelper: Documentos encontrados para query "$query" no dossier $dossierId: ${result.length}');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em searchDocumentsByText: $e');
      return [];
    }
  }

  Future<int> deleteDossier(int dossierId) async {
    try {
      final db = await database;
      final result = await db.delete(
        'Dossier',
        where: 'dossier_id = ?',
        whereArgs: [dossierId],
      );
      print('DataBaseHelper: Dossiê deletado, dossierId: $dossierId, resultado: $result');
      return result;
    } catch (e) {
      print('DataBaseHelper: Erro em deleteDossier: $e');
      return 0;
    }
  }

  Future<void> deleteDocument(int id) async {
    try {
      final db = await database;
      await db.delete('Document', where: 'document_id = ?', whereArgs: [id]);
      print('DataBaseHelper: Documento deletado, documentId: $id');
    } catch (e) {
      print('DataBaseHelper: Erro em deleteDocument: $e');
      rethrow;
    }
  }

  Future<void> diagnoseDatabase() async {
    try {
      final db = await database;
      final fkStatus = await db.rawQuery('PRAGMA foreign_keys;');
      print('DataBaseHelper: Estado das chaves estrangeiras: $fkStatus');
      final invalidDocuments = await db.rawQuery('''
        SELECT document_id, dossier_id 
        FROM Document 
        WHERE dossier_id NOT IN (SELECT dossier_id FROM Dossier)''');

      print('DataBaseHelper: Documentos com dossierId inválido: $invalidDocuments');
      final nullDocuments = await db.query(
        'Document',
        where: 'dossier_id IS NULL OR dossier_id = 0',
        columns: ['document_id', 'dossier_id'],
      );
      print('DataBaseHelper: Documentos com dossierId nulo ou zero: $nullDocuments');
      final dossiers = await db.query('Dossier');
      print('DataBaseHelper: Dossiês no banco: $dossiers');
      final documents = await db.query(
        'Document',
        columns: ['document_id', 'document_type_name', 'document_name', 'created_at', 'dossier_id'],
      );
      print('DataBaseHelper: Documentos no banco: $documents');
      final alerts = await db.query('Alert');
      print('DataBaseHelper: Alertas no banco: $alerts');
      final images = await db.query('Image');
      print('DataBaseHelper: Imagens no banco: $images');
      final users = await db.query('User_data');
      print('DataBaseHelper: Usuários no banco: $users');
      final tableInfo = await db.rawQuery('PRAGMA table_info(Document)');
      print('DataBaseHelper: Estrutura da tabela Document: $tableInfo');
      final userTableInfo = await db.rawQuery('PRAGMA table_info(User_data)');
      print('DataBaseHelper: Estrutura da tabela User_data: $userTableInfo');
    } catch (e) {
      print('DataBaseHelper: Erro em diagnoseDatabase: $e');
    }
  }

  Future<int?> getImageCountForDocument(int documentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Image WHERE document_id = ?',
      [documentId],
    );
    return result.isNotEmpty ? Sqflite.firstIntValue(result) : 0;
  }
}