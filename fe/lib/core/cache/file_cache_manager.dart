import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk cache for downloaded record documents (PDF/image) and profile
/// photos. 7-day max age per the caching plan.
///
/// Callers MUST pass a stable `key` (e.g. `record_id`) rather than relying on
/// the default url-based key wherever the url is a presigned S3 URL - those
/// rotate on every fetch (15-min TTL), so caching by url alone would never hit.
class RecordFileCacheManager extends CacheManager {
  static const key = 'record_file_cache';

  static final RecordFileCacheManager instance = RecordFileCacheManager._();

  RecordFileCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          // ponytail: flutter_cache_manager only caps by object count, not raw
          // bytes, so 500MB is approximated assuming ~3.3MB/file (medical
          // scans/PDFs). Upgrade to a real byte cap if average file size grows -
          // e.g. a periodic directory-size sweep evicting oldest-first.
          maxNrOfCacheObjects: 150,
        ));
}
