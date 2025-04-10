import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/journey.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('journeys.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journeys(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        budget REAL NOT NULL
      )
    ''');
  }

  Future<Journey> create(Journey journey) async {
    final db = await instance.database;
    await db.insert('journeys', journey.toMap());
    return journey;
  }

  Future<List<Journey>> readAllJourneys() async {
    final db = await instance.database;
    final result = await db.query('journeys');
    return result.map((json) => Journey.fromMap(json)).toList();
  }

  Future<Journey?> readJourney(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'journeys',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Journey.fromMap(maps.first);
    }
    return null;
  }

  Future<int> update(Journey journey) async {
    final db = await instance.database;
    return db.update(
      'journeys',
      journey.toMap(),
      where: 'id = ?',
      whereArgs: [journey.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return db.delete(
      'journeys',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
} 