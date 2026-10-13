import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdminPushNotifications.initialize();
  await AdminPushNotifications.handleInitialMessage();
  runApp(const ProviderScope(child: PanizAdminApp()));
}
