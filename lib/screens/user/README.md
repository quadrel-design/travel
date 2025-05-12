# User Management Screens

This directory contains screens related to user management in the Travel application, including user profile, settings, and administration features.

## File Overview

### `user_management_screen.dart`
An administrative screen for managing application users. It displays a list of all users with their profile information, provides functionality to delete users, and supports refreshing the user list. This screen interacts directly with Firestore to fetch and update user data.

## Usage

The user management screens are typically accessed from the settings menu and are restricted to users with administrative privileges. The screen provides:

- A scrollable list of all users with profile images and basic information
- Delete functionality with confirmation dialog
- Manual refresh capability for updating the user list
- Error handling for network and database operations

The screen uses the application's user model for data representation and Firestore for persistence, demonstrating proper state management and error handling patterns within the app. 