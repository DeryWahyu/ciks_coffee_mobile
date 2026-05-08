class ProductModel {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;
  final double? priceLite;
  final String? categoryName;
  final bool isCoffee;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.price,
    this.priceLite,
    this.categoryName,
    this.isCoffee = false,
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
    );
  }

  bool get hasLitePrice => priceLite != null;

  double getPrice(String? variant) {
    if (variant == 'lite' && priceLite != null) {
      return priceLite!;
    }
    return price;
  }
}
