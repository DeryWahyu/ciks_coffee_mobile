import 'dart:async';
import 'dart:convert';

import 'package:ciks_coffee_mobile/main.dart';
import 'package:ciks_coffee_mobile/models/product_model.dart';
import 'package:ciks_coffee_mobile/providers/cart_provider.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/cart_screen.dart';
import 'package:ciks_coffee_mobile/screens/history_screen.dart';
import 'package:ciks_coffee_mobile/screens/login_screen.dart';
import 'package:ciks_coffee_mobile/screens/order_status_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/qris_payment_sheet.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> secure;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'session_user_id': 7});
    secure = {
      'auth_token': 'old-token',
      'auth_token_expires_at': '2099-01-01T00:00:00Z',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map;
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'write':
              secure[key!] = arguments['value'] as String;
              break;
            case 'delete':
              secure.remove(key);
              break;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_messaging'),
          (_) async => null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'temporary server failure retains the valid token and existing basket',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_data', 'existing-cart');
      final api = ApiService(
        client: MockClient((_) async => http.Response('Unavailable', 503)),
      );
      expect(await api.validateSession(), SessionStatus.unavailable);
      expect(secure['auth_token'], 'old-token');
      expect(prefs.getString('cart_data'), 'existing-cart');
    },
  );

  test('401 ends the session and clears stored and in-memory basket', () async {
    final cart = CartProvider();
    await cart.ready;
    cart.addItem(_product(), variant: 'base');
    final ended = <void>[];
    final subscription = ApiService.sessionEnded.listen(ended.add);
    final api = ApiService(
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    expect((await api.getProfile())['success'], isFalse);
    expect(secure, isEmpty);
    expect(cart.isEmpty, isTrue);
    expect(ended.length, 1);
    expect(
      (await SharedPreferences.getInstance()).getString('cart_data'),
      isNull,
    );
    await subscription.cancel();
    cart.dispose();
  });

  for (final status in [200, 401]) {
    test(
      'late $status from the previous account cannot affect the next session',
      () async {
        final sent = Completer<void>();
        final response = Completer<http.Response>();
        final api = ApiService(
          client: MockClient((_) {
            sent.complete();
            return response.future;
          }),
        );
        final oldRequest = api.getProfile();
        await sent.future;
        await api.saveToken('new-token', expiresAt: '2099-01-01T00:00:00Z');
        response.complete(
          http.Response('{"id":1,"name":"Previous user"}', status),
        );
        expect((await oldRequest)['success'], isFalse);
        expect(await api.getToken(), 'new-token');
      },
    );
  }

  test(
    'logout clears the basket for the next account and saved provider',
    () async {
      final cart = CartProvider();
      await cart.ready;
      cart.addItem(_product(), variant: 'base');
      final api = ApiService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await api.logout();
      expect(cart.isEmpty, isTrue);
      final next = CartProvider();
      await next.ready;
      expect(next.isEmpty, isTrue);
      next.dispose();
      cart.dispose();
    },
  );

  test(
    'restoring preferences cannot overwrite quantities added during startup',
    () async {
      final cart = CartProvider();
      cart.addItem(_product(), variant: 'base');
      cart.addItem(_product(), variant: 'base');
      await cart.ready;
      expect(cart.totalItemCount, 2);
      cart.dispose();
    },
  );

  test(
    'successful checkout removes only purchased quantities and respects account changes',
    () async {
      final cart = CartProvider();
      await cart.ready;
      cart.addItem(_product(), variant: 'base');
      final generation = cart.sessionGeneration;
      final submitted = cart.toCheckoutItems();
      cart.addItem(_product(), variant: 'base');
      cart.addItem(_product(), variant: 'lite');
      cart.removePurchased(submitted, generation);
      expect(cart.items['1_base']!.quantity, 1);
      expect(cart.items['1_lite']!.quantity, 1);
      await ApiService().clearToken();
      cart.addItem(_product(), variant: 'base');
      cart.removePurchased(submitted, generation);
      expect(cart.totalItemCount, 1);
      cart.dispose();
    },
  );

  test(
    'reservation retry after lost response preserves request identity and original cart',
    () async {
      final payloads = <Map<String, dynamic>>[];
      var calls = 0;
      final api = ApiService(
        client: MockClient((request) async {
          payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (++calls == 1) throw http.ClientException('Connection dropped');
          return http.Response(
            jsonEncode({
              'data': _quote(
                payloads.last['items'] as List,
                20000,
                key: payloads.last['request_key'],
              ),
            }),
            201,
          );
        }),
      );
      final items = [
        {'product_id': 1, 'variant': 'base', 'quantity': 1, 'price': 20000},
      ];
      expect(
        (await api.prepareCheckout(
          items: items,
          expectedTotal: 20000,
        ))['success'],
        isFalse,
      );
      final pending = await api.pendingCheckout();
      expect(
        (await api.prepareCheckout(
          items: [],
          expectedTotal: 0,
          pending: pending,
        ))['success'],
        isTrue,
      );
      expect(payloads[0]['request_key'], payloads[1]['request_key']);
      expect(payloads[1]['items'], items);
      expect(payloads[1]['expected_total'], 20000);
    },
  );

  test(
    'payment application stays idempotent after restarting the basket',
    () async {
      final cart = CartProvider();
      await cart.ready;
      cart.addItem(_product(), variant: 'base');
      final purchased = cart.toCheckoutItems();
      cart.addItem(_product(), variant: 'base');
      final basketId = cart.basketId;
      cart.removePurchased(
        purchased,
        cart.sessionGeneration,
        checkoutId: 'paid-1',
      );
      expect(await cart.persist(), isTrue);
      cart.dispose();

      final restored = CartProvider();
      await restored.ready;
      expect(restored.basketId, basketId);
      expect(restored.totalItemCount, 1);
      restored.addItem(_product(), variant: 'base');
      restored.removePurchased(
        purchased,
        restored.sessionGeneration,
        checkoutId: 'paid-1',
      );
      expect(restored.totalItemCount, 2);
      await restored.persist();
      restored.dispose();
    },
  );

  test(
    'malformed successful catalogue response is treated as unavailable',
    () async {
      final api = ApiService(
        client: MockClient((_) async => http.Response('{"data":{}}', 200)),
      );
      expect((await api.getProducts())['success'], isFalse);
      expect(secure['auth_token'], 'old-token');
    },
  );

  testWidgets('server rejects combined recipe shortage before QRIS opens', (
    tester,
  ) async {
    final cart = CartProvider();
    await cart.ready;
    cart.addItem(_product(), variant: 'base');
    cart.addItem(_product(), variant: 'lite');
    final api = _PaymentApi(reject: true);
    await tester.pumpWidget(_app(cart, api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
    await tester.pumpAndSettle();
    expect(find.byType(QrisPaymentSheet), findsNothing);
    expect(find.text('Stok gabungan tidak cukup.'), findsOneWidget);
    expect(cart.totalItemCount, 2);
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });

  testWidgets('an item added while upload is pending stays in the basket', (
    tester,
  ) async {
    final cart = CartProvider();
    await cart.ready;
    cart.addItem(_product(), variant: 'base');
    final api = _PaymentApi();
    await tester.pumpWidget(_app(cart, api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(QrisPaymentSheet)),
    ).pop('proof.png');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    cart.addItem(_product(), variant: 'lite');
    api.upload.complete({
      'success': true,
      'data': {
        'order': {'order_number': 'TEST', 'total': 20000},
      },
    });
    await tester.pumpAndSettle();
    expect(api.uploadedId, 'quote-id');
    expect(cart.items.keys, ['1_lite']);
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });

  testWidgets('payment can resume after logout cleared the local basket', (
    tester,
  ) async {
    final cart = CartProvider();
    await cart.ready;
    final api = _PaymentApi(resume: true);
    await tester.pumpWidget(_app(cart, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjutkan pembayaran'));
    await tester.pumpAndSettle();
    expect(find.byType(QrisPaymentSheet), findsOneWidget);
    expect(find.text('Rp 20.000'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });

  testWidgets('recovering a submitted payment preserves a new local basket', (
    tester,
  ) async {
    final cart = CartProvider();
    await cart.ready;
    cart.addItem(_product(), variant: 'base');
    await tester.pumpWidget(
      _app(cart, _PaymentApi(resume: true, submitted: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
    await tester.pumpAndSettle();
    expect(find.byType(QrisPaymentSheet), findsNothing);
    expect(find.text('Pesanan diterima!'), findsOneWidget);
    expect(cart.totalItemCount, 1);
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });

  for (final cancelled in [false, true]) {
    testWidgets(
      '${cancelled ? 'cancelled' : 'expired'} payment hides QRIS and permits recovery instructions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: QrisPaymentSheet(
              total: 'Rp 20.000',
              language: LanguageProvider(),
              apiService: _PaymentApi(),
              expiresAt: DateTime.now().add(
                Duration(minutes: cancelled ? 15 : -1),
              ),
              allowPayment: !cancelled,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Jangan lakukan pembayaran baru'),
          findsOneWidget,
        );
        expect(find.byType(Image), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'old status response cannot overwrite a newer refresh and polls cannot overlap',
    (tester) async {
      final api = _StatusApi();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
          child: MaterialApp(home: OrderStatusScreen(apiService: api)),
        ),
      );
      await tester.pumpAndSettle();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(api.calls, 2);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(api.calls, 2);
      await refresh();
      await tester.pumpAndSettle();
      expect(find.text('TEST-ORDER'), findsNothing);
      api.delayed.complete({
        'success': true,
        'data': [_order],
      });
      await tester.pumpAndSettle();
      expect(find.text('TEST-ORDER'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'old history response cannot restore an order after a newer refresh',
    (tester) async {
      final api = _HistoryApi();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
          child: MaterialApp(home: HistoryScreen(apiService: api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TEST-ORDER'), findsOneWidget);
      globalHistoryRefresh.value++;
      await tester.pump();
      expect(api.calls, 2);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('TEST-ORDER'), findsNothing);
      api.delayed.complete({
        'success': true,
        'data': [
          {..._order, 'status': 'diambil'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('TEST-ORDER'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('startup server error shows retry without clearing the token', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(home: AuthWrapper()),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(secure['auth_token'], 'old-token');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => http.Response('Unavailable', 503)));
  });
}

ProductModel _product() => ProductModel.fromJson(_productJson);
const _productJson = {
  'id': 1,
  'name': 'Kopi uji',
  'price': 20000,
  'price_lite': 18000,
  'category': {'slug': 'coffee'},
  'is_available': true,
  'stock_quantities': {'base': 10, 'lite': 10},
};
const _order = {
  'id': 11,
  'order_number': 'TEST-ORDER',
  'total': 20000,
  'status': 'selesai',
  'status_label': 'Selesai',
  'payment_method': 'qris',
  'created_at': '2026-11-17T00:00:00Z',
  'items': <dynamic>[],
};
Map<String, dynamic> _quote(
  List items,
  double total, {
  String key = 'request-key',
}) => {
  'id': 'quote-id',
  'can_pay': true,
  'request_key': key,
  'items': items,
  'total': total,
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
};
Widget _app(CartProvider cart, ApiService api) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: cart),
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
  ],
  child: MaterialApp(home: CartScreen(apiService: api)),
);

class _PaymentApi extends ApiService {
  _PaymentApi({
    this.reject = false,
    this.resume = false,
    this.submitted = false,
  });
  final bool reject, resume, submitted;
  final upload = Completer<Map<String, dynamic>>();
  String? uploadedId;
  @override
  Future<Map<String, dynamic>?> pendingCheckout() async => resume
      ? {
          'items': [
            {'product_id': 1, 'variant': 'base', 'quantity': 1, 'price': 20000},
          ],
          'expected_total': 20000,
        }
      : null;
  @override
  Future<Map<String, dynamic>> getProducts({
    int? categoryId,
    String? search,
  }) async => {
    'success': true,
    'data': [_productJson],
  };
  @override
  Future<Map<String, dynamic>> prepareCheckout({
    required List<Map<String, dynamic>> items,
    required double expectedTotal,
    Map<String, dynamic>? pending,
    String? cartId,
  }) async => reject
      ? {'success': false, 'message': 'Stok gabungan tidak cukup.'}
      : {
          'success': true,
          'data': {
            if (submitted) 'order': {'order_number': 'TEST', 'total': 20000},
            ..._quote(
              pending?['items'] as List? ?? items,
              (pending?['expected_total'] as num?)?.toDouble() ?? expectedTotal,
            ),
            'local_cart_id': pending == null
                ? cartId
                : pending['local_cart_id'],
          },
        };
  @override
  Future<Map<String, dynamic>> getQrisImage() async => {'success': false};
  @override
  Future<Map<String, dynamic>> checkout({
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    double? cashReceived,
    String? paymentProofPath,
    String? checkoutId,
  }) {
    uploadedId = checkoutId;
    return upload.future;
  }
}

class _HistoryApi extends ApiService {
  int calls = 0;
  final delayed = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> getOrderHistory() async {
    calls++;
    if (calls == 1) {
      return {
        'success': true,
        'data': [
          {..._order, 'status': 'diambil'},
        ],
      };
    }
    if (calls == 2) return delayed.future;
    return {'success': true, 'data': <dynamic>[]};
  }
}

class _StatusApi extends ApiService {
  var calls = 0;
  final delayed = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> getActiveOrders() async {
    calls++;
    if (calls == 1) {
      return {
        'success': true,
        'data': [_order],
      };
    }
    if (calls == 2) return delayed.future;
    return {'success': true, 'data': <dynamic>[]};
  }
}
