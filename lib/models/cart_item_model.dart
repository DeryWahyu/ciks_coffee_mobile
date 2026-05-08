import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  final String? variant; // 'base', 'lite', or null
  int quantity;

  CartItemModel({
    required this.product,
    this.variant,
    this.quantity = 1,
  });

  double get unitPrice => product.getPrice(variant);
  double get subtotal => unitPrice * quantity;

  /// Unique key to distinguish same product with different variant
  String get uniqueKey => '${product.id}_${variant ?? 'default'}';

  String get displayName {
    if (variant != null) {
      return '${product.name} (${variant![0].toUpperCase()}${variant!.substring(1)})';
    }
    return product.name;
  }

  Map<String, dynamic> toCheckoutJson() {
    return {
      'product_id': product.id,
      'variant': variant,
      'quantity': quantity,
      'price': unitPrice,
    };
  }
}
