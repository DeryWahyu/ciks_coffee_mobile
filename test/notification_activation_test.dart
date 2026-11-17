import 'package:ciks_coffee_mobile/screens/profile_screen.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'read' ? 'audit-token' : null,
        );
  });

  for (final status in [
    AuthorizationStatus.denied,
    AuthorizationStatus.notDetermined,
  ]) {
    test('permission $status is distinguished from a server failure', () async {
      var requests = 0;
      final service = PushNotificationService(
        messaging: _Messaging(status: status),
        apiService: ApiService(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        ),
      );
      final result = await service.setEnabled(true);
      expect(result.status, NotificationActivationStatus.permissionDenied);
      expect(result.message, contains('Izin notifikasi'));
      expect(requests, 0);
    });
  }

  test('a missing token does not claim permission was denied', () async {
    final result = await PushNotificationService(
      messaging: _Messaging(token: null),
    ).setEnabled(true);
    expect(result.status, NotificationActivationStatus.tokenUnavailable);
    expect(result.message, contains('Layanan notifikasi perangkat belum siap'));
  });

  test(
    'registration failure retains the server reason with permission granted',
    () async {
      final service = PushNotificationService(
        messaging: _Messaging(),
        apiService: ApiService(
          client: MockClient(
            (_) async => http.Response(
              '{"message":"Layanan sedang dalam pemeliharaan. Coba lagi 15 menit."}',
              503,
            ),
          ),
        ),
      );
      final result = await service.setEnabled(true);
      expect(result.status, NotificationActivationStatus.serverUnavailable);
      expect(result.enabled, isFalse);
      expect(result.message, contains('pemeliharaan'));
      expect(result.message, isNot(contains('Izin notifikasi')));
    },
  );

  test('a network exception gives connection advice', () async {
    final result = await PushNotificationService(
      messaging: _Messaging(),
      apiService: ApiService(
        client: MockClient((_) async => throw http.ClientException('network')),
      ),
    ).setEnabled(true);
    expect(result.status, NotificationActivationStatus.serverUnavailable);
    expect(result.message, contains('koneksi'));
  });

  test('successful registration enables notifications', () async {
    final result = await PushNotificationService(
      messaging: _Messaging(status: AuthorizationStatus.provisional),
      apiService: ApiService(
        client: MockClient((_) async => http.Response('{}', 201)),
      ),
    ).setEnabled(true);
    expect(result.enabled, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('notifications_enabled'),
      isTrue,
    );
  });

  testWidgets('profile shows connection advice rather than permission advice', (
    tester,
  ) async {
    final service = PushNotificationService(
      messaging: _Messaging(),
      apiService: ApiService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          home: ProfileScreen(
            apiService: _ProfileApi(),
            notificationService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Periksa koneksi'), findsOneWidget);
    expect(find.textContaining('Izin notifikasi belum aktif'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Messaging extends Fake implements FirebaseMessaging {
  _Messaging({
    this.status = AuthorizationStatus.authorized,
    this.token = 'device-token',
  });
  final AuthorizationStatus status;
  final String? token;
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => _Settings(status);
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => token;
}

class _Settings extends Fake implements NotificationSettings {
  _Settings(this.authorizationStatus);
  @override
  final AuthorizationStatus authorizationStatus;
}

class _ProfileApi extends ApiService {
  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'success': true,
    'data': {
      'id': 1,
      'name': 'Audit',
      'email': 'audit@example.test',
      'role': 'pengguna',
    },
  };
}
