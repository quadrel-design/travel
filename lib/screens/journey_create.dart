import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for formatter
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Add import

import '../models/journey.dart'; // Import Journey model
import '../widgets/app_title.dart'; // Import AppTitle

class CreateJourneyScreen extends ConsumerStatefulWidget {
  const CreateJourneyScreen({super.key});

  @override
  ConsumerState<CreateJourneyScreen> createState() => _CreateJourneyScreenState();
}

class _CreateJourneyScreenState extends ConsumerState<CreateJourneyScreen> {
  final _formKey = GlobalKey<ShadFormState>(); // Use ShadFormState key
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveJourney() async {
    final l10n = AppLocalizations.of(context)!;
    // Read repositories using ref
    final journeyRepository = ref.read(journeyRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    
    // Validate form
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _startDate == null || _endDate == null) {
       ShadToaster.of(context).show(
         ShadToast.destructive(
           title: const Text('Missing Information'),
           description: const Text('Please fill in all fields, including dates.'),
         ),
       );
      return;
    }

    setState(() { _isLoading = true; });

    // Get user ID from repository
    final userId = authRepository.currentUser?.id;
    if (userId == null) {
      ShadToaster.of(context).show(
         ShadToast.destructive(
           title: const Text('Error'),
           description: const Text('User not logged in.'),
         ),
       );
       setState(() { _isLoading = false; });
       return;
    }

    // Safely parse budget
    final budgetValue = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    final newJourney = Journey(
      id: const Uuid().v4(),
      user_id: userId,
      title: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      start_date: _startDate!,
      end_date: _endDate!,
      budget: budgetValue,
      image_urls: [],
      is_completed: false,
    );

    try {
      // Use repository method
      await journeyRepository.addJourney(newJourney);
      if (mounted) {
         ShadToaster.of(context).show(
           const ShadToast(
             title: Text('Journey Saved'),
             description: Text('Your new journey has been created.'),
           ),
         );
         // Navigate back after saving
         context.pop(); 
      }
    } catch (error) {
       print('Error saving journey: $error');
        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text('Save Error'),
              description: Text('Could not save journey: $error'),
            ),
          );
       }
    } finally {
       if (mounted) { setState(() { _isLoading = false; }); }
    }

  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Get l10n
    return Scaffold(
      appBar: AppBar(
        // Use the reusable AppTitle widget
        title: const AppTitle(),
        actions: [
          ShadButton.ghost(
            child: const Text('Save'), 
            onPressed: _isLoading ? null : _saveJourney,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ShadForm(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.createJourneyTitle, // Use l10n
                style: ShadTheme.of(context).textTheme.h2,
              ),
              const SizedBox(height: 24),

              // Journey Name Field
              ShadInputFormField(
                id: 'journey_name',
                controller: _nameController,
                label: const Text('Travel Name'),
                placeholder: const Text('e.g., Summer Vacation in Italy'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a journey name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Replace date fields with ShadDatePickerFormFields
              ShadDatePickerFormField(
                id: 'start_date',
                label: const Text('From'),
                onChanged: (v) {
                  print('Start Date selected: $v');
                  setState(() {
                    _startDate = v;
                    // Optional: Validate end date is after start date here
                    if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                      _endDate = null; // Reset end date if invalid
                    }
                  });
                },
                validator: (v) {
                  if (v == null) return 'Please select a start date.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ShadDatePickerFormField(
                id: 'end_date',
                label: const Text('Till'),
                onChanged: (v) {
                   print('End Date selected: $v');
                   setState(() => _endDate = v);
                },
                validator: (v) {
                   if (v == null) return 'Please select an end date.';
                   if (_startDate != null && v.isBefore(_startDate!)) {
                     return 'End date must be after start date.';
                   }
                   return null;
                },
              ),
              
              // Add other fields like description, budget etc. here later
              ShadInputFormField(
                id: 'description',
                controller: _descriptionController,
                label: const Text('Description'),
                placeholder: const Text('Describe your journey...'),
                maxLines: 3, // Allow multiple lines for description
                validator: (v) {
                  // Optional: Make description optional if needed
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a description.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ShadInputFormField(
                id: 'location',
                controller: _locationController,
                label: const Text('Location'),
                placeholder: const Text('e.g., Rome, Italy'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a location.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ShadInputFormField(
                id: 'budget',
                controller: _budgetController,
                label: const Text('Budget (\$)'),
                placeholder: const Text('e.g., 2000'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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
              
              // Show loading indicator during save
              if (_isLoading)
                 const Padding(
                   padding: EdgeInsets.only(top: 20.0),
                   child: Center(child: CircularProgressIndicator()),
                 )
            ],
          ),
        ),
      ),
    );
  }
}
