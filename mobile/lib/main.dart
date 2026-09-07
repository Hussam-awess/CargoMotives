import 'package:flutter/material.dart';

import 'app.dart';
import 'core/localization/locale_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = await LocaleController.load();

  runApp(CargoMotivesApp(localeController: localeController));
}
