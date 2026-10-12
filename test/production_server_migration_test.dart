import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> secureValues;

  setUp(() {
    secureValues = {
      'auth_token': 'existing-token',
      'auth_token_expires_at': '2099-01-01T00:00:00Z',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final key = (call.arguments as Map?)?['key'] as String?;
          if (call.method == 'delete') secureValues.remove(key);
          if (call.method == 'read') return secureValues[key];
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'an existing local installation switches servers and signs out',
    () async {
      SharedPreferences.setMockInitialValues({
        'custom_api_base_url': 'http://192.168.18.189:8000/api',
        'auth_token': 'legacy-token',
      });

      await ApiService.init();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('custom_api_base_url'), isFalse);
      expect(prefs.containsKey('auth_token'), isFalse);
      expect(secureValues, isEmpty);
      expect(ApiService().baseUrl, 'https://cikscoffee.biz.id/api');
    },
  );

  test(
    'an existing production session survives removal of the selector',
    () async {
      SharedPreferences.setMockInitialValues({
        'custom_api_base_url': 'https://cikscoffee.biz.id/api/',
      });

      await ApiService.init();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('custom_api_base_url'), isFalse);
      expect(secureValues['auth_token'], 'existing-token');
    },
  );
}
