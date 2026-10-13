import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

final adminNavigatorKey = GlobalKey<NavigatorState>();
final adminScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> panizFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AdminPushNotifications {
  AdminPushNotifications._();

  static FirebaseMessaging? _messaging;
  static StreamSubscription<String>? _tokenSubscription;
  static bool _pendingInboxNavigation = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;
      FirebaseMessaging.onBackgroundMessage(panizFirebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? 'اعلان تازه';
        final body = message.notification?.body ?? '';
        adminScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(body.isEmpty ? title : '$title\n$body'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        final navigator = adminNavigatorKey.currentState;
        if (navigator == null) {
          _pendingInboxNavigation = true;
        } else {
          navigator.pushNamed('/admin-notifications');
        }
      });
    } catch (_) {
      // The app can run without Firebase until its Android project is configured.
      _messaging = null;
    }
  }

  static Future<String?> requestToken() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return null;
      }
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> watchTokenChanges(Future<void> Function(String token) onToken) async {
    await _tokenSubscription?.cancel();
    final messaging = _messaging;
    if (messaging == null) return;
    _tokenSubscription = messaging.onTokenRefresh.listen((token) {
      unawaited(onToken(token).catchError((_) {}));
    });
  }

  static Future<String?> currentToken() async {
    try {
      return await _messaging?.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> handleInitialMessage() async {
    try {
      final message = await _messaging?.getInitialMessage();
      if (message != null) {
        _pendingInboxNavigation = true;
      }
    } catch (_) {}
  }

  static bool takePendingInboxNavigation({required bool isOwner}) {
    if (!isOwner || !_pendingInboxNavigation) return false;
    _pendingInboxNavigation = false;
    return true;
  }

  static Future<void> stopWatchingTokens() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}
