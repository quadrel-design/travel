import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'providers/journey_provider.dart';
import 'models/journey.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => JourneyProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF24292E), // GitHub's dark gray
          surface: Colors.white,
          background: Colors.white,
          onPrimary: Colors.white,
          onSurface: const Color(0xFF24292E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF24292E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF24292E),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF24292E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JourneyProvider>().loadJourneys();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Expense Tracker'),
      ),
      body: Consumer<JourneyProvider>(
        builder: (context, journeyProvider, child) {
          if (journeyProvider.journeys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No journeys yet',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF586069),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddJourneyDialog(context),
                    child: const Text('Add Your First Journey'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: journeyProvider.journeys.length,
            itemBuilder: (context, index) {
              final journey = journeyProvider.journeys[index];
              return JourneyCard(
                journey: journey,
                onEdit: () => _showEditJourneyDialog(context, journey),
                onDelete: () => _showDeleteConfirmation(context, journey.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddJourneyDialog(context),
        backgroundColor: const Color(0xFF24292E),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddJourneyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const JourneyDialog(),
    );
  }

  void _showEditJourneyDialog(BuildContext context, Journey journey) {
    showDialog(
      context: context,
      builder: (context) => JourneyDialog(journey: journey),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String journeyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Journey'),
        content: const Text('Are you sure you want to delete this journey?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<JourneyProvider>().deleteJourney(journeyId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class JourneyCard extends StatelessWidget {
  final Journey journey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const JourneyCard({
    super.key,
    required this.journey,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE1E4E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    journey.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              journey.description,
              style: const TextStyle(color: Color(0xFF586069)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${journey.startDate.day}/${journey.startDate.month}/${journey.startDate.year} - ${journey.endDate.day}/${journey.endDate.month}/${journey.endDate.year}',
                  style: const TextStyle(color: Color(0xFF586069)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Budget: \$${journey.budget.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF586069)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyDialog extends StatefulWidget {
  final Journey? journey;

  const JourneyDialog({super.key, this.journey});

  @override
  State<JourneyDialog> createState() => _JourneyDialogState();
}

class _JourneyDialogState extends State<JourneyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.journey?.title ?? '');
    _descriptionController = TextEditingController(text: widget.journey?.description ?? '');
    _budgetController = TextEditingController(text: widget.journey?.budget.toString() ?? '');
    if (widget.journey != null) {
      _startDate = widget.journey!.startDate;
      _endDate = widget.journey!.endDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.journey == null ? 'Add Journey' : 'Edit Journey'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: 'Budget'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a budget';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final journey = Journey(
                id: widget.journey?.id ?? const Uuid().v4(),
                title: _titleController.text,
                description: _descriptionController.text,
                startDate: _startDate,
                endDate: _endDate,
                budget: double.parse(_budgetController.text),
              );

              if (widget.journey == null) {
                context.read<JourneyProvider>().addJourney(journey);
              } else {
                context.read<JourneyProvider>().updateJourney(journey);
              }

              Navigator.pop(context);
            }
          },
          child: Text(widget.journey == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
} 