import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/notifications/medication_notification_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../family/providers/family_provider.dart';

/// In owner mode this is a shared, family-wide tracking view that aggregates the
/// owner's own medications and every family member's, grouped in the UI below -
/// mirroring web's loadMedications. When viewing a specific family member's own
/// profile (activeMemberIdProvider set), it is scoped to just that member's
/// medications instead, never the owner's or any other member's.
final medicationsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);

  if (memberId != null) {
    final response = await api.get<List<dynamic>>('/medications',
        queryParameters: {'family_member_id': memberId},
        cachePolicy: CachePolicy.forceCache);
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  final familyMembers = await ref.watch(familyMembersProvider.future);
  final ownResponse = await api.get<List<dynamic>>('/medications',
      cachePolicy: CachePolicy.forceCache);
  final own = (ownResponse.data ?? []).cast<Map<String, dynamic>>();
  final memberLists = await Future.wait(familyMembers.map((m) async {
    final response = await api.get<List<dynamic>>('/medications',
        queryParameters: {'family_member_id': m['id']},
        cachePolicy: CachePolicy.forceCache);
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }));
  return [...own, ...memberLists.expand((list) => list)];
});

/// Active-only medications for the active profile, used by the home dashboard's
/// Medications stat card - both the active count and the "reviewed X ago" line
/// need this same data, mirroring web's listMedicationReminders(status: "active").
final activeMedicationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final params = <String, dynamic>{'status': 'active'};
  if (memberId != null) params['family_member_id'] = memberId;
  final response = await api.get<List<dynamic>>('/medications',
      queryParameters: params, cachePolicy: CachePolicy.forceCache);
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

final medicationDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/medications/$id',
      cachePolicy: CachePolicy.forceCache);
  return response.data ?? {};
});

final upcomingDosesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/medications/upcoming/all',
      queryParameters: {'hours_ahead': 48}, cachePolicy: CachePolicy.forceCache);
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

/// Records for the "select medication from an uploaded document" flow - reuses the existing
/// records list (already latest-first) rather than a separate medication-specific endpoint.
/// Scoped by the family member picked in the flow's first step, so the document choices match
/// whoever the reminder is actually being created for.
final recordsForMedicationProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
        (ref, familyMemberId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/records',
      queryParameters:
          familyMemberId != null ? {'family_member_id': familyMemberId} : null,
      cachePolicy: CachePolicy.forceCache);
  final records = (response.data ?? []).cast<Map<String, dynamic>>();
  records.sort((a, b) =>
      (b['uploaded_at'] as String).compareTo(a['uploaded_at'] as String));
  return records;
});

final recordMedicationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, recordId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/records/$recordId/full');
  final clinical = response.data?['clinical'] as Map<String, dynamic>?;
  return ((clinical?['medications'] as List<dynamic>?) ?? [])
      .cast<Map<String, dynamic>>();
});

class MedicationsController {
  MedicationsController(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AppLocalizations get _t => _ref.read(appLocalizationsProvider);

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response =
        await _api.post<Map<String, dynamic>>('/medications', data: body);
    await _api.clearCachePath('/medications');
    final reminder = response.data!;
    await _scheduleLocalNotifications(reminder['id'] as String);
    return reminder;
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final response =
        await _api.patch<Map<String, dynamic>>('/medications/$id', data: body);
    await _api.clearCachePath('/medications');
    final reminder = response.data!;
    if (reminder['status'] == 'active' &&
        reminder['push_reminders_enabled'] == true) {
      await _scheduleLocalNotifications(id);
    } else {
      await MedicationNotificationService.instance.cancelForReminder(
        id,
        channelName: _t.medNotifChannelName,
        channelDescription: _t.medNotifChannelDescription,
      );
    }
    return reminder;
  }

  Future<void> delete(String id) async {
    await _api.delete('/medications/$id');
    await _api.clearCachePath('/medications');
    await MedicationNotificationService.instance.cancelForReminder(
      id,
      channelName: _t.medNotifChannelName,
      channelDescription: _t.medNotifChannelDescription,
    );
  }

  Future<void> markDose(String reminderId, String status, String scheduledAtIso) async {
    await _api.post('/medications/$reminderId/doses/status', data: {
      'status': status,
      'scheduled_at': scheduledAtIso,
    });
    await _api.clearCachePath('/medications');
  }

  /// Fetches this reminder's upcoming dose instants and schedules the on-device alarm-style
  /// notifications for them - call after create/update so the mobile reminder channel stays
  /// in sync with the schedule stored on the backend.
  Future<void> _scheduleLocalNotifications(String reminderId) async {
    final response = await _api.get<List<dynamic>>(
        '/medications/$reminderId/schedule',
        queryParameters: {'days_ahead': 30});
    final doses = (response.data ?? []).cast<Map<String, dynamic>>();
    if (doses.isEmpty) return;
    final medicationName = doses.first['medication_name'] as String;
    final dosage = doses.first['dosage'] as String?;
    final body = dosage != null && dosage.isNotEmpty
        ? _t.medNotifReminderBodyWithDosage(medicationName, dosage)
        : _t.medNotifReminderBody(medicationName);
    await MedicationNotificationService.instance.rescheduleForReminder(
      reminderId: reminderId,
      notificationTitle: _t.medNotifReminderTitle,
      notificationBody: body,
      channelName: _t.medNotifChannelName,
      channelDescription: _t.medNotifChannelDescription,
      upcomingDoseInstantsUtc:
          doses.map((d) => DateTime.parse(d['scheduled_at'] as String)).toList(),
    );
  }
}

final medicationsControllerProvider = Provider<MedicationsController>(
  (ref) => MedicationsController(ref),
);
