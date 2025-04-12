import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/journey.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class JourneyForm extends StatefulWidget {
  final Journey? initialJourney;
  final Function(Journey) onSave;
  final GlobalKey<FormState> formKey;

  const JourneyForm({
    super.key,
    this.initialJourney,
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
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialJourney != null) {
      final journey = widget.initialJourney!;
      _titleController.text = journey.title;
      _descriptionController.text = journey.description;
      _locationController.text = journey.location;
      _startDate = journey.startDate;
      _endDate = journey.endDate;
      _budgetController.text = journey.budget.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
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

  Future<void> _submitData() async {
    if (widget.formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in!')),
          );
          setState(() { _isLoading = false; });
        }
        return;
      }

      List<String> finalImageUrls = widget.initialJourney?.imageUrls ?? [];

      try {
        final journeyData = Journey(
          id: widget.initialJourney?.id ?? const Uuid().v4(),
          userId: currentUserId,
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          startDate: _startDate,
          endDate: _endDate,
          budget: double.tryParse(_budgetController.text) ?? 0.0,
          imageUrls: finalImageUrls,
          isCompleted: widget.initialJourney?.isCompleted ?? false,
        );

        widget.onSave(journeyData);

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
     final DateTime initial = isStartDate ? _startDate : _endDate;
     final DateTime first = isStartDate ? DateTime(2000) : _startDate;

     final DateTime? picked = await showDatePicker(
       context: context,
       initialDate: initial,
       firstDate: first,
       lastDate: DateTime(2100),
     );

     if (picked != null) {
       setState(() {
         if (isStartDate) {
           _startDate = picked;
           if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(days: 1));
           }
         } else {
           _endDate = picked;
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
               title: Text('Start Date: ${_formatDate(_startDate)}'),
               trailing: const Icon(Icons.calendar_today),
               onTap: () => _selectDate(context, true),
            ),
            ListTile(
               contentPadding: EdgeInsets.zero,
               title: Text('End Date: ${_formatDate(_endDate)}'),
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
              onPressed: _isLoading ? null : _submitData,
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
