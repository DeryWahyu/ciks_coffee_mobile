import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../screens/history_screen.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final ApiService _apiService = ApiService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  
  Timer? _pollingTimer;
  final Map<int, String> _previousStatuses = {};

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 5 seconds to check for order updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollActiveOrders();
    });
  }

  Future<void> _fetchActiveOrders() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getActiveOrders();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final data = result['data'] as List<dynamic>;
          _orders = data.map((o) => OrderModel.fromJson(o)).toList();
          
          for (var order in _orders) {
            _previousStatuses[order.id] = order.status;
          }
        }
      });
      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  Future<void> _pollActiveOrders() async {
    final result = await _apiService.getActiveOrders();
    if (!mounted) return;
    
    if (result['success']) {
      final data = result['data'] as List<dynamic>;
      final newOrders = data.map((o) => OrderModel.fromJson(o)).toList();
      
      bool statusChanged = false;
      
      for (var newOrder in newOrders) {
        final oldStatus = _previousStatuses[newOrder.id];
        if (oldStatus != null && oldStatus != newOrder.status) {
          final oldStage = _stageIndex(oldStatus);
          final newStage = _stageIndex(newOrder.status);
          
          // If the order progressed to a further stage, trigger the notification
          if (newStage > oldStage) {
            statusChanged = true;
          }
        }
        _previousStatuses[newOrder.id] = newOrder.status;
      }
      
      if (statusChanged) {
        _playNotificationSound();
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.isEnglish ? 'Your order status has been updated!' : 'Status pesananmu telah diperbarui!', 
              style: GoogleFonts.inter()
            ),
            backgroundColor: const Color(0xFF4A3022),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          )
        );
      }
      
      setState(() {
        _orders = newOrders;
      });
    }
  }

  Future<void> _playNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    if (!isEnabled) return;

    FlutterRingtonePlayer().play(
      android: AndroidSounds.notification,
      ios: IosSounds.receivedMessage,
      looping: false,
      volume: 1.0,
      asAlarm: true, // asAlarm ensures it is loud even if media volume is low (but respects silent mode)
    );
  }

  String _formatPrice(double price) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatCurrency.format(price);
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  Future<void> _confirmPickup(OrderModel order, LanguageProvider lang) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.isEnglish ? 'Confirm Pickup' : 'Konfirmasi Pengambilan',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),
        ),
        content: Text(
          lang.isEnglish ? 'Have you picked up order ${order.orderNumber}?' : 'Apakah pesanan ${order.orderNumber} sudah kamu ambil?',
          style: GoogleFonts.inter(color: const Color(0xFF4A3022)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.isEnglish ? 'Not yet' : 'Belum', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A3022),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(lang.isEnglish ? 'Picked Up' : 'Sudah Diambil', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _apiService.confirmPickup(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? const Color(0xFF4A3022) : Colors.red.shade700,
          ),
        );
        if (result['success']) {
          _fetchActiveOrders();
          globalHistoryRefresh.value++; // Trigger HistoryScreen refresh
        }
      }
    }
  }

  // ─── Status Data ───
  static const _stages = [
    {'status': 'menunggu_verifikasi', 'label': 'Verifikasi', 'label_en': 'Verification', 'icon': Icons.hourglass_top},
    {'status': 'antrian_baru', 'label': 'Antrean Baru', 'label_en': 'In Queue', 'icon': Icons.receipt_long},
    {'status': 'sedang_dibuat', 'label': 'Sedang Dibuat', 'label_en': 'Preparing', 'icon': Icons.coffee_maker},
    {'status': 'selesai', 'label': 'Siap Diambil', 'label_en': 'Ready to Pickup', 'icon': Icons.check_circle},
  ];

  Color _stageColor(String status) {
    switch (status) {
      case 'menunggu_verifikasi':
        return const Color(0xFFFF6D00);
      case 'antrian_baru':
        return const Color(0xFFFF9800);
      case 'sedang_dibuat':
        return const Color(0xFF2196F3);
      case 'selesai':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  int _stageIndex(String status) {
    switch (status) {
      case 'menunggu_verifikasi':
        return 0;
      case 'antrian_baru':
        return 1;
      case 'sedang_dibuat':
        return 2;
      case 'selesai':
        return 3;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3),
      appBar: AppBar(
        title: Text(lang.isEnglish ? 'Order Status' : 'Status Pesanan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4A3022),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3022)))
          : _orders.isEmpty
              ? _buildEmptyState(lang)
              : RefreshIndicator(
                  onRefresh: _fetchActiveOrders,
                  color: const Color(0xFF4A3022),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) => _buildOrderCard(_orders[index], lang),
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
            child: Icon(Icons.coffee, size: 56, color: const Color(0xFFD2B48C).withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          Text(
            lang.isEnglish ? 'No Active Orders' : 'Tidak Ada Pesanan Aktif',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4A3022),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang.isEnglish ? 'Your orders will appear here\nafter you place an order.' : 'Pesananmu akan muncul di sini\nsetelah kamu melakukan pemesanan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF4A3022).withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _fetchActiveOrders,
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

  Widget _buildOrderCard(OrderModel order, LanguageProvider lang) {
    final currentStage = _stageIndex(order.status);
    final isReady = order.status == 'selesai';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: isReady
            ? Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: _stageColor(order.status).withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.orderNumber,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: const Color(0xFF4A3022),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _stageColor(order.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lang.isEnglish ? _stages[currentStage >= 0 ? currentStage : 0]['label_en'] as String : order.statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _stageColor(order.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.paymentMethod.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatPrice(order.total),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF4A3022),
                  ),
                ),
              ],
            ),
          ),

          // Progress Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: List.generate(_stages.length * 2 - 1, (i) {
                if (i.isOdd) {
                  // Connector line
                  final lineIndex = i ~/ 2;
                  final isActive = currentStage > lineIndex;
                  return Expanded(
                     child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive
                            ? _stageColor(order.status)
                            : const Color(0xFFD2B48C).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                } else {
                  // Stage dot
                  final stageIdx = i ~/ 2;
                  final stage = _stages[stageIdx];
                  final isActive = currentStage >= stageIdx;
                  final isCurrent = currentStage == stageIdx;
                  final color = isActive ? _stageColor(order.status) : const Color(0xFFD2B48C).withValues(alpha: 0.4);

                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.all(isCurrent ? 8 : 6),
                        decoration: BoxDecoration(
                          color: isCurrent ? color.withValues(alpha: 0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          stage['icon'] as IconData,
                          size: isCurrent ? 22 : 18,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.isEnglish ? stage['label_en'] as String : stage['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? const Color(0xFF4A3022) : const Color(0xFF4A3022).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  );
                }
              }),
            ),
          ),

          // Divider
          Divider(height: 1, color: const Color(0xFFD2B48C).withValues(alpha: 0.2)),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E6D3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}x',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A3022),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4A3022)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatPrice(item.subtotal),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Pickup Button (only for 'selesai' status)
          if (isReady)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmPickup(order, lang),
                  icon: const Icon(Icons.back_hand_outlined, size: 18),
                  label: Text(
                    lang.isEnglish ? 'Order Picked Up' : 'Pesanan Telah Diambil',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}
