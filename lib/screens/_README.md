# Screens Directory

This directory contains all the screen components for the Travel application, organized by feature area. Each screen is responsible for a specific part of the user interface and interaction flow.

## Main Files

### `home_screen.dart`
The main dashboard screen displayed after login, showing the user's travel projects in a list view. Features include project navigation, subscription status indicator (Pro/Free), settings access, and a floating action button to create new projects. It uses Riverpod StreamProvider for reactive data fetching and GoRouter for navigation.

## Subdirectories

### [`auth/`](auth/README.md)
Contains screens related to user authentication, including login, registration, email verification, and the initial splash screen.

### [`project/`](project/README.md)
Contains screens for creating, viewing, and managing travel projects, with functionality for updating project details, settings, and overview information.

### [`invoices/`](invoices/README.md)
Contains screens for capturing, viewing, and analyzing invoice images, with OCR and data extraction capabilities.

### [`expenses/`](expenses/README.md)
Contains screens for managing expenses associated with travel projects, though currently in development with placeholder implementations.

### [`user/`](user/README.md)
Contains screens for user profile management and administration, including user listing and account management features.

### [`settings/`](settings/README.md)
Contains screens for application configuration, preferences, and user session management.

## Navigation Flow

The application's main navigation follows this pattern:

1. Auth flow (splash → login/register → verification if needed)
2. Home screen (list of projects)
3. Feature-specific screens depending on user action:
   - Project creation and management
   - Invoice capture and analysis
   - Expense tracking
   - User and account settings

All screens are designed with a consistent Material Design aesthetic and utilize Riverpod for state management. 