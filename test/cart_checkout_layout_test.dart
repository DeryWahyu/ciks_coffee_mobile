import 'package:ciks_coffee_mobile/models/product_model.dart';
import 'package:ciks_coffee_mobile/providers/cart_provider.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/cart_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/app_bottom_navigation.dart';
import 'package:ciks_coffee_mobile/widgets/cart_checkout_panel.dart';
import 'package:ciks_coffee_mobile/widgets/coffee_overlays.dart';
import 'package:ciks_coffee_mobile/widgets/qris_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'checkout is aligned above navigation and only applies the bottom inset once',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(320, 740), const Size(390, 844)]) {
        await tester.binding.setSurfaceSize(size);
        final cart = _cart();
        await tester.pumpWidget(_app(cart, _FakeApi()));
        await tester.pumpAndSettle();
        final panel = tester.getRect(find.byType(CartCheckoutPanel));
        final action = tester.getRect(
          find.byKey(const ValueKey('cart-checkout-action')),
        );
        final navigation = tester.getRect(find.byType(AppBottomNavigation));
        expect(panel.bottom - action.bottom, closeTo(20, 0.1));
        expect(action.width, closeTo(size.width - 40, 0.1));
        expect(action.bottom, lessThan(navigation.top));
        expect(find.text('Rp 48.000'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('cart remains usable in landscape and with large text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(844, 390), const Size(320, 568)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(_cart(), _FakeApi(), textScale: 1.8));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('cart-checkout-action')),
      );
      await tester.drag(find.byType(CartScreen), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Lanjutkan Pembayaran'), findsOneWidget);
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('cart-checkout-action')))
            .dy,
        lessThan(tester.getTopLeft(find.byType(AppBottomNavigation)).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'closing QRIS preserves cart and proof is required before submitting',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = _cart();
      final api = _FakeApi();
      await tester.pumpWidget(_app(cart, api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
      await tester.pumpAndSettle();
      expect(find.byType(QrisPaymentSheet), findsOneWidget);
      final submit = find.descendant(
        of: find.byKey(const ValueKey('qris-submit')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(QrisPaymentSheet), findsNothing);
      expect(cart.totalItemCount, 2);
      expect(api.checkoutCalls, 0);
      final action = tester.widget<CoffeeButton>(
        find.byKey(const ValueKey('cart-checkout-action')),
      );
      expect(action.loading, isFalse);
    },
  );
}

CartProvider _cart() => CartProvider()
  ..addItem(
    ProductModel(
      id: 1,
      name: 'Kopi Susu Gula Aren',
      price: 24000,
      isCoffee: true,
    ),
    variant: 'base',
  )
  ..addItem(
    ProductModel(
      id: 1,
      name: 'Kopi Susu Gula Aren',
      price: 24000,
      isCoffee: true,
    ),
    variant: 'base',
  );

Widget _app(CartProvider cart, ApiService api, {double textScale = 1}) {
  final language = LanguageProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider.value(value: language),
    ],
    child: MaterialApp(
      theme: ThemeData(fontFamily: 'CiksSans'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: 34),
            viewPadding: const EdgeInsets.only(bottom: 34),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            extendBody: true,
            body: CartScreen(apiService: api),
            bottomNavigationBar: AppBottomNavigation(
              index: 1,
              onSelected: (_) {},
              language: language,
              cartCount: cart.totalItemCount,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakeApi extends ApiService {
  int checkoutCalls = 0;

  @override
  Future<Map<String, dynamic>> getQrisImage() async => {
    'success': false,
    'message': 'QRIS belum tersedia.',
  };

  @override
  Future<Map<String, dynamic>> checkout({
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    double? cashReceived,
    String? paymentProofPath,
  }) async {
    checkoutCalls++;
    return {'success': false, 'message': 'Unexpected checkout'};
  }
}
