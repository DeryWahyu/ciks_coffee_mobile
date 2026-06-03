import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../providers/language_provider.dart';

// Global notifier to trigger history refresh from other screens (e.g. OrderStatusScreen)
final ValueNotifier<int> globalHistoryRefresh = ValueNotifier<int>(0);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    globalHistoryRefresh.addListener(_fetchHistoryBackground);
  }

  @override
  void dispose() {
    globalHistoryRefresh.removeListener(_fetchHistoryBackground);
    super.dispose();
  }

  void _fetchHistoryBackground() async {
    final result = await _apiService.getOrderHistory();
    if (mounted && result['success']) {
      final data = result['data'] as List<dynamic>;
      setState(() {
        _orders = data.map((o) => OrderModel.fromJson(o)).toList();
      });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _apiService.getOrderHistory();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final data = result['data'] as List<dynamic>;
          _orders = data.map((o) => OrderModel.fromJson(o)).toList();
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  String _formatPrice(double price) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatCurrency.format(price);
  }

  String _formatDate(String dateStr, LanguageProvider lang) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return lang.isEnglish ? '${diff.inMinutes} mins ago' : '${diff.inMinutes} menit lalu';
      } else if (diff.inHours < 24) {
        return lang.isEnglish ? '${diff.inHours} hours ago' : '${diff.inHours} jam lalu';
      } else if (diff.inDays < 7) {
        return lang.isEnglish ? '${diff.inDays} days ago' : '${diff.inDays} hari lalu';
      } else {
        return DateFormat('dd MMM yyyy').format(date);
      }
    } catch (_) {
      return dateStr;
    }
  }

  String _formatFullDate(String dateStr, LanguageProvider lang) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(lang.isEnglish ? 'EEEE, MMMM dd yyyy • HH:mm' : 'EEEE, dd MMMM yyyy • HH:mm', lang.isEnglish ? 'en_US' : 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3),
      appBar: AppBar(
        title: Text(lang.isEnglish ? 'Order History' : 'Riwayat Pesanan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4A3022),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3022)))
          : _errorMessage != null
              ? _buildErrorState(lang)
              : _orders.isEmpty
                  ? _buildEmptyState(lang)
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      color: const Color(0xFF4A3022),
                      child: Column(
                        children: [
                          // Summary header
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4A3022),
                                  const Color(0xFF4A3022).withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_orders.length} ${lang.isEnglish ? 'Orders' : 'Pesanan'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Total: ${_formatPrice(_orders.fold(0.0, (sum, o) => sum + o.total))}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Order list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) => _buildHistoryCard(_orders[index], lang),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFD2B48C).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 56, color: const Color(0xFFD2B48C).withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          Text(
            lang.isEnglish ? 'No History Yet' : 'Belum Ada Riwayat',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4A3022),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang.isEnglish ? 'Orders that have been picked up\nwill appear here.' : 'Pesanan yang sudah diambil\nakan muncul di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF4A3022).withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _fetchHistory,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Refresh', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A3022),
              side: const BorderSide(color: Color(0xFF4A3022)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? (lang.isEnglish ? 'An error occurred' : 'Terjadi kesalahan'),
            style: GoogleFonts.inter(color: const Color(0xFF4A3022)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchHistory,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(lang.isEnglish ? 'Try Again' : 'Coba Lagi', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A3022),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(OrderModel order, LanguageProvider lang) {
    return GestureDetector(
      onTap: () => _showDetailSheet(order, lang),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF4A3022),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: const Color(0xFF4A3022).withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(order.createdAt, lang),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E6D3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${order.items.length} item',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrice(order.total),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A3022),
                  ),
                ),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right, size: 18, color: const Color(0xFF4A3022).withValues(alpha: 0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(OrderModel order, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.isEnglish ? 'Order Details' : 'Detail Pesanan',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A3022),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.orderNumber,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 4),
                          Text(
                            lang.isEnglish ? 'Done' : 'Selesai',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Date
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: const Color(0xFF4A3022).withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Text(
                      _formatFullDate(order.createdAt, lang),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: const Color(0xFFD2B48C).withValues(alpha: 0.2)),
              // Items list
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  shrinkWrap: true,
                  children: [
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5E6D3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${item.quantity}x',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.productName,
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF4A3022)),
                            ),
                          ),
                          Text(
                            _formatPrice(item.subtotal),
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF4A3022)),
                          ),
                        ],
                      ),
                    )),
                    Divider(color: const Color(0xFFD2B48C).withValues(alpha: 0.2)),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF4A3022)),
                          ),
                          Text(
                            _formatPrice(order.total),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF4A3022)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Payment info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6D3).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payment, size: 18, color: const Color(0xFF4A3022).withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Text(
                            lang.isEnglish ? 'Payment Method' : 'Metode Pembayaran',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            order.paymentMethod.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4A3022),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
