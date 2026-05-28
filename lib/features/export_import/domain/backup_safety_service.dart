import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class BackupSafetyService {
  static Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'finance_app.db');
  }

  static Future<bool> verifyDatabaseExists() async {
    final path = await getDatabasePath();
    final file = File(path);
    return await file.exists();
  }

  static Future<bool> verifyDatabaseNotEmpty() async {
    final path = await getDatabasePath();
    final file = File(path);
    if (!await file.exists()) return false;
    final length = await file.length();
    return length > 0;
  }

  static Future<String> createLocalBackup() async {
    try {
      final path = await getDatabasePath();
      final file = File(path);
      
      if (!await file.exists()) {
        // Si no hay archivo, no hay nada que respaldar ni reemplazar. 
        // Aún así crearemos un respaldo vacío por si acaso.
        return '';
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final dbPathDir = await getDatabasesPath();
      final backupPath = join(dbPathDir, 'finance_app_local_backup_$timestamp.db');
      
      await file.copy(backupPath);
      return backupPath;
    } catch (e) {
      throw Exception('Fallo al crear el respaldo local preventivo: $e');
    }
  }

  static Future<void> validateLocalDatabase() async {
    final path = await getDatabasePath();
    if (!await verifyDatabaseExists()) {
      throw Exception('La base de datos local no existe.');
    }
    if (!await verifyDatabaseNotEmpty()) {
      throw Exception('La base de datos local está vacía.');
    }

    Database? db;
    try {
      // Intentar abrir la base de datos en modo solo lectura
      db = await openReadOnlyDatabase(path);
      
      // Verificar tablas requeridas
      final requiredTables = [
        'categories',
        'transactions',
        'budgets',
        'fixed_expenses',
        'fixed_expense_payments'
      ];

      final List<Map<String, Object?>> tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();

      for (var table in requiredTables) {
        if (!tableNames.contains(table)) {
          throw Exception('La tabla obligatoria "$table" no existe en la base de datos local.');
        }
      }
    } catch (e) {
      throw Exception('La base de datos local es inválida o está corrupta: $e');
    } finally {
      if (db != null) {
        await db.close();
      }
    }
  }
}
