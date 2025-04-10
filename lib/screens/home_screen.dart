import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../providers/journey_provider.dart';
import 'journey_detail_screen.dart';
import 'user_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const JourneyListContent(),
    const UserSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class JourneyListContent extends StatefulWidget {
  const JourneyListContent({Key? key}) : super(key: key);

  @override
  State<JourneyListContent> createState() => _JourneyListContentState();
}

class _JourneyListContentState extends State<JourneyListContent> {
  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    await context.read<JourneyProvider>().loadJourneys();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journeys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showJourneyForm(context);
            },
          ),
        ],
      ),
      body: Consumer<JourneyProvider>(
        builder: (context, journeyProvider, child) {
          final journeys = journeyProvider.journeys;
          if (journeys.isEmpty) {
            return const Center(
              child: Text('No journeys yet. Tap the + button to create one!'),
            );
          }
          return ListView.builder(
            itemCount: journeys.length,
            itemBuilder: (context, index) {
              final journey = journeys[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(journey.title),
                  subtitle: Text(
                    '${_formatDate(journey.startDate)} - ${_formatDate(journey.endDate)}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JourneyDetailScreen(journey: journey),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showJourneyForm(BuildContext context) {
    final _titleController = TextEditingController();
    final _descriptionController = TextEditingController();
    DateTime _startDate = DateTime.now();
    DateTime _endDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Journey'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(_formatDate(_startDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('End Date'),
                subtitle: Text(_formatDate(_endDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_titleController.text.isNotEmpty) {
                  final journey = Journey(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: _titleController.text,
                    description: _descriptionController.text,
                    startDate: _startDate,
                    endDate: _endDate,
                    users: [],
                  );
                  await context.read<JourneyProvider>().createJourney(journey);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 