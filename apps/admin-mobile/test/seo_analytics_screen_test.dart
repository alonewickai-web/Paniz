import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panizstyle_admin/core/admin_api.dart';
import 'package:panizstyle_admin/core/providers.dart';
import 'package:panizstyle_admin/features/dashboard/seo_analytics_screen.dart';

const owner = AdminIdentity(
  id: '1',
  fullName: 'مدیر',
  username: 'owner',
  phone: '',
  role: 'owner',
);

JsonMap fixture(bool connected) => {
  'range': {'start': '2026-10-01', 'end': '2026-10-07'},
  'sources': {
    'searchConsole': {
      'state': connected ? 'connected' : 'needs_configuration',
      'reason': 'دسترسی حساب هنوز تنظیم نشده است.',
    },
    'analytics': {
      'state': connected ? 'connected' : 'needs_configuration',
      'reason': 'دسترسی حساب هنوز تنظیم نشده است.',
    },
  },
  'metrics': {
    'google': {
      'clicks': connected ? 20 : null,
      'impressions': connected ? 200 : null,
      'averagePosition': connected ? 3.5 : null,
      'ctrPercent': connected ? 10 : null,
    },
    'analytics': {
      'users': connected ? 30 : null,
      'activeUsers': connected ? 25 : null,
      'newUsers': connected ? 5 : null,
      'sessions': connected ? 50 : null,
    },
    'store': {
      'paidOrders': 0,
      'conversionPercent': connected ? 0 : null,
      'organicRevenueToman': null,
    },
    'comparison': {},
  },
  'daily': [
    for (var index = 1; index <= 7; index++)
      {
        'date': '2026-10-0$index',
        'googleClicks': connected ? index * 2 : null,
        'previousGoogleClicks': connected ? index : null,
        'googleImpressions': connected ? index * 20 : null,
        'previousGoogleImpressions': connected ? index * 10 : null,
        'visitors': connected ? index * 3 : null,
        'previousVisitors': connected ? index * 2 : null,
      },
  ],
  'queries': [],
  'products': [],
  'pages': [],
  'alerts': [],
  'audit': {'publishedProducts': 0},
  'notes': [],
};

Widget app(JsonMap data, {bool dark = false, double scale = 1}) =>
    ProviderScope(
      overrides: [seoAnalyticsProvider('28').overrideWith((ref) async => data)],
      child: MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme:
            dark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData(useMaterial3: true),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: const Scaffold(body: SeoAnalyticsScreen(admin: owner)),
      ),
    );

void main() {
  testWidgets(
    'unconfigured Google accounts stay unknown on a small phone with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(fixture(false), scale: 1.5));
      await tester.pumpAndSettle();
      expect(find.text('نیازمند اتصال'), findsOneWidget);
      expect(find.text('گزارش واقعی گوگل دریافت شد'), findsNothing);
      for (var index = 0; index < 8; index++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'the dark landscape chart shows an exact value after touching a day',
    (tester) async {
      tester.view.physicalSize = const Size(812, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(fixture(true), dark: true, scale: 1.3));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('seo-chart')),
        450,
        scrollable:
            find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('seo-chart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('seo-chart')));
      await tester.pumpAndSettle();
      expect(find.textContaining('۸ · دورهٔ قبل: ۴'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
