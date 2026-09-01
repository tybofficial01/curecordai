import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

final familyMembersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/family',
      cachePolicy: CachePolicy.forceCache);
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

final familyMemberDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, memberId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>('/family/$memberId',
      cachePolicy: CachePolicy.forceCache);
  return response.data ?? {};
});

/// Call after any add/edit/delete under `/family` so the sidebar "Switch
/// profile" list and the Family Management screen pick up the change right
/// away, instead of only after the app restarts. `refreshForceCache` forces
/// a real network round-trip and rewrites the cached `/family` response
/// (rather than relying on the cache-clear having matched and removed the
/// stale entry first), then invalidating [familyMembersProvider] makes its
/// next `forceCache` read pick up that freshly-written entry.
Future<void> refreshFamilyMembers(WidgetRef ref) async {
  final api = ref.read(apiClientProvider);
  await api.get<List<dynamic>>('/family',
      cachePolicy: CachePolicy.refreshForceCache);
  ref.invalidate(familyMembersProvider);
}
