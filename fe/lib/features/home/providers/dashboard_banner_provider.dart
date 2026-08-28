import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../records/providers/records_provider.dart';
import '../../sharing/screens/doctor_instructions_screen.dart';
import '../../insights/providers/insights_provider.dart';

/// Mirrors the web dashboard's time-based greeting
/// (web/app/dashboard/page.tsx, getTimeBasedGreeting).
String timeBasedGreeting(DateTime now, AppLocalizations t) {
  final hour = now.hour;
  if (hour < 12) return t.homeGreetingMorning;
  if (hour < 17) return t.homeGreetingAfternoon;
  if (hour < 21) return t.homeGreetingEvening;
  return t.homeGreetingNight;
}

/// Nudge condition ids, in priority order. First match wins - mirrors
/// web/app/dashboard/page.tsx's priority nudge list.
enum DashboardNudgeId { unreadDoctorInstruction, noDocuments, noMedications }

/// Resolves which priority nudge (if any) applies right now. The widget maps
/// the id to localized copy and a route, same split web keeps between logic
/// (page.tsx) and copy (messages/en.json).
final priorityNudgeIdProvider = Provider<DashboardNudgeId?>((ref) {
  final unseenInstructions = ref.watch(unseenDoctorInstructionsCountProvider);
  if (unseenInstructions > 0) {
    return DashboardNudgeId.unreadDoctorInstruction;
  }

  final records = ref.watch(recordsListProvider).valueOrNull;
  if (records != null && records.isEmpty) {
    return DashboardNudgeId.noDocuments;
  }

  final summary = ref.watch(healthSummaryProvider).valueOrNull;
  if (summary != null && (summary['active_medications'] as int? ?? -1) == 0) {
    return DashboardNudgeId.noMedications;
  }

  return null;
});

/// Most recent 3 AI chat sessions for the active profile, for the dashboard's
/// Recent AI Conversations preview - mirrors web's sessions.slice(0, 3), but
/// asks the backend for just the 3 it needs instead of over-fetching.
final recentChatSessionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final response = await api.get<List<dynamic>>(
    '/ai/sessions',
    queryParameters: {
      if (memberId != null) 'family_member_id': memberId,
      'limit': 3,
    },
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});
