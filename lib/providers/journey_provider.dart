import 'package:flutter/foundation.dart';
import '../models/journey.dart';
import '../services/database_helper.dart';

class JourneyProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Journey> _journeys = [];
  Journey? _selectedJourney;

  List<Journey> get journeys => _journeys;
  Journey? get selectedJourney => _selectedJourney;

  Future<void> loadJourneys() async {
    _journeys = await _dbHelper.readAllJourneys();
    notifyListeners();
  }

  Future<void> createJourney(Journey journey) async {
    await _dbHelper.createJourney(journey);
    await loadJourneys();
  }

  Future<void> updateJourney(Journey journey) async {
    await _dbHelper.updateJourney(journey);
    await loadJourneys();
  }

  Future<void> deleteJourney(String? id) async {
    if (id != null) {
      await _dbHelper.deleteJourney(id);
      await loadJourneys();
    }
  }

  void selectJourney(Journey journey) {
    _selectedJourney = journey;
    notifyListeners();
  }
} 