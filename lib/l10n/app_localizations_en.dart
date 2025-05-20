// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorTitle => 'Error';

  @override
  String get unexpectedErrorDesc => 'An unexpected error occurred.';

  @override
  String get logoutErrorTitle => 'Logout Error';

  @override
  String get logoutUnexpectedErrorDesc => 'An unexpected error occurred during logout.';

  @override
  String get missingInfoTitle => 'Missing Information';

  @override
  String get enterEmailFirstDesc => 'Please enter your email address first.';

  @override
  String get passwordResetEmailSentTitle => 'Check Your Email';

  @override
  String get passwordResetEmailSentDesc => 'Password reset email sent! Please check your inbox.';

  @override
  String get passwordResetFailedDesc => 'Could not send reset email. Please try again.';

  @override
  String get authErrorTitle => 'Authentication Error';

  @override
  String get signInFailedTitle => 'Sign In Failed';

  @override
  String get emailRegisteredTitle => 'Email Registered';

  @override
  String get emailRegisteredDesc => 'This email is already registered. Please sign in instead.';

  @override
  String get emailNotConfirmedDesc => 'Please confirm your email before signing in.';

  @override
  String get invalidLoginCredentialsDesc => 'Incorrect email or password.';

  @override
  String get signUpSuccessTitle => 'Sign Up Successful';

  @override
  String get signUpSuccessDesc => 'Please check your email to confirm.';

  @override
  String get verificationErrorTitle => 'Verification Error';

  @override
  String get verificationErrorDesc => 'Could not verify email. Please try again.';

  @override
  String get projectSaveErrorTitle => 'Save Error';

  @override
  String get projectSaveSuccessTitle => 'Project Saved';

  @override
  String get projectSaveSuccessDesc => 'Your new project has been created.';

  @override
  String get projectSaveMissingInfoDesc => 'Please fill in all required fields, including dates.';

  @override
  String get projectSaveInvalidDateRange => 'End date cannot be before start date.';

  @override
  String get projectDeleteSuccessDesc => 'Project deleted.';

  @override
  String projectDeleteErrorDesc(Object error) {
    return 'Failed to delete project: $error';
  }

  @override
  String get invoiceImageLoadErrorDesc => 'Failed to load images';

  @override
  String get editNotImplementedDesc => 'Edit not yet implemented.';

  @override
  String get settingsGroupTitle => 'Group +';

  @override
  String get settingsItemSaved => 'Saved';

  @override
  String get settingsItemArchive => 'Archive';

  @override
  String get settingsItemActivity => 'Your Activity';

  @override
  String get settingsItemNotifications => 'Notifications';

  @override
  String get settingsItemTimeManagement => 'Time Management';

  @override
  String get settingsItemLogout => 'Logout';

  @override
  String get homeScreenNoProjects => 'No projects yet! Start by adding one.';

  @override
  String get homeScreenRetryButton => 'Retry';

  @override
  String get homeScreenAddProjectTooltip => 'Add Project';

  @override
  String get homeScreenRefreshTooltip => 'Refresh Projects';

  @override
  String get createProjectTitle => 'Create Project';

  @override
  String get createProjectErrorUserNotLoggedIn => 'User not logged in. Cannot create project.';

  @override
  String get projectFormFieldNameLabel => 'Project Name';

  @override
  String get projectFormFieldNameDesc => 'Enter a descriptive name for your project.';

  @override
  String get projectFormFieldNameHint => 'e.g., Summer Vacation in Italy';

  @override
  String get projectFormFieldRequiredError => 'This field is required.';

  @override
  String get projectFormFieldNameMinLengthError => 'Name must be at least 3 characters.';

  @override
  String get projectFormFieldFromLabel => 'From';

  @override
  String get projectFormFieldFromHint => 'Select start date';

  @override
  String get projectFormFieldTillLabel => 'Till';

  @override
  String get projectFormFieldTillHint => 'Select end date';

  @override
  String get projectFormFieldDescLabel => 'Description';

  @override
  String get projectFormFieldDescDesc => 'Add some details about your project plans.';

  @override
  String get projectFormFieldDescHint => 'Describe your project...';

  @override
  String get projectFormFieldDescMaxLengthError => 'Description too long (max 500 chars).';

  @override
  String get projectFormFieldLocationLabel => 'Location';

  @override
  String get projectFormFieldLocationDesc => 'Where is this project taking place?';

  @override
  String get projectFormFieldLocationHint => 'Start typing a city or place...';

  @override
  String get projectFormFieldBudgetLabel => 'Budget (\$)';

  @override
  String get projectFormFieldBudgetDesc => 'Estimated budget for the project.';

  @override
  String get projectFormFieldBudgetHint => 'e.g., 2000';

  @override
  String get projectFormFieldNumericError => 'Please enter a valid number.';

  @override
  String get projectFormFieldBudgetMinError => 'Budget must be a positive number.';

  @override
  String get projectDetailInfoLabel => 'Info';

  @override
  String get projectDetailExpensesLabel => 'Expenses';

  @override
  String get projectDetailParticipantsLabel => 'Participants';

  @override
  String get projectDetailImagesLabel => 'Images';

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get galleryEmptyState => 'No images in gallery.';

  @override
  String galleryImageCount(String index, String total) {
    return '$index of $total';
  }

  @override
  String get galleryImageErrorLoading => 'Could not load image';

  @override
  String get galleryScanInProgressError => 'Scan already in progress for another image.';

  @override
  String get galleryScanInitiatedSnackbar => 'Scan initiated...';

  @override
  String galleryScanErrorSnackbar(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get deleteImageConfirmTitle => 'Delete Image?';

  @override
  String get deleteImageConfirmDesc => 'Are you sure you want to delete this image?';

  @override
  String get imageDeleteSuccessSnackbar => 'Image deleted successfully.';

  @override
  String get imageDeleteErrorSnackbar => 'Failed to delete image.';

  @override
  String galleryDetailTitle(int index, int total) {
    return 'Image $index of $total';
  }

  @override
  String get downloadingImage => 'Downloading image...';

  @override
  String get downloadComplete => 'Download complete.';

  @override
  String get downloadFailed => 'Download failed.';

  @override
  String get scanButtonTooltip => 'Scan for Text';

  @override
  String get deleteButtonTooltip => 'Delete Image';

  @override
  String get deleteImage => 'Delete image';

  @override
  String get imageLoadError => 'Error loading image';

  @override
  String get imageStatusNotScanned => 'Not Scanned';

  @override
  String get imageStatusProcessing => 'Processing';

  @override
  String get imageStatusNoText => 'No Text Found';

  @override
  String get imageStatusText => 'Text Found';

  @override
  String get imageStatusInvoice => 'Invoice Found';

  @override
  String get imageStatusError => 'Error';

  @override
  String get groupedButtonInfoTooltip => 'View Info';

  @override
  String get groupedButtonRemoveFavoriteTooltip => 'Remove from Favorites';

  @override
  String get groupedButtonAddFavoriteTooltip => 'Add to Favorites';

  @override
  String get groupedButtonOptionsTooltip => 'View Options';

  @override
  String get addImageFromGalleryTooltip => 'Add image from gallery';

  @override
  String get appName => 'TravelMouse';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'Enter your email address';

  @override
  String get emailValidationError => 'Please enter a valid email address.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordValidationError => 'Password must be at least 6 characters long.';

  @override
  String get signInButton => 'Sign In';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get signInPrompt => 'Already have an account? Sign In';

  @override
  String get signUpPrompt => 'Don\'t have an account? Sign Up';

  @override
  String get forgotPasswordButton => 'Forgot Password?';

  @override
  String get yourProjectsTitle => 'Your Projects';

  @override
  String get projectSettingsTitle => 'Project Settings';

  @override
  String get projectDeleteLabel => 'Delete Project';

  @override
  String get projectDeleteConfirmTitle => 'Confirm Deletion';

  @override
  String projectDeleteConfirmDesc(String projectTitle) {
    return 'Are you sure you want to delete the project \'$projectTitle\'? This action cannot be undone.';
  }

  @override
  String projectDeleteSuccess(String projectTitle) {
    return 'Project \'$projectTitle\' deleted successfully.';
  }

  @override
  String get deletingProgress => 'Deleting...';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deleteButton => 'Delete';

  @override
  String get invoiceTotalLabel => 'Total';

  @override
  String get invoicePaidLabel => 'Paid';

  @override
  String get invoiceRemainingLabel => 'Remaining';

  @override
  String get invoiceShareTooltip => 'Share Invoice';

  @override
  String get invoiceScanTooltip => 'Scan Text';

  @override
  String get invoiceDeleteTooltip => 'Delete Invoice';

  @override
  String get verifyEmailTitle => 'Verify Your Email';

  @override
  String get verificationEmailSentTitle => 'Verification Email Sent!';

  @override
  String get checkYourEmailInstruction => 'Please check your inbox (and spam folder!) for a verification link to complete your registration.';

  @override
  String get resendEmailButton => 'Resend Verification Email';

  @override
  String get verificationEmailResent => 'Verification email resent.';

  @override
  String get errorResendingVerification => 'Error Resending Verification';

  @override
  String get appTitle => 'Travel';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginButtonLabel => 'Login';

  @override
  String get loginErrorInvalidEmail => 'Invalid email address';

  @override
  String get loginErrorEmptyPassword => 'Password cannot be empty';

  @override
  String get loginErrorAuthFailed => 'Authentication failed';

  @override
  String get registerTitle => 'Register';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerConfirmPasswordLabel => 'Confirm Password';

  @override
  String get registerButtonLabel => 'Register';

  @override
  String get registerErrorPasswordMismatch => 'Passwords do not match';

  @override
  String get registerErrorWeakPassword => 'Password is too weak';

  @override
  String get registerErrorEmailInUse => 'Email is already in use';

  @override
  String get homeTitle => 'My Projects';

  @override
  String get homeEmptyState => 'No projects yet';

  @override
  String get homeAddProjectTooltip => 'Add new project';

  @override
  String get projectTitleLabel => 'Project Title';

  @override
  String get projectDescriptionLabel => 'Description';

  @override
  String get projectStartDateLabel => 'Start Date';

  @override
  String get projectEndDateLabel => 'End Date';

  @override
  String get projectLocationLabel => 'Location';

  @override
  String get projectCreateTitle => 'New Project';

  @override
  String get projectCreateButtonLabel => 'Create Project';

  @override
  String get projectEditTitle => 'Edit Project';

  @override
  String get projectEditButtonLabel => 'Save Changes';

  @override
  String get projectDeleteConfirmMessage => 'Are you sure you want to delete this project? This action cannot be undone.';

  @override
  String get projectNotFound => 'Project not found';

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get errorNetworkGeneric => 'Network error occurred';

  @override
  String get errorInvalidInput => 'Invalid input';

  @override
  String get invoiceCaptureTitle => 'Invoices';

  @override
  String get invoiceCaptureEmptyState => 'No invoices captured yet.';

  @override
  String invoiceCaptureImageCount(String index, String total) {
    return 'Image $index of $total';
  }

  @override
  String get invoiceCaptureImageErrorLoading => 'Could not load image';

  @override
  String get invoiceCaptureScanInProgressError => 'Scan already in progress for another invoice.';

  @override
  String get invoiceCaptureScanInitiatedSnackbar => 'Scan initiated...';

  @override
  String invoiceCaptureScanErrorSnackbar(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get deleteInvoiceConfirmTitle => 'Delete Invoice?';

  @override
  String get deleteInvoiceConfirmDesc => 'Are you sure you want to delete this invoice?';

  @override
  String get invoiceDeleteSuccessSnackbar => 'Invoice deleted successfully.';

  @override
  String get invoiceDeleteErrorSnackbar => 'Failed to delete invoice.';

  @override
  String invoiceCaptureDetailTitle(int index, int total) {
    return 'Invoice $index of $total';
  }

  @override
  String get downloadingInvoice => 'Downloading invoice...';

  @override
  String get addInvoiceFromGalleryTooltip => 'Add invoice from gallery';

  @override
  String get invoiceImages => 'Project Images';

  @override
  String get noImagesYet => 'No images yet';

  @override
  String get addImage => 'Add Image';

  @override
  String get projectSaveSuccess => 'Project saved successfully';

  @override
  String get save => 'Save';
}
