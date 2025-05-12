# Project Screens

This directory contains screens related to project management in the Travel application, including project creation, viewing, and editing functionality.

## File Overview

### `project_create.dart`
A comprehensive form-based screen for creating new travel projects, with fields for title, description, location, dates, and budget. Uses Flutter Form Builder for validation and Riverpod for state management, with error handling for form submission.

### `project_detail_screen.dart`
Displays detailed information about a specific project, including metadata, related invoices, and expenses. Provides navigation options to view and manage project elements like attached invoice images and expense details.

### `project_overview_screen.dart`
Shows a summary view of project information, allowing users to quickly see the status, budget, and timeline of a project. Acts as an entry point to more detailed project views and management options.

### `project_settings_screen.dart`
Provides configuration options for a specific project, allowing users to update project details, manage sharing settings, and adjust project-specific preferences and permissions.

## Usage Pattern

The project screens are typically accessed in this sequence:

1. Users view their projects in the home screen
2. They can create new projects using `project_create.dart`
3. Users can select a project to view its overview in `project_overview_screen.dart`
4. From there, they can navigate to `project_detail_screen.dart` or `project_settings_screen.dart`

All screens are integrated with the application's repository layer for data fetching and persistence. 