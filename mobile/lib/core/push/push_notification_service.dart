import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../../features/notifications/data/notification_repository.dart';

/// Wires this device into Firebase Cloud Messaging (TRD §1/§12) — the
/// actual push-delivery half of the notification system; the in-app list
/// (NotificationRepository/NotificationsScreen) works identically with or
/// without this ever succeeding.
///
/// No real Firebase project is configured in this environment yet (no
/// google-services.json / GoogleService-Info.plist / web firebaseConfig —
/// see the README for what `flutterfire configure` needs), so every method
/// here is deliberately best-effort and never throws: the exact same
/// graceful-degradation principle already applied to SMS_DRIVER=log and the
/// missing Google Maps key. [initialize] failing just means [registerDeviceToken]
/// silently becomes a no-op — the rest of the app is unaffected.
///
/// Deliberately NOT unregistering the device token on logout: re-registering
/// upserts by token (backend's DeviceToken::updateOrCreate keyed on the
/// token itself), so a different account logging in on the same physical
/// device correctly takes over that token's ownership on its own next
/// registration. The only gap this leaves is the window between logout and
/// the next login on that device, which is an acceptable, deliberately
/// deferred nicety rather than a correctness issue.
class PushNotificationService {
  PushNotificationService({NotificationRepository? notificationRepository})
    : _notifications = notificationRepository ?? NotificationRepository();

  final NotificationRepository _notifications;
  bool _initialized = false;

  /// Call once, early in main() — before any screen might call
  /// [registerDeviceToken].
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  /// Call once an authenticated session exists — both right after login
  /// and at app startup when Splash resumes an existing session, since
  /// either path lands on one of the two home shells.
  Future<void> registerDeviceToken() async {
    if (!_initialized) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _notifications.registerDeviceToken(token: token, platform: _platform());
    } catch (_) {
      // Best-effort — see class docblock.
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';

    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
