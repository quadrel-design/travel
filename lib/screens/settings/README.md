# Settings Screens

This directory contains screens related to application settings and user preferences in the Travel application.

## File Overview

### `app_settings_screen.dart`
The main settings screen of the application, providing user interface for various configuration options. Features include:

- Account management options (saved items, archive, activity history)
- Notification preferences
- Time management settings
- Sign-out functionality with error handling
- Localized content using Flutter's app_localizations
- Navigation using GoRouter

The screen follows Material Design guidelines and uses theming for consistent styling throughout the app. It integrates with the application's authentication repository for user session management.

## Usage

The settings screen is typically accessed from the main navigation menu or app drawer. Settings are organized in logical groups with appropriate icons and clear labels. The screen demonstrates:

- Proper use of ListTile widgets for consistent settings items
- Section headers and dividers for visual organization
- Error handling for operations like signing out
- Internationalization support for all text elements

This modular approach allows for easy extension with additional settings categories as the application evolves. 