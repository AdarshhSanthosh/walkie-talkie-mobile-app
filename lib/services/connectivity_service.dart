import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has *some* network path (spec §19: Wi-Fi ↔
/// mobile data changes, weak/lost network). Doesn't guarantee internet
/// reachability, just that an interface is up — good enough to know when
/// it's worth retrying a dropped connection.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});
