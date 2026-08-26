import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/cache/http_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final httpCacheStore = await createEncryptedHttpCacheStore();
  runApp(ProviderScope(
    overrides: [httpCacheStoreProvider.overrideWithValue(httpCacheStore)],
    child: const CurecordAiApp(),
  ));
}
