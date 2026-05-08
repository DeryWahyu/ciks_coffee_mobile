class OrderModel {
  final int id;
  final String orderNumber;
  final String customerName;
  final String paymentMethod;
  final double total;
  final double? cashReceived;
  final double? changeAmount;
  final String status;
  final String statusLabel;
  final String? paidAt;
  final String createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.paymentMethod,
    required this.total,
    this.cashReceived,
    this.changeAmount,
    required this.status,
    required this.statusLabel,
    this.paidAt,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?) ?? [];
    return OrderModel(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      cashReceived: json['cash_received'] != null
          ? double.tryParse(json['cash_received'].toString())
          : null,
      changeAmount: json['change_amount'] != null
          ? double.tryParse(json['change_amount'].toString())
          : null,
      status: json['status'] ?? '',
      statusLabel: json['status_label'] ?? json['status'] ?? '',
      paidAt: json['paid_at'],
      createdAt: json['created_at'] ?? '',
      items: itemsList.map((i) => OrderItemModel.fromJson(i)).toList(),
    );
  }
}

class OrderItemModel {
  final String productName;
  final String? variant;
  final int quantity;
  final double price;
  final double subtotal;

  OrderItemModel({
    required this.productName,
    this.variant,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productName: json['product_name'] ?? '',
      variant: json['variant'],
      quantity: json['quantity'] ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
    );
  }
}
