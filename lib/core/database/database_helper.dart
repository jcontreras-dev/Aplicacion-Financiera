import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Los bloques if de migración NO deben estar anidados.
        // Si un usuario actualiza de la v1 a la v4, SQLite ejecutará primero
        // oldVersion < 2, luego oldVersion < 3, y finalmente oldVersion < 4.
        // Anidarlos causaría que algunas actualizaciones nunca se ejecuten.
        if (oldVersion < 2) {
          // NO usamos DROP TABLE para evitar la pérdida irreversible de datos.
          // Solo nos aseguramos de crear las tablas si por alguna razón no existieran.
          await _createCoreTables(db);
        }
        if (oldVersion < 3) {
          await _createBudgetsTable(db);
        }
        if (oldVersion < 4) {
          await _createFixedExpensesTables(db);
        }
      },
      onOpen: (db) async {
        // Validación defensiva:
        // Aseguramos que las tablas críticas existan siempre usando IF NOT EXISTS.
        // Esto previene crashes si el archivo SQLite vino vacío o corrupto 
        // (por ejemplo, por una mala importación de Drive sin estructura).
        // Y al usar IF NOT EXISTS, NO modificamos ni alteramos los datos existentes.
        await _createCoreTables(db);
        await _createBudgetsTable(db);
        await _createFixedExpensesTables(db);
      }
    );
  }

  Future<void> _createCoreTables(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id $idType,
        name $textType,
        icon $textType,
        color $textType,
        isIncome $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id $idType,
        amount $realType,
        categoryId $textType,
        date $textType,
        description $textType,
        details $textTypeNull,
        receiptImagePath $textTypeNull,
        ocrRawText $textTypeNull,
        isIncome $integerType
      )
    ''');
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        categoryId TEXT PRIMARY KEY,
        amountLimit REAL NOT NULL
      )
    ''');
  }

  Future<void> _createFixedExpensesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_expenses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        categoryId TEXT NOT NULL,
        dayOfMonth INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_expense_payments (
        fixedExpenseId TEXT NOT NULL,
        monthKey TEXT NOT NULL,
        PRIMARY KEY (fixedExpenseId, monthKey)
      )
    ''');
  }

  Future _createDB(Database db, int version) async {
    await _createCoreTables(db);
    await _createBudgetsTable(db);
    await _createFixedExpensesTables(db);

    // Insertar categorías por defecto
    await _insertDefaultCategories(db);
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      {'id': 'cat_1', 'name': 'Alimentación', 'icon': 'restaurant', 'color': '0xFFF44336', 'isIncome': 0},
      {'id': 'cat_2', 'name': 'Servicios', 'icon': 'bolt', 'color': '0xFFFF9800', 'isIncome': 0},
      {'id': 'cat_3', 'name': 'Otros', 'icon': 'category', 'color': '0xFF9E9E9E', 'isIncome': 0},
      {'id': 'cat_4', 'name': 'Ingresos / Salario', 'icon': 'attach_money', 'color': '0xFF4CAF50', 'isIncome': 1},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', cat, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
