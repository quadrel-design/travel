import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import 'package:intl/intl.dart';
import 'journey_settings_screen.dart';
import '../models/user.dart';
import '../providers/journey_provider.dart';
import '../providers/user_provider.dart';

class JourneyDetailScreen extends StatefulWidget {
  final Journey journey;

  const JourneyDetailScreen({Key? key, required this.journey}) : super(key: key);

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Transport';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadExpensesForJourney(widget.journey.id!);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add New Expense'),
            onTap: () {
              Navigator.pop(context);
              _showExpenseForm();
            },
          ),
        ],
      ),
    );
  }

  void _showExpenseForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('New Expense'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Category'),
                    subtitle: Text(_selectedCategory),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Select Category'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              'Transport',
                              'Accommodation',
                              'Food',
                              'Activities',
                              'Shopping',
                              'Other',
                            ].map((category) => ListTile(
                              title: Text(category),
                              onTap: () {
                                setState(() => _selectedCategory = category);
                                Navigator.pop(context);
                              },
                            )).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (_titleController.text.isNotEmpty &&
                          _amountController.text.isNotEmpty) {
                        final expense = Expense(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          journeyId: widget.journey.id!,
                          title: _titleController.text,
                          description: _descriptionController.text,
                          amount: double.parse(_amountController.text),
                          date: _selectedDate,
                          category: _selectedCategory,
                        );

                        context.read<ExpenseProvider>().addExpense(expense);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Add Expense'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseForm(Expense expense) {
    _titleController.text = expense.title;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _selectedCategory = expense.category;
    _selectedDate = expense.date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Edit Expense'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Category'),
                    subtitle: Text(_selectedCategory),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Select Category'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              'Transport',
                              'Accommodation',
                              'Food',
                              'Activities',
                              'Shopping',
                              'Other',
                            ].map((category) => ListTile(
                              title: Text(category),
                              onTap: () {
                                setState(() => _selectedCategory = category);
                                Navigator.pop(context);
                              },
                            )).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          context.read<ExpenseProvider>().deleteExpense(
                                expense.id,
                                expense.journeyId,
                              );
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_titleController.text.isNotEmpty &&
                              _amountController.text.isNotEmpty) {
                            final updatedExpense = Expense(
                              id: expense.id,
                              journeyId: expense.journeyId,
                              title: _titleController.text,
                              description: _descriptionController.text,
                              amount: double.parse(_amountController.text),
                              date: _selectedDate,
                              category: _selectedCategory,
                            );

                            context.read<ExpenseProvider>().updateExpense(updatedExpense);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.journey.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JourneySettingsScreen(journey: widget.journey),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Journey details section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journey Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Title', widget.journey.title),
                  _buildDetailRow(
                    'Duration',
                    '${_formatDate(widget.journey.startDate)} - ${_formatDate(widget.journey.endDate)}',
                  ),
                  _buildDetailRow(
                    'Description',
                    widget.journey.description.isEmpty ? 'No description' : widget.journey.description,
                  ),
                  _buildDetailRow(
                    'Participants',
                    widget.journey.users.isEmpty
                        ? 'No participants yet'
                        : '${widget.journey.users.length} participants',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 