import 'package:flutter/material.dart';

import 'app.dart';
import 'core/localization/locale_controller.dart';
import 'core/push/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = await LocaleController.load();

  // Best-effort — see PushNotificationService's docblock for why this
  // never throws even without a real Firebase project configured yet.
  await PushNotificationService().initialize();

  runApp(CargoMotivesApp(localeController: localeController));
}
