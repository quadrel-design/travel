import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/journey.dart';
import '../models/user.dart';
import '../providers/journey_provider.dart';
import '../providers/user_provider.dart';

class JourneySettingsScreen extends StatefulWidget {
  final Journey journey;

  const JourneySettingsScreen({
    Key? key,
    required this.journey,
  }) : super(key: key);

  @override
  State<JourneySettingsScreen> createState() => _JourneySettingsScreenState();
}

class _JourneySettingsScreenState extends State<JourneySettingsScreen> {
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Journey'),
        content: Text(
          'Are you sure you want to delete "${widget.journey.title}"? This will also delete all associated expenses and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<JourneyProvider>().deleteJourney(widget.journey.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings
              Navigator.pop(context); // Return to journey list
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddParticipantDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final journeyProvider = context.read<JourneyProvider>();
    
    final availableUsers = userProvider.users
        .where((user) => !widget.journey.users.any((jUser) => jUser.id == user.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (availableUsers.isNotEmpty) ...[
              const Text('Select from existing users:'),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = availableUsers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      onTap: () {
                        final updatedJourney = widget.journey.copyWith(
                          users: [...widget.journey.users, user],
                        );
                        journeyProvider.updateJourney(updatedJourney);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Create Invitation Link'),
              subtitle: const Text('Share this link to invite others'),
              onTap: () {
                Navigator.pop(context);
                _createAndShareInvitationLink();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createAndShareInvitationLink() {
    // Generate a unique invitation code for this journey
    final invitationCode = '${widget.journey.id}-${DateTime.now().millisecondsSinceEpoch}';
    final invitationLink = 'travelapp://join/${widget.journey.id}?code=$invitationCode';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invitation Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this link to invite others to join your journey:'),
            const SizedBox(height: 16),
            SelectableText(
              invitationLink,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'When someone clicks this link, they will be able to join your journey.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Share.share(
                  'Join my journey "${widget.journey.title}"!\n\nClick this link to join: $invitationLink',
                  subject: 'Join my journey: ${widget.journey.title}',
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to share the invitation link'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _removeParticipant(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Are you sure you want to remove ${user.name} from this journey?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updatedJourney = widget.journey.copyWith(
                users: widget.journey.users.where((u) => u.id != user.id).toList(),
              );
              context.read<JourneyProvider>().updateJourney(updatedJourney);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Settings'),
      ),
      body: ListView(
        children: [
          // Participants section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: () => _showAddParticipantDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Participant'),
                ),
              ],
            ),
          ),
          Consumer<JourneyProvider>(
            builder: (context, journeyProvider, child) {
              final updatedJourney = journeyProvider.journeys
                  .firstWhere((j) => j.id == widget.journey.id, orElse: () => widget.journey);
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: updatedJourney.users.length,
                itemBuilder: (context, index) {
                  final user = updatedJourney.users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _removeParticipant(context, user),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const Divider(),
          // Delete journey section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: () => _showDeleteConfirmation(context),
              child: const Text(
                'Delete Journey',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 