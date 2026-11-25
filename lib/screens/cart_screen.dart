import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cart_item_model.dart';
import '../models/checkout_session_model.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/user_message.dart';
import '../widgets/cart_checkout_panel.dart';
import '../widgets/coffee_overlays.dart';
import '../widgets/qris_payment_sheet.dart';
import '../widgets/navigation_safe_content.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  bool _isCheckingOut = false;
  bool _paymentSheetOpen = false;
  bool _closingPaymentSheet = false;
  Map<String, dynamic>? _pendingCheckout;
  Timer? _paymentDeadline;
  VoidCallback? _closePaymentSheet;
  int _pendingRevision = 0;
  bool get _hasPendingCheckout => _pendingCheckout != null;
  bool get _needsPaymentReview =>
      _pendingCheckout != null &&
      CheckoutSession(_pendingCheckout!).needsReview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restorePending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentDeadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final pending = _pendingCheckout;
    if (pending != null && CheckoutSession(pending).endedAt(DateTime.now())) {
      unawaited(_expirePending(pending));
    }
    if (!_paymentSheetOpen && !_isCheckingOut) unawaited(_restorePending());
  }

  void _setPending(Map<String, dynamic>? pending) {
    _pendingRevision++;
    _paymentDeadline?.cancel();
    setState(() => _pendingCheckout = pending);
    if (pending == null) return;
    final session = CheckoutSession(pending);
    if (session.expiresAt == null || session.needsReview) return;
    final account = ApiService.sessionVersion;
    _paymentDeadline = Timer(session.expiresAt!.difference(DateTime.now()), () {
      if (!mounted) return;
      if (account != ApiService.sessionVersion) {
        _setPending(null);
        return;
      }
      unawaited(_expirePending(pending));
    });
  }

  Future<void> _expirePending(Map<String, dynamic> pending) async {
    if (!mounted ||
        _isCheckingOut ||
        !identical(_pendingCheckout, pending) ||
        CheckoutSession(pending).needsReview) {
      return;
    }
    _setPending(null);
    _closePaymentSheet?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sesi pembayaran telah berakhir. Jika sudah membayar, tunjukkan bukti kepada kasir.',
        ),
      ),
    );
    try {
      await _apiService.clearPendingCheckout(
        checkoutId: pending['checkout_id'],
        requestKey: pending['request_key'],
      );
    } catch (_) {
      // Expired metadata will also be checked when storage is read again.
    }
  }

  Future<void> _restorePending() async {
    final request = ++_pendingRevision;
    try {
      final pending = await _apiService.pendingCheckout();
      if (mounted &&
          request == _pendingRevision &&
          !_paymentSheetOpen &&
          !_isCheckingOut) {
        _setPending(pending);
      }
    } catch (_) {
      /* The checkout button retries when the connection is available. */
    }
  }

  String _formatPrice(double value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  Future<void> _checkout() async {
    if (_isCheckingOut || _paymentSheetOpen) return;
    _pendingRevision++;
    final cart = context.read<CartProvider>();
    final lang = context.read<LanguageProvider>();
    _paymentSheetOpen = true;
    try {
      final generation = cart.sessionGeneration;
      await cart.ready;
      final pending = await _apiService.pendingCheckout();
      if (!mounted) return;
      if (generation != cart.sessionGeneration) return;
      _setPending(pending);
      if (cart.isEmpty && pending == null) return;
      if (pending == null) {
        final catalogue = await _apiService.getProducts();
        if (!mounted) return;
        if (catalogue['success'] != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.tr(
                  UserMessage.display(
                    catalogue['message'],
                    fallback: 'Stok belum dapat diperiksa. Silakan coba lagi.',
                  ),
                ),
              ),
            ),
          );
          return;
        }
        cart.updateCatalogue(
          (catalogue['data'] as List)
              .map(
                (row) => ProductModel.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList(),
          refreshPrices: true,
        );
        if (cart.hasStockConflict) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.isEnglish
                    ? 'Some items exceed available stock. Please review your cart.'
                    : 'Ada produk yang habis atau jumlahnya melebihi stok. Periksa kembali keranjang.',
              ),
            ),
          );
          return;
        }
      }
      final prepared = await _apiService.prepareCheckout(
        items: cart.toCheckoutItems(),
        expectedTotal: cart.totalPrice,
        pending: pending,
        cartId: cart.basketId,
      );
      if (!mounted) return;
      if (generation != cart.sessionGeneration) return;
      if (prepared['success'] != true) {
        if (prepared['expired'] == true) _setPending(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              prepared['message']?.toString() ??
                  'Pembayaran belum dapat disiapkan.',
            ),
          ),
        );
        return;
      }
      final quote = Map<String, dynamic>.from(prepared['data']);
      final paymentItems = (quote['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (quote['order'] is Map) {
        cart.removePurchased(
          paymentItems,
          generation,
          checkoutId: quote['id'],
          removeFromCart:
              quote['local_cart_id'] != null &&
              quote['local_cart_id'] == cart.basketId,
        );
        final persisted = await cart.persist();
        if (persisted) {
          await _apiService.clearPendingCheckout(checkoutId: quote['id']);
        }
        if (mounted) {
          _setPending(
            persisted
                ? null
                : CheckoutSession.fromQuote(
                    quote,
                    localCartId: quote['local_cart_id'],
                    submissionPending: true,
                  ).data,
          );
        }
        if (mounted) await _showSuccessDialog({'order': quote['order']}, lang);
        return;
      }
      final paymentTotal = _formatPrice(
        double.parse(quote['total'].toString()),
      );
      final active = CheckoutSession.fromQuote(
        quote,
        localCartId: quote['local_cart_id'],
        submissionPending: pending?['submission_pending'] == true,
      ).data;
      if (CheckoutSession(active).endedAt(DateTime.now())) {
        _setPending(active);
        await _expirePending(active);
        return;
      }
      _setPending(active);
      final proof = await showCoffeeSheet<String>(
        context: context,
        builder: (sheetContext) {
          _closePaymentSheet = () {
            if (_closingPaymentSheet || !sheetContext.mounted) return;
            final route = ModalRoute.of(sheetContext);
            if (route == null || !route.isActive) return;
            _closingPaymentSheet = true;
            final navigator = Navigator.of(sheetContext);
            navigator.popUntil((entry) => entry == route);
            navigator.pop();
          };
          return QrisPaymentSheet(
            total: paymentTotal,
            language: lang,
            apiService: _apiService,
            expiresAt: DateTime.parse(quote['expires_at']),
            items: paymentItems,
            allowPayment:
                quote['can_pay'] == true &&
                !CheckoutSession(active).needsReview,
            onExpired:
                quote['can_pay'] == true && !CheckoutSession(active).needsReview
                ? () {
                    unawaited(_expirePending(active));
                  }
                : null,
            onCancel: () async {
              final cancelled = await _apiService.cancelCheckout(quote['id']);
              if (cancelled['success'] == true &&
                  mounted &&
                  _pendingCheckout?['checkout_id'] == quote['id']) {
                _setPending(null);
              }
              return cancelled;
            },
          );
        },
      );
      if (!mounted || proof == null || proof.isEmpty) return;
      if (generation != cart.sessionGeneration) return;
      setState(() => _isCheckingOut = true);
      _setPending({...active, 'submission_pending': true});
      final result = await _apiService.checkout(
        paymentMethod: 'qris',
        items: paymentItems,
        paymentProofPath: proof,
        checkoutId: quote['id'],
      );
      if (result['success'] == true) {
        cart.removePurchased(
          paymentItems,
          generation,
          checkoutId: quote['id'],
          removeFromCart:
              quote['local_cart_id'] != null &&
              quote['local_cart_id'] == cart.basketId,
        );
        final persisted = await cart.persist();
        if (persisted) {
          await _apiService.clearPendingCheckout(checkoutId: quote['id']);
        }
        if (mounted && persisted) _setPending(null);
      }
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _isCheckingOut = false);
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pembayaran belum dapat diperiksa. Silakan coba lagi untuk melanjutkan sesi yang sama.',
            ),
          ),
        );
      }
    } finally {
      _paymentSheetOpen = false;
      _closingPaymentSheet = false;
      _closePaymentSheet = null;
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
            if (cart.isEmpty && _hasPendingCheckout) {
              return NavigationSafeContent(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _needsPaymentReview
                          ? 'Periksa hasil pengiriman pembayaran sebelumnya.'
                          : 'Ada sesi pembayaran yang masih aktif.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    CoffeeButton(
                      label: _needsPaymentReview
                          ? 'Periksa pembayaran'
                          : 'Lanjutkan pembayaran',
                      onPressed: _checkout,
                      loading: _isCheckingOut,
                    ),
                  ],
                ),
              );
            }
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
                  total: _formatPrice(
                    _hasPendingCheckout
                        ? double.tryParse(
                                '${_pendingCheckout!['expected_total']}',
                              ) ??
                              cart.totalPrice
                        : cart.totalPrice,
                  ),
                  itemCount: _pendingCheckout?['items'] is List
                      ? (_pendingCheckout!['items'] as List).fold<int>(
                          0,
                          (sum, item) =>
                              sum + (int.tryParse('${item['quantity']}') ?? 0),
                        )
                      : cart.totalItemCount,
                  language: lang,
                  busy: _isCheckingOut,
                  resumePayment: _hasPendingCheckout,
                  reviewPayment: _needsPaymentReview,
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

  Widget _emptyCart(LanguageProvider lang) => NavigationSafeContent(
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
  );

  Widget _cartItem(
    CartItemModel item,
    CartProvider cart,
    LanguageProvider lang,
  ) {
    final image = _apiService.getImageUrl(item.product.imageUrl ?? '');
    final current = cart.currentProduct(item.product);
    final stock = current == null ? 0 : current.stockFor(item.variant);
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
                    if (stock != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        stock == 0
                            ? (lang.isEnglish ? 'Sold out' : 'Stok habis')
                            : (lang.isEnglish
                                  ? 'Stock: $stock portions'
                                  : 'Stok: $stock porsi'),
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 11,
                          color: CoffeeColors.muted,
                        ),
                      ),
                      if (item.quantity > stock)
                        Text(
                          lang.isEnglish
                              ? 'Please reduce the quantity or remove this item.'
                              : 'Kurangi jumlah atau hapus produk ini.',
                          style: const TextStyle(
                            fontFamily: 'CiksSans',
                            fontSize: 11,
                            color: CoffeeColors.danger,
                          ),
                        ),
                    ],
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
                      onPressed:
                          _isCheckingOut ||
                              !cart.canAddItem(
                                item.product,
                                variant: item.variant,
                              )
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
