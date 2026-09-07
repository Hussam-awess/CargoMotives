import '../../../core/network/api_client.dart';

/// An in-app notification (Backend Schema §2.18) — AppFlow §6's Notification
/// Trigger Map, surfaced behind a bell icon on each role's home tab (AppFlow
/// §3.1) rather than a dedicated bottom-nav item.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedJobId,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      relatedJobId: json['related_job_id'] as int?,
      readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final int? relatedJobId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
}

/// REST client for the notification list + FCM device-token registration
/// (Backend Schema §2.18). Deliberately plain REST + refresh-on-open (TRD
/// §4 — notification lists are explicitly not one of the two WebSocket use
/// cases), matching NotificationController's own docblock.
class NotificationRepository {
  NotificationRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<AppNotification>> list() async {
    final body = await _client.get('/notifications');

    return (body['data'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final body = await _client.get('/notifications/unread-count');

    return body['unread_count'] as int;
  }

  Future<void> markRead(int notificationId) async {
    await _client.post('/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _client.post('/notifications/read-all');
  }

  Future<void> registerDeviceToken({required String token, required String platform}) async {
    await _client.post('/notifications/device-token', data: {'token': token, 'platform': platform});
  }

  Future<void> deleteDeviceToken(String token) async {
    await _client.delete('/notifications/device-token', data: {'token': token});
  }
}
