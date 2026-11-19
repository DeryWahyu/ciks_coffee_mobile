import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'user_message.dart';

enum NotificationActivationStatus {
  enabled,
  disabled,
  permissionDenied,
  tokenUnavailable,
  serverUnavailable,
}

class NotificationActivation {
  const NotificationActivation(this.status, {this.reason});
  final NotificationActivationStatus status;
  final String? reason;
  bool get enabled => status == NotificationActivationStatus.enabled;
  String get message => switch (status) {
    NotificationActivationStatus.enabled => 'Notifikasi berhasil diaktifkan.',
    NotificationActivationStatus.disabled => 'Notifikasi dinonaktifkan.',
    NotificationActivationStatus.permissionDenied =>
      'Izin notifikasi belum aktif. Periksa pengaturan aplikasi di perangkat.',
    NotificationActivationStatus.tokenUnavailable =>
      'Layanan notifikasi perangkat belum siap. Periksa koneksi internet lalu coba lagi beberapa saat.',
    NotificationActivationStatus.serverUnavailable => UserMessage.display(
      reason,
      fallback:
          'Notifikasi belum dapat dihubungkan ke server. Periksa koneksi lalu coba lagi.',
    ),
  };
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    ApiService? apiService,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _apiService = apiService ?? ApiService();

  static final PushNotificationService instance = PushNotificationService();

  static const String _preferenceKey = 'notifications_enabled';
  static const String _channelId = 'order_status_updates';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    'Status Pesanan',
    description: 'Pembaruan proses dan kesiapan pesanan Ciks Coffee.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService;
  final StreamController<Map<String, dynamic>> _orderStatusUpdates =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _statusNavigation =
      StreamController<void>.broadcast();

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _authenticated = false;
  bool _pendingStatusNavigation = false;
  String? _registeredToken;
  int? _registeredSession;
  String? get registeredToken =>
      _registeredSession == ApiService.sessionVersion ? _registeredToken : null;

  void invalidateRegistration() {
    _registeredToken = null;
    _registeredSession = null;
  }

  Stream<Map<String, dynamic>> get orderStatusUpdates =>
      _orderStatusUpdates.stream;

  Stream<void> get statusNavigation => _statusNavigation.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (_) => _navigateToOrderStatus(),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _pendingStatusNavigation = true;
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageOpened);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && _isOrderStatusMessage(initialMessage.data)) {
      _pendingStatusNavigation = true;
    }

    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      if (_authenticated) {
        unawaited(_registerTokenIfEnabled(token));
      }
    });
  }

  Future<void> initializeForAuthenticatedUser() async {
    _authenticated = true;
    await syncToken();
  }

  Future<NotificationActivation> getStatus() =>
      syncToken(requestPermission: false);

  Future<NotificationActivation> syncToken({
    bool requestPermission = true,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_preferenceKey) ?? true)) {
      return const NotificationActivation(
        NotificationActivationStatus.disabled,
      );
    }

    try {
      final settings = requestPermission
          ? await _messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : await _messaging.getNotificationSettings();
      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAuthorized) {
        return const NotificationActivation(
          NotificationActivationStatus.permissionDenied,
        );
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return const NotificationActivation(
          NotificationActivationStatus.tokenUnavailable,
        );
      }

      if (_registeredToken == token &&
          _registeredSession == ApiService.sessionVersion) {
        return const NotificationActivation(
          NotificationActivationStatus.enabled,
        );
      }
      final session = ApiService.sessionVersion;
      final result = await _apiService.registerDeviceToken(token);
      if (result['success'] == true && session == ApiService.sessionVersion) {
        _registeredToken = token;
        _registeredSession = session;
      }
      return result['success'] == true
          ? const NotificationActivation(NotificationActivationStatus.enabled)
          : NotificationActivation(
              NotificationActivationStatus.serverUnavailable,
              reason: result['message'] as String?,
            );
    } catch (error) {
      debugPrint('[PushNotification] token sync failed: $error');
      return const NotificationActivation(
        NotificationActivationStatus.serverUnavailable,
      );
    }
  }

  Future<NotificationActivation> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, enabled);

    if (!enabled) {
      final removed = await unregisterCurrentDevice();
      if (!removed) {
        await preferences.setBool(_preferenceKey, true);
        return const NotificationActivation(
          NotificationActivationStatus.serverUnavailable,
          reason:
              'Notifikasi belum dapat dinonaktifkan. Periksa koneksi lalu coba lagi.',
        );
      }
      _registeredToken = null;
      _registeredSession = null;
      return const NotificationActivation(
        NotificationActivationStatus.disabled,
      );
    }

    final activated = await syncToken();
    if (!activated.enabled) {
      await preferences.setBool(_preferenceKey, false);
    }
    return activated;
  }

  Future<String?> currentToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<bool> unregisterCurrentDevice() async {
    final token = await currentToken();
    var unregistered = false;
    if (token != null && token.isNotEmpty) {
      unregistered = await _apiService.unregisterDeviceToken(token);
    }

    try {
      await _messaging.deleteToken();
      return true;
    } catch (error) {
      debugPrint('[PushNotification] local token removal failed: $error');
      return unregistered;
    }
  }

  Future<void> onLoggedOut() async {
    _authenticated = false;
    _pendingStatusNavigation = false;
    _registeredToken = null;
    _registeredSession = null;

    try {
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('[PushNotification] logout token removal failed: $error');
    }
  }

  bool consumePendingStatusNavigation() {
    final pending = _pendingStatusNavigation;
    _pendingStatusNavigation = false;
    return pending;
  }

  Future<void> _registerTokenIfEnabled(String token) async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_preferenceKey) ?? true)) return;

    final session = ApiService.sessionVersion;
    final result = await _apiService.registerDeviceToken(token);
    if (result['success'] == true && session == ApiService.sessionVersion) {
      _registeredToken = token;
      _registeredSession = session;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_isOrderStatusMessage(message.data)) return;

    _orderStatusUpdates.add(Map<String, dynamic>.from(message.data));

    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_preferenceKey) ?? true)) return;

    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Status pesanan diperbarui';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'Buka aplikasi untuk melihat status pesananmu.';
    final orderId = int.tryParse(message.data['order_id']?.toString() ?? '');

    try {
      await _localNotifications.show(
        id: orderId ?? message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Status Pesanan',
            channelDescription:
                'Pembaruan proses dan kesiapan pesanan Ciks Coffee.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
          ),
        ),
        payload: 'order_status',
      );
    } catch (error) {
      debugPrint('[PushNotification] foreground display failed: $error');
    }
  }

  void _handleRemoteMessageOpened(RemoteMessage message) {
    if (_isOrderStatusMessage(message.data)) {
      _navigateToOrderStatus();
    }
  }

  bool _isOrderStatusMessage(Map<String, dynamic> data) {
    return data['type']?.toString() == 'order_status';
  }

  void _navigateToOrderStatus() {
    _pendingStatusNavigation = true;
    _statusNavigation.add(null);
  }
}
