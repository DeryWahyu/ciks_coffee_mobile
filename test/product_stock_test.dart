import 'package:ciks_coffee_mobile/models/product_model.dart';
import 'package:ciks_coffee_mobile/providers/cart_provider.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/cart_screen.dart';
import 'package:ciks_coffee_mobile/screens/home_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/coffee_overlays.dart';
import 'package:ciks_coffee_mobile/widgets/qris_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'stock survives serialization and a valid Lite can be sold without Base',
    () {
      final product = ProductModel.fromJson(_coffee(base: 0, lite: 3));
      expect(product.hasStock, isTrue);
      expect(product.stockFor('base'), 0);
      expect(product.stockFor('lite'), 3);
      final restored = ProductModel.fromLocalJson(product.toJson());
      expect(restored.stockQuantities, {'base': 0, 'lite': 3});
      expect(restored.stockFor('lite'), 3);
    },
  );

  test('inactive products and unsold variants cannot be added', () async {
    final cart = CartProvider();
    await Future<void>.delayed(Duration.zero);
    final inactive = ProductModel.fromJson({
      ..._coffee(),
      'is_available': false,
    });
    final baseOnly = ProductModel.fromJson({..._coffee(), 'price_lite': null});
    expect(cart.addItem(inactive, variant: 'base'), isFalse);
    expect(cart.addItem(baseOnly, variant: 'lite'), isFalse);
    expect(cart.addItem(baseOnly), isFalse);
    expect(cart.items, isEmpty);
  });

  test(
    'old API payloads remain usable while malformed or zero counts fail closed',
    () {
      final legacy = _coffee()..remove('stock_quantities');
      expect(ProductModel.fromJson(legacy).stockFor('base'), isNull);
      final invalid = ProductModel.fromJson({
        ..._coffee(),
        'stock_quantities': {'base': -2, 'lite': 'invalid'},
      });
      expect(invalid.hasStock, isFalse);
      expect(invalid.stockFor('base'), 0);
    },
  );

  test(
    'cart stops at variant stock and removing an item restores remaining quantity',
    () async {
      final cart = CartProvider();
      await Future<void>.delayed(Duration.zero);
      final product = ProductModel.fromJson(_coffee(base: 0, lite: 2));
      expect(cart.addItem(product, variant: 'base'), isFalse);
      expect(cart.addItem(product, variant: 'lite'), isTrue);
      expect(cart.remainingFor(product, variant: 'lite'), 1);
      expect(cart.addItem(product, variant: 'lite'), isTrue);
      expect(cart.addItem(product, variant: 'lite'), isFalse);
      expect(cart.items['1_lite']!.quantity, 2);
      cart.removeItem('1_lite');
      expect(cart.remainingFor(product, variant: 'lite'), 1);
      cart.updateQuantity('1_lite', 99);
      expect(cart.items['1_lite']!.quantity, 1);
    },
  );

  test(
    'new stock detects shortages without silently removing cart items',
    () async {
      final cart = CartProvider();
      await Future<void>.delayed(Duration.zero);
      final product = ProductModel.fromJson(_coffee(base: 3));
      cart.addItem(product, variant: 'base');
      cart.addItem(product, variant: 'base');
      cart.updateCatalogue([ProductModel.fromJson(_coffee(base: 1))]);
      expect(cart.items['1_base']!.quantity, 2);
      expect(cart.hasStockConflict, isTrue);
      expect(cart.canAddItem(product, variant: 'base'), isFalse);
      cart.removeItem('1_base');
      expect(cart.hasStockConflict, isFalse);
      cart.updateCatalogue([]);
      expect(cart.hasStockConflict, isTrue);
      expect(cart.items['1_base']!.quantity, 1);
      cart.updateCatalogue([ProductModel.fromJson(_coffee(base: 4))]);
      expect(cart.remainingFor(product, variant: 'base'), 3);
      expect(cart.hasStockConflict, isFalse);
    },
  );

  test(
    'background stock refresh keeps quoted cart prices stable until preflight',
    () async {
      final cart = CartProvider();
      await Future<void>.delayed(Duration.zero);
      cart.addItem(ProductModel.fromJson(_coffee()), variant: 'base');
      final repriced = ProductModel.fromJson({
        ..._coffee(base: 1),
        'price': 30000,
      });
      cart.updateCatalogue([repriced]);
      expect(cart.totalPrice, 24000);
      expect(cart.remainingFor(repriced, variant: 'base'), 0);
      cart.updateCatalogue([repriced], refreshPrices: true);
      expect(cart.totalPrice, 30000);
    },
  );

  testWidgets('sold out variant tile is faded and cannot be pressed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoffeeOptionTile(
            title: 'Base',
            subtitle: 'Habis',
            value: 'Rp 24.000',
            icon: Icons.coffee,
            onTap: null,
          ),
        ),
      ),
    );
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
    await tester.tap(find.text('Base'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'customer menu disables sold-out products and unavailable Base while keeping Lite selectable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = CartProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: MaterialApp(home: HomeScreen(apiService: _HomeApi())),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final unavailable = find.byKey(const ValueKey('menu-add-2'));
      await tester.ensureVisible(unavailable);
      expect(tester.widget<GestureDetector>(unavailable).onTap, isNull);
      expect(find.text('Stok habis'), findsOneWidget);
      expect(find.text('Base: 0 · Lite: 2 porsi'), findsOneWidget);
      final available = find.byKey(const ValueKey('menu-add-1'));
      await tester.ensureVisible(available);
      await tester.tap(available);
      await tester.pump(const Duration(milliseconds: 500));
      final base = find.ancestor(
        of: find.text('Base'),
        matching: find.byType(CoffeeOptionTile),
      );
      final lite = find.ancestor(
        of: find.text('Lite'),
        matching: find.byType(CoffeeOptionTile),
      );
      expect(tester.widget<CoffeeOptionTile>(base).onTap, isNull);
      expect(tester.widget<CoffeeOptionTile>(lite).onTap, isNotNull);
      await tester.ensureVisible(find.text('Lite'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Lite'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(cart.items['1_lite']?.quantity, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('cart shows stock and disables increasing an exhausted variant', (
    tester,
  ) async {
    final cart = CartProvider();
    await tester.pump();
    cart.addItem(ProductModel.fromJson(_coffee(base: 1)), variant: 'base');
    await tester.pumpWidget(_app(cart, _StockApi()));
    await tester.pumpAndSettle();
    expect(find.text('Stok: 1 porsi'), findsOneWidget);
    final increment = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_rounded),
    );
    expect(increment.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh sold out stock blocks QRIS before the payment sheet opens', (
    tester,
  ) async {
    final cart = CartProvider();
    await tester.pump();
    cart.addItem(ProductModel.fromJson(_coffee(base: 1)), variant: 'base');
    final api = _StockApi(stock: 0);
    await tester.pumpWidget(_app(cart, api));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('cart-checkout-action')),
    );
    await tester.tap(find.byKey(const ValueKey('cart-checkout-action')));
    await tester.pumpAndSettle();
    expect(find.byType(QrisPaymentSheet), findsNothing);
    expect(
      find.text(
        'Ada produk yang habis atau jumlahnya melebihi stok. Periksa kembali keranjang.',
      ),
      findsOneWidget,
    );
    expect(cart.totalItemCount, 1);
    expect(api.qrisCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _coffee({int base = 2, int lite = 2}) => {
  'id': 1,
  'name': 'Kopi uji',
  'price': 24000,
  'price_lite': 20000,
  'category': {'slug': 'coffee', 'name': 'Coffee'},
  'is_available': true,
  'stock_quantities': {'base': base, 'lite': lite},
};

Widget _app(CartProvider cart, ApiService api) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: cart),
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
  ],
  child: MaterialApp(
    home: Scaffold(body: CartScreen(apiService: api)),
  ),
);

class _StockApi extends ApiService {
  @override
  Future<Map<String, dynamic>?> pendingCheckout() async => null;

  @override
  Future<Map<String, dynamic>> prepareCheckout({
    required List<Map<String, dynamic>> items,
    required double expectedTotal,
    Map<String, dynamic>? pending,
    String? cartId,
  }) async => {
    'success': true,
    'data': {
      'id': 'test-reservation',
      'can_pay': true,
      'local_cart_id': pending == null ? cartId : pending['local_cart_id'],
      'items': items,
      'total': expectedTotal,
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    },
  };

  _StockApi({this.stock = 1});
  final int stock;
  int qrisCalls = 0;

  @override
  Future<Map<String, dynamic>> getProducts({
    int? categoryId,
    String? search,
  }) async => {
    'success': true,
    'data': [_coffee(base: stock, lite: 0)],
  };

  @override
  Future<Map<String, dynamic>> getQrisImage() async {
    qrisCalls++;
    return {'success': false};
  }
}

class _HomeApi extends _StockApi {
  @override
  Future<Map<String, dynamic>> getProducts({
    int? categoryId,
    String? search,
  }) async => {
    'success': true,
    'data': [
      {..._coffee(base: 0, lite: 2), 'category_id': 1},
      {
        ..._coffee(base: 0, lite: 0),
        'id': 2,
        'name': 'Kopi habis',
        'category_id': 1,
        'is_available': false,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> getCategories() async => {
    'success': true,
    'data': [
      {'id': 1, 'name': 'Coffee', 'slug': 'coffee'},
    ],
  };

  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'success': true,
    'data': {
      'id': 1,
      'name': 'Pelanggan uji',
      'email': 'uji@example.test',
      'role': 'pengguna',
    },
  };
}
