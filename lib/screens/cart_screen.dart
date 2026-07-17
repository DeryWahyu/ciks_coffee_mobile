import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _apiService = ApiService();
  bool _isCheckingOut = false;
  String _selectedPayment = 'qris';

  String _formatPrice(double price) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatCurrency.format(price);
  }

  void _checkout() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (cart.isEmpty) return;

    if (_selectedPayment == 'qris') {
      _showQrisPaymentSheet(cart, lang);
      return;
    }

    _processCheckout(cart, null, lang);
  }

  void _processCheckout(CartProvider cart, String? paymentProofPath, LanguageProvider lang) async {
    setState(() => _isCheckingOut = true);

    final result = await _apiService.checkout(
      paymentMethod: _selectedPayment,
      items: cart.toCheckoutItems(),
      paymentProofPath: paymentProofPath,
    );

    setState(() => _isCheckingOut = false);

    if (!mounted) return;

    if (result['success']) {
      cart.clear();
      _showSuccessDialog(result['data'], lang);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showQrisPaymentSheet(CartProvider cart, LanguageProvider lang) async {
    final qrisResult = await _apiService.getQrisImage();

    if (!mounted) return;

    File? proofFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        lang.tr('Pembayaran QRIS'),
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A3022),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(cart.totalPrice),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4A3022),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // QRIS Image
                    if (qrisResult['success'] == true)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD2B48C).withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            qrisResult['image_url'],
                            height: 200,
                            width: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Container(
                              height: 200,
                              color: const Color(0xFFF5E6D3),
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48, color: Color(0xFFD2B48C)),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E6D3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.qr_code_2, size: 64, color: Color(0xFFD2B48C)),
                            const SizedBox(height: 8),
                            Text(
                              qrisResult['message'] ?? lang.tr('QRIS belum tersedia'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Upload Proof Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Divider with label
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  lang.tr('Upload Bukti Transfer'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4A3022).withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Image Picker Button / Preview
                          if (proofFile == null)
                            GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1200,
                                  imageQuality: 80,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    proofFile = File(picked.path);
                                  });
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFD2B48C),
                                    style: BorderStyle.solid,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: const Color(0xFFF5E6D3).withValues(alpha: 0.5),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 36,
                                      color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      lang.tr('Ketuk untuk pilih screenshot bukti transfer'),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    proofFile!,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setModalState(() => proofFile = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          lang.tr('Bukti terpilih'),
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: proofFile == null
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _processCheckout(cart, proofFile?.path, lang);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A3022),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            proofFile == null
                                ? lang.tr('Upload bukti terlebih dahulu')
                                : lang.tr('Kirim Pesanan & Bukti Transfer'),
                            style: GoogleFonts.inter(
                              color: proofFile == null ? Colors.grey.shade500 : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        lang.tr('Batal'),
                        style: GoogleFonts.inter(color: Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(Map<String, dynamic> data, LanguageProvider lang) {
    final order = data['order'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                lang.tr('Pesanan Berhasil!'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${lang.tr('No.')} ${order['order_number']}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF4A3022).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${lang.tr('Total:')} ${order['formatted_total']}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3022),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3),
      appBar: AppBar(
        title: Text(lang.tr('Keranjang'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),
        backgroundColor: const Color(0xFFF5E6D3),
        foregroundColor: const Color(0xFF4A3022),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: const Color(0xFFD2B48C).withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text(
                    lang.tr('Keranjang Kosong'),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A3022),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.tr('Yuk, pilih menu favoritmu!'),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Cart Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.itemsList.length,
                  itemBuilder: (context, index) {
                    final item = cart.itemsList[index];
                    final imageUrl = _apiService.getImageUrl(item.product.imageUrl ?? '');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Product Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: imageUrl.isNotEmpty
                                ? Image.network(imageUrl, width: 64, height: 64, fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _imagePlaceholder())
                                : _imagePlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          // Product Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: const Color(0xFF4A3022),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatPrice(item.unitPrice),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4A3022).withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Quantity Controls
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5E6D3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _quantityButton(
                                  icon: Icons.remove,
                                  onTap: () => cart.removeItem(item.uniqueKey),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '${item.quantity}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: const Color(0xFF4A3022),
                                    ),
                                  ),
                                ),
                                _quantityButton(
                                  icon: Icons.add,
                                  onTap: () => cart.addItem(item.product, variant: item.variant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Checkout Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Payment Method Selector
                      Row(
                        children: [
                          Text(
                            lang.tr('Pembayaran:'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4A3022),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _paymentChip('QRIS', 'qris'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Total + Checkout Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Total'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                _formatPrice(cart.totalPrice),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4A3022),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _isCheckingOut ? null : _checkout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A3022),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isCheckingOut
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        lang.tr('Pesan Sekarang'),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFFF5E6D3),
      child: const Icon(Icons.coffee, color: Color(0xFFD2B48C), size: 28),
    );
  }

  Widget _quantityButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: const Color(0xFF4A3022)),
      ),
    );
  }

  Widget _paymentChip(String label, String value) {
    final isSelected = _selectedPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A3022) : const Color(0xFFF5E6D3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isSelected ? Colors.white : const Color(0xFF4A3022),
          ),
        ),
      ),
    );
  }
}
