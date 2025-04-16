import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for formatter
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// import 'package:shadcn_ui/shadcn_ui.dart'; // Remove import
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Add import

import '../models/journey.dart'; // Import Journey model
import '../widgets/app_title.dart'; // Import AppTitle
// import '../repositories/journey_repository.dart'; // Unused import
// import '../repositories/auth_repository.dart'; // Unused import
import '../widgets/form_field_group.dart'; // Import the new widget
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
// Remove http and dotenv imports if only used for direct Places API call
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// Import Supabase client
import 'package:supabase_flutter/supabase_flutter.dart';
// Import flutter_typeahead package
// import 'package:flutter_typeahead/flutter_typeahead.dart';

class CreateJourneyScreen extends ConsumerStatefulWidget {
  const CreateJourneyScreen({super.key});

  @override
  ConsumerState<CreateJourneyScreen> createState() => _CreateJourneyScreenState();
}

class _CreateJourneyScreenState extends ConsumerState<CreateJourneyScreen> {
  // Add a ScaffoldMessenger Key
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>(); 

  final _formKey = GlobalKey<FormBuilderState>();
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

    final formData = _formKey.currentState!.value;
    final String title = formData['name'] ?? '';
    final String description = formData['description'] ?? '';
    final String location = formData['location'] ?? '';
    final double budget = double.tryParse(formData['budget']?.toString() ?? '0.0') ?? 0.0;

    final newJourney = Journey(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      description: description,
      location: location,
      startDate: _startDate!,
      endDate: _endDate!,
      budget: budget,
      isCompleted: false,
    );

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

  // --- REMOVE Google Places API Helper --- 
  // final String _googleApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
  // final String _sessionToken = const Uuid().v4();

  // --- REWRITE _searchLocations to call Supabase Edge Function ---
   Future<List<String>> _searchLocations(String pattern) async {
     print('[_searchLocations] triggered with pattern: "$pattern"'); // Existing log

     if (pattern.isEmpty) {
       return [];
     }

     try {
       print('[DEBUG] Attempting to invoke Supabase function location-autocomplete...'); // Added log
       final response = await Supabase.instance.client.functions.invoke(
         'location-autocomplete',
         body: { 'query': pattern },
       );
       print('[DEBUG] Supabase function response status: ${response.status}'); // Added log
       print('[DEBUG] Supabase function response data: ${response.data}'); // Added log


       if (response.status != 200) {
          print('[ERROR] Supabase function invocation failed (Status != 200)'); // Added log
          // Handle function invocation errors (e.g., function not found, server error)
          // print('Supabase function invocation failed with status: ${response.status}');
          // print('Error data: ${response.data}');
          // Try to parse error message if available
          String errorMessage = 'Failed to fetch suggestions.';
          if (response.data != null && response.data['error'] is String) {
            errorMessage = response.data['error'];
          }
          // Optionally show error to user via snackbar
          if (mounted) {
              _showErrorSnackBar(context, 'Search Error', errorMessage); // Placeholder text
          }
          return [];
       }

       // Check if the response data contains the expected 'suggestions' list
       if (response.data != null && response.data['suggestions'] is List) {
          // Ensure elements are strings before casting
          final suggestions = List<String>.from(response.data['suggestions']
              .where((item) => item is String)); 
          print('[DEBUG] Received ${suggestions.length} suggestions from Supabase function.'); // Changed log level
          return suggestions;
       } else {
         print('[ERROR] Received unexpected data format from Supabase function: ${response.data}'); // Added log
         return [];
       }

     } catch (e, stackTrace) { // Catch specific invocation errors
       print('[ERROR] Exception caught invoking Supabase function: $e'); // Added log
       print('[ERROR] StackTrace: $stackTrace'); // Added log
        if (mounted) {
            // _showErrorSnackBar(context, 'Search Error', 'An unexpected error occurred.'); // Placeholder text
             _showErrorSnackBar(context, 'Search Error', 'Failed to connect to search service: $e'); // Show exception
        }
       return []; // Return empty list on error
     }
   }
   // --- End Supabase Edge Function Call ---

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
            child: Text(l10n.saveButton),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0), // Already const
        child: FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons later?
            children: [
              Text(l10n.createJourneyTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 24),

              // --- Travel Name Field --- 
              FormFieldGroup(
                label: l10n.journeyFormFieldNameLabel,
                description: l10n.journeyFormFieldNameDesc,
                child: FormBuilderTextField(
                  name: 'name',
                  decoration: InputDecoration(
                    hintText: l10n.journeyFormFieldNameHint,
                  ),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: l10n.journeyFormFieldRequiredError),
                    FormBuilderValidators.minLength(3, errorText: l10n.journeyFormFieldNameMinLengthError),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // --- Date Fields (Row for layout) --- 
              Row(
                 crossAxisAlignment: CrossAxisAlignment.start, // Align tops
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
              ),
              const SizedBox(height: 16),
              
              // --- Description Field ---
              FormFieldGroup(
                label: l10n.journeyFormFieldDescLabel,
                description: l10n.journeyFormFieldDescDesc,
                child: FormBuilderTextField(
                  name: 'description',
                  decoration: InputDecoration(
                    hintText: l10n.journeyFormFieldDescHint,
                  ),
                  maxLines: 3,
                  validator: FormBuilderValidators.maxLength(500, errorText: l10n.journeyFormFieldDescMaxLengthError),
                ),
              ),
              const SizedBox(height: 16),

              // --- Location Field (Using built-in Autocomplete) ---
              FormFieldGroup(
                label: l10n.journeyFormFieldLocationLabel,
                description: l10n.journeyFormFieldLocationDesc,
                child: FormBuilderField<String>(
                  name: 'location',
                  validator: FormBuilderValidators.required(errorText: l10n.journeyFormFieldRequiredError),
                  builder: (FormFieldState<String?> field) {
                    // Use Flutter's built-in Autocomplete widget
                    return Autocomplete<String>(
                      // Provide initial value from the FormBuilder field state
                      initialValue: TextEditingValue(text: field.value ?? ''),
                      // Function that provides options based on text input
                      optionsBuilder: (TextEditingValue textEditingValue) async {
                        // Add debounce here as well
                        await Future.delayed(const Duration(milliseconds: 300));
                        // Call the same backend function
                        return await _searchLocations(textEditingValue.text);
                      },
                      // How to display the options in the overlay
                      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            // Constrain the height of the suggestions list
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
                      // What to do when an option is selected
                      onSelected: (String selection) {
                        // Update the FormBuilder field state when an option is selected
                        field.didChange(selection);
                        FocusScope.of(context).unfocus(); // Close keyboard
                      },
                      // How to build the text field itself
                      fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                        // Forward the field state changes to the FormBuilder field
                        // This ensures validation works even if user doesn't select an option
                        textEditingController.addListener(() {
                           field.didChange(textEditingController.text);
                         });
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                             hintText: l10n.journeyFormFieldLocationHint,
                             // Display error text from FormBuilderField state
                             errorText: field.errorText,
                           ),
                           // Optional: handle submission if needed
                           // onFieldSubmitted: (String value) { onFieldSubmitted(); },
                         );
                      },
                      // Optional: Convert an option String to a String display value (usually identity)
                      displayStringForOption: (String option) => option,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // --- Budget Field ---
              FormFieldGroup(
                label: l10n.journeyFormFieldBudgetLabel,
                description: l10n.journeyFormFieldBudgetDesc,
                child: FormBuilderTextField(
                  name: 'budget',
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
