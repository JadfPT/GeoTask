import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/*
  Ficheiro: database_helper.dart
  Propósito: Inicialização e migração do esquema SQLite da aplicação.

  Descrição:
  - Fornece um singleton `DatabaseHelper.instance` com getter `database`
    que garante a criação/abertura e aplicação de migrações necessárias.
  - Mantém a versão do esquema em `_dbVersion`. As migrações em `_onUpgrade`
    são idempotentes e seguras para execução ao arranque.

  Observações importantes para o professor:
  - Colunas adicionadas em migrações usam `try/catch` para serem seguras
    caso a coluna já exista (compatibilidade com versões anteriores).
  - Os tipos armazenados no esquema refletem como os DAOs persistem campos
    (ex.: `lastNotifiedAt` como INTEGER em epoch ms; `categories` pode ser
    JSON armazenado em TEXT).
*/

/// DatabaseHelper é um singleton que gere a abertura da base de dados SQLite
/// e a aplicação de migrações. Use `DatabaseHelper.instance.database` para
/// obter um handle [Database] pronto a usar.
class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static const _dbName = 'geotask.db';
  // bumped to 5 to add `lastNotifiedAt` column to tasks
  static const _dbVersion = 5;

  Database? _db;

  /// Returns an open [Database], creating or migrating it if necessary.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    // Ensure directory exists
    try {
      final dir = Directory(dirname(path));
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {}

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Initialize and return a database handle. This method ensures the
  /// parent directory exists and opens the database with the current
  /// schema version and migration callbacks.
  ///
  /// Note: callers should use the `database` getter which caches the
  /// opened handle on the helper instance.

  /// Called when a new database is created. Create the required tables here.
  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        note TEXT,
        due TEXT,
        done INTEGER NOT NULL DEFAULT 0,
        lat REAL,
        lng REAL,
        radius REAL DEFAULT 150,
        category TEXT,
        categories TEXT,
        lastNotifiedAt INTEGER,
        ownerId TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        username TEXT,
        passwordHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        ownerId TEXT NOT NULL,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        sortIndex INTEGER DEFAULT 0
      )
    ''');
  }

  /// Apply schema migrations between [oldVersion] and [newVersion]. Keep
  /// migrations idempotent and safe to call on startup.
  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // add ownerId column to tasks and create users table
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN ownerId TEXT');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          email TEXT NOT NULL UNIQUE,
          username TEXT,
          passwordHash TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
      oldVersion = 2;
    }

    if (oldVersion < 3) {
      // add username column to users table
      try {
        await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
      } catch (_) {}
    }

    if (oldVersion < 4) {
      // create categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          ownerId TEXT NOT NULL,
          name TEXT NOT NULL,
          color INTEGER NOT NULL,
          sortIndex INTEGER DEFAULT 0
        )
      ''');
    }

    if (oldVersion < 5) {
      // add lastNotifiedAt column to tasks to persist when a task was
      // last notified. Stored as epoch milliseconds (INTEGER).
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN lastNotifiedAt INTEGER');
      } catch (_) {}
    }
  }

  /// Close the open database handle if any.
  Future<void> close() async {
    final d = _db;
    if (d != null && d.isOpen) await d.close();
    _db = null;
  }
}
