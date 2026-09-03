import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// True once the initial connectivity check resolves, then live-updates as
/// connectivity changes for the rest of the app session. A `none` result only
/// means "no network interface" - it doesn't guarantee internet reachability,
/// but it's what every screen in the app checks before gating upload/AI/sharing
/// or showing the offline banner.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  yield _isOnline(await Connectivity().checkConnectivity());
  yield* Connectivity().onConnectivityChanged.map(_isOnline);
});
