class ProductModel {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;
  final double? priceLite;
  final String? categoryName;
  final bool isCoffee;
  final bool isAvailable;
  final Map<String, int>? stockQuantities;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.price,
    this.priceLite,
    this.categoryName,
    this.isCoffee = false,
    this.isAvailable = true,
    this.stockQuantities,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final categorySlug = category?['slug'] ?? '';

    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      priceLite: json['price_lite'] != null
          ? double.tryParse(json['price_lite'].toString())
          : null,
      categoryName: category?['name'],
      isCoffee: categorySlug == 'coffee',
      isAvailable: json['is_available'] ?? true,
      stockQuantities: _parseStocks(json['stock_quantities']),
    );
  }

  bool get hasLitePrice => priceLite != null;

  static Map<String, int>? _parseStocks(dynamic value) {
    if (value is! Map) return null;
    return Map.unmodifiable(
      value.map((key, count) {
        final quantity = int.tryParse(count.toString()) ?? 0;
        return MapEntry(key.toString(), quantity < 0 ? 0 : quantity);
      }),
    );
  }

  int? stockFor(String? variant) {
    if (!isAvailable) return 0;
    if (isCoffee) {
      if (variant != 'base' && variant != 'lite') return 0;
      if (variant == 'lite' && !hasLitePrice) return 0;
    } else if (variant != null) {
      return 0;
    }
    return stockQuantities?[isCoffee ? variant : 'default'] ??
        (stockQuantities == null ? null : 0);
  }

  bool get hasStock =>
      isAvailable &&
      (isCoffee
          ? (stockFor('base') ?? 1) > 0 ||
                (hasLitePrice && (stockFor('lite') ?? 1) > 0)
          : (stockFor(null) ?? 1) > 0);

  double getPrice(String? variant) {
    if (variant == 'lite' && priceLite != null) {
      return priceLite!;
    }
    return price;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'price': price,
      'price_lite': priceLite,
      'categoryName': categoryName,
      'isCoffee': isCoffee,
      'is_available': isAvailable,
      'stock_quantities': stockQuantities,
    };
  }

  factory ProductModel.fromLocalJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      priceLite: json['price_lite'] != null
          ? double.tryParse(json['price_lite'].toString())
          : null,
      categoryName: json['categoryName'],
      isCoffee: json['isCoffee'] ?? false,
      isAvailable: json['is_available'] ?? true,
      stockQuantities: _parseStocks(json['stock_quantities']),
    );
  }
}
