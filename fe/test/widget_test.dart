// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:curecordai/app.dart';
import 'package:curecordai/core/cache/http_cache.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mirrors main()'s ProviderScope, but overrides httpCacheStoreProvider with
    // an in-memory store instead of createEncryptedHttpCacheStore() - that
    // factory touches flutter_secure_storage and path_provider, both of which
    // need platform channels unavailable in a plain widget test.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [httpCacheStoreProvider.overrideWithValue(MemCacheStore())],
        child: const CurecordAiApp(),
      ),
    );
  });
}
