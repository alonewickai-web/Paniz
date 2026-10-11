import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'admin_api.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  final api = AdminApi();
  ref.onDispose(() => api.dio.close(force: true));
  return api;
});

final authProvider = AsyncNotifierProvider<AuthController, AdminIdentity?>(AuthController.new);

class AuthController extends AsyncNotifier<AdminIdentity?> {
  @override
  Future<AdminIdentity?> build() => ref.read(adminApiProvider).restoreSession();

  Future<void> login(String username, String password) async {
    final admin = await ref.read(adminApiProvider).login(username, password);
    state = AsyncData(admin);
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
}

final themeModeProvider = AsyncNotifierProvider<AdminThemeController, ThemeMode>(AdminThemeController.new);

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

final dashboardProvider = FutureProvider.autoDispose<JsonMap>((ref) => ref.watch(adminApiProvider).dashboard());
final storeConfigurationProvider = FutureProvider.autoDispose<JsonMap>((ref) => ref.watch(adminApiProvider).storeConfiguration());
final productsProvider = FutureProvider.autoDispose<List<JsonMap>>((ref) => ref.watch(adminApiProvider).products());
final categoriesProvider = FutureProvider.autoDispose<List<JsonMap>>((ref) => ref.watch(adminApiProvider).categories());
final ordersProvider = FutureProvider.autoDispose<List<JsonMap>>((ref) => ref.watch(adminApiProvider).orders());
