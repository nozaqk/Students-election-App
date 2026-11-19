import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/session.dart';
import 'app.dart';
import 'native/notifications.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlay);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  // Restore a saved sign-in (if any) before the first frame so the right screen shows at once.
  await Session.instance.restore();
  await ElectionNotifications.init();

  runApp(const ElectionApp());
}
