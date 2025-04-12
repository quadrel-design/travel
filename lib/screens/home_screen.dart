import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/journey.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _error;
  List<Journey> _journeys = [];
  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client
          .from('journeys')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      final journeys = response
          .map((data) => Journey.fromJson(data))
          .toList();

      if (mounted) {
        setState(() {
          _journeys = journeys;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load journeys: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _goToCreateJourney() {
    Navigator.of(context).pushNamed('/create-journey').then((_) {
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
        itemCount: _journeys.length,
        itemBuilder: (context, index) {
          final journey = _journeys[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(journey.title),
              subtitle: Text(journey.description),
              trailing: Text(_dateFormat.format(journey.startDate)),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/journey-detail',
                  arguments: journey,
                ).then((result) {
                  if (result == true) {
                    _loadJourneys();
                  }
                });
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journeys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJourneys,
            tooltip: 'Refresh Journeys',
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
