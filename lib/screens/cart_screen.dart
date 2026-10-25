import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cart_item_model.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../widgets/cart_checkout_panel.dart';
import '../widgets/coffee_overlays.dart';
import '../widgets/qris_payment_sheet.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  bool _isCheckingOut = false;
  bool _paymentSheetOpen = false;

  String _formatPrice(double value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  Future<void> _checkout() async {
    if (_isCheckingOut || _paymentSheetOpen) return;
    final cart = context.read<CartProvider>();
    final lang = context.read<LanguageProvider>();
    if (cart.isEmpty) return;
    _paymentSheetOpen = true;
    try {
      final proof = await showCoffeeSheet<String>(
        context: context,
        builder: (_) => QrisPaymentSheet(
          total: _formatPrice(cart.totalPrice),
          language: lang,
          apiService: _apiService,
        ),
      );
      if (!mounted || proof == null) return;
      setState(() => _isCheckingOut = true);
      final result = await _apiService.checkout(
        paymentMethod: 'qris',
        items: cart.toCheckoutItems(),
        paymentProofPath: proof,
      );
      if (result['success'] == true) cart.clear();
      if (!mounted) return;
      if (result['success'] == true) {
        await _showSuccessDialog(
          Map<String, dynamic>.from(result['data']),
          lang,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  (lang.isEnglish
                      ? 'Order could not be sent.'
                      : 'Pesanan belum dapat dikirim.'),
            ),
            backgroundColor: CoffeeColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      _paymentSheetOpen = false;
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _showSuccessDialog(
    Map<String, dynamic> data,
    LanguageProvider lang,
  ) {
    final order = Map<String, dynamic>.from(data['order'] ?? data);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CoffeeDialog(
        title: lang.isEnglish ? 'Order received!' : 'Pesanan diterima!',
        message: lang.isEnglish
            ? 'Your payment proof is being reviewed. Track your order in the Status menu.'
            : 'Bukti pembayaranmu akan diperiksa kasir. Pantau perkembangan pesanan di menu Status.',
        icon: Icons.check_circle_outline_rounded,
        accent: CoffeeColors.success,
        dismissible: false,
        content: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CoffeeColors.cream,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order['order_number']?.toString() ?? '',
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CoffeeColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order['formatted_total']?.toString() ??
                    _formatPrice(double.tryParse('${order['total']}') ?? 0),
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CoffeeColors.ink,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CoffeeButton(
            label: lang.isEnglish ? 'Done' : 'Selesai',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: CoffeeColors.cream,
      appBar: AppBar(
        title: Text(
          lang.tr('Keranjang'),
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: CoffeeColors.ink,
          ),
        ),
        backgroundColor: CoffeeColors.cream,
        foregroundColor: CoffeeColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.isEmpty) return _emptyCart(lang);
            return LayoutBuilder(
              builder: (context, constraints) {
                final navigationInset = MediaQuery.paddingOf(context).bottom;
                final scrollTogether =
                    constraints.maxHeight - navigationInset < 450 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final items = ListView.builder(
                  shrinkWrap: scrollTogether,
                  physics: scrollTogether
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: cart.itemsList.length,
                  itemBuilder: (_, index) =>
                      _cartItem(cart.itemsList[index], cart, lang),
                );
                final panel = CartCheckoutPanel(
                  total: _formatPrice(cart.totalPrice),
                  itemCount: cart.totalItemCount,
                  language: lang,
                  busy: _isCheckingOut,
                  onCheckout: _checkout,
                );
                if (scrollTogether) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: navigationInset),
                    child: Column(children: [items, panel]),
                  );
                }
                return Column(
                  children: [
                    Expanded(child: items),
                    panel,
                    SizedBox(height: navigationInset),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyCart(LanguageProvider lang) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: CoffeeColors.muted,
          ),
          const SizedBox(height: 20),
          Text(
            lang.tr('Keranjang Kosong'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: CoffeeColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang.tr('Yuk, pilih menu favoritmu!'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 14,
              color: CoffeeColors.muted,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cartItem(
    CartItemModel item,
    CartProvider cart,
    LanguageProvider lang,
  ) {
    final image = _apiService.getImageUrl(item.product.imageUrl ?? '');
    return Container(
      key: ValueKey('cart-item-${item.uniqueKey}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CoffeeColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: CoffeeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatPrice(item.unitPrice),
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        fontSize: 13,
                        color: CoffeeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: lang.isEnglish ? 'Remove item' : 'Hapus item',
                onPressed: _isCheckingOut
                    ? null
                    : () => cart.deleteItem(item.uniqueKey),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: CoffeeColors.muted,
                  size: 20,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: CoffeeColors.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: lang.isEnglish
                          ? 'Decrease quantity'
                          : 'Kurangi jumlah',
                      onPressed: _isCheckingOut
                          ? null
                          : () => cart.removeItem(item.uniqueKey),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CoffeeColors.ink,
                      ),
                    ),
                    IconButton(
                      tooltip: lang.isEnglish
                          ? 'Increase quantity'
                          : 'Tambah jumlah',
                      onPressed: _isCheckingOut
                          ? null
                          : () => cart.addItem(
                              item.product,
                              variant: item.variant,
                            ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => const SizedBox(
    width: 64,
    height: 64,
    child: ColoredBox(
      color: CoffeeColors.cream,
      child: Icon(Icons.coffee_outlined, color: CoffeeColors.muted, size: 28),
    ),
  );
}
