import 'package:flutter/material.dart';
import '../models/journey.dart';

class JourneySettingsScreen extends StatelessWidget {
  final Journey journey;

  const JourneySettingsScreen({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Journey'),
            onTap: () {
              // TODO: Implement delete functionality
            },
          ),
        ],
      ),
    );
  }
}
