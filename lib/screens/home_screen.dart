import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/journey.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/app_title.dart';
import '../repositories/journey_repository.dart';
import '../repositories/auth_repository.dart';

class HomeScreen extends StatefulWidget {
  final String title;
  
  const HomeScreen({Key? key, required this.title}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _error;
  List<Journey> _journeys = [];
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final JourneyRepository _journeyRepository = JourneyRepository();
  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _authRepository.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      final loadedJourneys = await _journeyRepository.fetchUserJourneys(userId);

      if (mounted) {
        setState(() {
          _journeys = loadedJourneys;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading journeys: $e");
      if (mounted) {
        setState(() {
          _error = 'Failed to load journeys';
          _isLoading = false;
        });
      }
    }
  }

  void _goToCreateJourney() {
    context.push('/create-journey').then((_) {
      _loadJourneys();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _loadJourneys, child: const Text('Retry'))
          ],
        ),
      );
    } else if (_journeys.isEmpty) {
      bodyContent = const Center(child: Text('No journeys yet! Start by adding one.'));
    } else {
      bodyContent = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _journeys.length,
        itemBuilder: (context, index) {
          final journey = _journeys[index];
          return GestureDetector(
            onTap: () {
              context.push('/journey-detail', extra: journey);
              print('Navigating to detail for: ${journey.title}');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ShadCard(
                title: Text(journey.title, style: ShadTheme.of(context).textTheme.h4),
                description: Text(journey.description),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'From: ${_dateFormat.format(journey.start_date)}\n'
                    'To:     ${_dateFormat.format(journey.end_date)}',
                    style: ShadTheme.of(context).textTheme.muted,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppTitle(),
        actions: [
          ShadButton.ghost(
            icon: const Icon(LucideIcons.circleUserRound, size: 20),
            onPressed: () {
              context.push('/app-settings');
            },
          ),
        ],
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
         onPressed: _goToCreateJourney,
         tooltip: 'Add Journey',
         child: const Icon(Icons.add), 
       ),
    );
  }
}
