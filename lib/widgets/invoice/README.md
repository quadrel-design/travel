# Invoice Processing UI Components

## State-based Invoice Processing Bar

### Problem Statement

The current `InvoiceProcessingBar` widget has several limitations:

- UI elements, icons, and functionality change significantly based on the invoice processing state
- Many conditional flags and optional callbacks make the code complex and harder to maintain
- Different states require completely different sets of actions and behaviors
- As new features are added, the complexity grows exponentially

### Solution: State Pattern for Processing Bars

We propose implementing a **State Pattern** with specialized UI components for each invoice processing state:

1. Create an abstract base class that acts as a factory
2. Implement concrete state-specific UI components for each status
3. Each implementation fully defines its own UI and behavior

## Implementation Details

### 1. Base Abstract Class

```dart
abstract class BaseInvoiceProcessingBar extends StatelessWidget {
  final InvoiceCaptureProcess process;
  final VoidCallback? onProcessingComplete;
  
  const BaseInvoiceProcessingBar({
    super.key,
    required this.process,
    this.onProcessingComplete,
  });
  
  // Factory constructor to return the appropriate implementation
  factory BaseInvoiceProcessingBar.forProcess(
    InvoiceCaptureProcess process, {
    VoidCallback? onProcessingComplete,
  }) {
    final status = InvoiceCaptureStatus.fromFirebaseStatus(process.status);
    
    switch (status) {
      case InvoiceCaptureStatus.ready:
        return ReadyInvoiceProcessingBar(
          process: process, 
          onProcessingComplete: onProcessingComplete,
        );
      case InvoiceCaptureStatus.processing:
        return ProcessingInvoiceProcessingBar(
          process: process,
          onProcessingComplete: onProcessingComplete,
        );
      case InvoiceCaptureStatus.invoice:
        return InvoiceRecognizedProcessingBar(
          process: process,
          onProcessingComplete: onProcessingComplete,
        );
      case InvoiceCaptureStatus.text:
      case InvoiceCaptureStatus.noText:
        return NonInvoiceProcessingBar(
          process: process,
          onProcessingComplete: onProcessingComplete,
        );
      case InvoiceCaptureStatus.error:
        return ErrorInvoiceProcessingBar(
          process: process,
          onProcessingComplete: onProcessingComplete,
        );
    }
  }
}
```

### 2. State-Specific Implementations

Each state gets its own implementation with specialized UI and behavior:

#### Ready State Bar

```dart
class ReadyInvoiceProcessingBar extends BaseInvoiceProcessingBar {
  const ReadyInvoiceProcessingBar({
    required super.process,
    super.onProcessingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Ready state shows scan button and delete
          CircleButton(
            icon: Icons.document_scanner_outlined,
            tooltip: 'Scan for invoice',
            onPressed: () => _handleScan(context),
          ),
          CircleButton(
            icon: Icons.info_outline,
            tooltip: 'Info',
            onPressed: () => _showInfo(context),
          ),
          CircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
    );
  }
  
  void _handleScan(BuildContext context) {
    // Implement scan logic specific to Ready state
    // ...
    if (onProcessingComplete != null) {
      onProcessingComplete!();
    }
  }
  
  void _showInfo(BuildContext context) {
    // Show info dialog
  }
  
  void _handleDelete(BuildContext context) {
    // Delete logic
  }
}
```

#### Processing State Bar

```dart
class ProcessingInvoiceProcessingBar extends BaseInvoiceProcessingBar {
  const ProcessingInvoiceProcessingBar({
    required super.process,
    super.onProcessingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Processing state shows progress and cancel option
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
          const SizedBox(width: 16),
          Text('Processing...', 
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 16),
          CircleButton(
            icon: Icons.cancel_outlined,
            tooltip: 'Cancel',
            onPressed: () => _cancelProcessing(context),
          ),
        ],
      ),
    );
  }
  
  void _cancelProcessing(BuildContext context) {
    // Cancel processing logic
  }
}
```

#### Invoice Recognized State Bar

```dart
class InvoiceRecognizedProcessingBar extends BaseInvoiceProcessingBar {
  const InvoiceRecognizedProcessingBar({
    required super.process,
    super.onProcessingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Invoice recognized state shows different options
          CircleButton(
            icon: Icons.ios_share,
            tooltip: 'Share invoice',
            onPressed: () => _handleShare(context),
          ),
          CircleButton(
            icon: Icons.add_chart,
            tooltip: 'Add to expenses',
            onPressed: () => _addToExpenses(context),
          ),
          CircleButton(
            icon: Icons.document_scanner_outlined,
            tooltip: 'Rescan',
            onPressed: () => _handleRescan(context),
          ),
          CircleButton(
            icon: Icons.edit_document,
            tooltip: 'Edit details',
            onPressed: () => _editDetails(context),
          ),
          CircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
    );
  }
  
  void _handleShare(BuildContext context) {
    // Share logic
  }
  
  void _addToExpenses(BuildContext context) {
    // Add to expenses logic
  }
  
  void _handleRescan(BuildContext context) {
    // Rescan logic
  }
  
  void _editDetails(BuildContext context) {
    // Edit details logic
  }
  
  void _handleDelete(BuildContext context) {
    // Delete logic
  }
}
```

### 3. Usage in Parent Widgets

```dart
// In the parent widget that uses the processing bar:
Widget build(BuildContext context) {
  return Scaffold(
    // Other widgets...
    bottomNavigationBar: BaseInvoiceProcessingBar.forProcess(
      invoiceCaptureProcess,
      onProcessingComplete: () {
        // Handle processing complete event
        setState(() {});
      },
    ),
  );
}
```

## Specific Implementation States

For our invoice processing flow, we will implement three specific states with their unique UI elements and functionality:

### 1. OCR State
This state represents when the image is ready for Optical Character Recognition processing.

**UI Elements & Functions:**
- **Start OCR** - Icon: `Icons.document_scanner` - Function: Initiates OCR processing
- **Delete Image** - Icon: `Icons.delete_outline` - Function: Removes the image
- **Download** - Icon: `Icons.download` - Function: Downloads the image to device

```dart
class OcrInvoiceProcessingBar extends BaseInvoiceProcessingBar {
  const OcrInvoiceProcessingBar({
    required super.process,
    super.onProcessingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleButton(
            icon: Icons.document_scanner,
            tooltip: 'Start OCR',
            onPressed: () => _startOcr(context),
          ),
          CircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete Image',
            onPressed: () => _deleteImage(context),
          ),
          CircleButton(
            icon: Icons.download,
            tooltip: 'Download',
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
    );
  }
  
  // Function implementations...
}
```

### 2. Analysis State
This state represents when OCR has completed and the image is ready for analysis to extract invoice data.

**UI Elements & Functions:**
- **Analyse OCR** - Icon: `Icons.analytics_outlined` - Function: Starts invoice data extraction
- **Delete** - Icon: `Icons.delete_outline` - Function: Removes the image
- **Restart OCR** - Icon: `Icons.refresh` - Function: Restarts OCR processing
- **Download** - Icon: `Icons.download` - Function: Downloads the image to device

```dart
class AnalysisInvoiceProcessingBar extends BaseInvoiceProcessingBar {
  const AnalysisInvoiceProcessingBar({
    required super.process,
    super.onProcessingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleButton(
            icon: Icons.analytics_outlined,
            tooltip: 'Analyse OCR',
            onPressed: () => _analyseOcr(context),
          ),
          CircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () => _deleteImage(context),
          ),
          CircleButton(
            icon: Icons.refresh,
            tooltip: 'Restart OCR',
            onPressed: () => _restartOcr(context),
          ),
          CircleButton(
            icon: Icons.download,
            tooltip: 'Download',
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
    );
  }
  
  // Function implementations...
}
```

### 3. Result State
This state represents when analysis has completed and invoice data has been extracted.

**UI Elements & Functions:**
- **Settings Group** - A group of settings-related buttons:
  - **Settings** - Icon: `Icons.settings` - Function: Opens settings panel
  - **Favourite** - Icon: `Icons.favorite_border`/`Icons.favorite` - Function: Toggles favouriting
  - **Info** - Icon: `Icons.info_outline` - Function: Shows invoice information
- **Delete** - Icon: `Icons.delete_outline` - Function: Removes the invoice
- **Download** - Icon: `Icons.download` - Function: Downloads the invoice to device
- **Restart OCR** - Icon: `Icons.refresh` - Function: Restarts OCR processing

```dart
class ResultInvoiceProcessingBar extends BaseInvoiceProcessingBar {
  const ResultInvoiceProcessingBar({
    required super.process,
    super.onProcessingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    final bool isFavorite = false; // Determine from process data
    
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Settings Group
          CircleButtonGroup(
            children: [
              CircleButton(
                icon: Icons.settings,
                tooltip: 'Settings',
                onPressed: () => _openSettings(context),
              ),
              CircleButton(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                iconColor: isFavorite ? Colors.redAccent : null,
                onPressed: () => _toggleFavorite(context),
              ),
              CircleButton(
                icon: Icons.info_outline,
                tooltip: 'Info',
                onPressed: () => _showInfo(context),
              ),
            ],
          ),
          CircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () => _deleteInvoice(context),
          ),
          CircleButton(
            icon: Icons.download,
            tooltip: 'Download',
            onPressed: () => _downloadInvoice(context),
          ),
          CircleButton(
            icon: Icons.refresh,
            tooltip: 'Restart OCR',
            onPressed: () => _restartOcr(context),
          ),
        ],
      ),
    );
  }
  
  // Function implementations...
}
```

## Benefits

1. **Complete UI Customization**: Each state has its own specialized UI with different icons, layouts, and functions.

2. **State-Specific Logic**: Each implementation encapsulates all the logic specific to its state.

3. **Different Number of Buttons**: Some states might need more or fewer buttons (like the processing state showing fewer options).

4. **Different Button Arrangements**: States can use different layouts appropriate to their function.

5. **Contextual Actions**: Actions change based on the document's state (e.g., "Scan" for ready state vs. "Add to expenses" for recognized invoices).

6. **Easy Evolution**: As the app evolves, new features can be added to specific states without affecting others.

7. **Simplified Testing**: Each state component can be tested in isolation.

8. **Better Maintainability**: Code organization follows the Single Responsibility Principle.

## Implementation Plan

1. Create the base abstract class `BaseInvoiceProcessingBar`
2. Implement each state-specific bar as a separate class
3. Refactor existing code to use the new pattern
4. Update parent widgets to use the factory constructor

## Future Considerations

- Consider using a provider (e.g., Riverpod) to manage state transitions
- Add analytics events for tracking user interactions with different states
- Create a design system document for UI consistency across states 