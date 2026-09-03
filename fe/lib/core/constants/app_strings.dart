class AppStrings {
  AppStrings._();

  static const String appName = 'CurecordAI';
  static const String tagline = 'Your Health, Always With You';

  // Carousel
  static const List<Map<String, String>> carouselSlides = [
    {
      'title': 'Store All Your Medical Records',
      'subtitle':
          'Keep prescriptions, reports, and X-rays safe in one secure vault.',
      'image': 'assets/images/carousel_1.png',
    },
    {
      'title': 'Share With Your Doctor Instantly',
      'subtitle':
          'Generate a QR code so doctors can view your history without any app.',
      'image': 'assets/images/carousel_2.png',
    },
    {
      'title': 'Set Up Your Emergency Widget',
      'subtitle':
          'Keep critical health info one glance away, even on your lock screen.',
      'image': 'assets/images/carousel_3.png',
    },
  ];

  // Auth
  static const String createAccount = 'Create your Account';
  static const String createAccountSubtitle =
      'Sign up to start managing your medical records.';
  static const String welcomeBack = 'Welcome Back';
  static const String welcomeBackSubtitle =
      'Log in to view your medical records.';
  static const String continueWithPhone = 'Continue with Phone';
  static const String continueWithEmail = 'Continue with Email';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String logIn = 'Log in';
  static const String signUp = 'Sign Up';
  static const String newToCurecord = 'New to CurecordAI?';

  // Email Signup
  static const String emailSignupTitle = 'Create your Account';
  static const String emailSignupSubtitle =
      'Please enter your Email and Password to Continue';
  static const String emailLoginTitle = 'Email Login';
  static const String emailLoginSubtitle =
      'Please enter your Email and Password to Continue';

  // Phone
  static const String phoneSignupTitle = 'Create Your Account';
  static const String phoneSignupSubtitle =
      "We'll send you a verification code.";
  static const String phoneLoginTitle = 'Phone Login';
  static const String phoneLoginSubtitle =
      'Login with your phone number to access your health records';
  static const String sendOtp = 'Send OTP';

  // OTP
  static const String otpTitle = 'Verify Your Number';
  static const String otpSubtitle = 'Enter the 6-digit code sent to';
  static const String verify = 'Verify';
  static const String resendSms = 'Resend SMS';

  // Onboarding
  static const String tellUsAboutYourselfTitle = 'Tell Us About Yourself';
  static const String tellUsAboutYourselfSubtitle =
      'This helps us personalize your health vault.';
  static const String physicalMetricsTitle = 'Physical Metrics';
  static const String physicalMetricsSubtitle =
      'Help us personalize your wellness journey by providing your key physical indicators.';
  static const String almostThereTitle = 'Almost there!';
  static const String almostThereSubtitle =
      'We use this information to provide personalized health insights and safety alerts.';

  // Buttons
  static const String next = 'Next →';
  static const String previous = 'Previous';
  static const String finish = 'Finish →';
  static const String getStarted = 'Get Started';
  static const String skipForNow = 'Skip for now';
  static const String logout = 'Logout';

  // Assets
  static const String logoAsset = 'assets/images/logo.png';
  static const String signupOptionsAsset = 'assets/images/signup_options.png';
  static const String emailSignupAsset = 'assets/images/email_signup.png';
  static const String enterPhoneAsset = 'assets/images/enter_phone_number.png';
  static const String otpVerificationAsset =
      'assets/images/otp_verification.png';
  static const String successIllustrationAsset =
      'assets/images/success_illustration.png';

  // Conditions
  static const List<String> predefinedConditions = [
    'Asthma',
    'Diabetes',
    'Epilepsy',
    'Hypertension',
    'Thyroid Issue',
  ];

  // Blood groups
  static const List<String> bloodGroups = [
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−'
  ];

  // Gender
  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
}
