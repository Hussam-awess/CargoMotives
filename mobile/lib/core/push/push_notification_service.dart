import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/company/jobs/company_job_detail_screen.dart';
import '../../features/jobs/job_detail_screen.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/notifications_screen.dart';
import '../auth/session_store.dart';
import '../routing/app_router.dart';

const _androidChannel = AndroidNotificationChannel(
  'cargo_motives_default',
  'Cargo Motives',
  description: 'Shipment updates, new bids, and other account activity.',
  importance: Importance.high,
);

/// Runs in a separate background isolate (no access to this instance's
/// state) whenever a push arrives while the app is backgrounded or
/// terminated — required by firebase_messaging even though there's nothing
/// to do here: Android/iOS already display the OS notification themselves
/// from the payload's notification block (using the manifest's
/// default_notification_icon/_color — see AndroidManifest.xml), and tapping
/// it is handled by [FirebaseMessaging.onMessageOpenedApp]/`getInitialMessage()`
/// once the app is actually running again.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Wires this device into Firebase Cloud Messaging (TRD §1/§12) — the
/// actual push-delivery half of the notification system; the in-app list
/// (NotificationRepository/NotificationsScreen) works identically with or
/// without this ever succeeding.
///
/// A real "cargo-motives" Firebase project is configured (google-services.json
/// / GoogleService-Info.plist) and the backend actually sends via
/// kreait/firebase-php (PUSH_DRIVER=firebase) — so every method here is
/// still deliberately best-effort and never throws (the same graceful-
/// degradation principle already applied to SMS_DRIVER=log and the missing
/// Google Maps key), but for a different reason now: a device without
/// notification permission, a stale token, or a momentary Firebase hiccup
/// must never break the rest of the app, not because the project itself is
/// unconfigured.
///
/// Three delivery states, three handlers:
///  - Foreground: FCM delivers the message silently (no OS banner on
///    Android) — [_showForegroundNotification] uses flutter_local_notifications
///    to display one manually, via the same channel/icon/color the manifest
///    already declares for the OS-shown case.
///  - Background (app alive, not focused): the OS shows the notification
///    itself from the payload; tapping it fires [FirebaseMessaging.onMessageOpenedApp].
///  - Terminated: same OS display; tapping it cold-starts the app, and the
///    tapped message is recovered once via [FirebaseMessaging.getInitialMessage].
/// All three tap paths converge on [_openFromData], which reuses the same
/// role-specific job-detail screens NotificationsScreen's own onTapJob
/// already pushes — deliberately not a deep-link route, since there is no
/// bare `/job/:id` entry in the go_router table (job detail is only ever
/// reached by pushing straight from a role's home shell) and adding one
/// would mean duplicating that role branch there too.
///
/// Deliberately NOT unregistering the device token on logout: re-registering
/// upserts by token (backend's DeviceToken::updateOrCreate keyed on the
/// token itself), so a different account logging in on the same physical
/// device correctly takes over that token's ownership on its own next
/// registration. The only gap this leaves is the window between logout and
/// the next login on that device, which is an acceptable, deliberately
/// deferred nicety rather than a correctness issue.
class PushNotificationService {
  /// A singleton, deliberately: [initialize] runs once from main() and sets
  /// [_initialized] on that instance; every screen that later calls
  /// [registerDeviceToken] must see that same flag, not a fresh `false` on
  /// a brand-new object. A plain constructor here was a real, confirmed bug
  /// — `PushNotificationService()` in each home shell created its own
  /// never-initialized instance, so registration silently no-opped on
  /// every single launch regardless of Firebase/permission/token state.
  factory PushNotificationService() => _instance;

  PushNotificationService._internal({NotificationRepository? notificationRepository, SessionStore? sessionStore})
    : _notifications = notificationRepository ?? NotificationRepository(),
      _sessionStore = sessionStore ?? SessionStore();

  static final PushNotificationService _instance = PushNotificationService._internal();

  final NotificationRepository _notifications;
  final SessionStore _sessionStore;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Call once, early in main() — before any screen might call
  /// [registerDeviceToken].
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (_) {
      _initialized = false;
      return;
    }

    await _initLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _openFromData(message.data));

    // The app was cold-started by tapping a notification — getInitialMessage
    // only ever returns a non-null value the first time it's checked, so
    // there's no risk of re-opening the same job on a later hot restart.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openFromData(initialMessage.data);
  }

  Future<void> _initLocalNotifications() async {
    try {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_cargo_motives'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null) return;
          _openFromData((jsonDecode(payload) as Map).cast<String, dynamic>());
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // iOS/macOS show the OS banner for a foreground push on their own
      // (no local-notifications gap the way Android has) once asked to.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Best-effort — see class docblock.
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final notification = message.notification;
    if (notification == null) return;

    // Prefer the backend's own notification id (stable, one row per event)
    // so re-showing the same push twice updates one entry in the shade
    // instead of stacking a duplicate under a hash-derived id.
    final id = int.tryParse('${message.data['notification_id']}') ?? notification.hashCode;

    _localNotifications.show(
      id,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: 'ic_stat_cargo_motives',
          color: const Color(0xFF16294B),
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _openFromData(Map<String, dynamic> data) async {
    final notificationId = int.tryParse('${data['notification_id']}');
    if (notificationId != null) {
      // Best-effort — a failure here shouldn't block navigation.
      unawaited(_notifications.markRead(notificationId).catchError((_) {}));
    }

    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final jobId = int.tryParse('${data['related_job_id']}');
    final role = await _sessionStore.getRole();
    if (role == null) return;
    if (!context.mounted) return;

    if (jobId == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsScreen(repository: _notifications)));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            role == AccountRole.customer ? JobDetailScreen(jobId: jobId) : CompanyJobDetailScreen(jobId: jobId),
      ),
    );
  }

  /// Call once an authenticated session exists — both right after login
  /// and at app startup when Splash resumes an existing session, since
  /// either path lands on one of the two home shells.
  Future<void> registerDeviceToken() async {
    if (!_initialized) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

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
