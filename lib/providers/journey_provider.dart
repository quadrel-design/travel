import 'package:flutter/foundation.dart';
import '../models/journey.dart';
import '../services/database_helper.dart';

class JourneyProvider with ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<Journey> _journeys = [];

  List<Journey> get journeys => _journeys;

  Future<void> loadJourneys() async {
    _journeys = await _databaseHelper.readAllJourneys();
    notifyListeners();
  }

  Future<void> addJourney(Journey journey) async {
    // Create the journey in the database
    await _databaseHelper.createJourney(journey);
    
    // Reload all journeys to get the updated list
    await loadJourneys();
  }

  Future<void> updateJourney(Journey journey) async {
    await _databaseHelper.updateJourney(journey);
    final index = _journeys.indexWhere((j) => j.id == journey.id);
    if (index != -1) {
      _journeys[index] = journey;
      notifyListeners();
    }
  }

  Future<void> deleteJourney(String id) async {
    await _databaseHelper.deleteJourney(id);
    _journeys.removeWhere((journey) => journey.id == id);
    notifyListeners();
  }
} 