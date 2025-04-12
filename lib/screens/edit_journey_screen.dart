import 'package:flutter/material.dart';
import '../models/journey.dart';

class EditJourneyScreen extends StatelessWidget {
  final Journey journey;

  const EditJourneyScreen({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${journey.title}'),
      ),
      body: const Center(
        child: Text('Edit Journey Screen'),
      ),
    );
  }
}
