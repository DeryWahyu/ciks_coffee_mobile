import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  Map<String, CartItemModel> _items = {};
  Map<int, ProductModel>? _catalogue;

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart_data');
      if (cartData != null) {
        final decoded = json.decode(cartData) as Map<String, dynamic>;
        _items = decoded.map(
          (key, value) => MapEntry(key, CartItemModel.fromJson(value)),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        _items.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString('cart_data', encoded);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
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

    if (_items[key]!.quantity > 1) {
      _items[key]!.quantity--;
    } else {
      _items.remove(key);
    }
    _saveCart();
    notifyListeners();
  }

  /// Completely remove a product from the cart
  void deleteItem(String key) {
    _items.remove(key);
    _saveCart();
    notifyListeners();
  }

  /// Update quantity directly
  void updateQuantity(String key, int quantity) {
    if (!_items.containsKey(key)) return;

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
    _saveCart();
    notifyListeners();
  }

  /// Clear the entire cart
  void clear() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  /// Generate the items list for checkout API payload
  List<Map<String, dynamic>> toCheckoutItems() {
    return _items.values.map((item) => item.toCheckoutJson()).toList();
  }
}
