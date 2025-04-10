import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/database_helper.dart';

class UserProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<User> _users = [];

  List<User> get users => _users;

  Future<void> loadUsers() async {
    _users = await _dbHelper.readAllUsers();
    notifyListeners();
  }

  Future<void> createUser(User user) async {
    await _dbHelper.createUser(user);
    await loadUsers();
  }

  Future<void> updateUser(User user) async {
    await _dbHelper.updateUser(user);
    await loadUsers();
  }

  Future<void> deleteUser(String id) async {
    await _dbHelper.deleteUser(id);
    await loadUsers();
  }
} 