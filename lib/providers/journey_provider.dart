import 'package:flutter/foundation.dart';
import '../models/journey.dart';
import '../services/database_helper.dart';

class JourneyProvider with ChangeNotifier {
  List<Journey> _journeys = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Journey> get journeys => _journeys;

  Future<void> loadJourneys() async {
    _journeys = await _dbHelper.readAllJourneys();
    notifyListeners();
  }

  Future<void> addJourney(Journey journey) async {
    await _dbHelper.create(journey);
    _journeys = await _dbHelper.readAllJourneys();
    notifyListeners();
  }

  Future<void> updateJourney(Journey updatedJourney) async {
    await _dbHelper.update(updatedJourney);
    _journeys = await _dbHelper.readAllJourneys();
    notifyListeners();
  }

  Future<void> deleteJourney(String id) async {
    await _dbHelper.delete(id);
    _journeys = await _dbHelper.readAllJourneys();
    notifyListeners();
  }
} 