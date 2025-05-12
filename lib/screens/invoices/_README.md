# Invoice Screens

This directory contains screens related to invoice management in the Travel application, including capturing, viewing, and analyzing invoice images.

## File Overview

### `invoice_capture_overview_screen.dart`
Displays a grid view of all captured invoice images for a specific project. Provides functionality to upload new invoices via the device camera or gallery, view existing invoices in detail, and delete invoice images. Integrates with Google Cloud Storage for image management.

### `invoice_capture_detail_screen.dart`
Shows a detailed view of a specific invoice image, allowing users to see the full-size document, scan it for text using OCR, and analyze the extracted information. Provides navigation between multiple invoice images and options to process the data.

### `invoice_detail_screen.dart`
Presents the detailed information of a processed invoice, showing extracted data such as vendor, date, amount, and line items. Allows users to edit invoice metadata and associate expenses with the invoice.

## Usage Pattern

The invoice screens follow this typical usage flow:

1. From a project detail screen, users navigate to `invoice_capture_overview_screen.dart` to see all invoices
2. They can capture new invoices using the camera or upload from gallery
3. Tapping on an invoice thumbnail opens `invoice_capture_detail_screen.dart` for viewing and processing
4. After processing, the structured data can be viewed in `invoice_detail_screen.dart`

These screens leverage several services including OCR, image storage, and Firestore for data persistence. 