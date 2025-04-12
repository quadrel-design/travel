import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/journey.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        itemCount: _journeys.length,
        itemBuilder: (context, index) {
          final journey = _journeys[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(journey.title),
              subtitle: Text(journey.description),
              trailing: Text(_dateFormat.format(journey.start_date)),
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
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJourneys,
            tooltip: 'Refresh Journeys',
          ),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 0,
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
             border: Border(
                top: BorderSide(
                  color: Colors.grey.shade400,
                  width: 1.0,
              ),
             )
          ),
          child: Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ShadButton.ghost(
                  icon: const Icon(LucideIcons.layoutDashboard, size: 20),
                  onPressed: () {
                    context.go('/home');
                    print('Home button tapped');
                  },
                ),
                ShadButton(
                  icon: const Icon(LucideIcons.plus, size: 20),
                  onPressed: _goToCreateJourney,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
