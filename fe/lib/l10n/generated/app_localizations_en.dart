// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navRecords => 'Records';

  @override
  String get navAi => 'AI';

  @override
  String get navMedications => 'Medications';

  @override
  String get navInsights => 'Insights';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAiAssistant => 'AI Assistant';

  @override
  String get appName => 'CurecordAI';

  @override
  String get settingsSectionAccount => 'ACCOUNT';

  @override
  String get settingsProfileInformation => 'Profile Information';

  @override
  String get settingsProfileInformationSubtitle =>
      'Update your medical details';

  @override
  String get settingsFamilyManagement => 'Family Management';

  @override
  String get settingsFamilyManagementSubtitle => 'Add or edit family members';

  @override
  String get settingsSectionPreferences => 'PREFERENCES';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'English / Urdu / Roman Urdu';

  @override
  String get langEnglish => 'English';

  @override
  String get langUrdu => 'اردو';

  @override
  String get langRomanUrdu => 'Roman Urdu';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeCurrentDark => 'Current: Dark Mode';

  @override
  String get settingsThemeCurrentLight => 'Current: Light Mode';

  @override
  String get settingsSectionMedical => 'MEDICAL';

  @override
  String get settingsEmergencyCard => 'Emergency Card Settings';

  @override
  String get settingsEmergencyCardSubtitle => 'SOS contacts & Medical ID';

  @override
  String get settingsSectionPrivacyData => 'PRIVACY & DATA';

  @override
  String get settingsDataPrivacy => 'Data & Privacy';

  @override
  String get settingsDataPrivacySubtitle => 'How we handle your health data';

  @override
  String get settingsExportData => 'Export My Data';

  @override
  String get settingsExportDataSubtitle =>
      'Download a copy of your health data';

  @override
  String get settingsConsentManagement => 'Consent Management';

  @override
  String get settingsConsentManagementSubtitle =>
      'Review & manage your data consents';

  @override
  String get settingsLogOut => 'Log Out';

  @override
  String get settingsLogOutConfirmTitle => 'Log Out';

  @override
  String get settingsLogOutConfirmBody => 'Are you sure you want to log out?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonErrorOccurred => 'An error occurred';

  @override
  String get settingsExportDataTitle => 'Export My Data';

  @override
  String get settingsExportDataBody =>
      'We\'ll prepare a full copy of your health data. This may take up to 30 days. You\'ll be notified when it\'s ready.';

  @override
  String get settingsRequestExport => 'Request Export';

  @override
  String get settingsExportRequestedSnack =>
      'Export requested. You\'ll be notified when ready.';

  @override
  String get settingsExportInProgressError =>
      'An export is already in progress.';

  @override
  String get settingsExportFailedError =>
      'Failed to request export. Please try again.';

  @override
  String get settingsAvatarUploadFailed => 'Failed to upload avatar';

  @override
  String get settingsManagedByYou => 'Managed by you';

  @override
  String get settingsProfileCompletion => 'Profile Completion';

  @override
  String get settingsProfileCompletionHint =>
      'Complete your medical history to help doctors provide better care.';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsAppVersion => 'CurecordAI v1.0.0';

  @override
  String get authWelcomeBack => 'Welcome Back';

  @override
  String get authLoginSubtitle => 'Log in to view your medical records.';

  @override
  String get authContinueWithPhone => 'Continue with Phone';

  @override
  String get authContinueWithEmail => 'Continue with Email';

  @override
  String get authNewToApp => 'New to CurecordAI? ';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authCreateAccountTitle => 'Create your Account';

  @override
  String get authCreateAccountSubtitle =>
      'Sign up to start managing your medical records.';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get authLogIn => 'Log in';

  @override
  String get otpVerifyTitle => 'Verify Your Number';

  @override
  String get otpSubtitlePrefix => 'Enter the 6-digit code sent to ';

  @override
  String get otpResendCodeIn => 'Resend code in ';

  @override
  String get otpResendSms => 'Resend SMS';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpTermsPrefix => 'By continuing you agree to ';

  @override
  String get otpTermsLink => 'Terms & Privacy Policy';

  @override
  String get otpIncompleteError => 'Please enter the complete 6-digit code';

  @override
  String get otpAlreadyRegisteredError =>
      'This number is already registered. Please log in.';

  @override
  String get otpNotFoundError =>
      'No account found for this number. Please sign up.';

  @override
  String get otpInvalidError => 'Invalid OTP. Please try again.';

  @override
  String get otpResendFailedError => 'Failed to resend OTP. Please try again.';

  @override
  String get homeRecentActivity => 'Recent Activity';

  @override
  String get homeUploadDocument => 'Upload Document';

  @override
  String get homeUploadDocumentSubtitle => 'Reports & Prescriptions';

  @override
  String get homeAskAi => 'Ask AI';

  @override
  String get homeAskAiSubtitle => 'Instant Medical Insights';

  @override
  String get homeGenerateQr => 'Generate QR';

  @override
  String get homeGenerateQrSubtitle => 'Quick Profile Share';

  @override
  String get homeViewSummary => 'View Summary';

  @override
  String get homeViewSummarySubtitle => 'Health Record Preview';

  @override
  String get homeMedications => 'Medications';

  @override
  String get homeMedicationsSubtitle => 'Reminders & Schedules';

  @override
  String get homeDetected => 'Detected';

  @override
  String get homeMedicationsActive => 'Active';

  @override
  String get homeYourDashboard => 'Your Dashboard';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingNight => 'Good night';

  @override
  String get homeNudgeUnreadInstructionMessage =>
      'Your doctor left new instructions.';

  @override
  String get homeNudgeUnreadInstructionButton => 'View instructions';

  @override
  String get homeNudgeNoDocumentsMessage =>
      'Upload your first record to get started.';

  @override
  String get homeNudgeNoDocumentsButton => 'Upload document';

  @override
  String get homeNudgeNoMedicationsMessage =>
      '0 active medications. Add yours to stay on track.';

  @override
  String get homeNudgeNoMedicationsButton => 'Add medication';

  @override
  String get homeRotatingTip1 =>
      'Try asking the AI assistant to explain any report in plain language.';

  @override
  String get homeRotatingTip2 =>
      'Your records are only visible to you and doctors you choose to share with.';

  @override
  String get homeRotatingTip3 =>
      'You have kept your records organized, nice work staying on top of things.';

  @override
  String get homeTotalDocuments => 'Total Documents';

  @override
  String get homeUploadedLabel => 'Uploaded';

  @override
  String get homeActiveLabel => 'Active';

  @override
  String get homeNoMedicationsYet => 'None added yet';

  @override
  String get homeAddMedicationsHint =>
      'Add medications to track refills and interactions.';

  @override
  String homeMedicationsReviewedAgo(String time) {
    return 'Reviewed $time ago';
  }

  @override
  String get homeActiveAllergiesAlert => 'You have active allergies';

  @override
  String get homeViewDetails => 'View details';

  @override
  String get homeRecentDocuments => 'Recent Documents';

  @override
  String get homeNoDocumentsMessage =>
      'No documents yet. Upload your first prescription or lab report to get started.';

  @override
  String get homeRecentConversations => 'Recent AI Conversations';

  @override
  String get homeOpenAssistant => 'Open assistant';

  @override
  String get homeNoConversationsMessage =>
      'No conversations yet. Ask the AI assistant a question about your health records.';

  @override
  String get homeConversationsLoadFailed =>
      'Could not load recent conversations';

  @override
  String homeMessagesCount(int count) {
    return '$count messages';
  }

  @override
  String get homeShareWithDoctor => 'Share with Doctor';

  @override
  String get homeShareWithDoctorSubtitle => 'Quick Profile Share';

  @override
  String get homeNewTag => 'New';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeProfileCompletePrefix => 'Your profile is ';

  @override
  String get homeProfileCompleteSuffix =>
      ' complete. Finish the\nremaining details ';

  @override
  String get homeHereLink => 'here';

  @override
  String get homeSwitchProfile => 'Switch profile';

  @override
  String get homeOwnerYou => 'Owner · You';

  @override
  String get homeAddFamilyMember => 'Add family member';

  @override
  String get homeNoRecentActivity => 'No recent activity';

  @override
  String homeMemberNoRecentActivity(String name) {
    return '$name has no recent activity';
  }

  @override
  String get homeUploadFirstRecord =>
      'Upload your first medical document to get started';

  @override
  String get homeUploadRecord => 'Upload Record';

  @override
  String get homeDefaultRecordType => 'Medical Record';

  @override
  String homeMemberDashboardTitle(String name) {
    return '$name\'s Dashboard';
  }

  @override
  String get homeOwnerHasAllergies => 'You have active allergies';

  @override
  String homeMemberHasAllergies(String name) {
    return '$name has active allergies';
  }

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get commonOr => 'or';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonGetStarted => 'Get Started';

  @override
  String get commonSkipForNow => 'Skip for now';

  @override
  String get commonFinish => 'Finish';

  @override
  String get authIncorrectEmailOrPassword => 'Incorrect email or password';

  @override
  String get authGoogleSignInFailed =>
      'Google sign-in failed. Please try again.';

  @override
  String get authEmailLoginTitle => 'Email Login';

  @override
  String get authEmailLoginSubtitle =>
      'Please enter your Email and Password to Continue';

  @override
  String get authLogin => 'Login';

  @override
  String get authSigningIn => 'Signing in...';

  @override
  String get authGoogle => 'Google';

  @override
  String get authApple => 'Apple';

  @override
  String get authEmailAlreadyRegistered =>
      'Email already registered. Please log in.';

  @override
  String get authSignUpFailed => 'Sign up failed. Please try again.';

  @override
  String get authSignupSubtitle => 'Please fill in your details to continue';

  @override
  String get authSignUpButton => 'Sign up';

  @override
  String get authPhoneLoginTitle => 'Phone Login';

  @override
  String get authPhoneLoginSubtitle =>
      'Login with your phone number to access your health records';

  @override
  String get authSendOtp => 'Send OTP';

  @override
  String get authPhoneAlreadyRegistered =>
      'Number already registered. Try logging in.';

  @override
  String get authPhoneSignupSubtitle => 'We\'ll send you a verification code.';

  @override
  String get authCreateAccountLower => 'Create your account';

  @override
  String get authPhoneVerifiedSetupProfile =>
      'Your phone is verified. Let\'s set up your profile.';

  @override
  String get authCreateAccountButton => 'Create Account';

  @override
  String get authTermsFooter =>
      'By continuing, you agree to our Terms of Service\nand Privacy Policy';

  @override
  String get authRegistrationFailed => 'Registration failed. Please try again.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get hintEmail => 'Your email address';

  @override
  String get fieldPassword => 'Password';

  @override
  String get hintPassword => 'Your password';

  @override
  String get fieldFullName => 'Full Name';

  @override
  String get hintFullName => 'Your full name';

  @override
  String get fieldConfirmPassword => 'Confirm Password';

  @override
  String get hintConfirmPassword => 'Confirm your password';

  @override
  String get fieldPhoneNumber => 'Phone Number';

  @override
  String get hintPhoneNumber => 'Phone number';

  @override
  String get validationEmailRequired => 'Email is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email';

  @override
  String get validationPasswordRequired => 'Password is required';

  @override
  String get validationNameMinLength =>
      'Full name must be at least 2 characters';

  @override
  String get validationPasswordMin8 => 'Minimum 8 characters';

  @override
  String get validationPasswordUppercase =>
      'Must contain at least 1 uppercase letter';

  @override
  String get validationPasswordNumber => 'Must contain at least 1 number';

  @override
  String get validationPasswordsMismatch => 'Passwords do not match';

  @override
  String get validationPhoneRequired => 'Please enter your phone number';

  @override
  String get validationFullNameMinLength =>
      'Please enter your full name (at least 2 characters)';

  @override
  String get otpVerifyEmailTitle => 'Verify Your Email';

  @override
  String get otpResendCode => 'Resend code';

  @override
  String get otpSendFailedError =>
      'Failed to send OTP. Check your number and try again.';

  @override
  String get splashTagline => 'Your Health, Always With You';

  @override
  String get successAllSet => 'You\'re All Set!';

  @override
  String get successWelcomeBack => 'Welcome Back!';

  @override
  String get successNewUserBody =>
      'Your account has been created successfully.\nYour health journey starts now.';

  @override
  String get successReturningUserBody =>
      'You have successfully logged in.\nYour health records are ready.';

  @override
  String get successGoToDashboard => 'Go to Dashboard';

  @override
  String get carousel1Title => 'Store All Your\nMedical Records';

  @override
  String get carousel1Subtitle =>
      'Keep prescriptions, reports, and X-rays safe in one secure vault.';

  @override
  String get carousel2Title => 'Share With Your\nDoctor Instantly';

  @override
  String get carousel2Subtitle =>
      'Generate a QR code so doctors can view your history without any app.';

  @override
  String get carousel3Title => 'Set Up Your\nEmergency Widget';

  @override
  String get carousel3Subtitle =>
      'Keep critical health info one glance away, even on your lock screen.';

  @override
  String get onboardingStep1Of3 => 'Step 1 of 3';

  @override
  String get onboardingStep2Of3 => 'Step 2 of 3';

  @override
  String get onboardingStep3Of3 => 'Step 3 of 3';

  @override
  String get onboardingTellUsTitle => 'Tell Us About Yourself';

  @override
  String get onboardingTellUsSubtitle =>
      'This helps us personalize your health vault.';

  @override
  String get fieldFullNameRequired => 'Full Name *';

  @override
  String get fieldYearOfBirthRequired => 'Year of Birth *';

  @override
  String get hintYearOfBirth => 'Year of birth';

  @override
  String get fieldGenderRequired => 'Gender *';

  @override
  String get hintSelectGender => 'Select gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get genderPreferNotToSay => 'Prefer not to say';

  @override
  String get validationYearRequired => 'Year of birth is required';

  @override
  String get validationYearInvalid => 'Enter a valid 4-digit year';

  @override
  String validationYearRange(int year) {
    return 'Enter a year between 1900 and $year';
  }

  @override
  String get validationMinAge13 => 'You must be at least 13 years old';

  @override
  String get validationGenderRequired => 'Please select your gender';

  @override
  String get onboardingPhysicalMetricsTitle => 'Physical Metrics';

  @override
  String get onboardingPhysicalMetricsSubtitle =>
      'Help us personalize your wellness journey...';

  @override
  String get fieldHeightCm => 'Height (cm)';

  @override
  String get hintHeightCm => 'Height in cm';

  @override
  String get fieldWeightKg => 'Weight (kg)';

  @override
  String get hintWeightKg => 'Weight in kg';

  @override
  String get fieldBloodGroup => 'Blood Group';

  @override
  String get hintSelectBloodGroup => 'Select blood group';

  @override
  String get onboardingPhysicalDataNotice =>
      'Your physical data is used exclusively to calculate BMI and customize nutritional recommendations. All data is encrypted.';

  @override
  String get validationHeightRange => 'Enter a height between 50 and 300 cm';

  @override
  String get validationWeightRange => 'Enter a weight between 1 and 500 kg';

  @override
  String get onboardingAlmostThereTitle => 'Almost there!';

  @override
  String get onboardingAlmostThereSubtitle =>
      'We use this information to provide personalized health insights...';

  @override
  String get fieldAllergies => 'Allergies';

  @override
  String get hintAllergiesExample => 'e.g., Pollen, Penicillin...';

  @override
  String get helperSeparateWithCommas => 'Separate items with commas';

  @override
  String get fieldExistingConditions => 'Existing Conditions';

  @override
  String get hintAddOtherConditions => 'Add other conditions...';

  @override
  String get badgeHipaaSecureStorage => 'HIPAA Compliant\nSecure Storage';

  @override
  String get badgeEncryptedPersonalData => 'Encrypted\nPersonal Data';

  @override
  String get onboardingSaveProfileFailed =>
      'Could not save profile. Update it later in settings.';

  @override
  String get conditionAsthma => 'Asthma';

  @override
  String get conditionDiabetes => 'Diabetes';

  @override
  String get conditionEpilepsy => 'Epilepsy';

  @override
  String get conditionHypertension => 'Hypertension';

  @override
  String get conditionThyroidIssue => 'Thyroid Issue';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDelete => 'Delete';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get recordsTabAll => 'All';

  @override
  String get recordsTabPrescriptions => 'Prescriptions';

  @override
  String get recordsTabMedicalReports => 'Medical Reports';

  @override
  String get recordsTabXRays => 'X-Rays';

  @override
  String get recordsTabLab => 'Lab';

  @override
  String get recordsTabOther => 'Other';

  @override
  String get recordsFolder => 'Folder';

  @override
  String get recordsFolderName => 'Folder Name';

  @override
  String get recordsFolderNameHint => 'e.g. Cardiology, Orthopedic';

  @override
  String get recordsFolderNameRequired => 'Please enter a folder name.';

  @override
  String get recordsCreateFolderFailed =>
      'Failed to create folder. Please try again.';

  @override
  String get recordsCreateNewFolder => 'Create New Folder';

  @override
  String get recordsCreateFolderSubtitle =>
      'Organize records by health condition';

  @override
  String get recordsSelectIcon => 'Select Icon';

  @override
  String get recordsCreateFolder => 'Create Folder';

  @override
  String get recordsLoadFailed => 'Failed to load records';

  @override
  String get recordsEmptyDescription =>
      'No documents found. Try a different search or category, or upload a new document to your health vault.';

  @override
  String get recordsSearchPlaceholder => 'Search documents';

  @override
  String get recordsUntitled => 'Untitled';

  @override
  String get recordsAnalysing => 'Analysing…';

  @override
  String get recordsViewAiSummary => 'View AI Summary';

  @override
  String get recordsExplainWithAi => 'Explain with AI';

  @override
  String get recordsDeleteTitle => 'Delete Record';

  @override
  String get recordsDeleteBody =>
      'This record will be permanently deleted. Are you sure?';

  @override
  String get recordsDeleteFailed => 'Failed to delete record.';

  @override
  String get recordsViewDetails => 'View Details';

  @override
  String get recordsAiSummary => 'AI Summary';

  @override
  String get uploadTitle => 'Add Medical Record';

  @override
  String uploadTitleForMember(String name) {
    return 'Upload for $name';
  }

  @override
  String get uploadSubtitle =>
      'Upload your health records to your secure vault.';

  @override
  String uploadSubtitleForMember(String name) {
    return 'Upload records for $name to their secure vault.';
  }

  @override
  String get uploadOfflineNotice =>
      'Uploading documents needs a connection so they can be securely stored and analysed. Reconnect and try again.';

  @override
  String get uploadFileTooLarge =>
      'File too large. Maximum allowed size is 50 MB.';

  @override
  String get uploadImageTooLarge =>
      'Image too large. Maximum allowed size is 50 MB.';

  @override
  String get uploadFilePickerFailed =>
      'Could not open file picker. Please try again.';

  @override
  String get uploadCameraFailed => 'Could not open camera. Please try again.';

  @override
  String get uploadSelectFileFirst => 'Please select a file to upload.';

  @override
  String get uploadFileReadFailed =>
      'Could not read the selected file. Please try again.';

  @override
  String get uploadStagePreparing => 'Preparing upload…';

  @override
  String get uploadStageUploading => 'Uploading file…';

  @override
  String get uploadStageAnalysing => 'AI is analysing your document…';

  @override
  String get uploadFailedShort => 'Upload failed.';

  @override
  String get uploadFailedConnection =>
      'Upload failed. Please check your connection and try again.';

  @override
  String get uploadFailedRetry => 'Upload failed. Please try again.';

  @override
  String get uploadCamera => 'Camera';

  @override
  String get uploadGallery => 'Gallery';

  @override
  String get uploadSelectFolder => 'Select Folder (optional)';

  @override
  String get uploadGeneralRecords => 'General Records';

  @override
  String get uploadProcessing => 'Processing…';

  @override
  String get uploadPrivacyFirst => 'Privacy First';

  @override
  String get uploadPrivacyNote =>
      'Documents are encrypted and stored securely.';

  @override
  String get uploadTakePhotoOrChooseFile => 'Take Photo or Choose File';

  @override
  String get uploadFileTypesHint => 'PDF, JPG, PNG, WebP, or DICOM - max 50 MB';

  @override
  String get uploadUnsupportedType =>
      'Unsupported file type. Choose a PDF, JPG, PNG, WebP, or DICOM (.dcm) file.';

  @override
  String get uploadDuplicateMessage =>
      'This document has already been uploaded to your health vault.';

  @override
  String get uploadRejectedTitle => 'Upload Failed';

  @override
  String get uploadRejectedBody =>
      'This document was not added to your health vault.';

  @override
  String get uploadCouldNotVerify =>
      'We could not verify this document. Please try again.';

  @override
  String get uploadTryAgain => 'Try Again';

  @override
  String get uploadCancel => 'Cancel';

  @override
  String get recordTypeLabReport => 'Lab Report';

  @override
  String get recordTypePrescription => 'Prescription';

  @override
  String get recordTypeRadiology => 'Radiology';

  @override
  String get recordTypeDischargeSummary => 'Discharge Summary';

  @override
  String get recordTypeVaccination => 'Vaccination';

  @override
  String get recordTypeInsurance => 'Insurance';

  @override
  String get recordTypeReferral => 'Referral';

  @override
  String get recordTypeOther => 'Other';

  @override
  String get recordWord => 'Record';

  @override
  String get recordPreviewLoadFailed => 'Could not load this record.';

  @override
  String get recordViewFullRecord => 'View Full Record';

  @override
  String get recordStillProcessing =>
      'Still processing - AI summary will appear once ready.';

  @override
  String get recordProcessingFailed => 'Processing failed.';

  @override
  String get recordIssuedBy => 'Issued by';

  @override
  String get recordDoctor => 'Doctor';

  @override
  String get viewerUnsupportedFileType =>
      'Preview isn\'t supported for this file type yet.';

  @override
  String get viewerLoadFailed =>
      'Could not load the document. Please try again.';

  @override
  String get chatAttachRecords => 'Attach Records';

  @override
  String get chatAttachRecordsSubtitle =>
      'Pick which records the AI should focus on for this question.';

  @override
  String get chatNoRecordsForPatient =>
      'No records found for this patient yet.';

  @override
  String get chatCouldNotLoadRecords => 'Could not load records.';

  @override
  String get chatQuickChipLastReport => 'Explain my last report';

  @override
  String get chatQuickChipEmergencyInfo => 'Show emergency info';

  @override
  String get chatDefaultUntitledRecord => 'Untitled record';

  @override
  String get chatAskAboutYourHealth => 'Ask about your health';

  @override
  String chatAskAboutMembersHealth(String name) {
    return 'Ask about $name\'s health';
  }

  @override
  String get chatHealthAssistantTitle => 'Health Assistant';

  @override
  String get chatOfflineNotice =>
      'The AI assistant needs a connection to read your records and respond. Reconnect and try again.';

  @override
  String get chatSessionHistoryTooltip => 'Session History';

  @override
  String get chatNewSessionTooltip => 'New Session';

  @override
  String get chatInputHint => 'Ask about your health records...';

  @override
  String get chatSessionStartFailed =>
      'Sorry, I could not start a chat session. Please try again.';

  @override
  String get chatGenericError =>
      'Sorry, I encountered an error. Please try again.';

  @override
  String get chatSourcesLabel => 'Sources';

  @override
  String get chatRenameConversationTitle => 'Rename conversation';

  @override
  String get chatConversationTitleHint => 'Conversation title';

  @override
  String get commonSave => 'Save';

  @override
  String get chatRenameFailed => 'Failed to rename chat.';

  @override
  String get chatUnpinFailed => 'Failed to unpin chat.';

  @override
  String get chatPinFailed => 'Failed to pin chat.';

  @override
  String get chatDeleteConversationTitle => 'Delete conversation?';

  @override
  String get chatDeleteConversationBody =>
      'This can\'t be undone. This conversation will be permanently deleted.';

  @override
  String get chatDeleteFailed => 'Failed to delete chat.';

  @override
  String get chatSessionHistoryTitle => 'Conversations';

  @override
  String get chatCouldNotLoadHistory => 'Could not load session history.';

  @override
  String get chatNoPreviousSessions => 'No previous sessions yet.';

  @override
  String get chatNewConversation => 'New conversation';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatPin => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatAttachButton => 'Attach';

  @override
  String chatAttachCountButton(int count) {
    return 'Attach ($count)';
  }

  @override
  String get chatYourHealthAssistant => 'Your Health Assistant';

  @override
  String get chatEmptyStateSubtitle =>
      'Ask me anything about your health records.\nI\'ll explain things in plain language.';

  @override
  String get chatSuggestionSummarizeLabs => 'Summarize my recent lab results';

  @override
  String get chatSuggestionActiveConditions =>
      'What are my current active conditions?';

  @override
  String get chatSuggestionExplainMeds => 'Explain my medications';

  @override
  String get chatSuggestionCriticalAllergies =>
      'Do I have any critical allergies?';

  @override
  String get chatEmptyTitle => 'Ask me anything about your health';

  @override
  String get chatEmptyDescription =>
      'Get answers grounded in the records you\'ve already uploaded to your Health Vault.';

  @override
  String get chatSuggestionSummarizeLatestLab =>
      'Summarize my latest lab report';

  @override
  String get chatSuggestionExplainXray => 'What does my X-ray show?';

  @override
  String get chatSuggestionAnyConcerns => 'Any concerns based on my records?';

  @override
  String get chatDisclaimerBanner =>
      'CurecordAI is not a substitute for professional medical advice. Always confirm important decisions with your doctor.';

  @override
  String get chatUntitledConversation => 'Untitled';

  @override
  String get chatAttachSearchPlaceholder => 'Search documents';

  @override
  String get chatAttachNoMatches => 'No documents match your search.';

  @override
  String get chatTimeNow => 'now';

  @override
  String chatTimeMinutesAgo(int value) {
    return '${value}m ago';
  }

  @override
  String chatTimeHoursAgo(int value) {
    return '${value}h ago';
  }

  @override
  String chatTimeDaysAgo(int value) {
    return '${value}d ago';
  }

  @override
  String chatTimeWeeksAgo(int value) {
    return '${value}w ago';
  }

  @override
  String chatTimeMonthsAgo(int value) {
    return '${value}mo ago';
  }

  @override
  String chatTimeYearsAgo(int value) {
    return '${value}y ago';
  }

  @override
  String get aiSummaryAppBarTitle => 'AI Report Summary';

  @override
  String get aiSummaryLoadFailed => 'Could not load record';

  @override
  String get aiSummaryProcessing => 'AI is analysing your document';

  @override
  String get aiSummaryProcessingSubtitle =>
      'This usually takes a few seconds. Pull down to refresh when ready.';

  @override
  String get aiSummaryFailedTitle => 'Analysis failed';

  @override
  String get aiSummaryFailedSubtitle =>
      'We could not process this document. Please try re-uploading it.';

  @override
  String get aiSummaryAskAiInstead => 'Ask AI instead';

  @override
  String get aiSummaryNoLabParams => 'No lab parameters found';

  @override
  String get aiSummaryNoLabParamsSubtitle =>
      'This document does not contain numeric lab results. You can still ask the AI to explain it.';

  @override
  String get aiSummaryContinueInChat => 'Continue in Chat';

  @override
  String get aiSummaryViewRecordDetails => 'View Record Details';

  @override
  String get aiSummaryResultLabel => 'ANALYSIS RESULT';

  @override
  String aiSummaryOverallLabel(String status) {
    return 'Overall: $status';
  }

  @override
  String get aiSummaryDisclaimer =>
      'This summary is generated by AI to help you understand your results. Please consult with your physician for a formal diagnosis.';

  @override
  String get aiSummaryContinueExplanation => 'Continue explanation in Chat';

  @override
  String get commonYou => 'You';

  @override
  String get medFamilyMemberFallback => 'Family member';

  @override
  String get medAddTitle => 'Add Medication';

  @override
  String get medNameRequired => 'Medication name is required.';

  @override
  String get medSelectDayRequired => 'Select at least one day of the week.';

  @override
  String get medSaveFailed => 'Could not save this medication reminder.';

  @override
  String get medWhoIsFor => 'Who is this medication for?';

  @override
  String get medMyself => 'Myself';

  @override
  String get medHowToAdd => 'How would you like to add this medication?';

  @override
  String get medSelectFromDocument => 'Select from an uploaded document';

  @override
  String get medSelectFromDocumentSubtitle =>
      'Reuse medications already extracted from your records';

  @override
  String get medAddManually => 'Add manually';

  @override
  String get medAddManuallySubtitle => 'Enter medication details yourself';

  @override
  String get medCouldNotLoadDocuments => 'Could not load documents.';

  @override
  String get medNoDocumentsUploaded => 'No documents uploaded yet.';

  @override
  String get medSelectDocument => 'Select a document (newest first)';

  @override
  String get medCouldNotLoadMedications => 'Could not load medications.';

  @override
  String get medSelectMedicationFromDocument =>
      'Select a medication from this document';

  @override
  String get medNoMedicationsExtracted =>
      'No medications were extracted from this document.';

  @override
  String get medUnknownMedication => 'Unknown';

  @override
  String get medChooseDifferentDocument => 'Choose a different document';

  @override
  String get medFieldName => 'Medication name';

  @override
  String get medFieldDosage => 'Dosage';

  @override
  String get medDosageHint => 'e.g. 500mg';

  @override
  String get medFieldForm => 'Form';

  @override
  String get medFormHint => 'e.g. Tablet, Syrup';

  @override
  String get medFieldInstructions => 'Instructions (optional)';

  @override
  String get medContinueToSchedule => 'Continue to schedule';

  @override
  String get medFrequencyLabel => 'Frequency';

  @override
  String get medFreqDaily => 'Every day';

  @override
  String get medFreqSpecificDays => 'Specific days of the week';

  @override
  String get medFreqInterval => 'Every N days';

  @override
  String get medFreqAsNeeded => 'As needed (no fixed reminder)';

  @override
  String get medEveryLabel => 'Every';

  @override
  String get medDaysUnit => 'day(s)';

  @override
  String get medReminderTimes => 'Reminder times';

  @override
  String get medAddAnotherTime => 'Add another time';

  @override
  String get medStartDate => 'Start date';

  @override
  String get medEndDateOptional => 'End date (optional)';

  @override
  String get medOngoing => 'Ongoing';

  @override
  String get medEmailReminder => 'Email reminder (web app)';

  @override
  String get medPushReminder => 'Alarm-style reminder on this device';

  @override
  String get medSaving => 'Saving...';

  @override
  String get medSaveReminder => 'Save Medication Reminder';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get medicationsTitle => 'Medications';

  @override
  String get medicationsLoadFailed => 'Unable to load medications right now';

  @override
  String get medicationsEmptyTitle => 'No medications yet';

  @override
  String get medicationsEmptySubtitle =>
      'Add a medication from a document or manually to start getting reminders.';

  @override
  String get medicationsAddButton => 'Add Medication';

  @override
  String get medFreqAsNeededSummary => 'As needed';

  @override
  String medFreqDailySummary(String times) {
    return 'Daily · $times';
  }

  @override
  String medFreqIntervalSummary(String days, String times) {
    return 'Every $days day(s) · $times';
  }

  @override
  String get medDetailTitle => 'Medication';

  @override
  String get medUpdateFailed => 'Could not update this medication.';

  @override
  String get medDeleteConfirmTitle => 'Delete medication?';

  @override
  String get medDeleteConfirmBody =>
      'This reminder will be removed. This cannot be undone.';

  @override
  String get medDeleteFailed => 'Could not delete this medication.';

  @override
  String get medLoadFailed => 'Could not load this medication.';

  @override
  String medForMember(String name) {
    return 'For $name';
  }

  @override
  String get medRowDosage => 'Dosage';

  @override
  String get medRowForm => 'Form';

  @override
  String get medRowInstructions => 'Instructions';

  @override
  String get medRowFrequency => 'Frequency';

  @override
  String get medRowTimes => 'Times';

  @override
  String get medRowStartDate => 'Start date';

  @override
  String get medRowEndDate => 'End date';

  @override
  String get medRowTimezone => 'Timezone';

  @override
  String get medRowReminders => 'Reminders';

  @override
  String get medRowStatus => 'Status';

  @override
  String get medReminderEmail => 'Email';

  @override
  String get medReminderMobileAlarm => 'Mobile alarm';

  @override
  String get medReminderNone => 'None';

  @override
  String get medResume => 'Resume';

  @override
  String get medPause => 'Pause';

  @override
  String get medMarkCompleted => 'Mark completed';

  @override
  String get medNotifChannelName => 'Medication Reminders';

  @override
  String get medNotifChannelDescription =>
      'Alarm-style reminders so you never miss a medication dose';

  @override
  String get medNotifReminderTitle => 'Medication reminder';

  @override
  String medNotifReminderBody(String medicationName) {
    return 'Time to take $medicationName';
  }

  @override
  String medNotifReminderBodyWithDosage(String medicationName, String dosage) {
    return 'Time to take $medicationName ($dosage)';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get medTabActive => 'Active';

  @override
  String get medTabPaused => 'Paused';

  @override
  String get medTabCompleted => 'Completed';

  @override
  String get medTabAll => 'All';

  @override
  String get medNoActiveMedications => 'No active medications';

  @override
  String get medNoPausedMedications => 'No paused medications';

  @override
  String get medNoCompletedMedications => 'No completed medications';

  @override
  String medOtherTabsNote(String summary) {
    return 'You have $summary in other tabs.';
  }

  @override
  String get medExplainerAllergiesTitle => 'Checked against your allergies';

  @override
  String get medExplainerAllergiesDescription =>
      'Medications you track show up alongside your recorded allergies in your AI health summary, making it easier for you and your care team to notice a potential conflict.';

  @override
  String get medExplainerDocumentsTitle => 'Consistent with your documents';

  @override
  String get medExplainerDocumentsDescription =>
      'Importing a medication from an uploaded prescription links it to that document, so your medication list stays consistent with the rest of your health records.';

  @override
  String get medNotProvided => 'Not provided';

  @override
  String get medMyselfHint => 'Manage your own medications';

  @override
  String get medFamilyMemberHint =>
      'Manage medications for someone you care for';

  @override
  String get medNoFamilyMembersYet =>
      'You have not added any family members yet. Add one to continue.';

  @override
  String get medCurrentlySelected => 'currently selected';

  @override
  String get medFamilyMemberTileTitle => 'Family member';

  @override
  String get medSelectFamilyMemberPrompt => 'Select a family member';

  @override
  String get medBackStep => 'Back';

  @override
  String get medAddDescription =>
      'Set up a reminder so this dose never gets missed.';

  @override
  String get medEditTitle => 'Edit Medication';

  @override
  String get medEditDescription =>
      'Update the details for this medication reminder.';

  @override
  String get medSaveChanges => 'Save changes';

  @override
  String get medNoDosageDetails => 'No dosage details';

  @override
  String get medSectionDetails => 'Medication details';

  @override
  String get medSectionSchedule => 'Schedule';

  @override
  String get medSectionNotifications => 'Notifications';

  @override
  String medAddedSnack(String name) {
    return '$name has been added';
  }

  @override
  String medAddedForMember(String name, String memberName) {
    return '$name has been added for $memberName';
  }

  @override
  String get familyManagementTitle => 'Family Management';

  @override
  String get familyManagementSubtitle =>
      'Manage your health circle. Share medical records, manage dependents, and receive alerts.';

  @override
  String get familyMemberFallbackName => 'Member';

  @override
  String get familyMemberRemoved => 'Member removed';

  @override
  String get familyMemberRemoveFailed => 'Failed to remove member';

  @override
  String get familyPrivacyPolicy => 'Privacy Policy';

  @override
  String get familyTermsOfService => 'Terms of Service';

  @override
  String get familySupport => 'Support';

  @override
  String get familyAppVersion => 'CurecordAI v1.0.0';

  @override
  String get familyManagedByGuardian => 'Managed by parent/guardian';

  @override
  String get familyHasAccessToRecords => 'Has access to your records';

  @override
  String get familyAddMemberTitle => 'Add Family Member';

  @override
  String get familyAddMemberSubtitle =>
      'Invite a partner, relative, or add a child to your unified health sync profile.';

  @override
  String get familyRemoveMemberTitle => 'Remove Member?';

  @override
  String familyRemoveMemberBody(String name) {
    return 'Are you sure you want to remove $name from your health circle? Their health records will be preserved.';
  }

  @override
  String get familyRemove => 'Remove';

  @override
  String get commonDone => 'Done';

  @override
  String get famPhotoUploadTitle => 'Add photo';

  @override
  String get famPhotoUploadHint => 'Optional, coming soon';

  @override
  String get famFullNameLabel => 'Full Name *';

  @override
  String get famValidationNameMin => 'Please enter the full name (min 2 chars)';

  @override
  String get famDobLabel => 'Date of Birth';

  @override
  String get famDobPlaceholder => 'DD / MM / YYYY';

  @override
  String get famAddSubtitle =>
      'Add a child, parent, or sibling to manage their health records.';

  @override
  String get famNameHintFamily => 'e.g. John Doe';

  @override
  String get famValidationRelationshipRequired =>
      'Please select a relationship';

  @override
  String famAddedSnack(String name) {
    return '$name has been added to your family';
  }

  @override
  String get famAddFailed => 'Failed to add family member. Please try again.';

  @override
  String get famRelationshipLabel => 'Relationship *';

  @override
  String get famRelationshipPlaceholder => 'Select relationship';

  @override
  String get famSelectRelationshipTitle => 'Select Relationship';

  @override
  String get famGenderLabel => 'Gender';

  @override
  String get famGenderPlaceholder => 'Select gender';

  @override
  String get famSelectGenderTitle => 'Select Gender';

  @override
  String get famBloodGroupLabel => 'Blood Group';

  @override
  String get famPrivacyAgreementMember =>
      'By adding a member, you agree to CurecordAI\'s family privacy policy.';

  @override
  String get famRoleLabel => 'Role';

  @override
  String get famRoleDependent => 'Dependent (I manage their records)';

  @override
  String get famRoleCaregiver => 'Caregiver (helps manage my records)';

  @override
  String get famRoleLockedHint =>
      'Role cannot be changed after a family member is created.';

  @override
  String get famEditMemberTitle => 'Edit Family Member';

  @override
  String get famEditMemberSubtitle =>
      'Update this family member\'s health profile.';

  @override
  String famUpdateSuccess(String name) {
    return '$name has been updated';
  }

  @override
  String get famUpdateFailed =>
      'Failed to update family member. Please try again.';

  @override
  String get famSaveChanges => 'Save changes';

  @override
  String get relSon => 'Son';

  @override
  String get relDaughter => 'Daughter';

  @override
  String get relFather => 'Father';

  @override
  String get relMother => 'Mother';

  @override
  String get relWife => 'Wife';

  @override
  String get relHusband => 'Husband';

  @override
  String get relBrother => 'Brother';

  @override
  String get relSister => 'Sister';

  @override
  String get relGrandfather => 'Grandfather';

  @override
  String get relGrandmother => 'Grandmother';

  @override
  String get relOther => 'Other';

  @override
  String get relSpouse => 'Spouse';

  @override
  String get relParent => 'Parent';

  @override
  String get relChild => 'Child';

  @override
  String get relSibling => 'Sibling';

  @override
  String get familyEmptyTitle => 'No family members yet';

  @override
  String get familyEmptyDescription =>
      'Add a parent, spouse, or child to start managing their health records alongside your own.';

  @override
  String get familyAddShortcutParentTitle => 'Add a parent';

  @override
  String get familyAddShortcutParentDescription =>
      'Track their medications and appointments.';

  @override
  String get familyAddShortcutSpouseTitle => 'Add a spouse';

  @override
  String get familyAddShortcutSpouseDescription =>
      'Manage shared health history together.';

  @override
  String get familyAddShortcutChildTitle => 'Add a child';

  @override
  String get familyAddShortcutChildDescription =>
      'Keep their records organized in one place.';

  @override
  String get familyFieldGender => 'Gender';

  @override
  String get familyFieldBloodGroup => 'Blood group';

  @override
  String get familyFieldAge => 'Age';

  @override
  String get familyNotProvided => 'Not provided';

  @override
  String familyYearsOld(int age) {
    return '$age years old';
  }

  @override
  String familyEditAria(String name) {
    return 'Edit $name';
  }

  @override
  String get caregiverAddTitle => 'Add Caregiver';

  @override
  String get caregiverAddSubtitle =>
      'Add a doctor or caregiver to share your health records with them.';

  @override
  String get caregiverValidationTypeRequired =>
      'Please select a caregiver type';

  @override
  String get caregiverAddedSnack => 'Caregiver added';

  @override
  String get caregiverAddFailed => 'Failed to add caregiver. Please try again.';

  @override
  String get caregiverTypeLabel => 'Type *';

  @override
  String get caregiverTypePlaceholder => 'Select type';

  @override
  String get caregiverSelectTypeTitle => 'Select Type';

  @override
  String get caregiverRelationshipLabel => 'Relationship (optional)';

  @override
  String get caregiverRelationshipHint => 'e.g. Family Doctor';

  @override
  String get caregiverNameHint => 'e.g. Dr. John Smith';

  @override
  String get caregiverAccessPermissionTitle => 'Access Permission';

  @override
  String get caregiverAccessPermissionSubtitle =>
      'What can this person view when you share your records?';

  @override
  String get caregiverAccessFullTitle => 'Full Access';

  @override
  String get caregiverAccessFullSubtitle =>
      'All records - conditions, medications, allergies and documents';

  @override
  String get caregiverAccessVitalsTitle => 'Vitals Only';

  @override
  String get caregiverAccessVitalsSubtitle =>
      'Blood pressure, heart rate, SpO2 and basic vitals only';

  @override
  String get caregiverAccessReadOnlyTitle => 'Read Only';

  @override
  String get caregiverAccessReadOnlySubtitle =>
      'Can view all records but cannot add or edit anything';

  @override
  String get caregiverPrivacyAgreement =>
      'By adding a caregiver, you agree to CurecordAI\'s family privacy policy.';

  @override
  String get caregiverTypeDoctor => 'Doctor';

  @override
  String get caregiverTypeNurse => 'Nurse';

  @override
  String get caregiverTypeHomeAide => 'Home Aide';

  @override
  String get caregiverTypeSpecialist => 'Specialist';

  @override
  String get caregiverTypeTherapist => 'Therapist';

  @override
  String get caregiverTypeOther => 'Other';

  @override
  String get emergencyInfoTitle => 'Emergency Info';

  @override
  String emergencyInfoTitleFor(String name) {
    return '$name\'s Emergency Info';
  }

  @override
  String get emergencyWidgetSetupTitle => 'Emergency Widget Setup';

  @override
  String get emergencyWidgetSetupSubtitle =>
      'Choose what to show on your lock screen';

  @override
  String get emergencyLockScreenHint => 'Emergency info visible below';

  @override
  String get emergencyInfoLabel => 'EMERGENCY INFO';

  @override
  String get emergencyBloodGroupLabel => 'BLOOD GROUP';

  @override
  String get emergencyNotSet => 'Not set';

  @override
  String get emergencyAllergiesLabel => 'ALLERGIES';

  @override
  String get emergencyNoneKnown => 'None known';

  @override
  String get emergencyContactLabel => 'EMERGENCY CONTACT';

  @override
  String get emergencyToggleBloodGroupTitle => 'Blood Group';

  @override
  String get emergencyToggleBloodGroupSubtitle =>
      'Display your blood type for first responders';

  @override
  String get emergencyToggleAllergiesTitle => 'Allergies';

  @override
  String get emergencyToggleAllergiesSubtitle =>
      'Show critical medication and food allergies';

  @override
  String get emergencyToggleContactTitle => 'Emergency Contact';

  @override
  String get emergencyToggleContactSubtitle =>
      'Primary contact name and phone number';

  @override
  String get emergencyToggleChronicTitle => 'Chronic Conditions';

  @override
  String get emergencyToggleChronicSubtitle =>
      'Display important ongoing health issues';

  @override
  String get emergencyEnableWidgetTitle => 'Enable Lock Screen Widget';

  @override
  String get emergencyEnableWidgetSubtitle =>
      'Allow emergency info to bypass security';

  @override
  String get emergencyContactsSectionTitle => 'EMERGENCY CONTACTS';

  @override
  String get commonAdd => 'Add';

  @override
  String get emergencyContactNameHint => 'Contact name';

  @override
  String get emergencyContactPhoneHint => 'Phone number';

  @override
  String get emergencyRelFamily => 'Family';

  @override
  String get emergencyRelFriend => 'Friend';

  @override
  String get emergencyRelDoctor => 'Doctor';

  @override
  String get emergencyRelNurse => 'Nurse';

  @override
  String get emergencyAddContactButton => 'Add Contact';

  @override
  String get emergencyNoContacts => 'No emergency contacts added';

  @override
  String get emergencySaveSettingsButton => 'Save Settings';

  @override
  String get emergencySettingsSaved => 'Settings saved';

  @override
  String get emergencySettingsSaveFailed => 'Failed to save settings';

  @override
  String get emergencyAddContactFailed => 'Failed to add contact';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get alertCenterTitle => 'Alert Center';

  @override
  String get alertCenterSubtitle => 'Manage your health priorities';

  @override
  String get alertMarkAllRead => 'Mark all as read';

  @override
  String get alertEmptyTitle => 'All caught up!';

  @override
  String get alertEmptySubtitle => 'You have no notifications';

  @override
  String get alertYesterday => 'Yesterday';

  @override
  String get alertEarlier => 'Earlier';

  @override
  String get alertPriorityHigh => 'HIGH PRIORITY';

  @override
  String get alertPriorityAttention => 'ATTENTION';

  @override
  String get alertPrioritySystemUpdate => 'SYSTEM UPDATE';

  @override
  String get alertCategoryMedication => 'Medication';

  @override
  String get alertCategoryVitals => 'Vitals';

  @override
  String get alertCategoryProfile => 'Profile';

  @override
  String get alertCategoryRecords => 'Records';

  @override
  String get alertDefaultTitle => 'Notification';

  @override
  String alertTimeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String alertTimeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String alertTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get shareScopeLast1Year => 'Last 1 Year';

  @override
  String get shareScopeLast6Months => 'Last 6 Months';

  @override
  String get shareScopeFullHistory => 'Complete History';

  @override
  String get shareScopeEmergencyOnly => 'Emergency Info Only';

  @override
  String get shareRecordsTitle => 'Share Records';

  @override
  String get shareOfflineMessage =>
      'Sharing records with a doctor needs a connection to generate a secure link. Reconnect and try again.';

  @override
  String shareRecordsTitleFor(String name) {
    return 'Share $name\'s Records';
  }

  @override
  String get shareFailedGenerateQr => 'Failed to generate QR code';

  @override
  String get shareDoctorInstructionsTitle => 'Doctor Instructions';

  @override
  String get shareSubtitleOwner =>
      'Share your health records with your doctor or caregiver';

  @override
  String shareSubtitleFor(String name) {
    return 'Share $name\'s health records with their doctor or caregiver';
  }

  @override
  String get shareGenerateQrButton => 'Generate QR Code';

  @override
  String get shareGeneratingButton => 'Generating...';

  @override
  String get shareEncryptedNote =>
      'Your data is encrypted. The QR code expires in 10 minutes and can only be scanned by verified practitioners.';

  @override
  String get shareActiveSessionsTitle => 'ACTIVE SESSIONS';

  @override
  String get shareNoActiveSessions => 'No active sharing sessions';

  @override
  String get shareShowDoctorTitle => 'Show This to Your Doctor';

  @override
  String get shareShowDoctorSubtitle =>
      'Doctor can scan this without installing any app';

  @override
  String get shareValidityExpired => 'Expired';

  @override
  String shareValidityMinSec(int mins, String secs) {
    return '$mins min $secs sec';
  }

  @override
  String shareValiditySeconds(int secs) {
    return '$secs seconds';
  }

  @override
  String shareValidFor(String text) {
    return 'Valid for $text';
  }

  @override
  String get shareCodeExpired => 'Code expired';

  @override
  String get shareRegenerateCode => 'Regenerate Code';

  @override
  String get shareLinkCopied => 'Link copied to clipboard';

  @override
  String get shareCopyLink => 'Copy Link';

  @override
  String shareScanned(int count) {
    return 'Scanned $count times';
  }

  @override
  String get shareRevoke => 'Revoke';

  @override
  String get shareInstructionsLoadError => 'Could not load instructions';

  @override
  String get shareInstructionsEmpty =>
      'When a doctor leaves instructions after viewing a record you shared, they\'ll show up here.';

  @override
  String get shareDoctorNameFallback => 'Doctor';

  @override
  String shareDoctorInstructionRow(String name, String institution) {
    return 'Dr. $name · $institution';
  }

  @override
  String get profileMyProfileTitle => 'My Profile';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonUser => 'User';

  @override
  String profilePatientId(String id) {
    return 'Patient ID: $id';
  }

  @override
  String get profileSectionPersonalDetails => 'PERSONAL DETAILS';

  @override
  String get profileLabelDob => 'Date of Birth';

  @override
  String get profileLabelGender => 'Gender';

  @override
  String get profileLabelPhone => 'Phone';

  @override
  String get profileSectionPhysicalMetrics => 'PHYSICAL METRICS';

  @override
  String get profileLabelHeight => 'Height';

  @override
  String get profileLabelWeight => 'Weight';

  @override
  String get profileLabelBloodGroup => 'Blood Group';

  @override
  String get profileLabelBmi => 'BMI';

  @override
  String get profileBmiUnderweight => 'Underweight';

  @override
  String get profileBmiNormal => 'Normal';

  @override
  String get profileBmiOverweight => 'Overweight';

  @override
  String get profileBmiObese => 'Obese';

  @override
  String get profileSectionHealthDetails => 'HEALTH DETAILS';

  @override
  String get profileFailedUploadPhoto => 'Failed to upload photo';

  @override
  String get profileCropPhotoTitle => 'Crop Photo';

  @override
  String get profileCompletionTitle => 'Profile Completion';

  @override
  String get profileCompletionTapToComplete =>
      'Tap to complete your medical profile';

  @override
  String get profileAllergiesLabel => 'Allergies';

  @override
  String get profileNoneRecorded => 'None recorded';

  @override
  String get profileConditionsLabel => 'Conditions';

  @override
  String get profileNoMemberSelected => 'No family member selected';

  @override
  String profileMemberTitleFor(String name) {
    return '$name\'s Profile';
  }

  @override
  String get profileSelectGenderTitle => 'Select Gender';

  @override
  String get profileSelectBloodGroupTitle => 'Select Blood Group';

  @override
  String get profileFailedLoad => 'Failed to load profile';

  @override
  String get profileInformationTitle => 'Profile Information';

  @override
  String profileFailedToLoadWith(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get profileUpdatedSuccess => 'Profile updated successfully';

  @override
  String profileUpdateErrorWith(String error) {
    return 'Error: $error';
  }

  @override
  String get profileFailedUpdatePicture => 'Failed to update profile picture.';

  @override
  String get profileSectionPersonalDetailsLabel => 'Personal Details';

  @override
  String get profileFieldFullName => 'Full Name';

  @override
  String get profileHintFullName => 'Enter your full name';

  @override
  String get profileValidationRequired => 'Required';

  @override
  String get profileFieldDob => 'Date of Birth';

  @override
  String get profileDobPlaceholder => 'DD / MM / YYYY';

  @override
  String get profileFieldGender => 'Gender';

  @override
  String get profileHintSelectGender => 'Select gender';

  @override
  String get profileFieldPhoneNumber => 'Phone Number';

  @override
  String get profileSectionPhysicalMetricsLabel => 'Physical Metrics';

  @override
  String get profileFieldHeightCm => 'Height (cm)';

  @override
  String get profileHintHeightExample => 'e.g. 175';

  @override
  String get profileFieldWeightKg => 'Weight (kg)';

  @override
  String get profileHintWeightExample => 'e.g. 70';

  @override
  String get profileFieldBloodGroupLabel => 'Blood Group';

  @override
  String get profileHintSelectBloodGroup => 'Select Blood Group';

  @override
  String get profileSectionHealthDetailsLabel => 'Health Details';

  @override
  String get profileFieldAllergies => 'Allergies';

  @override
  String get profileHintAllergiesExample => 'e.g., Pollen, Penicillin...';

  @override
  String get profileFieldExistingConditions => 'Existing Conditions';

  @override
  String get profileHintAddOtherConditions => 'Add other conditions...';

  @override
  String get profileSaveChangesButton => 'Save Changes';

  @override
  String get profileConditionAsthma => 'Asthma';

  @override
  String get profileConditionDiabetes => 'Diabetes';

  @override
  String get profileConditionEpilepsy => 'Epilepsy';

  @override
  String get profileConditionHypertension => 'Hypertension';

  @override
  String get profileConditionThyroidIssue => 'Thyroid Issue';

  @override
  String get insightsTitle => 'Health Insights';

  @override
  String insightsTitleFor(String name) {
    return '$name\'s Insights';
  }

  @override
  String get insightsCouldNotLoad => 'Could not load insights';

  @override
  String get insightsOverview => 'Overview';

  @override
  String get insightsTotalRecords => 'Total Records';

  @override
  String get insightsThisMonth => 'This Month';

  @override
  String get insightsActiveConditions => 'Active Conditions';

  @override
  String get insightsUnreadAlerts => 'Unread Alerts';

  @override
  String get insightsRecordsByType => 'Records by Type';

  @override
  String get insightsCouldNotLoadChart => 'Could not load chart data';

  @override
  String get insightsNoRecordsYet => 'No records yet';

  @override
  String get insightsVitalTrends => 'Vital Trends';

  @override
  String get insightsBloodGlucose => 'Blood Glucose';

  @override
  String get insightsHemoglobin => 'Hemoglobin';

  @override
  String get insightsBloodPressureSystolic => 'Blood Pressure (Systolic)';

  @override
  String get insightsFailedToLoad => 'Failed to load';

  @override
  String get insightsNoDataRecordedYet => 'No data recorded yet';

  @override
  String get insightsChartLabelLab => 'Lab';

  @override
  String get insightsChartLabelRx => 'Rx';

  @override
  String get insightsChartLabelRad => 'Rad';

  @override
  String get insightsChartLabelVax => 'Vax';

  @override
  String get insightsChartLabelOther => 'Other';

  @override
  String get healthSummaryTitle => 'Health Summary';

  @override
  String healthSummaryTitleFor(String name) {
    return '$name\'s Health Summary';
  }

  @override
  String get healthSummaryCouldNotLoad => 'Could not load your health summary';

  @override
  String get healthSummaryActiveConditions => 'Active Conditions';

  @override
  String get healthSummaryCurrentMedications => 'Current Medications';

  @override
  String get healthSummaryAllergies => 'Allergies';

  @override
  String get healthSummaryRecentLabsVitals => 'Recent Labs & Vitals';

  @override
  String get healthSummaryDisclaimer =>
      'This overview is generated from your uploaded records by AI and may not be complete. Always consult your doctor for clinical decisions.';

  @override
  String get healthSummaryYourOverview => 'Your Health Overview';

  @override
  String get healthSummaryNoDataYet => 'No health data yet';

  @override
  String healthSummaryNoDataYetFor(String name) {
    return 'No health data yet for $name';
  }

  @override
  String get healthSummaryUploadPrompt =>
      'Upload medical records to build a complete health overview.';

  @override
  String get profileCompletionPersonalDetailsTitle => 'Personal Details';

  @override
  String get profileCompletionPersonalDetailsSubtitle =>
      'Let\'s start with your basic information.';

  @override
  String get profileCompletionFullNameRequired => 'Full name is required';

  @override
  String get profileCompletionDobFormat => 'DD / MM / YYYY';

  @override
  String get profileCompletionDobRequired => 'Date of birth is required';

  @override
  String get profileCompletionGenderRequired => 'Please select a gender';

  @override
  String get profileCompletionPhoneHint => '000-000-0000';

  @override
  String get profileCompletionPhoneRequired => 'Phone number is required';

  @override
  String get profileCompletionStep1Note =>
      'This information helps doctors identify you accurately.';

  @override
  String get profileCompletionNext => 'Next →';

  @override
  String get profileCompletionStep1HelpTitle => 'Step 1 Help';

  @override
  String get profileCompletionStep1HelpBody =>
      'Enter your personal details accurately. This helps healthcare providers identify you and personalize your care.';

  @override
  String get profileCompletionStep2SkipNotice =>
      'You can complete this later from your profile';

  @override
  String get profileCompletionPhysicalMetricsTitle => 'Physical Metrics';

  @override
  String get profileCompletionPhysicalMetricsSubtitle =>
      'Help us personalize your wellness journey by providing your key physical indicators.';

  @override
  String get profileCompletionStep2Note =>
      'Your physical data is used exclusively to calculate BMI and customize nutritional recommendations. All data is encrypted.';

  @override
  String get profileCompletionStep2HelpTitle => 'Step 2 Help';

  @override
  String get profileCompletionStep2HelpBody =>
      'Physical metrics help calculate your BMI and tailor nutritional recommendations. All fields are optional - you can skip and complete later.';

  @override
  String profileCompletionSaveError(String error) {
    return 'Error: $error';
  }

  @override
  String get profileCompletionSuccessTitle => 'Profile Updated!';

  @override
  String get profileCompletionSuccessBody =>
      'Your health profile has been saved.';

  @override
  String get profileCompletionGoToProfile => 'Go to Profile';

  @override
  String get profileCompletionAlmostThere => 'Almost there!';

  @override
  String get profileCompletionStep3Subtitle =>
      'We use this information to provide personalized health insights and safety alerts.';

  @override
  String get profileCompletionSeparateWithCommas =>
      'Separate items with commas';

  @override
  String get profileCompletionHipaaCompliant => 'HIPAA Compliant';

  @override
  String get profileCompletionSecureStorage => 'Secure Storage';

  @override
  String get profileCompletionEncrypted => 'Encrypted';

  @override
  String get profileCompletionPersonalData => 'Personal Data';

  @override
  String get profileCompletionSaving => 'Saving...';

  @override
  String get profileCompletionFinish => 'Finish →';

  @override
  String get profileCompletionStep3HelpTitle => 'Step 3 Help';

  @override
  String get profileCompletionStep3HelpBody =>
      'Your health details help generate personalized safety alerts and recommendations. You can update these anytime from your profile.';

  @override
  String get privacyPolicyAppBarTitle => 'Data & Privacy';

  @override
  String get privacyPolicyHeading => 'How CurecordAI handles your data';

  @override
  String get privacyPolicyIntro =>
      'This page explains what health data we collect, how it\'s used, and the controls you have over it.';

  @override
  String get privacyPolicyDataWeCollectTitle => 'Data We Collect';

  @override
  String get privacyPolicyDataWeCollectBody =>
      'To provide your personal health record, we store the profile details you provide (name, date of birth, gender, contact information), the medical documents you upload, the structured clinical data extracted from those documents (conditions, medications, lab results, allergies, and visit history), and your conversations with the in-app AI assistant. We also record basic device and session metadata (IP address, device type, login timestamps) to keep your account secure.';

  @override
  String get privacyPolicyHowWeUseDataTitle => 'How We Use Your Data';

  @override
  String get privacyPolicyHowWeUseDataBody =>
      'Your data is used exclusively to power the features you use: extracting structured health information from uploaded documents, generating AI summaries, answering questions about your records in AI Chat, computing your profile completion score, populating your Emergency Medical Card, and enabling secure sharing with family members, caregivers, or clinicians that you explicitly authorize.';

  @override
  String get privacyPolicyAiProcessingTitle => 'AI Processing';

  @override
  String get privacyPolicyAiProcessingBody =>
      'When a document is processed or you ask a question in AI Chat, the relevant document content or record data is sent to our AI processing provider solely to extract clinical data or generate a response. This data is used only to serve your request - it is not used to train third-party AI models, and it is not retained by the AI provider beyond what is required to process that single request.';

  @override
  String get privacyPolicyStorageSecurityTitle => 'Storage & Security';

  @override
  String get privacyPolicyStorageSecurityBody =>
      'Uploaded documents are stored in encrypted cloud storage, and all data in transit is protected with TLS encryption. Access to your records is scoped to your account and any family members or caregivers you explicitly grant access to. You can revoke a login session for this device at any time by logging out, which immediately invalidates the associated access and refresh tokens.';

  @override
  String get privacyPolicyFamilyAccessTitle => 'Family & Caregiver Access';

  @override
  String get privacyPolicyFamilyAccessBody =>
      'If you add family members or caregivers to your account, they can only view records and data explicitly scoped to the family member profile you created for them. You remain in control of what each family member profile contains and can remove access at any time from Family Management.';

  @override
  String get privacyPolicySharingCliniciansTitle => 'Sharing With Clinicians';

  @override
  String get privacyPolicySharingCliniciansBody =>
      'Generating a QR code from your dashboard creates a time-limited, revocable share link to selected records. Clinicians who scan it can view only the records included in that share - never your full account - and you can revoke access at any time.';

  @override
  String get privacyPolicyYourRightsTitle => 'Your Rights';

  @override
  String get privacyPolicyYourRightsBody =>
      'You can request a full export of your health data at any time from Settings → Export My Data, review and withdraw specific consents from Consent Management, and permanently delete records you no longer want stored. Deleted records are removed from active use immediately and purged from backups on our standard retention schedule.';

  @override
  String get privacyPolicyDataRetentionTitle => 'Data Retention';

  @override
  String get privacyPolicyDataRetentionBody =>
      'We retain your data for as long as your account remains active. If you delete a record, it is immediately hidden from the app and permanently purged from our systems within the retention window described above. If you delete your account, all associated personal and medical data is scheduled for permanent deletion.';

  @override
  String get privacyPolicyContactTitle => 'Contact';

  @override
  String get privacyPolicyContactBody =>
      'If you have questions about how your data is handled, reach out to our support team from the Support link below and we\'ll be glad to help.';

  @override
  String get privacyControlsTitle => 'Privacy Controls';

  @override
  String get privacyControlsBiometricLockTitle => 'Biometric Lock';

  @override
  String get privacyControlsBiometricLockSubtitle =>
      'Use Face ID or fingerprint to unlock';

  @override
  String get privacyControlsAppLockTitle => 'App Lock on Background';

  @override
  String get privacyControlsAppLockSubtitle => 'Lock app when switching tasks';

  @override
  String get privacyControlsScreenshotTitle => 'Screenshot Prevention';

  @override
  String get privacyControlsScreenshotSubtitle => 'Block screenshots in app';

  @override
  String get privacyControlsNote =>
      'Privacy settings help keep your medical data safe. Biometric lock ensures only you can access the app. Changes are saved automatically.';

  @override
  String get dataSharingTitle => 'Data Sharing';

  @override
  String get dataSharingSubtitle =>
      'Manage which doctors and hospitals can access your records';

  @override
  String get dataSharingAddNewAccess => 'Add New Access';

  @override
  String get dataSharingRevokeAccessTitle => 'Revoke Access';

  @override
  String dataSharingRevokeAccessConfirm(String name) {
    return 'Remove access for $name?';
  }

  @override
  String get dataSharingRevoke => 'Revoke';

  @override
  String get dataSharingRevokeFailed => 'Failed to revoke access';

  @override
  String get dataSharingAccessFull => 'Full';

  @override
  String get dataSharingAccessRead => 'Read';

  @override
  String dataSharingUntil(String date) {
    return 'Until $date';
  }

  @override
  String get dataSharingEmptyTitle => 'No shared access yet';

  @override
  String get dataSharingEmptyBody =>
      'Tap \"Add New Access\" to grant access to doctors or hospitals.';

  @override
  String get dataSharingAddFailed => 'Failed to add access';

  @override
  String get dataSharingDoctorHospitalName => 'Doctor / Hospital Name';

  @override
  String get dataSharingEnterName => 'Enter name';

  @override
  String get dataSharingAccessType => 'Access Type';

  @override
  String get dataSharingGrantedUntilOptional => 'Granted Until (optional)';

  @override
  String get dataSharingNoExpiry => 'No expiry';

  @override
  String get dataSharingGrantAccess => 'Grant Access';

  @override
  String get consentManagementTitle => 'Consent Management';

  @override
  String get consentOptionalSectionTitle => 'OPTIONAL CONSENTS';

  @override
  String get consentRequiredSectionTitle => 'REQUIRED AGREEMENTS';

  @override
  String get consentAnalyticsTitle => 'Analytics & Usage Data';

  @override
  String get consentAnalyticsSubtitle =>
      'Help improve the app by sharing anonymous usage statistics';

  @override
  String get consentMarketingTitle => 'Marketing Communications';

  @override
  String get consentMarketingSubtitle =>
      'Receive updates, tips, and health news from CurecordAI';

  @override
  String get consentTermsOfServiceTitle => 'Terms of Service';

  @override
  String get consentTermsOfServiceSubtitle => 'Required to use CurecordAI';

  @override
  String get consentPrivacyPolicyTitle => 'Privacy Policy';

  @override
  String get consentPrivacyPolicySubtitle => 'How we handle your medical data';

  @override
  String get consentDataProcessingTitle => 'Data Processing';

  @override
  String get consentDataProcessingSubtitle =>
      'Processing your health information to provide services';

  @override
  String get consentWithdrawalNote =>
      'Withdrawing a consent takes effect immediately. Required agreements cannot be withdrawn while using the app.';

  @override
  String get consentUpdateFailed =>
      'Failed to update consent. Please try again.';

  @override
  String get consentAccepted => 'Accepted';

  @override
  String get consentNotSet => 'Not set';

  @override
  String recordDetailIcd11Code(String code) {
    return 'ICD-11: $code';
  }

  @override
  String get errorSaveChangesFailed => 'Failed to save changes.';

  @override
  String get recordDeletePermanentBody =>
      'This will permanently delete this record. This action cannot be undone.';

  @override
  String get recordDocumentLinkUnavailable => 'Document link is not available.';

  @override
  String get recordDetailsTitle => 'Record Details';

  @override
  String get recordLoadFailed => 'Failed to load record.';

  @override
  String get recordDocumentWord => 'Document';

  @override
  String get recordDocumentDetails => 'Document Details';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldDate => 'Date';

  @override
  String get commonTapToSet => 'Tap to set';

  @override
  String get fieldPatientName => 'Patient Name';

  @override
  String get fieldIssuingLabOrg => 'Lab / Organization';

  @override
  String get fieldReferringDoctor => 'Referring Doctor';

  @override
  String get fieldFile => 'File';

  @override
  String get fieldStatus => 'Status';

  @override
  String get recordAiExtracting =>
      'AI is extracting information from your document...';

  @override
  String get recordAiProcessingFailed =>
      'AI processing failed. Please try again.';

  @override
  String get recordViewOriginal => 'View Original';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get clinicalLabResultsVitals => 'Lab Results & Vitals';

  @override
  String get clinicalConditions => 'Conditions';

  @override
  String get clinicalMedications => 'Medications';

  @override
  String get clinicalVisitsEncounters => 'Visits & Encounters';

  @override
  String get clinicalEditCondition => 'Edit Condition';

  @override
  String get clinicalEditMedication => 'Edit Medication';

  @override
  String get clinicalEditObservation => 'Edit Observation';

  @override
  String get clinicalEditAllergy => 'Edit Allergy';

  @override
  String get clinicalEditVisit => 'Edit Visit';

  @override
  String get clinicalConditionField => 'Condition';

  @override
  String get clinicalSeverity => 'Severity';

  @override
  String get clinicalMedicationField => 'Medication';

  @override
  String get clinicalDosage => 'Dosage';

  @override
  String get clinicalFrequency => 'Frequency';

  @override
  String get clinicalTestVitalName => 'Test / Vital Name';

  @override
  String get clinicalValue => 'Value';

  @override
  String get clinicalUnit => 'Unit';

  @override
  String get clinicalInterpretation => 'Interpretation';

  @override
  String get clinicalSubstance => 'Substance';

  @override
  String get clinicalCriticality => 'Criticality';

  @override
  String get clinicalReaction => 'Reaction';

  @override
  String get clinicalHospitalClinic => 'Hospital / Clinic';

  @override
  String get clinicalVisitType => 'Visit Type';

  @override
  String get clinicalAiExtractedHint =>
      'AI-extracted from your document. Review and correct if needed.';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get interpNormal => 'Normal';

  @override
  String get interpLow => 'Low';

  @override
  String get interpHigh => 'High';

  @override
  String get interpCriticalLow => 'Critical Low';

  @override
  String get interpCriticalHigh => 'Critical High';

  @override
  String get interpAbnormal => 'Abnormal';

  @override
  String get interpVeryAbnormal => 'Very Abnormal';

  @override
  String get commonActive => 'Active';

  @override
  String get recordTypeSheetTitle => 'Select Record Type';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String recordProcessingFailedWithReason(String reason) {
    return 'Processing failed: $reason';
  }

  @override
  String clinicalRefRange(String range) {
    return 'Ref: $range';
  }

  @override
  String clinicalDoctorPrefix(String name) {
    return 'Dr. $name';
  }

  @override
  String get commonGotIt => 'Got it';

  @override
  String get chatInfoAria => 'How to use AI Health Assistant';

  @override
  String get chatInfoModalTitle => 'How to use AI Health Assistant';

  @override
  String get chatInfoAskTitle => 'Ask about your health';

  @override
  String get chatInfoAskDescription =>
      'Ask anything about your health, and the assistant answers based on the documents you\'ve already uploaded.';

  @override
  String get chatInfoAttachTitle => 'Attach records from Health Vault';

  @override
  String get chatInfoAttachDescription =>
      'Attach specific documents from your Health Vault to a question for more targeted, context-aware answers.';

  @override
  String get chatInfoSummarizeTitle => 'Summarize reports';

  @override
  String get chatInfoSummarizeDescription =>
      'Ask the assistant to summarize a lab report, prescription, or X-ray in plain language.';

  @override
  String get chatInfoUnderstandTitle => 'Understand your health';

  @override
  String get chatInfoUnderstandDescription =>
      'Get help understanding medical terms, results, and what they mean for your overall health.';

  @override
  String get familyInfoAria => 'How family management works';

  @override
  String get familyInfoModalTitle => 'How Family Management Works';

  @override
  String get familyInfoNoLoginTitle => 'No separate login needed';

  @override
  String get familyInfoNoLoginDescription =>
      'Family members do not need their own account. You manage everything from your own login.';

  @override
  String get familyInfoProfilesTitle => 'Individual profiles';

  @override
  String get familyInfoProfilesDescription =>
      'Each family member gets their own separate documents and medications, kept apart from your own records.';

  @override
  String get familyInfoTogetherTitle => 'Manage together';

  @override
  String get familyInfoTogetherDescription =>
      'Upload documents, track medications, and view AI summaries for each family member, just like your own profile.';

  @override
  String get familyInfoShareTitle => 'Share access instantly';

  @override
  String get familyInfoShareDescription =>
      'Generate a QR share for any family member\'s records individually, same as your own.';

  @override
  String get medicationsInfoAria => 'How medications work';

  @override
  String get medicationsInfoModalTitle => 'How Medications Work';

  @override
  String get medicationsInfoWhoTitle => 'Who it is for';

  @override
  String get medicationsInfoWhoDescription =>
      'Medications can be added for yourself or for a family member you manage.';

  @override
  String get medicationsInfoAddTitle => 'Add manually or import';

  @override
  String get medicationsInfoAddDescription =>
      'Enter details yourself, or pull them from an already uploaded document.';

  @override
  String get medicationsInfoTrackTitle => 'Track status';

  @override
  String get medicationsInfoTrackDescription =>
      'Medications can be marked Active, Paused, or Completed using the tabs above.';
}
