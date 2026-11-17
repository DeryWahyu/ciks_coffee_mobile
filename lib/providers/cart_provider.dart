import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  Map<String, CartItemModel> _items = {};
  Map<int, ProductModel>? _catalogue;
  static int _basketSequence = 0;
  static String _newBasketId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${++_basketSequence}';
  String _basketId = _newBasketId();
  String get basketId => _basketId;
  final Set<String> _appliedCheckouts = {};
  int _sessionGeneration = 0;
  int _editVersion = 0;
  bool _loaded = false;
  late final Future<void> ready;
  int get sessionGeneration => _sessionGeneration;
  late final StreamSubscription<void> _resetSubscription;
  Future<void> _saveQueue = Future.value();
  bool _lastSaveSucceeded = true;
  Future<bool> persist() async {
    await _saveQueue;
    return _lastSaveSucceeded;
  }

  CartProvider() {
    _resetSubscription = ApiService.cartResets.listen((_) {
      _sessionGeneration++;
      _catalogue = null;
      _appliedCheckouts.clear();
      clear();
    });
    ready = _loadCart();
  }

  @override
  void dispose() {
    _resetSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadCart() async {
    final generation = _sessionGeneration;
    final editVersion = _editVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _sessionGeneration || editVersion != _editVersion) {
        return;
      }
      final cartData = prefs.getString('cart_data');
      if (cartData != null) {
        final decoded = json.decode(cartData) as Map<String, dynamic>;
        final entries = decoded['version'] == 2
            ? Map<String, dynamic>.from(decoded['items'] as Map)
            : decoded;
        if (decoded['version'] == 2) {
          _basketId = decoded['basket_id'] as String;
          _appliedCheckouts.addAll(
            List<String>.from(decoded['applied_checkouts'] as List? ?? []),
          );
        }
        _items = entries.map(
          (key, value) => MapEntry(key, CartItemModel.fromJson(value)),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    } finally {
      _loaded = true;
    }
  }

  Future<void> _saveCart() {
    final generation = _sessionGeneration;
    final empty = _items.isEmpty && _appliedCheckouts.isEmpty;
    final encoded = json.encode({
      'version': 2,
      'basket_id': _basketId,
      'applied_checkouts': _appliedCheckouts.toList(),
      'items': _items.map((key, value) => MapEntry(key, value.toJson())),
    });
    _saveQueue = _saveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (generation != _sessionGeneration) return;
        if (empty) {
          _lastSaveSucceeded = await prefs.remove('cart_data');
        } else {
          _lastSaveSucceeded = await prefs.setString('cart_data', encoded);
        }
      } catch (e) {
        _lastSaveSucceeded = false;
        debugPrint('Error saving cart: $e');
      }
    });
    return _saveQueue;
  }

  /// Unmodifiable view of all cart items
  Map<String, CartItemModel> get items => Map.unmodifiable(_items);

  /// List of cart items for easy iteration
  List<CartItemModel> get itemsList => _items.values.toList();

  /// Total number of items (sum of all quantities)
  int get totalItemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Total price
  double get totalPrice =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Whether the cart is empty
  bool get isEmpty => _items.isEmpty;

  ProductModel? currentProduct(ProductModel product) =>
      _catalogue == null ? product : _catalogue![product.id];

  int? remainingFor(ProductModel product, {String? variant}) {
    final current = currentProduct(product);
    if (current == null || !current.hasStock) return 0;
    final stock = current.stockFor(variant);
    if (stock == null) return null;
    final inCart =
        _items['${product.id}_${variant ?? 'default'}']?.quantity ?? 0;
    return (stock - inCart).clamp(0, stock);
  }

  bool canAddItem(ProductModel product, {String? variant}) =>
      (remainingFor(product, variant: variant) ?? 1) > 0;

  bool get hasStockConflict => _items.values.any((item) {
    final product = currentProduct(item.product);
    if (product == null || !product.hasStock) return true;
    final stock = product.stockFor(item.variant);
    return stock != null && item.quantity > stock;
  });

  /// Keep quantities intact so customers can review shortages themselves.
  void updateCatalogue(
    List<ProductModel> products, {
    bool refreshPrices = false,
  }) {
    if (!_loaded) {
      ready.then(
        (_) => updateCatalogue(products, refreshPrices: refreshPrices),
      );
      return;
    }
    _catalogue = {for (final product in products) product.id: product};
    _items = _items.map(
      (key, item) => MapEntry(
        key,
        CartItemModel(
          product: _catalogue![item.product.id] == null
              ? item.product
              : ProductModel.fromLocalJson({
                  ..._catalogue![item.product.id]!.toJson(),
                  if (!refreshPrices) ...{
                    'price': item.product.price,
                    'price_lite': item.product.priceLite,
                  },
                }),
          variant: item.variant,
          quantity: item.quantity,
        ),
      ),
    );
    _saveCart();
    notifyListeners();
  }

  /// Add a product to the cart. If it already exists (same product+variant), increment quantity.
  bool addItem(ProductModel product, {String? variant}) {
    if (!canAddItem(product, variant: variant)) return false;
    _editVersion++;
    product = currentProduct(product)!;
    final key = '${product.id}_${variant ?? 'default'}';

    if (_items.containsKey(key)) {
      _items[key]!.quantity++;
    } else {
      _items[key] = CartItemModel(
        product: product,
        variant: variant,
        quantity: 1,
      );
    }
    _saveCart();
    notifyListeners();
    return true;
  }

  /// Remove one quantity of a product. If quantity reaches 0, remove entirely.
  void removeItem(String key) {
    if (!_items.containsKey(key)) return;
    _editVersion++;

    if (_items[key]!.quantity > 1) {
      _items[key]!.quantity--;
    } else {
      _items.remove(key);
    }
    if (_items.isEmpty) _basketId = _newBasketId();
    _saveCart();
    notifyListeners();
  }

  /// Completely remove a product from the cart
  void deleteItem(String key) {
    _editVersion++;
    _items.remove(key);
    if (_items.isEmpty) _basketId = _newBasketId();
    _saveCart();
    notifyListeners();
  }

  /// Update quantity directly
  void updateQuantity(String key, int quantity) {
    if (!_items.containsKey(key)) return;
    _editVersion++;

    if (quantity <= 0) {
      _items.remove(key);
    } else {
      final item = _items[key]!;
      final limit = currentProduct(item.product)?.stockFor(item.variant);
      if (quantity > item.quantity &&
          (currentProduct(item.product) == null ||
              !currentProduct(item.product)!.hasStock ||
              (limit != null && quantity > limit))) {
        return;
      }
      _items[key]!.quantity = quantity;
    }
    if (_items.isEmpty) _basketId = _newBasketId();
    _saveCart();
    notifyListeners();
  }

  /// Clear the entire cart
  void clear() {
    _editVersion++;
    _items.clear();
    _basketId = _newBasketId();
    _saveCart();
    notifyListeners();
  }

  /// Remove the submitted quantities only, retaining additions made on another tab.
  void removePurchased(
    List<Map<String, dynamic>> submitted,
    int generation, {
    String? checkoutId,
    bool removeFromCart = true,
  }) {
    if (generation != _sessionGeneration) return;
    if (checkoutId != null && !_appliedCheckouts.add(checkoutId)) {
      _saveCart();
      return;
    }
    while (_appliedCheckouts.length > 100) {
      _appliedCheckouts.remove(_appliedCheckouts.first);
    }
    _editVersion++;
    for (final item in removeFromCart ? submitted : <Map<String, dynamic>>[]) {
      final key = '${item['product_id']}_${item['variant'] ?? 'default'}';
      final current = _items[key];
      if (current == null) continue;
      current.quantity -= (item['quantity'] as num).toInt();
      if (current.quantity <= 0) _items.remove(key);
    }
    if (_items.isEmpty) _basketId = _newBasketId();
    _saveCart();
    notifyListeners();
  }

  /// Generate the items list for checkout API payload
  List<Map<String, dynamic>> toCheckoutItems() {
    return _items.values.map((item) => item.toCheckoutJson()).toList();
  }
}
