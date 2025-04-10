import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../providers/journey_provider.dart';

class JourneySettingsScreen extends StatelessWidget {
  final Journey journey;

  const JourneySettingsScreen({
    Key? key,
    required this.journey,
  }) : super(key: key);

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Journey'),
        content: Text(
          'Are you sure you want to delete "${journey.title}"? This will also delete all associated expenses and cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              context.read<JourneyProvider>().deleteJourney(journey.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings
              Navigator.pop(context); // Return to journey list
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Journey Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journey Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Title', journey.title),
                  _buildDetailRow(
                    'Duration',
                    '${journey.startDate.toString().split(' ')[0]} - ${journey.endDate.toString().split(' ')[0]}',
                  ),
                  _buildDetailRow(
                    'Participants',
                    journey.users.isEmpty
                        ? 'No participants yet'
                        : '${journey.users.length} participants',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (journey.users.isEmpty)
                    const Text(
                      'No participants added yet',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    )
                  else
                    ...journey.users.map((user) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(user.name),
                              const Spacer(),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 40),
            CupertinoButton(
              onPressed: () => _showDeleteConfirmation(context),
              child: const Text(
                'Delete Journey',
                style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
} 