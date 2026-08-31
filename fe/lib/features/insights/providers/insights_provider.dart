import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../family/providers/active_profile_provider.dart';

final healthSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final params = <String, dynamic>{};
  if (memberId != null) params['family_member_id'] = memberId;
  final response = await api.get<Map<String, dynamic>>(
    '/insights/summary',
    queryParameters: params.isEmpty ? null : params,
    cachePolicy: CachePolicy.refreshForceCache,
  );
  return response.data ?? {};
});

final observationTrendProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, loincCode) async {
  final api = ref.watch(apiClientProvider);
  final memberId = ref.watch(activeMemberIdProvider);
  final params = <String, dynamic>{};
  if (memberId != null) params['family_member_id'] = memberId;
  final response = await api.get<Map<String, dynamic>>(
    '/insights/trends/$loincCode',
    queryParameters: params.isEmpty ? null : params,
  );
  return response.data ?? {};
});
