import 'package:flutter/foundation.dart';

/// How this device labels its sign-in session on the server — what the
/// user sees in Settings > Active sessions to tell their devices apart.
/// Deliberately coarse (platform only, no model/serial): enough to spot
/// "an iPhone I don't own", without collecting a device fingerprint.
String currentDeviceName() {
  if (kIsWeb) return 'Web browser';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android device',
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.windows => 'Windows PC',
    TargetPlatform.linux => 'Linux PC',
    TargetPlatform.fuchsia => 'Mobile app',
  };
}
