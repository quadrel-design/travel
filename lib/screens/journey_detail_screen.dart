import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import 'package:intl/intl.dart';
import 'journey_settings_screen.dart';

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
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add New Expense'),
        message: const Text('Enter the expense details'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showExpenseForm();
            },
            child: const Text('Add Expense'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showExpenseForm() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('New Expense'),
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
              CupertinoTextField(
                controller: _amountController,
                placeholder: 'Amount',
                keyboardType: TextInputType.number,
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
                          initialDateTime: _selectedDate,
                          mode: CupertinoDatePickerMode.date,
                          use24hFormat: true,
                          onDateTimeChanged: (DateTime newDate) {
                            setState(() => _selectedDate = newDate);
                          },
                        ),
                      ),
                    ),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: Text(
                  'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => CupertinoActionSheet(
                      title: const Text('Select Category'),
                      actions: [
                        'Transport',
                        'Accommodation',
                        'Food',
                        'Activities',
                        'Shopping',
                        'Other',
                      ].map((category) => CupertinoActionSheetAction(
                        onPressed: () {
                          setState(() => _selectedCategory = category);
                          Navigator.pop(context);
                        },
                        child: Text(category),
                      )).toList(),
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  );
                },
                child: Text('Category: $_selectedCategory'),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
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
      ),
    );
  }

  void _showEditExpenseForm(Expense expense) {
    _titleController.text = expense.title;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _selectedCategory = expense.category;
    _selectedDate = expense.date;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Edit Expense'),
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
              CupertinoTextField(
                controller: _amountController,
                placeholder: 'Amount',
                keyboardType: TextInputType.number,
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
                          initialDateTime: _selectedDate,
                          mode: CupertinoDatePickerMode.date,
                          use24hFormat: true,
                          onDateTimeChanged: (DateTime newDate) {
                            setState(() => _selectedDate = newDate);
                          },
                        ),
                      ),
                    ),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: Text(
                  'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => CupertinoActionSheet(
                      title: const Text('Select Category'),
                      actions: [
                        'Transport',
                        'Accommodation',
                        'Food',
                        'Activities',
                        'Shopping',
                        'Other',
                      ].map((category) => CupertinoActionSheetAction(
                        onPressed: () {
                          setState(() => _selectedCategory = category);
                          Navigator.pop(context);
                        },
                        child: Text(category),
                      )).toList(),
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  );
                },
                child: Text('Category: $_selectedCategory'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      context.read<ExpenseProvider>().deleteExpense(
                            expense.id,
                            expense.journeyId,
                          );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                  ),
                  CupertinoButton.filled(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.journey.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => JourneySettingsScreen(
                      journey: widget.journey,
                    ),
                  ),
                );
              },
              child: const Icon(CupertinoIcons.settings),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showAddExpenseModal,
              child: const Icon(CupertinoIcons.add),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Consumer<ExpenseProvider>(
          builder: (context, expenseProvider, child) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.systemGrey4,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${expenseProvider.totalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: expenseProvider.expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenseProvider.expenses[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemGrey4,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CupertinoListTile(
                          title: Text(expense.title),
                          subtitle: Text(
                            '${DateFormat('MMM d, yyyy').format(expense.date)} - ${expense.category}',
                          ),
                          trailing: Text(
                            '\$${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            _showEditExpenseForm(expense);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 