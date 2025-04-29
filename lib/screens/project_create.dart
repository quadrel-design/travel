/// Project Creation Screen
///
/// Provides a form using flutter_form_builder for users to input details
/// (title, dates, description, location, budget) and create a new project/invoice.
/// Uses [projectFormProvider] for state management and handling the save operation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for formatter
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:intl/intl.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:travel/providers/logging_provider.dart'; // Import logger provider

// Ensure Project model is imported
import '../models/project.dart'; // Import Project model
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
// import '../providers/project_provider.dart';

// Add imports used by the logic (might have been missed)
// import '../providers/repository_providers.dart';
// import 'package:travel/utils/validators.dart'; // Remove this non-existent import
import 'package:travel/constants/app_routes.dart';
// import 'package:travel/providers/location_service_provider.dart'; // Removed location service import
import 'package:travel/providers/project_form_provider.dart';
// import 'package:travel/providers/auth_repository_provider.dart';

/// A screen widget for creating new projects/invoices.
class ProjectCreateScreen extends ConsumerStatefulWidget {
  const ProjectCreateScreen({super.key});

  @override
  ConsumerState<ProjectCreateScreen> createState() =>
      _ProjectCreateScreenState();
}

/// State class for the [ProjectCreateScreen].
class _ProjectCreateScreenState extends ConsumerState<ProjectCreateScreen> {
  static const Duration _kAutocompleteDebounceDuration =
      Duration(milliseconds: 300);

  // Constants for form field names
  /// Form field name for the project title.
  static const _fieldName = 'name';

  /// Form field name for the project description.
  static const _fieldDescription = 'description';

  /// Form field name for the project location.
  static const _fieldLocation = 'location';

  /// Form field name for the project budget.
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
  // Removed local _isLoading state - now managed by projectFormProvider

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

  /// Saves the project without performing any Google Places search.
  Future<void> _saveProject() async {
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
              context, "Error", "User session lost. Cannot save project.");
        }
        return; // Cannot proceed without user ID
      }

      // Create the Project object
      final newProject = Project(
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

      // Call the notifier to create the project
      // The listen callback will handle success/error feedback and navigation
      await ref.read(projectFormProvider.notifier).createProject(newProject);
    }
  }

  /// Builds the UI for the Create Project screen.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Watch the form state provider
    final formState = ref.watch(projectFormProvider);
    final isLoading = formState.isLoading; // Get loading state from provider

    // Listen to the form provider for side effects (navigation, snackbars)
    ref.listen<ProjectFormState>(projectFormProvider, (previous, next) {
      // Handle errors shown via SnackBar
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(context, l10n.projectSaveErrorTitle, next.error!);
        // Optionally reset the error in the provider after showing it
        // This prevents the snackbar from reappearing on rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Check mounted before interacting with ref post-frame
            ref.read(projectFormProvider.notifier).state =
                next.copyWith(clearError: true);
          }
        });
      }
      // Handle navigation on success
      if (next.isSuccess && previous?.isSuccess == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.projectSaveSuccessDesc),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate on success, passing the created project if available
        if (next.project != null) {
          context.pushReplacement(
              '${AppRoutes.home}/${AppRoutes.projectDetail.split('/').last}/${next.project!.id}',
              extra: next.project);
        } else {
          // Fallback navigation if project data isn't in state
          context.pop();
        }
        // Reset provider state after navigation completes (optional, depends on desired behavior)
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   if (mounted) {
        //      ref.read(projectFormProvider.notifier).resetState();
        //   }
        // });
      }
    });

    return Scaffold(
      key: _scaffoldMessengerKey, // Use the key here
      appBar: AppBar(
        title: Text(l10n.createProjectTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _saveProject,
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
        labelText: l10n.projectFormFieldNameLabel,
        hintText: l10n.projectFormFieldNameHint,
        border: const OutlineInputBorder(), // Add standard border
      ),
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: l10n.projectFormFieldRequiredError,
        ), // Add error text
        FormBuilderValidators.minLength(
          3,
          errorText: l10n.projectFormFieldNameMinLengthError,
        ),
      ]),
    );
  }

  Widget _buildDescriptionField(BuildContext context, AppLocalizations l10n) {
    return FormBuilderTextField(
      name: _fieldDescription,
      decoration: InputDecoration(
        labelText: l10n.projectFormFieldDescLabel,
        hintText: l10n.projectFormFieldDescHint,
        border: const OutlineInputBorder(), // Add standard border
      ),
      maxLines: 3,
      validator: FormBuilderValidators.maxLength(
        500,
        errorText: l10n.projectFormFieldDescMaxLengthError,
      ),
    );
  }

  Widget _buildLocationField(BuildContext context, AppLocalizations l10n) {
    // Simple text field instead of autocomplete
    return FormBuilderTextField(
      name: _fieldLocation,
      decoration: InputDecoration(
        labelText: l10n.projectFormFieldLocationLabel,
        hintText: l10n.projectFormFieldLocationHint,
        border: const OutlineInputBorder(),
      ),
      validator: FormBuilderValidators.required(
        errorText: l10n.projectFormFieldRequiredError,
      ),
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
              labelText: l10n.projectFormFieldFromLabel,
              hintText: l10n.projectFormFieldFromHint,
              border: const OutlineInputBorder(), // Add standard border
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () => _pickDate(true),
            validator: (value) {
              // Validate the underlying _startDate
              if (_startDate == null) {
                return l10n.projectFormFieldRequiredError;
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
              labelText: l10n.projectFormFieldTillLabel,
              hintText: l10n.projectFormFieldTillHint,
              border: const OutlineInputBorder(), // Add standard border
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () => _pickDate(false),
            validator: (value) {
              // Validate the underlying _endDate
              if (_endDate == null) {
                return l10n.projectFormFieldRequiredError;
              }
              if (_startDate != null && _endDate!.isBefore(_startDate!)) {
                return l10n.projectSaveInvalidDateRange;
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
        labelText: l10n.projectFormFieldBudgetLabel,
        hintText: l10n.projectFormFieldBudgetHint,
        border: const OutlineInputBorder(), // Add standard border
        prefixIcon: const Icon(Icons.attach_money), // Add money icon
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Allow digits and at most one decimal point
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d* ')),
      ],
      valueTransformer: (text) => num.tryParse(text ?? ''),
      validator: FormBuilderValidators.compose([
        // Budget is optional, so no required validator
        FormBuilderValidators.numeric(
          errorText: l10n.projectFormFieldNumericError,
        ),
        FormBuilderValidators.min(
          0,
          errorText: l10n.projectFormFieldBudgetMinError,
        ),
      ]),
    );
  }
}
