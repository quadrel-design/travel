# Widgets Directory

This directory contains reusable UI components (widgets) for the Travel application. These widgets provide the building blocks for the app's user interface, particularly focusing on invoice capture and analysis functionality.

## File Overview

### `circle_icon_button.dart`
Implements a circular Material Design button with an icon, providing customizable background and icon colors, size, and padding. Used throughout the app for consistent action buttons.

### `circle_icon_group.dart`
Groups multiple circular icon buttons together in a horizontally arranged container with a shared background and rounded corners, creating a cohesive button group.

### `invoice_analysis_panel.dart`
Displays a detailed analysis panel for invoice images, showing extracted data such as merchant information, amounts, and dates from OCR and AI processing results.

### `invoice_capture_controller.dart`
Manages the business logic for invoice capture operations, including scanning, analysis, and deletion, serving as a controller between UI widgets and backend services.

### `invoice_capture_detail_view.dart`
Provides a full-screen view for interacting with invoice images, including navigation between multiple images, and buttons for scanning, analysis, and deletion.

### `invoice_capture_feedback_widgets.dart`
Contains helper widgets for providing visual feedback during processing, such as error messages, loading indicators, and retry buttons.

### `invoice_detail_bottom_bar.dart`
Renders a customizable bottom navigation bar specifically for invoice detail screens, with circular buttons for actions like uploading, scanning, and deleting.

### `invoice_image_gallery.dart`
Implements a zoomable, swipeable gallery view for invoice images using PhotoView, with support for loading images from Google Cloud Storage.

## Usage Example

```dart
// Example: Using the InvoiceDetailBottomBar
Scaffold(
  appBar: AppBar(title: Text('Invoice Details')),
  body: // Your main content here,
  bottomNavigationBar: InvoiceDetailBottomBar(
    onScan: () => handleScanButtonPressed(),
    onDelete: () => handleDeleteButtonPressed(),
    onUpload: () => handleUploadButtonPressed(),
  ),
)

// Example: Using circular icon buttons
CircleIconButton(
  icon: Icons.camera_alt,
  onPressed: () => captureImage(),
  backgroundColor: Theme.of(context).primaryColor,
  iconColor: Colors.white,
)
``` 