import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn')
  ];

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get navRecords;

  /// No description provided for @navAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get navAi;

  /// No description provided for @navMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get navMedications;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get navAiAssistant;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CurecordAI'**
  String get appName;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsSectionAccount;

  /// No description provided for @settingsProfileInformation.
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get settingsProfileInformation;

  /// No description provided for @settingsProfileInformationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your medical details'**
  String get settingsProfileInformationSubtitle;

  /// No description provided for @settingsFamilyManagement.
  ///
  /// In en, this message translates to:
  /// **'Family Management'**
  String get settingsFamilyManagement;

  /// No description provided for @settingsFamilyManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or edit family members'**
  String get settingsFamilyManagementSubtitle;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'English / Urdu / Roman Urdu'**
  String get settingsLanguageSubtitle;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langUrdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get langUrdu;

  /// No description provided for @langRomanUrdu.
  ///
  /// In en, this message translates to:
  /// **'Roman Urdu'**
  String get langRomanUrdu;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeCurrentDark.
  ///
  /// In en, this message translates to:
  /// **'Current: Dark Mode'**
  String get settingsThemeCurrentDark;

  /// No description provided for @settingsThemeCurrentLight.
  ///
  /// In en, this message translates to:
  /// **'Current: Light Mode'**
  String get settingsThemeCurrentLight;

  /// No description provided for @settingsSectionMedical.
  ///
  /// In en, this message translates to:
  /// **'MEDICAL'**
  String get settingsSectionMedical;

  /// No description provided for @settingsEmergencyCard.
  ///
  /// In en, this message translates to:
  /// **'Emergency Card Settings'**
  String get settingsEmergencyCard;

  /// No description provided for @settingsEmergencyCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SOS contacts & Medical ID'**
  String get settingsEmergencyCardSubtitle;

  /// No description provided for @settingsSectionPrivacyData.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & DATA'**
  String get settingsSectionPrivacyData;

  /// No description provided for @settingsDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get settingsDataPrivacy;

  /// No description provided for @settingsDataPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle your health data'**
  String get settingsDataPrivacySubtitle;

  /// No description provided for @settingsExportData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get settingsExportData;

  /// No description provided for @settingsExportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download a copy of your health data'**
  String get settingsExportDataSubtitle;

  /// No description provided for @settingsConsentManagement.
  ///
  /// In en, this message translates to:
  /// **'Consent Management'**
  String get settingsConsentManagement;

  /// No description provided for @settingsConsentManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review & manage your data consents'**
  String get settingsConsentManagementSubtitle;

  /// No description provided for @settingsLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogOut;

  /// No description provided for @settingsLogOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogOutConfirmTitle;

  /// No description provided for @settingsLogOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get settingsLogOutConfirmBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get commonErrorOccurred;

  /// No description provided for @settingsExportDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get settingsExportDataTitle;

  /// No description provided for @settingsExportDataBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll prepare a full copy of your health data. This may take up to 30 days. You\'ll be notified when it\'s ready.'**
  String get settingsExportDataBody;

  /// No description provided for @settingsRequestExport.
  ///
  /// In en, this message translates to:
  /// **'Request Export'**
  String get settingsRequestExport;

  /// No description provided for @settingsExportRequestedSnack.
  ///
  /// In en, this message translates to:
  /// **'Export requested. You\'ll be notified when ready.'**
  String get settingsExportRequestedSnack;

  /// No description provided for @settingsExportInProgressError.
  ///
  /// In en, this message translates to:
  /// **'An export is already in progress.'**
  String get settingsExportInProgressError;

  /// No description provided for @settingsExportFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to request export. Please try again.'**
  String get settingsExportFailedError;

  /// No description provided for @settingsAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload avatar'**
  String get settingsAvatarUploadFailed;

  /// No description provided for @settingsManagedByYou.
  ///
  /// In en, this message translates to:
  /// **'Managed by you'**
  String get settingsManagedByYou;

  /// No description provided for @settingsProfileCompletion.
  ///
  /// In en, this message translates to:
  /// **'Profile Completion'**
  String get settingsProfileCompletion;

  /// No description provided for @settingsProfileCompletionHint.
  ///
  /// In en, this message translates to:
  /// **'Complete your medical history to help doctors provide better care.'**
  String get settingsProfileCompletionHint;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfService;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'CurecordAI v1.0.0'**
  String get settingsAppVersion;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeBack;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to view your medical records.'**
  String get authLoginSubtitle;

  /// No description provided for @authContinueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get authContinueWithPhone;

  /// No description provided for @authContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get authContinueWithEmail;

  /// No description provided for @authNewToApp.
  ///
  /// In en, this message translates to:
  /// **'New to CurecordAI? '**
  String get authNewToApp;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your Account'**
  String get authCreateAccountTitle;

  /// No description provided for @authCreateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up to start managing your medical records.'**
  String get authCreateAccountSubtitle;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authAlreadyHaveAccount;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// No description provided for @otpVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Number'**
  String get otpVerifyTitle;

  /// No description provided for @otpSubtitlePrefix.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to '**
  String get otpSubtitlePrefix;

  /// No description provided for @otpResendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in '**
  String get otpResendCodeIn;

  /// No description provided for @otpResendSms.
  ///
  /// In en, this message translates to:
  /// **'Resend SMS'**
  String get otpResendSms;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to '**
  String get otpTermsPrefix;

  /// No description provided for @otpTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms & Privacy Policy'**
  String get otpTermsLink;

  /// No description provided for @otpIncompleteError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the complete 6-digit code'**
  String get otpIncompleteError;

  /// No description provided for @otpAlreadyRegisteredError.
  ///
  /// In en, this message translates to:
  /// **'This number is already registered. Please log in.'**
  String get otpAlreadyRegisteredError;

  /// No description provided for @otpNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'No account found for this number. Please sign up.'**
  String get otpNotFoundError;

  /// No description provided for @otpInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get otpInvalidError;

  /// No description provided for @otpResendFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend OTP. Please try again.'**
  String get otpResendFailedError;

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get homeRecentActivity;

  /// No description provided for @homeUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get homeUploadDocument;

  /// No description provided for @homeUploadDocumentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reports & Prescriptions'**
  String get homeUploadDocumentSubtitle;

  /// No description provided for @homeAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get homeAskAi;

  /// No description provided for @homeAskAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instant Medical Insights'**
  String get homeAskAiSubtitle;

  /// No description provided for @homeGenerateQr.
  ///
  /// In en, this message translates to:
  /// **'Generate QR'**
  String get homeGenerateQr;

  /// No description provided for @homeGenerateQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Profile Share'**
  String get homeGenerateQrSubtitle;

  /// No description provided for @homeViewSummary.
  ///
  /// In en, this message translates to:
  /// **'View Summary'**
  String get homeViewSummary;

  /// No description provided for @homeViewSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Health Record Preview'**
  String get homeViewSummarySubtitle;

  /// No description provided for @homeMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get homeMedications;

  /// No description provided for @homeMedicationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders & Schedules'**
  String get homeMedicationsSubtitle;

  /// No description provided for @homeDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get homeDetected;

  /// No description provided for @homeMedicationsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get homeMedicationsActive;

  /// No description provided for @homeYourDashboard.
  ///
  /// In en, this message translates to:
  /// **'Your Dashboard'**
  String get homeYourDashboard;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get homeGreetingNight;

  /// No description provided for @homeNudgeUnreadInstructionMessage.
  ///
  /// In en, this message translates to:
  /// **'Your doctor left new instructions.'**
  String get homeNudgeUnreadInstructionMessage;

  /// No description provided for @homeNudgeUnreadInstructionButton.
  ///
  /// In en, this message translates to:
  /// **'View instructions'**
  String get homeNudgeUnreadInstructionButton;

  /// No description provided for @homeNudgeNoDocumentsMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload your first record to get started.'**
  String get homeNudgeNoDocumentsMessage;

  /// No description provided for @homeNudgeNoDocumentsButton.
  ///
  /// In en, this message translates to:
  /// **'Upload document'**
  String get homeNudgeNoDocumentsButton;

  /// No description provided for @homeNudgeNoMedicationsMessage.
  ///
  /// In en, this message translates to:
  /// **'0 active medications. Add yours to stay on track.'**
  String get homeNudgeNoMedicationsMessage;

  /// No description provided for @homeNudgeNoMedicationsButton.
  ///
  /// In en, this message translates to:
  /// **'Add medication'**
  String get homeNudgeNoMedicationsButton;

  /// No description provided for @homeRotatingTip1.
  ///
  /// In en, this message translates to:
  /// **'Try asking the AI assistant to explain any report in plain language.'**
  String get homeRotatingTip1;

  /// No description provided for @homeRotatingTip2.
  ///
  /// In en, this message translates to:
  /// **'Your records are only visible to you and doctors you choose to share with.'**
  String get homeRotatingTip2;

  /// No description provided for @homeRotatingTip3.
  ///
  /// In en, this message translates to:
  /// **'You have kept your records organized, nice work staying on top of things.'**
  String get homeRotatingTip3;

  /// No description provided for @homeTotalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Total Documents'**
  String get homeTotalDocuments;

  /// No description provided for @homeUploadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get homeUploadedLabel;

  /// No description provided for @homeActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get homeActiveLabel;

  /// No description provided for @homeNoMedicationsYet.
  ///
  /// In en, this message translates to:
  /// **'None added yet'**
  String get homeNoMedicationsYet;

  /// No description provided for @homeAddMedicationsHint.
  ///
  /// In en, this message translates to:
  /// **'Add medications to track refills and interactions.'**
  String get homeAddMedicationsHint;

  /// No description provided for @homeMedicationsReviewedAgo.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {time} ago'**
  String homeMedicationsReviewedAgo(String time);

  /// No description provided for @homeActiveAllergiesAlert.
  ///
  /// In en, this message translates to:
  /// **'You have active allergies'**
  String get homeActiveAllergiesAlert;

  /// No description provided for @homeViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get homeViewDetails;

  /// No description provided for @homeRecentDocuments.
  ///
  /// In en, this message translates to:
  /// **'Recent Documents'**
  String get homeRecentDocuments;

  /// No description provided for @homeNoDocumentsMessage.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Upload your first prescription or lab report to get started.'**
  String get homeNoDocumentsMessage;

  /// No description provided for @homeRecentConversations.
  ///
  /// In en, this message translates to:
  /// **'Recent AI Conversations'**
  String get homeRecentConversations;

  /// No description provided for @homeOpenAssistant.
  ///
  /// In en, this message translates to:
  /// **'Open assistant'**
  String get homeOpenAssistant;

  /// No description provided for @homeNoConversationsMessage.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet. Ask the AI assistant a question about your health records.'**
  String get homeNoConversationsMessage;

  /// No description provided for @homeConversationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load recent conversations'**
  String get homeConversationsLoadFailed;

  /// No description provided for @homeMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String homeMessagesCount(int count);

  /// No description provided for @homeShareWithDoctor.
  ///
  /// In en, this message translates to:
  /// **'Share with Doctor'**
  String get homeShareWithDoctor;

  /// No description provided for @homeShareWithDoctorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Profile Share'**
  String get homeShareWithDoctorSubtitle;

  /// No description provided for @homeNewTag.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get homeNewTag;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeProfileCompletePrefix.
  ///
  /// In en, this message translates to:
  /// **'Your profile is '**
  String get homeProfileCompletePrefix;

  /// No description provided for @homeProfileCompleteSuffix.
  ///
  /// In en, this message translates to:
  /// **' complete. Finish the\nremaining details '**
  String get homeProfileCompleteSuffix;

  /// No description provided for @homeHereLink.
  ///
  /// In en, this message translates to:
  /// **'here'**
  String get homeHereLink;

  /// No description provided for @homeSwitchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get homeSwitchProfile;

  /// No description provided for @homeOwnerYou.
  ///
  /// In en, this message translates to:
  /// **'Owner · You'**
  String get homeOwnerYou;

  /// No description provided for @homeAddFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Add family member'**
  String get homeAddFamilyMember;

  /// No description provided for @homeNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get homeNoRecentActivity;

  /// No description provided for @homeMemberNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'{name} has no recent activity'**
  String homeMemberNoRecentActivity(String name);

  /// No description provided for @homeUploadFirstRecord.
  ///
  /// In en, this message translates to:
  /// **'Upload your first medical document to get started'**
  String get homeUploadFirstRecord;

  /// No description provided for @homeUploadRecord.
  ///
  /// In en, this message translates to:
  /// **'Upload Record'**
  String get homeUploadRecord;

  /// No description provided for @homeDefaultRecordType.
  ///
  /// In en, this message translates to:
  /// **'Medical Record'**
  String get homeDefaultRecordType;

  /// No description provided for @homeMemberDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Dashboard'**
  String homeMemberDashboardTitle(String name);

  /// No description provided for @homeOwnerHasAllergies.
  ///
  /// In en, this message translates to:
  /// **'You have active allergies'**
  String get homeOwnerHasAllergies;

  /// No description provided for @homeMemberHasAllergies.
  ///
  /// In en, this message translates to:
  /// **'{name} has active allergies'**
  String homeMemberHasAllergies(String name);

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoInternet;

  /// No description provided for @commonOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get commonOr;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get commonGetStarted;

  /// No description provided for @commonSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get commonSkipForNow;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @authIncorrectEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get authIncorrectEmailOrPassword;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get authGoogleSignInFailed;

  /// No description provided for @authEmailLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Login'**
  String get authEmailLoginTitle;

  /// No description provided for @authEmailLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your Email and Password to Continue'**
  String get authEmailLoginSubtitle;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get authSigningIn;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get authGoogle;

  /// No description provided for @authApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get authApple;

  /// No description provided for @authEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Email already registered. Please log in.'**
  String get authEmailAlreadyRegistered;

  /// No description provided for @authSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get authSignUpFailed;

  /// No description provided for @authSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please fill in your details to continue'**
  String get authSignupSubtitle;

  /// No description provided for @authSignUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUpButton;

  /// No description provided for @authPhoneLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Login'**
  String get authPhoneLoginTitle;

  /// No description provided for @authPhoneLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login with your phone number to access your health records'**
  String get authPhoneLoginSubtitle;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get authSendOtp;

  /// No description provided for @authPhoneAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Number already registered. Try logging in.'**
  String get authPhoneAlreadyRegistered;

  /// No description provided for @authPhoneSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a verification code.'**
  String get authPhoneSignupSubtitle;

  /// No description provided for @authCreateAccountLower.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccountLower;

  /// No description provided for @authPhoneVerifiedSetupProfile.
  ///
  /// In en, this message translates to:
  /// **'Your phone is verified. Let\'s set up your profile.'**
  String get authPhoneVerifiedSetupProfile;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccountButton;

  /// No description provided for @authTermsFooter.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms of Service\nand Privacy Policy'**
  String get authTermsFooter;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get authRegistrationFailed;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @hintEmail.
  ///
  /// In en, this message translates to:
  /// **'Your email address'**
  String get hintEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @hintPassword.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get hintPassword;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fieldFullName;

  /// No description provided for @hintFullName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get hintFullName;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get fieldConfirmPassword;

  /// No description provided for @hintConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get hintConfirmPassword;

  /// No description provided for @fieldPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get fieldPhoneNumber;

  /// No description provided for @hintPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get hintPhoneNumber;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get validationPasswordRequired;

  /// No description provided for @validationNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Full name must be at least 2 characters'**
  String get validationNameMinLength;

  /// No description provided for @validationPasswordMin8.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get validationPasswordMin8;

  /// No description provided for @validationPasswordUppercase.
  ///
  /// In en, this message translates to:
  /// **'Must contain at least 1 uppercase letter'**
  String get validationPasswordUppercase;

  /// No description provided for @validationPasswordNumber.
  ///
  /// In en, this message translates to:
  /// **'Must contain at least 1 number'**
  String get validationPasswordNumber;

  /// No description provided for @validationPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordsMismatch;

  /// No description provided for @validationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get validationPhoneRequired;

  /// No description provided for @validationFullNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name (at least 2 characters)'**
  String get validationFullNameMinLength;

  /// No description provided for @otpVerifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get otpVerifyEmailTitle;

  /// No description provided for @otpResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResendCode;

  /// No description provided for @otpSendFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Check your number and try again.'**
  String get otpSendFailedError;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your Health, Always With You'**
  String get splashTagline;

  /// No description provided for @successAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get successAllSet;

  /// No description provided for @successWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get successWelcomeBack;

  /// No description provided for @successNewUserBody.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created successfully.\nYour health journey starts now.'**
  String get successNewUserBody;

  /// No description provided for @successReturningUserBody.
  ///
  /// In en, this message translates to:
  /// **'You have successfully logged in.\nYour health records are ready.'**
  String get successReturningUserBody;

  /// No description provided for @successGoToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get successGoToDashboard;

  /// No description provided for @carousel1Title.
  ///
  /// In en, this message translates to:
  /// **'Store All Your\nMedical Records'**
  String get carousel1Title;

  /// No description provided for @carousel1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep prescriptions, reports, and X-rays safe in one secure vault.'**
  String get carousel1Subtitle;

  /// No description provided for @carousel2Title.
  ///
  /// In en, this message translates to:
  /// **'Share With Your\nDoctor Instantly'**
  String get carousel2Title;

  /// No description provided for @carousel2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a QR code so doctors can view your history without any app.'**
  String get carousel2Subtitle;

  /// No description provided for @carousel3Title.
  ///
  /// In en, this message translates to:
  /// **'Set Up Your\nEmergency Widget'**
  String get carousel3Title;

  /// No description provided for @carousel3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep critical health info one glance away, even on your lock screen.'**
  String get carousel3Subtitle;

  /// No description provided for @onboardingStep1Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 3'**
  String get onboardingStep1Of3;

  /// No description provided for @onboardingStep2Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3'**
  String get onboardingStep2Of3;

  /// No description provided for @onboardingStep3Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 3'**
  String get onboardingStep3Of3;

  /// No description provided for @onboardingTellUsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell Us About Yourself'**
  String get onboardingTellUsTitle;

  /// No description provided for @onboardingTellUsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us personalize your health vault.'**
  String get onboardingTellUsSubtitle;

  /// No description provided for @fieldFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get fieldFullNameRequired;

  /// No description provided for @fieldYearOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Year of Birth *'**
  String get fieldYearOfBirthRequired;

  /// No description provided for @hintYearOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Year of birth'**
  String get hintYearOfBirth;

  /// No description provided for @fieldGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Gender *'**
  String get fieldGenderRequired;

  /// No description provided for @hintSelectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get hintSelectGender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @genderPreferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get genderPreferNotToSay;

  /// No description provided for @validationYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Year of birth is required'**
  String get validationYearRequired;

  /// No description provided for @validationYearInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 4-digit year'**
  String get validationYearInvalid;

  /// No description provided for @validationYearRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a year between 1900 and {year}'**
  String validationYearRange(int year);

  /// No description provided for @validationMinAge13.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 years old'**
  String get validationMinAge13;

  /// No description provided for @validationGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get validationGenderRequired;

  /// No description provided for @onboardingPhysicalMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Physical Metrics'**
  String get onboardingPhysicalMetricsTitle;

  /// No description provided for @onboardingPhysicalMetricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us personalize your wellness journey...'**
  String get onboardingPhysicalMetricsSubtitle;

  /// No description provided for @fieldHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get fieldHeightCm;

  /// No description provided for @hintHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Height in cm'**
  String get hintHeightCm;

  /// No description provided for @fieldWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get fieldWeightKg;

  /// No description provided for @hintWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight in kg'**
  String get hintWeightKg;

  /// No description provided for @fieldBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get fieldBloodGroup;

  /// No description provided for @hintSelectBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Select blood group'**
  String get hintSelectBloodGroup;

  /// No description provided for @onboardingPhysicalDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Your physical data is used exclusively to calculate BMI and customize nutritional recommendations. All data is encrypted.'**
  String get onboardingPhysicalDataNotice;

  /// No description provided for @validationHeightRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a height between 50 and 300 cm'**
  String get validationHeightRange;

  /// No description provided for @validationWeightRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight between 1 and 500 kg'**
  String get validationWeightRange;

  /// No description provided for @onboardingAlmostThereTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost there!'**
  String get onboardingAlmostThereTitle;

  /// No description provided for @onboardingAlmostThereSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We use this information to provide personalized health insights...'**
  String get onboardingAlmostThereSubtitle;

  /// No description provided for @fieldAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get fieldAllergies;

  /// No description provided for @hintAllergiesExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., Pollen, Penicillin...'**
  String get hintAllergiesExample;

  /// No description provided for @helperSeparateWithCommas.
  ///
  /// In en, this message translates to:
  /// **'Separate items with commas'**
  String get helperSeparateWithCommas;

  /// No description provided for @fieldExistingConditions.
  ///
  /// In en, this message translates to:
  /// **'Existing Conditions'**
  String get fieldExistingConditions;

  /// No description provided for @hintAddOtherConditions.
  ///
  /// In en, this message translates to:
  /// **'Add other conditions...'**
  String get hintAddOtherConditions;

  /// No description provided for @badgeHipaaSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'HIPAA Compliant\nSecure Storage'**
  String get badgeHipaaSecureStorage;

  /// No description provided for @badgeEncryptedPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Encrypted\nPersonal Data'**
  String get badgeEncryptedPersonalData;

  /// No description provided for @onboardingSaveProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile. Update it later in settings.'**
  String get onboardingSaveProfileFailed;

  /// No description provided for @conditionAsthma.
  ///
  /// In en, this message translates to:
  /// **'Asthma'**
  String get conditionAsthma;

  /// No description provided for @conditionDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes'**
  String get conditionDiabetes;

  /// No description provided for @conditionEpilepsy.
  ///
  /// In en, this message translates to:
  /// **'Epilepsy'**
  String get conditionEpilepsy;

  /// No description provided for @conditionHypertension.
  ///
  /// In en, this message translates to:
  /// **'Hypertension'**
  String get conditionHypertension;

  /// No description provided for @conditionThyroidIssue.
  ///
  /// In en, this message translates to:
  /// **'Thyroid Issue'**
  String get conditionThyroidIssue;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @recordsTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get recordsTabAll;

  /// No description provided for @recordsTabPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get recordsTabPrescriptions;

  /// No description provided for @recordsTabMedicalReports.
  ///
  /// In en, this message translates to:
  /// **'Medical Reports'**
  String get recordsTabMedicalReports;

  /// No description provided for @recordsTabXRays.
  ///
  /// In en, this message translates to:
  /// **'X-Rays'**
  String get recordsTabXRays;

  /// No description provided for @recordsTabLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get recordsTabLab;

  /// No description provided for @recordsTabOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recordsTabOther;

  /// No description provided for @recordsFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get recordsFolder;

  /// No description provided for @recordsFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get recordsFolderName;

  /// No description provided for @recordsFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cardiology, Orthopedic'**
  String get recordsFolderNameHint;

  /// No description provided for @recordsFolderNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a folder name.'**
  String get recordsFolderNameRequired;

  /// No description provided for @recordsCreateFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create folder. Please try again.'**
  String get recordsCreateFolderFailed;

  /// No description provided for @recordsCreateNewFolder.
  ///
  /// In en, this message translates to:
  /// **'Create New Folder'**
  String get recordsCreateNewFolder;

  /// No description provided for @recordsCreateFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize records by health condition'**
  String get recordsCreateFolderSubtitle;

  /// No description provided for @recordsSelectIcon.
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get recordsSelectIcon;

  /// No description provided for @recordsCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Create Folder'**
  String get recordsCreateFolder;

  /// No description provided for @recordsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load records'**
  String get recordsLoadFailed;

  /// No description provided for @recordsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'No documents found. Try a different search or category, or upload a new document to your health vault.'**
  String get recordsEmptyDescription;

  /// No description provided for @recordsSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search documents'**
  String get recordsSearchPlaceholder;

  /// No description provided for @recordsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get recordsUntitled;

  /// No description provided for @recordsAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing…'**
  String get recordsAnalysing;

  /// No description provided for @recordsViewAiSummary.
  ///
  /// In en, this message translates to:
  /// **'View AI Summary'**
  String get recordsViewAiSummary;

  /// No description provided for @recordsExplainWithAi.
  ///
  /// In en, this message translates to:
  /// **'Explain with AI'**
  String get recordsExplainWithAi;

  /// No description provided for @recordsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Record'**
  String get recordsDeleteTitle;

  /// No description provided for @recordsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This record will be permanently deleted. Are you sure?'**
  String get recordsDeleteBody;

  /// No description provided for @recordsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete record.'**
  String get recordsDeleteFailed;

  /// No description provided for @recordsViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get recordsViewDetails;

  /// No description provided for @recordsAiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get recordsAiSummary;

  /// No description provided for @uploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Medical Record'**
  String get uploadTitle;

  /// No description provided for @uploadTitleForMember.
  ///
  /// In en, this message translates to:
  /// **'Upload for {name}'**
  String uploadTitleForMember(String name);

  /// No description provided for @uploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your health records to your secure vault.'**
  String get uploadSubtitle;

  /// No description provided for @uploadSubtitleForMember.
  ///
  /// In en, this message translates to:
  /// **'Upload records for {name} to their secure vault.'**
  String uploadSubtitleForMember(String name);

  /// No description provided for @uploadOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Uploading documents needs a connection so they can be securely stored and analysed. Reconnect and try again.'**
  String get uploadOfflineNotice;

  /// No description provided for @uploadFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large. Maximum allowed size is 50 MB.'**
  String get uploadFileTooLarge;

  /// No description provided for @uploadImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large. Maximum allowed size is 50 MB.'**
  String get uploadImageTooLarge;

  /// No description provided for @uploadFilePickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open file picker. Please try again.'**
  String get uploadFilePickerFailed;

  /// No description provided for @uploadCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera. Please try again.'**
  String get uploadCameraFailed;

  /// No description provided for @uploadSelectFileFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a file to upload.'**
  String get uploadSelectFileFirst;

  /// No description provided for @uploadFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file. Please try again.'**
  String get uploadFileReadFailed;

  /// No description provided for @uploadStagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing upload…'**
  String get uploadStagePreparing;

  /// No description provided for @uploadStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading file…'**
  String get uploadStageUploading;

  /// No description provided for @uploadStageAnalysing.
  ///
  /// In en, this message translates to:
  /// **'AI is analysing your document…'**
  String get uploadStageAnalysing;

  /// No description provided for @uploadFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Upload failed.'**
  String get uploadFailedShort;

  /// No description provided for @uploadFailedConnection.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please check your connection and try again.'**
  String get uploadFailedConnection;

  /// No description provided for @uploadFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get uploadFailedRetry;

  /// No description provided for @uploadCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get uploadCamera;

  /// No description provided for @uploadGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get uploadGallery;

  /// No description provided for @uploadSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Folder (optional)'**
  String get uploadSelectFolder;

  /// No description provided for @uploadGeneralRecords.
  ///
  /// In en, this message translates to:
  /// **'General Records'**
  String get uploadGeneralRecords;

  /// No description provided for @uploadProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get uploadProcessing;

  /// No description provided for @uploadPrivacyFirst.
  ///
  /// In en, this message translates to:
  /// **'Privacy First'**
  String get uploadPrivacyFirst;

  /// No description provided for @uploadPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Documents are encrypted and stored securely.'**
  String get uploadPrivacyNote;

  /// No description provided for @uploadTakePhotoOrChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Take Photo or Choose File'**
  String get uploadTakePhotoOrChooseFile;

  /// No description provided for @uploadFileTypesHint.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG, PNG, WebP, or DICOM - max 50 MB'**
  String get uploadFileTypesHint;

  /// No description provided for @uploadUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type. Choose a PDF, JPG, PNG, WebP, or DICOM (.dcm) file.'**
  String get uploadUnsupportedType;

  /// No description provided for @uploadDuplicateMessage.
  ///
  /// In en, this message translates to:
  /// **'This document has already been uploaded to your health vault.'**
  String get uploadDuplicateMessage;

  /// No description provided for @uploadRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Failed'**
  String get uploadRejectedTitle;

  /// No description provided for @uploadRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'This document was not added to your health vault.'**
  String get uploadRejectedBody;

  /// No description provided for @uploadCouldNotVerify.
  ///
  /// In en, this message translates to:
  /// **'We could not verify this document. Please try again.'**
  String get uploadCouldNotVerify;

  /// No description provided for @uploadTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get uploadTryAgain;

  /// No description provided for @uploadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uploadCancel;

  /// No description provided for @recordTypeLabReport.
  ///
  /// In en, this message translates to:
  /// **'Lab Report'**
  String get recordTypeLabReport;

  /// No description provided for @recordTypePrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get recordTypePrescription;

  /// No description provided for @recordTypeRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get recordTypeRadiology;

  /// No description provided for @recordTypeDischargeSummary.
  ///
  /// In en, this message translates to:
  /// **'Discharge Summary'**
  String get recordTypeDischargeSummary;

  /// No description provided for @recordTypeVaccination.
  ///
  /// In en, this message translates to:
  /// **'Vaccination'**
  String get recordTypeVaccination;

  /// No description provided for @recordTypeInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get recordTypeInsurance;

  /// No description provided for @recordTypeReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get recordTypeReferral;

  /// No description provided for @recordTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recordTypeOther;

  /// No description provided for @recordWord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordWord;

  /// No description provided for @recordPreviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this record.'**
  String get recordPreviewLoadFailed;

  /// No description provided for @recordViewFullRecord.
  ///
  /// In en, this message translates to:
  /// **'View Full Record'**
  String get recordViewFullRecord;

  /// No description provided for @recordStillProcessing.
  ///
  /// In en, this message translates to:
  /// **'Still processing - AI summary will appear once ready.'**
  String get recordStillProcessing;

  /// No description provided for @recordProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed.'**
  String get recordProcessingFailed;

  /// No description provided for @recordIssuedBy.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get recordIssuedBy;

  /// No description provided for @recordDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get recordDoctor;

  /// No description provided for @viewerUnsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'Preview isn\'t supported for this file type yet.'**
  String get viewerUnsupportedFileType;

  /// No description provided for @viewerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the document. Please try again.'**
  String get viewerLoadFailed;

  /// No description provided for @chatAttachRecords.
  ///
  /// In en, this message translates to:
  /// **'Attach Records'**
  String get chatAttachRecords;

  /// No description provided for @chatAttachRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick which records the AI should focus on for this question.'**
  String get chatAttachRecordsSubtitle;

  /// No description provided for @chatNoRecordsForPatient.
  ///
  /// In en, this message translates to:
  /// **'No records found for this patient yet.'**
  String get chatNoRecordsForPatient;

  /// No description provided for @chatCouldNotLoadRecords.
  ///
  /// In en, this message translates to:
  /// **'Could not load records.'**
  String get chatCouldNotLoadRecords;

  /// No description provided for @chatQuickChipLastReport.
  ///
  /// In en, this message translates to:
  /// **'Explain my last report'**
  String get chatQuickChipLastReport;

  /// No description provided for @chatQuickChipEmergencyInfo.
  ///
  /// In en, this message translates to:
  /// **'Show emergency info'**
  String get chatQuickChipEmergencyInfo;

  /// No description provided for @chatDefaultUntitledRecord.
  ///
  /// In en, this message translates to:
  /// **'Untitled record'**
  String get chatDefaultUntitledRecord;

  /// No description provided for @chatAskAboutYourHealth.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health'**
  String get chatAskAboutYourHealth;

  /// No description provided for @chatAskAboutMembersHealth.
  ///
  /// In en, this message translates to:
  /// **'Ask about {name}\'s health'**
  String chatAskAboutMembersHealth(String name);

  /// No description provided for @chatHealthAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Assistant'**
  String get chatHealthAssistantTitle;

  /// No description provided for @chatOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'The AI assistant needs a connection to read your records and respond. Reconnect and try again.'**
  String get chatOfflineNotice;

  /// No description provided for @chatSessionHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get chatSessionHistoryTooltip;

  /// No description provided for @chatNewSessionTooltip.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get chatNewSessionTooltip;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health records...'**
  String get chatInputHint;

  /// No description provided for @chatSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I could not start a chat session. Please try again.'**
  String get chatSessionStartFailed;

  /// No description provided for @chatGenericError.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I encountered an error. Please try again.'**
  String get chatGenericError;

  /// No description provided for @chatSourcesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get chatSourcesLabel;

  /// No description provided for @chatRenameConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get chatRenameConversationTitle;

  /// No description provided for @chatConversationTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Conversation title'**
  String get chatConversationTitleHint;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @chatRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename chat.'**
  String get chatRenameFailed;

  /// No description provided for @chatUnpinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unpin chat.'**
  String get chatUnpinFailed;

  /// No description provided for @chatPinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pin chat.'**
  String get chatPinFailed;

  /// No description provided for @chatDeleteConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation?'**
  String get chatDeleteConversationTitle;

  /// No description provided for @chatDeleteConversationBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone. This conversation will be permanently deleted.'**
  String get chatDeleteConversationBody;

  /// No description provided for @chatDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete chat.'**
  String get chatDeleteFailed;

  /// No description provided for @chatSessionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatSessionHistoryTitle;

  /// No description provided for @chatCouldNotLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load session history.'**
  String get chatCouldNotLoadHistory;

  /// No description provided for @chatNoPreviousSessions.
  ///
  /// In en, this message translates to:
  /// **'No previous sessions yet.'**
  String get chatNoPreviousSessions;

  /// No description provided for @chatNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatNewConversation;

  /// No description provided for @chatRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRename;

  /// No description provided for @chatPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatPin;

  /// No description provided for @chatUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatUnpin;

  /// No description provided for @chatAttachButton.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttachButton;

  /// No description provided for @chatAttachCountButton.
  ///
  /// In en, this message translates to:
  /// **'Attach ({count})'**
  String chatAttachCountButton(int count);

  /// No description provided for @chatYourHealthAssistant.
  ///
  /// In en, this message translates to:
  /// **'Your Health Assistant'**
  String get chatYourHealthAssistant;

  /// No description provided for @chatEmptyStateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your health records.\nI\'ll explain things in plain language.'**
  String get chatEmptyStateSubtitle;

  /// No description provided for @chatSuggestionSummarizeLabs.
  ///
  /// In en, this message translates to:
  /// **'Summarize my recent lab results'**
  String get chatSuggestionSummarizeLabs;

  /// No description provided for @chatSuggestionActiveConditions.
  ///
  /// In en, this message translates to:
  /// **'What are my current active conditions?'**
  String get chatSuggestionActiveConditions;

  /// No description provided for @chatSuggestionExplainMeds.
  ///
  /// In en, this message translates to:
  /// **'Explain my medications'**
  String get chatSuggestionExplainMeds;

  /// No description provided for @chatSuggestionCriticalAllergies.
  ///
  /// In en, this message translates to:
  /// **'Do I have any critical allergies?'**
  String get chatSuggestionCriticalAllergies;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your health'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Get answers grounded in the records you\'ve already uploaded to your Health Vault.'**
  String get chatEmptyDescription;

  /// No description provided for @chatSuggestionSummarizeLatestLab.
  ///
  /// In en, this message translates to:
  /// **'Summarize my latest lab report'**
  String get chatSuggestionSummarizeLatestLab;

  /// No description provided for @chatSuggestionExplainXray.
  ///
  /// In en, this message translates to:
  /// **'What does my X-ray show?'**
  String get chatSuggestionExplainXray;

  /// No description provided for @chatSuggestionAnyConcerns.
  ///
  /// In en, this message translates to:
  /// **'Any concerns based on my records?'**
  String get chatSuggestionAnyConcerns;

  /// No description provided for @chatDisclaimerBanner.
  ///
  /// In en, this message translates to:
  /// **'CurecordAI is not a substitute for professional medical advice. Always confirm important decisions with your doctor.'**
  String get chatDisclaimerBanner;

  /// No description provided for @chatUntitledConversation.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get chatUntitledConversation;

  /// No description provided for @chatAttachSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search documents'**
  String get chatAttachSearchPlaceholder;

  /// No description provided for @chatAttachNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No documents match your search.'**
  String get chatAttachNoMatches;

  /// No description provided for @chatTimeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get chatTimeNow;

  /// No description provided for @chatTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}m ago'**
  String chatTimeMinutesAgo(int value);

  /// No description provided for @chatTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}h ago'**
  String chatTimeHoursAgo(int value);

  /// No description provided for @chatTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}d ago'**
  String chatTimeDaysAgo(int value);

  /// No description provided for @chatTimeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}w ago'**
  String chatTimeWeeksAgo(int value);

  /// No description provided for @chatTimeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}mo ago'**
  String chatTimeMonthsAgo(int value);

  /// No description provided for @chatTimeYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}y ago'**
  String chatTimeYearsAgo(int value);

  /// No description provided for @aiSummaryAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Report Summary'**
  String get aiSummaryAppBarTitle;

  /// No description provided for @aiSummaryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load record'**
  String get aiSummaryLoadFailed;

  /// No description provided for @aiSummaryProcessing.
  ///
  /// In en, this message translates to:
  /// **'AI is analysing your document'**
  String get aiSummaryProcessing;

  /// No description provided for @aiSummaryProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few seconds. Pull down to refresh when ready.'**
  String get aiSummaryProcessingSubtitle;

  /// No description provided for @aiSummaryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get aiSummaryFailedTitle;

  /// No description provided for @aiSummaryFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We could not process this document. Please try re-uploading it.'**
  String get aiSummaryFailedSubtitle;

  /// No description provided for @aiSummaryAskAiInstead.
  ///
  /// In en, this message translates to:
  /// **'Ask AI instead'**
  String get aiSummaryAskAiInstead;

  /// No description provided for @aiSummaryNoLabParams.
  ///
  /// In en, this message translates to:
  /// **'No lab parameters found'**
  String get aiSummaryNoLabParams;

  /// No description provided for @aiSummaryNoLabParamsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This document does not contain numeric lab results. You can still ask the AI to explain it.'**
  String get aiSummaryNoLabParamsSubtitle;

  /// No description provided for @aiSummaryContinueInChat.
  ///
  /// In en, this message translates to:
  /// **'Continue in Chat'**
  String get aiSummaryContinueInChat;

  /// No description provided for @aiSummaryViewRecordDetails.
  ///
  /// In en, this message translates to:
  /// **'View Record Details'**
  String get aiSummaryViewRecordDetails;

  /// No description provided for @aiSummaryResultLabel.
  ///
  /// In en, this message translates to:
  /// **'ANALYSIS RESULT'**
  String get aiSummaryResultLabel;

  /// No description provided for @aiSummaryOverallLabel.
  ///
  /// In en, this message translates to:
  /// **'Overall: {status}'**
  String aiSummaryOverallLabel(String status);

  /// No description provided for @aiSummaryDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This summary is generated by AI to help you understand your results. Please consult with your physician for a formal diagnosis.'**
  String get aiSummaryDisclaimer;

  /// No description provided for @aiSummaryContinueExplanation.
  ///
  /// In en, this message translates to:
  /// **'Continue explanation in Chat'**
  String get aiSummaryContinueExplanation;

  /// No description provided for @commonYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get commonYou;

  /// No description provided for @medFamilyMemberFallback.
  ///
  /// In en, this message translates to:
  /// **'Family member'**
  String get medFamilyMemberFallback;

  /// No description provided for @medAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Medication'**
  String get medAddTitle;

  /// No description provided for @medNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Medication name is required.'**
  String get medNameRequired;

  /// No description provided for @medSelectDayRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one day of the week.'**
  String get medSelectDayRequired;

  /// No description provided for @medSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this medication reminder.'**
  String get medSaveFailed;

  /// No description provided for @medWhoIsFor.
  ///
  /// In en, this message translates to:
  /// **'Who is this medication for?'**
  String get medWhoIsFor;

  /// No description provided for @medMyself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get medMyself;

  /// No description provided for @medHowToAdd.
  ///
  /// In en, this message translates to:
  /// **'How would you like to add this medication?'**
  String get medHowToAdd;

  /// No description provided for @medSelectFromDocument.
  ///
  /// In en, this message translates to:
  /// **'Select from an uploaded document'**
  String get medSelectFromDocument;

  /// No description provided for @medSelectFromDocumentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse medications already extracted from your records'**
  String get medSelectFromDocumentSubtitle;

  /// No description provided for @medAddManually.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get medAddManually;

  /// No description provided for @medAddManuallySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter medication details yourself'**
  String get medAddManuallySubtitle;

  /// No description provided for @medCouldNotLoadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Could not load documents.'**
  String get medCouldNotLoadDocuments;

  /// No description provided for @medNoDocumentsUploaded.
  ///
  /// In en, this message translates to:
  /// **'No documents uploaded yet.'**
  String get medNoDocumentsUploaded;

  /// No description provided for @medSelectDocument.
  ///
  /// In en, this message translates to:
  /// **'Select a document (newest first)'**
  String get medSelectDocument;

  /// No description provided for @medCouldNotLoadMedications.
  ///
  /// In en, this message translates to:
  /// **'Could not load medications.'**
  String get medCouldNotLoadMedications;

  /// No description provided for @medSelectMedicationFromDocument.
  ///
  /// In en, this message translates to:
  /// **'Select a medication from this document'**
  String get medSelectMedicationFromDocument;

  /// No description provided for @medNoMedicationsExtracted.
  ///
  /// In en, this message translates to:
  /// **'No medications were extracted from this document.'**
  String get medNoMedicationsExtracted;

  /// No description provided for @medUnknownMedication.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get medUnknownMedication;

  /// No description provided for @medChooseDifferentDocument.
  ///
  /// In en, this message translates to:
  /// **'Choose a different document'**
  String get medChooseDifferentDocument;

  /// No description provided for @medFieldName.
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get medFieldName;

  /// No description provided for @medFieldDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medFieldDosage;

  /// No description provided for @medDosageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500mg'**
  String get medDosageHint;

  /// No description provided for @medFieldForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get medFieldForm;

  /// No description provided for @medFormHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tablet, Syrup'**
  String get medFormHint;

  /// No description provided for @medFieldInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions (optional)'**
  String get medFieldInstructions;

  /// No description provided for @medContinueToSchedule.
  ///
  /// In en, this message translates to:
  /// **'Continue to schedule'**
  String get medContinueToSchedule;

  /// No description provided for @medFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get medFrequencyLabel;

  /// No description provided for @medFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get medFreqDaily;

  /// No description provided for @medFreqSpecificDays.
  ///
  /// In en, this message translates to:
  /// **'Specific days of the week'**
  String get medFreqSpecificDays;

  /// No description provided for @medFreqInterval.
  ///
  /// In en, this message translates to:
  /// **'Every N days'**
  String get medFreqInterval;

  /// No description provided for @medFreqAsNeeded.
  ///
  /// In en, this message translates to:
  /// **'As needed (no fixed reminder)'**
  String get medFreqAsNeeded;

  /// No description provided for @medEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get medEveryLabel;

  /// No description provided for @medDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'day(s)'**
  String get medDaysUnit;

  /// No description provided for @medReminderTimes.
  ///
  /// In en, this message translates to:
  /// **'Reminder times'**
  String get medReminderTimes;

  /// No description provided for @medAddAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Add another time'**
  String get medAddAnotherTime;

  /// No description provided for @medStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get medStartDate;

  /// No description provided for @medEndDateOptional.
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get medEndDateOptional;

  /// No description provided for @medOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get medOngoing;

  /// No description provided for @medEmailReminder.
  ///
  /// In en, this message translates to:
  /// **'Email reminder (web app)'**
  String get medEmailReminder;

  /// No description provided for @medPushReminder.
  ///
  /// In en, this message translates to:
  /// **'Alarm-style reminder on this device'**
  String get medPushReminder;

  /// No description provided for @medSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get medSaving;

  /// No description provided for @medSaveReminder.
  ///
  /// In en, this message translates to:
  /// **'Save Medication Reminder'**
  String get medSaveReminder;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @medicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medicationsTitle;

  /// No description provided for @medicationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load medications right now'**
  String get medicationsLoadFailed;

  /// No description provided for @medicationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No medications yet'**
  String get medicationsEmptyTitle;

  /// No description provided for @medicationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a medication from a document or manually to start getting reminders.'**
  String get medicationsEmptySubtitle;

  /// No description provided for @medicationsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Medication'**
  String get medicationsAddButton;

  /// No description provided for @medFreqAsNeededSummary.
  ///
  /// In en, this message translates to:
  /// **'As needed'**
  String get medFreqAsNeededSummary;

  /// No description provided for @medFreqDailySummary.
  ///
  /// In en, this message translates to:
  /// **'Daily · {times}'**
  String medFreqDailySummary(String times);

  /// No description provided for @medFreqIntervalSummary.
  ///
  /// In en, this message translates to:
  /// **'Every {days} day(s) · {times}'**
  String medFreqIntervalSummary(String days, String times);

  /// No description provided for @medDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medDetailTitle;

  /// No description provided for @medUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update this medication.'**
  String get medUpdateFailed;

  /// No description provided for @medDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete medication?'**
  String get medDeleteConfirmTitle;

  /// No description provided for @medDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This reminder will be removed. This cannot be undone.'**
  String get medDeleteConfirmBody;

  /// No description provided for @medDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this medication.'**
  String get medDeleteFailed;

  /// No description provided for @medLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this medication.'**
  String get medLoadFailed;

  /// No description provided for @medForMember.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String medForMember(String name);

  /// No description provided for @medRowDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medRowDosage;

  /// No description provided for @medRowForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get medRowForm;

  /// No description provided for @medRowInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get medRowInstructions;

  /// No description provided for @medRowFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get medRowFrequency;

  /// No description provided for @medRowTimes.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get medRowTimes;

  /// No description provided for @medRowStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get medRowStartDate;

  /// No description provided for @medRowEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get medRowEndDate;

  /// No description provided for @medRowTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get medRowTimezone;

  /// No description provided for @medRowReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get medRowReminders;

  /// No description provided for @medRowStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get medRowStatus;

  /// No description provided for @medReminderEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get medReminderEmail;

  /// No description provided for @medReminderMobileAlarm.
  ///
  /// In en, this message translates to:
  /// **'Mobile alarm'**
  String get medReminderMobileAlarm;

  /// No description provided for @medReminderNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get medReminderNone;

  /// No description provided for @medResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get medResume;

  /// No description provided for @medPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get medPause;

  /// No description provided for @medMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get medMarkCompleted;

  /// No description provided for @medNotifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Medication Reminders'**
  String get medNotifChannelName;

  /// No description provided for @medNotifChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Alarm-style reminders so you never miss a medication dose'**
  String get medNotifChannelDescription;

  /// No description provided for @medNotifReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Medication reminder'**
  String get medNotifReminderTitle;

  /// No description provided for @medNotifReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Time to take {medicationName}'**
  String medNotifReminderBody(String medicationName);

  /// No description provided for @medNotifReminderBodyWithDosage.
  ///
  /// In en, this message translates to:
  /// **'Time to take {medicationName} ({dosage})'**
  String medNotifReminderBodyWithDosage(String medicationName, String dosage);

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @medTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get medTabActive;

  /// No description provided for @medTabPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get medTabPaused;

  /// No description provided for @medTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get medTabCompleted;

  /// No description provided for @medTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get medTabAll;

  /// No description provided for @medNoActiveMedications.
  ///
  /// In en, this message translates to:
  /// **'No active medications'**
  String get medNoActiveMedications;

  /// No description provided for @medNoPausedMedications.
  ///
  /// In en, this message translates to:
  /// **'No paused medications'**
  String get medNoPausedMedications;

  /// No description provided for @medNoCompletedMedications.
  ///
  /// In en, this message translates to:
  /// **'No completed medications'**
  String get medNoCompletedMedications;

  /// No description provided for @medOtherTabsNote.
  ///
  /// In en, this message translates to:
  /// **'You have {summary} in other tabs.'**
  String medOtherTabsNote(String summary);

  /// No description provided for @medExplainerAllergiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Checked against your allergies'**
  String get medExplainerAllergiesTitle;

  /// No description provided for @medExplainerAllergiesDescription.
  ///
  /// In en, this message translates to:
  /// **'Medications you track show up alongside your recorded allergies in your AI health summary, making it easier for you and your care team to notice a potential conflict.'**
  String get medExplainerAllergiesDescription;

  /// No description provided for @medExplainerDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistent with your documents'**
  String get medExplainerDocumentsTitle;

  /// No description provided for @medExplainerDocumentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Importing a medication from an uploaded prescription links it to that document, so your medication list stays consistent with the rest of your health records.'**
  String get medExplainerDocumentsDescription;

  /// No description provided for @medNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get medNotProvided;

  /// No description provided for @medMyselfHint.
  ///
  /// In en, this message translates to:
  /// **'Manage your own medications'**
  String get medMyselfHint;

  /// No description provided for @medFamilyMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Manage medications for someone you care for'**
  String get medFamilyMemberHint;

  /// No description provided for @medNoFamilyMembersYet.
  ///
  /// In en, this message translates to:
  /// **'You have not added any family members yet. Add one to continue.'**
  String get medNoFamilyMembersYet;

  /// No description provided for @medCurrentlySelected.
  ///
  /// In en, this message translates to:
  /// **'currently selected'**
  String get medCurrentlySelected;

  /// No description provided for @medFamilyMemberTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Family member'**
  String get medFamilyMemberTileTitle;

  /// No description provided for @medSelectFamilyMemberPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a family member'**
  String get medSelectFamilyMemberPrompt;

  /// No description provided for @medBackStep.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get medBackStep;

  /// No description provided for @medAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Set up a reminder so this dose never gets missed.'**
  String get medAddDescription;

  /// No description provided for @medEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Medication'**
  String get medEditTitle;

  /// No description provided for @medEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Update the details for this medication reminder.'**
  String get medEditDescription;

  /// No description provided for @medSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get medSaveChanges;

  /// No description provided for @medNoDosageDetails.
  ///
  /// In en, this message translates to:
  /// **'No dosage details'**
  String get medNoDosageDetails;

  /// No description provided for @medSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Medication details'**
  String get medSectionDetails;

  /// No description provided for @medSectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get medSectionSchedule;

  /// No description provided for @medSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get medSectionNotifications;

  /// No description provided for @medAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} has been added'**
  String medAddedSnack(String name);

  /// No description provided for @medAddedForMember.
  ///
  /// In en, this message translates to:
  /// **'{name} has been added for {memberName}'**
  String medAddedForMember(String name, String memberName);

  /// No description provided for @familyManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Management'**
  String get familyManagementTitle;

  /// No description provided for @familyManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your health circle. Share medical records, manage dependents, and receive alerts.'**
  String get familyManagementSubtitle;

  /// No description provided for @familyMemberFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get familyMemberFallbackName;

  /// No description provided for @familyMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get familyMemberRemoved;

  /// No description provided for @familyMemberRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member'**
  String get familyMemberRemoveFailed;

  /// No description provided for @familyPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get familyPrivacyPolicy;

  /// No description provided for @familyTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get familyTermsOfService;

  /// No description provided for @familySupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get familySupport;

  /// No description provided for @familyAppVersion.
  ///
  /// In en, this message translates to:
  /// **'CurecordAI v1.0.0'**
  String get familyAppVersion;

  /// No description provided for @familyManagedByGuardian.
  ///
  /// In en, this message translates to:
  /// **'Managed by parent/guardian'**
  String get familyManagedByGuardian;

  /// No description provided for @familyHasAccessToRecords.
  ///
  /// In en, this message translates to:
  /// **'Has access to your records'**
  String get familyHasAccessToRecords;

  /// No description provided for @familyAddMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Family Member'**
  String get familyAddMemberTitle;

  /// No description provided for @familyAddMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a partner, relative, or add a child to your unified health sync profile.'**
  String get familyAddMemberSubtitle;

  /// No description provided for @familyRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Member?'**
  String get familyRemoveMemberTitle;

  /// No description provided for @familyRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from your health circle? Their health records will be preserved.'**
  String familyRemoveMemberBody(String name);

  /// No description provided for @familyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get familyRemove;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @famPhotoUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get famPhotoUploadTitle;

  /// No description provided for @famPhotoUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, coming soon'**
  String get famPhotoUploadHint;

  /// No description provided for @famFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get famFullNameLabel;

  /// No description provided for @famValidationNameMin.
  ///
  /// In en, this message translates to:
  /// **'Please enter the full name (min 2 chars)'**
  String get famValidationNameMin;

  /// No description provided for @famDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get famDobLabel;

  /// No description provided for @famDobPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get famDobPlaceholder;

  /// No description provided for @famAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a child, parent, or sibling to manage their health records.'**
  String get famAddSubtitle;

  /// No description provided for @famNameHintFamily.
  ///
  /// In en, this message translates to:
  /// **'e.g. John Doe'**
  String get famNameHintFamily;

  /// No description provided for @famValidationRelationshipRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a relationship'**
  String get famValidationRelationshipRequired;

  /// No description provided for @famAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} has been added to your family'**
  String famAddedSnack(String name);

  /// No description provided for @famAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add family member. Please try again.'**
  String get famAddFailed;

  /// No description provided for @famRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship *'**
  String get famRelationshipLabel;

  /// No description provided for @famRelationshipPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select relationship'**
  String get famRelationshipPlaceholder;

  /// No description provided for @famSelectRelationshipTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Relationship'**
  String get famSelectRelationshipTitle;

  /// No description provided for @famGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get famGenderLabel;

  /// No description provided for @famGenderPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get famGenderPlaceholder;

  /// No description provided for @famSelectGenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get famSelectGenderTitle;

  /// No description provided for @famBloodGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get famBloodGroupLabel;

  /// No description provided for @famPrivacyAgreementMember.
  ///
  /// In en, this message translates to:
  /// **'By adding a member, you agree to CurecordAI\'s family privacy policy.'**
  String get famPrivacyAgreementMember;

  /// No description provided for @famRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get famRoleLabel;

  /// No description provided for @famRoleDependent.
  ///
  /// In en, this message translates to:
  /// **'Dependent (I manage their records)'**
  String get famRoleDependent;

  /// No description provided for @famRoleCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver (helps manage my records)'**
  String get famRoleCaregiver;

  /// No description provided for @famRoleLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Role cannot be changed after a family member is created.'**
  String get famRoleLockedHint;

  /// No description provided for @famEditMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Family Member'**
  String get famEditMemberTitle;

  /// No description provided for @famEditMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update this family member\'s health profile.'**
  String get famEditMemberSubtitle;

  /// No description provided for @famUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been updated'**
  String famUpdateSuccess(String name);

  /// No description provided for @famUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update family member. Please try again.'**
  String get famUpdateFailed;

  /// No description provided for @famSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get famSaveChanges;

  /// No description provided for @relSon.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get relSon;

  /// No description provided for @relDaughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get relDaughter;

  /// No description provided for @relFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get relFather;

  /// No description provided for @relMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get relMother;

  /// No description provided for @relWife.
  ///
  /// In en, this message translates to:
  /// **'Wife'**
  String get relWife;

  /// No description provided for @relHusband.
  ///
  /// In en, this message translates to:
  /// **'Husband'**
  String get relHusband;

  /// No description provided for @relBrother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get relBrother;

  /// No description provided for @relSister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get relSister;

  /// No description provided for @relGrandfather.
  ///
  /// In en, this message translates to:
  /// **'Grandfather'**
  String get relGrandfather;

  /// No description provided for @relGrandmother.
  ///
  /// In en, this message translates to:
  /// **'Grandmother'**
  String get relGrandmother;

  /// No description provided for @relOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get relOther;

  /// No description provided for @relSpouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get relSpouse;

  /// No description provided for @relParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get relParent;

  /// No description provided for @relChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get relChild;

  /// No description provided for @relSibling.
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get relSibling;

  /// No description provided for @familyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No family members yet'**
  String get familyEmptyTitle;

  /// No description provided for @familyEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a parent, spouse, or child to start managing their health records alongside your own.'**
  String get familyEmptyDescription;

  /// No description provided for @familyAddShortcutParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a parent'**
  String get familyAddShortcutParentTitle;

  /// No description provided for @familyAddShortcutParentDescription.
  ///
  /// In en, this message translates to:
  /// **'Track their medications and appointments.'**
  String get familyAddShortcutParentDescription;

  /// No description provided for @familyAddShortcutSpouseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a spouse'**
  String get familyAddShortcutSpouseTitle;

  /// No description provided for @familyAddShortcutSpouseDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage shared health history together.'**
  String get familyAddShortcutSpouseDescription;

  /// No description provided for @familyAddShortcutChildTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a child'**
  String get familyAddShortcutChildTitle;

  /// No description provided for @familyAddShortcutChildDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep their records organized in one place.'**
  String get familyAddShortcutChildDescription;

  /// No description provided for @familyFieldGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get familyFieldGender;

  /// No description provided for @familyFieldBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get familyFieldBloodGroup;

  /// No description provided for @familyFieldAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get familyFieldAge;

  /// No description provided for @familyNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get familyNotProvided;

  /// No description provided for @familyYearsOld.
  ///
  /// In en, this message translates to:
  /// **'{age} years old'**
  String familyYearsOld(int age);

  /// No description provided for @familyEditAria.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String familyEditAria(String name);

  /// No description provided for @caregiverAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Caregiver'**
  String get caregiverAddTitle;

  /// No description provided for @caregiverAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a doctor or caregiver to share your health records with them.'**
  String get caregiverAddSubtitle;

  /// No description provided for @caregiverValidationTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a caregiver type'**
  String get caregiverValidationTypeRequired;

  /// No description provided for @caregiverAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Caregiver added'**
  String get caregiverAddedSnack;

  /// No description provided for @caregiverAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add caregiver. Please try again.'**
  String get caregiverAddFailed;

  /// No description provided for @caregiverTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type *'**
  String get caregiverTypeLabel;

  /// No description provided for @caregiverTypePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select type'**
  String get caregiverTypePlaceholder;

  /// No description provided for @caregiverSelectTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Type'**
  String get caregiverSelectTypeTitle;

  /// No description provided for @caregiverRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship (optional)'**
  String get caregiverRelationshipLabel;

  /// No description provided for @caregiverRelationshipHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Family Doctor'**
  String get caregiverRelationshipHint;

  /// No description provided for @caregiverNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dr. John Smith'**
  String get caregiverNameHint;

  /// No description provided for @caregiverAccessPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Permission'**
  String get caregiverAccessPermissionTitle;

  /// No description provided for @caregiverAccessPermissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What can this person view when you share your records?'**
  String get caregiverAccessPermissionSubtitle;

  /// No description provided for @caregiverAccessFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Access'**
  String get caregiverAccessFullTitle;

  /// No description provided for @caregiverAccessFullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All records - conditions, medications, allergies and documents'**
  String get caregiverAccessFullSubtitle;

  /// No description provided for @caregiverAccessVitalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vitals Only'**
  String get caregiverAccessVitalsTitle;

  /// No description provided for @caregiverAccessVitalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure, heart rate, SpO2 and basic vitals only'**
  String get caregiverAccessVitalsSubtitle;

  /// No description provided for @caregiverAccessReadOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Read Only'**
  String get caregiverAccessReadOnlyTitle;

  /// No description provided for @caregiverAccessReadOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can view all records but cannot add or edit anything'**
  String get caregiverAccessReadOnlySubtitle;

  /// No description provided for @caregiverPrivacyAgreement.
  ///
  /// In en, this message translates to:
  /// **'By adding a caregiver, you agree to CurecordAI\'s family privacy policy.'**
  String get caregiverPrivacyAgreement;

  /// No description provided for @caregiverTypeDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get caregiverTypeDoctor;

  /// No description provided for @caregiverTypeNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get caregiverTypeNurse;

  /// No description provided for @caregiverTypeHomeAide.
  ///
  /// In en, this message translates to:
  /// **'Home Aide'**
  String get caregiverTypeHomeAide;

  /// No description provided for @caregiverTypeSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Specialist'**
  String get caregiverTypeSpecialist;

  /// No description provided for @caregiverTypeTherapist.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get caregiverTypeTherapist;

  /// No description provided for @caregiverTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get caregiverTypeOther;

  /// No description provided for @emergencyInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Info'**
  String get emergencyInfoTitle;

  /// No description provided for @emergencyInfoTitleFor.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Emergency Info'**
  String emergencyInfoTitleFor(String name);

  /// No description provided for @emergencyWidgetSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Widget Setup'**
  String get emergencyWidgetSetupTitle;

  /// No description provided for @emergencyWidgetSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what to show on your lock screen'**
  String get emergencyWidgetSetupSubtitle;

  /// No description provided for @emergencyLockScreenHint.
  ///
  /// In en, this message translates to:
  /// **'Emergency info visible below'**
  String get emergencyLockScreenHint;

  /// No description provided for @emergencyInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY INFO'**
  String get emergencyInfoLabel;

  /// No description provided for @emergencyBloodGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'BLOOD GROUP'**
  String get emergencyBloodGroupLabel;

  /// No description provided for @emergencyNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get emergencyNotSet;

  /// No description provided for @emergencyAllergiesLabel.
  ///
  /// In en, this message translates to:
  /// **'ALLERGIES'**
  String get emergencyAllergiesLabel;

  /// No description provided for @emergencyNoneKnown.
  ///
  /// In en, this message translates to:
  /// **'None known'**
  String get emergencyNoneKnown;

  /// No description provided for @emergencyContactLabel.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY CONTACT'**
  String get emergencyContactLabel;

  /// No description provided for @emergencyToggleBloodGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get emergencyToggleBloodGroupTitle;

  /// No description provided for @emergencyToggleBloodGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display your blood type for first responders'**
  String get emergencyToggleBloodGroupSubtitle;

  /// No description provided for @emergencyToggleAllergiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get emergencyToggleAllergiesTitle;

  /// No description provided for @emergencyToggleAllergiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show critical medication and food allergies'**
  String get emergencyToggleAllergiesSubtitle;

  /// No description provided for @emergencyToggleContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyToggleContactTitle;

  /// No description provided for @emergencyToggleContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Primary contact name and phone number'**
  String get emergencyToggleContactSubtitle;

  /// No description provided for @emergencyToggleChronicTitle.
  ///
  /// In en, this message translates to:
  /// **'Chronic Conditions'**
  String get emergencyToggleChronicTitle;

  /// No description provided for @emergencyToggleChronicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display important ongoing health issues'**
  String get emergencyToggleChronicSubtitle;

  /// No description provided for @emergencyEnableWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Lock Screen Widget'**
  String get emergencyEnableWidgetTitle;

  /// No description provided for @emergencyEnableWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow emergency info to bypass security'**
  String get emergencyEnableWidgetSubtitle;

  /// No description provided for @emergencyContactsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY CONTACTS'**
  String get emergencyContactsSectionTitle;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @emergencyContactNameHint.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get emergencyContactNameHint;

  /// No description provided for @emergencyContactPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get emergencyContactPhoneHint;

  /// No description provided for @emergencyRelFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get emergencyRelFamily;

  /// No description provided for @emergencyRelFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get emergencyRelFriend;

  /// No description provided for @emergencyRelDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get emergencyRelDoctor;

  /// No description provided for @emergencyRelNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get emergencyRelNurse;

  /// No description provided for @emergencyAddContactButton.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get emergencyAddContactButton;

  /// No description provided for @emergencyNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts added'**
  String get emergencyNoContacts;

  /// No description provided for @emergencySaveSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get emergencySaveSettingsButton;

  /// No description provided for @emergencySettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get emergencySettingsSaved;

  /// No description provided for @emergencySettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get emergencySettingsSaveFailed;

  /// No description provided for @emergencyAddContactFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add contact'**
  String get emergencyAddContactFailed;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @alertCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert Center'**
  String get alertCenterTitle;

  /// No description provided for @alertCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your health priorities'**
  String get alertCenterSubtitle;

  /// No description provided for @alertMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get alertMarkAllRead;

  /// No description provided for @alertEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get alertEmptyTitle;

  /// No description provided for @alertEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You have no notifications'**
  String get alertEmptySubtitle;

  /// No description provided for @alertYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get alertYesterday;

  /// No description provided for @alertEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get alertEarlier;

  /// No description provided for @alertPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'HIGH PRIORITY'**
  String get alertPriorityHigh;

  /// No description provided for @alertPriorityAttention.
  ///
  /// In en, this message translates to:
  /// **'ATTENTION'**
  String get alertPriorityAttention;

  /// No description provided for @alertPrioritySystemUpdate.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM UPDATE'**
  String get alertPrioritySystemUpdate;

  /// No description provided for @alertCategoryMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get alertCategoryMedication;

  /// No description provided for @alertCategoryVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get alertCategoryVitals;

  /// No description provided for @alertCategoryProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get alertCategoryProfile;

  /// No description provided for @alertCategoryRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get alertCategoryRecords;

  /// No description provided for @alertDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get alertDefaultTitle;

  /// No description provided for @alertTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String alertTimeMinutesAgo(int minutes);

  /// No description provided for @alertTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String alertTimeHoursAgo(int hours);

  /// No description provided for @alertTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String alertTimeDaysAgo(int days);

  /// No description provided for @shareScopeLast1Year.
  ///
  /// In en, this message translates to:
  /// **'Last 1 Year'**
  String get shareScopeLast1Year;

  /// No description provided for @shareScopeLast6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 Months'**
  String get shareScopeLast6Months;

  /// No description provided for @shareScopeFullHistory.
  ///
  /// In en, this message translates to:
  /// **'Complete History'**
  String get shareScopeFullHistory;

  /// No description provided for @shareScopeEmergencyOnly.
  ///
  /// In en, this message translates to:
  /// **'Emergency Info Only'**
  String get shareScopeEmergencyOnly;

  /// No description provided for @shareRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Records'**
  String get shareRecordsTitle;

  /// No description provided for @shareOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Sharing records with a doctor needs a connection to generate a secure link. Reconnect and try again.'**
  String get shareOfflineMessage;

  /// No description provided for @shareRecordsTitleFor.
  ///
  /// In en, this message translates to:
  /// **'Share {name}\'s Records'**
  String shareRecordsTitleFor(String name);

  /// No description provided for @shareFailedGenerateQr.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate QR code'**
  String get shareFailedGenerateQr;

  /// No description provided for @shareDoctorInstructionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Instructions'**
  String get shareDoctorInstructionsTitle;

  /// No description provided for @shareSubtitleOwner.
  ///
  /// In en, this message translates to:
  /// **'Share your health records with your doctor or caregiver'**
  String get shareSubtitleOwner;

  /// No description provided for @shareSubtitleFor.
  ///
  /// In en, this message translates to:
  /// **'Share {name}\'s health records with their doctor or caregiver'**
  String shareSubtitleFor(String name);

  /// No description provided for @shareGenerateQrButton.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get shareGenerateQrButton;

  /// No description provided for @shareGeneratingButton.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get shareGeneratingButton;

  /// No description provided for @shareEncryptedNote.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted. The QR code expires in 10 minutes and can only be scanned by verified practitioners.'**
  String get shareEncryptedNote;

  /// No description provided for @shareActiveSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE SESSIONS'**
  String get shareActiveSessionsTitle;

  /// No description provided for @shareNoActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'No active sharing sessions'**
  String get shareNoActiveSessions;

  /// No description provided for @shareShowDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Show This to Your Doctor'**
  String get shareShowDoctorTitle;

  /// No description provided for @shareShowDoctorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor can scan this without installing any app'**
  String get shareShowDoctorSubtitle;

  /// No description provided for @shareValidityExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get shareValidityExpired;

  /// No description provided for @shareValidityMinSec.
  ///
  /// In en, this message translates to:
  /// **'{mins} min {secs} sec'**
  String shareValidityMinSec(int mins, String secs);

  /// No description provided for @shareValiditySeconds.
  ///
  /// In en, this message translates to:
  /// **'{secs} seconds'**
  String shareValiditySeconds(int secs);

  /// No description provided for @shareValidFor.
  ///
  /// In en, this message translates to:
  /// **'Valid for {text}'**
  String shareValidFor(String text);

  /// No description provided for @shareCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired'**
  String get shareCodeExpired;

  /// No description provided for @shareRegenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Code'**
  String get shareRegenerateCode;

  /// No description provided for @shareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get shareLinkCopied;

  /// No description provided for @shareCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get shareCopyLink;

  /// No description provided for @shareScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned {count} times'**
  String shareScanned(int count);

  /// No description provided for @shareRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get shareRevoke;

  /// No description provided for @shareInstructionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load instructions'**
  String get shareInstructionsLoadError;

  /// No description provided for @shareInstructionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'When a doctor leaves instructions after viewing a record you shared, they\'ll show up here.'**
  String get shareInstructionsEmpty;

  /// No description provided for @shareDoctorNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get shareDoctorNameFallback;

  /// No description provided for @shareDoctorInstructionRow.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name} · {institution}'**
  String shareDoctorInstructionRow(String name, String institution);

  /// No description provided for @profileMyProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileMyProfileTitle;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUser;

  /// No description provided for @profilePatientId.
  ///
  /// In en, this message translates to:
  /// **'Patient ID: {id}'**
  String profilePatientId(String id);

  /// No description provided for @profileSectionPersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL DETAILS'**
  String get profileSectionPersonalDetails;

  /// No description provided for @profileLabelDob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get profileLabelDob;

  /// No description provided for @profileLabelGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileLabelGender;

  /// No description provided for @profileLabelPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileLabelPhone;

  /// No description provided for @profileSectionPhysicalMetrics.
  ///
  /// In en, this message translates to:
  /// **'PHYSICAL METRICS'**
  String get profileSectionPhysicalMetrics;

  /// No description provided for @profileLabelHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get profileLabelHeight;

  /// No description provided for @profileLabelWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get profileLabelWeight;

  /// No description provided for @profileLabelBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get profileLabelBloodGroup;

  /// No description provided for @profileLabelBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get profileLabelBmi;

  /// No description provided for @profileBmiUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get profileBmiUnderweight;

  /// No description provided for @profileBmiNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get profileBmiNormal;

  /// No description provided for @profileBmiOverweight.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get profileBmiOverweight;

  /// No description provided for @profileBmiObese.
  ///
  /// In en, this message translates to:
  /// **'Obese'**
  String get profileBmiObese;

  /// No description provided for @profileSectionHealthDetails.
  ///
  /// In en, this message translates to:
  /// **'HEALTH DETAILS'**
  String get profileSectionHealthDetails;

  /// No description provided for @profileFailedUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo'**
  String get profileFailedUploadPhoto;

  /// No description provided for @profileCropPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop Photo'**
  String get profileCropPhotoTitle;

  /// No description provided for @profileCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Completion'**
  String get profileCompletionTitle;

  /// No description provided for @profileCompletionTapToComplete.
  ///
  /// In en, this message translates to:
  /// **'Tap to complete your medical profile'**
  String get profileCompletionTapToComplete;

  /// No description provided for @profileAllergiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileAllergiesLabel;

  /// No description provided for @profileNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get profileNoneRecorded;

  /// No description provided for @profileConditionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get profileConditionsLabel;

  /// No description provided for @profileNoMemberSelected.
  ///
  /// In en, this message translates to:
  /// **'No family member selected'**
  String get profileNoMemberSelected;

  /// No description provided for @profileMemberTitleFor.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Profile'**
  String profileMemberTitleFor(String name);

  /// No description provided for @profileSelectGenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get profileSelectGenderTitle;

  /// No description provided for @profileSelectBloodGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Blood Group'**
  String get profileSelectBloodGroupTitle;

  /// No description provided for @profileFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get profileFailedLoad;

  /// No description provided for @profileInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileInformationTitle;

  /// No description provided for @profileFailedToLoadWith.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String profileFailedToLoadWith(String error);

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccess;

  /// No description provided for @profileUpdateErrorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String profileUpdateErrorWith(String error);

  /// No description provided for @profileFailedUpdatePicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture.'**
  String get profileFailedUpdatePicture;

  /// No description provided for @profileSectionPersonalDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal Details'**
  String get profileSectionPersonalDetailsLabel;

  /// No description provided for @profileFieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get profileFieldFullName;

  /// No description provided for @profileHintFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get profileHintFullName;

  /// No description provided for @profileValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get profileValidationRequired;

  /// No description provided for @profileFieldDob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get profileFieldDob;

  /// No description provided for @profileDobPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get profileDobPlaceholder;

  /// No description provided for @profileFieldGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileFieldGender;

  /// No description provided for @profileHintSelectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get profileHintSelectGender;

  /// No description provided for @profileFieldPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get profileFieldPhoneNumber;

  /// No description provided for @profileSectionPhysicalMetricsLabel.
  ///
  /// In en, this message translates to:
  /// **'Physical Metrics'**
  String get profileSectionPhysicalMetricsLabel;

  /// No description provided for @profileFieldHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get profileFieldHeightCm;

  /// No description provided for @profileHintHeightExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 175'**
  String get profileHintHeightExample;

  /// No description provided for @profileFieldWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get profileFieldWeightKg;

  /// No description provided for @profileHintWeightExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 70'**
  String get profileHintWeightExample;

  /// No description provided for @profileFieldBloodGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get profileFieldBloodGroupLabel;

  /// No description provided for @profileHintSelectBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Blood Group'**
  String get profileHintSelectBloodGroup;

  /// No description provided for @profileSectionHealthDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Health Details'**
  String get profileSectionHealthDetailsLabel;

  /// No description provided for @profileFieldAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileFieldAllergies;

  /// No description provided for @profileHintAllergiesExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., Pollen, Penicillin...'**
  String get profileHintAllergiesExample;

  /// No description provided for @profileFieldExistingConditions.
  ///
  /// In en, this message translates to:
  /// **'Existing Conditions'**
  String get profileFieldExistingConditions;

  /// No description provided for @profileHintAddOtherConditions.
  ///
  /// In en, this message translates to:
  /// **'Add other conditions...'**
  String get profileHintAddOtherConditions;

  /// No description provided for @profileSaveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get profileSaveChangesButton;

  /// No description provided for @profileConditionAsthma.
  ///
  /// In en, this message translates to:
  /// **'Asthma'**
  String get profileConditionAsthma;

  /// No description provided for @profileConditionDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes'**
  String get profileConditionDiabetes;

  /// No description provided for @profileConditionEpilepsy.
  ///
  /// In en, this message translates to:
  /// **'Epilepsy'**
  String get profileConditionEpilepsy;

  /// No description provided for @profileConditionHypertension.
  ///
  /// In en, this message translates to:
  /// **'Hypertension'**
  String get profileConditionHypertension;

  /// No description provided for @profileConditionThyroidIssue.
  ///
  /// In en, this message translates to:
  /// **'Thyroid Issue'**
  String get profileConditionThyroidIssue;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Insights'**
  String get insightsTitle;

  /// No description provided for @insightsTitleFor.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Insights'**
  String insightsTitleFor(String name);

  /// No description provided for @insightsCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load insights'**
  String get insightsCouldNotLoad;

  /// No description provided for @insightsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get insightsOverview;

  /// No description provided for @insightsTotalRecords.
  ///
  /// In en, this message translates to:
  /// **'Total Records'**
  String get insightsTotalRecords;

  /// No description provided for @insightsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get insightsThisMonth;

  /// No description provided for @insightsActiveConditions.
  ///
  /// In en, this message translates to:
  /// **'Active Conditions'**
  String get insightsActiveConditions;

  /// No description provided for @insightsUnreadAlerts.
  ///
  /// In en, this message translates to:
  /// **'Unread Alerts'**
  String get insightsUnreadAlerts;

  /// No description provided for @insightsRecordsByType.
  ///
  /// In en, this message translates to:
  /// **'Records by Type'**
  String get insightsRecordsByType;

  /// No description provided for @insightsCouldNotLoadChart.
  ///
  /// In en, this message translates to:
  /// **'Could not load chart data'**
  String get insightsCouldNotLoadChart;

  /// No description provided for @insightsNoRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get insightsNoRecordsYet;

  /// No description provided for @insightsVitalTrends.
  ///
  /// In en, this message translates to:
  /// **'Vital Trends'**
  String get insightsVitalTrends;

  /// No description provided for @insightsBloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get insightsBloodGlucose;

  /// No description provided for @insightsHemoglobin.
  ///
  /// In en, this message translates to:
  /// **'Hemoglobin'**
  String get insightsHemoglobin;

  /// No description provided for @insightsBloodPressureSystolic.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure (Systolic)'**
  String get insightsBloodPressureSystolic;

  /// No description provided for @insightsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get insightsFailedToLoad;

  /// No description provided for @insightsNoDataRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'No data recorded yet'**
  String get insightsNoDataRecordedYet;

  /// No description provided for @insightsChartLabelLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get insightsChartLabelLab;

  /// No description provided for @insightsChartLabelRx.
  ///
  /// In en, this message translates to:
  /// **'Rx'**
  String get insightsChartLabelRx;

  /// No description provided for @insightsChartLabelRad.
  ///
  /// In en, this message translates to:
  /// **'Rad'**
  String get insightsChartLabelRad;

  /// No description provided for @insightsChartLabelVax.
  ///
  /// In en, this message translates to:
  /// **'Vax'**
  String get insightsChartLabelVax;

  /// No description provided for @insightsChartLabelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get insightsChartLabelOther;

  /// No description provided for @healthSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Summary'**
  String get healthSummaryTitle;

  /// No description provided for @healthSummaryTitleFor.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Health Summary'**
  String healthSummaryTitleFor(String name);

  /// No description provided for @healthSummaryCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load your health summary'**
  String get healthSummaryCouldNotLoad;

  /// No description provided for @healthSummaryActiveConditions.
  ///
  /// In en, this message translates to:
  /// **'Active Conditions'**
  String get healthSummaryActiveConditions;

  /// No description provided for @healthSummaryCurrentMedications.
  ///
  /// In en, this message translates to:
  /// **'Current Medications'**
  String get healthSummaryCurrentMedications;

  /// No description provided for @healthSummaryAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get healthSummaryAllergies;

  /// No description provided for @healthSummaryRecentLabsVitals.
  ///
  /// In en, this message translates to:
  /// **'Recent Labs & Vitals'**
  String get healthSummaryRecentLabsVitals;

  /// No description provided for @healthSummaryDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This overview is generated from your uploaded records by AI and may not be complete. Always consult your doctor for clinical decisions.'**
  String get healthSummaryDisclaimer;

  /// No description provided for @healthSummaryYourOverview.
  ///
  /// In en, this message translates to:
  /// **'Your Health Overview'**
  String get healthSummaryYourOverview;

  /// No description provided for @healthSummaryNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No health data yet'**
  String get healthSummaryNoDataYet;

  /// No description provided for @healthSummaryNoDataYetFor.
  ///
  /// In en, this message translates to:
  /// **'No health data yet for {name}'**
  String healthSummaryNoDataYetFor(String name);

  /// No description provided for @healthSummaryUploadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Upload medical records to build a complete health overview.'**
  String get healthSummaryUploadPrompt;

  /// No description provided for @profileCompletionPersonalDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Details'**
  String get profileCompletionPersonalDetailsTitle;

  /// No description provided for @profileCompletionPersonalDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start with your basic information.'**
  String get profileCompletionPersonalDetailsSubtitle;

  /// No description provided for @profileCompletionFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get profileCompletionFullNameRequired;

  /// No description provided for @profileCompletionDobFormat.
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get profileCompletionDobFormat;

  /// No description provided for @profileCompletionDobRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required'**
  String get profileCompletionDobRequired;

  /// No description provided for @profileCompletionGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a gender'**
  String get profileCompletionGenderRequired;

  /// No description provided for @profileCompletionPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'000-000-0000'**
  String get profileCompletionPhoneHint;

  /// No description provided for @profileCompletionPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get profileCompletionPhoneRequired;

  /// No description provided for @profileCompletionStep1Note.
  ///
  /// In en, this message translates to:
  /// **'This information helps doctors identify you accurately.'**
  String get profileCompletionStep1Note;

  /// No description provided for @profileCompletionNext.
  ///
  /// In en, this message translates to:
  /// **'Next →'**
  String get profileCompletionNext;

  /// No description provided for @profileCompletionStep1HelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 1 Help'**
  String get profileCompletionStep1HelpTitle;

  /// No description provided for @profileCompletionStep1HelpBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your personal details accurately. This helps healthcare providers identify you and personalize your care.'**
  String get profileCompletionStep1HelpBody;

  /// No description provided for @profileCompletionStep2SkipNotice.
  ///
  /// In en, this message translates to:
  /// **'You can complete this later from your profile'**
  String get profileCompletionStep2SkipNotice;

  /// No description provided for @profileCompletionPhysicalMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Physical Metrics'**
  String get profileCompletionPhysicalMetricsTitle;

  /// No description provided for @profileCompletionPhysicalMetricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us personalize your wellness journey by providing your key physical indicators.'**
  String get profileCompletionPhysicalMetricsSubtitle;

  /// No description provided for @profileCompletionStep2Note.
  ///
  /// In en, this message translates to:
  /// **'Your physical data is used exclusively to calculate BMI and customize nutritional recommendations. All data is encrypted.'**
  String get profileCompletionStep2Note;

  /// No description provided for @profileCompletionStep2HelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 2 Help'**
  String get profileCompletionStep2HelpTitle;

  /// No description provided for @profileCompletionStep2HelpBody.
  ///
  /// In en, this message translates to:
  /// **'Physical metrics help calculate your BMI and tailor nutritional recommendations. All fields are optional - you can skip and complete later.'**
  String get profileCompletionStep2HelpBody;

  /// No description provided for @profileCompletionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String profileCompletionSaveError(String error);

  /// No description provided for @profileCompletionSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Updated!'**
  String get profileCompletionSuccessTitle;

  /// No description provided for @profileCompletionSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your health profile has been saved.'**
  String get profileCompletionSuccessBody;

  /// No description provided for @profileCompletionGoToProfile.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile'**
  String get profileCompletionGoToProfile;

  /// No description provided for @profileCompletionAlmostThere.
  ///
  /// In en, this message translates to:
  /// **'Almost there!'**
  String get profileCompletionAlmostThere;

  /// No description provided for @profileCompletionStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'We use this information to provide personalized health insights and safety alerts.'**
  String get profileCompletionStep3Subtitle;

  /// No description provided for @profileCompletionSeparateWithCommas.
  ///
  /// In en, this message translates to:
  /// **'Separate items with commas'**
  String get profileCompletionSeparateWithCommas;

  /// No description provided for @profileCompletionHipaaCompliant.
  ///
  /// In en, this message translates to:
  /// **'HIPAA Compliant'**
  String get profileCompletionHipaaCompliant;

  /// No description provided for @profileCompletionSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure Storage'**
  String get profileCompletionSecureStorage;

  /// No description provided for @profileCompletionEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get profileCompletionEncrypted;

  /// No description provided for @profileCompletionPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Personal Data'**
  String get profileCompletionPersonalData;

  /// No description provided for @profileCompletionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get profileCompletionSaving;

  /// No description provided for @profileCompletionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish →'**
  String get profileCompletionFinish;

  /// No description provided for @profileCompletionStep3HelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 3 Help'**
  String get profileCompletionStep3HelpTitle;

  /// No description provided for @profileCompletionStep3HelpBody.
  ///
  /// In en, this message translates to:
  /// **'Your health details help generate personalized safety alerts and recommendations. You can update these anytime from your profile.'**
  String get profileCompletionStep3HelpBody;

  /// No description provided for @privacyPolicyAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get privacyPolicyAppBarTitle;

  /// No description provided for @privacyPolicyHeading.
  ///
  /// In en, this message translates to:
  /// **'How CurecordAI handles your data'**
  String get privacyPolicyHeading;

  /// No description provided for @privacyPolicyIntro.
  ///
  /// In en, this message translates to:
  /// **'This page explains what health data we collect, how it\'s used, and the controls you have over it.'**
  String get privacyPolicyIntro;

  /// No description provided for @privacyPolicyDataWeCollectTitle.
  ///
  /// In en, this message translates to:
  /// **'Data We Collect'**
  String get privacyPolicyDataWeCollectTitle;

  /// No description provided for @privacyPolicyDataWeCollectBody.
  ///
  /// In en, this message translates to:
  /// **'To provide your personal health record, we store the profile details you provide (name, date of birth, gender, contact information), the medical documents you upload, the structured clinical data extracted from those documents (conditions, medications, lab results, allergies, and visit history), and your conversations with the in-app AI assistant. We also record basic device and session metadata (IP address, device type, login timestamps) to keep your account secure.'**
  String get privacyPolicyDataWeCollectBody;

  /// No description provided for @privacyPolicyHowWeUseDataTitle.
  ///
  /// In en, this message translates to:
  /// **'How We Use Your Data'**
  String get privacyPolicyHowWeUseDataTitle;

  /// No description provided for @privacyPolicyHowWeUseDataBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is used exclusively to power the features you use: extracting structured health information from uploaded documents, generating AI summaries, answering questions about your records in AI Chat, computing your profile completion score, populating your Emergency Medical Card, and enabling secure sharing with family members, caregivers, or clinicians that you explicitly authorize.'**
  String get privacyPolicyHowWeUseDataBody;

  /// No description provided for @privacyPolicyAiProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Processing'**
  String get privacyPolicyAiProcessingTitle;

  /// No description provided for @privacyPolicyAiProcessingBody.
  ///
  /// In en, this message translates to:
  /// **'When a document is processed or you ask a question in AI Chat, the relevant document content or record data is sent to our AI processing provider solely to extract clinical data or generate a response. This data is used only to serve your request - it is not used to train third-party AI models, and it is not retained by the AI provider beyond what is required to process that single request.'**
  String get privacyPolicyAiProcessingBody;

  /// No description provided for @privacyPolicyStorageSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage & Security'**
  String get privacyPolicyStorageSecurityTitle;

  /// No description provided for @privacyPolicyStorageSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Uploaded documents are stored in encrypted cloud storage, and all data in transit is protected with TLS encryption. Access to your records is scoped to your account and any family members or caregivers you explicitly grant access to. You can revoke a login session for this device at any time by logging out, which immediately invalidates the associated access and refresh tokens.'**
  String get privacyPolicyStorageSecurityBody;

  /// No description provided for @privacyPolicyFamilyAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Family & Caregiver Access'**
  String get privacyPolicyFamilyAccessTitle;

  /// No description provided for @privacyPolicyFamilyAccessBody.
  ///
  /// In en, this message translates to:
  /// **'If you add family members or caregivers to your account, they can only view records and data explicitly scoped to the family member profile you created for them. You remain in control of what each family member profile contains and can remove access at any time from Family Management.'**
  String get privacyPolicyFamilyAccessBody;

  /// No description provided for @privacyPolicySharingCliniciansTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing With Clinicians'**
  String get privacyPolicySharingCliniciansTitle;

  /// No description provided for @privacyPolicySharingCliniciansBody.
  ///
  /// In en, this message translates to:
  /// **'Generating a QR code from your dashboard creates a time-limited, revocable share link to selected records. Clinicians who scan it can view only the records included in that share - never your full account - and you can revoke access at any time.'**
  String get privacyPolicySharingCliniciansBody;

  /// No description provided for @privacyPolicyYourRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get privacyPolicyYourRightsTitle;

  /// No description provided for @privacyPolicyYourRightsBody.
  ///
  /// In en, this message translates to:
  /// **'You can request a full export of your health data at any time from Settings → Export My Data, review and withdraw specific consents from Consent Management, and permanently delete records you no longer want stored. Deleted records are removed from active use immediately and purged from backups on our standard retention schedule.'**
  String get privacyPolicyYourRightsBody;

  /// No description provided for @privacyPolicyDataRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Retention'**
  String get privacyPolicyDataRetentionTitle;

  /// No description provided for @privacyPolicyDataRetentionBody.
  ///
  /// In en, this message translates to:
  /// **'We retain your data for as long as your account remains active. If you delete a record, it is immediately hidden from the app and permanently purged from our systems within the retention window described above. If you delete your account, all associated personal and medical data is scheduled for permanent deletion.'**
  String get privacyPolicyDataRetentionBody;

  /// No description provided for @privacyPolicyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get privacyPolicyContactTitle;

  /// No description provided for @privacyPolicyContactBody.
  ///
  /// In en, this message translates to:
  /// **'If you have questions about how your data is handled, reach out to our support team from the Support link below and we\'ll be glad to help.'**
  String get privacyPolicyContactBody;

  /// No description provided for @privacyControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Controls'**
  String get privacyControlsTitle;

  /// No description provided for @privacyControlsBiometricLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Lock'**
  String get privacyControlsBiometricLockTitle;

  /// No description provided for @privacyControlsBiometricLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID or fingerprint to unlock'**
  String get privacyControlsBiometricLockSubtitle;

  /// No description provided for @privacyControlsAppLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App Lock on Background'**
  String get privacyControlsAppLockTitle;

  /// No description provided for @privacyControlsAppLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock app when switching tasks'**
  String get privacyControlsAppLockSubtitle;

  /// No description provided for @privacyControlsScreenshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Screenshot Prevention'**
  String get privacyControlsScreenshotTitle;

  /// No description provided for @privacyControlsScreenshotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots in app'**
  String get privacyControlsScreenshotSubtitle;

  /// No description provided for @privacyControlsNote.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings help keep your medical data safe. Biometric lock ensures only you can access the app. Changes are saved automatically.'**
  String get privacyControlsNote;

  /// No description provided for @dataSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Sharing'**
  String get dataSharingTitle;

  /// No description provided for @dataSharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage which doctors and hospitals can access your records'**
  String get dataSharingSubtitle;

  /// No description provided for @dataSharingAddNewAccess.
  ///
  /// In en, this message translates to:
  /// **'Add New Access'**
  String get dataSharingAddNewAccess;

  /// No description provided for @dataSharingRevokeAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Access'**
  String get dataSharingRevokeAccessTitle;

  /// No description provided for @dataSharingRevokeAccessConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove access for {name}?'**
  String dataSharingRevokeAccessConfirm(String name);

  /// No description provided for @dataSharingRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get dataSharingRevoke;

  /// No description provided for @dataSharingRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke access'**
  String get dataSharingRevokeFailed;

  /// No description provided for @dataSharingAccessFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get dataSharingAccessFull;

  /// No description provided for @dataSharingAccessRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get dataSharingAccessRead;

  /// No description provided for @dataSharingUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String dataSharingUntil(String date);

  /// No description provided for @dataSharingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shared access yet'**
  String get dataSharingEmptyTitle;

  /// No description provided for @dataSharingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add New Access\" to grant access to doctors or hospitals.'**
  String get dataSharingEmptyBody;

  /// No description provided for @dataSharingAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add access'**
  String get dataSharingAddFailed;

  /// No description provided for @dataSharingDoctorHospitalName.
  ///
  /// In en, this message translates to:
  /// **'Doctor / Hospital Name'**
  String get dataSharingDoctorHospitalName;

  /// No description provided for @dataSharingEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get dataSharingEnterName;

  /// No description provided for @dataSharingAccessType.
  ///
  /// In en, this message translates to:
  /// **'Access Type'**
  String get dataSharingAccessType;

  /// No description provided for @dataSharingGrantedUntilOptional.
  ///
  /// In en, this message translates to:
  /// **'Granted Until (optional)'**
  String get dataSharingGrantedUntilOptional;

  /// No description provided for @dataSharingNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get dataSharingNoExpiry;

  /// No description provided for @dataSharingGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant Access'**
  String get dataSharingGrantAccess;

  /// No description provided for @consentManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Consent Management'**
  String get consentManagementTitle;

  /// No description provided for @consentOptionalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL CONSENTS'**
  String get consentOptionalSectionTitle;

  /// No description provided for @consentRequiredSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED AGREEMENTS'**
  String get consentRequiredSectionTitle;

  /// No description provided for @consentAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics & Usage Data'**
  String get consentAnalyticsTitle;

  /// No description provided for @consentAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app by sharing anonymous usage statistics'**
  String get consentAnalyticsSubtitle;

  /// No description provided for @consentMarketingTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketing Communications'**
  String get consentMarketingTitle;

  /// No description provided for @consentMarketingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive updates, tips, and health news from CurecordAI'**
  String get consentMarketingSubtitle;

  /// No description provided for @consentTermsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get consentTermsOfServiceTitle;

  /// No description provided for @consentTermsOfServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required to use CurecordAI'**
  String get consentTermsOfServiceSubtitle;

  /// No description provided for @consentPrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get consentPrivacyPolicyTitle;

  /// No description provided for @consentPrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle your medical data'**
  String get consentPrivacyPolicySubtitle;

  /// No description provided for @consentDataProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Processing'**
  String get consentDataProcessingTitle;

  /// No description provided for @consentDataProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Processing your health information to provide services'**
  String get consentDataProcessingSubtitle;

  /// No description provided for @consentWithdrawalNote.
  ///
  /// In en, this message translates to:
  /// **'Withdrawing a consent takes effect immediately. Required agreements cannot be withdrawn while using the app.'**
  String get consentWithdrawalNote;

  /// No description provided for @consentUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update consent. Please try again.'**
  String get consentUpdateFailed;

  /// No description provided for @consentAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get consentAccepted;

  /// No description provided for @consentNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get consentNotSet;

  /// No description provided for @recordDetailIcd11Code.
  ///
  /// In en, this message translates to:
  /// **'ICD-11: {code}'**
  String recordDetailIcd11Code(String code);

  /// No description provided for @errorSaveChangesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save changes.'**
  String get errorSaveChangesFailed;

  /// No description provided for @recordDeletePermanentBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this record. This action cannot be undone.'**
  String get recordDeletePermanentBody;

  /// No description provided for @recordDocumentLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Document link is not available.'**
  String get recordDocumentLinkUnavailable;

  /// No description provided for @recordDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Details'**
  String get recordDetailsTitle;

  /// No description provided for @recordLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load record.'**
  String get recordLoadFailed;

  /// No description provided for @recordDocumentWord.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get recordDocumentWord;

  /// No description provided for @recordDocumentDetails.
  ///
  /// In en, this message translates to:
  /// **'Document Details'**
  String get recordDocumentDetails;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @commonTapToSet.
  ///
  /// In en, this message translates to:
  /// **'Tap to set'**
  String get commonTapToSet;

  /// No description provided for @fieldPatientName.
  ///
  /// In en, this message translates to:
  /// **'Patient Name'**
  String get fieldPatientName;

  /// No description provided for @fieldIssuingLabOrg.
  ///
  /// In en, this message translates to:
  /// **'Lab / Organization'**
  String get fieldIssuingLabOrg;

  /// No description provided for @fieldReferringDoctor.
  ///
  /// In en, this message translates to:
  /// **'Referring Doctor'**
  String get fieldReferringDoctor;

  /// No description provided for @fieldFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fieldFile;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @recordAiExtracting.
  ///
  /// In en, this message translates to:
  /// **'AI is extracting information from your document...'**
  String get recordAiExtracting;

  /// No description provided for @recordAiProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'AI processing failed. Please try again.'**
  String get recordAiProcessingFailed;

  /// No description provided for @recordViewOriginal.
  ///
  /// In en, this message translates to:
  /// **'View Original'**
  String get recordViewOriginal;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get commonSaveChanges;

  /// No description provided for @clinicalLabResultsVitals.
  ///
  /// In en, this message translates to:
  /// **'Lab Results & Vitals'**
  String get clinicalLabResultsVitals;

  /// No description provided for @clinicalConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get clinicalConditions;

  /// No description provided for @clinicalMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get clinicalMedications;

  /// No description provided for @clinicalVisitsEncounters.
  ///
  /// In en, this message translates to:
  /// **'Visits & Encounters'**
  String get clinicalVisitsEncounters;

  /// No description provided for @clinicalEditCondition.
  ///
  /// In en, this message translates to:
  /// **'Edit Condition'**
  String get clinicalEditCondition;

  /// No description provided for @clinicalEditMedication.
  ///
  /// In en, this message translates to:
  /// **'Edit Medication'**
  String get clinicalEditMedication;

  /// No description provided for @clinicalEditObservation.
  ///
  /// In en, this message translates to:
  /// **'Edit Observation'**
  String get clinicalEditObservation;

  /// No description provided for @clinicalEditAllergy.
  ///
  /// In en, this message translates to:
  /// **'Edit Allergy'**
  String get clinicalEditAllergy;

  /// No description provided for @clinicalEditVisit.
  ///
  /// In en, this message translates to:
  /// **'Edit Visit'**
  String get clinicalEditVisit;

  /// No description provided for @clinicalConditionField.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get clinicalConditionField;

  /// No description provided for @clinicalSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get clinicalSeverity;

  /// No description provided for @clinicalMedicationField.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get clinicalMedicationField;

  /// No description provided for @clinicalDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get clinicalDosage;

  /// No description provided for @clinicalFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get clinicalFrequency;

  /// No description provided for @clinicalTestVitalName.
  ///
  /// In en, this message translates to:
  /// **'Test / Vital Name'**
  String get clinicalTestVitalName;

  /// No description provided for @clinicalValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get clinicalValue;

  /// No description provided for @clinicalUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get clinicalUnit;

  /// No description provided for @clinicalInterpretation.
  ///
  /// In en, this message translates to:
  /// **'Interpretation'**
  String get clinicalInterpretation;

  /// No description provided for @clinicalSubstance.
  ///
  /// In en, this message translates to:
  /// **'Substance'**
  String get clinicalSubstance;

  /// No description provided for @clinicalCriticality.
  ///
  /// In en, this message translates to:
  /// **'Criticality'**
  String get clinicalCriticality;

  /// No description provided for @clinicalReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get clinicalReaction;

  /// No description provided for @clinicalHospitalClinic.
  ///
  /// In en, this message translates to:
  /// **'Hospital / Clinic'**
  String get clinicalHospitalClinic;

  /// No description provided for @clinicalVisitType.
  ///
  /// In en, this message translates to:
  /// **'Visit Type'**
  String get clinicalVisitType;

  /// No description provided for @clinicalAiExtractedHint.
  ///
  /// In en, this message translates to:
  /// **'AI-extracted from your document. Review and correct if needed.'**
  String get clinicalAiExtractedHint;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @interpNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get interpNormal;

  /// No description provided for @interpLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get interpLow;

  /// No description provided for @interpHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get interpHigh;

  /// No description provided for @interpCriticalLow.
  ///
  /// In en, this message translates to:
  /// **'Critical Low'**
  String get interpCriticalLow;

  /// No description provided for @interpCriticalHigh.
  ///
  /// In en, this message translates to:
  /// **'Critical High'**
  String get interpCriticalHigh;

  /// No description provided for @interpAbnormal.
  ///
  /// In en, this message translates to:
  /// **'Abnormal'**
  String get interpAbnormal;

  /// No description provided for @interpVeryAbnormal.
  ///
  /// In en, this message translates to:
  /// **'Very Abnormal'**
  String get interpVeryAbnormal;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @recordTypeSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Record Type'**
  String get recordTypeSheetTitle;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @recordProcessingFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Processing failed: {reason}'**
  String recordProcessingFailedWithReason(String reason);

  /// No description provided for @clinicalRefRange.
  ///
  /// In en, this message translates to:
  /// **'Ref: {range}'**
  String clinicalRefRange(String range);

  /// No description provided for @clinicalDoctorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name}'**
  String clinicalDoctorPrefix(String name);

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @chatInfoAria.
  ///
  /// In en, this message translates to:
  /// **'How to use AI Health Assistant'**
  String get chatInfoAria;

  /// No description provided for @chatInfoModalTitle.
  ///
  /// In en, this message translates to:
  /// **'How to use AI Health Assistant'**
  String get chatInfoModalTitle;

  /// No description provided for @chatInfoAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health'**
  String get chatInfoAskTitle;

  /// No description provided for @chatInfoAskDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your health, and the assistant answers based on the documents you\'ve already uploaded.'**
  String get chatInfoAskDescription;

  /// No description provided for @chatInfoAttachTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach records from Health Vault'**
  String get chatInfoAttachTitle;

  /// No description provided for @chatInfoAttachDescription.
  ///
  /// In en, this message translates to:
  /// **'Attach specific documents from your Health Vault to a question for more targeted, context-aware answers.'**
  String get chatInfoAttachDescription;

  /// No description provided for @chatInfoSummarizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Summarize reports'**
  String get chatInfoSummarizeTitle;

  /// No description provided for @chatInfoSummarizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask the assistant to summarize a lab report, prescription, or X-ray in plain language.'**
  String get chatInfoSummarizeDescription;

  /// No description provided for @chatInfoUnderstandTitle.
  ///
  /// In en, this message translates to:
  /// **'Understand your health'**
  String get chatInfoUnderstandTitle;

  /// No description provided for @chatInfoUnderstandDescription.
  ///
  /// In en, this message translates to:
  /// **'Get help understanding medical terms, results, and what they mean for your overall health.'**
  String get chatInfoUnderstandDescription;

  /// No description provided for @familyInfoAria.
  ///
  /// In en, this message translates to:
  /// **'How family management works'**
  String get familyInfoAria;

  /// No description provided for @familyInfoModalTitle.
  ///
  /// In en, this message translates to:
  /// **'How Family Management Works'**
  String get familyInfoModalTitle;

  /// No description provided for @familyInfoNoLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'No separate login needed'**
  String get familyInfoNoLoginTitle;

  /// No description provided for @familyInfoNoLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Family members do not need their own account. You manage everything from your own login.'**
  String get familyInfoNoLoginDescription;

  /// No description provided for @familyInfoProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Individual profiles'**
  String get familyInfoProfilesTitle;

  /// No description provided for @familyInfoProfilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Each family member gets their own separate documents and medications, kept apart from your own records.'**
  String get familyInfoProfilesDescription;

  /// No description provided for @familyInfoTogetherTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage together'**
  String get familyInfoTogetherTitle;

  /// No description provided for @familyInfoTogetherDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload documents, track medications, and view AI summaries for each family member, just like your own profile.'**
  String get familyInfoTogetherDescription;

  /// No description provided for @familyInfoShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share access instantly'**
  String get familyInfoShareTitle;

  /// No description provided for @familyInfoShareDescription.
  ///
  /// In en, this message translates to:
  /// **'Generate a QR share for any family member\'s records individually, same as your own.'**
  String get familyInfoShareDescription;

  /// No description provided for @medicationsInfoAria.
  ///
  /// In en, this message translates to:
  /// **'How medications work'**
  String get medicationsInfoAria;

  /// No description provided for @medicationsInfoModalTitle.
  ///
  /// In en, this message translates to:
  /// **'How Medications Work'**
  String get medicationsInfoModalTitle;

  /// No description provided for @medicationsInfoWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Who it is for'**
  String get medicationsInfoWhoTitle;

  /// No description provided for @medicationsInfoWhoDescription.
  ///
  /// In en, this message translates to:
  /// **'Medications can be added for yourself or for a family member you manage.'**
  String get medicationsInfoWhoDescription;

  /// No description provided for @medicationsInfoAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add manually or import'**
  String get medicationsInfoAddTitle;

  /// No description provided for @medicationsInfoAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter details yourself, or pull them from an already uploaded document.'**
  String get medicationsInfoAddDescription;

  /// No description provided for @medicationsInfoTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track status'**
  String get medicationsInfoTrackTitle;

  /// No description provided for @medicationsInfoTrackDescription.
  ///
  /// In en, this message translates to:
  /// **'Medications can be marked Active, Paused, or Completed using the tabs above.'**
  String get medicationsInfoTrackDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'ur':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsUrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
