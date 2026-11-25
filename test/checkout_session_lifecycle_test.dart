import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ciks_coffee_mobile/models/checkout_session_model.dart';
import 'package:ciks_coffee_mobile/models/product_model.dart';
import 'package:ciks_coffee_mobile/providers/cart_provider.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/cart_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/coffee_overlays.dart';
import 'package:ciks_coffee_mobile/widgets/cart_checkout_panel.dart';
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
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async =>
              call.method == 'read' && call.arguments['key'] == 'auth_token'
              ? 'test-token'
              : null,
        );
  });

  test(
    'reservation persists its deadline and can be restored without renewing it',
    () async {
      var calls = 0;
      final quote = _quote(DateTime.now().add(const Duration(minutes: 15)));
      final api = ApiService(
        client: MockClient((request) async {
          calls++;
          quote['request_key'] = jsonDecode(request.body)['request_key'];
          return http.Response(jsonEncode({'data': quote}), 201);
        }),
      );
      expect(
        (await api.prepareCheckout(
          items: _items,
          expectedTotal: 20000,
          cartId: 'basket',
        ))['success'],
        isTrue,
      );
      final pending = await ApiService().pendingCheckout();
      expect(pending!['expires_at'], quote['expires_at']);
      expect(pending['local_cart_id'], 'basket');
      expect(pending['checkout_id'], quote['id']);
      expect(calls, 1);
    },
  );

  test(
    'expired local session is removed and an expired server session cannot restore it',
    () async {
      final expired = _quote(
        DateTime.now().subtract(const Duration(seconds: 1)),
      )..['can_pay'] = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pending_checkout',
        jsonEncode(CheckoutSession.fromQuote(expired).data),
      );
      var calls = 0;
      final api = ApiService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/checkouts/current');
          return http.Response(jsonEncode({'data': expired}), 200);
        }),
      );
      expect(await api.pendingCheckout(), isNull);
      expect(prefs.getString('pending_checkout'), isNull);
      expect(calls, 0);
      expect(await api.pendingCheckout(), isNull);
      expect(prefs.getString('pending_checkout'), isNull);
      expect(calls, 1);
    },
  );

  for (final expired in [false, true]) {
    test(
      'legacy session without a saved deadline is reconciled with its original key: expired=$expired',
      () async {
        final quote = _quote(
          DateTime.now().add(Duration(minutes: expired ? -1 : 15)),
        )..['can_pay'] = !expired;
        final saved = CheckoutSession.fromQuote(quote).data
          ..remove('expires_at')
          ..remove('can_pay');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_checkout', jsonEncode(saved));
        final api = ApiService(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              jsonDecode(request.body)['request_key'],
              saved['request_key'],
            );
            expect(jsonDecode(request.body)['items'], _items);
            return http.Response(jsonEncode({'data': quote}), 201);
          }),
        );
        final pending = await api.pendingCheckout();
        if (expired) {
          expect(pending, isNull);
          expect(prefs.getString('pending_checkout'), isNull);
        } else {
          expect(pending!['expires_at'], quote['expires_at']);
          expect(pending['request_key'], saved['request_key']);
        }
      },
    );
  }

  test('cancelled session is discarded even before its deadline', () async {
    final quote = _quote(DateTime.now().add(const Duration(minutes: 15)))
      ..['status'] = 'cancelled';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pending_checkout',
      jsonEncode(CheckoutSession.fromQuote(quote).data),
    );
    expect(await ApiService().pendingCheckout(), isNull);
    expect(prefs.getString('pending_checkout'), isNull);
  });

  test('an old expiry callback cannot remove a newer reservation', () async {
    final prefs = await SharedPreferences.getInstance();
    final pending = CheckoutSession.fromQuote(
      _quote(DateTime.now().add(const Duration(minutes: 15))),
    ).data;
    await prefs.setString('pending_checkout', jsonEncode(pending));
    await ApiService().clearPendingCheckout(
      checkoutId: 'older-id',
      requestKey: 'older-key',
    );
    expect(jsonDecode(prefs.getString('pending_checkout')!), pending);
    await ApiService().clearPendingCheckout(requestKey: 'older-key');
    expect(jsonDecode(prefs.getString('pending_checkout')!), pending);
  });

  test('a delayed restore cannot overwrite a newer reservation', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = ApiService(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          started.complete();
          return response.future;
        }
        final quote = _quote(DateTime.now().add(const Duration(minutes: 15)))
          ..['id'] = 'newer-reservation'
          ..['request_key'] = jsonDecode(request.body)['request_key'];
        return http.Response(jsonEncode({'data': quote}), 201);
      }),
    );
    final restoring = api.pendingCheckout();
    await started.future;
    expect(
      (await api.prepareCheckout(
        items: _items,
        expectedTotal: 20000,
      ))['success'],
      isTrue,
    );
    response.complete(
      http.Response(
        jsonEncode({
          'data': _quote(DateTime.now().add(const Duration(minutes: 15))),
        }),
        200,
      ),
    );
    expect((await restoring)!['checkout_id'], 'newer-reservation');
    expect((await api.pendingCheckout())!['checkout_id'], 'newer-reservation');
  });

  test(
    'a lost upload response is preserved for reconciliation after the deadline',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ciks-payment-proof-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final proof = await File(
        '${directory.path}/proof.png',
      ).writeAsBytes([1, 2, 3]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pending_checkout',
        jsonEncode(
          CheckoutSession.fromQuote(
            _quote(DateTime.now().add(const Duration(minutes: 15))),
          ).data,
        ),
      );
      final api = ApiService(
        client: MockClient(
          (_) async => throw http.ClientException('response lost'),
        ),
      );
      expect(
        (await api.checkout(
          paymentMethod: 'qris',
          items: _items,
          paymentProofPath: proof.path,
          checkoutId: 'reservation-1',
        ))['success'],
        isFalse,
      );
      final saved = Map<String, dynamic>.from(
        jsonDecode(prefs.getString('pending_checkout')!),
      );
      expect(saved['submission_pending'], isTrue);
      saved['expires_at'] = DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String();
      await prefs.setString('pending_checkout', jsonEncode(saved));
      expect((await api.pendingCheckout())!['checkout_id'], 'reservation-1');
    },
  );

  for (final closeWithBack in [false, true]) {
    testWidgets(
      'closing payment preserves a resumable session without creating another reservation: back=$closeWithBack',
      (tester) async {
        final cart = _cart();
        final api = _SessionApi();
        await _mount(tester, cart, api);
        await _pay(tester);
        final deadline = tester
            .widget<QrisPaymentSheet>(find.byType(QrisPaymentSheet))
            .expiresAt;
        if (closeWithBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Tutup'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Lanjutkan pembayaran'), findsOneWidget);
        expect(cart.totalItemCount, 1);
        await _pay(tester);
        expect(api.reservations, 1);
        expect(
          tester
              .widget<QrisPaymentSheet>(find.byType(QrisPaymentSheet))
              .expiresAt,
          deadline,
        );
        await tester.pumpWidget(const SizedBox());
        cart.dispose();
      },
    );
  }

  testWidgets('a dismissed sheet cannot expire the resumed payment', (
    tester,
  ) async {
    final cart = _cart();
    final api = _SessionApi();
    await _mount(tester, cart, api);
    await _pay(tester);
    final oldExpiry = tester
        .widget<QrisPaymentSheet>(find.byType(QrisPaymentSheet))
        .onExpired!;
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    await _pay(tester);
    oldExpiry();
    await tester.pumpAndSettle();
    expect(find.byType(QrisPaymentSheet), findsOneWidget);
    expect(api.saved, isNotNull);
    expect(api.reservations, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });

  testWidgets(
    'resume shows the reserved amount and quantity after the basket changes',
    (tester) async {
      final cart = _cart();
      final api = _SessionApi();
      await _mount(tester, cart, api);
      await _pay(tester);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      cart.addItem(
        ProductModel(id: 1, name: 'Kopi uji', price: 20000, isCoffee: true),
        variant: 'base',
      );
      await tester.pumpAndSettle();
      final panel = tester.widget<CartCheckoutPanel>(
        find.byType(CartCheckoutPanel),
      );
      expect(panel.total, 'Rp 20.000');
      expect(panel.itemCount, 1);
      expect(cart.totalItemCount, 2);
      await _pay(tester);
      expect(
        tester
            .widget<QrisPaymentSheet>(find.byType(QrisPaymentSheet))
            .items
            .single['quantity'],
        1,
      );
      expect(api.reservations, 1);
      await tester.pumpWidget(const SizedBox());
      cart.dispose();
    },
  );

  for (final keepOpen in [false, true]) {
    testWidgets(
      'deadline removes the session and resume action: sheetOpen=$keepOpen',
      (tester) async {
        final cart = _cart();
        final api = _SessionApi()..firstDeadline = const Duration(seconds: 2);
        await _mount(tester, cart, api);
        await _pay(tester);
        if (!keepOpen) {
          await tester.tap(find.byTooltip('Tutup'));
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byType(QrisPaymentSheet), findsNothing);
        expect(find.text('Lanjutkan pembayaran'), findsNothing);
        expect(find.text('Bayar sekarang'), findsOneWidget);
        expect(api.saved, isNull);
        expect(cart.totalItemCount, 1);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await _pay(tester);
        expect(api.reservations, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        cart.dispose();
      },
    );
  }

  testWidgets(
    'deadline closes both a cancellation dialog and the payment sheet',
    (tester) async {
      final cart = _cart();
      final api = _SessionApi()..firstDeadline = const Duration(seconds: 2);
      await _mount(tester, cart, api);
      await _pay(tester);
      await tester.ensureVisible(
        find.text('Belum membayar? Batalkan sesi pembayaran'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belum membayar? Batalkan sesi pembayaran'));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan pembayaran?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(CoffeeDialog), findsNothing);
      expect(find.byType(QrisPaymentSheet), findsNothing);
      expect(find.text('Bayar sekarang'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      cart.dispose();
    },
  );

  testWidgets('returning from the background rechecks the saved payment', (
    tester,
  ) async {
    final cart = _cart();
    final api = _SessionApi();
    await _mount(tester, cart, api);
    await _pay(tester);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    api.saved!['expires_at'] = DateTime.now()
        .subtract(const Duration(seconds: 1))
        .toIso8601String();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Lanjutkan pembayaran'), findsNothing);
    expect(find.text('Bayar sekarang'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    cart.dispose();
  });

  testWidgets(
    'expiry does not discard an in-flight proof or offer a second payment',
    (tester) async {
      final cart = _cart();
      final api = _SessionApi()..firstDeadline = const Duration(seconds: 2);
      await _mount(tester, cart, api);
      await _pay(tester);
      Navigator.of(
        tester.element(find.byType(QrisPaymentSheet)),
      ).pop('proof.png');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 3));
      expect(api.saved, isNotNull);
      api.upload.complete({
        'success': false,
        'message': 'Hasil pengiriman belum dapat diperiksa.',
      });
      await tester.pumpAndSettle();
      expect(find.text('Periksa pembayaran'), findsOneWidget);
      expect(find.text('Bayar sekarang'), findsNothing);
      expect(find.text('Lanjutkan pembayaran'), findsNothing);
      expect(api.reservations, 1);
      expect(cart.totalItemCount, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _pay(tester);
      expect(
        tester
            .widget<QrisPaymentSheet>(find.byType(QrisPaymentSheet))
            .allowPayment,
        isFalse,
      );
      expect(api.qrisCalls, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(QrisPaymentSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      cart.dispose();
    },
  );
}

const _items = <Map<String, dynamic>>[
  {'product_id': 1, 'variant': 'base', 'quantity': 1, 'price': 20000},
];
Map<String, dynamic> _quote(DateTime deadline) => {
  'id': 'reservation-1',
  'request_key': 'original-request',
  'items': _items,
  'total': 20000,
  'expires_at': deadline.toIso8601String(),
  'status': 'reserved',
  'can_pay': true,
};
CartProvider _cart() => CartProvider()
  ..addItem(
    ProductModel(id: 1, name: 'Kopi uji', price: 20000, isCoffee: true),
    variant: 'base',
  );
Future<void> _mount(
  WidgetTester tester,
  CartProvider cart,
  ApiService api,
) async {
  await cart.ready;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cart),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(home: CartScreen(apiService: api)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pay(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
  await tester.pumpAndSettle();
}

class _SessionApi extends ApiService {
  Map<String, dynamic>? saved;
  Map<String, dynamic>? quote;
  Duration firstDeadline = const Duration(minutes: 15);
  int reservations = 0;
  int qrisCalls = 0;
  final upload = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>?> pendingCheckout() async {
    if (saved != null && CheckoutSession(saved!).endedAt(DateTime.now())) {
      saved = null;
    }
    return saved;
  }

  @override
  Future<Map<String, dynamic>> prepareCheckout({
    required List<Map<String, dynamic>> items,
    required double expectedTotal,
    Map<String, dynamic>? pending,
    String? cartId,
  }) async {
    if (pending == null) {
      reservations++;
      quote =
          _quote(
              DateTime.now().add(
                reservations == 1 ? firstDeadline : const Duration(minutes: 15),
              ),
            )
            ..['id'] = 'reservation-$reservations'
            ..['request_key'] = 'request-$reservations'
            ..['local_cart_id'] = cartId;
      saved = CheckoutSession.fromQuote(quote!, localCartId: cartId).data;
    }
    return {'success': true, 'data': quote};
  }

  @override
  Future<void> clearPendingCheckout({
    String? checkoutId,
    String? requestKey,
  }) async {
    if (checkoutId != null && saved?['checkout_id'] != checkoutId) return;
    if (requestKey != null && saved?['request_key'] != requestKey) return;
    saved = null;
  }

  @override
  Future<Map<String, dynamic>> getProducts({
    int? categoryId,
    String? search,
  }) async => {
    'success': true,
    'data': [
      {
        'id': 1,
        'name': 'Kopi uji',
        'price': 20000,
        'category': {'slug': 'coffee'},
        'is_available': true,
        'stock_quantities': {'base': 10, 'lite': 0},
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> getQrisImage() async {
    qrisCalls++;
    return {'success': false, 'message': 'QRIS uji.'};
  }

  @override
  Future<Map<String, dynamic>> cancelCheckout(String id) async {
    await clearPendingCheckout(checkoutId: id);
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> checkout({
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    double? cashReceived,
    String? paymentProofPath,
    String? checkoutId,
  }) {
    saved = {...saved!, 'submission_pending': true};
    return upload.future;
  }
}
