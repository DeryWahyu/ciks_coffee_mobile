import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItemModel> _items = {};

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

  /// Add a product to the cart. If it already exists (same product+variant), increment quantity.
  void addItem(ProductModel product, {String? variant}) {
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
    notifyListeners();
  }

  /// Remove one quantity of a product. If quantity reaches 0, remove entirely.
  void removeItem(String key) {
    if (!_items.containsKey(key)) return;

    if (_items[key]!.quantity > 1) {
      _items[key]!.quantity--;
    } else {
      _items.remove(key);
    }
    notifyListeners();
  }

  /// Completely remove a product from the cart
  void deleteItem(String key) {
    _items.remove(key);
    notifyListeners();
  }

  /// Update quantity directly
  void updateQuantity(String key, int quantity) {
    if (!_items.containsKey(key)) return;

    if (quantity <= 0) {
      _items.remove(key);
    } else {
      _items[key]!.quantity = quantity;
    }
    notifyListeners();
  }

  /// Clear the entire cart
  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Generate the items list for checkout API payload
  List<Map<String, dynamic>> toCheckoutItems() {
    return _items.values.map((item) => item.toCheckoutJson()).toList();
  }
}
