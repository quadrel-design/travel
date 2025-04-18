import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for formatter
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:intl/intl.dart';
// import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// import '../models/journey.dart'; // Import Journey model
import '../widgets/app_title.dart'; // Import AppTitle
import '../widgets/form_field_group.dart'; // Import the new widget
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

// Import Supabase client
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_footer_bar.dart'; // Import the footer bar

// Remove imports for non-existent files
// import '../providers/auth_provider.dart';
// import '../providers/journey_provider.dart';

class CreateJourneyScreen extends ConsumerStatefulWidget {
  const CreateJourneyScreen({super.key});

  @override
  ConsumerState<CreateJourneyScreen> createState() => _CreateJourneyScreenState();
}

class _CreateJourneyScreenState extends ConsumerState<CreateJourneyScreen> {
  // Constants for form field names
  static const _fieldName = 'name';
  static const _fieldDescription = 'description';
  static const _fieldLocation = 'location';
  static const _fieldBudget = 'budget';

  // Constant for Autocomplete debounce
  static const _kAutocompleteDebounceDuration = Duration(milliseconds: 300);

  // ScaffoldMessenger Key
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Form Key
  final _formKey = GlobalKey<FormBuilderState>();

  // Date Controllers & Format
  final _startDateDisplayController = TextEditingController();
  final _endDateDisplayController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy'); 

  // State variables
  DateTime? _startDate;
  DateTime? _endDate;
  // ignore: prefer_final_fields
  bool _isLoading = false;

  @override
  void dispose() {
    // Use the key to remove the SnackBar
    _scaffoldMessengerKey.currentState?.removeCurrentSnackBar(); 
    
    // dispose all controllers
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
   
   // Commented out for now - will be used when success messaging is needed
   /*
   void _showSuccessSnackBar(BuildContext context, String title, String message) {
     // Use the key to hide/show
     _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
     _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(message)]), backgroundColor: Theme.of(context).colorScheme.primary));
   }
   */

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

  // Commented out for now - will be connected to UI when implementation is finalized
  /*
  Future<void> _saveJourney() async {
    final l10n = AppLocalizations.of(context)!;
    final journeyRepository = ref.read(journeyRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) {
      _showErrorSnackBar(context, l10n.missingInfoTitle, l10n.journeySaveMissingInfoDesc);
      return;
    }
    
    if (_startDate == null || _endDate == null) {
       _showErrorSnackBar(context, l10n.errorTitle, l10n.journeySaveInvalidDateRange);
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
       _showErrorSnackBar(context, l10n.errorTitle, l10n.journeySaveInvalidDateRange);
      return;
    }

    setState(() { _isLoading = true; });

    final userId = authRepository.currentUser?.id;
    if (userId == null) {
      _showErrorSnackBar(context, l10n.errorTitle, l10n.createJourneyErrorUserNotLoggedIn);
      setState(() { _isLoading = false; });
      return;
    }

    // Extract form data using constants
    final formData = _formKey.currentState!.value;
    final title = formData[_fieldName] as String;
    // Unused variables - comment out or remove
    // final description = formData[_fieldDescription] as String? ?? '';
    // final location = formData[_fieldLocation] as String; // Already validated as required
    // Unused variable - comment out or remove
    // final budgetNum = formData[_fieldBudget] as num?;
    // final budget = budgetNum?.toDouble() ?? 0.0;

    try {
      await journeyRepository.createJourney(title);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close screen on success
    } catch (error) {
       if (mounted) {
           _showErrorSnackBar(context, l10n.journeySaveErrorTitle, l10n.journeyDeleteErrorDesc(error.toString()));
       }
    } finally {
       if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
  */

  // --- REWRITE _searchLocations to call Supabase Edge Function ---
   Future<List<String>> _searchLocations(String pattern) async {
     // Debug print - keep as a comment
     // print('[_searchLocations] triggered with pattern: "$pattern"');

     if (pattern.isEmpty) {
       return [];
     }

     try {
       // Invoke Supabase function for location autocomplete
       final response = await Supabase.instance.client.functions.invoke(
         'location-autocomplete',
         body: { 'query': pattern },
       );

       if (response.status != 200) {
          // Log error but comment out print statement
          // print('[ERROR] Supabase function invocation failed (Status != 200)');
          
          // Handle function invocation errors
          String errorMessage = 'Failed to fetch suggestions.';
          if (response.data != null && response.data['error'] is String) {
            errorMessage = response.data['error'];
          }
          // Optionally show error to user via snackbar
          if (mounted) {
              _showErrorSnackBar(context, 'Search Error', errorMessage);
          }
          return [];
       }

       // Check if the response data contains the expected 'suggestions' list
       if (response.data != null && response.data['suggestions'] is List) {
          // Ensure elements are strings before casting
          final suggestions = List<String>.from(response.data['suggestions']
              .where((item) => item is String)); 
          return suggestions;
       } else {
         // Log error but comment out print statement
         // print('[ERROR] Received unexpected data format from Supabase function: ${response.data}');
         return [];
       }

     } catch (e) { // Remove unused stackTrace parameter
       // Log error but comment out print statements
       // print('[ERROR] Exception caught invoking Supabase function: $e');
       // print('[ERROR] StackTrace: $stackTrace');
       
        if (mounted) {
             _showErrorSnackBar(context, 'Search Error', 'Failed to connect to search service: $e');
        }
       return []; // Return empty list on error
     }
   }
   // --- End Supabase Edge Function Call ---

  @override
  Widget build(BuildContext context) {
     final l10n = AppLocalizations.of(context)!;
     final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: const AppTitle(),
        actions: const [], // Remove the Save button from actions
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.createJourneyTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 24),

              // Call private build methods for each section
              _buildNameField(context, l10n),
              const SizedBox(height: 16),
              _buildDateFields(context, l10n),
              const SizedBox(height: 16),
              _buildDescriptionField(context, l10n),
              const SizedBox(height: 16),
              _buildLocationField(context, l10n),
              const SizedBox(height: 16),
              _buildBudgetField(context, l10n),
              const SizedBox(height: 16), // Add space before indicator

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
      // Add the footer bar here
      bottomNavigationBar: const AppFooterBar(),
    );
  }

  // --- Private Build Methods for Form Sections ---

  Widget _buildNameField(BuildContext context, AppLocalizations l10n) {
    return FormFieldGroup(
      label: l10n.journeyFormFieldNameLabel,
      description: l10n.journeyFormFieldNameDesc,
      child: FormBuilderTextField(
        name: _fieldName,
        decoration: InputDecoration(
          hintText: l10n.journeyFormFieldNameHint,
        ),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(errorText: l10n.journeyFormFieldRequiredError),
          FormBuilderValidators.minLength(3, errorText: l10n.journeyFormFieldNameMinLengthError),
        ]),
      ),
    );
  }

  Widget _buildDateFields(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FormFieldGroup(
            label: l10n.journeyFormFieldFromLabel,
            child: TextFormField(
              controller: _startDateDisplayController,
              decoration: InputDecoration(
                hintText: l10n.journeyFormFieldFromHint,
              ),
              readOnly: true,
              onTap: () => _pickDate(true),
              validator: (v) => _startDate == null ? l10n.journeyFormFieldRequiredError : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FormFieldGroup(
            label: l10n.journeyFormFieldTillLabel,
            child: TextFormField(
              controller: _endDateDisplayController,
              decoration: InputDecoration(
                hintText: l10n.journeyFormFieldTillHint,
              ),
              readOnly: true,
              onTap: () => _pickDate(false),
              validator: (v) => _endDate == null ? l10n.journeyFormFieldRequiredError : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(BuildContext context, AppLocalizations l10n) {
    return FormFieldGroup(
      label: l10n.journeyFormFieldDescLabel,
      description: l10n.journeyFormFieldDescDesc,
      child: FormBuilderTextField(
        name: _fieldDescription,
        decoration: InputDecoration(
          hintText: l10n.journeyFormFieldDescHint,
        ),
        maxLines: 3,
        validator: FormBuilderValidators.maxLength(500, errorText: l10n.journeyFormFieldDescMaxLengthError),
      ),
    );
  }

  Widget _buildLocationField(BuildContext context, AppLocalizations l10n) {
    return FormFieldGroup(
      label: l10n.journeyFormFieldLocationLabel,
      description: l10n.journeyFormFieldLocationDesc,
      child: FormBuilderField<String>(
        name: _fieldLocation,
        validator: FormBuilderValidators.required(errorText: l10n.journeyFormFieldRequiredError),
        builder: (FormFieldState<String?> field) {
          return Autocomplete<String>(
            initialValue: TextEditingValue(text: field.value ?? ''),
            optionsBuilder: (TextEditingValue textEditingValue) async {
              // Use the constant for debounce delay
              await Future.delayed(_kAutocompleteDebounceDuration);
              return await _searchLocations(textEditingValue.text);
            },
            optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
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
                        return InkWell(
                          onTap: () {
                            onSelected(option);
                          },
                          child: ListTile(
                            title: Text(option),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (String selection) {
              field.didChange(selection);
              FocusScope.of(context).unfocus();
            },
            fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
              textEditingController.addListener(() {
                  field.didChange(textEditingController.text);
                });
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                    hintText: l10n.journeyFormFieldLocationHint,
                    errorText: field.errorText,
                  ),
                );
            },
            displayStringForOption: (String option) => option,
          );
        },
      ),
    );
  }

  Widget _buildBudgetField(BuildContext context, AppLocalizations l10n) {
    return FormFieldGroup(
      label: l10n.journeyFormFieldBudgetLabel,
      description: l10n.journeyFormFieldBudgetDesc,
      child: FormBuilderTextField(
        name: _fieldBudget,
        decoration: InputDecoration(
          hintText: l10n.journeyFormFieldBudgetHint,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        valueTransformer: (text) => num.tryParse(text ?? ''),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(errorText: l10n.journeyFormFieldRequiredError),
          FormBuilderValidators.numeric(errorText: l10n.journeyFormFieldNumericError),
          FormBuilderValidators.min(0.01, errorText: l10n.journeyFormFieldBudgetMinError),
        ]),
      ),
    );
  }

}
