import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // Remove unused import
import '../../models/user.dart' as app_user;
// Import Firestore
// import 'package:cloud_firestore/cloud_firestore.dart'; // Remove this import
import 'package:firebase_core/firebase_core.dart'; // Keep for FirebaseException if used generally

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  UserManagementScreenState createState() => UserManagementScreenState();
}

class UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  List<app_user.User> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Use Firestore
      // final firestore = FirebaseFirestore.instance; // Comment out
      // final querySnapshot = await firestore.collection('users').get(); // Comment out

      // Map Firestore documents, including the ID
      // final List<app_user.User> loadedUsers = querySnapshot.docs.map((doc) { // Comment out
      //   final data = doc.data(); // Comment out
      //   data['id'] = doc.id; // Add Firestore document ID // Comment out
      //   return app_user.User.fromJson(data); // Comment out
      // }).toList(); // Comment out
      final List<app_user.User> loadedUsers = []; // Placeholder

      if (mounted) {
        setState(() {
          _users = loadedUsers;
          _isLoading = false;
          if (loadedUsers.isEmpty) {
            _error =
                'User fetching logic needs to be updated to use PostgreSQL.'; // Placeholder message
          }
        });
      }
      // Catch FirebaseException
    } on FirebaseException catch (e) {
      // This might catch general Firebase errors, fine to keep
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: ${e.message} (Firebase Core Error)';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to remove this user?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
      try {
        // Use Firestore
        // final firestore = FirebaseFirestore.instance; // Comment out
        // await firestore.collection('users').doc(userId).delete(); // Comment out

        _error =
            'User deletion logic needs to be updated to use PostgreSQL for user ID: $userId.'; // Placeholder

        // Refetch users after delete
        await _fetchUsers(); // This will show the placeholder error now

        // Catch FirebaseException
      } on FirebaseException catch (e) {
        // This might catch general Firebase errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to delete user: ${e.message} (Firebase Core Error)')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(child: Text('No users found.'));

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    } else if (_users.isNotEmpty) {
      content = ListView.builder(
        itemCount: _users.length,
        itemBuilder: (ctx, index) {
          final user = _users[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(user.name),
            subtitle: Text(user.email),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _deleteUser(user.id),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: content,
    );
  }
}
