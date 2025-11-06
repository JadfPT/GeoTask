import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static const _dbName = 'geotask.db';
  static const _dbVersion = 1;

  Database? _db;

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
        categories TEXT
      )
    ''');
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here when incrementing _dbVersion
  }

  Future<void> close() async {
    final d = _db;
    if (d != null && d.isOpen) await d.close();
    _db = null;
  }
}
