import 'dart:async';
import 'dart:convert';
import 'package:ciks_coffee_mobile/models/user_model.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/login_screen.dart';
import 'package:ciks_coffee_mobile/screens/profile_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/services/app_info_service.dart';
import 'package:ciks_coffee_mobile/services/push_notification_service.dart';
import 'package:ciks_coffee_mobile/widgets/coffee_overlays.dart';
import 'package:ciks_coffee_mobile/widgets/profile_forms.dart';
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
  late Map<String, String> secure;
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': false,
      'session_user_id': 1,
      'cart_data': 'saved-cart',
      'pending_checkout': 'saved-checkout',
    });
    secure = {
      'auth_token': 'test-token',
      'auth_token_expires_at': '2099-01-01T00:00:00Z',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String?;
          if (call.method == 'read') return secure[key];
          if (call.method == 'write') secure[key!] = args['value'] as String;
          if (call.method == 'delete') secure.remove(key);
          return null;
        });
  });

  test(
    'profile API saves user data without clearing the basket or current session',
    () async {
      final version = ApiService.sessionVersion;
      final requests = <http.Request>[];
      final api = ApiService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'user': {..._user, 'name': 'Rani', 'email': 'rani@example.test'},
            }),
            200,
          );
        }),
      );
      final result = await api.updateProfile(
        name: ' Rani ',
        email: 'rani@example.test',
        phone: '081234567890',
        currentPassword: 'password123',
      );
      expect(result['success'], isTrue);
      expect((result['user'] as UserModel).name, 'Rani');
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, '/api/user');
      expect(
        jsonDecode(requests.single.body)['current_password'],
        'password123',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'Rani');
      expect(prefs.getString('cart_data'), 'saved-cart');
      expect(prefs.getString('pending_checkout'), 'saved-checkout');
      expect(secure['auth_token'], 'test-token');
      expect(ApiService.sessionVersion, version);
    },
  );

  test('profile API keeps readable field errors from the server', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Email sudah digunakan.',
            'errors': {
              'email': ['Email sudah digunakan.'],
            },
          }),
          422,
        ),
      ),
    );
    final result = await api.updateProfile(
      name: 'Rani',
      email: 'taken@example.test',
    );
    expect(result['success'], isFalse);
    expect(result['message'], 'Email sudah digunakan.');
    expect((result['errors'] as Map)['email'], ['Email sudah digunakan.']);
  });

  test(
    'password API uses the dedicated endpoint and retains this device session',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/user/password');
          expect(jsonDecode(request.body)['device_token'], 'this-device');
          return http.Response(
            '{"message":"Kata sandi berhasil diperbarui."}',
            200,
          );
        }),
      );
      expect(
        (await api.changePassword(
          currentPassword: 'password123',
          password: 'new-password123',
          confirmation: 'new-password123',
          deviceToken: 'this-device',
        ))['success'],
        isTrue,
      );
      expect(secure['auth_token'], 'test-token');
      expect(
        (await SharedPreferences.getInstance()).getString('pending_checkout'),
        'saved-checkout',
      );
    },
  );

  test(
    'app information comes from the installed application and settings failure is reported',
    () async {
      const channel = MethodChannel('com.cikscoffee.app/app_info');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'getAppInfo'
                ? {'version': '9.8.7', 'build': '456'}
                : true,
          );
      expect(await AppInfoService().version(), '9.8.7 (456)');
      expect(await AppInfoService().openNotificationSettings(), isTrue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'unavailable'),
          );
      expect(await AppInfoService().version(), isNull);
      expect(await AppInfoService().openNotificationSettings(), isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets(
    'profile removes duplicated account actions and saves edited details',
    (tester) async {
      final api = _ProfileApi();
      await _pump(tester, api);
      expect(find.text('Informasi Pribadi'), findsNothing);
      expect(find.text('Nomor Telepon'), findsNothing);
      await tester.tap(find.text('Edit profil'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-name')),
        'Rani Baru',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-email')),
        'rani@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-phone')),
        '081234567890',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-current_password')),
        'password123',
      );
      await _save(tester);
      expect(api.profileSaves, 1);
      expect(api.lastPassword, 'password123');
      expect(find.byType(ProfileFormSheet), findsNothing);
      expect(find.text('Rani Baru'), findsOneWidget);
      expect(find.text('rani@example.test'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a changed email requires current password and a server rejection keeps the form open',
    (tester) async {
      final api = _ProfileApi();
      await _pump(tester, api);
      await tester.tap(find.text('Edit profil'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-email')),
        'other@example.test',
      );
      await _save(tester);
      expect(api.profileSaves, 0);
      expect(find.text('Kata sandi saat ini wajib diisi.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-current_password')),
        'password123',
      );
      api.saveError = 'Email sudah digunakan. Gunakan email lain.';
      await _save(tester);
      expect(api.profileSaves, 1);
      expect(find.byType(ProfileFormSheet), findsOneWidget);
      expect(find.text(api.saveError!), findsWidgets);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('profile-field-email')),
            )
            .controller!
            .text,
        'other@example.test',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'password form checks confirmation and saves through the password API',
    (tester) async {
      final api = _ProfileApi();
      await _pump(tester, api);
      await tester.tap(find.text('Ubah kata sandi'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-current_password')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-password')),
        'new-password123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-password_confirmation')),
        'different-password',
      );
      await _save(tester);
      expect(api.passwordSaves, 0);
      expect(find.text('Konfirmasi kata sandi tidak cocok.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('profile-field-password_confirmation')),
        'new-password123',
      );
      await _save(tester);
      expect(api.passwordSaves, 1);
      expect(find.byType(ProfileFormSheet), findsNothing);
      expect(find.textContaining('Sesi di perangkat lain'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('language selection persists and updates profile labels', (
    tester,
  ) async {
    await _pump(tester, _ProfileApi());
    await tester.ensureVisible(find.text('Bahasa'));
    await tester.tap(find.text('Bahasa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'selected_language_english',
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed profile load offers retry and logout, and retry restores the menu',
    (tester) async {
      final api = _ProfileApi()..profileFails = true;
      await _pump(tester, api);
      expect(
        find.text('Profil belum dapat dimuat. Periksa koneksi lalu coba lagi.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-logout')), findsOneWidget);
      api.profileFails = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profil'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'password update does not claim success for a malformed server response',
    () async {
      final result =
          await ApiService(
            client: MockClient(
              (_) async => http.Response('<html>Error</html>', 200),
            ),
          ).changePassword(
            currentPassword: 'password123',
            password: 'new-password123',
            confirmation: 'new-password123',
          );
      expect(result['success'], isFalse);
      expect(result['message'], contains('belum dapat diperbarui'));
    },
  );

  testWidgets(
    'help has real ordering guidance and about shows the actual build',
    (tester) async {
      await _pump(tester, _ProfileApi());
      await tester.ensureVisible(find.text('Bantuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bantuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah membayar tetapi muncul kendala?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jangan membayar ulang.'), findsOneWidget);
      expect(find.textContaining('support@cikscoffee.com'), findsNothing);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tentang Aplikasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentang Aplikasi'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CoffeeDialog),
          matching: find.text('Versi 2.3.4 (456)'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'notification activation cannot run twice and a failure preserves the previous switch',
    (tester) async {
      final push = _Push()
        ..state = const NotificationActivation(
          NotificationActivationStatus.enabled,
        );
      await _pump(tester, _ProfileApi(), push: push);
      push.pending = Completer<NotificationActivation>();
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      expect(push.changes, 1);
      push.pending!.complete(
        const NotificationActivation(
          NotificationActivationStatus.serverUnavailable,
          reason:
              'Notifikasi belum dapat dinonaktifkan. Periksa koneksi lalu coba lagi.',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
        find.textContaining('Notifikasi belum dapat dinonaktifkan.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('device settings can be opened after permission is denied', (
    tester,
  ) async {
    final push = _Push()
      ..state = const NotificationActivation(
        NotificationActivationStatus.permissionDenied,
      );
    final info = _AppInfo();
    await _pump(tester, _ProfileApi(), push: push, info: info);
    await tester.ensureVisible(find.text('Buka pengaturan notifikasi'));
    await tester.tap(find.text('Buka pengaturan notifikasi'));
    await tester.pumpAndSettle();
    expect(info.settingsOpened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'logout clears credentials and pending checkout even if notification cleanup fails',
    (tester) async {
      final api = _ProfileApi();
      final push = _Push()..logoutFails = true;
      await _pump(tester, api, push: push);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-logout')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(secure['auth_token'], 'test-token');
      await tester.tap(find.byKey(const ValueKey('profile-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(secure['auth_token'], isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cart_data'), isNull);
      expect(prefs.getString('pending_checkout'), isNull);
      expect(push.logouts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'profile editing remains scrollable above the keyboard on a short screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, _ProfileApi(), small: true);
      await tester.ensureVisible(find.text('Edit profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simpan perubahan'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _ProfileApi api, {
  _Push? push,
  _AppInfo? info,
  bool small = false,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        builder: small
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(1.8),
                  viewInsets: const EdgeInsets.only(bottom: 200),
                ),
                child: child!,
              )
            : null,
        home: ProfileScreen(
          apiService: api,
          notificationService: push ?? _Push(),
          appInfoService: info ?? _AppInfo(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Simpan perubahan'));
  await tester.tap(find.text('Simpan perubahan'));
  await tester.pumpAndSettle();
}

const _user = {
  'id': 1,
  'name': 'Pelanggan',
  'email': 'pelanggan@example.test',
  'phone': '081234567890',
  'role': 'pengguna',
};

class _ProfileApi extends ApiService {
  _ProfileApi()
    : super(client: MockClient((_) async => http.Response('{}', 200)));
  int profileSaves = 0, passwordSaves = 0;
  String? lastPassword, saveError;
  bool profileFails = false;
  @override
  Future<Map<String, dynamic>> getProfile() async => profileFails
      ? {
          'success': false,
          'message':
              'Profil belum dapat dimuat. Periksa koneksi lalu coba lagi.',
        }
      : {'success': true, 'data': _user};
  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? phone,
    String? currentPassword,
  }) async {
    profileSaves++;
    lastPassword = currentPassword;
    if (saveError != null) return {'success': false, 'message': saveError};
    return {
      'success': true,
      'user': UserModel.fromJson({
        ..._user,
        'name': name,
        'email': email,
        'phone': phone,
      }),
    };
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
    String? deviceToken,
  }) async {
    passwordSaves++;
    return {'success': true};
  }
}

class _Push extends PushNotificationService {
  _Push() : super(messaging: _Messaging());
  NotificationActivation state = const NotificationActivation(
    NotificationActivationStatus.disabled,
  );
  Completer<NotificationActivation>? pending;
  int changes = 0, logouts = 0;
  bool logoutFails = false;
  @override
  Future<NotificationActivation> getStatus() async => state;
  @override
  Future<NotificationActivation> setEnabled(bool enabled) async {
    changes++;
    return pending?.future ??
        NotificationActivation(
          enabled
              ? NotificationActivationStatus.enabled
              : NotificationActivationStatus.disabled,
        );
  }

  @override
  Future<String?> currentToken() async => 'this-device';
  @override
  Future<void> onLoggedOut() async {
    logouts++;
    if (logoutFails) throw StateError('Firebase unavailable');
  }
}

class _Messaging extends Fake implements FirebaseMessaging {}

class _AppInfo extends AppInfoService {
  int settingsOpened = 0;
  @override
  Future<String?> version() async => '2.3.4 (456)';
  @override
  Future<bool> openNotificationSettings() async {
    settingsOpened++;
    return true;
  }
}
