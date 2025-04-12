import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // Removed unused provider
import '../models/journey.dart';
import '../widgets/journey_form.dart';
// import 'package:intl/intl.dart'; // Removed unused intl
import 'package:supabase_flutter/supabase_flutter.dart';

class JourneyEditScreen extends StatefulWidget {
  final Journey journey; // Expect a Journey object

  const JourneyEditScreen({super.key, required this.journey});

  @override
  State<JourneyEditScreen> createState() => _JourneyEditScreenState();
}

class _JourneyEditScreenState extends State<JourneyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late Journey _editedJourney;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _editedJourney = widget.journey;
  }

  void _saveForm(Journey journeyData) async {
    // The form key validation is primarily handled by the form itself upon its submission
    // This callback receives the validated data
    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client
          .from('journeys')
          .update(journeyData.toJson())
          .eq('id', journeyData.id);

      if (mounted) {
        Navigator.of(context).pop(journeyData);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update journey: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Edit Journey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Removed redundant AppBar save button, rely on form's button
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: JourneyForm(
                initialJourney: _editedJourney,
                onSave: _saveForm,
                formKey: _formKey,
              ),
            ),
    );
  }
}
