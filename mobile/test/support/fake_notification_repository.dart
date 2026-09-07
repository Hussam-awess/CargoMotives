import 'package:cargo_motives/features/notifications/data/notification_repository.dart';

class FakeNotificationRepository extends NotificationRepository {
  FakeNotificationRepository({
    this.onList,
    this.onUnreadCount,
    this.onMarkRead,
    this.onMarkAllRead,
    this.onRegisterDeviceToken,
    this.onDeleteDeviceToken,
  });

  final Future<List<AppNotification>> Function()? onList;
  final Future<int> Function()? onUnreadCount;
  final Future<void> Function(int notificationId)? onMarkRead;
  final Future<void> Function()? onMarkAllRead;
  final Future<void> Function({required String token, required String platform})? onRegisterDeviceToken;
  final Future<void> Function(String token)? onDeleteDeviceToken;

  @override
  Future<List<AppNotification>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<int> unreadCount() => onUnreadCount?.call() ?? Future.value(0);

  @override
  Future<void> markRead(int notificationId) => onMarkRead?.call(notificationId) ?? Future.value();

  @override
  Future<void> markAllRead() => onMarkAllRead?.call() ?? Future.value();

  @override
  Future<void> registerDeviceToken({required String token, required String platform}) =>
      onRegisterDeviceToken?.call(token: token, platform: platform) ?? Future.value();

  @override
  Future<void> deleteDeviceToken(String token) => onDeleteDeviceToken?.call(token) ?? Future.value();
}
