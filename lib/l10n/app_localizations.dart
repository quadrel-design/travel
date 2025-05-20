import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @unexpectedErrorDesc.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get unexpectedErrorDesc;

  /// No description provided for @logoutErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout Error'**
  String get logoutErrorTitle;

  /// No description provided for @logoutUnexpectedErrorDesc.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred during logout.'**
  String get logoutUnexpectedErrorDesc;

  /// No description provided for @missingInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing Information'**
  String get missingInfoTitle;

  /// No description provided for @enterEmailFirstDesc.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address first.'**
  String get enterEmailFirstDesc;

  /// No description provided for @passwordResetEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Your Email'**
  String get passwordResetEmailSentTitle;

  /// No description provided for @passwordResetEmailSentDesc.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent! Please check your inbox.'**
  String get passwordResetEmailSentDesc;

  /// No description provided for @passwordResetFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset email. Please try again.'**
  String get passwordResetFailedDesc;

  /// No description provided for @authErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Error'**
  String get authErrorTitle;

  /// No description provided for @signInFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In Failed'**
  String get signInFailedTitle;

  /// No description provided for @emailRegisteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Registered'**
  String get emailRegisteredTitle;

  /// No description provided for @emailRegisteredDesc.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please sign in instead.'**
  String get emailRegisteredDesc;

  /// No description provided for @emailNotConfirmedDesc.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before signing in.'**
  String get emailNotConfirmedDesc;

  /// No description provided for @invalidLoginCredentialsDesc.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get invalidLoginCredentialsDesc;

  /// No description provided for @signUpSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Up Successful'**
  String get signUpSuccessTitle;

  /// No description provided for @signUpSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Please check your email to confirm.'**
  String get signUpSuccessDesc;

  /// No description provided for @verificationErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Error'**
  String get verificationErrorTitle;

  /// No description provided for @verificationErrorDesc.
  ///
  /// In en, this message translates to:
  /// **'Could not verify email. Please try again.'**
  String get verificationErrorDesc;

  /// No description provided for @projectSaveErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Error'**
  String get projectSaveErrorTitle;

  /// No description provided for @projectSaveSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Saved'**
  String get projectSaveSuccessTitle;

  /// No description provided for @projectSaveSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Your new project has been created.'**
  String get projectSaveSuccessDesc;

  /// No description provided for @projectSaveMissingInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields, including dates.'**
  String get projectSaveMissingInfoDesc;

  /// No description provided for @projectSaveInvalidDateRange.
  ///
  /// In en, this message translates to:
  /// **'End date cannot be before start date.'**
  String get projectSaveInvalidDateRange;

  /// No description provided for @projectDeleteSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Project deleted.'**
  String get projectDeleteSuccessDesc;

  /// Error message when deleting project, includes details
  ///
  /// In en, this message translates to:
  /// **'Failed to delete project: {error}'**
  String projectDeleteErrorDesc(Object error);

  /// No description provided for @invoiceImageLoadErrorDesc.
  ///
  /// In en, this message translates to:
  /// **'Failed to load images'**
  String get invoiceImageLoadErrorDesc;

  /// No description provided for @editNotImplementedDesc.
  ///
  /// In en, this message translates to:
  /// **'Edit not yet implemented.'**
  String get editNotImplementedDesc;

  /// No description provided for @settingsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Group +'**
  String get settingsGroupTitle;

  /// No description provided for @settingsItemSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settingsItemSaved;

  /// No description provided for @settingsItemArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get settingsItemArchive;

  /// No description provided for @settingsItemActivity.
  ///
  /// In en, this message translates to:
  /// **'Your Activity'**
  String get settingsItemActivity;

  /// No description provided for @settingsItemNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsItemNotifications;

  /// No description provided for @settingsItemTimeManagement.
  ///
  /// In en, this message translates to:
  /// **'Time Management'**
  String get settingsItemTimeManagement;

  /// No description provided for @settingsItemLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsItemLogout;

  /// No description provided for @homeScreenNoProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet! Start by adding one.'**
  String get homeScreenNoProjects;

  /// No description provided for @homeScreenRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeScreenRetryButton;

  /// No description provided for @homeScreenAddProjectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get homeScreenAddProjectTooltip;

  /// No description provided for @homeScreenRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Projects'**
  String get homeScreenRefreshTooltip;

  /// No description provided for @createProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get createProjectTitle;

  /// No description provided for @createProjectErrorUserNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in. Cannot create project.'**
  String get createProjectErrorUserNotLoggedIn;

  /// No description provided for @projectFormFieldNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get projectFormFieldNameLabel;

  /// No description provided for @projectFormFieldNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter a descriptive name for your project.'**
  String get projectFormFieldNameDesc;

  /// No description provided for @projectFormFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Summer Vacation in Italy'**
  String get projectFormFieldNameHint;

  /// No description provided for @projectFormFieldRequiredError.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get projectFormFieldRequiredError;

  /// No description provided for @projectFormFieldNameMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 3 characters.'**
  String get projectFormFieldNameMinLengthError;

  /// No description provided for @projectFormFieldFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get projectFormFieldFromLabel;

  /// No description provided for @projectFormFieldFromHint.
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get projectFormFieldFromHint;

  /// No description provided for @projectFormFieldTillLabel.
  ///
  /// In en, this message translates to:
  /// **'Till'**
  String get projectFormFieldTillLabel;

  /// No description provided for @projectFormFieldTillHint.
  ///
  /// In en, this message translates to:
  /// **'Select end date'**
  String get projectFormFieldTillHint;

  /// No description provided for @projectFormFieldDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get projectFormFieldDescLabel;

  /// No description provided for @projectFormFieldDescDesc.
  ///
  /// In en, this message translates to:
  /// **'Add some details about your project plans.'**
  String get projectFormFieldDescDesc;

  /// No description provided for @projectFormFieldDescHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your project...'**
  String get projectFormFieldDescHint;

  /// No description provided for @projectFormFieldDescMaxLengthError.
  ///
  /// In en, this message translates to:
  /// **'Description too long (max 500 chars).'**
  String get projectFormFieldDescMaxLengthError;

  /// No description provided for @projectFormFieldLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get projectFormFieldLocationLabel;

  /// No description provided for @projectFormFieldLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Where is this project taking place?'**
  String get projectFormFieldLocationDesc;

  /// No description provided for @projectFormFieldLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Start typing a city or place...'**
  String get projectFormFieldLocationHint;

  /// No description provided for @projectFormFieldBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget (\$)'**
  String get projectFormFieldBudgetLabel;

  /// No description provided for @projectFormFieldBudgetDesc.
  ///
  /// In en, this message translates to:
  /// **'Estimated budget for the project.'**
  String get projectFormFieldBudgetDesc;

  /// No description provided for @projectFormFieldBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 2000'**
  String get projectFormFieldBudgetHint;

  /// No description provided for @projectFormFieldNumericError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number.'**
  String get projectFormFieldNumericError;

  /// No description provided for @projectFormFieldBudgetMinError.
  ///
  /// In en, this message translates to:
  /// **'Budget must be a positive number.'**
  String get projectFormFieldBudgetMinError;

  /// Label for the Info tab in project details
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get projectDetailInfoLabel;

  /// Label for the Expenses tab in project details
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get projectDetailExpensesLabel;

  /// Label for the Participants tab in project details
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get projectDetailParticipantsLabel;

  /// Label for the Images tab in project details
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get projectDetailImagesLabel;

  /// Title for the image gallery page
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryTitle;

  /// Message shown when the gallery has no images
  ///
  /// In en, this message translates to:
  /// **'No images in gallery.'**
  String get galleryEmptyState;

  /// Title showing the current image index and total count in the gallery page view
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String galleryImageCount(String index, String total);

  /// Error message when a gallery image fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get galleryImageErrorLoading;

  /// Error shown if user tries to scan while another scan is running or if it's already done.
  ///
  /// In en, this message translates to:
  /// **'Scan already in progress for another image.'**
  String get galleryScanInProgressError;

  /// Snackbar message indicating the image scan has started.
  ///
  /// In en, this message translates to:
  /// **'Scan initiated...'**
  String get galleryScanInitiatedSnackbar;

  /// Snackbar message indicating the image scan failed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String galleryScanErrorSnackbar(String error);

  /// Title for the image deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Image?'**
  String get deleteImageConfirmTitle;

  /// Content text for the image deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this image?'**
  String get deleteImageConfirmDesc;

  /// Snackbar message shown after successful image deletion
  ///
  /// In en, this message translates to:
  /// **'Image deleted successfully.'**
  String get imageDeleteSuccessSnackbar;

  /// Snackbar message shown after failed image deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete image.'**
  String get imageDeleteErrorSnackbar;

  /// Title for the image detail view showing current index and total count
  ///
  /// In en, this message translates to:
  /// **'Image {index} of {total}'**
  String galleryDetailTitle(int index, int total);

  /// Snackbar message when image download starts
  ///
  /// In en, this message translates to:
  /// **'Downloading image...'**
  String get downloadingImage;

  /// Snackbar message when image download finishes successfully
  ///
  /// In en, this message translates to:
  /// **'Download complete.'**
  String get downloadComplete;

  /// Snackbar message when image download fails
  ///
  /// In en, this message translates to:
  /// **'Download failed.'**
  String get downloadFailed;

  /// Tooltip for the button that triggers text scanning
  ///
  /// In en, this message translates to:
  /// **'Scan for Text'**
  String get scanButtonTooltip;

  /// Tooltip for the button that deletes the current image
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get deleteButtonTooltip;

  /// Label for delete image button
  ///
  /// In en, this message translates to:
  /// **'Delete image'**
  String get deleteImage;

  /// Error message when image failed to load
  ///
  /// In en, this message translates to:
  /// **'Error loading image'**
  String get imageLoadError;

  /// Status label for an image that hasn't been scanned for text yet
  ///
  /// In en, this message translates to:
  /// **'Not Scanned'**
  String get imageStatusNotScanned;

  /// Status label for an image that is currently being processed
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get imageStatusProcessing;

  /// Status label for an image processed but no text was found
  ///
  /// In en, this message translates to:
  /// **'No Text Found'**
  String get imageStatusNoText;

  /// Status label for an image where text was found but not identified as an invoice
  ///
  /// In en, this message translates to:
  /// **'Text Found'**
  String get imageStatusText;

  /// Status label for an image that was identified as an invoice
  ///
  /// In en, this message translates to:
  /// **'Invoice Found'**
  String get imageStatusInvoice;

  /// Status label for an image where processing resulted in an error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get imageStatusError;

  /// Tooltip for the info button in the grouped actions
  ///
  /// In en, this message translates to:
  /// **'View Info'**
  String get groupedButtonInfoTooltip;

  /// Tooltip for the favorite button (when active) in the grouped actions
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get groupedButtonRemoveFavoriteTooltip;

  /// Tooltip for the favorite button (when inactive) in the grouped actions
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get groupedButtonAddFavoriteTooltip;

  /// Tooltip for the options/list/tune button in the grouped actions
  ///
  /// In en, this message translates to:
  /// **'View Options'**
  String get groupedButtonOptionsTooltip;

  /// Tooltip for the FAB to add an image from the device gallery
  ///
  /// In en, this message translates to:
  /// **'Add image from gallery'**
  String get addImageFromGalleryTooltip;

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'TravelMouse'**
  String get appName;

  /// Label for the email input field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Hint text for the email input field
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get emailHint;

  /// Error message for invalid email format
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get emailValidationError;

  /// Label for the password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Hint text for the password input field
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Error message for invalid password length
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters long.'**
  String get passwordValidationError;

  /// Text for the sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// Text for the sign up button
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// Prompt text to switch to sign in mode
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get signInPrompt;

  /// Prompt text to switch to sign up mode
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get signUpPrompt;

  /// Text for the forgot password button
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordButton;

  /// Title for the home screen displaying the list of projects
  ///
  /// In en, this message translates to:
  /// **'Your Projects'**
  String get yourProjectsTitle;

  /// Title for the project settings screen
  ///
  /// In en, this message translates to:
  /// **'Project Settings'**
  String get projectSettingsTitle;

  /// Label for the delete project action
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get projectDeleteLabel;

  /// Title for the delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get projectDeleteConfirmTitle;

  /// Confirmation message asking the user to confirm project deletion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the project \'{projectTitle}\'? This action cannot be undone.'**
  String projectDeleteConfirmDesc(String projectTitle);

  /// Success message shown after deleting a project.
  ///
  /// In en, this message translates to:
  /// **'Project \'{projectTitle}\' deleted successfully.'**
  String projectDeleteSuccess(String projectTitle);

  /// Text indicating deletion is in progress
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deletingProgress;

  /// Generic cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Generic delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// Label for the total amount in the invoice summary bar
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceTotalLabel;

  /// Label for the paid amount in the invoice summary bar
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoicePaidLabel;

  /// Label for the remaining amount in the invoice summary bar
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get invoiceRemainingLabel;

  /// Tooltip for the share button on the invoice bottom bar
  ///
  /// In en, this message translates to:
  /// **'Share Invoice'**
  String get invoiceShareTooltip;

  /// Tooltip for the scan button on the invoice bottom bar
  ///
  /// In en, this message translates to:
  /// **'Scan Text'**
  String get invoiceScanTooltip;

  /// Tooltip for the delete button on the invoice bottom bar
  ///
  /// In en, this message translates to:
  /// **'Delete Invoice'**
  String get invoiceDeleteTooltip;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyEmailTitle;

  /// No description provided for @verificationEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Email Sent!'**
  String get verificationEmailSentTitle;

  /// No description provided for @checkYourEmailInstruction.
  ///
  /// In en, this message translates to:
  /// **'Please check your inbox (and spam folder!) for a verification link to complete your registration.'**
  String get checkYourEmailInstruction;

  /// No description provided for @resendEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Resend Verification Email'**
  String get resendEmailButton;

  /// No description provided for @verificationEmailResent.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent.'**
  String get verificationEmailResent;

  /// No description provided for @errorResendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Error Resending Verification'**
  String get errorResendingVerification;

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get appTitle;

  /// Title for the login page
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// Label for the email input field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// Label for the password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// Label for the login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButtonLabel;

  /// Error message shown when an invalid email is entered
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get loginErrorInvalidEmail;

  /// Error message shown when password is empty
  ///
  /// In en, this message translates to:
  /// **'Password cannot be empty'**
  String get loginErrorEmptyPassword;

  /// Error message shown when login fails
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get loginErrorAuthFailed;

  /// Title for the registration page
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// Label for the email input field in registration
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerEmailLabel;

  /// Label for the password input field in registration
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPasswordLabel;

  /// Label for the confirm password input field
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get registerConfirmPasswordLabel;

  /// Label for the register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButtonLabel;

  /// Error message shown when passwords don't match
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerErrorPasswordMismatch;

  /// Error message shown when password is too weak
  ///
  /// In en, this message translates to:
  /// **'Password is too weak'**
  String get registerErrorWeakPassword;

  /// Error message shown when email is already registered
  ///
  /// In en, this message translates to:
  /// **'Email is already in use'**
  String get registerErrorEmailInUse;

  /// Title for the home page showing projects
  ///
  /// In en, this message translates to:
  /// **'My Projects'**
  String get homeTitle;

  /// Message shown when there are no projects
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get homeEmptyState;

  /// Tooltip for the add project FAB
  ///
  /// In en, this message translates to:
  /// **'Add new project'**
  String get homeAddProjectTooltip;

  /// No description provided for @projectTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Project Title'**
  String get projectTitleLabel;

  /// No description provided for @projectDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get projectDescriptionLabel;

  /// No description provided for @projectStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get projectStartDateLabel;

  /// No description provided for @projectEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get projectEndDateLabel;

  /// No description provided for @projectLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get projectLocationLabel;

  /// No description provided for @projectCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get projectCreateTitle;

  /// No description provided for @projectCreateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get projectCreateButtonLabel;

  /// No description provided for @projectEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get projectEditTitle;

  /// No description provided for @projectEditButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get projectEditButtonLabel;

  /// No description provided for @projectDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this project? This action cannot be undone.'**
  String get projectDeleteConfirmMessage;

  /// No description provided for @projectNotFound.
  ///
  /// In en, this message translates to:
  /// **'Project not found'**
  String get projectNotFound;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorGeneric;

  /// Generic network error message
  ///
  /// In en, this message translates to:
  /// **'Network error occurred'**
  String get errorNetworkGeneric;

  /// Generic invalid input error message
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get errorInvalidInput;

  /// Title for the invoice capture page
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoiceCaptureTitle;

  /// Message shown when there are no invoices
  ///
  /// In en, this message translates to:
  /// **'No invoices captured yet.'**
  String get invoiceCaptureEmptyState;

  /// Title showing the current image index and total count in the invoice capture view
  ///
  /// In en, this message translates to:
  /// **'Image {index} of {total}'**
  String invoiceCaptureImageCount(String index, String total);

  /// Error message when an invoice image fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get invoiceCaptureImageErrorLoading;

  /// Error shown if user tries to scan while another scan is running or if it's already done.
  ///
  /// In en, this message translates to:
  /// **'Scan already in progress for another invoice.'**
  String get invoiceCaptureScanInProgressError;

  /// Snackbar message indicating the invoice scan has started.
  ///
  /// In en, this message translates to:
  /// **'Scan initiated...'**
  String get invoiceCaptureScanInitiatedSnackbar;

  /// Snackbar message indicating the invoice scan failed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String invoiceCaptureScanErrorSnackbar(String error);

  /// Title for the invoice deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Invoice?'**
  String get deleteInvoiceConfirmTitle;

  /// Content text for the invoice deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this invoice?'**
  String get deleteInvoiceConfirmDesc;

  /// Snackbar message shown after successful invoice deletion
  ///
  /// In en, this message translates to:
  /// **'Invoice deleted successfully.'**
  String get invoiceDeleteSuccessSnackbar;

  /// Snackbar message shown after failed invoice deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete invoice.'**
  String get invoiceDeleteErrorSnackbar;

  /// Title for the invoice detail view showing current index and total count
  ///
  /// In en, this message translates to:
  /// **'Invoice {index} of {total}'**
  String invoiceCaptureDetailTitle(int index, int total);

  /// Message shown while downloading an invoice image
  ///
  /// In en, this message translates to:
  /// **'Downloading invoice...'**
  String get downloadingInvoice;

  /// Tooltip for the FAB to add an invoice from the device gallery
  ///
  /// In en, this message translates to:
  /// **'Add invoice from gallery'**
  String get addInvoiceFromGalleryTooltip;

  /// Title for the project images section
  ///
  /// In en, this message translates to:
  /// **'Project Images'**
  String get invoiceImages;

  /// Message shown when there are no images in a project
  ///
  /// In en, this message translates to:
  /// **'No images yet'**
  String get noImagesYet;

  /// Label for the add image button
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get addImage;

  /// Message shown when a project is saved successfully
  ///
  /// In en, this message translates to:
  /// **'Project saved successfully'**
  String get projectSaveSuccess;

  /// Label for save buttons
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
