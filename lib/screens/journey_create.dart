import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for formatter
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// import 'package:shadcn_ui/shadcn_ui.dart'; // Remove import
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Add import

import '../models/journey.dart'; // Import Journey model
import '../widgets/app_title.dart'; // Import AppTitle
// import '../repositories/journey_repository.dart'; // Unused import
// import '../repositories/auth_repository.dart'; // Unused import
import '../widgets/form_field_group.dart'; // Import the new widget

class CreateJourneyScreen extends ConsumerStatefulWidget {
  const CreateJourneyScreen({super.key});

  @override
  ConsumerState<CreateJourneyScreen> createState() => _CreateJourneyScreenState();
}

class _CreateJourneyScreenState extends ConsumerState<CreateJourneyScreen> {
  // Add a ScaffoldMessenger Key
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>(); 

  final _formKey = GlobalKey<FormState>(); // Use FormState key
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  // Add controllers for date display
  final _startDateDisplayController = TextEditingController();
  final _endDateDisplayController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy'); 

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    // Use the key to remove the SnackBar
    _scaffoldMessengerKey.currentState?.removeCurrentSnackBar(); 
    
    // dispose all controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _startDateDisplayController.dispose();
    _endDateDisplayController.dispose();
    super.dispose();
  }

  // Helper to show SnackBar
  void _showErrorSnackBar(BuildContext context, String title, String message) {
     // print('[DEBUG] CreateJourneyScreen _showErrorSnackBar: Title="$title", Message="$message"'); // Remove log
     // Use the key to hide/show
     _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
     _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(message)]), backgroundColor: Theme.of(context).colorScheme.error));
   }
   void _showSuccessSnackBar(BuildContext context, String title, String message) {
     // Use the key to hide/show
     _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
     _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(message)]), backgroundColor: Theme.of(context).colorScheme.primary));
   }

  Future<void> _pickDate(bool isStartDate) async {
    final now = DateTime.now();
    final initial = isStartDate ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    final first = isStartDate ? DateTime(now.year - 5) : (_startDate ?? DateTime(now.year - 5));
    final last = DateTime(now.year + 5);
    
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first, 
      lastDate: last,
    );

    if (date != null) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
          _startDateDisplayController.text = _dateFormat.format(date);
          // Reset end date if it's before new start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
            _endDateDisplayController.clear();
          }
        } else {
          _endDate = date;
          _endDateDisplayController.text = _dateFormat.format(date);
        }
      });
    }
  }

  Future<void> _saveJourney() async {
    final l10n = AppLocalizations.of(context)!;
    final journeyRepository = ref.read(journeyRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return; // Validators handle messages
    
    if (_startDate == null || _endDate == null) {
       _showErrorSnackBar(context, l10n.missingInfoTitle, l10n.journeySaveMissingInfoDesc);
      return;
    }

    setState(() { _isLoading = true; });

    final userId = authRepository.currentUser?.id;
    if (userId == null) {
      _showErrorSnackBar(context, l10n.errorTitle, l10n.createJourneyErrorUserNotLoggedIn);
      setState(() { _isLoading = false; });
      return;
    }

    final budgetValue = double.tryParse(_budgetController.text.trim()) ?? 0.0;
    final newJourney = Journey(
      id: Uuid().v4(),
      userId: userId,
      title: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      budget: budgetValue,
      isCompleted: false,
    );

    try {
      await journeyRepository.addJourney(newJourney);
      if (mounted) {
         _showSuccessSnackBar(context, l10n.journeySaveSuccessTitle, l10n.journeySaveSuccessDesc);
         context.pop(); 
      }
    } catch (error) {
       if (mounted) {
           // Use parameterized localization
           _showErrorSnackBar(context, l10n.journeySaveErrorTitle, l10n.journeyDeleteErrorDesc(error));
       }
    } finally {
       if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
     final l10n = AppLocalizations.of(context)!;
     final theme = Theme.of(context); // Get Material theme

    return Scaffold(
      key: _scaffoldMessengerKey, // Assign the key here
      appBar: AppBar(
        title: const AppTitle(),
        actions: [
          // Replace with TextButton
          TextButton(
            onPressed: _isLoading ? null : _saveJourney,
            child: const Text( 'Save'), // Add const - TODO: Localize
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0), // Already const
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons later?
            children: [
              Text(l10n.createJourneyTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 24),

              // --- Travel Name Field --- 
              FormFieldGroup(
                label: 'Travel Name', // TODO: Localize
                description: 'Enter a descriptive name for your trip.', // TODO: Localize
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'e.g., Summer Vacation in Italy'), // Add const back
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a journey name.' : null,
                ),
              ),
              const SizedBox(height: 16),

              // --- Date Fields (Row for layout) --- 
              Row(
                 crossAxisAlignment: CrossAxisAlignment.start, // Align tops
                 children: [
                   Expanded(
                     child: FormFieldGroup(
                        label: 'From', // TODO: Localize
                        child: TextFormField(
                          controller: _startDateDisplayController,
                          decoration: const InputDecoration(hintText: 'Select start date'), // Add const
                          readOnly: true,
                          onTap: () => _pickDate(true),
                          validator: (v) => _startDate == null ? 'Please select a start date.' : null,
                        ),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                      child: FormFieldGroup(
                        label: 'Till', // TODO: Localize
                        child: TextFormField(
                          controller: _endDateDisplayController,
                          decoration: const InputDecoration(hintText: 'Select end date'), // Add const
                          readOnly: true,
                          onTap: () => _pickDate(false),
                          validator: (v) {
                             if (_endDate == null) return 'Please select an end date.';
                             if (_startDate != null && _endDate!.isBefore(_startDate!)) {
                                return 'End date must be after start date.';
                             }
                             return null;
                          },
                        ),
                     ),
                   ),
                 ],
              ),
              const SizedBox(height: 16),
              
              // --- Description Field ---
              FormFieldGroup(
                label: 'Description', // TODO: Localize
                description: 'Add some details about your travel plans.', // TODO: Localize
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(hintText: 'Describe your journey...'), // Add const
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 16),

              // --- Location Field ---
              FormFieldGroup(
                label: 'Location', // TODO: Localize
                description: 'Where is this journey taking place?', // TODO: Localize
                child: TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(hintText: 'e.g., Rome, Italy'), // Add const
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a location.' : null,
                ),
              ),
              const SizedBox(height: 16),
              
              // --- Budget Field ---
              FormFieldGroup(
                label: 'Budget (\$)', // TODO: Localize
                description: 'Estimated budget for the trip.', // TODO: Localize
                child: TextFormField(
                  controller: _budgetController,
                  decoration: const InputDecoration(hintText: 'e.g., 2000'), // Add const back
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), // Already const
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  validator: (v) {
                     if (v == null || v.trim().isEmpty) {
                        return 'Please enter a budget.';
                     }
                     if (double.tryParse(v.trim()) == null) {
                        return 'Please enter a valid number.';
                     }
                     if (double.parse(v.trim()) <= 0) {
                        return 'Budget must be positive.';
                     }
                     return null;
                  },
                ),
              ),

              // --- Loading Indicator --- 
              if (_isLoading)
                 const Padding(
                   padding: EdgeInsets.only(top: 20.0),
                   child: Center(child: CircularProgressIndicator()),
                 ),
            ],
          ),
        ),
      ),
    );
  }
}
