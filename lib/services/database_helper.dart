import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/journey.dart';
import '../models/expense.dart';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'travel_expense.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE journeys(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE users(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE journey_users(
          journey_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          FOREIGN KEY (journey_id) REFERENCES journeys (id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
          PRIMARY KEY (journey_id, user_id)
        )
      ''');

      await txn.execute('''
        CREATE TABLE expenses(
          id TEXT PRIMARY KEY,
          journey_id TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          category TEXT NOT NULL,
          FOREIGN KEY (journey_id) REFERENCES journeys (id) ON DELETE CASCADE
        )
      ''');
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        // Create new tables
        await txn.execute('''
          CREATE TABLE users(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL
          )
        ''');

        await txn.execute('''
          CREATE TABLE journey_users(
            journey_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            FOREIGN KEY (journey_id) REFERENCES journeys (id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            PRIMARY KEY (journey_id, user_id)
          )
        ''');

        // Remove destination column from journeys table
        await txn.execute('''
          CREATE TABLE journeys_new(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL
          )
        ''');

        await txn.execute('''
          INSERT INTO journeys_new (id, title, description, start_date, end_date)
          SELECT id, title, description, start_date, end_date FROM journeys
        ''');

        await txn.execute('DROP TABLE journeys');
        await txn.execute('ALTER TABLE journeys_new RENAME TO journeys');
      });
    }
  }

  Future<List<Map<String, dynamic>>> query(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.query(
      table,
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<int> create(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String table, String id) async {
    final db = await database;
    return await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalExpensesForJourney(String journeyId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM expenses
      WHERE journey_id = ?
    ''', [journeyId]);
    return result.first['total'] as double? ?? 0.0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Journey operations
  Future<Journey> createJourney(Journey journey) async {
    final db = await instance.database;
    
    try {
      await db.transaction((txn) async {
        // Insert journey
        await txn.insert('journeys', {
          'id': journey.id,
          'title': journey.title,
          'description': journey.description,
          'start_date': journey.startDate.toIso8601String(),
          'end_date': journey.endDate.toIso8601String(),
        });
        
        // Insert users and journey_users relationships
        for (final user in journey.users) {
          await txn.insert('users', user.toJson(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          await txn.insert('journey_users', {
            'journey_id': journey.id,
            'user_id': user.id,
          });
        }
      });
      
      return journey;
    } catch (e) {
      print('Error creating journey: $e');
      rethrow;
    }
  }

  Future<List<Journey>> readAllJourneys() async {
    final db = await instance.database;
    
    try {
      final journeys = await db.query('journeys');
      
      return Future.wait(journeys.map((journeyData) async {
        final users = await db.rawQuery('''
          SELECT u.*
          FROM users u
          JOIN journey_users ju ON u.id = ju.user_id
          WHERE ju.journey_id = ?
        ''', [journeyData['id']]);
        
        return Journey.fromJson({
          ...journeyData,
          'users': users,
        });
      }));
    } catch (e) {
      print('Error reading journeys: $e');
      rethrow;
    }
  }

  Future<Journey?> readJourney(String id) async {
    final db = await instance.database;
    
    try {
      final journeys = await db.query(
        'journeys',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (journeys.isEmpty) return null;

      final journeyData = journeys.first;
      final users = await db.rawQuery('''
        SELECT u.*
        FROM users u
        JOIN journey_users ju ON u.id = ju.user_id
        WHERE ju.journey_id = ?
      ''', [id]);
      
      return Journey.fromJson({
        ...journeyData,
        'users': users,
      });
    } catch (e) {
      print('Error reading journey: $e');
      rethrow;
    }
  }

  Future<int> updateJourney(Journey journey) async {
    final db = await instance.database;
    
    try {
      return await db.transaction((txn) async {
        // Update journey data
        final result = await txn.update(
          'journeys',
          {
            'title': journey.title,
            'description': journey.description,
            'start_date': journey.startDate.toIso8601String(),
            'end_date': journey.endDate.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [journey.id],
        );
        
        // Update users
        await txn.delete(
          'journey_users',
          where: 'journey_id = ?',
          whereArgs: [journey.id],
        );
        
        for (final user in journey.users) {
          await txn.insert('users', user.toJson(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          await txn.insert('journey_users', {
            'journey_id': journey.id,
            'user_id': user.id,
          });
        }
        
        return result;
      });
    } catch (e) {
      print('Error updating journey: $e');
      rethrow;
    }
  }

  Future<int> deleteJourney(String id) async {
    final db = await instance.database;
    
    try {
      return await db.delete(
        'journeys',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting journey: $e');
      rethrow;
    }
  }

  // Expense operations
  Future<Expense> createExpense(Expense expense) async {
    final db = await instance.database;
    
    try {
      await db.insert('expenses', expense.toMap());
      return expense;
    } catch (e) {
      print('Error creating expense: $e');
      rethrow;
    }
  }

  Future<List<Expense>> readExpensesForJourney(String journeyId) async {
    final db = await instance.database;
    
    try {
      final result = await db.query(
        'expenses',
        where: 'journey_id = ?',
        whereArgs: [journeyId],
        orderBy: 'date DESC',
      );
      return result.map((json) => Expense.fromMap(json)).toList();
    } catch (e) {
      print('Error reading expenses: $e');
      rethrow;
    }
  }

  Future<Expense?> readExpense(String id) async {
    final db = await instance.database;
    
    try {
      final maps = await db.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return Expense.fromMap(maps.first);
    } catch (e) {
      print('Error reading expense: $e');
      rethrow;
    }
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    
    try {
      return await db.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    
    try {
      return await db.delete(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }
} 