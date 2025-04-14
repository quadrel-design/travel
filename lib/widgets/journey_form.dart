import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/journey.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class JourneyForm extends StatefulWidget {
  final Journey? journey;
  final Function(Journey) onSave;
  final GlobalKey<FormState> formKey;

  const JourneyForm({
    super.key,
    this.journey,
    required this.onSave,
    required this.formKey,
  });

  @override
  State<JourneyForm> createState() => _JourneyFormState();
}

class _JourneyFormState extends State<JourneyForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    if (widget.journey != null) {
      _titleController.text = widget.journey!.title;
      _descriptionController.text = widget.journey!.description;
      _locationController.text = widget.journey!.location;
      _budgetController.text = widget.journey!.budget.toString();
      _selectedStartDate = widget.journey!.startDate;
      _selectedEndDate = widget.journey!.endDate;
    } else {
      _selectedStartDate = DateTime.now();
    }
  }

  Future<void> _pickImages() async {
    List<File> newlySelectedImages = [];
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1920,
      );
      if (images.isNotEmpty) {
        newlySelectedImages = images.map((xFile) => File(xFile.path)).toList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${newlySelectedImages.length} images selected. Upload not implemented.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in.')),
      );
      return;
    }

    if (widget.formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newJourney = Journey(
          id: widget.journey?.id ?? const Uuid().v4(),
          userId: currentUserId,
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          budget: double.tryParse(_budgetController.text) ?? 0.0,
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
          isCompleted: false,
        );

        widget.onSave(newJourney);

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving journey: $e')),
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
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
     final DateTime initial = isStartDate ? _selectedStartDate : _selectedEndDate;
     final DateTime first = isStartDate ? DateTime(2000) : _selectedStartDate;

     final DateTime? picked = await showDatePicker(
       context: context,
       initialDate: initial,
       firstDate: first,
       lastDate: DateTime(2100),
     );

     if (picked != null) {
       setState(() {
         if (isStartDate) {
           _selectedStartDate = picked;
           if (_selectedEndDate.isBefore(_selectedStartDate)) {
              _selectedEndDate = _selectedStartDate.add(const Duration(days: 1));
           }
         } else {
           _selectedEndDate = picked;
         }
       });
     }
   }

   String _formatDate(DateTime date) {
       return '${date.day}/${date.month}/${date.year}';
   }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
               validator: (value) {
                 if (value == null || value.isEmpty) {
                   return 'Please enter a description.';
                 }
                 return null;
               },
            ),
             const SizedBox(height: 10),
             TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
               validator: (value) {
                 if (value == null || value.isEmpty) {
                   return 'Please enter a location.';
                 }
                 return null;
               },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(labelText: 'Budget (\$)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a budget.';
                }
                final budgetValue = double.tryParse(value);
                if (budgetValue == null || budgetValue <= 0) {
                  return 'Please enter a valid positive budget.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            ListTile(
               contentPadding: EdgeInsets.zero,
               title: Text('Start Date: ${_formatDate(_selectedStartDate)}'),
               trailing: const Icon(Icons.calendar_today),
               onTap: () => _selectDate(context, true),
            ),
            ListTile(
               contentPadding: EdgeInsets.zero,
               title: Text('End Date: ${_formatDate(_selectedEndDate)}'),
               trailing: const Icon(Icons.calendar_today),
               onTap: () => _selectDate(context, false),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _pickImages,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Select Images'),
            ),
             const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Journey'),
            ),
          ],
        ),
      ),
    );
  }
}
