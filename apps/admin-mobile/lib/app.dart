import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/admin_api.dart';
import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/home/admin_home.dart';

const panizPrimary = Color(0xFF0F766E);
const panizRose = panizPrimary;
const panizMint = Color(0xFF99F6E4);
const panizPeach = Color(0xFFFDBA74);
const panizLilac = Color(0xFFC4B5FD);
const panizCoral = Color(0xFFFDA4AF);
const panizError = Color(0xFFDC2626);
const panizCanvas = Color(0xFFF8FAFC);
const panizInk = Color(0xFF1E293B);
const panizMuted = Color(0xFF64748B);
const panizLine = Color(0xFFE2E8F0);

class PanizAdminApp extends ConsumerWidget {
  const PanizAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'مدیریت PanizStyle',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: panizPrimary,
          brightness: Brightness.light,
          surface: Colors.white,
          error: panizError,
        ),
        scaffoldBackgroundColor: panizCanvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: panizCanvas,
          foregroundColor: panizInk,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: panizLine),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: panizMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: panizLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: panizLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: panizPrimary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE6FFFA),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected) ? panizPrimary : panizMuted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          )),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: panizPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: auth.when(
        loading: () => const _LoadingScreen(),
        error: (error, _) => _AppErrorScreen(error: AdminApi.friendlyError(error)),
        data: (admin) => admin == null ? const LoginScreen() : AdminHome(admin: admin),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: panizPrimary)),
  );
}

class _AppErrorScreen extends ConsumerWidget {
  const _AppErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: panizError),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => ref.invalidate(authProvider), child: const Text('تلاش دوباره')),
        ]),
      ),
    ),
  );
}
