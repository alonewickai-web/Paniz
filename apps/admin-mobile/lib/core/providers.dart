import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import 'admin_api.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  final api = AdminApi();
  ref.onDispose(() => api.dio.close(force: true));
  return api;
});

final authProvider = AsyncNotifierProvider<AuthController, AdminIdentity?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AdminIdentity?> {
  static const _storage = FlutterSecureStorage();
  static const _biometricKey = 'paniz.admin.biometric-unlock';
  static const _biometricChannel = MethodChannel('paniz/admin-biometric');

  Future<bool> _authenticateWithBiometrics() async {
    try {
      return await _biometricChannel.invokeMethod<bool>('authenticate') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<AdminIdentity?> build() async {
    final api = ref.read(adminApiProvider);
    if (await _storage.read(key: _biometricKey) == 'true' &&
        await api.hasSavedSession()) {
      final unlocked = await _authenticateWithBiometrics();
      if (!unlocked) return null;
    }
    final admin = await api.restoreSession();
    if (admin != null) unawaited(api.resumeNotificationMonitoringIfEnabled());
    return admin;
  }

  Future<bool> unlockWithBiometrics() async {
    final unlocked = await _authenticateWithBiometrics();
    if (!unlocked) return false;
    final admin = await ref.read(adminApiProvider).restoreSession();
    state = AsyncData(admin);
    return admin != null;
  }

  Future<bool> setBiometricsEnabled(bool enabled) async {
    if (!enabled) {
      await _storage.write(key: _biometricKey, value: 'false');
      return false;
    }
    final available =
        await _biometricChannel.invokeMethod<bool>('isAvailable') ?? false;
    if (!available) {
      throw const AdminApiException(
        'روی این دستگاه اثر انگشت یا زیست‌سنجی فعالی پیدا نشد.',
      );
    }
    final confirmed = await _authenticateWithBiometrics();
    if (confirmed) await _storage.write(key: _biometricKey, value: 'true');
    return confirmed;
  }

  Future<void> login(String username, String password) async {
    final api = ref.read(adminApiProvider);
    final admin = await api.login(username, password);
    state = AsyncData(admin);
    unawaited(api.resumeNotificationMonitoringIfEnabled());
  }

  Future<void> logout() async {
    try {
      await ref.read(adminApiProvider).logout();
    } finally {
      state = const AsyncData(null);
    }
  }

  Future<void> clearLocalSession() async {
    await ref.read(adminApiProvider).clearSession();
    state = const AsyncData(null);
  }

  Future<void> refreshIdentity() async {
    final admin = await ref.read(adminApiProvider).restoreSession();
    state = AsyncData(admin);
  }
}

final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'paniz.admin.biometric-unlock') == 'true';
});

final themeModeProvider =
    AsyncNotifierProvider<AdminThemeController, ThemeMode>(
      AdminThemeController.new,
    );

class AdminThemeController extends AsyncNotifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'paniz.admin.theme-mode';

  @override
  Future<ThemeMode> build() async {
    final stored = await _storage.read(key: _key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setDark(bool enabled) async {
    final selected = enabled ? ThemeMode.dark : ThemeMode.light;
    state = AsyncData(selected);
    try {
      await _storage.write(key: _key, value: enabled ? 'dark' : 'light');
    } catch (_) {
      // Keep the selected theme for this session when secure storage is unavailable.
    }
  }
}

final dashboardProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) => ref.watch(adminApiProvider).dashboard(),
);
final siteVisitAnalyticsProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) => ref.watch(adminApiProvider).siteVisitAnalytics(),
);
final seoAnalyticsProvider = FutureProvider.autoDispose.family<JsonMap, String>((ref, rangeKey) {
  final parts = rangeKey.split(':');
  if (parts.first == 'custom' && parts.length == 3) {
    return ref.watch(adminApiProvider).seoAnalytics(range: 'custom', from: parts[1], to: parts[2]);
  }
  return ref.watch(adminApiProvider).seoAnalytics(range: parts.first);
});
final financeReportProvider = FutureProvider.autoDispose.family<JsonMap, String>(
  (ref, range) => ref.watch(adminApiProvider).financeReport(range),
);
final storeConfigurationProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) => ref.watch(adminApiProvider).storeConfiguration(),
);
final publicStoreConfigurationProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) => ref.watch(adminApiProvider).publicStoreConfiguration(),
);
final productsProvider = FutureProvider.autoDispose<List<JsonMap>>(
  (ref) => ref.watch(adminApiProvider).products(),
);
final categoriesProvider = FutureProvider.autoDispose<List<JsonMap>>((
  ref,
) async {
  return ref.watch(adminApiProvider).productCategories();
});
final ordersProvider = FutureProvider.autoDispose<List<JsonMap>>(
  (ref) => ref.watch(adminApiProvider).orders(),
);
final adminNotificationsProvider = FutureProvider.autoDispose<JsonMap>((ref) {
  final timer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(timer.cancel);
  return ref.watch(adminApiProvider).adminNotifications();
});
