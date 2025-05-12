import 'dart:typed_data'; // For Uint8List
import 'dart:async';

// Firebase Imports
// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed unused import
// import 'package:firebase_auth/firebase_auth.dart'; // Removed unused import

// Remove Supabase import
// import 'package:supabase_flutter/supabase_flutter.dart';

// import 'package:logger/logger.dart'; // Removed unused import
import '../models/invoice_image_process.dart';
// import 'repository_exceptions.dart'; // Removed unused import
import '../models/project.dart';
// import '../services/gcs_file_service.dart'; // Removed unused import

/// Interface for invoice-related operations
abstract class InvoiceRepository {
  /// Fetches a stream of all projects for the current user
  Stream<List<Project>> fetchUserProjects();

  /// Gets a stream for a specific project
  Stream<Project?> getProjectStream(String projectId);

  /// Gets a stream of images for a specific invoice in a project
  Stream<List<InvoiceImageProcess>> getInvoiceImagesStream(
      String projectId, String invoiceId);

  /// Adds a new project
  Future<Project> addProject(Project project);

  /// Updates an existing project
  Future<void> updateProject(Project project);

  /// Deletes a project
  Future<void> deleteProject(String projectId);

  /// Updates image info with OCR results
  Future<void> updateImageWithOcrResults(
    String projectId,
    String invoiceId,
    String imageId, {
    bool? isInvoice,
    Map<String, dynamic>? invoiceAnalysis,
  });

  /// Updates image info with full analysis details from Gemini
  Future<void> updateImageWithAnalysisDetails(
    String projectId,
    String invoiceId,
    String imageId, {
    required Map<String, dynamic> analysisData,
    required bool isInvoiceConfirmed,
    String?
        status, // Optional: to set a specific status like 'analysis_complete'
  });

  /// Deletes a project image
  Future<void> deleteInvoiceImage(
      String projectId, String invoiceId, String imageId);

  /// Uploads a project image
  Future<InvoiceImageProcess> uploadInvoiceImage(
    String projectId,
    String invoiceId,
    Uint8List fileBytes,
    String fileName,
  );

  /// Returns a stream of all invoice images for all invoices in a project.
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId);
}
