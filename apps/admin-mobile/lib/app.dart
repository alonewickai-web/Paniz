import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/admin_api.dart';
import 'core/paniz_theme.dart';
import 'core/providers.dart';
import 'core/push_notification_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/admin_home.dart';
import 'features/auth/security_settings_screen.dart';
import 'features/notifications/notification_inbox_screen.dart';

class PanizAdminApp extends ConsumerWidget {
  const PanizAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    return MaterialApp(
      navigatorKey: adminNavigatorKey,
      scaffoldMessengerKey: adminScaffoldMessengerKey,
      title: 'PANIZ Admin',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: PanizTheme.light,
      darkTheme: PanizTheme.dark,
      themeMode: themeMode,
      routes: {
        '/admin-notifications': (_) => Scaffold(
          appBar: AppBar(title: const Text('اعلان‌ها')),
          body: const SafeArea(child: NotificationInboxScreen()),
        ),
      },
      home: auth.when(
        loading: () => const _LoadingScreen(),
        error: (error, _) => _AppErrorScreen(error: AdminApi.friendlyError(error)),
        data: (admin) => admin == null ? const LoginScreen() : admin.mustChangePassword
          ? Scaffold(appBar: AppBar(title: const Text('تغییر گذرواژهٔ موقت')), body: SafeArea(child: SecuritySettingsScreen(admin: admin)))
          : AdminHome(admin: admin),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

class _AppErrorScreen extends ConsumerWidget {
  const _AppErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 42, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => ref.invalidate(authProvider), child: const Text('تلاش دوباره')),
          ]),
        ),
      ),
    ),
  );
}
