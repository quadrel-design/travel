# Authentication Screens

This directory contains screens related to user authentication, login, registration, and session management in the Travel application.

## File Overview

### `auth_screen.dart`
The main authentication screen that handles user login, registration, password reset, and email verification. It uses Firebase Authentication and implements comprehensive error handling, form validation, and supports various authentication states through Riverpod.

### `auth_wait_screen.dart`
A screen displayed while waiting for email verification or other authentication processes to complete. It shows a loading state with appropriate messaging and includes options to resend verification emails.

### `splash_screen.dart`
Initial loading screen displayed when the app starts, showing the app logo while checking authentication state and initializing necessary services before directing users to either the login screen or home screen.

## Usage Pattern

The authentication flow typically follows this sequence:

1. `splash_screen.dart` is shown on app startup
2. Based on authentication state:
   - Unauthenticated users see `auth_screen.dart`
   - During email verification, users see `auth_wait_screen.dart`
   - Authenticated users are directed to the home screen

Each screen uses Riverpod for state management and integrates with the application's authentication repository. 