import 'dart:convert';
import 'package:ciks_coffee_mobile/models/product_model.dart';
import 'package:ciks_coffee_mobile/providers/cart_provider.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/cart_screen.dart';
import 'package:ciks_coffee_mobile/screens/profile_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/qris_payment_sheet.dart';
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
    SharedPreferences.setMockInitialValues({'session_user_id': 1});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'read' ? 'audit-token' : null,
        );
  });
  for (final value in [
    (422, 'validation.unique'),
    (429, 'Too Many Attempts.'),
    (403, 'Unauthorized'),
    (404, 'No query results for model [App\\Models\\Order] 999999'),
  ]) {
    test('API error mapping ${value.$1}', () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': value.$2,
              if (value.$1 == 422)
                'errors': {
                  'email': [value.$2],
                },
            }),
            value.$1,
          ),
        ),
      );
      final result = value.$1 == 422
          ? await api.register(
              'Audit',
              'audit@example.test',
              '08123456789',
              'auditpass123',
            )
          : await api.login('audit@example.test', 'auditpass123');
      expect(result['success'], false);
      expect(result['message'], isNot(value.$2));
      expect(result['message'], isNot(contains('validation.')));
      expect(result['message'], isNot(contains('App\\Models')));
    });
  }
  test('cancellation preserves the server explanation', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(
          '{"message":"Bukti sudah dikirim. Periksa menu Status."}',
          409,
        ),
      ),
    );
    final result = await api.cancelCheckout('audit-id');
    expect(result['success'], false);
    expect(result['message'], 'Bukti sudah dikirim. Periksa menu Status.');
  });
  test('existing Indonesian validation reasons remain intact', () async {
    for (final reason in [
      'Alamat email atau kata sandi salah.',
      'Email maksimal 255 karakter.',
      'Konfirmasi kata sandi tidak cocok.',
      'Perbarui aplikasi sebelum melakukan pembayaran QRIS.',
    ]) {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': reason,
              'errors': {
                'email': [reason],
              },
            }),
            422,
          ),
        ),
      );
      expect(
        (await api.login('audit@example.test', 'test-password'))['message'],
        reason,
      );
    }
  });
  testWidgets('cart displays the specific preflight message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cart = CartProvider();
    await cart.ready;
    cart.addItem(ProductModel(id: 1, name: 'Menu audit', price: 10000));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(home: CartScreen(apiService: _AuditApi())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
    await tester.pumpAndSettle();
    expect(
      find.text('Stok belum dapat diperiksa. Silakan coba lagi.'),
      findsNothing,
    );
    expect(
      find.text('Perbarui aplikasi sebelum melakukan pembayaran QRIS.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });
  testWidgets('profile displays the reason for failure', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: MaterialApp(home: ProfileScreen(apiService: _AuditApi())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat profil.'), findsNothing);
    expect(
      find.text('Layanan sedang dalam pemeliharaan. Coba lagi 15 menit.'),
      findsOneWidget,
    );
  });
  testWidgets('QRIS configuration and network failures display their reasons', (
    tester,
  ) async {
    for (final reason in [
      'QRIS belum tersedia.',
      'Koneksi terputus. Silakan coba lagi.',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: QrisPaymentSheet(
            total: 'Rp 10.000',
            language: LanguageProvider(),
            apiService: _AuditApi(qrisReason: reason),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('QRIS belum dapat dimuat.'), findsNothing);
      expect(find.text(reason), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'payment cancellation displays the reason and keeps the sheet open',
    (tester) async {
      const reason = 'Bukti sudah dikirim. Periksa menu Status.';
      await tester.pumpWidget(
        MaterialApp(
          home: QrisPaymentSheet(
            total: 'Rp 10.000',
            language: LanguageProvider(),
            apiService: _AuditApi(),
            onCancel: () async => {'success': false, 'message': reason},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cancel = find.text('Belum membayar? Batalkan sesi pembayaran');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saya belum membayar, batalkan'));
      await tester.pumpAndSettle();
      expect(find.text(reason), findsOneWidget);
      expect(find.byType(QrisPaymentSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _AuditApi extends ApiService {
  _AuditApi({this.qrisReason = 'QRIS belum tersedia.'});
  final String qrisReason;
  @override
  Future<Map<String, dynamic>?> pendingCheckout() async => null;
  @override
  Future<Map<String, dynamic>> getProducts({
    int? categoryId,
    String? search,
  }) async => {
    'success': false,
    'message': 'Perbarui aplikasi sebelum melakukan pembayaran QRIS.',
  };
  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'success': false,
    'message': 'Layanan sedang dalam pemeliharaan. Coba lagi 15 menit.',
  };
  @override
  Future<Map<String, dynamic>> getQrisImage() async => {
    'success': false,
    'message': qrisReason,
  };
}
