import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  static const String _sessionKey = 'vm_active_session_id';

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<_SessionInfo> ensureSession() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(_sessionKey) ?? '').trim();

    final info = await PackageInfo.fromPlatform();
    final buildNumber = int.tryParse(info.buildNumber.trim()) ?? 0;
    final appVersion = '${info.version.trim()}+${info.buildNumber.trim()}';

    if (existing.isNotEmpty) {
      return _SessionInfo(
        sessionId: existing,
        buildNumber: buildNumber,
        appVersion: appVersion,
      );
    }

    final callable = _functions.httpsCallable('vmClaimSession');
    final result = await callable.call(<String, dynamic>{
      'buildNumber': buildNumber,
      'appVersion': appVersion,
      // A random hint helps avoid collisions even if server falls back.
      'clientNonce': '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}',
    });

    final data = result.data;
    final sessionId = data is Map ? (data['sessionId'] as String? ?? '') : '';
    if (sessionId.trim().isEmpty) {
      throw Exception('Unable to start session.');
    }
    await prefs.setString(_sessionKey, sessionId.trim());

    return _SessionInfo(
      sessionId: sessionId.trim(),
      buildNumber: buildNumber,
      appVersion: appVersion,
    );
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

class _SessionInfo {
  const _SessionInfo({
    required this.sessionId,
    required this.buildNumber,
    required this.appVersion,
  });

  final String sessionId;
  final int buildNumber;
  final String appVersion;
}

