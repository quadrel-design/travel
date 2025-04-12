import 'package:flutter/material.dart';

class CreateJourneyScreen extends StatelessWidget {
  const CreateJourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Journey'),
      ),
      body: const Center(
        child: Text('Create Journey Screen'),
      ),
    );
  }
}
