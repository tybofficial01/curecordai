import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/create_account_screen.dart';
import '../../features/auth/screens/email_signup_screen.dart';
import '../../features/auth/screens/email_otp_screen.dart';
import '../../features/auth/screens/phone_signup_screen.dart';
import '../../features/auth/screens/email_login_screen.dart';
import '../../features/auth/screens/phone_login_screen.dart';
import '../../features/auth/screens/onboarding/tell_us_about_yourself_screen.dart';
import '../../features/auth/screens/onboarding/physical_metrics_screen.dart';
import '../../features/auth/screens/onboarding/almost_there_screen.dart';
import '../../features/auth/screens/success_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/records/screens/records_screen.dart';
import '../../features/records/screens/upload_screen.dart';
import '../../features/records/screens/ai_summary_screen.dart';
import '../../features/records/screens/record_detail_screen.dart';
import '../../features/ai_chat/screens/ai_chat_screen.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/insights/screens/health_summary_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/profile_completion_step1_screen.dart';
import '../../features/profile/screens/profile_completion_step2_screen.dart';
import '../../features/profile/screens/profile_completion_step3_screen.dart';
import '../../features/profile/screens/profile_information_screen.dart';
import '../../features/profile/screens/privacy_controls_screen.dart';
import '../../features/profile/screens/privacy_policy_screen.dart';
import '../../features/profile/screens/data_sharing_screen.dart';
import '../../features/profile/screens/consent_management_screen.dart';
import '../../features/family/screens/family_screen.dart';
import '../../features/family/screens/add_family_member_screen.dart';
import '../../features/family/screens/add_caregiver_screen.dart';
import '../../features/family/screens/family_member_shell.dart';
import '../../features/medications/screens/medications_screen.dart';
import '../../features/medications/screens/medication_detail_screen.dart';
import '../../features/sharing/screens/share_screen.dart';
import '../../features/sharing/screens/doctor_instructions_screen.dart';
import '../../features/emergency/screens/emergency_screen.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/main/main_shell.dart';
import '../storage/secure_storage.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) async {
      final storage = ref.read(secureStorageProvider);
      bool isLoggedIn = false;
      try {
        isLoggedIn = await storage.hasValidSession();
      } catch (_) {
        // Storage failure → treat as logged out, don't block navigation
      }
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc.startsWith('/auth') || loc == '/splash' || loc == '/onboarding';

      if (!isLoggedIn && !isAuthRoute) {
        final carouselSeen = await storage.hasSeenCarousel();
        return carouselSeen ? '/auth/login' : '/onboarding';
      }
      if (isLoggedIn &&
          isAuthRoute &&
          loc != '/splash' &&
          !loc.startsWith('/auth/onboarding') &&
          loc != '/auth/success') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // Auth flow
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpScreen(
          phoneNumber: state.extra as String? ?? '',
          purpose: 'login',
        ),
      ),
      GoRoute(
        path: '/auth/otp-register',
        builder: (_, state) => OtpScreen(
          phoneNumber: state.extra as String? ?? '',
          purpose: 'registration',
        ),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, state) => RegisterScreen(
          otpVerifiedToken: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
          path: '/auth/create-account',
          builder: (_, __) => const CreateAccountScreen()),
      GoRoute(
          path: '/auth/email-signup',
          builder: (_, __) => const EmailSignupScreen()),
      GoRoute(
        path: '/auth/email-otp-register',
        builder: (_, state) {
          final data = state.extra as Map<String, dynamic>? ?? const {};
          return EmailOtpScreen(
            fullName: data['fullName'] as String? ?? '',
            email: data['email'] as String? ?? '',
            password: data['password'] as String? ?? '',
          );
        },
      ),
      GoRoute(
          path: '/auth/phone-signup',
          builder: (_, __) => const PhoneSignupScreen()),
      GoRoute(
          path: '/auth/email-login',
          builder: (_, __) => const EmailLoginScreen()),
      GoRoute(
          path: '/auth/phone-login',
          builder: (_, __) => const PhoneLoginScreen()),
      GoRoute(
        path: '/auth/onboarding/step1',
        builder: (_, state) => TellUsAboutYourselfScreen(
          otpVerifiedToken: state.extra as String?,
        ),
      ),
      GoRoute(
          path: '/auth/onboarding/step2',
          builder: (_, __) => const PhysicalMetricsScreen()),
      GoRoute(
          path: '/auth/onboarding/step3',
          builder: (_, __) => const AlmostThereScreen()),
      GoRoute(
        path: '/auth/success',
        builder: (_, state) => SuccessScreen(
          isNewUser: state.extra as bool? ?? true,
        ),
      ),

      // Main shell with bottom nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/records',
            builder: (_, __) => const RecordsScreen(),
            routes: [
              GoRoute(
                path: 'upload',
                builder: (_, state) => UploadScreen(
                  initialFolderId: state.extra as String?,
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => RecordDetailScreen(
                  recordId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'summary',
                    builder: (_, state) => AiSummaryScreen(
                      recordId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/ai',
            builder: (_, state) {
              final extra = state.extra;
              return AiChatScreen(
                initialAttachment: extra is AiChatAttachment ? extra : null,
                initialSessionId: extra is String ? extra : null,
              );
            },
          ),
          GoRoute(
            path: '/medications',
            builder: (_, __) => const MedicationsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => MedicationDetailScreen(
                    medicationId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
              path: '/insights', builder: (_, __) => const InsightsScreen()),
          GoRoute(
              path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),

      // Profile & Settings
      // Family member context shell - slide-up overlay
      GoRoute(
        path: '/family-member',
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const FamilyMemberShell(),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        ),
      ),

      // Full-screen routes (above shell)
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/profile/information',
          builder: (_, __) => const ProfileInformationScreen()),
      GoRoute(
          path: '/profile/privacy',
          builder: (_, __) => const PrivacyControlsScreen()),
      GoRoute(
          path: '/profile/privacy-policy',
          builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(
          path: '/profile/data-sharing',
          builder: (_, __) => const DataSharingScreen()),
      GoRoute(
          path: '/consent',
          builder: (_, __) => const ConsentManagementScreen()),

      // Profile completion flow
      GoRoute(
          path: '/profile-completion/step1',
          builder: (_, __) => const ProfileCompletionStep1Screen()),
      GoRoute(
          path: '/profile-completion/step2',
          builder: (_, __) => const ProfileCompletionStep2Screen()),
      GoRoute(
          path: '/profile-completion/step3',
          builder: (_, __) => const ProfileCompletionStep3Screen()),

      // Other full-screen routes
      GoRoute(path: '/family', builder: (_, __) => const FamilyScreen()),
      GoRoute(
        path: '/family/add',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddFamilyMemberScreen(
            editMemberId: extra?['editId'] as String?,
            initialRelation: extra?['initialRelation'] as String?,
          );
        },
      ),
      GoRoute(
          path: '/family/add-caregiver',
          builder: (_, __) => const AddCaregiverScreen()),
      GoRoute(path: '/share', builder: (_, __) => const ShareScreen()),
      GoRoute(
          path: '/share/instructions',
          builder: (_, __) => const DoctorInstructionsScreen()),
      GoRoute(path: '/emergency', builder: (_, __) => const EmergencyScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
      GoRoute(
          path: '/health-summary',
          builder: (_, __) => const HealthSummaryScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
