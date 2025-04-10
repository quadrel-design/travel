import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return ListView.builder(
            itemCount: userProvider.users.length,
            itemBuilder: (context, index) {
              final user = userProvider.users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showUserForm(context, user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteUser(context, user),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUserForm(BuildContext context, [User? user]) {
    final nameController = TextEditingController(text: user?.name);
    final emailController = TextEditingController(text: user?.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user == null ? 'Add User' : 'Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                final newUser = User(
                  id: user?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  email: emailController.text,
                );

                if (user == null) {
                  context.read<UserProvider>().addUser(newUser);
                } else {
                  context.read<UserProvider>().updateUser(newUser);
                }

                Navigator.pop(context);
              }
            },
            child: Text(user == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<UserProvider>().deleteUser(user.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 