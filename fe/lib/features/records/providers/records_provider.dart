import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../family/providers/active_profile_provider.dart';

final recordsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final params = <String, dynamic>{};
  if (memberId != null) params['family_member_id'] = memberId;
  final response = await api.get<List<dynamic>>(
    '/records',
    queryParameters: params.isEmpty ? null : params,
    cachePolicy: CachePolicy.forceCache,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

final recordDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/records/$id',
      cachePolicy: CachePolicy.forceCache);
  return response.data ?? {};
});

/// Records scoped to a specific patient - null familyMemberId means the account owner's own
/// records (the backend now enforces this exactly: omitted family_member_id means "self
/// only", never "everyone"). Used by the AI chat attachment picker so only records in scope
/// for the active chat session's patient are ever offered for attaching.
final recordsByFamilyMemberProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
        (ref, familyMemberId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>(
    '/records',
    queryParameters:
        familyMemberId != null ? {'family_member_id': familyMemberId} : null,
    cachePolicy: CachePolicy.forceCache,
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

final foldersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/records/folders',
      cachePolicy: CachePolicy.forceCache);
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

final recordClinicalProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/records/$id/clinical',
      cachePolicy: CachePolicy.forceCache);
  return response.data ?? {};
});

/// Record details + clinical entities in one round trip - used by the Record Detail
/// screen so it doesn't have to wait on two sequential requests to render fully.
///
/// Deliberately NOT cached: while `processing_status == 'processing'`, the detail
/// screen polls this every 3s via `ref.invalidate` to reflect the AI extraction
/// pipeline finishing - a forceCache/refreshForceCache policy here would serve the
/// same stale "processing" response for up to the cache's maxStale window and the
/// UI would never see completion. Cache invalidation after edits still applies via
/// `ApiClient.clearCachePath('/records')`.
final recordFullProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/records/$id/full');
  return response.data ?? {};
});

/// Calls POST /records/folders and invalidates foldersProvider on success.
Future<void> createFolder(
  WidgetRef ref, {
  required String name,
  String? icon,
}) async {
  final api = ref.read(apiClientProvider);
  await api.post('/records/folders', data: {'name': name, 'icon': icon});
  await api.clearCachePath('/records/folders');
  ref.invalidate(foldersProvider);
}
