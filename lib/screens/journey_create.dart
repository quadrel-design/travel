/**
 * Journey Creation Screen
 *
 * Provides a form using flutter_form_builder for users to input details
 * (title, dates, description, location, budget) and create a new journey/invoice.
 * Uses [journeyFormProvider] for state management and handling the save operation.
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for formatter
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:intl/intl.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:travel/providers/logging_provider.dart'; // Import logger provider

// Ensure Journey model is imported
import '../models/journey.dart'; // Import Journey model
// Import AppTitle
// Import the new widget
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
// import 'package:travel/utils/validators.dart'; // Remove this non-existent import

// Import Supabase client
// import 'package:supabase_flutter/supabase_flutter.dart';
// Import the footer bar

// Remove imports for non-existent files
// import '../providers/auth_provider.dart';
// import '../providers/journey_provider.dart';

// Add imports used by the logic (might have been missed)
// import '../providers/repository_providers.dart';
// import 'package:travel/utils/validators.dart'; // Remove this non-existent import
import 'package:travel/constants/app_routes.dart';
import 'package:travel/providers/location_service_provider.dart'; // Fix import path - Uncommented
import 'package:travel/providers/journey_form_provider.dart';
// import 'package:travel/providers/auth_repository_provider.dart';

/// A screen widget for creating new journeys/invoices.
class CreateJourneyScreen extends ConsumerStatefulWidget {
  const CreateJourneyScreen({super.key});

  @override
  ConsumerState<CreateJourneyScreen> createState() =>
      _CreateJourneyScreenState();
}

/// State class for the [CreateJourneyScreen].
class _CreateJourneyScreenState extends ConsumerState<CreateJourneyScreen> {
  static const Duration _kAutocompleteDebounceDuration =
      Duration(milliseconds: 300);

  // Constants for form field names
  /// Form field name for the journey title.
  static const _fieldName = 'name';

  /// Form field name for the journey description.
  static const _fieldDescription = 'description';

  /// Form field name for the journey location.
  static const _fieldLocation = 'location';

  /// Form field name for the journey budget.
  static const _fieldBudget = 'budget';

  // ScaffoldMessenger Key
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Form Key
  /// Global key for the [FormBuilder] instance.
  final _formKey = GlobalKey<FormBuilderState>();

  // Date Controllers & Format
  /// Controller for displaying the selected start date.
  final _startDateDisplayController = TextEditingController();

  /// Controller for displaying the selected end date.
  final _endDateDisplayController = TextEditingController();

  /// Date format used for display controllers.
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // State variables
  /// The selected start date.
  DateTime? _startDate;

  /// The selected end date.
  DateTime? _endDate;
  // Removed local _isLoading state - now managed by journeyFormProvider

  @override
  void dispose() {
    // Use the key to remove the SnackBar
    _scaffoldMessengerKey.currentState?.removeCurrentSnackBar();

    // dispose all controllers
    _startDateDisplayController.dispose();
    _endDateDisplayController.dispose();
    super.dispose();
  }

  // Helper function to show error SnackBar
  /// Displays a floating SnackBar with an error message.
  void _showErrorSnackBar(BuildContext context, String title, String message) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final snackBar = SnackBar(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(message),
        ],
      ),
      backgroundColor: theme.colorScheme.error,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? (screenWidth - 600) / 2 : 16.0,
        vertical: 16.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Commented out for now - will be used when success messaging is needed
  /*
   void _showSuccessSnackBar(BuildContext context, String title, String message) {
     if (!mounted) return; // Check if mounted
     // Use the key to hide/show
     _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
     _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(message)]), backgroundColor: Theme.of(context).colorScheme.primary));
   }
   */

  /// Shows a date picker dialog and updates the corresponding state variable
  /// and display controller.
  ///
  /// Ensures the end date cannot be before the start date.
  Future<void> _pickDate(bool isStartDate) async {
    final now = DateTime.now();
    final initial =
        isStartDate ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    // Ensure first date is not before the start date when picking end date
    final first = isStartDate
        ? DateTime(now.year - 5)
        : (_startDate ?? DateTime(now.year - 5));
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
            // Trigger validation for end date field if needed
            _formKey.currentState?.fields['endDateDisplay']?.validate();
          }
          // Trigger validation for start date field
          _formKey.currentState?.fields['startDateDisplay']?.validate();
        } else {
          _endDate = date;
          _endDateDisplayController.text = _dateFormat.format(date);
          // Trigger validation for end date field
          _formKey.currentState?.fields['endDateDisplay']?.validate();
        }
      });
    }
  }

  // Commented out for now - will be connected to UI when implementation is finalized

  /// Validates the form, creates a [Journey] object, and triggers the creation
  /// process via the [journeyFormProvider].
  Future<void> _saveJourney() async {
    final formState = _formKey.currentState!;
    if (formState.saveAndValidate()) {
      final formData = formState.value;
      // Localization can be fetched here if needed for validation messages, though not currently used.
      // final l10n = AppLocalizations.of(context)!;

      // Extract values (Get dates from state variables, not formData)
      final String title = formData['name']?.toString().trim() ?? '';
      final DateTime? startDate = _startDate; // Use state variable
      final DateTime? endDate = _endDate; // Use state variable
      final String description =
          formData['description']?.toString().trim() ?? '';
      // Get location value (might be null if field is commented out)
      final String? location = formData[_fieldLocation]?.toString().trim();
      final double? budget = formData['budget'] as double?;

      // Basic validation (redundant if form validators are robust, but safe)
      if (title.isEmpty || startDate == null || endDate == null) {
        if (mounted) {
          _showErrorSnackBar(context, "Missing Information",
              "Please fill in title and select both dates.");
        }
        return;
      }
      if (endDate.isBefore(startDate)) {
        if (mounted) {
          _showErrorSnackBar(context, "Invalid Dates",
              "End date cannot be before start date.");
        }
        return;
      }

      // Get user ID *again* right before use and perform null check
      final String? currentUserId =
          ref.read(authRepositoryProvider).currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) {
          _showErrorSnackBar(
              context, "Error", "User session lost. Cannot save journey.");
        }
        return; // Cannot proceed without user ID
      }

      // Create the Journey object
      final newJourney = Journey(
        id: const Uuid().v4(), // Generate new ID
        userId: currentUserId, // Now guaranteed non-null
        title: title,
        startDate: startDate,
        endDate: endDate,
        description: description,
        location: location ?? '', // Use extracted location or default
        budget: budget ?? 0.0,
        isCompleted: false,
      );

      // Call the notifier to create the journey
      // The listen callback will handle success/error feedback and navigation
      await ref.read(journeyFormProvider.notifier).createJourney(newJourney);
    }
  }

  /// Fetches location suggestions based on user input.
  /// Used by the (currently commented out) location typeahead field.
  Future<List<String>> _searchLocations(String pattern) async {
    if (!mounted) return []; // Check mounted state
    if (pattern.isEmpty) {
      return [];
    }

    // Debounce mechanism (optional but recommended)
    await Future.delayed(_kAutocompleteDebounceDuration);
    if (!mounted) return []; // Check again after delay

    try {
      final locationService = ref.read(locationServiceProvider);
      final suggestions = await locationService.searchLocations(pattern);

      if (!mounted) return []; // Check again after await
      return suggestions;
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          context,
          'Search Error',
          'Failed to fetch location suggestions: $e',
        );
      }
      return [];
    }
  }

  /// Builds the UI for the Create Journey screen.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Watch the form state provider
    final formState = ref.watch(journeyFormProvider);
    final isLoading = formState.isLoading; // Get loading state from provider

    // Listen to the form provider for side effects (navigation, snackbars)
    ref.listen<JourneyFormState>(journeyFormProvider, (previous, next) {
      // Handle errors shown via SnackBar
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(context, l10n.journeySaveErrorTitle, next.error!);
        // Optionally reset the error in the provider after showing it
        // This prevents the snackbar from reappearing on rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Check mounted before interacting with ref post-frame
            ref.read(journeyFormProvider.notifier).state =
                next.copyWith(clearError: true);
          }
        });
      }
      // Handle navigation on success
      if (next.isSuccess && previous?.isSuccess == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.journeySaveSuccessDesc),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate on success, passing the created journey if available
        if (next.journey != null) {
          context.pushReplacement(
              '${AppRoutes.home}/${AppRoutes.journeyDetail.split('/').last}/${next.journey!.id}',
              extra: next.journey);
        } else {
          // Fallback navigation if journey data isn't in state
          context.pop();
        }
        // Reset provider state after navigation completes (optional, depends on desired behavior)
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   if (mounted) {
        //      ref.read(journeyFormProvider.notifier).resetState();
        //   }
        // });
      }
    });

    return Scaffold(
      key: _scaffoldMessengerKey, // Use the key here
      appBar: AppBar(
        title: Text(l10n.createJourneyTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _saveJourney,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: FormBuilder(
          key: _formKey,
          // Enable auto-validation on user interaction
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNameField(context, l10n),
              const SizedBox(height: 16),
              _buildDescriptionField(context, l10n),
              const SizedBox(height: 16),
              _buildLocationField(context, l10n),
              const SizedBox(height: 16),
              _buildDateFields(context, l10n),
              const SizedBox(height: 16),
              _buildBudgetField(context, l10n),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- Refactored Field Builders ---

  Widget _buildNameField(BuildContext context, AppLocalizations l10n) {
    return FormBuilderTextField(
      name: _fieldName,
      decoration: InputDecoration(
        labelText: l10n.journeyFormFieldNameLabel,
        hintText: l10n.journeyFormFieldNameHint,
        border: const OutlineInputBorder(), // Add standard border
      ),
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: l10n.journeyFormFieldRequiredError,
        ), // Add error text
        FormBuilderValidators.minLength(
          3,
          errorText: l10n.journeyFormFieldNameMinLengthError,
        ),
      ]),
    );
  }

  Widget _buildDescriptionField(BuildContext context, AppLocalizations l10n) {
    return FormBuilderTextField(
      name: _fieldDescription,
      decoration: InputDecoration(
        labelText: l10n.journeyFormFieldDescLabel,
        hintText: l10n.journeyFormFieldDescHint,
        border: const OutlineInputBorder(), // Add standard border
      ),
      maxLines: 3,
      validator: FormBuilderValidators.maxLength(
        500,
        errorText: l10n.journeyFormFieldDescMaxLengthError,
      ),
    );
  }

  Widget _buildLocationField(BuildContext context, AppLocalizations l10n) {
    // Replace FormBuilderAutocomplete with FormBuilderField wrapping Autocomplete
    return FormBuilderField<String>(
      name: _fieldLocation,
      validator: FormBuilderValidators.required(
        errorText: l10n.journeyFormFieldRequiredError,
      ),
      builder: (FormFieldState<String?> field) {
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const [];
            }
            return _searchLocations(textEditingValue.text);
          },
          onSelected: (String selection) {
            field.didChange(selection);
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Update the field's controller if the value changes externally
            if (field.value != null &&
                fieldTextEditingController.text != field.value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                fieldTextEditingController.text = field.value!;
                // Move cursor to end
                fieldTextEditingController.selection =
                    TextSelection.fromPosition(
                  TextPosition(offset: fieldTextEditingController.text.length),
                );
              });
            }
            return TextField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                labelText: l10n.journeyFormFieldLocationLabel,
                hintText: l10n.journeyFormFieldLocationHint,
                border: const OutlineInputBorder(),
                errorText: field.errorText,
              ),
              onChanged: (value) {
                // Important: Update FormBuilderField state on change
                field.didChange(value);
              },
              // onSubmitted: (value) => onFieldSubmitted(), // Optional: Handle submission
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateFields(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align tops of fields
      children: [
        Expanded(
          child: FormBuilderTextField(
            name: 'startDateDisplay', // Separate display field name
            controller: _startDateDisplayController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: l10n.journeyFormFieldFromLabel,
              hintText: l10n.journeyFormFieldFromHint,
              border: const OutlineInputBorder(), // Add standard border
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () => _pickDate(true),
            validator: (value) {
              // Validate the underlying _startDate
              if (_startDate == null) {
                return l10n.journeyFormFieldRequiredError;
              }
              return null; // Return null if valid
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FormBuilderTextField(
            name: 'endDateDisplay', // Separate display field name
            controller: _endDateDisplayController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: l10n.journeyFormFieldTillLabel,
              hintText: l10n.journeyFormFieldTillHint,
              border: const OutlineInputBorder(), // Add standard border
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () => _pickDate(false),
            validator: (value) {
              // Validate the underlying _endDate
              if (_endDate == null) {
                return l10n.journeyFormFieldRequiredError;
              }
              if (_startDate != null && _endDate!.isBefore(_startDate!)) {
                return l10n.journeySaveInvalidDateRange;
              }
              return null; // Return null if valid
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetField(BuildContext context, AppLocalizations l10n) {
    return FormBuilderTextField(
      name: _fieldBudget,
      decoration: InputDecoration(
        labelText: l10n.journeyFormFieldBudgetLabel,
        hintText: l10n.journeyFormFieldBudgetHint,
        border: const OutlineInputBorder(), // Add standard border
        prefixIcon: const Icon(Icons.attach_money), // Add money icon
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Allow digits and at most one decimal point
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
      ],
      valueTransformer: (text) => num.tryParse(text ?? ''),
      validator: FormBuilderValidators.compose([
        // Budget is optional, so no required validator
        FormBuilderValidators.numeric(
          errorText: l10n.journeyFormFieldNumericError,
        ),
        FormBuilderValidators.min(
          0,
          errorText: l10n.journeyFormFieldBudgetMinError,
        ),
      ]),
    );
  }
}
