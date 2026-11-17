import 'package:ciks_coffee_mobile/models/product_model.dart';
import 'package:ciks_coffee_mobile/providers/cart_provider.dart';
import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:ciks_coffee_mobile/screens/home_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/app_bottom_navigation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
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

  for (final scenario in [
    (const Size(390, 844), 34.0, 1.0),
    (const Size(320, 568), 0.0, 1.0),
    (const Size(844, 390), 0.0, 1.0),
    (const Size(390, 844), 34.0, 1.8),
  ]) {
    testWidgets(
      'last content clears floating navbar after scroll settles at $scenario',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cart = CartProvider();
        await cart.ready;
        cart.addItem(ProductModel.fromJson(_product(1)));
        await tester.pumpWidget(
          _app(cart, _MenuApi(), scenario.$2, scenario.$3),
        );
        await tester.pumpAndSettle();
        await _atEnd(tester);
        _clear(tester, find.byKey(const ValueKey('menu-add-5')));
        for (final (tab, key) in [
          ('Profil', 'profile-logout'),
          ('Status', 'active-order-3'),
          ('Riwayat', 'history-order-3'),
          ('Keranjang', 'cart-checkout-action'),
        ]) {
          await tester.tap(
            find.descendant(
              of: find.byType(AppBottomNavigation),
              matching: find.text(tab),
            ),
          );
          await tester.pumpAndSettle();
          await _atEnd(tester);
          _clear(tester, find.byKey(ValueKey(key)));
          expect(tester.takeException(), isNull, reason: '$tab at $scenario');
        }
        await tester.pumpWidget(const SizedBox());
        cart.dispose();
      },
    );
  }

  testWidgets(
    'empty states and error retry remain reachable on a short screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = CartProvider();
      await cart.ready;
      await tester.pumpWidget(_app(cart, _MenuApi(empty: true), 34, 1.4));
      await tester.pumpAndSettle();
      for (final tab in ['Status', 'Riwayat', 'Profil', 'Keranjang']) {
        await tester.tap(
          find.descendant(
            of: find.byType(AppBottomNavigation),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        await _atEnd(tester);
        _clear(
          tester,
          find.text(
            tab == 'Profil'
                ? 'Coba Lagi'
                : tab == 'Keranjang'
                ? 'Yuk, pilih menu favoritmu!'
                : 'Refresh',
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      cart.dispose();
    },
  );
}

void _clear(WidgetTester tester, Finder content) {
  expect(content, findsOneWidget);
  final navigation = tester.getRect(find.byType(AppBottomNavigation));
  final rect = tester.getRect(content);
  expect(rect.bottom, lessThanOrEqualTo(navigation.top - 10));
  expect(rect.bottom, greaterThan(0));
}

Future<void> _atEnd(WidgetTester tester) async {
  final stack = tester.widget<IndexedStack>(find.byType(IndexedStack).first);
  final current = find.byWidget(stack.children[stack.index!]);
  final scrollables = find.descendant(
    of: current,
    matching: find.byType(Scrollable),
  );
  if (scrollables.evaluate().isEmpty) return;
  final state = scrollables
      .evaluate()
      .map((element) => (element as StatefulElement).state as ScrollableState)
      .firstWhere(
        (state) => axisDirectionToAxis(state.axisDirection) == Axis.vertical,
      );
  for (var i = 0; i < 3; i++) {
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

Widget _app(
  CartProvider cart,
  ApiService api,
  double safeBottom,
  double scale,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: cart),
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
  ],
  child: MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(bottom: safeBottom),
          viewPadding: EdgeInsets.only(bottom: safeBottom),
          textScaler: TextScaler.linear(scale),
        ),
        child: HomeScreen(apiService: api),
      ),
    ),
  ),
);

Map<String, dynamic> _product(int id) => {
  'id': id,
  'name': 'Menu uji $id',
  'price': 15000,
  'category_id': 1,
  'category': {'id': 1, 'slug': 'snack', 'name': 'Snack'},
  'is_available': true,
  'stock_quantities': {'default': 20},
};
Map<String, dynamic> _order(int id, String status) => {
  'id': id,
  'order_number': 'PESANAN-$id',
  'total': 15000,
  'status': status,
  'status_label': status == 'diambil' ? 'Sudah diambil' : 'Siap diambil',
  'payment_method': 'qris',
  'created_at': '2026-11-17T00:00:00Z',
  'items': [
    {
      'product_name': 'Menu uji $id',
      'quantity': 1,
      'price': 15000,
      'subtotal': 15000,
    },
  ],
};

class _MenuApi extends ApiService {
  _MenuApi({this.empty = false});
  final bool empty;
  @override
  Future<Map<String, dynamic>?> pendingCheckout() async => null;
  @override
  Future<Map<String, dynamic>> getCategories() async => {
    'success': true,
    'data': [
      {'id': 1, 'name': 'Snack', 'slug': 'snack'},
    ],
  };
  @override
  Future<Map<String, dynamic>> getProducts({
    int? categoryId,
    String? search,
  }) async => {
    'success': true,
    'data': List.generate(5, (i) => _product(i + 1)),
  };
  @override
  Future<Map<String, dynamic>> getProfile() async => empty
      ? {'success': false, 'message': 'Tidak tersambung'}
      : {
          'success': true,
          'data': {
            'id': 1,
            'name': 'Pelanggan uji',
            'email': 'uji@example.test',
            'role': 'pengguna',
          },
        };
  @override
  Future<Map<String, dynamic>> getActiveOrders() async => {
    'success': true,
    'data': empty ? [] : List.generate(3, (i) => _order(i + 1, 'selesai')),
  };
  @override
  Future<Map<String, dynamic>> getOrderHistory() async => {
    'success': true,
    'data': empty ? [] : List.generate(3, (i) => _order(i + 1, 'diambil')),
  };
}
