import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../providers/journey_provider.dart';
import 'journey_detail_screen.dart';
import 'package:intl/intl.dart';

class JourneyListScreen extends StatefulWidget {
  const JourneyListScreen({super.key});

  @override
  State<JourneyListScreen> createState() => _JourneyListScreenState();
}

class _JourneyListScreenState extends State<JourneyListScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JourneyProvider>().loadJourneys();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showJourneyForm() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('New Journey'),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CupertinoTextField(
                controller: _titleController,
                placeholder: 'Title',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: 'Description',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: () async {
                  final date = await showCupertinoModalPopup<DateTime>(
                    context: context,
                    builder: (context) => Container(
                      height: 216,
                      padding: const EdgeInsets.only(top: 6.0),
                      margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      color: CupertinoColors.systemBackground.resolveFrom(context),
                      child: SafeArea(
                        top: false,
                        child: CupertinoDatePicker(
                          initialDateTime: _startDate,
                          mode: CupertinoDatePickerMode.date,
                          use24hFormat: true,
                          onDateTimeChanged: (DateTime newDate) {
                            setState(() => _startDate = newDate);
                          },
                        ),
                      ),
                    ),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
                child: Text(
                  'Start Date: ${DateFormat('MMM d, yyyy').format(_startDate)}',
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: () async {
                  final date = await showCupertinoModalPopup<DateTime>(
                    context: context,
                    builder: (context) => Container(
                      height: 216,
                      padding: const EdgeInsets.only(top: 6.0),
                      margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      color: CupertinoColors.systemBackground.resolveFrom(context),
                      child: SafeArea(
                        top: false,
                        child: CupertinoDatePicker(
                          initialDateTime: _endDate,
                          mode: CupertinoDatePickerMode.date,
                          use24hFormat: true,
                          onDateTimeChanged: (DateTime newDate) {
                            setState(() => _endDate = newDate);
                          },
                        ),
                      ),
                    ),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
                child: Text(
                  'End Date: ${DateFormat('MMM d, yyyy').format(_endDate)}',
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () {
                  if (_titleController.text.isNotEmpty) {
                    final journey = Journey(
                      id: DateTime.now().toString(),
                      title: _titleController.text,
                      description: _descriptionController.text,
                      startDate: _startDate,
                      endDate: _endDate,
                      users: [],
                    );

                    context.read<JourneyProvider>().addJourney(journey);
                    Navigator.pop(context);

                    // Clear the form
                    _titleController.clear();
                    _descriptionController.clear();
                    setState(() {
                      _startDate = DateTime.now();
                      _endDate = DateTime.now().add(const Duration(days: 7));
                    });
                  }
                },
                child: const Text('Add Journey'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('My Journeys'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showJourneyForm,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Consumer<JourneyProvider>(
          builder: (context, journeyProvider, child) {
            if (journeyProvider.journeys.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.airplane,
                      size: 64,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No journeys yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoButton(
                      onPressed: _showJourneyForm,
                      child: const Text('Create your first journey'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: journeyProvider.journeys.length,
              itemBuilder: (context, index) {
                final journey = journeyProvider.journeys[index];
                return CupertinoListTile(
                  title: Text(journey.title),
                  subtitle: Text(
                    '${DateFormat('MMM d').format(journey.startDate)} - ${DateFormat('MMM d, yyyy').format(journey.endDate)}',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => JourneyDetailScreen(journey: journey),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
} 